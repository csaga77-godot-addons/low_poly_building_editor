@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Stairs tool controller — owns the stairs dock settings, rotated-rectangle
## draw preview, R-key rotation, hover highlight, and body/edge/corner drag
## editing (stage 4 of the plugin split). Undo/redo actions bind the
## plugin-lifetime context, never per-gesture objects.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs/stairs_3d.gd")
const TurningStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/turning_stairs_3d.gd"
)
const WinderStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/winder_stairs_3d.gd"
)

var m_stair_settings := {
	"grid_step": 0.5,
	"base_height": 0.0,
	"height": 1.2,
	"step_count": 6,
	"thickness": 0.12,
	"tread_style": Stairs3DScript.TreadStyle.CLOSED,
	"nosing_depth": 0.08,
	"rotation_degrees": 0.0,
	"color": Color(0.52, 0.46, 0.38, 1.0),
	"layout_script": BuildingFactoryScript.StraightStairs3DScript,
	"turn_direction": TurningStairs3DScript.TurnDirection.RIGHT,
	"winder_turn": WinderStairs3DScript.WinderTurn.TURN_90,
	"spiral_turn_degrees": 360.0,
	"flight_width": 1.2,
	"left_rail_enabled": false,
	"right_rail_enabled": false,
	"infill_style": 0,
	"lower_newel_enabled": false,
	"lower_newel_placement": Stairs3DScript.NewelPlacement.TREAD,
	"upper_newel_enabled": false,
	"upper_newel_placement": Stairs3DScript.NewelPlacement.TREAD,
	"middle_newel_post_count": 0,
	"infill_count_between_newels": 1,
	"rail_newel_post_thickness": 0.1,
	"rail_edge_margin": 0.15,
	"rail_height": 1.0,
	"infill_rail_thickness": 0.08,
	"rail_thickness": 0.1,
	"rail_lower_height": 0.18,
	"rail_color": Color(0.33, 0.28, 0.22, 1.0),
}
var m_stair_start_local := Vector3.ZERO
var m_stair_end_local := Vector3.ZERO
var m_stair_start_screen_position := Vector2.ZERO
var m_stair_has_valid_preview := false
var m_stair_release_commits_preview := false
var m_stair_draw_rotation_degrees := 0.0
var m_is_drawing_stair := false
var m_stair_preview: Stairs3DScript
var m_dragging_stair: Stairs3DScript
var m_drag_stair_old_start := Vector3.ZERO
var m_drag_stair_old_end := Vector3.ZERO
var m_drag_stair_old_rotation_degrees := 0.0
var m_drag_stair_anchor_local := Vector3.ZERO
var m_drag_stair_plane_y := 0.0
var m_drag_stair_edit_mask := FLOOR_EDIT_MOVE
var m_drag_stair_active_material: Material
var m_drag_stair_hover: Stairs3DScript
var m_drag_stair_hover_material: Material
var m_drag_stair_hover_edit_mask := FLOOR_EDIT_MOVE


func apply_settings(settings: Dictionary) -> void:
	m_stair_settings = settings.duplicate(true)
	_clear_stair_preview()


func cancel_preview() -> void:
	_cancel_stair_drag()
	_clear_stair_hover()
	_clear_stair_preview()
	_reset_stair_drawing_state()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and !key_event.echo and key_event.keycode == KEY_R:
			return _handle_stair_rotation_key(key_event)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if m_dragging_stair != null:
		return _handle_stair_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_stair:
			_update_stair_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_stair_start_screen_position) >= DRAG_COMMIT_DISTANCE:
				m_stair_release_commits_preview = true
			return m_context.handled()
		var stair_pick := _find_stair_pick(camera, mouse_motion.position)
		var hover_stair := stair_pick.get("stair") as Stairs3DScript
		var edit_mask := int(stair_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_stair_hover(hover_stair, edit_mask)
		if hover_stair != null:
			m_context.set_status(
				"Drag stairs corner to resize." if _stair_edit_mask_is_corner(edit_mask)
				else "Drag stairs edge to resize." if edit_mask != FLOOR_EDIT_MOVE
				else "Drag stairs body to move."
			)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_stair:
		if !m_stair_release_commits_preview:
			m_context.set_status("Click the opposite corner to place stairs, or drag from the first corner and release.")
			return m_context.handled()
		var release_coordinator := _get_active_stair_coordinator()
		if release_coordinator != null:
			var release_end := m_stair_end_local
			if !m_stair_has_valid_preview:
				release_end = _stair_draw_local_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_stairs(release_coordinator, m_stair_start_local, release_end, m_stair_draw_rotation_degrees)
		_clear_stair_preview()
		_reset_stair_drawing_state()
		return m_context.handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_stair:
		var stair_pick := _find_stair_pick(camera, mouse_button.position)
		var hit_stair := stair_pick.get("stair") as Stairs3DScript
		if hit_stair != null:
			_clear_stair_hover()
			_start_stair_drag(hit_stair, camera, mouse_button.position, int(stair_pick.get("edit_mask", FLOOR_EDIT_MOVE)))
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing stairs.")
		return m_context.handled()

	var snapped_local := _stair_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_stair:
		m_stair_start_local = snapped_local
		m_stair_end_local = snapped_local
		m_stair_start_screen_position = mouse_button.position
		m_stair_has_valid_preview = false
		m_stair_release_commits_preview = false
		m_stair_draw_rotation_degrees = normalize_degrees(float(m_stair_settings.get("rotation_degrees", 0.0)))
		m_is_drawing_stair = true
		_create_stair_preview(coordinator)
		_update_stair_preview(camera, mouse_button.position)
		m_context.set_status("Stairs first corner captured. Drag and release, or click the opposite corner.")
		return m_context.handled()

	_commit_stairs(coordinator, m_stair_start_local, snapped_local, m_stair_draw_rotation_degrees)
	_clear_stair_preview()
	_reset_stair_drawing_state()
	return m_context.handled()


func _create_stair_preview(coordinator: Building3DScript) -> void:
	_clear_stair_preview()
	m_stair_preview = BuildingFactoryScript.instantiate_stair_layout(
		m_stair_settings.get(
			"layout_script",
			BuildingFactoryScript.StraightStairs3DScript
		)
	)
	m_stair_preview.name = "StairsPreview"
	m_stair_preview.set_meta(Stairs3DScript.PREVIEW_META, true)
	m_stair_preview.stair_height = float(m_stair_settings["height"])
	m_stair_preview.step_count = int(m_stair_settings["step_count"])
	m_stair_preview.stair_thickness = float(m_stair_settings["thickness"])
	m_stair_preview.stair_rotation_degrees = m_stair_draw_rotation_degrees
	var preview_color := Color(m_stair_settings["color"])
	preview_color.a = 0.46
	m_stair_preview.stair_color = preview_color
	_apply_stair_layout_settings(m_stair_preview)
	_apply_stair_rail_settings(m_stair_preview)
	m_stair_preview.generate_collision = false
	coordinator.add_child(m_stair_preview)
	m_stair_preview.owner = null
	m_context.apply_debug_wireframe_to_node(m_stair_preview)


func _update_stair_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_stair_preview == null:
		return
	var coordinator := m_stair_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var local_end := _stair_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_stair_end_local = local_end
	var stair_points := Stairs3DScript.stair_corners_from_base_points(
		m_stair_start_local,
		local_end,
		m_stair_draw_rotation_degrees
	)
	var stair_start := Vector3(stair_points["start"])
	var stair_end := Vector3(stair_points["end"])
	m_stair_has_valid_preview = _is_stair_span_large_enough(stair_start, stair_end)
	m_stair_preview.stair_height = float(m_stair_settings["height"])
	m_stair_preview.step_count = int(m_stair_settings["step_count"])
	m_stair_preview.stair_thickness = float(m_stair_settings["thickness"])
	_apply_stair_layout_settings(m_stair_preview)
	_apply_stair_rail_settings(m_stair_preview)
	m_stair_preview.set_stair_corners_and_rotation(stair_start, stair_end, m_stair_draw_rotation_degrees)
	if m_stair_has_valid_preview:
		var size := m_stair_preview.get_stair_size()
		m_context.set_status(
			"Release or click to place stairs: %.2f x %.2f, %.0f deg." %
			[size.x, size.y, m_stair_draw_rotation_degrees]
		)


func _apply_stair_layout_settings(stairs: Stairs3DScript) -> void:
	BuildingFactoryScript.configure_stair_layout(
		stairs,
		int(m_stair_settings.get(
			"turn_direction",
			TurningStairs3DScript.TurnDirection.RIGHT
		)),
		int(m_stair_settings.get(
			"winder_turn",
			WinderStairs3DScript.WinderTurn.TURN_90
		)),
		float(m_stair_settings.get("flight_width", 1.2)),
		float(m_stair_settings.get("spiral_turn_degrees", 360.0))
	)
	stairs.tread_style = int(m_stair_settings.get(
		"tread_style",
		Stairs3DScript.TreadStyle.CLOSED
	))
	stairs.nosing_depth = float(m_stair_settings.get("nosing_depth", 0.08))


func _apply_stair_rail_settings(stairs: Stairs3DScript) -> void:
	stairs.left_rail_enabled = bool(m_stair_settings.get("left_rail_enabled", false))
	stairs.right_rail_enabled = bool(m_stair_settings.get("right_rail_enabled", false))
	stairs.infill_style = int(m_stair_settings.get("infill_style", 0))
	stairs.lower_newel_enabled = bool(m_stair_settings.get("lower_newel_enabled", false))
	stairs.lower_newel_placement = int(m_stair_settings.get(
		"lower_newel_placement",
		Stairs3DScript.NewelPlacement.TREAD
	))
	stairs.upper_newel_enabled = bool(m_stair_settings.get("upper_newel_enabled", false))
	stairs.upper_newel_placement = int(m_stair_settings.get(
		"upper_newel_placement",
		Stairs3DScript.NewelPlacement.TREAD
	))
	stairs.middle_newel_post_count = int(
		m_stair_settings.get("middle_newel_post_count", 0)
	)
	stairs.infill_count_between_newels = int(
		m_stair_settings.get("infill_count_between_newels", 1)
	)
	stairs.rail_newel_post_thickness = float(
		m_stair_settings.get("rail_newel_post_thickness", 0.1)
	)
	stairs.rail_edge_margin = float(m_stair_settings.get("rail_edge_margin", 0.15))
	stairs.rail_height = float(m_stair_settings.get("rail_height", 1.0))
	stairs.infill_rail_thickness = float(m_stair_settings.get("infill_rail_thickness", 0.08))
	stairs.rail_thickness = float(m_stair_settings.get("rail_thickness", 0.1))
	stairs.rail_lower_height = float(m_stair_settings.get("rail_lower_height", 0.18))
	stairs.rail_color = Color(m_stair_settings.get("rail_color", Color(0.33, 0.28, 0.22, 1.0)))


func _stair_base_height() -> float:
	return float(m_stair_settings.get("base_height", 0.0))


func _stair_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _stair_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_stair_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := m_context.raycast_world(camera, mouse_position, false)
	return _snap_stair_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_stair_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_stair_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _get_active_stair_coordinator() -> Building3DScript:
	if m_stair_preview != null and is_instance_valid(m_stair_preview):
		var preview_parent := m_stair_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return m_context.get_or_create_coordinator(false)


func _handle_stair_rotation_key(key_event: InputEventKey) -> int:
	var delta := -90.0 if key_event.shift_pressed else 90.0
	if m_is_drawing_stair:
		m_stair_draw_rotation_degrees = normalize_degrees(m_stair_draw_rotation_degrees + delta)
		if m_stair_preview != null and is_instance_valid(m_stair_preview):
			var stair_points := Stairs3DScript.stair_corners_from_base_points(
				m_stair_start_local,
				m_stair_end_local,
				m_stair_draw_rotation_degrees
			)
			m_stair_preview.set_stair_corners_and_rotation(
				Vector3(stair_points["start"]),
				Vector3(stair_points["end"]),
				m_stair_draw_rotation_degrees
			)
		m_context.set_status("Stairs preview rotation: %.0f degrees." % m_stair_draw_rotation_degrees)
		return m_context.handled()

	if m_dragging_stair != null:
		m_context.set_status("Release the stairs edit before rotating.")
		return m_context.handled()

	var stair := m_drag_stair_hover if is_instance_valid(m_drag_stair_hover) else _selected_stair_for_rotation()
	if stair == null:
		m_context.set_status("Hover or select stairs to rotate them.")
		return m_context.handled()
	_commit_stair_rotation(stair, delta)
	return m_context.handled()


func _selected_stair_for_rotation() -> Stairs3DScript:
	var selection := m_context.editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		if node is Stairs3DScript:
			return node as Stairs3DScript
	return null


func _commit_stair_rotation(stair: Stairs3DScript, delta_degrees: float) -> void:
	if stair == null or !is_instance_valid(stair):
		return
	var old_start := stair.start_point
	var old_end := stair.end_point
	var old_rotation := stair.stair_rotation_degrees
	var new_rotation := normalize_degrees(old_rotation + delta_degrees)
	var rotated_state := _stair_state_rotated_around_center(stair, new_rotation)
	var new_start := Vector3(rotated_state["start"])
	var new_end := Vector3(rotated_state["end"])
	_clear_stair_hover()

	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Rotate Stairs")
	undo_redo.add_do_method(stair, "set_stair_corners_and_rotation", new_start, new_end, new_rotation)
	undo_redo.add_do_method(m_context, "select_node", stair)
	undo_redo.add_undo_method(stair, "set_stair_corners_and_rotation", old_start, old_end, old_rotation)
	undo_redo.commit_action()
	m_context.set_status("Rotated stairs to %.0f degrees." % new_rotation)


func _stair_state_rotated_around_center(stair: Stairs3DScript, rotation_degrees: float) -> Dictionary:
	var size := stair.get_stair_size()
	var center := stair.get_stair_center_point()
	var anchor := center - _stair_rotation_basis(rotation_degrees) * Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	return {
		"start": anchor,
		"end": anchor + Vector3(size.x, 0.0, size.y),
	}


func _commit_stairs(
	coordinator: Building3DScript,
	draw_start: Vector3,
	draw_end: Vector3,
	rotation_degrees: float
) -> void:
	var stair_points := Stairs3DScript.stair_corners_from_base_points(draw_start, draw_end, rotation_degrees)
	var local_start := Vector3(stair_points["start"])
	var local_end := Vector3(stair_points["end"])
	if !_is_stair_span_large_enough(local_start, local_end):
		m_context.set_status("Stairs footprint is too small.")
		return

	var stairs_settings := m_stair_settings.duplicate()
	stairs_settings["rotation_degrees"] = normalize_degrees(rotation_degrees)
	var stairs := BuildingFactoryScript.create_stairs_node(
		coordinator,
		local_start,
		local_end,
		stairs_settings
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Stairs")
	undo_redo.add_do_reference(stairs)
	undo_redo.add_do_method(m_context, "do_add_node", coordinator, stairs, scene_root, true)
	undo_redo.add_undo_method(m_context, "undo_remove_node", coordinator, stairs)
	undo_redo.commit_action()
	var size := stairs.get_stair_size()
	m_context.set_status("Created stairs: %.2f x %.2f units." % [size.x, size.y])


func _handle_stair_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_stair_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_stair_drag()
			return m_context.handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_stair_drag()
			return m_context.handled()
	return m_context.handled()


func _start_stair_drag(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int
) -> void:
	m_dragging_stair = stair
	m_drag_stair_old_start = stair.start_point
	m_drag_stair_old_end = stair.end_point
	m_drag_stair_old_rotation_degrees = stair.stair_rotation_degrees
	m_drag_stair_edit_mask = edit_mask
	m_drag_stair_active_material = stair.material_override
	m_drag_stair_plane_y = _stair_drag_plane_y_from_mouse(stair, camera, mouse_pos)
	m_drag_stair_anchor_local = _stair_plane_local_from_mouse_at_y(stair, camera, mouse_pos, m_drag_stair_plane_y)
	stair.material_override = m_context.build_preview_material(_stair_drag_color(edit_mask, true))
	m_context.select_node(stair)
	m_context.set_status("Dragging stairs %s - release to commit, Escape to cancel." % _stair_edit_label(edit_mask))


func _update_stair_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_stair == null or !is_instance_valid(m_dragging_stair):
		_reset_stair_drag_state()
		return
	var stair := m_dragging_stair
	var hit_local := _stair_plane_local_from_mouse_at_y(stair, camera, mouse_pos, m_drag_stair_plane_y)
	var new_start := m_drag_stair_old_start
	var new_end := m_drag_stair_old_end
	if m_drag_stair_edit_mask == FLOOR_EDIT_MOVE:
		var step := _active_stair_grid_step(stair)
		var raw_delta := hit_local - m_drag_stair_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start = m_drag_stair_old_start + snapped_delta
		new_end = m_drag_stair_old_end + snapped_delta
	else:
		var stair_local := _stair_edit_local_from_parent_position(hit_local)
		var resized := _resized_stair_points(stair, stair_local)
		new_start = Vector3(resized["start"])
		new_end = Vector3(resized["end"])

	stair.set_stair_corners_and_rotation(new_start, new_end, m_drag_stair_old_rotation_degrees)
	var valid := _is_stair_span_large_enough(new_start, new_end)
	stair.material_override = m_context.build_preview_material(
		_stair_drag_color(m_drag_stair_edit_mask, valid)
	)
	if valid:
		var size := stair.get_stair_size()
		m_context.set_status("Release to commit stairs %s: %.2f x %.2f." % [_stair_edit_label(m_drag_stair_edit_mask), size.x, size.y])
	else:
		m_context.set_status("Stairs footprint is too small.")


func _commit_stair_drag() -> void:
	if m_dragging_stair == null:
		return
	var stair := m_dragging_stair
	var old_start := m_drag_stair_old_start
	var old_end := m_drag_stair_old_end
	var old_rotation := m_drag_stair_old_rotation_degrees
	var new_start := stair.start_point
	var new_end := stair.end_point
	var new_rotation := stair.stair_rotation_degrees
	var edit_mask := m_drag_stair_edit_mask
	stair.material_override = m_drag_stair_active_material
	if !_is_stair_span_large_enough(new_start, new_end):
		stair.set_stair_corners_and_rotation(old_start, old_end, old_rotation)
		_reset_stair_drag_state()
		m_context.set_status("Stairs footprint is too small.")
		return
	if (
			old_start.distance_to(new_start) <= 0.001
			and old_end.distance_to(new_end) <= 0.001
			and angles_match(old_rotation, new_rotation)
	):
		_reset_stair_drag_state()
		m_context.set_status("Stairs unchanged.")
		return

	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Move Stairs" if edit_mask == FLOOR_EDIT_MOVE else "Resize Stairs")
	undo_redo.add_do_method(stair, "set_stair_corners_and_rotation", new_start, new_end, new_rotation)
	undo_redo.add_do_method(m_context, "select_node", stair)
	undo_redo.add_undo_method(stair, "set_stair_corners_and_rotation", old_start, old_end, old_rotation)
	undo_redo.commit_action()
	_reset_stair_drag_state()
	var size := stair.get_stair_size()
	m_context.set_status("Edited stairs: %.2f x %.2f units." % [size.x, size.y])


func _cancel_stair_drag() -> void:
	if m_dragging_stair == null:
		return
	if is_instance_valid(m_dragging_stair):
		m_dragging_stair.set_stair_corners_and_rotation(
			m_drag_stair_old_start,
			m_drag_stair_old_end,
			m_drag_stair_old_rotation_degrees
		)
		m_dragging_stair.material_override = m_drag_stair_active_material
	_reset_stair_drag_state()
	m_context.set_status("Stairs edit canceled.")


func _resized_stair_points(stair: Stairs3DScript, stair_local_hit: Vector3) -> Dictionary:
	var old_size := Vector2(
		absf(m_drag_stair_old_end.x - m_drag_stair_old_start.x),
		absf(m_drag_stair_old_end.z - m_drag_stair_old_start.z)
	)
	var min_x := 0.0
	var max_x := old_size.x
	var min_z := 0.0
	var max_z := old_size.y
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MIN_X) != 0:
		min_x = _snap_stair_footprint_edge(stair, stair_local_hit.x)
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MAX_X) != 0:
		max_x = _snap_stair_footprint_edge(stair, stair_local_hit.x)
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MIN_Z) != 0:
		min_z = _snap_stair_footprint_edge(stair, stair_local_hit.z)
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MAX_Z) != 0:
		max_z = _snap_stair_footprint_edge(stair, stair_local_hit.z)
	var sorted_min_x := minf(min_x, max_x)
	var sorted_max_x := maxf(min_x, max_x)
	var sorted_min_z := minf(min_z, max_z)
	var sorted_max_z := maxf(min_z, max_z)
	var base_y := m_drag_stair_old_start.y
	var old_anchor := Vector3(
		minf(m_drag_stair_old_start.x, m_drag_stair_old_end.x),
		base_y,
		minf(m_drag_stair_old_start.z, m_drag_stair_old_end.z)
	)
	var rotated_anchor := old_anchor + _stair_rotation_basis(m_drag_stair_old_rotation_degrees) * Vector3(
		sorted_min_x,
		0.0,
		sorted_min_z
	)
	var resized_size := Vector2(sorted_max_x - sorted_min_x, sorted_max_z - sorted_min_z)
	return {
		"start": rotated_anchor,
		"end": rotated_anchor + Vector3(resized_size.x, 0.0, resized_size.y),
	}


func _stair_plane_local_from_mouse(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	return _stair_plane_local_from_mouse_at_y(stair, camera, mouse_position, stair.start_point.y)


func _stair_plane_local_from_mouse_at_y(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_position: Vector2,
	plane_y: float
) -> Vector3:
	var parent_3d := stair.get_parent() as Node3D
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
	return stair.start_point


func _stair_drag_plane_y_from_mouse(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> float:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var hit := _intersect_stair_bounds(stair, origin, direction)
	if hit.is_empty():
		return stair.start_point.y
	var hit_position := Vector3(hit.get("position", stair.global_position))
	var parent_3d := stair.get_parent() as Node3D
	var parent_position := parent_3d.to_local(hit_position) if parent_3d != null else hit_position
	return parent_position.y


func _stair_edit_local_from_parent_position(local_position: Vector3) -> Vector3:
	var drag_anchor := Vector3(
		minf(m_drag_stair_old_start.x, m_drag_stair_old_end.x),
		m_drag_stair_old_start.y,
		minf(m_drag_stair_old_start.z, m_drag_stair_old_end.z)
	)
	var drag_frame := Transform3D(_stair_rotation_basis(m_drag_stair_old_rotation_degrees), drag_anchor)
	return drag_frame.affine_inverse() * local_position


func _snap_stair_footprint_edge(stair: Stairs3DScript, value: float) -> float:
	var step := _active_stair_grid_step(stair)
	return roundf(value / step) * step


func _stair_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _stair_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	return "corner" if _stair_edit_mask_is_corner(edit_mask) else "edge"


func _stair_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _active_stair_grid_step(_stair: Stairs3DScript) -> float:
	return maxf(float(m_stair_settings["grid_step"]), 0.05)


func _stair_rotation_basis(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(normalize_degrees(rotation_degrees)))


func _reset_stair_drag_state() -> void:
	m_dragging_stair = null
	m_drag_stair_old_start = Vector3.ZERO
	m_drag_stair_old_end = Vector3.ZERO
	m_drag_stair_old_rotation_degrees = 0.0
	m_drag_stair_anchor_local = Vector3.ZERO
	m_drag_stair_plane_y = 0.0
	m_drag_stair_edit_mask = FLOOR_EDIT_MOVE
	m_drag_stair_active_material = null


func _find_stair_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_stairs(origin, direction)
	if hit.is_empty():
		return {}
	var stair := hit.get("stair") as Stairs3DScript
	if stair == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mask"] = _stair_edit_mask_for_local_hit(stair, local_position)
	return hit


func _raycast_stairs(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var stairs_nodes: Array[Stairs3DScript] = []
	_collect_scene_stairs(scene_root, stairs_nodes)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for stair in stairs_nodes:
		if !is_instance_valid(stair) or stair == m_stair_preview:
			continue
		if stair.has_meta(Stairs3DScript.PREVIEW_META):
			continue
		var hit := _intersect_stair_bounds(stair, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_stairs(node: Node, stairs_nodes: Array[Stairs3DScript]) -> void:
	if node is Stairs3DScript:
		stairs_nodes.append(node as Stairs3DScript)
	for child in node.get_children():
		_collect_scene_stairs(child, stairs_nodes)


func _intersect_stair_bounds(
	stair: Stairs3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var size := stair.get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return {}
	var inverse_frame := stair.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var min_corner := stair.get_stair_bounds_min()
	var max_corner := stair.get_stair_bounds_max()
	var hit := m_context.intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
	if hit.is_empty():
		return {}

	var local_hit := Vector3(hit["position"])
	var local_normal := m_context.nearest_box_normal(local_hit, min_corner, max_corner)
	var global_hit := stair.global_transform * local_hit
	return {
		"stair": stair,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (stair.global_transform.basis * local_normal).normalized(),
		"collider": stair,
		"distance": origin.distance_to(global_hit),
	}


func _stair_edit_mask_for_local_hit(stair: Stairs3DScript, local_hit: Vector3) -> int:
	var size := stair.get_stair_size()
	var radius := maxf(_active_stair_grid_step(stair) * 0.35, 0.16)
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


func _update_stair_hover(stair: Stairs3DScript, edit_mask: int) -> void:
	if stair == m_drag_stair_hover and edit_mask == m_drag_stair_hover_edit_mask:
		return
	_clear_stair_hover()
	if stair == null:
		return
	m_drag_stair_hover = stair
	m_drag_stair_hover_edit_mask = edit_mask
	m_drag_stair_hover_material = stair.material_override
	stair.material_override = m_context.build_preview_material(_stair_drag_color(edit_mask, true))


func _clear_stair_hover() -> void:
	if m_drag_stair_hover == null:
		return
	if is_instance_valid(m_drag_stair_hover):
		m_drag_stair_hover.material_override = m_drag_stair_hover_material
	m_drag_stair_hover = null
	m_drag_stair_hover_material = null
	m_drag_stair_hover_edit_mask = FLOOR_EDIT_MOVE


func _clear_stair_preview() -> void:
	if m_stair_preview != null and is_instance_valid(m_stair_preview):
		m_stair_preview.queue_free()
	m_stair_preview = null


func _reset_stair_drawing_state() -> void:
	m_is_drawing_stair = false
	m_stair_has_valid_preview = false
	m_stair_release_commits_preview = false
	m_stair_start_screen_position = Vector2.ZERO
	m_stair_draw_rotation_degrees = normalize_degrees(float(m_stair_settings.get("rotation_degrees", 0.0)))


func _is_stair_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_stair_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)
