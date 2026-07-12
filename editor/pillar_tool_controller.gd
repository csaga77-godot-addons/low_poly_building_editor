@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Pillar tool controller — owns the pillar dock settings, placement preview,
## hover highlight, and move/resize drag editing (stage 3 of the plugin
## split). Undo/redo actions bind the plugin-lifetime context, never
## per-gesture objects.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillars/pillar_3d.gd")

const PILLAR_EDIT_MOVE := 0
const PILLAR_EDIT_RADIUS := 1

var m_pillar_settings := {
	"grid_step": 0.5,
	"style": "round",
	"base_height": 0.0,
	"radius": 0.25,
	"upper_radius": 0.0,
	"height": 2.4,
	"sides": 8,
	"lower_rim_height": 0.12,
	"lower_rim_outset": 0.05,
	"upper_rim_height": 0.12,
	"upper_rim_outset": 0.05,
	"color": Color(0.70, 0.64, 0.52, 1.0),
}
var m_pillar_preview: Pillar3DScript
var m_pillar_preview_valid := false
var m_dragging_pillar: Pillar3DScript
var m_drag_pillar_old_base := Vector3.ZERO
var m_drag_pillar_old_radius := 0.0
var m_drag_pillar_old_upper_radius := 0.0
var m_drag_pillar_anchor_local := Vector3.ZERO
var m_drag_pillar_edit_mode := PILLAR_EDIT_MOVE
var m_drag_pillar_active_material: Material
var m_drag_pillar_hover: Pillar3DScript
var m_drag_pillar_hover_material: Material
var m_drag_pillar_hover_edit_mode := PILLAR_EDIT_MOVE


func apply_settings(settings: Dictionary) -> void:
	m_pillar_settings = settings.duplicate(true)
	_clear_pillar_preview()


func cancel_preview() -> void:
	_cancel_pillar_drag()
	_clear_pillar_hover()
	_clear_pillar_preview()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_pillar != null:
		return _handle_pillar_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		var pillar_pick := _find_pillar_pick(camera, mouse_pos)
		var hover_pillar := pillar_pick.get("pillar") as Pillar3DScript
		var edit_mode := int(pillar_pick.get("edit_mode", PILLAR_EDIT_MOVE))
		_update_pillar_hover(hover_pillar, edit_mode)
		if hover_pillar != null:
			_clear_pillar_preview()
			m_context.set_status(
				"Drag pillar edge to resize radius." if edit_mode == PILLAR_EDIT_RADIUS
				else "Drag pillar body to move."
			)
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_update_pillar_preview(camera, mouse_pos, false)
		return m_context.handled() if m_pillar_preview != null else EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var pillar_pick := _find_pillar_pick(camera, mouse_button.position)
	var hit_pillar := pillar_pick.get("pillar") as Pillar3DScript
	if hit_pillar != null:
		_clear_pillar_preview()
		_clear_pillar_hover()
		_start_pillar_drag(
			hit_pillar,
			camera,
			mouse_button.position,
			int(pillar_pick.get("edit_mode", PILLAR_EDIT_MOVE))
		)
		return m_context.handled()

	_update_pillar_preview(camera, mouse_button.position, true)
	if m_pillar_preview_valid:
		_commit_pillar()
	return m_context.handled()


func _create_pillar_preview(coordinator: Building3DScript) -> void:
	_clear_pillar_preview()
	m_pillar_preview = BuildingFactoryScript.instantiate_pillar_style(
		String(m_pillar_settings["style"])
	)
	m_pillar_preview.name = "PillarPreview"
	m_pillar_preview.set_meta(Pillar3DScript.PREVIEW_META, true)
	m_pillar_preview.pillar_radius = float(m_pillar_settings["radius"])
	m_pillar_preview.upper_radius = float(m_pillar_settings["upper_radius"])
	m_pillar_preview.pillar_height = float(m_pillar_settings["height"])
	if m_pillar_preview.get_pillar_style() == "round" or m_pillar_preview.get_pillar_style() == "tapered":
		m_pillar_preview.set(&"side_count", int(m_pillar_settings["sides"]))
	m_pillar_preview.set_pillar_rims(
		float(m_pillar_settings["lower_rim_height"]),
		float(m_pillar_settings["lower_rim_outset"]),
		float(m_pillar_settings["upper_rim_height"]),
		float(m_pillar_settings["upper_rim_outset"])
	)
	var preview_color := Color(m_pillar_settings["color"])
	preview_color.a = 0.48
	m_pillar_preview.pillar_color = preview_color
	m_pillar_preview.generate_collision = false
	coordinator.add_child(m_pillar_preview)
	m_pillar_preview.owner = null
	m_context.apply_debug_wireframe_to_node(m_pillar_preview)


func _update_pillar_preview(camera: Camera3D, mouse_position: Vector2, create_if_missing: bool) -> void:
	var coordinator := m_context.get_or_create_coordinator(create_if_missing)
	if coordinator == null:
		_clear_pillar_preview()
		m_pillar_preview_valid = false
		m_context.set_status("Click to create a coordinator and place a pillar." if create_if_missing else "Move over the scene, then click to place a pillar.")
		return
	if m_pillar_preview == null:
		_create_pillar_preview(coordinator)
	elif m_pillar_preview.get_pillar_style() != String(m_pillar_settings["style"]):
		_create_pillar_preview(coordinator)
	var local_base := _pillar_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_pillar_preview.set_pillar_base_position(local_base)
	m_pillar_preview.pillar_radius = float(m_pillar_settings["radius"])
	m_pillar_preview.upper_radius = float(m_pillar_settings["upper_radius"])
	m_pillar_preview.pillar_height = float(m_pillar_settings["height"])
	if m_pillar_preview.get_pillar_style() == "round" or m_pillar_preview.get_pillar_style() == "tapered":
		m_pillar_preview.set(&"side_count", int(m_pillar_settings["sides"]))
	m_pillar_preview.set_pillar_rims(
		float(m_pillar_settings["lower_rim_height"]),
		float(m_pillar_settings["lower_rim_outset"]),
		float(m_pillar_settings["upper_rim_height"]),
		float(m_pillar_settings["upper_rim_outset"])
	)
	m_pillar_preview_valid = _is_pillar_radius_valid(m_pillar_preview.pillar_radius)
	m_context.set_status("Click to place pillar." if m_pillar_preview_valid else "Pillar radius is too small.")


func _pillar_base_height() -> float:
	return float(m_pillar_settings.get("base_height", 0.0))


func _pillar_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _pillar_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_pillar_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := m_context.raycast_world(camera, mouse_position, false)
	return _snap_pillar_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_pillar_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_pillar_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _commit_pillar() -> void:
	if m_pillar_preview == null:
		return
	var coordinator := m_pillar_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	if !_is_pillar_radius_valid(m_pillar_preview.pillar_radius):
		m_context.set_status("Pillar radius is too small.")
		return

	var pillar := BuildingFactoryScript.create_pillar_node(coordinator,
		m_pillar_preview.base_point,
		float(m_pillar_settings["radius"]),
		float(m_pillar_settings["height"]),
		int(m_pillar_settings["sides"]),
		String(m_pillar_settings["style"]),
		Color(m_pillar_settings["color"]),
		float(m_pillar_settings["lower_rim_height"]),
		float(m_pillar_settings["lower_rim_outset"]),
		float(m_pillar_settings["upper_rim_height"]),
		float(m_pillar_settings["upper_rim_outset"]),
		float(m_pillar_settings["upper_radius"])
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Pillar")
	undo_redo.add_do_reference(pillar)
	undo_redo.add_do_method(m_context, "do_add_node", coordinator, pillar, scene_root, true)
	undo_redo.add_undo_method(m_context, "undo_remove_node", coordinator, pillar)
	undo_redo.commit_action()
	m_context.set_status("Created pillar.")


func _handle_pillar_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_pillar_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_pillar_drag()
			return m_context.handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_pillar_drag()
			return m_context.handled()
	return m_context.handled()


func _start_pillar_drag(
	pillar: Pillar3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mode: int
) -> void:
	m_dragging_pillar = pillar
	m_drag_pillar_old_base = pillar.base_point
	m_drag_pillar_old_radius = pillar.pillar_radius
	m_drag_pillar_old_upper_radius = pillar.upper_radius
	m_drag_pillar_edit_mode = edit_mode
	m_drag_pillar_active_material = pillar.material_override
	m_drag_pillar_anchor_local = _pillar_plane_local_from_mouse(pillar, camera, mouse_pos)
	pillar.material_override = m_context.build_preview_material(_pillar_drag_color(edit_mode, true))
	m_context.select_node(pillar)
	m_context.set_status("Dragging pillar %s - release to commit, Escape to cancel." % _pillar_edit_label(edit_mode))


func _update_pillar_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_pillar == null or !is_instance_valid(m_dragging_pillar):
		_reset_pillar_drag_state()
		return
	var pillar := m_dragging_pillar
	var hit_local := _pillar_plane_local_from_mouse(pillar, camera, mouse_pos)
	if m_drag_pillar_edit_mode == PILLAR_EDIT_RADIUS:
		var raw_radius := Vector2(hit_local.x - pillar.base_point.x, hit_local.z - pillar.base_point.z).length()
		var new_lower_radius := _snap_pillar_radius(pillar, raw_radius)
		var new_upper_radius := m_drag_pillar_old_upper_radius
		if new_upper_radius > 0.0001 and m_drag_pillar_old_radius > 0.0001:
			new_upper_radius = maxf(0.05, new_upper_radius * new_lower_radius / m_drag_pillar_old_radius)
		pillar.set_pillar_radii(new_lower_radius, new_upper_radius)
	else:
		var step := _active_pillar_grid_step(pillar)
		var raw_delta := hit_local - m_drag_pillar_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		pillar.set_pillar_base_position(m_drag_pillar_old_base + snapped_delta)
	var valid := _is_pillar_radius_valid(pillar.pillar_radius)
	pillar.material_override = m_context.build_preview_material(_pillar_drag_color(m_drag_pillar_edit_mode, valid))
	m_context.set_status(
		"Release to commit pillar %s." % _pillar_edit_label(m_drag_pillar_edit_mode)
		if valid
		else "Pillar radius is too small."
	)


func _commit_pillar_drag() -> void:
	if m_dragging_pillar == null:
		return
	var pillar := m_dragging_pillar
	var old_base := m_drag_pillar_old_base
	var old_radius := m_drag_pillar_old_radius
	var old_upper_radius := m_drag_pillar_old_upper_radius
	var new_base := pillar.base_point
	var new_radius := pillar.pillar_radius
	var new_upper_radius := pillar.upper_radius
	var edit_mode := m_drag_pillar_edit_mode
	pillar.material_override = m_drag_pillar_active_material
	if !_is_pillar_radius_valid(new_radius):
		pillar.set_pillar_base_and_radii(old_base, old_radius, old_upper_radius)
		_reset_pillar_drag_state()
		m_context.set_status("Pillar radius is too small.")
		return
	if (
		old_base.distance_to(new_base) <= 0.001
		and is_equal_approx(old_radius, new_radius)
		and is_equal_approx(old_upper_radius, new_upper_radius)
	):
		_reset_pillar_drag_state()
		m_context.set_status("Pillar unchanged.")
		return

	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Move Pillar" if edit_mode == PILLAR_EDIT_MOVE else "Resize Pillar")
	undo_redo.add_do_method(pillar, "set_pillar_base_and_radii", new_base, new_radius, new_upper_radius)
	undo_redo.add_do_method(m_context, "select_node", pillar)
	undo_redo.add_undo_method(pillar, "set_pillar_base_and_radii", old_base, old_radius, old_upper_radius)
	undo_redo.commit_action()
	_reset_pillar_drag_state()
	m_context.set_status("Edited pillar.")


func _cancel_pillar_drag() -> void:
	if m_dragging_pillar == null:
		return
	if is_instance_valid(m_dragging_pillar):
		m_dragging_pillar.set_pillar_base_and_radii(
			m_drag_pillar_old_base,
			m_drag_pillar_old_radius,
			m_drag_pillar_old_upper_radius
		)
		m_dragging_pillar.material_override = m_drag_pillar_active_material
	_reset_pillar_drag_state()
	m_context.set_status("Pillar edit canceled.")


func _pillar_plane_local_from_mouse(
	pillar: Pillar3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var parent_3d := pillar.get_parent() as Node3D
	var base_y := pillar.base_point.y
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
	return pillar.base_point


func _snap_pillar_radius(pillar: Pillar3DScript, radius: float) -> float:
	var step := maxf(_active_pillar_grid_step(pillar) * 0.5, 0.05)
	return maxf(roundf(radius / step) * step, 0.05)


func _pillar_drag_color(edit_mode: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	return Color(1.0, 0.85, 0.20, 0.72) if edit_mode == PILLAR_EDIT_RADIUS else Color(0.20, 0.60, 1.0, 0.55)


func _pillar_edit_label(edit_mode: int) -> String:
	return "radius" if edit_mode == PILLAR_EDIT_RADIUS else "body"


func _active_pillar_grid_step(_pillar: Pillar3DScript) -> float:
	return maxf(float(m_pillar_settings["grid_step"]), 0.05)


func _is_pillar_radius_valid(radius: float) -> bool:
	return radius >= maxf(float(m_pillar_settings["grid_step"]) * 0.1, 0.05)


func _reset_pillar_drag_state() -> void:
	m_dragging_pillar = null
	m_drag_pillar_old_base = Vector3.ZERO
	m_drag_pillar_old_radius = 0.0
	m_drag_pillar_old_upper_radius = 0.0
	m_drag_pillar_anchor_local = Vector3.ZERO
	m_drag_pillar_edit_mode = PILLAR_EDIT_MOVE
	m_drag_pillar_active_material = null


func _find_pillar_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_pillars(origin, direction)
	if hit.is_empty():
		return {}
	var pillar := hit.get("pillar") as Pillar3DScript
	if pillar == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mode"] = _pillar_edit_mode_for_local_hit(pillar, local_position)
	return hit


func _raycast_pillars(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var pillars: Array[Pillar3DScript] = []
	_collect_scene_pillars(scene_root, pillars)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for pillar in pillars:
		if !is_instance_valid(pillar) or pillar == m_pillar_preview:
			continue
		if pillar.has_meta(Pillar3DScript.PREVIEW_META):
			continue
		var hit := _intersect_pillar_cylinder(pillar, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_pillars(node: Node, pillars: Array[Pillar3DScript]) -> void:
	if node is Pillar3DScript:
		pillars.append(node as Pillar3DScript)
	for child in node.get_children():
		_collect_scene_pillars(child, pillars)


func _intersect_pillar_cylinder(
	pillar: Pillar3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var pick_radius := pillar.get_outer_radius()
	if pick_radius <= 0.001 or pillar.pillar_height <= 0.001:
		return {}
	var inverse_frame := pillar.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var candidates: Array[Dictionary] = []
	var a := local_direction.x * local_direction.x + local_direction.z * local_direction.z
	if a > 0.000001:
		var b := 2.0 * (local_origin.x * local_direction.x + local_origin.z * local_direction.z)
		var c := (
			local_origin.x * local_origin.x
			+ local_origin.z * local_origin.z
			- pick_radius * pick_radius
		)
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var sqrt_discriminant := sqrt(discriminant)
			_append_pillar_side_hit_candidate(candidates, pillar, local_origin, local_direction, (-b - sqrt_discriminant) / (2.0 * a))
			_append_pillar_side_hit_candidate(candidates, pillar, local_origin, local_direction, (-b + sqrt_discriminant) / (2.0 * a))

	if absf(local_direction.y) > 0.000001:
		_append_pillar_cap_hit_candidate(candidates, pillar, local_origin, local_direction, 0.0, Vector3.DOWN)
		_append_pillar_cap_hit_candidate(candidates, pillar, local_origin, local_direction, pillar.pillar_height, Vector3.UP)

	if candidates.is_empty():
		return {}

	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if float(candidate["t"]) < float(best["t"]):
			best = candidate
	var local_hit := Vector3(best["position"])
	var local_normal := Vector3(best["normal"])
	var global_hit := pillar.global_transform * local_hit
	return {
		"pillar": pillar,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (pillar.global_transform.basis * local_normal).normalized(),
		"collider": pillar,
		"distance": origin.distance_to(global_hit),
	}


func _append_pillar_side_hit_candidate(
	candidates: Array[Dictionary],
	pillar: Pillar3DScript,
	local_origin: Vector3,
	local_direction: Vector3,
	t: float
) -> void:
	if t < 0.0:
		return
	var hit_position := local_origin + local_direction * t
	if hit_position.y < 0.0 or hit_position.y > pillar.pillar_height:
		return
	var normal := Vector3(hit_position.x, 0.0, hit_position.z)
	if normal.length_squared() <= 0.000001:
		return
	candidates.append({
		"t": t,
		"position": hit_position,
		"normal": normal.normalized(),
	})


func _append_pillar_cap_hit_candidate(
	candidates: Array[Dictionary],
	pillar: Pillar3DScript,
	local_origin: Vector3,
	local_direction: Vector3,
	cap_y: float,
	normal: Vector3
) -> void:
	var t := (cap_y - local_origin.y) / local_direction.y
	if t < 0.0:
		return
	var hit_position := local_origin + local_direction * t
	var radius_sq := hit_position.x * hit_position.x + hit_position.z * hit_position.z
	var pick_radius := pillar.get_outer_radius()
	if radius_sq > pick_radius * pick_radius:
		return
	candidates.append({
		"t": t,
		"position": hit_position,
		"normal": normal,
	})


func _pillar_edit_mode_for_local_hit(pillar: Pillar3DScript, local_hit: Vector3) -> int:
	var radius := Vector2(local_hit.x, local_hit.z).length()
	var edge_tolerance := maxf(_active_pillar_grid_step(pillar) * 0.25, 0.08)
	if (
		absf(pillar.pillar_radius - radius) <= edge_tolerance
		or absf(pillar.get_outer_radius() - radius) <= edge_tolerance
	):
		return PILLAR_EDIT_RADIUS
	return PILLAR_EDIT_MOVE


func _update_pillar_hover(pillar: Pillar3DScript, edit_mode: int) -> void:
	if pillar == m_drag_pillar_hover and edit_mode == m_drag_pillar_hover_edit_mode:
		return
	_clear_pillar_hover()
	if pillar == null:
		return
	m_drag_pillar_hover = pillar
	m_drag_pillar_hover_edit_mode = edit_mode
	m_drag_pillar_hover_material = pillar.material_override
	pillar.material_override = m_context.build_preview_material(_pillar_drag_color(edit_mode, true))


func _clear_pillar_hover() -> void:
	if m_drag_pillar_hover == null:
		return
	if is_instance_valid(m_drag_pillar_hover):
		m_drag_pillar_hover.material_override = m_drag_pillar_hover_material
	m_drag_pillar_hover = null
	m_drag_pillar_hover_material = null
	m_drag_pillar_hover_edit_mode = PILLAR_EDIT_MOVE


func _clear_pillar_preview() -> void:
	if m_pillar_preview != null and is_instance_valid(m_pillar_preview):
		m_pillar_preview.queue_free()
	m_pillar_preview = null
	m_pillar_preview_valid = false
