@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Floor tool controller — owns the floor dock settings, rectangle/polygon
## draw previews (including hole mode), Enter-to-close polygon handling,
## hover-edit picks, and vertex/edge/body drag editing (stage 5 of the plugin
## split). Undo/redo actions bind this plugin-lifetime controller, the
## context, or the edited nodes.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floors/floor_3d.gd")

const FLOOR_TYPE_SOLID := "solid"
const FLOOR_TYPE_HOLE := "hole"

var m_floor_settings := {
	"grid_step": 0.5,
	"type": FLOOR_TYPE_SOLID,
	"style": FLOOR_STYLE_RECTANGLE,
	"base_height": 0.0,
	"thickness": 0.12,
	"color": Color(0.46, 0.40, 0.32, 1.0),
}
var m_floor_start_local := Vector3.ZERO
var m_floor_end_local := Vector3.ZERO
var m_floor_start_screen_position := Vector2.ZERO
var m_floor_has_valid_preview := false
var m_floor_release_commits_preview := false
var m_is_drawing_floor := false
var m_floor_preview: Floor3DScript
var m_floor_polygon_points := PackedVector3Array()
var m_dragging_floor: Floor3DScript
var m_drag_floor_old_start := Vector3.ZERO
var m_drag_floor_old_end := Vector3.ZERO
var m_drag_floor_old_polygon := PackedVector3Array()
var m_drag_floor_old_holes: Array[Rect2] = []
var m_drag_floor_started_as_polygon := false
var m_drag_floor_vertex_index := -1
var m_drag_floor_edge_index := -1
var m_drag_floor_hole_index := -1
var m_drag_floor_hole_old_polygons: Array[PackedVector2Array] = []
var m_drag_floor_anchor_local := Vector3.ZERO
var m_drag_floor_edit_mask := FLOOR_EDIT_MOVE
var m_drag_floor_active_material: Material
var m_drag_floor_hover: Floor3DScript
var m_drag_floor_hover_material: Material
var m_drag_floor_hover_edit_mask := FLOOR_EDIT_MOVE


func apply_settings(settings: Dictionary) -> void:
	m_floor_settings = settings.duplicate(true)
	_clear_floor_preview()
	_reset_floor_drawing_state()


func cancel_preview() -> void:
	_cancel_floor_drag()
	_clear_floor_hover()
	_clear_floor_preview()
	_reset_floor_drawing_state()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and !key_event.echo
			and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER)
			and _is_polygon_floor_mode()
			and m_is_drawing_floor
		):
			_finish_polygon_floor()
			return m_context.handled()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	return _handle_floor_input(camera, event)


func _handle_floor_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_floor != null:
		return _handle_floor_drag_input(camera, event)
	if _is_polygon_floor_mode():
		return _handle_polygon_floor_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_floor:
			_update_floor_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_floor_start_screen_position) >= DRAG_COMMIT_DISTANCE:
				m_floor_release_commits_preview = true
			return m_context.handled()
		var floor_pick := (
			_find_floor_hole_edit_pick(camera, mouse_motion.position)
			if _is_floor_hole_mode()
			else _find_floor_edit_pick(camera, mouse_motion.position)
		)
		if _is_floor_hole_mode() and floor_pick.is_empty():
			floor_pick = _find_floor_pick(camera, mouse_motion.position)
		var hover_floor := floor_pick.get("floor") as Floor3DScript
		var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_floor_hover(hover_floor, edit_mask)
		if hover_floor != null:
			if _is_floor_hole_mode():
				if floor_pick.has("hole_index"):
					_set_floor_hole_edit_hover_status(edit_mask)
				else:
					m_context.set_status("Drag to draw a floor hole inside the highlighted floor.")
			else:
				_set_floor_edit_hover_status(hover_floor, edit_mask)
		elif _is_floor_hole_mode():
			m_context.set_status("Draw a hole fully inside an existing floor.")
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_floor:
		if !m_floor_release_commits_preview:
			m_context.set_status(
				"Click the opposite corner to cut floor hole, or drag from the first corner and release."
				if _is_floor_hole_mode()
				else "Click the opposite corner to place floor, or drag from the first corner and release."
			)
			return m_context.handled()
		var release_coordinator := _get_active_floor_coordinator()
		if release_coordinator != null:
			var release_end := m_floor_end_local
			if !m_floor_has_valid_preview:
				release_end = _floor_draw_local_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_floor(release_coordinator, m_floor_start_local, release_end)
		_clear_floor_preview()
		_reset_floor_drawing_state()
		return m_context.handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_floor and !_is_floor_hole_mode():
		var floor_pick := _find_floor_edit_pick(camera, mouse_button.position)
		if _begin_floor_edit_from_pick(camera, mouse_button, floor_pick):
			return m_context.handled()
	if !m_is_drawing_floor and _is_floor_hole_mode():
		var hole_pick := _find_floor_hole_edit_pick(camera, mouse_button.position)
		if _begin_floor_hole_edit_from_pick(camera, mouse_button, hole_pick):
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing floors.")
		return m_context.handled()

	var snapped_local := _floor_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_floor:
		m_floor_start_local = snapped_local
		m_floor_end_local = snapped_local
		m_floor_start_screen_position = mouse_button.position
		m_floor_has_valid_preview = false
		m_floor_release_commits_preview = false
		m_is_drawing_floor = true
		_create_floor_preview(coordinator)
		_update_floor_preview(camera, mouse_button.position)
		m_context.set_status(
			"Floor hole first corner captured. Drag and release, or click the opposite corner."
			if _is_floor_hole_mode()
			else "Floor first corner captured. Drag and release, or click the opposite corner."
		)
		return m_context.handled()

	_commit_floor(coordinator, m_floor_start_local, snapped_local)
	_clear_floor_preview()
	_reset_floor_drawing_state()
	return m_context.handled()


func _handle_polygon_floor_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_floor:
			_update_polygon_floor_preview(camera, mouse_motion.position)
			return m_context.handled()
		var floor_pick := (
			_find_floor_hole_edit_pick(camera, mouse_motion.position)
			if _is_floor_hole_mode()
			else _find_floor_edit_pick(camera, mouse_motion.position)
		)
		var hover_floor := floor_pick.get("floor") as Floor3DScript
		var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_floor_hover(hover_floor, edit_mask)
		if hover_floor != null:
			if _is_floor_hole_mode():
				_set_floor_hole_edit_hover_status(edit_mask)
			else:
				_set_floor_edit_hover_status(hover_floor, edit_mask)
		else:
			m_context.set_status("Click the first polygon vertex.")
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_floor:
		var floor_pick := (
			_find_floor_hole_edit_pick(camera, mouse_button.position)
			if _is_floor_hole_mode()
			else _find_floor_edit_pick(camera, mouse_button.position)
		)
		var began_edit := (
			_begin_floor_hole_edit_from_pick(camera, mouse_button, floor_pick)
			if _is_floor_hole_mode()
			else _begin_floor_edit_from_pick(camera, mouse_button, floor_pick)
		)
		if began_edit:
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing floors.")
		return m_context.handled()
	var snapped_local := _floor_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_floor:
		m_is_drawing_floor = true
		m_floor_polygon_points = PackedVector3Array([snapped_local])
		_create_floor_preview(coordinator)
		_update_polygon_floor_preview(camera, mouse_button.position)
		m_context.set_status("Polygon vertex 1 captured. Click more vertices, then click the first vertex or press Enter.")
		return m_context.handled()

	if (
		m_floor_polygon_points.size() >= 3
		and snapped_local.distance_to(m_floor_polygon_points[0])
			<= maxf(float(m_floor_settings["grid_step"]) * 0.25, 0.05)
	):
		_finish_polygon_floor()
		return m_context.handled()
	m_floor_polygon_points.append(snapped_local)
	_update_polygon_floor_preview(camera, mouse_button.position)
	m_context.set_status(
		"Polygon vertex %d captured. Click the first vertex or press Enter to close."
		% m_floor_polygon_points.size()
	)
	return m_context.handled()


func _update_polygon_floor_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_floor_preview == null:
		return
	var coordinator := m_floor_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var hover_point := _floor_draw_local_from_mouse(coordinator, camera, mouse_position)
	var preview_points := m_floor_polygon_points.duplicate()
	if preview_points.is_empty() or !preview_points[preview_points.size() - 1].is_equal_approx(hover_point):
		preview_points.append(hover_point)
	m_floor_preview.set_floor_polygon(preview_points)
	m_floor_has_valid_preview = _is_valid_floor_polygon(preview_points)


func _finish_polygon_floor() -> void:
	var coordinator := _get_active_floor_coordinator()
	if coordinator == null or !_is_valid_floor_polygon(m_floor_polygon_points):
		m_context.set_status("A floor polygon needs at least three non-intersecting vertices.")
		return
	if _is_floor_hole_mode():
		_commit_floor_polygon_hole(coordinator, m_floor_polygon_points)
	else:
		_commit_floor_polygon(coordinator, m_floor_polygon_points)
	_clear_floor_preview()
	_reset_floor_drawing_state()


func _commit_floor_polygon(
	coordinator: Building3DScript,
	local_points: PackedVector3Array
) -> void:
	if !_is_valid_floor_polygon(local_points):
		m_context.set_status("Floor polygon is invalid.")
		return
	var floor := BuildingFactoryScript.create_floor_polygon_node(
		coordinator,
		local_points,
		float(m_floor_settings["thickness"]),
		Color(m_floor_settings["color"])
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Polygon Floor")
	undo_redo.add_do_reference(floor)
	undo_redo.add_do_method(m_context, "do_add_node", coordinator, floor, scene_root, true)
	undo_redo.add_undo_method(m_context, "undo_remove_node", coordinator, floor)
	undo_redo.commit_action()
	m_context.set_status(
		"Created polygon floor: %d vertices, %.2f square units."
		% [local_points.size(), floor.get_floor_area()]
	)


func _set_floor_edit_hover_status(floor: Floor3DScript, edit_mask: int) -> void:
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		m_context.set_status("Drag vertex to reshape. Option/Alt-click it to remove.")
		return
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		m_context.set_status("Drag edge to reshape. Shift-click it to add a vertex.")
		return
	if floor.is_polygon_floor():
		m_context.set_status("Drag floor body to move it.")
		return
	m_context.set_status(
		"Drag floor corner to resize." if _floor_edit_mask_is_corner(edit_mask)
		else "Drag floor edge to resize." if edit_mask != FLOOR_EDIT_MOVE
		else "Drag floor body to move."
	)


func _set_floor_hole_edit_hover_status(edit_mask: int) -> void:
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		m_context.set_status("Drag hole vertex to reshape. Option/Alt-click it to remove.")
	elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		m_context.set_status("Drag hole edge to reshape. Shift-click it to add a vertex.")
	else:
		m_context.set_status("Drag hole body to move it.")


func _begin_floor_hole_edit_from_pick(
	camera: Camera3D,
	mouse_button: InputEventMouseButton,
	floor_pick: Dictionary
) -> bool:
	var floor := floor_pick.get("floor") as Floor3DScript
	if floor == null or !floor_pick.has("hole_index"):
		return false
	_clear_floor_hover()
	var hole_index := int(floor_pick.get("hole_index", -1))
	var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
	var vertex_index := int(floor_pick.get("vertex_index", -1))
	var edge_index := int(floor_pick.get("edge_index", -1))
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX and mouse_button.alt_pressed:
		_remove_floor_hole_vertex(floor, hole_index, vertex_index)
		return true
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE and mouse_button.shift_pressed:
		var parent_position := Vector3(floor_pick.get("parent_position", floor.start_point))
		_add_floor_hole_vertex(floor, hole_index, edge_index, parent_position)
		return true
	_start_floor_hole_drag(
		floor,
		hole_index,
		camera,
		mouse_button.position,
		edit_mask,
		vertex_index,
		edge_index
	)
	return true


func _start_floor_hole_drag(
	floor: Floor3DScript,
	hole_index: int,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int,
	vertex_index: int,
	edge_index: int
) -> void:
	m_dragging_floor = floor
	m_drag_floor_hole_index = hole_index
	m_drag_floor_hole_old_polygons = floor.get_floor_hole_polygons()
	m_drag_floor_edit_mask = edit_mask
	m_drag_floor_vertex_index = vertex_index
	m_drag_floor_edge_index = edge_index
	m_drag_floor_anchor_local = _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	m_drag_floor_active_material = floor.material_override
	floor.material_override = m_context.build_preview_material(_floor_drag_color(edit_mask, true))
	m_context.select_node(floor)
	m_context.set_status("Dragging floor hole %s - release to commit, Escape to cancel." % _floor_edit_label(edit_mask))


func _add_floor_hole_vertex(
	floor: Floor3DScript,
	hole_index: int,
	edge_index: int,
	parent_position: Vector3
) -> void:
	var old_holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
	if hole_index < 0 or hole_index >= old_holes.size():
		return
	var hole: PackedVector2Array = old_holes[hole_index].duplicate()
	if edge_index < 0 or edge_index >= hole.size():
		return
	var snapped_parent := _snap_floor_edit_local(floor, parent_position)
	var new_point := Vector2(
		snapped_parent.x - floor.position.x,
		snapped_parent.z - floor.position.z
	)
	if new_point.distance_to(hole[edge_index]) <= 0.001:
		return
	if new_point.distance_to(hole[(edge_index + 1) % hole.size()]) <= 0.001:
		return
	hole.insert(edge_index + 1, new_point)
	if !floor.can_set_floor_hole_polygon(hole_index, hole):
		m_context.set_status("That point would make the floor hole invalid.")
		return
	var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
	new_holes[hole_index] = hole
	_commit_floor_hole_polygons(floor, old_holes, new_holes, "Add Floor Hole Vertex")


func _remove_floor_hole_vertex(
	floor: Floor3DScript,
	hole_index: int,
	vertex_index: int
) -> void:
	var old_holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
	if hole_index < 0 or hole_index >= old_holes.size():
		return
	var hole: PackedVector2Array = old_holes[hole_index].duplicate()
	if hole.size() <= 3:
		m_context.set_status("A floor hole must keep at least three vertices.")
		return
	if vertex_index < 0 or vertex_index >= hole.size():
		return
	hole.remove_at(vertex_index)
	if !floor.can_set_floor_hole_polygon(hole_index, hole):
		m_context.set_status("Removing that vertex would make the floor hole invalid.")
		return
	var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
	new_holes[hole_index] = hole
	_commit_floor_hole_polygons(floor, old_holes, new_holes, "Remove Floor Hole Vertex")


func _commit_floor_hole_polygons(
	floor: Floor3DScript,
	old_holes: Array[PackedVector2Array],
	new_holes: Array[PackedVector2Array],
	action_name: String
) -> void:
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(floor, "set_floor_hole_polygons", new_holes)
	undo_redo.add_do_method(m_context, "select_node", floor)
	undo_redo.add_undo_method(floor, "set_floor_hole_polygons", old_holes)
	undo_redo.add_undo_method(m_context, "select_node", floor)
	undo_redo.commit_action()


func _begin_floor_edit_from_pick(
	camera: Camera3D,
	mouse_button: InputEventMouseButton,
	floor_pick: Dictionary
) -> bool:
	var floor := floor_pick.get("floor") as Floor3DScript
	if floor == null:
		return false
	_clear_floor_hover()
	var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
	var vertex_index := int(floor_pick.get("vertex_index", -1))
	var edge_index := int(floor_pick.get("edge_index", -1))
	if (
		edit_mask == FLOOR_EDIT_POLYGON_VERTEX
		and mouse_button.alt_pressed
	):
		_remove_floor_vertex(floor, vertex_index)
		return true
	if (
		edit_mask == FLOOR_EDIT_POLYGON_EDGE
		and mouse_button.shift_pressed
	):
		var hit_parent_position := Vector3(
			floor_pick.get("parent_position", floor.start_point)
		)
		_add_floor_vertex(floor, edge_index, hit_parent_position)
		return true
	_start_floor_drag(
		floor,
		camera,
		mouse_button.position,
		edit_mask,
		vertex_index,
		edge_index
	)
	return true


func _add_floor_vertex(
	floor: Floor3DScript,
	edge_index: int,
	parent_position: Vector3
) -> void:
	var old_points := _get_floor_edit_points(floor)
	if edge_index < 0 or edge_index >= old_points.size():
		m_context.set_status("No floor edge selected.")
		return
	var new_point := _snap_floor_edit_local(floor, parent_position)
	var edge_start := old_points[edge_index]
	var edge_end := old_points[(edge_index + 1) % old_points.size()]
	if new_point.distance_to(edge_start) <= 0.001 or new_point.distance_to(edge_end) <= 0.001:
		m_context.set_status("New vertex must be between two existing vertices.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		new_points.append(old_points[index])
		if index == edge_index:
			new_points.append(new_point)
	if !_is_valid_floor_polygon(new_points):
		m_context.set_status("That point would make an invalid polygon.")
		return
	_commit_floor_points(
		floor,
		old_points,
		new_points,
		"Add Floor Vertex",
		"Added floor vertex."
	)


func _remove_floor_vertex(floor: Floor3DScript, vertex_index: int) -> void:
	var old_points := _get_floor_edit_points(floor)
	if old_points.size() <= 3:
		m_context.set_status("A floor must keep at least three vertices.")
		return
	if vertex_index < 0 or vertex_index >= old_points.size():
		m_context.set_status("No floor vertex selected.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		if index != vertex_index:
			new_points.append(old_points[index])
	if !_is_valid_floor_polygon(new_points):
		m_context.set_status("Removing that vertex would make an invalid polygon.")
		return
	_commit_floor_points(
		floor,
		old_points,
		new_points,
		"Remove Floor Vertex",
		"Removed floor vertex."
	)


func _commit_floor_points(
	floor: Floor3DScript,
	old_points: PackedVector3Array,
	new_points: PackedVector3Array,
	action_name: String,
	status: String
) -> void:
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(floor, "set_floor_polygon", new_points)
	undo_redo.add_do_method(m_context, "select_node", floor)
	if floor.is_polygon_floor():
		undo_redo.add_undo_method(floor, "set_floor_polygon", old_points)
	else:
		undo_redo.add_undo_method(
			floor,
			"set_floor_corners_and_holes",
			floor.start_point,
			floor.end_point,
			floor.get_floor_holes()
		)
	undo_redo.add_undo_method(m_context, "select_node", floor)
	undo_redo.commit_action()
	m_context.set_status(status)


func _create_floor_preview(coordinator: Building3DScript) -> void:
	_clear_floor_preview()
	m_floor_preview = Floor3DScript.new() as Floor3DScript
	m_floor_preview.name = "FloorPreview"
	m_floor_preview.set_meta(Floor3DScript.PREVIEW_META, true)
	m_floor_preview.floor_thickness = float(m_floor_settings["thickness"])
	var preview_color := (
		Color(0.95, 0.20, 0.16, 1.0)
		if _is_floor_hole_mode()
		else Color(m_floor_settings["color"])
	)
	preview_color.a = 0.44
	m_floor_preview.floor_color = preview_color
	m_floor_preview.generate_collision = false
	coordinator.add_child(m_floor_preview)
	m_floor_preview.owner = null
	m_context.apply_debug_wireframe_to_node(m_floor_preview)


func _update_floor_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_floor_preview == null:
		return
	var coordinator := m_floor_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var local_end := _floor_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_floor_end_local = local_end
	m_floor_has_valid_preview = _is_floor_span_large_enough(m_floor_start_local, local_end)
	m_floor_preview.set_floor_corners(m_floor_start_local, local_end)
	if m_floor_has_valid_preview:
		var size := m_floor_preview.get_floor_size()
		if _is_floor_hole_mode():
			var target_floor := _find_floor_for_polygon_hole(
				coordinator,
				_rectangle_floor_points(m_floor_start_local, local_end)
			)
			if target_floor != null:
				m_context.set_status("Release or click to cut floor hole: %.2f x %.2f." % [size.x, size.y])
			else:
				m_context.set_status("Draw the hole fully inside one existing floor.")
		else:
			m_context.set_status("Release or click to place floor: %.2f x %.2f." % [size.x, size.y])


func _floor_base_height() -> float:
	return float(m_floor_settings.get("base_height", 0.0))


func _floor_tool_type() -> String:
	return str(m_floor_settings.get("type", FLOOR_TYPE_SOLID))


func _floor_tool_style() -> String:
	return str(m_floor_settings.get("style", FLOOR_STYLE_RECTANGLE))


func _is_floor_hole_mode() -> bool:
	return _floor_tool_type() == FLOOR_TYPE_HOLE


func _is_polygon_floor_mode() -> bool:
	return _floor_tool_style() == FLOOR_STYLE_POLYGON


func _floor_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _floor_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	if _is_floor_hole_mode():
		if m_is_drawing_floor:
			base_y = m_floor_start_local.y
		var floor_hit := _raycast_floors(origin, direction)
		var hit_floor := floor_hit.get("floor") as Floor3DScript
		if hit_floor != null:
			base_y = hit_floor.start_point.y
			return _snap_floor_draw_local(
				coordinator,
				coordinator.to_local(Vector3(floor_hit["position"])),
				base_y
			)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_floor_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := m_context.raycast_world(camera, mouse_position, false)
	return _snap_floor_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_floor_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_floor_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _get_active_floor_coordinator() -> Building3DScript:
	if m_floor_preview != null and is_instance_valid(m_floor_preview):
		var preview_parent := m_floor_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return m_context.get_or_create_coordinator(false)


func _commit_floor(coordinator: Building3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_floor_span_large_enough(local_start, local_end):
		m_context.set_status("Floor is too small.")
		return
	if _is_floor_hole_mode():
		_commit_floor_hole(coordinator, local_start, local_end)
		return

	var floor := BuildingFactoryScript.create_floor_node(
		coordinator,
		local_start,
		local_end,
		float(m_floor_settings["thickness"]),
		Color(m_floor_settings["color"])
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Floor")
	undo_redo.add_do_reference(floor)
	undo_redo.add_do_method(m_context, "do_add_node", coordinator, floor, scene_root, true)
	undo_redo.add_undo_method(m_context, "undo_remove_node", coordinator, floor)
	undo_redo.commit_action()
	var size := floor.get_floor_size()
	m_context.set_status("Created floor: %.2f x %.2f units." % [size.x, size.y])


func _commit_floor_hole(
	coordinator: Building3DScript,
	local_start: Vector3,
	local_end: Vector3
) -> void:
	_commit_floor_polygon_hole(
		coordinator,
		_rectangle_floor_points(local_start, local_end)
	)


func _commit_floor_polygon_hole(
	coordinator: Building3DScript,
	parent_points: PackedVector3Array
) -> void:
	var target_floor := _find_floor_for_polygon_hole(coordinator, parent_points)
	if target_floor == null:
		m_context.set_status("Draw the hole fully inside one existing floor.")
		return
	var local_polygon := target_floor.get_floor_hole_polygon_from_parent_points(parent_points)
	if !target_floor.can_add_floor_hole_polygon(local_polygon):
		m_context.set_status("Floor hole must stay fully inside the floor.")
		return
	var old_holes: Array[PackedVector2Array] = target_floor.get_floor_hole_polygons()
	var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
	new_holes.append(local_polygon)
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Floor Hole")
	undo_redo.add_do_method(target_floor, "set_floor_hole_polygons", new_holes)
	undo_redo.add_do_method(m_context, "select_node", target_floor)
	undo_redo.add_undo_method(target_floor, "set_floor_hole_polygons", old_holes)
	undo_redo.add_undo_method(m_context, "select_node", target_floor)
	undo_redo.commit_action()
	m_context.set_status(
		"Cut floor hole: %d vertices."
		% local_polygon.size()
	)


func _find_floor_for_polygon_hole(
	coordinator: Building3DScript,
	parent_points: PackedVector3Array
) -> Floor3DScript:
	if coordinator == null or parent_points.is_empty():
		return null
	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(coordinator, floors)
	var best_floor: Floor3DScript = null
	var best_area := INF
	var height_tolerance := maxf(float(m_floor_settings["grid_step"]) * 0.05, 0.01)
	for floor in floors:
		if !is_instance_valid(floor) or floor == m_floor_preview:
			continue
		if floor.has_meta(Floor3DScript.PREVIEW_META):
			continue
		if absf(floor.start_point.y - parent_points[0].y) > height_tolerance:
			continue
		var local_polygon := floor.get_floor_hole_polygon_from_parent_points(parent_points)
		if !floor.can_add_floor_hole_polygon(local_polygon):
			continue
		var floor_area := floor.get_floor_area()
		if best_floor == null or floor_area < best_area:
			best_floor = floor
			best_area = floor_area
	return best_floor


func _handle_floor_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_floor_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_floor_drag()
			return m_context.handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_floor_drag()
			return m_context.handled()
	return m_context.handled()


func _start_floor_drag(
	floor: Floor3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int,
	vertex_index: int = -1,
	edge_index: int = -1
) -> void:
	m_dragging_floor = floor
	m_drag_floor_old_start = floor.start_point
	m_drag_floor_old_end = floor.end_point
	m_drag_floor_old_polygon = _get_floor_edit_points(floor)
	m_drag_floor_old_holes = floor.get_floor_holes()
	m_drag_floor_started_as_polygon = floor.is_polygon_floor()
	m_drag_floor_edit_mask = edit_mask
	if vertex_index >= 0:
		m_drag_floor_edit_mask = FLOOR_EDIT_POLYGON_VERTEX
	elif edge_index >= 0:
		m_drag_floor_edit_mask = FLOOR_EDIT_POLYGON_EDGE
	elif floor.is_polygon_floor():
		m_drag_floor_edit_mask = FLOOR_EDIT_MOVE
	m_drag_floor_vertex_index = vertex_index if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_VERTEX else -1
	m_drag_floor_edge_index = edge_index if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_EDGE else -1
	m_drag_floor_active_material = floor.material_override
	m_drag_floor_anchor_local = _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	floor.material_override = m_context.build_preview_material(_floor_drag_color(m_drag_floor_edit_mask, true))
	m_context.select_node(floor)
	m_context.set_status(
		"Dragging floor %s - release to commit, Escape to cancel."
		% _floor_edit_label(m_drag_floor_edit_mask)
	)


func _update_floor_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_floor == null or !is_instance_valid(m_dragging_floor):
		_reset_floor_drag_state()
		return
	var floor := m_dragging_floor
	if m_drag_floor_hole_index >= 0:
		_update_floor_hole_drag(floor, camera, mouse_pos)
		return
	var hit_local := _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	var new_start := m_drag_floor_old_start
	var new_end := m_drag_floor_old_end
	if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		var edited_polygon := m_drag_floor_old_polygon.duplicate()
		if m_drag_floor_vertex_index < 0 or m_drag_floor_vertex_index >= edited_polygon.size():
			return
		edited_polygon[m_drag_floor_vertex_index] = _snap_floor_edit_local(floor, hit_local)
		var valid := _is_valid_floor_polygon(edited_polygon)
		if valid:
			floor.set_floor_polygon(edited_polygon)
			m_context.set_status("Release to commit floor vertex position.")
		else:
			m_context.set_status("That position would make the floor invalid.")
		floor.material_override = m_context.build_preview_material(
			_floor_drag_color(FLOOR_EDIT_POLYGON_VERTEX, valid)
		)
		return
	if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		var edited_polygon := m_drag_floor_old_polygon.duplicate()
		if m_drag_floor_edge_index < 0 or m_drag_floor_edge_index >= edited_polygon.size():
			return
		var step := _active_floor_grid_step(floor)
		var raw_delta := hit_local - m_drag_floor_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var next_edge_index := (m_drag_floor_edge_index + 1) % edited_polygon.size()
		edited_polygon[m_drag_floor_edge_index] += snapped_delta
		edited_polygon[next_edge_index] += snapped_delta
		var valid := _is_valid_floor_polygon(edited_polygon)
		if valid:
			floor.set_floor_polygon(edited_polygon)
			m_context.set_status("Release to commit floor edge position.")
		else:
			m_context.set_status("That position would make the floor invalid.")
		floor.material_override = m_context.build_preview_material(
			_floor_drag_color(FLOOR_EDIT_POLYGON_EDGE, valid)
		)
		return
	if floor.is_polygon_floor():
		var step := _active_floor_grid_step(floor)
		var raw_delta := hit_local - m_drag_floor_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var moved_polygon := PackedVector3Array()
		for point in m_drag_floor_old_polygon:
			moved_polygon.append(point + snapped_delta)
		floor.set_floor_polygon(moved_polygon)
		floor.material_override = m_context.build_preview_material(_floor_drag_color(FLOOR_EDIT_MOVE, true))
		m_context.set_status("Release to commit polygon floor move.")
		return
	if m_drag_floor_edit_mask == FLOOR_EDIT_MOVE:
		var step := _active_floor_grid_step(floor)
		var raw_delta := hit_local - m_drag_floor_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start = m_drag_floor_old_start + snapped_delta
		new_end = m_drag_floor_old_end + snapped_delta
	else:
		var snapped := _snap_floor_edit_local(floor, hit_local)
		var resized := _resized_floor_points(snapped)
		new_start = Vector3(resized["start"])
		new_end = Vector3(resized["end"])

	floor.set_floor_corners(new_start, new_end)
	var holes_fit := _floor_holes_fit_for_points(floor, new_start, new_end)
	var valid := _is_floor_span_large_enough(new_start, new_end) and holes_fit
	floor.material_override = m_context.build_preview_material(
		_floor_drag_color(m_drag_floor_edit_mask, valid)
	)
	if valid:
		var size := floor.get_floor_size()
		m_context.set_status("Release to commit floor %s: %.2f x %.2f." % [_floor_edit_label(m_drag_floor_edit_mask), size.x, size.y])
	elif !holes_fit:
		m_context.set_status("Floor resize would move a hole outside the floor.")
	else:
		m_context.set_status("Floor is too small.")


func _update_floor_hole_drag(
	floor: Floor3DScript,
	camera: Camera3D,
	mouse_pos: Vector2
) -> void:
	var holes: Array[PackedVector2Array] = m_drag_floor_hole_old_polygons.duplicate()
	if m_drag_floor_hole_index < 0 or m_drag_floor_hole_index >= holes.size():
		return
	var hole: PackedVector2Array = holes[m_drag_floor_hole_index].duplicate()
	var hit_parent := _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	var snapped_parent := _snap_floor_edit_local(floor, hit_parent)
	var snapped_local := Vector2(
		snapped_parent.x - floor.position.x,
		snapped_parent.z - floor.position.z
	)
	var anchor_local := Vector2(
		m_drag_floor_anchor_local.x - floor.position.x,
		m_drag_floor_anchor_local.z - floor.position.z
	)
	var step := _active_floor_grid_step(floor)
	var raw_delta := snapped_local - anchor_local
	var delta := Vector2(
		roundf(raw_delta.x / step) * step,
		roundf(raw_delta.y / step) * step
	)
	if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		if m_drag_floor_vertex_index < 0 or m_drag_floor_vertex_index >= hole.size():
			return
		hole[m_drag_floor_vertex_index] = snapped_local
	elif m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		if m_drag_floor_edge_index < 0 or m_drag_floor_edge_index >= hole.size():
			return
		hole[m_drag_floor_edge_index] += delta
		hole[(m_drag_floor_edge_index + 1) % hole.size()] += delta
	else:
		for index in range(hole.size()):
			hole[index] += delta
	var valid := floor.can_set_floor_hole_polygon(m_drag_floor_hole_index, hole)
	if valid:
		holes[m_drag_floor_hole_index] = hole
		floor.set_floor_hole_polygons(holes)
		m_context.set_status("Release to commit floor hole edit.")
	else:
		m_context.set_status("That edit would make the floor hole invalid.")
	floor.material_override = m_context.build_preview_material(
		_floor_drag_color(m_drag_floor_edit_mask, valid)
	)


func _commit_floor_drag() -> void:
	if m_dragging_floor == null:
		return
	var floor := m_dragging_floor
	var old_start := m_drag_floor_old_start
	var old_end := m_drag_floor_old_end
	var old_polygon := m_drag_floor_old_polygon.duplicate()
	var new_start := floor.start_point
	var new_end := floor.end_point
	var new_polygon := floor.get_floor_polygon()
	var edit_mask := m_drag_floor_edit_mask
	floor.material_override = m_drag_floor_active_material
	if m_drag_floor_hole_index >= 0:
		var old_holes: Array[PackedVector2Array] = m_drag_floor_hole_old_polygons
		var new_holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
		if _floor_hole_polygons_match(old_holes, new_holes):
			_reset_floor_drag_state()
			m_context.set_status("Floor hole unchanged.")
			return
		_commit_floor_hole_polygons(floor, old_holes, new_holes, "Edit Floor Hole")
		_reset_floor_drag_state()
		m_context.set_status("Edited floor hole.")
		return
	if floor.is_polygon_floor():
		if old_polygon == new_polygon:
			_restore_floor_drag_original(floor)
			_reset_floor_drag_state()
			m_context.set_status("Floor unchanged.")
			return
		var polygon_undo_redo := m_context.undo_redo()
		var action_name := "Move Floor"
		if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
			action_name = "Edit Floor Vertex"
		elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
			action_name = "Edit Floor Edge"
		polygon_undo_redo.create_action(action_name)
		polygon_undo_redo.add_do_method(floor, "set_floor_polygon", new_polygon)
		polygon_undo_redo.add_do_method(m_context, "select_node", floor)
		if m_drag_floor_started_as_polygon:
			polygon_undo_redo.add_undo_method(floor, "set_floor_polygon", old_polygon)
		else:
			polygon_undo_redo.add_undo_method(
				floor,
				"set_floor_corners_and_holes",
				old_start,
				old_end,
				m_drag_floor_old_holes
			)
		polygon_undo_redo.commit_action()
		_reset_floor_drag_state()
		if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
			m_context.set_status("Edited floor vertex.")
		elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
			m_context.set_status("Edited floor edge.")
		else:
			m_context.set_status("Moved polygon floor.")
		return
	if !_is_floor_span_large_enough(new_start, new_end):
		floor.set_floor_corners(old_start, old_end)
		_reset_floor_drag_state()
		m_context.set_status("Floor is too small.")
		return
	if !_floor_holes_fit_for_points(floor, new_start, new_end):
		floor.set_floor_corners(old_start, old_end)
		_reset_floor_drag_state()
		m_context.set_status("Floor resize would move a hole outside the floor.")
		return
	if old_start.distance_to(new_start) <= 0.001 and old_end.distance_to(new_end) <= 0.001:
		_reset_floor_drag_state()
		m_context.set_status("Floor unchanged.")
		return

	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Move Floor" if edit_mask == FLOOR_EDIT_MOVE else "Resize Floor")
	undo_redo.add_do_method(floor, "set_floor_corners", new_start, new_end)
	undo_redo.add_do_method(m_context, "select_node", floor)
	undo_redo.add_undo_method(floor, "set_floor_corners", old_start, old_end)
	undo_redo.commit_action()
	_reset_floor_drag_state()
	var size := floor.get_floor_size()
	m_context.set_status("Edited floor: %.2f x %.2f units." % [size.x, size.y])


func _cancel_floor_drag() -> void:
	if m_dragging_floor == null:
		return
	if is_instance_valid(m_dragging_floor):
		if m_drag_floor_hole_index >= 0:
			m_dragging_floor.set_floor_hole_polygons(m_drag_floor_hole_old_polygons)
		else:
			_restore_floor_drag_original(m_dragging_floor)
		m_dragging_floor.material_override = m_drag_floor_active_material
	_reset_floor_drag_state()
	m_context.set_status("Floor edit canceled.")


func _restore_floor_drag_original(floor: Floor3DScript) -> void:
	if m_drag_floor_started_as_polygon:
		floor.set_floor_polygon(m_drag_floor_old_polygon)
	else:
		floor.set_floor_corners_and_holes(
			m_drag_floor_old_start,
			m_drag_floor_old_end,
			m_drag_floor_old_holes
		)


func _floor_hole_polygons_match(
	a: Array[PackedVector2Array],
	b: Array[PackedVector2Array]
) -> bool:
	if a.size() != b.size():
		return false
	for hole_index in range(a.size()):
		if a[hole_index].size() != b[hole_index].size():
			return false
		for point_index in range(a[hole_index].size()):
			if a[hole_index][point_index].distance_to(b[hole_index][point_index]) > 0.001:
				return false
	return true


func _resized_floor_points(snapped_hit: Vector3) -> Dictionary:
	var min_x := minf(m_drag_floor_old_start.x, m_drag_floor_old_end.x)
	var max_x := maxf(m_drag_floor_old_start.x, m_drag_floor_old_end.x)
	var min_z := minf(m_drag_floor_old_start.z, m_drag_floor_old_end.z)
	var max_z := maxf(m_drag_floor_old_start.z, m_drag_floor_old_end.z)
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MIN_X) != 0:
		min_x = snapped_hit.x
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MAX_X) != 0:
		max_x = snapped_hit.x
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MIN_Z) != 0:
		min_z = snapped_hit.z
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MAX_Z) != 0:
		max_z = snapped_hit.z
	var sorted_min_x := minf(min_x, max_x)
	var sorted_max_x := maxf(min_x, max_x)
	var sorted_min_z := minf(min_z, max_z)
	var sorted_max_z := maxf(min_z, max_z)
	var base_y := m_drag_floor_old_start.y
	return {
		"start": Vector3(sorted_min_x, base_y, sorted_min_z),
		"end": Vector3(sorted_max_x, base_y, sorted_max_z),
	}


func _floor_plane_local_from_mouse(
	floor: Floor3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var parent_3d := floor.get_parent() as Node3D
	var base_y := floor.start_point.y
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := parent_3d.to_local(origin) if parent_3d != null else origin
	var local_direction := (
		parent_3d.global_transform.basis.inverse() * direction
		if parent_3d != null
		else direction
	)
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return local_origin + local_direction * distance_to_plane
	return floor.start_point


func _snap_floor_edit_local(floor: Floor3DScript, local_position: Vector3) -> Vector3:
	var step := _active_floor_grid_step(floor)
	return Vector3(
		roundf(local_position.x / step) * step,
		floor.start_point.y,
		roundf(local_position.z / step) * step
	)


func _floor_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _floor_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		return "vertex"
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		return "edge"
	return "corner" if _floor_edit_mask_is_corner(edit_mask) else "edge"


func _floor_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _floor_holes_fit_for_points(floor: Floor3DScript, local_start: Vector3, local_end: Vector3) -> bool:
	if floor == null:
		return true
	return floor.floor_holes_fit_size(
		Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	)


func _active_floor_grid_step(_floor: Floor3DScript) -> float:
	return maxf(float(m_floor_settings["grid_step"]), 0.05)


func _reset_floor_drag_state() -> void:
	m_dragging_floor = null
	m_drag_floor_old_start = Vector3.ZERO
	m_drag_floor_old_end = Vector3.ZERO
	m_drag_floor_old_polygon = PackedVector3Array()
	m_drag_floor_old_holes.clear()
	m_drag_floor_started_as_polygon = false
	m_drag_floor_vertex_index = -1
	m_drag_floor_edge_index = -1
	m_drag_floor_hole_index = -1
	m_drag_floor_hole_old_polygons.clear()
	m_drag_floor_anchor_local = Vector3.ZERO
	m_drag_floor_edit_mask = FLOOR_EDIT_MOVE
	m_drag_floor_active_material = null


func _find_floor_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_floors(origin, direction)
	if hit.is_empty():
		return {}
	var floor := hit.get("floor") as Floor3DScript
	if floor == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mask"] = _floor_edit_mask_for_local_hit(floor, local_position)
	return hit


func _find_floor_edit_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var handle_pick := _find_floor_handle_pick(camera, mouse_pos)
	if !handle_pick.is_empty():
		return handle_pick
	return _find_floor_pick(camera, mouse_pos)


func _find_floor_hole_edit_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(scene_root, floors)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var best_pick: Dictionary = {}
	var best_camera_distance := INF
	for floor in floors:
		if !is_instance_valid(floor) or floor == m_floor_preview:
			continue
		var holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
		if holes.is_empty():
			continue
		var parent_3d := floor.get_parent() as Node3D
		var local_origin := parent_3d.to_local(ray_origin) if parent_3d != null else ray_origin
		var local_direction := (
			parent_3d.global_transform.basis.inverse() * ray_direction
			if parent_3d != null
			else ray_direction
		)
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()
		if absf(local_direction.y) <= 0.001:
			continue
		var plane_distance := (floor.start_point.y - local_origin.y) / local_direction.y
		if plane_distance <= 0.0:
			continue
		var parent_hit := local_origin + local_direction * plane_distance
		var floor_local_hit := Vector2(
			parent_hit.x - floor.position.x,
			parent_hit.z - floor.position.z
		)
		var global_hit := parent_3d.to_global(parent_hit) if parent_3d != null else parent_hit
		var camera_distance := ray_origin.distance_to(global_hit)
		if camera_distance > best_camera_distance + 0.01:
			continue
		var radius := maxf(_active_floor_grid_step(floor) * 0.35, 0.16)
		for hole_index in range(holes.size()):
			var hole: PackedVector2Array = holes[hole_index]
			var closest_vertex_index := -1
			var closest_vertex_distance := INF
			for vertex_index in range(hole.size()):
				var distance := floor_local_hit.distance_to(hole[vertex_index])
				if distance < closest_vertex_distance:
					closest_vertex_distance = distance
					closest_vertex_index = vertex_index
			if closest_vertex_index >= 0 and closest_vertex_distance <= radius:
				best_camera_distance = camera_distance
				best_pick = {
					"floor": floor,
					"hole_index": hole_index,
					"edit_mask": FLOOR_EDIT_POLYGON_VERTEX,
					"vertex_index": closest_vertex_index,
					"edge_index": -1,
					"parent_position": parent_hit,
				}
				continue
			var closest_edge_index := -1
			var closest_edge_distance := INF
			for edge_index in range(hole.size()):
				var edge_point := m_context.closest_point_on_plan_segment(
					floor_local_hit,
					hole[edge_index],
					hole[(edge_index + 1) % hole.size()]
				)
				var distance := floor_local_hit.distance_to(edge_point)
				if distance < closest_edge_distance:
					closest_edge_distance = distance
					closest_edge_index = edge_index
			if closest_edge_index >= 0 and closest_edge_distance <= radius:
				best_camera_distance = camera_distance
				best_pick = {
					"floor": floor,
					"hole_index": hole_index,
					"edit_mask": FLOOR_EDIT_POLYGON_EDGE,
					"vertex_index": -1,
					"edge_index": closest_edge_index,
					"parent_position": parent_hit,
				}
				continue
			if Geometry2D.is_point_in_polygon(floor_local_hit, hole):
				best_camera_distance = camera_distance
				best_pick = {
					"floor": floor,
					"hole_index": hole_index,
					"edit_mask": FLOOR_EDIT_MOVE,
					"vertex_index": -1,
					"edge_index": -1,
					"parent_position": parent_hit,
				}
	return best_pick


func _find_floor_handle_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(scene_root, floors)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var best_vertex_pick: Dictionary = {}
	var best_vertex_camera_distance := INF
	var best_edge_pick: Dictionary = {}
	var best_edge_camera_distance := INF
	for floor in floors:
		if !is_instance_valid(floor):
			continue
		if floor == m_floor_preview or floor.has_meta(Floor3DScript.PREVIEW_META):
			continue
		if floor.has_any_floor_holes():
			continue
		var parent_3d := floor.get_parent() as Node3D
		var local_origin := parent_3d.to_local(ray_origin) if parent_3d != null else ray_origin
		var local_direction := (
			parent_3d.global_transform.basis.inverse() * ray_direction
			if parent_3d != null
			else ray_direction
		)
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()
		if absf(local_direction.y) <= 0.001:
			continue
		var plane_distance := (floor.start_point.y - local_origin.y) / local_direction.y
		if plane_distance <= 0.0:
			continue
		var parent_hit := local_origin + local_direction * plane_distance
		var plan_hit := Vector2(parent_hit.x, parent_hit.z)
		var points := _get_floor_edit_points(floor)
		var radius := maxf(_active_floor_grid_step(floor) * 0.35, 0.16)
		var global_hit := (
			parent_3d.to_global(parent_hit)
			if parent_3d != null
			else parent_hit
		)
		var camera_distance := ray_origin.distance_to(global_hit)
		var closest_vertex_index := -1
		var closest_vertex_distance := INF
		for vertex_index in range(points.size()):
			var vertex_plan := Vector2(points[vertex_index].x, points[vertex_index].z)
			var vertex_distance := plan_hit.distance_to(vertex_plan)
			if vertex_distance < closest_vertex_distance:
				closest_vertex_distance = vertex_distance
				closest_vertex_index = vertex_index
		if (
			closest_vertex_index >= 0
			and closest_vertex_distance <= radius
			and camera_distance < best_vertex_camera_distance
		):
			best_vertex_camera_distance = camera_distance
			best_vertex_pick = {
				"floor": floor,
				"edit_mask": FLOOR_EDIT_POLYGON_VERTEX,
				"vertex_index": closest_vertex_index,
				"edge_index": -1,
				"parent_position": points[closest_vertex_index],
			}

		var closest_edge_index := -1
		var closest_edge_distance := INF
		var closest_edge_point := Vector2.ZERO
		for edge_index in range(points.size()):
			var edge_start := Vector2(points[edge_index].x, points[edge_index].z)
			var edge_end_point := points[(edge_index + 1) % points.size()]
			var edge_end := Vector2(edge_end_point.x, edge_end_point.z)
			var edge_point := m_context.closest_point_on_plan_segment(plan_hit, edge_start, edge_end)
			var edge_distance := plan_hit.distance_to(edge_point)
			if edge_distance < closest_edge_distance:
				closest_edge_distance = edge_distance
				closest_edge_index = edge_index
				closest_edge_point = edge_point
		if (
			closest_edge_index >= 0
			and closest_edge_distance <= radius
			and camera_distance < best_edge_camera_distance
		):
			best_edge_camera_distance = camera_distance
			best_edge_pick = {
				"floor": floor,
				"edit_mask": FLOOR_EDIT_POLYGON_EDGE,
				"vertex_index": -1,
				"edge_index": closest_edge_index,
				"parent_position": Vector3(
					closest_edge_point.x,
					floor.start_point.y,
					closest_edge_point.y
				),
			}
	if (
		!best_vertex_pick.is_empty()
		and (
			best_edge_pick.is_empty()
			or best_vertex_camera_distance <= best_edge_camera_distance + 0.01
		)
	):
		return best_vertex_pick
	return best_edge_pick


func _raycast_floors(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(scene_root, floors)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for floor in floors:
		if !is_instance_valid(floor) or floor == m_floor_preview:
			continue
		if floor.has_meta(Floor3DScript.PREVIEW_META):
			continue
		var hit := _intersect_floor_box(floor, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_floors(node: Node, floors: Array[Floor3DScript]) -> void:
	if node is Floor3DScript:
		floors.append(node as Floor3DScript)
	for child in node.get_children():
		_collect_scene_floors(child, floors)


func _intersect_floor_box(
	floor: Floor3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var size := floor.get_floor_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return {}
	var inverse_frame := floor.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var min_corner := Vector3(0.0, -floor.floor_thickness, 0.0)
	var max_corner := Vector3(size.x, 0.0, size.y)
	var hit := m_context.intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
	if hit.is_empty():
		return {}

	var local_hit := Vector3(hit["position"])
	if !floor.contains_local_plan_point(Vector2(local_hit.x, local_hit.z)):
		return {}
	if floor.has_floor_hole_at_local_point(Vector2(local_hit.x, local_hit.z)):
		return {}
	var local_normal := m_context.nearest_box_normal(local_hit, min_corner, max_corner)
	var global_hit := floor.global_transform * local_hit
	return {
		"floor": floor,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (floor.global_transform.basis * local_normal).normalized(),
		"collider": floor,
		"distance": origin.distance_to(global_hit),
	}


func _floor_edit_mask_for_local_hit(floor: Floor3DScript, local_hit: Vector3) -> int:
	if floor.has_any_floor_holes():
		return FLOOR_EDIT_MOVE
	if floor.is_polygon_floor():
		return FLOOR_EDIT_MOVE
	var size := floor.get_floor_size()
	var radius := maxf(_active_floor_grid_step(floor) * 0.35, 0.16)
	var edit_mask := FLOOR_EDIT_MOVE
	var min_x_distance := absf(local_hit.x)
	var max_x_distance := absf(size.x - local_hit.x)
	if minf(min_x_distance, max_x_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_X if min_x_distance <= max_x_distance else FLOOR_EDIT_MAX_X
	var min_z_distance := absf(local_hit.z)
	var max_z_distance := absf(size.y - local_hit.z)
	if minf(min_z_distance, max_z_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_Z if min_z_distance <= max_z_distance else FLOOR_EDIT_MAX_Z
	return edit_mask


func _update_floor_hover(floor: Floor3DScript, edit_mask: int) -> void:
	if floor == m_drag_floor_hover and edit_mask == m_drag_floor_hover_edit_mask:
		return
	_clear_floor_hover()
	if floor == null:
		return
	m_drag_floor_hover = floor
	m_drag_floor_hover_edit_mask = edit_mask
	m_drag_floor_hover_material = floor.material_override
	floor.material_override = m_context.build_preview_material(_floor_drag_color(edit_mask, true))


func _clear_floor_hover() -> void:
	if m_drag_floor_hover == null:
		return
	if is_instance_valid(m_drag_floor_hover):
		m_drag_floor_hover.material_override = m_drag_floor_hover_material
	m_drag_floor_hover = null
	m_drag_floor_hover_material = null
	m_drag_floor_hover_edit_mask = FLOOR_EDIT_MOVE


func _clear_floor_preview() -> void:
	if m_floor_preview != null and is_instance_valid(m_floor_preview):
		m_floor_preview.queue_free()
	m_floor_preview = null


func _reset_floor_drawing_state() -> void:
	m_is_drawing_floor = false
	m_floor_has_valid_preview = false
	m_floor_release_commits_preview = false
	m_floor_start_screen_position = Vector2.ZERO
	m_floor_polygon_points = PackedVector3Array()


func _is_floor_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_floor_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _is_valid_floor_polygon(points: PackedVector3Array) -> bool:
	if points.size() < 3:
		return false
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(point.x, point.z))
	return !Geometry2D.triangulate_polygon(polygon).is_empty()


func _rectangle_floor_points(local_start: Vector3, local_end: Vector3) -> PackedVector3Array:
	var min_x := minf(local_start.x, local_end.x)
	var max_x := maxf(local_start.x, local_end.x)
	var min_z := minf(local_start.z, local_end.z)
	var max_z := maxf(local_start.z, local_end.z)
	var base_y := local_start.y
	return PackedVector3Array([
		Vector3(min_x, base_y, min_z),
		Vector3(max_x, base_y, min_z),
		Vector3(max_x, base_y, max_z),
		Vector3(min_x, base_y, max_z),
	])


func _get_floor_edit_points(floor: Floor3DScript) -> PackedVector3Array:
	if floor.is_polygon_floor():
		return floor.get_floor_polygon()
	return _rectangle_floor_points(floor.start_point, floor.end_point)

