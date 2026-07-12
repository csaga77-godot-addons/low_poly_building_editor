@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Roof tool controller — owns the roof dock settings, rectangle/polygon
## draw previews, Enter-to-close and R-rotation key handling, covered-region
## bookkeeping, hover-edit picks, and vertex/edge/body drag editing (stage 5
## of the plugin split). Undo/redo actions bind this plugin-lifetime
## controller, the context, or the edited nodes.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")
const FlatRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/flat_roof_3d.gd"
)
const RoofStyleGeometryFactory := preload(
	"res://addons/low_poly_building_editor/roofs/roof_style_geometry_factory_3d.gd"
)

var m_roof_settings := {
	"grid_step": 0.5,
	"style": "gable",
	"footprint_style": FLOOR_STYLE_RECTANGLE,
	"base_height": 2.4,
	"height": 40.0,
	"thickness": 0.12,
	"overhang": 0.2,
	"hip_gable_height": 0.0,
	"hip_shape": 0,
	"rotation_degrees": 0.0,
	"color": Color(0.50, 0.34, 0.25, 1.0),
}
var m_roof_start_local := Vector3.ZERO
var m_roof_end_local := Vector3.ZERO
var m_roof_start_screen_position := Vector2.ZERO
var m_roof_has_valid_preview := false
var m_roof_release_commits_preview := false
var m_roof_draw_rotation_degrees := 0.0
var m_is_drawing_roof := false
var m_roof_preview: Roof3DScript
var m_roof_polygon_points := PackedVector3Array()
var m_dragging_roof: Roof3DScript
var m_drag_roof_old_start := Vector3.ZERO
var m_drag_roof_old_end := Vector3.ZERO
var m_drag_roof_old_polygon := PackedVector3Array()
var m_drag_roof_started_as_polygon := false
var m_drag_roof_vertex_index := -1
var m_drag_roof_edge_index := -1
var m_drag_roof_old_rotation_degrees := 0.0
var m_drag_roof_old_height := 0.0
var m_drag_roof_old_covered_rects: Array[Rect2] = []
var m_drag_roof_old_covered_polygons: Array[PackedVector2Array] = []
var m_drag_roof_anchor_local := Vector3.ZERO
var m_drag_roof_plane_y := 0.0
var m_drag_roof_edit_mask := FLOOR_EDIT_MOVE
var m_drag_roof_active_material: Material
var m_drag_roof_hover: Roof3DScript
var m_drag_roof_hover_material: Material
var m_drag_roof_hover_edit_mask := FLOOR_EDIT_MOVE


func apply_settings(settings: Dictionary) -> void:
	m_roof_settings = settings.duplicate(true)
	_clear_roof_preview()


func cancel_preview() -> void:
	_cancel_roof_drag()
	_clear_roof_hover()
	_clear_roof_preview()
	_reset_roof_drawing_state()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and !key_event.echo:
			if (
				(key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER)
				and _is_polygon_roof_mode()
				and m_is_drawing_roof
			):
				_finish_polygon_roof()
				return m_context.handled()
			if key_event.keycode == KEY_R:
				return _handle_roof_rotation_key(key_event)
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	return _handle_roof_input(camera, event)


func _handle_roof_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_roof != null:
		return _handle_roof_drag_input(camera, event)
	if _is_polygon_roof_mode():
		return _handle_polygon_roof_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_roof:
			_update_roof_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_roof_start_screen_position) >= DRAG_COMMIT_DISTANCE:
				m_roof_release_commits_preview = true
			return m_context.handled()
		var roof_pick := _find_roof_edit_pick(camera, mouse_motion.position)
		var hover_roof := roof_pick.get("roof") as Roof3DScript
		var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_roof_hover(hover_roof, edit_mask)
		if hover_roof != null:
			_set_roof_edit_hover_status(hover_roof, edit_mask)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_roof:
		if !m_roof_release_commits_preview:
			m_context.set_status("Click the opposite corner to place roof, or drag from the first corner and release.")
			return m_context.handled()
		var release_coordinator := _get_active_roof_coordinator()
		if release_coordinator != null:
			var release_end := m_roof_end_local
			if !m_roof_has_valid_preview:
				release_end = _roof_draw_local_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_roof(release_coordinator, m_roof_start_local, release_end, m_roof_draw_rotation_degrees)
		_clear_roof_preview()
		_reset_roof_drawing_state()
		return m_context.handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_roof:
		var roof_pick := _find_roof_edit_pick(camera, mouse_button.position)
		if _begin_roof_edit_from_pick(camera, mouse_button, roof_pick):
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing roofs.")
		return m_context.handled()

	var snapped_local := _roof_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_roof:
		m_roof_start_local = snapped_local
		m_roof_end_local = snapped_local
		m_roof_start_screen_position = mouse_button.position
		m_roof_has_valid_preview = false
		m_roof_release_commits_preview = false
		m_roof_draw_rotation_degrees = normalize_degrees(float(m_roof_settings.get("rotation_degrees", 0.0)))
		m_is_drawing_roof = true
		_create_roof_preview(coordinator)
		_update_roof_preview(camera, mouse_button.position)
		m_context.set_status("Roof first corner captured. Drag and release, or click the opposite corner.")
		return m_context.handled()

	_commit_roof(coordinator, m_roof_start_local, snapped_local, m_roof_draw_rotation_degrees)
	_clear_roof_preview()
	_reset_roof_drawing_state()
	return m_context.handled()


func _handle_polygon_roof_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_roof:
			_update_polygon_roof_preview(camera, mouse_motion.position)
			return m_context.handled()
		var roof_pick := _find_roof_edit_pick(camera, mouse_motion.position)
		var hover_roof := roof_pick.get("roof") as Roof3DScript
		var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_roof_hover(hover_roof, edit_mask)
		if hover_roof != null:
			_set_roof_edit_hover_status(hover_roof, edit_mask)
		else:
			m_context.set_status("Click the first Flat roof polygon vertex.")
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_roof:
		var roof_pick := _find_roof_edit_pick(camera, mouse_button.position)
		if _begin_roof_edit_from_pick(camera, mouse_button, roof_pick):
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing roofs.")
		return m_context.handled()
	var snapped_local := _roof_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_roof:
		m_is_drawing_roof = true
		m_roof_polygon_points = PackedVector3Array([snapped_local])
		m_roof_draw_rotation_degrees = 0.0
		_create_roof_preview(coordinator)
		_update_polygon_roof_preview(camera, mouse_button.position)
		m_context.set_status("Roof polygon vertex 1 captured. Click more vertices, then click the first vertex or press Enter.")
		return m_context.handled()

	if (
		m_roof_polygon_points.size() >= 3
		and snapped_local.distance_to(m_roof_polygon_points[0])
			<= maxf(float(m_roof_settings["grid_step"]) * 0.25, 0.05)
	):
		_finish_polygon_roof()
		return m_context.handled()
	m_roof_polygon_points.append(snapped_local)
	_update_polygon_roof_preview(camera, mouse_button.position)
	m_context.set_status(
		"Roof polygon vertex %d captured. Click the first vertex or press Enter to close."
		% m_roof_polygon_points.size()
	)
	return m_context.handled()


func _update_polygon_roof_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_roof_preview == null:
		return
	var coordinator := m_roof_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var hover_point := _roof_draw_local_from_mouse(coordinator, camera, mouse_position)
	var preview_points := m_roof_polygon_points.duplicate()
	if preview_points.is_empty() or !preview_points[preview_points.size() - 1].is_equal_approx(hover_point):
		preview_points.append(hover_point)
	_set_roof_polygon(m_roof_preview, preview_points)
	m_roof_has_valid_preview = _is_valid_roof_polygon(preview_points)


func _finish_polygon_roof() -> void:
	var coordinator := _get_active_roof_coordinator()
	if coordinator == null or !_is_valid_roof_polygon(m_roof_polygon_points):
		m_context.set_status("A roof polygon needs at least three non-intersecting vertices.")
		return
	_commit_roof_polygon(coordinator, m_roof_polygon_points)
	_clear_roof_preview()
	_reset_roof_drawing_state()


func _commit_roof_polygon(
	coordinator: Building3DScript,
	local_points: PackedVector3Array
) -> void:
	if !_is_valid_roof_polygon(local_points):
		m_context.set_status("Flat roof polygon is invalid.")
		return
	var bounds := _roof_polygon_parent_bounds(local_points)
	var local_start := Vector3(bounds.position.x, local_points[0].y, bounds.position.y)
	var local_end := Vector3(bounds.end.x, local_points[0].y, bounds.end.y)
	var merge := coordinator.find_roof_merge_target(
		local_start,
		local_end,
			RoofStyleGeometryFactory.STYLE_FLAT,
		0.0,
		float(m_roof_settings["thickness"]),
		float(m_roof_settings["overhang"]),
		Color(m_roof_settings["color"]),
		0.0,
		m_roof_preview
	)
	var roof := BuildingFactoryScript.create_flat_roof_polygon_node(
		coordinator,
		local_points,
		float(m_roof_settings["thickness"]),
		float(m_roof_settings["overhang"]),
		Color(m_roof_settings["color"])
	)
	var covered_rects := _roof_covered_rects_from_regions(merge)
	var covered_polygons := _roof_covered_polygons_from_regions(merge)
	if !covered_rects.is_empty() or !covered_polygons.is_empty():
		roof.set_covered_regions(covered_rects, covered_polygons)
	if !roof.has_visible_roof_geometry():
		m_context.set_status("Flat roof polygon is fully covered by overlapping roof geometry.")
		return
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Polygon Flat Roof")
	undo_redo.add_do_reference(roof)
	undo_redo.add_do_method(
		m_context,
		"do_add_node_and_refresh_roofs",
		coordinator,
		roof,
		scene_root,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		m_context,
		"undo_remove_node_and_refresh_roofs",
		coordinator,
		roof,
		coordinator
	)
	undo_redo.commit_action()
	m_context.set_status("Created Flat roof polygon: %d vertices." % local_points.size())


func _create_roof_preview(coordinator: Building3DScript) -> void:
	_clear_roof_preview()
	m_roof_preview = BuildingFactoryScript.instantiate_roof_style(String(m_roof_settings["style"]))
	m_roof_preview.name = "RoofPreview"
	m_roof_preview.set_meta(Roof3DScript.PREVIEW_META, true)
	BuildingFactoryScript.configure_roof_style(
		m_roof_preview,
		float(m_roof_settings["height"]),
		float(m_roof_settings.get("hip_gable_height", 0.0)),
		int(m_roof_settings.get("hip_shape", 0))
	)
	m_roof_preview.roof_thickness = float(m_roof_settings["thickness"])
	m_roof_preview.roof_overhang = float(m_roof_settings["overhang"])
	m_roof_preview.roof_rotation_degrees = m_roof_draw_rotation_degrees
	var preview_color := Color(m_roof_settings["color"])
	preview_color.a = 0.46
	m_roof_preview.roof_color = preview_color
	m_roof_preview.generate_collision = false
	coordinator.add_child(m_roof_preview)
	m_roof_preview.owner = null
	m_context.apply_debug_wireframe_to_node(m_roof_preview)


func _update_roof_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_roof_preview == null:
		return
	var coordinator := m_roof_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var selected_style := String(m_roof_settings["style"])
	if m_roof_preview.get_roof_style() != selected_style:
		_create_roof_preview(coordinator)
		if m_roof_preview == null:
			return
	var local_end := _roof_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_roof_end_local = local_end
	var roof_points := Roof3DScript.roof_corners_from_base_points(
		m_roof_start_local,
		local_end,
		m_roof_draw_rotation_degrees
	)
	var roof_start := Vector3(roof_points["start"])
	var roof_end := Vector3(roof_points["end"])
	m_roof_has_valid_preview = _is_roof_span_large_enough(roof_start, roof_end)
	BuildingFactoryScript.configure_roof_style(
		m_roof_preview,
		float(m_roof_settings["height"]),
		float(m_roof_settings.get("hip_gable_height", 0.0)),
		int(m_roof_settings.get("hip_shape", 0))
	)
	m_roof_preview.roof_thickness = float(m_roof_settings["thickness"])
	m_roof_preview.roof_overhang = float(m_roof_settings["overhang"])
	m_roof_preview.set_roof_corners_and_rotation(roof_start, roof_end, m_roof_draw_rotation_degrees)
	if m_roof_has_valid_preview:
		var size := m_roof_preview.get_roof_size()
		m_context.set_status(
			"Release or click to place roof: %.2f x %.2f, %.0f deg." %
			[size.x, size.y, m_roof_draw_rotation_degrees]
		)


func _roof_base_height() -> float:
	return float(m_roof_settings.get("base_height", 2.4))


func _is_polygon_roof_mode() -> bool:
	return (
			String(m_roof_settings.get("style", "")) == RoofStyleGeometryFactory.STYLE_FLAT
		and String(m_roof_settings.get("footprint_style", FLOOR_STYLE_RECTANGLE))
			== FLOOR_STYLE_POLYGON
	)


func _roof_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _roof_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_roof_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := m_context.raycast_world(camera, mouse_position, false)
	return _snap_roof_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_roof_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_roof_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _get_active_roof_coordinator() -> Building3DScript:
	if m_roof_preview != null and is_instance_valid(m_roof_preview):
		var preview_parent := m_roof_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return m_context.get_or_create_coordinator(false)


func _handle_roof_rotation_key(key_event: InputEventKey) -> int:
	var delta := -90.0 if key_event.shift_pressed else 90.0
	if m_is_drawing_roof:
		m_roof_draw_rotation_degrees = normalize_degrees(m_roof_draw_rotation_degrees + delta)
		if m_roof_preview != null and is_instance_valid(m_roof_preview):
			var roof_points := Roof3DScript.roof_corners_from_base_points(
				m_roof_start_local,
				m_roof_end_local,
				m_roof_draw_rotation_degrees
			)
			m_roof_preview.set_roof_corners_and_rotation(
				Vector3(roof_points["start"]),
				Vector3(roof_points["end"]),
				m_roof_draw_rotation_degrees
			)
		m_context.set_status("Roof preview rotation: %.0f degrees." % m_roof_draw_rotation_degrees)
		return m_context.handled()

	if m_dragging_roof != null:
		m_context.set_status("Release the roof edit before rotating.")
		return m_context.handled()

	var roof := m_drag_roof_hover if is_instance_valid(m_drag_roof_hover) else _selected_roof_for_rotation()
	if roof == null:
		m_context.set_status("Hover or select a roof to rotate it.")
		return m_context.handled()
	if _is_polygon_roof(roof):
		m_context.set_status("Polygon Flat roofs rotate by dragging their vertices or edges.")
		return m_context.handled()
	_commit_roof_rotation(roof, delta)
	return m_context.handled()


func _selected_roof_for_rotation() -> Roof3DScript:
	var selection := m_context.editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		if node is Roof3DScript:
			return node as Roof3DScript
	return null


func _commit_roof_rotation(roof: Roof3DScript, delta_degrees: float) -> void:
	if roof == null or !is_instance_valid(roof):
		return
	var old_start := roof.start_point
	var old_end := roof.end_point
	var old_rotation := roof.roof_rotation_degrees
	var old_height := _roof_angle_degrees(roof)
	var old_covered_rects := roof.get_covered_rects()
	var old_covered_polygons := roof.get_covered_polygons()
	var new_rotation := normalize_degrees(old_rotation + delta_degrees)
	var rotated_state := _roof_state_rotated_around_center(roof, new_rotation)
	var new_start := Vector3(rotated_state["start"])
	var new_end := Vector3(rotated_state["end"])
	var new_covered_rects: Array[Rect2] = []
	var new_covered_polygons: Array[PackedVector2Array] = []
	var coordinator := m_context.find_coordinator_from_node(roof)
	if coordinator != null:
		var cover_regions := coordinator.compute_roof_cover_regions(
			new_start,
			new_end,
			roof.get_roof_style(),
			_roof_angle_degrees(roof),
			roof.roof_thickness,
			roof.roof_overhang,
			roof.roof_color,
			new_rotation,
			roof,
			true,
			_roof_hip_gable_height(roof),
			_roof_hip_shape(roof)
		)
		new_covered_rects = _roof_covered_rects_from_regions(cover_regions)
		new_covered_polygons = _roof_covered_polygons_from_regions(cover_regions)
		if !coordinator.roof_has_visible_cover_area(
			new_start,
			new_end,
			roof.roof_overhang,
			new_covered_rects,
			new_covered_polygons
		):
			m_context.set_status("Rotated roof would be fully covered.")
			return
		if _roof_layout_would_hide_any_roof(
			coordinator,
			roof,
			new_start,
			new_end,
			new_rotation,
			old_height,
			new_covered_rects,
			new_covered_polygons
		):
			m_context.set_status("Rotated roof would fully cover another roof.")
			return
	_clear_roof_hover()

	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Rotate Roof")
	undo_redo.add_do_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		new_start,
		new_end,
		new_rotation,
		old_height,
		new_covered_rects,
		new_covered_polygons,
		coordinator
	)
	undo_redo.add_do_method(m_context, "select_node", roof)
	undo_redo.add_undo_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		old_start,
		old_end,
		old_rotation,
		old_height,
		old_covered_rects,
		old_covered_polygons,
		coordinator
	)
	undo_redo.commit_action()
	m_context.set_status("Rotated roof to %.0f degrees." % new_rotation)


func _roof_state_rotated_around_center(roof: Roof3DScript, rotation_degrees: float) -> Dictionary:
	var size := roof.get_roof_size()
	var center := roof.get_roof_center_point()
	var anchor := center - _roof_rotation_basis(rotation_degrees) * Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	return {
		"start": anchor,
		"end": anchor + Vector3(size.x, 0.0, size.y),
	}


func _commit_roof(
	coordinator: Building3DScript,
	draw_start: Vector3,
	draw_end: Vector3,
	rotation_degrees: float
) -> void:
	var roof_points := Roof3DScript.roof_corners_from_base_points(draw_start, draw_end, rotation_degrees)
	var local_start := Vector3(roof_points["start"])
	var local_end := Vector3(roof_points["end"])
	if !_is_roof_span_large_enough(local_start, local_end):
		m_context.set_status("Roof is too small.")
		return

	var style := String(m_roof_settings["style"])
	var height := float(m_roof_settings["height"])
	var thickness := float(m_roof_settings["thickness"])
	var overhang := float(m_roof_settings["overhang"])
	var hip_gable_height := float(m_roof_settings.get("hip_gable_height", 0.0))
	var hip_shape := int(m_roof_settings.get("hip_shape", 0))
	var color := Color(m_roof_settings["color"])
	var normalized_rotation := normalize_degrees(rotation_degrees)
	var merge := coordinator.find_roof_merge_target(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		normalized_rotation,
		m_roof_preview,
		hip_gable_height,
		hip_shape
	)
	var covered_rects := _roof_covered_rects_from_regions(merge)
	var covered_polygons := _roof_covered_polygons_from_regions(merge)

	var roof := BuildingFactoryScript.create_roof_node(coordinator,
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		normalized_rotation,
		hip_gable_height,
		hip_shape
	)
	if !covered_rects.is_empty() or !covered_polygons.is_empty():
		roof.set_covered_regions(covered_rects, covered_polygons)
	if !roof.has_visible_roof_geometry():
		m_context.set_status("Roof is fully covered by overlapping roof geometry.")
		return
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Roof")
	undo_redo.add_do_reference(roof)
	undo_redo.add_do_method(m_context, "do_add_node_and_refresh_roofs", coordinator, roof, scene_root, true, coordinator)
	undo_redo.add_undo_method(m_context, "undo_remove_node_and_refresh_roofs", coordinator, roof, coordinator)
	undo_redo.commit_action()
	var size := roof.get_roof_size()
	if covered_rects.is_empty():
		m_context.set_status("Created roof: %.2f x %.2f units." % [size.x, size.y])
	else:
		m_context.set_status("Created clipped roof: %.2f x %.2f units." % [size.x, size.y])


func _set_roof_edit_hover_status(roof: Roof3DScript, edit_mask: int) -> void:
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		m_context.set_status("Drag roof vertex to reshape. Option/Alt-click it to remove.")
	elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		m_context.set_status("Drag roof edge to reshape. Shift-click it to add a vertex.")
	elif _is_polygon_roof(roof):
		m_context.set_status("Drag roof body to move it.")
	else:
		m_context.set_status(
			"Drag roof corner to resize." if _roof_edit_mask_is_corner(edit_mask)
			else "Drag roof edge to resize." if edit_mask != FLOOR_EDIT_MOVE
			else "Drag roof body to move."
		)


func _begin_roof_edit_from_pick(
	camera: Camera3D,
	mouse_button: InputEventMouseButton,
	roof_pick: Dictionary
) -> bool:
	var roof := roof_pick.get("roof") as Roof3DScript
	if roof == null:
		return false
	_clear_roof_hover()
	var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
	var vertex_index := int(roof_pick.get("vertex_index", -1))
	var edge_index := int(roof_pick.get("edge_index", -1))
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX and mouse_button.alt_pressed:
		_remove_roof_vertex(roof, vertex_index)
		return true
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE and mouse_button.shift_pressed:
		_add_roof_vertex(
			roof,
			edge_index,
			Vector3(roof_pick.get("parent_position", roof.start_point))
		)
		return true
	_start_roof_drag(
		roof,
		camera,
		mouse_button.position,
		edit_mask,
		vertex_index,
		edge_index
	)
	return true


func _add_roof_vertex(
	roof: Roof3DScript,
	edge_index: int,
	parent_position: Vector3
) -> void:
	if roof.get_roof_style() != RoofStyleGeometryFactory.STYLE_FLAT:
		return
	var old_points := _get_roof_edit_points(roof)
	if edge_index < 0 or edge_index >= old_points.size():
		m_context.set_status("No roof edge selected.")
		return
	var new_point := _snap_roof_edit_point(roof, parent_position)
	var edge_start := old_points[edge_index]
	var edge_end := old_points[(edge_index + 1) % old_points.size()]
	if new_point.distance_to(edge_start) <= 0.001 or new_point.distance_to(edge_end) <= 0.001:
		m_context.set_status("New vertex must be between two existing roof vertices.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		new_points.append(old_points[index])
		if index == edge_index:
			new_points.append(new_point)
	if !_is_valid_roof_polygon(new_points):
		m_context.set_status("That point would make an invalid roof polygon.")
		return
	_commit_roof_points(roof, old_points, new_points, "Add Roof Vertex", "Added roof vertex.")


func _remove_roof_vertex(roof: Roof3DScript, vertex_index: int) -> void:
	if roof.get_roof_style() != RoofStyleGeometryFactory.STYLE_FLAT:
		return
	var old_points := _get_roof_edit_points(roof)
	if old_points.size() <= 3:
		m_context.set_status("A roof must keep at least three vertices.")
		return
	if vertex_index < 0 or vertex_index >= old_points.size():
		m_context.set_status("No roof vertex selected.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		if index != vertex_index:
			new_points.append(old_points[index])
	if !_is_valid_roof_polygon(new_points):
		m_context.set_status("Removing that vertex would make an invalid roof polygon.")
		return
	_commit_roof_points(roof, old_points, new_points, "Remove Roof Vertex", "Removed roof vertex.")


func _commit_roof_points(
	roof: Roof3DScript,
	old_points: PackedVector3Array,
	new_points: PackedVector3Array,
	action_name: String,
	status: String
) -> void:
	var coordinator := m_context.find_coordinator_from_node(roof)
	var started_as_polygon := _is_polygon_roof(roof)
	var old_start := roof.start_point
	var old_end := roof.end_point
	var old_rotation := roof.roof_rotation_degrees
	var old_height := _roof_angle_degrees(roof)
	var old_covered_rects := roof.get_covered_rects()
	var old_covered_polygons := roof.get_covered_polygons()
	_set_roof_polygon(roof, new_points)
	var layout_valid := true
	if coordinator != null:
		coordinator.refresh_roof_covered_rects()
		for roof_node in coordinator.get_roof_nodes():
			if roof_node.has_meta(Roof3DScript.PREVIEW_META):
				continue
			if !roof_node.has_visible_roof_geometry():
				layout_valid = false
				break
	if started_as_polygon:
		_set_roof_polygon(roof, old_points)
		roof.set_covered_regions(old_covered_rects, old_covered_polygons)
	else:
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
	if coordinator != null:
		coordinator.refresh_building_geometry_clips()
	if !layout_valid:
		m_context.set_status("Roof edit would fully cover a roof.")
		return
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(self, "_set_roof_polygon_and_refresh", roof, new_points, coordinator)
	undo_redo.add_do_method(m_context, "select_node", roof)
	if started_as_polygon:
		undo_redo.add_undo_method(self, "_set_roof_polygon_and_refresh", roof, old_points, coordinator)
	else:
		undo_redo.add_undo_method(
			self,
			"_set_roof_state_and_refresh",
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons,
			coordinator
		)
	undo_redo.commit_action()
	m_context.set_status(status)


func _set_roof_polygon_and_refresh(
	roof: Roof3DScript,
	points: PackedVector3Array,
	coordinator: Building3DScript
) -> void:
	_set_roof_polygon(roof, points)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func _handle_roof_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_roof_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_roof_drag()
			return m_context.handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_roof_drag()
			return m_context.handled()
	return m_context.handled()


func _start_roof_drag(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int,
	vertex_index: int = -1,
	edge_index: int = -1
) -> void:
	m_dragging_roof = roof
	m_drag_roof_old_start = roof.start_point
	m_drag_roof_old_end = roof.end_point
	m_drag_roof_old_polygon = _get_roof_edit_points(roof)
	m_drag_roof_started_as_polygon = _is_polygon_roof(roof)
	m_drag_roof_old_rotation_degrees = roof.roof_rotation_degrees
	m_drag_roof_old_height = _roof_angle_degrees(roof)
	m_drag_roof_old_covered_rects = roof.get_covered_rects()
	m_drag_roof_old_covered_polygons = roof.get_covered_polygons()
	m_drag_roof_edit_mask = edit_mask
	if vertex_index >= 0:
		m_drag_roof_edit_mask = FLOOR_EDIT_POLYGON_VERTEX
	elif edge_index >= 0:
		m_drag_roof_edit_mask = FLOOR_EDIT_POLYGON_EDGE
	elif _is_polygon_roof(roof):
		m_drag_roof_edit_mask = FLOOR_EDIT_MOVE
	m_drag_roof_vertex_index = (
		vertex_index if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_VERTEX else -1
	)
	m_drag_roof_edge_index = (
		edge_index if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_EDGE else -1
	)
	m_drag_roof_active_material = roof.material_override
	m_drag_roof_plane_y = _roof_drag_plane_y_from_mouse(roof, camera, mouse_pos)
	m_drag_roof_anchor_local = _roof_plane_local_from_mouse_at_y(roof, camera, mouse_pos, m_drag_roof_plane_y)
	roof.material_override = m_context.build_preview_material(_roof_drag_color(m_drag_roof_edit_mask, true))
	m_context.select_node(roof)
	m_context.set_status(
		"Dragging roof %s - release to commit, Escape to cancel."
		% _roof_edit_label(m_drag_roof_edit_mask)
	)


func _update_roof_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_roof == null or !is_instance_valid(m_dragging_roof):
		_reset_roof_drag_state()
		return
	var roof := m_dragging_roof
	var hit_local := _roof_plane_local_from_mouse_at_y(roof, camera, mouse_pos, m_drag_roof_plane_y)
	var new_start := m_drag_roof_old_start
	var new_end := m_drag_roof_old_end
	if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		var edited_polygon := m_drag_roof_old_polygon.duplicate()
		if m_drag_roof_vertex_index < 0 or m_drag_roof_vertex_index >= edited_polygon.size():
			return
		edited_polygon[m_drag_roof_vertex_index] = _snap_roof_edit_point(roof, hit_local)
		var valid := _is_valid_roof_polygon(edited_polygon)
		if valid:
			_set_roof_polygon(roof, edited_polygon)
			roof.set_covered_regions([], [])
			m_context.set_status("Release to commit roof vertex position.")
		else:
			m_context.set_status("That position would make the roof invalid.")
		roof.material_override = m_context.build_preview_material(
			_roof_drag_color(FLOOR_EDIT_POLYGON_VERTEX, valid)
		)
		return
	if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		var edited_polygon := m_drag_roof_old_polygon.duplicate()
		if m_drag_roof_edge_index < 0 or m_drag_roof_edge_index >= edited_polygon.size():
			return
		var step := _active_roof_grid_step(roof)
		var raw_delta := hit_local - m_drag_roof_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var next_edge_index := (m_drag_roof_edge_index + 1) % edited_polygon.size()
		edited_polygon[m_drag_roof_edge_index] += snapped_delta
		edited_polygon[next_edge_index] += snapped_delta
		var valid := _is_valid_roof_polygon(edited_polygon)
		if valid:
			_set_roof_polygon(roof, edited_polygon)
			roof.set_covered_regions([], [])
			m_context.set_status("Release to commit roof edge position.")
		else:
			m_context.set_status("That position would make the roof invalid.")
		roof.material_override = m_context.build_preview_material(
			_roof_drag_color(FLOOR_EDIT_POLYGON_EDGE, valid)
		)
		return
	if _is_polygon_roof(roof):
		var step := _active_roof_grid_step(roof)
		var raw_delta := hit_local - m_drag_roof_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var moved_polygon := PackedVector3Array()
		for point in m_drag_roof_old_polygon:
			moved_polygon.append(point + snapped_delta)
		_set_roof_polygon(roof, moved_polygon)
		roof.set_covered_regions([], [])
		roof.material_override = m_context.build_preview_material(
			_roof_drag_color(FLOOR_EDIT_MOVE, true)
		)
		m_context.set_status("Release to commit polygon roof move.")
		return
	if m_drag_roof_edit_mask == FLOOR_EDIT_MOVE:
		var step := _active_roof_grid_step(roof)
		var raw_delta := hit_local - m_drag_roof_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start = m_drag_roof_old_start + snapped_delta
		new_end = m_drag_roof_old_end + snapped_delta
	else:
		var roof_local := _roof_edit_local_from_parent_position(hit_local)
		var resized := _resized_roof_points(roof, roof_local)
		new_start = Vector3(resized["start"])
		new_end = Vector3(resized["end"])

	var preview_covered_rects: Array[Rect2] = []
	var preview_covered_polygons: Array[PackedVector2Array] = []
	_set_roof_corners_rotation_angle_and_covers(
		roof,
		new_start,
		new_end,
		m_drag_roof_old_rotation_degrees,
		m_drag_roof_old_height,
		preview_covered_rects,
		preview_covered_polygons
	)
	var valid := _is_roof_span_large_enough(new_start, new_end)
	roof.material_override = m_context.build_preview_material(
		_roof_drag_color(m_drag_roof_edit_mask, valid)
	)
	if valid:
		var size := roof.get_roof_size()
		m_context.set_status("Release to commit roof %s: %.2f x %.2f." % [_roof_edit_label(m_drag_roof_edit_mask), size.x, size.y])
	else:
		m_context.set_status("Roof is too small.")


func _commit_roof_drag() -> void:
	if m_dragging_roof == null:
		return
	var roof := m_dragging_roof
	if _is_polygon_roof(roof):
		_commit_polygon_roof_drag(roof)
		return
	var old_start := m_drag_roof_old_start
	var old_end := m_drag_roof_old_end
	var old_rotation := m_drag_roof_old_rotation_degrees
	var old_height := m_drag_roof_old_height
	var old_covered_rects := m_drag_roof_old_covered_rects
	var old_covered_polygons := m_drag_roof_old_covered_polygons
	var new_start := roof.start_point
	var new_end := roof.end_point
	var new_rotation := roof.roof_rotation_degrees
	var new_height := _roof_angle_degrees(roof)
	var edit_mask := m_drag_roof_edit_mask
	var coordinator := m_context.find_coordinator_from_node(roof)
	roof.material_override = m_drag_roof_active_material
	if !_is_roof_span_large_enough(new_start, new_end):
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
		if coordinator != null:
			coordinator.refresh_building_geometry_clips()
		_reset_roof_drag_state()
		m_context.set_status("Roof is too small.")
		return
	if (
			old_start.distance_to(new_start) <= 0.001
			and old_end.distance_to(new_end) <= 0.001
			and angles_match(old_rotation, new_rotation)
			and is_equal_approx(old_height, new_height)
	):
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
		if coordinator != null:
			coordinator.refresh_building_geometry_clips()
		_reset_roof_drag_state()
		m_context.set_status("Roof unchanged.")
		return

	var new_covered_rects: Array[Rect2] = []
	var new_covered_polygons: Array[PackedVector2Array] = []
	if coordinator != null:
		var cover_regions := coordinator.compute_roof_cover_regions(
			new_start,
			new_end,
			roof.get_roof_style(),
			new_height,
			roof.roof_thickness,
			roof.roof_overhang,
			roof.roof_color,
			roof.roof_rotation_degrees,
			roof,
			true,
			_roof_hip_gable_height(roof),
			_roof_hip_shape(roof)
		)
		new_covered_rects = _roof_covered_rects_from_regions(cover_regions)
		new_covered_polygons = _roof_covered_polygons_from_regions(cover_regions)
		if !coordinator.roof_has_visible_cover_area(
			new_start,
			new_end,
			roof.roof_overhang,
			new_covered_rects,
			new_covered_polygons
		):
			_set_roof_corners_rotation_angle_and_covers(
				roof,
				old_start,
				old_end,
				old_rotation,
				old_height,
				old_covered_rects,
				old_covered_polygons
			)
			coordinator.refresh_building_geometry_clips()
			_reset_roof_drag_state()
			m_context.set_status("Roof would be fully covered.")
			return
		if _roof_layout_would_hide_any_roof(
			coordinator,
			roof,
			new_start,
			new_end,
			new_rotation,
			new_height,
			new_covered_rects,
			new_covered_polygons
		):
			_set_roof_corners_rotation_angle_and_covers(
				roof,
				old_start,
				old_end,
				old_rotation,
				old_height,
				old_covered_rects,
				old_covered_polygons
			)
			coordinator.refresh_building_geometry_clips()
			_reset_roof_drag_state()
			m_context.set_status("Roof edit would fully cover another roof.")
			return

	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Move Roof" if edit_mask == FLOOR_EDIT_MOVE else "Resize Roof")
	undo_redo.add_do_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons,
		coordinator
	)
	undo_redo.add_do_method(m_context, "select_node", roof)
	undo_redo.add_undo_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		old_start,
		old_end,
		old_rotation,
		old_height,
		old_covered_rects,
		old_covered_polygons,
		coordinator
	)
	undo_redo.commit_action()
	_reset_roof_drag_state()
	var size := roof.get_roof_size()
	if new_covered_rects.is_empty():
		m_context.set_status("Edited roof: %.2f x %.2f units." % [size.x, size.y])
	else:
		m_context.set_status("Edited clipped roof: %.2f x %.2f units." % [size.x, size.y])


func _commit_polygon_roof_drag(roof: Roof3DScript) -> void:
	var new_points := _get_roof_polygon(roof)
	var old_points := m_drag_roof_old_polygon
	var coordinator := m_context.find_coordinator_from_node(roof)
	var edit_mask := m_drag_roof_edit_mask
	roof.material_override = m_drag_roof_active_material
	if !_is_valid_roof_polygon(new_points):
		_restore_roof_drag_start(roof, coordinator)
		_reset_roof_drag_state()
		m_context.set_status("Roof polygon is invalid.")
		return
	if old_points == new_points and m_drag_roof_started_as_polygon:
		_restore_roof_drag_start(roof, coordinator)
		_reset_roof_drag_state()
		m_context.set_status("Roof unchanged.")
		return
	if coordinator != null:
		coordinator.refresh_roof_covered_rects()
		for roof_node in coordinator.get_roof_nodes():
			if roof_node.has_meta(Roof3DScript.PREVIEW_META):
				continue
			if !roof_node.has_visible_roof_geometry():
				_restore_roof_drag_start(roof, coordinator)
				_reset_roof_drag_state()
				m_context.set_status("Roof edit would fully cover a roof.")
				return
	var old_start := m_drag_roof_old_start
	var old_end := m_drag_roof_old_end
	var old_rotation := m_drag_roof_old_rotation_degrees
	var old_height := m_drag_roof_old_height
	var old_covered_rects := m_drag_roof_old_covered_rects
	var old_covered_polygons := m_drag_roof_old_covered_polygons
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action(
		"Move Roof" if edit_mask == FLOOR_EDIT_MOVE
		else "Edit Roof Vertex" if edit_mask == FLOOR_EDIT_POLYGON_VERTEX
		else "Edit Roof Edge"
	)
	undo_redo.add_do_method(self, "_set_roof_polygon_and_refresh", roof, new_points, coordinator)
	undo_redo.add_do_method(m_context, "select_node", roof)
	if m_drag_roof_started_as_polygon:
		undo_redo.add_undo_method(
			self,
			"_set_roof_polygon_and_refresh",
			roof,
			old_points,
			coordinator
		)
	else:
		undo_redo.add_undo_method(
			self,
			"_set_roof_state_and_refresh",
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons,
			coordinator
		)
	undo_redo.commit_action()
	_reset_roof_drag_state()
	m_context.set_status("Edited Flat roof polygon: %d vertices." % new_points.size())


func _restore_roof_drag_start(
	roof: Roof3DScript,
	coordinator: Building3DScript
) -> void:
	if m_drag_roof_started_as_polygon:
		_set_roof_polygon(roof, m_drag_roof_old_polygon)
		roof.set_covered_regions(
			m_drag_roof_old_covered_rects,
			m_drag_roof_old_covered_polygons
		)
	else:
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			m_drag_roof_old_start,
			m_drag_roof_old_end,
			m_drag_roof_old_rotation_degrees,
			m_drag_roof_old_height,
			m_drag_roof_old_covered_rects,
			m_drag_roof_old_covered_polygons
		)
	if coordinator != null:
		coordinator.refresh_building_geometry_clips()


func _cancel_roof_drag() -> void:
	if m_dragging_roof == null:
		return
	var coordinator := m_context.find_coordinator_from_node(m_dragging_roof)
	if is_instance_valid(m_dragging_roof):
		_restore_roof_drag_start(m_dragging_roof, coordinator)
		m_dragging_roof.material_override = m_drag_roof_active_material
	_reset_roof_drag_state()
	m_context.set_status("Roof edit canceled.")


func _resized_roof_points(roof: Roof3DScript, roof_local_hit: Vector3) -> Dictionary:
	var old_size := Vector2(
		absf(m_drag_roof_old_end.x - m_drag_roof_old_start.x),
		absf(m_drag_roof_old_end.z - m_drag_roof_old_start.z)
	)
	var overhang := maxf(roof.roof_overhang, 0.0)
	var min_x := 0.0
	var max_x := old_size.x
	var min_z := 0.0
	var max_z := old_size.y
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MIN_X) != 0:
		min_x = _snap_roof_footprint_edge(roof, roof_local_hit.x + overhang)
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MAX_X) != 0:
		max_x = _snap_roof_footprint_edge(roof, roof_local_hit.x - overhang)
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MIN_Z) != 0:
		min_z = _snap_roof_footprint_edge(roof, roof_local_hit.z + overhang)
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MAX_Z) != 0:
		max_z = _snap_roof_footprint_edge(roof, roof_local_hit.z - overhang)
	var sorted_min_x := minf(min_x, max_x)
	var sorted_max_x := maxf(min_x, max_x)
	var sorted_min_z := minf(min_z, max_z)
	var sorted_max_z := maxf(min_z, max_z)
	var base_y := m_drag_roof_old_start.y
	var old_anchor := Vector3(
		minf(m_drag_roof_old_start.x, m_drag_roof_old_end.x),
		base_y,
		minf(m_drag_roof_old_start.z, m_drag_roof_old_end.z)
	)
	var rotated_anchor := old_anchor + _roof_rotation_basis(m_drag_roof_old_rotation_degrees) * Vector3(
		sorted_min_x,
		0.0,
		sorted_min_z
	)
	var resized_size := Vector2(sorted_max_x - sorted_min_x, sorted_max_z - sorted_min_z)
	return {
		"start": rotated_anchor,
		"end": rotated_anchor + Vector3(resized_size.x, 0.0, resized_size.y),
	}


func _roof_plane_local_from_mouse(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	return _roof_plane_local_from_mouse_at_y(roof, camera, mouse_position, roof.start_point.y)


func _roof_plane_local_from_mouse_at_y(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_position: Vector2,
	plane_y: float
) -> Vector3:
	var parent_3d := roof.get_parent() as Node3D
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
			var distance_to_plane := (plane_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return local_origin + local_direction * distance_to_plane
	return roof.start_point


func _roof_drag_plane_y_from_mouse(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> float:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var hit := _intersect_roof_bounds(roof, origin, direction)
	if hit.is_empty():
		return roof.start_point.y
	var hit_position := Vector3(hit.get("position", roof.global_position))
	var parent_3d := roof.get_parent() as Node3D
	var parent_position := parent_3d.to_local(hit_position) if parent_3d != null else hit_position
	return parent_position.y


func _roof_edit_local_from_parent_position(local_position: Vector3) -> Vector3:
	var drag_anchor := Vector3(
		minf(m_drag_roof_old_start.x, m_drag_roof_old_end.x),
		m_drag_roof_old_start.y,
		minf(m_drag_roof_old_start.z, m_drag_roof_old_end.z)
	)
	var drag_frame := Transform3D(_roof_rotation_basis(m_drag_roof_old_rotation_degrees), drag_anchor)
	return drag_frame.affine_inverse() * local_position


func _snap_roof_footprint_edge(roof: Roof3DScript, value: float) -> float:
	var step := _active_roof_grid_step(roof)
	return roundf(value / step) * step


func _snap_roof_edit_point(roof: Roof3DScript, point: Vector3) -> Vector3:
	var step := _active_roof_grid_step(roof)
	return Vector3(
		roundf(point.x / step) * step,
		m_drag_roof_old_start.y,
		roundf(point.z / step) * step
	)


func _roof_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _roof_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		return "vertex"
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		return "edge"
	return "corner" if _roof_edit_mask_is_corner(edit_mask) else "edge"


func _roof_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _active_roof_grid_step(_roof: Roof3DScript) -> float:
	return maxf(float(m_roof_settings["grid_step"]), 0.05)


func _roof_covered_rects_from_regions(regions: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if regions.is_empty():
		return rects
	for rect in regions.get("covered_rects", []):
		rects.append(rect)
	return rects


func _roof_covered_polygons_from_regions(regions: Dictionary) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if regions.is_empty():
		return polygons
	for polygon in regions.get("covered_polygons", []):
		polygons.append(PackedVector2Array(polygon))
	return polygons


func _roof_rotation_basis(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(normalize_degrees(rotation_degrees)))


func _reset_roof_drag_state() -> void:
	m_dragging_roof = null
	m_drag_roof_old_start = Vector3.ZERO
	m_drag_roof_old_end = Vector3.ZERO
	m_drag_roof_old_polygon = PackedVector3Array()
	m_drag_roof_started_as_polygon = false
	m_drag_roof_vertex_index = -1
	m_drag_roof_edge_index = -1
	m_drag_roof_old_rotation_degrees = 0.0
	m_drag_roof_old_height = 0.0
	m_drag_roof_old_covered_rects = []
	m_drag_roof_old_covered_polygons = []
	m_drag_roof_anchor_local = Vector3.ZERO
	m_drag_roof_plane_y = 0.0
	m_drag_roof_edit_mask = FLOOR_EDIT_MOVE
	m_drag_roof_active_material = null


func _find_roof_edit_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var handle_pick := _find_roof_handle_pick(camera, mouse_pos)
	if !handle_pick.is_empty():
		return handle_pick
	return _find_roof_pick(camera, mouse_pos)


func _find_roof_handle_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var roofs: Array[Roof3DScript] = []
	_collect_scene_roofs(scene_root, roofs)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var best_vertex_pick: Dictionary = {}
	var best_vertex_camera_distance := INF
	var best_edge_pick: Dictionary = {}
	var best_edge_camera_distance := INF
	for roof in roofs:
		if (
			!is_instance_valid(roof)
			or roof.get_roof_style() != RoofStyleGeometryFactory.STYLE_FLAT
		):
			continue
		if roof == m_roof_preview or roof.has_meta(Roof3DScript.PREVIEW_META):
			continue
		var parent_3d := roof.get_parent() as Node3D
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
		var plane_distance := (roof.start_point.y - local_origin.y) / local_direction.y
		if plane_distance <= 0.0:
			continue
		var parent_hit := local_origin + local_direction * plane_distance
		var plan_hit := Vector2(parent_hit.x, parent_hit.z)
		var points := _get_roof_edit_points(roof)
		var radius := maxf(_active_roof_grid_step(roof) * 0.35, 0.16)
		var global_hit := parent_3d.to_global(parent_hit) if parent_3d != null else parent_hit
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
				"roof": roof,
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
				"roof": roof,
				"edit_mask": FLOOR_EDIT_POLYGON_EDGE,
				"vertex_index": -1,
				"edge_index": closest_edge_index,
				"parent_position": Vector3(
					closest_edge_point.x,
					roof.start_point.y,
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


func _find_roof_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_roofs(origin, direction)
	if hit.is_empty():
		return {}
	var roof := hit.get("roof") as Roof3DScript
	if roof == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mask"] = _roof_edit_mask_for_local_hit(roof, local_position)
	return hit


func _raycast_roofs(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var roofs: Array[Roof3DScript] = []
	_collect_scene_roofs(scene_root, roofs)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for roof in roofs:
		if !is_instance_valid(roof) or roof == m_roof_preview:
			continue
		if roof.has_meta(Roof3DScript.PREVIEW_META):
			continue
		var hit := _intersect_roof_bounds(roof, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_roofs(node: Node, roofs: Array[Roof3DScript]) -> void:
	if node is Roof3DScript:
		roofs.append(node as Roof3DScript)
	for child in node.get_children():
		_collect_scene_roofs(child, roofs)


func _intersect_roof_bounds(
	roof: Roof3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var size := roof.get_roof_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return {}
	var inverse_frame := roof.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var min_corner := roof.get_roof_bounds_min()
	var max_corner := roof.get_roof_bounds_max()
	var hit := m_context.intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
	if hit.is_empty():
		return {}

	var local_hit := Vector3(hit["position"])
	if !roof.contains_local_plan_point(Vector2(local_hit.x, local_hit.z)):
		return {}
	var local_normal := m_context.nearest_box_normal(local_hit, min_corner, max_corner)
	var global_hit := roof.global_transform * local_hit
	return {
		"roof": roof,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (roof.global_transform.basis * local_normal).normalized(),
		"collider": roof,
		"distance": origin.distance_to(global_hit),
	}


func _roof_edit_mask_for_local_hit(roof: Roof3DScript, local_hit: Vector3) -> int:
	var size := roof.get_roof_size()
	var overhang := maxf(roof.roof_overhang, 0.0)
	var radius := maxf(_active_roof_grid_step(roof) * 0.35, 0.16)
	var edit_mask := FLOOR_EDIT_MOVE
	var min_x_distance := absf(local_hit.x + overhang)
	var max_x_distance := absf(size.x + overhang - local_hit.x)
	if minf(min_x_distance, max_x_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_X if min_x_distance <= max_x_distance else FLOOR_EDIT_MAX_X
	var min_z_distance := absf(local_hit.z + overhang)
	var max_z_distance := absf(size.y + overhang - local_hit.z)
	if minf(min_z_distance, max_z_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_Z if min_z_distance <= max_z_distance else FLOOR_EDIT_MAX_Z
	return edit_mask


func _update_roof_hover(roof: Roof3DScript, edit_mask: int) -> void:
	if roof == m_drag_roof_hover and edit_mask == m_drag_roof_hover_edit_mask:
		return
	_clear_roof_hover()
	if roof == null:
		return
	m_drag_roof_hover = roof
	m_drag_roof_hover_edit_mask = edit_mask
	m_drag_roof_hover_material = roof.material_override
	roof.material_override = m_context.build_preview_material(_roof_drag_color(edit_mask, true))


func _clear_roof_hover() -> void:
	if m_drag_roof_hover == null:
		return
	if is_instance_valid(m_drag_roof_hover):
		m_drag_roof_hover.material_override = m_drag_roof_hover_material
	m_drag_roof_hover = null
	m_drag_roof_hover_material = null
	m_drag_roof_hover_edit_mask = FLOOR_EDIT_MOVE


func _clear_roof_preview() -> void:
	if m_roof_preview != null and is_instance_valid(m_roof_preview):
		m_roof_preview.queue_free()
	m_roof_preview = null


func _reset_roof_drawing_state() -> void:
	m_is_drawing_roof = false
	m_roof_has_valid_preview = false
	m_roof_release_commits_preview = false
	m_roof_start_screen_position = Vector2.ZERO
	m_roof_polygon_points = PackedVector3Array()
	m_roof_draw_rotation_degrees = normalize_degrees(float(m_roof_settings.get("rotation_degrees", 0.0)))


func _is_roof_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_roof_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _is_valid_roof_polygon(points: PackedVector3Array) -> bool:
	if points.size() < 3:
		return false
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(point.x, point.z))
	return !Geometry2D.triangulate_polygon(polygon).is_empty()


func _roof_polygon_parent_bounds(points: PackedVector3Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := Vector2(points[0].x, points[0].z)
	var max_point := min_point
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.z)
	return Rect2(min_point, max_point - min_point)


func _flat_roof(roof: Roof3DScript) -> FlatRoof3DScript:
	return roof as FlatRoof3DScript


func _is_polygon_roof(roof: Roof3DScript) -> bool:
	var flat_roof := _flat_roof(roof)
	return flat_roof != null and flat_roof.is_polygon_roof()


func _get_roof_polygon(roof: Roof3DScript) -> PackedVector3Array:
	var flat_roof := _flat_roof(roof)
	return flat_roof.get_roof_polygon() if flat_roof != null else PackedVector3Array()


func _set_roof_polygon(roof: Roof3DScript, points: PackedVector3Array) -> void:
	var flat_roof := _flat_roof(roof)
	if flat_roof != null:
		flat_roof.set_roof_polygon(points)


func _roof_angle_degrees(roof: Roof3DScript) -> float:
	return BuildingFactoryScript.get_roof_angle_degrees(roof)


func _roof_hip_gable_height(roof: Roof3DScript) -> float:
	return BuildingFactoryScript.get_roof_hip_gable_height(roof)


func _roof_hip_shape(roof: Roof3DScript) -> int:
	return BuildingFactoryScript.get_roof_hip_shape(roof)


func _set_roof_corners_rotation_angle_and_covers(
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_angle_degrees: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array]
) -> void:
	var parameters := BuildingFactoryScript.get_roof_style_parameters(roof)
	if parameters.has("angle_degrees"):
		parameters["angle_degrees"] = new_angle_degrees
	roof.set_roof_corners_rotation_parameters_and_covers(
		new_start,
		new_end,
		new_rotation,
		parameters,
		new_covered_rects,
		new_covered_polygons
	)


func _get_roof_edit_points(roof: Roof3DScript) -> PackedVector3Array:
	if _is_polygon_roof(roof):
		return _get_roof_polygon(roof)
	var size := roof.get_roof_size()
	var anchor := roof.get_roof_anchor_point()
	var basis := _roof_rotation_basis(roof.roof_rotation_degrees)
	return PackedVector3Array([
		anchor,
		anchor + basis * Vector3(size.x, 0.0, 0.0),
		anchor + basis * Vector3(size.x, 0.0, size.y),
		anchor + basis * Vector3(0.0, 0.0, size.y),
	])


func _set_roof_state_and_refresh(
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_height: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array],
	coordinator: Building3DScript
) -> void:
	if roof == null or !is_instance_valid(roof):
		return
	_set_roof_corners_rotation_angle_and_covers(
		roof,
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons
	)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func _roof_layout_would_hide_any_roof(
	coordinator: Building3DScript,
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_height: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array]
) -> bool:
	if coordinator == null or !is_instance_valid(coordinator):
		return false
	if roof == null or !is_instance_valid(roof):
		return false

	var snapshots: Array[Dictionary] = []
	for roof_node in coordinator.get_roof_nodes():
		snapshots.append({
			"roof": roof_node,
			"start": roof_node.start_point,
			"end": roof_node.end_point,
			"polygon": _get_roof_polygon(roof_node),
			"rotation": roof_node.roof_rotation_degrees,
			"height": _roof_angle_degrees(roof_node),
			"covered_rects": roof_node.get_covered_rects(),
			"covered_polygons": roof_node.get_covered_polygons(),
		})

	_set_roof_corners_rotation_angle_and_covers(
		roof,
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons
	)
	coordinator.refresh_roof_covered_rects()
	var hides_roof := false
	for roof_node in coordinator.get_roof_nodes():
		if roof_node.has_meta(Roof3DScript.PREVIEW_META):
			continue
		if !roof_node.has_visible_roof_geometry():
			hides_roof = true
			break

	for snapshot in snapshots:
		var snapshot_roof := snapshot["roof"] as Roof3DScript
		if snapshot_roof == null or !is_instance_valid(snapshot_roof):
			continue
		var snapshot_covers: Array[Rect2] = []
		for rect in snapshot.get("covered_rects", []):
			snapshot_covers.append(rect)
		var snapshot_polygons: Array[PackedVector2Array] = []
		for polygon in snapshot.get("covered_polygons", []):
			snapshot_polygons.append(PackedVector2Array(polygon))
		var snapshot_polygon := PackedVector3Array(snapshot.get("polygon", PackedVector3Array()))
		if !snapshot_polygon.is_empty():
			_set_roof_polygon(snapshot_roof, snapshot_polygon)
			snapshot_roof.set_covered_regions(snapshot_covers, snapshot_polygons)
		else:
			_set_roof_corners_rotation_angle_and_covers(
				snapshot_roof,
				Vector3(snapshot["start"]),
				Vector3(snapshot["end"]),
				float(snapshot["rotation"]),
				float(snapshot["height"]),
				snapshot_covers,
				snapshot_polygons
			)
	return hides_roof

