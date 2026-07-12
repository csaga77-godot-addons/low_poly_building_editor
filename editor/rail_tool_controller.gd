@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Rail tool controller — owns the rail dock settings, two-point draw
## preview, hover highlight, and body/endpoint drag editing (stage 4 of the
## plugin split). Undo/redo actions bind the plugin-lifetime context, never
## per-gesture objects.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Rail3DScript = preload("res://addons/low_poly_building_editor/rails/rail_3d.gd")

var m_rail_settings := {
	"grid_step": 0.5,
	"base_height": 0.0,
	"height": 1.0,
	"post_spacing": 1.0,
	"infill_rail_thickness": 0.08,
	"rail_thickness": 0.1,
	"infill_style": 0,
	"newel_post_count": 2,
	"infill_count_between_newels": 1,
	"newel_post_thickness": 0.1,
	"lower_rail_height": 0.18,
	"color": Color(0.33, 0.28, 0.22, 1.0),
}
var m_rail_start_local := Vector3.ZERO
var m_rail_end_local := Vector3.ZERO
var m_rail_start_screen_position := Vector2.ZERO
var m_rail_has_valid_preview := false
var m_rail_release_commits_preview := false
var m_is_drawing_rail := false
var m_rail_preview: Rail3DScript
var m_dragging_rail: Rail3DScript
var m_drag_rail_old_start := Vector3.ZERO
var m_drag_rail_old_end := Vector3.ZERO
var m_drag_rail_anchor_local := Vector3.ZERO
var m_drag_rail_endpoint := -1
var m_drag_rail_active_material: Material
var m_drag_rail_hover: Rail3DScript
var m_drag_rail_hover_material: Material
var m_drag_rail_hover_endpoint := -1


func apply_settings(settings: Dictionary) -> void:
	m_rail_settings = settings.duplicate(true)
	_clear_rail_preview()


func cancel_preview() -> void:
	_cancel_rail_drag()
	_clear_rail_hover()
	_clear_rail_preview()
	_reset_rail_drawing_state()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_rail != null:
		return _handle_rail_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_rail:
			_update_rail_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_rail_start_screen_position) >= DRAG_COMMIT_DISTANCE:
				m_rail_release_commits_preview = true
			return m_context.handled()
		var pick := _find_rail_pick(camera, mouse_motion.position)
		var hover_rail := pick.get("rail") as Rail3DScript
		var endpoint := int(pick.get("endpoint", -1))
		_update_rail_hover(hover_rail, endpoint)
		if hover_rail != null:
			m_context.set_status(
				"Drag rail endpoint to resize."
				if endpoint >= 0
				else "Drag rail body to move."
			)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if (
		mouse_button.button_index == MOUSE_BUTTON_LEFT
		and !mouse_button.pressed
		and m_is_drawing_rail
	):
		if !m_rail_release_commits_preview:
			m_context.set_status("Click another point to place the rail, or drag from the start point and release.")
			return m_context.handled()
		var release_coordinator := _get_active_rail_coordinator()
		if release_coordinator != null:
			var release_end := m_rail_end_local
			if !m_rail_has_valid_preview:
				release_end = _rail_draw_local_from_mouse(
					release_coordinator,
					camera,
					mouse_button.position
				)
			_commit_rail(release_coordinator, m_rail_start_local, release_end)
		_clear_rail_preview()
		_reset_rail_drawing_state()
		return m_context.handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_rail:
		var pick := _find_rail_pick(camera, mouse_button.position)
		var hit_rail := pick.get("rail") as Rail3DScript
		if hit_rail != null:
			_clear_rail_hover()
			_start_rail_drag(
				hit_rail,
				camera,
				mouse_button.position,
				int(pick.get("endpoint", -1))
			)
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing rails.")
		return m_context.handled()
	var snapped_local := _rail_draw_local_from_mouse(
		coordinator,
		camera,
		mouse_button.position
	)
	if !m_is_drawing_rail:
		m_rail_start_local = snapped_local
		m_rail_end_local = snapped_local
		m_rail_start_screen_position = mouse_button.position
		m_rail_has_valid_preview = false
		m_rail_release_commits_preview = false
		m_is_drawing_rail = true
		_create_rail_preview(coordinator)
		_update_rail_preview(camera, mouse_button.position)
		m_context.set_status("Rail start captured. Drag and release, or click another point.")
		return m_context.handled()

	_commit_rail(coordinator, m_rail_start_local, snapped_local)
	_clear_rail_preview()
	_reset_rail_drawing_state()
	return m_context.handled()


func _create_rail_preview(coordinator: Building3DScript) -> void:
	_clear_rail_preview()
	m_rail_preview = Rail3DScript.new() as Rail3DScript
	m_rail_preview.name = "RailPreview"
	m_rail_preview.set_meta(Rail3DScript.PREVIEW_META, true)
	m_rail_preview.rail_height = float(m_rail_settings["height"])
	m_rail_preview.post_spacing = float(m_rail_settings["post_spacing"])
	m_rail_preview.infill_rail_thickness = float(m_rail_settings["infill_rail_thickness"])
	m_rail_preview.rail_thickness = float(m_rail_settings["rail_thickness"])
	m_rail_preview.infill_style = int(m_rail_settings.get("infill_style", 0))
	m_rail_preview.newel_post_count = int(m_rail_settings.get("newel_post_count", 2))
	m_rail_preview.infill_count_between_newels = int(
		m_rail_settings.get("infill_count_between_newels", 1)
	)
	m_rail_preview.newel_post_thickness = float(
		m_rail_settings.get("newel_post_thickness", 0.1)
	)
	m_rail_preview.lower_rail_height = float(m_rail_settings["lower_rail_height"])
	var preview_color := Color(m_rail_settings["color"])
	preview_color.a = 0.48
	m_rail_preview.rail_color = preview_color
	m_rail_preview.generate_collision = false
	coordinator.add_child(m_rail_preview)
	m_rail_preview.owner = null
	m_context.apply_debug_wireframe_to_node(m_rail_preview)


func _update_rail_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_rail_preview == null:
		return
	var coordinator := m_rail_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	m_rail_end_local = _rail_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_rail_has_valid_preview = _is_rail_span_long_enough(
		m_rail_start_local,
		m_rail_end_local
	)
	m_rail_preview.set_rail_points(m_rail_start_local, m_rail_end_local)
	if m_rail_has_valid_preview:
		m_context.set_status(
			"Release or click to place rail: %.2f units, %d posts."
			% [m_rail_preview.get_rail_length(), m_rail_preview.get_post_count()]
		)


func _rail_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := float(m_rail_settings.get("base_height", 0.0))
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_rail_local(
					local_origin + local_direction * distance_to_plane,
					base_y
				)
	var hit := m_context.raycast_world(camera, mouse_position, false)
	return _snap_rail_local(
		coordinator.to_local(Vector3(hit["position"])),
		base_y
	)


func _snap_rail_local(local_position: Vector3, base_y: float) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_rail_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _get_active_rail_coordinator() -> Building3DScript:
	if m_rail_preview != null and is_instance_valid(m_rail_preview):
		var preview_parent := m_rail_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return m_context.get_or_create_coordinator(false)


func _commit_rail(
	coordinator: Building3DScript,
	local_start: Vector3,
	local_end: Vector3
) -> void:
	if !_is_rail_span_long_enough(local_start, local_end):
		m_context.set_status("Rail is too short.")
		return
	var rail := BuildingFactoryScript.create_rail_node(
		coordinator,
		local_start,
		local_end,
		float(m_rail_settings["height"]),
		float(m_rail_settings["post_spacing"]),
		float(m_rail_settings["infill_rail_thickness"]),
		float(m_rail_settings["rail_thickness"]),
		float(m_rail_settings["lower_rail_height"]),
		Color(m_rail_settings["color"]),
		int(m_rail_settings.get("newel_post_count", 2)),
		int(m_rail_settings.get("infill_count_between_newels", 1)),
		float(m_rail_settings.get("newel_post_thickness", 0.1)),
		int(m_rail_settings.get("infill_style", 0))
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Rail")
	undo_redo.add_do_reference(rail)
	undo_redo.add_do_method(m_context, "do_add_node", coordinator, rail, scene_root, true)
	undo_redo.add_undo_method(m_context, "undo_remove_node", coordinator, rail)
	undo_redo.commit_action()
	m_context.set_status(
		"Created rail: %.2f units, %d posts."
		% [rail.get_rail_length(), rail.get_post_count()]
	)


func _handle_rail_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_rail_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed:
			_commit_rail_drag()
			return m_context.handled()
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_rail_drag()
			return m_context.handled()
	return m_context.handled()


func _start_rail_drag(
	rail: Rail3DScript,
	camera: Camera3D,
	mouse_position: Vector2,
	endpoint: int
) -> void:
	m_dragging_rail = rail
	m_drag_rail_old_start = rail.start_point
	m_drag_rail_old_end = rail.end_point
	m_drag_rail_endpoint = endpoint
	m_drag_rail_active_material = rail.material_override
	m_drag_rail_anchor_local = _rail_parent_local_from_mouse(
		rail,
		camera,
		mouse_position
	)
	rail.material_override = m_context.build_preview_material(_rail_drag_color(endpoint, true))
	m_context.select_node(rail)
	m_context.set_status(
		"Dragging rail endpoint - release to commit, Escape to cancel."
		if endpoint >= 0
		else "Dragging rail body - release to commit, Escape to cancel."
	)


func _update_rail_drag(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_dragging_rail == null or !is_instance_valid(m_dragging_rail):
		_reset_rail_drag_state()
		return
	var rail := m_dragging_rail
	var hit_local := _rail_parent_local_from_mouse(rail, camera, mouse_position)
	var new_start := m_drag_rail_old_start
	var new_end := m_drag_rail_old_end
	if m_drag_rail_endpoint < 0:
		var step := maxf(float(m_rail_settings["grid_step"]), 0.05)
		var raw_delta := hit_local - m_drag_rail_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start += snapped_delta
		new_end += snapped_delta
	elif m_drag_rail_endpoint == 0:
		new_start = _snap_rail_local(hit_local, m_drag_rail_old_start.y)
	else:
		new_end = _snap_rail_local(hit_local, m_drag_rail_old_start.y)
	rail.set_rail_points(new_start, new_end)
	var valid := _is_rail_span_long_enough(new_start, new_end)
	rail.material_override = m_context.build_preview_material(
		_rail_drag_color(m_drag_rail_endpoint, valid)
	)
	if valid:
		m_context.set_status("Release to commit rail: %.2f units." % rail.get_rail_length())
	else:
		m_context.set_status("Rail is too short.")


func _commit_rail_drag() -> void:
	if m_dragging_rail == null:
		return
	var rail := m_dragging_rail
	var old_start := m_drag_rail_old_start
	var old_end := m_drag_rail_old_end
	var new_start := rail.start_point
	var new_end := rail.end_point
	var endpoint := m_drag_rail_endpoint
	rail.material_override = m_drag_rail_active_material
	if !_is_rail_span_long_enough(new_start, new_end):
		rail.set_rail_points(old_start, old_end)
		_reset_rail_drag_state()
		m_context.set_status("Rail is too short.")
		return
	if (
		old_start.distance_to(new_start) <= 0.001
		and old_end.distance_to(new_end) <= 0.001
	):
		_reset_rail_drag_state()
		m_context.set_status("Rail unchanged.")
		return
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Move Rail" if endpoint < 0 else "Resize Rail")
	undo_redo.add_do_method(rail, "set_rail_points", new_start, new_end)
	undo_redo.add_do_method(m_context, "select_node", rail)
	undo_redo.add_undo_method(rail, "set_rail_points", old_start, old_end)
	undo_redo.commit_action()
	_reset_rail_drag_state()
	m_context.set_status("Edited rail: %.2f units." % rail.get_rail_length())


func _cancel_rail_drag() -> void:
	if m_dragging_rail == null:
		return
	if is_instance_valid(m_dragging_rail):
		m_dragging_rail.set_rail_points(
			m_drag_rail_old_start,
			m_drag_rail_old_end
		)
		m_dragging_rail.material_override = m_drag_rail_active_material
	_reset_rail_drag_state()
	m_context.set_status("Rail edit canceled.")


func _rail_parent_local_from_mouse(
	rail: Rail3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var parent_3d := rail.get_parent() as Node3D
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
			var distance_to_plane := (
				rail.start_point.y - local_origin.y
			) / local_direction.y
			if distance_to_plane > 0.0:
				return local_origin + local_direction * distance_to_plane
	return rail.start_point


func _is_rail_span_long_enough(local_start: Vector3, local_end: Vector3) -> bool:
	return (
		Vector2(
			local_end.x - local_start.x,
			local_end.z - local_start.z
		).length()
		>= maxf(float(m_rail_settings["grid_step"]) * 0.5, 0.1)
	)


func _rail_drag_color(endpoint: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if endpoint < 0:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _reset_rail_drag_state() -> void:
	m_dragging_rail = null
	m_drag_rail_old_start = Vector3.ZERO
	m_drag_rail_old_end = Vector3.ZERO
	m_drag_rail_anchor_local = Vector3.ZERO
	m_drag_rail_endpoint = -1
	m_drag_rail_active_material = null


func _find_rail_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var rails: Array[Rail3DScript] = []
	_collect_scene_rails(scene_root, rails)
	var best_hit: Dictionary = {}
	var best_distance := INF
	for rail in rails:
		if (
			!is_instance_valid(rail)
			or rail == m_rail_preview
			or rail.has_meta(Rail3DScript.PREVIEW_META)
		):
			continue
		var inverse_frame := rail.global_transform.affine_inverse()
		var local_origin := inverse_frame * origin
		var local_direction := inverse_frame.basis * direction
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()
		var hit := m_context.intersect_aabb_ray(
			local_origin,
			local_direction,
			rail.get_rail_bounds_min(),
			rail.get_rail_bounds_max()
		)
		if hit.is_empty():
			continue
		var local_hit := Vector3(hit["position"])
		var global_hit := rail.global_transform * local_hit
		var distance := origin.distance_to(global_hit)
		if distance >= best_distance:
			continue
		var endpoint_radius := maxf(
			float(m_rail_settings["grid_step"]) * 0.35,
			0.16
		)
		var endpoint := -1
		if absf(local_hit.x) <= endpoint_radius:
			endpoint = 0
		elif absf(local_hit.x - rail.get_rail_length()) <= endpoint_radius:
			endpoint = 1
		best_distance = distance
		best_hit = {
			"rail": rail,
			"position": global_hit,
			"local_position": local_hit,
			"endpoint": endpoint,
			"collider": rail,
			"distance": distance,
		}
	return best_hit


func _collect_scene_rails(node: Node, rails: Array[Rail3DScript]) -> void:
	if node is Rail3DScript:
		rails.append(node as Rail3DScript)
	for child in node.get_children():
		_collect_scene_rails(child, rails)


func _update_rail_hover(rail: Rail3DScript, endpoint: int) -> void:
	if rail == m_drag_rail_hover and endpoint == m_drag_rail_hover_endpoint:
		return
	_clear_rail_hover()
	if rail == null:
		return
	m_drag_rail_hover = rail
	m_drag_rail_hover_endpoint = endpoint
	m_drag_rail_hover_material = rail.material_override
	rail.material_override = m_context.build_preview_material(_rail_drag_color(endpoint, true))


func _clear_rail_hover() -> void:
	if m_drag_rail_hover == null:
		return
	if is_instance_valid(m_drag_rail_hover):
		m_drag_rail_hover.material_override = m_drag_rail_hover_material
	m_drag_rail_hover = null
	m_drag_rail_hover_material = null
	m_drag_rail_hover_endpoint = -1


func _clear_rail_preview() -> void:
	if m_rail_preview != null and is_instance_valid(m_rail_preview):
		m_rail_preview.queue_free()
	m_rail_preview = null


func _reset_rail_drawing_state() -> void:
	m_is_drawing_rail = false
	m_rail_has_valid_preview = false
	m_rail_release_commits_preview = false
	m_rail_start_screen_position = Vector2.ZERO
