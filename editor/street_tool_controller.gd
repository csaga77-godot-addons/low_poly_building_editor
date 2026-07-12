@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Street3DScript = preload("res://addons/low_poly_building_editor/streets/street_3d.gd")

var m_street_settings := {
	"grid_step": 0.5,
	"base_height": 0.0,
	"road_width": 3.2,
	"road_thickness": 0.18,
	"road_color": Color(0.38, 0.37, 0.34, 1.0),
	"kerb_width": 0.18,
	"kerb_height": 0.14,
	"kerb_color": Color(0.66, 0.64, 0.59, 1.0),
	"footpath_width": 1.1,
	"footpath_thickness": 0.16,
	"footpath_color": Color(0.72, 0.67, 0.57, 1.0),
	"stair_threshold_degrees": 25.0,
	"target_riser_height": 0.16,
	"max_riser_height": 0.18,
	"min_tread_depth": 0.24,
	"terrain_sample_spacing": 0.5,
	"terrain_clearance": 0.025,
}
var m_path_points := PackedVector3Array()
var m_hover_point := Vector3.ZERO
var m_preview: Street3DScript


func apply_settings(settings: Dictionary) -> void:
	m_street_settings = settings.duplicate(true)
	if m_preview != null:
		_clear_preview()
	_update_preview()


func cancel_preview() -> void:
	_clear_preview()
	m_path_points = PackedVector3Array()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and !key_event.echo and key_event.keycode == KEY_ENTER:
			if m_path_points.size() >= 2:
				_commit_path()
				return m_context.handled()
		if key_event.pressed and !key_event.echo and key_event.keycode == KEY_BACKSPACE:
			if !m_path_points.is_empty():
				m_path_points.resize(m_path_points.size() - 1)
				_update_preview()
				return m_context.handled()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		var coordinator := m_context.get_or_create_coordinator(false)
		if coordinator != null and !m_path_points.is_empty():
			m_hover_point = _local_from_mouse(coordinator, camera, (event as InputEventMouseMotion).position)
			_update_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing a street.")
		return m_context.handled()
	if mouse_button.double_click and m_path_points.size() >= 2:
		_commit_path()
		return m_context.handled()
	var point := _local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_path_points.is_empty() and point.distance_to(m_path_points[-1]) <= 0.001:
		return m_context.handled()
	m_path_points.append(point)
	m_hover_point = point
	_update_preview()
	m_context.set_status(
		"Street point %d added. Click for another bend; double-click or Enter to finish."
		% m_path_points.size()
	)
	return m_context.handled()


func resample_selected_street() -> void:
	var street := _selected_street()
	if street == null:
		m_context.set_status("Select a Street3D before resampling terrain.")
		return
	var provider := _find_terrain_provider()
	if provider == null:
		m_context.set_status("No terrain height provider was found in the edited scene.")
		return
	var old_state := street.capture_native_transform_state()
	var errors: Array[String] = []
	if _is_integrated_terrain_provider(provider):
		provider.call("rebuild_from_source")
		errors = _terrain_integration_errors(provider)
	else:
		errors = street.resample_terrain(provider)
	if !errors.is_empty():
		street.restore_native_transform_state(old_state)
		m_context.set_status(String(errors[0]))
		return
	var new_state := street.capture_native_transform_state()
	var undo := m_context.undo_redo()
	undo.create_action("Resample Street Terrain")
	undo.add_do_method(street, "restore_native_transform_state", new_state)
	undo.add_undo_method(street, "restore_native_transform_state", old_state)
	undo.commit_action()
	m_context.set_status("Resampled %d street profile points; manual heights were preserved." % street.profile_points.size())


func _local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	var base_height := float(m_street_settings.get("base_height", 0.0))
	var point := Vector3.ZERO
	if absf(local_direction.y) > 0.001:
		var distance := (base_height - local_origin.y) / local_direction.y
		point = local_origin + local_direction * maxf(distance, 0.0)
	else:
		point = coordinator.to_local(origin + direction * 12.0)
	point = BuildingFactoryScript.snap_local_position(
		point, float(m_street_settings.get("grid_step", 0.5))
	)
	point.y = base_height
	return point


func _update_preview() -> void:
	if m_path_points.is_empty():
		_clear_preview()
		return
	var coordinator := m_context.get_or_create_coordinator(false)
	if coordinator == null:
		return
	var preview_points := m_path_points.duplicate()
	if m_hover_point.distance_to(preview_points[-1]) > 0.001:
		preview_points.append(m_hover_point)
	if preview_points.size() < 2:
		return
	if m_preview == null:
		m_preview = BuildingFactoryScript.create_street_node(
			coordinator, preview_points, _preview_settings()
		)
		m_preview.name = "StreetPreview"
		m_preview.set_meta(Street3DScript.PREVIEW_META, true)
		m_preview.generate_collision = false
		coordinator.add_child(m_preview)
		m_preview.owner = null
		m_context.apply_debug_wireframe_to_node(m_preview)
	else:
		m_preview.set_path_points(preview_points)


func _preview_settings() -> Dictionary:
	var settings := m_street_settings.duplicate(true)
	for key in ["road_color", "kerb_color", "footpath_color"]:
		var color := Color(settings[key])
		color.a = 0.55
		settings[key] = color
	settings["generate_collision"] = false
	return settings


func _commit_path() -> void:
	if m_path_points.size() < 2:
		return
	var coordinator := m_context.get_or_create_coordinator(false)
	if coordinator == null:
		return
	var street := BuildingFactoryScript.create_street_node(
		coordinator, m_path_points, m_street_settings
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo := m_context.undo_redo()
	undo.create_action("Create Street")
	undo.add_do_reference(street)
	undo.add_do_method(m_context, "do_add_node", coordinator, street, scene_root, true)
	undo.add_undo_method(m_context, "undo_remove_node", coordinator, street)
	undo.commit_action()
	var provider := _find_terrain_provider()
	if provider != null:
		var errors: Array[String] = []
		if _is_integrated_terrain_provider(provider):
			provider.call("rebuild_from_source")
			errors = _terrain_integration_errors(provider)
		else:
			var unsampled_state := street.capture_native_transform_state()
			errors = street.resample_terrain(provider)
			if !errors.is_empty():
				street.restore_native_transform_state(unsampled_state)
		if !errors.is_empty():
			m_context.set_status("Created street; terrain sampling failed: %s" % errors[0])
		else:
			m_context.set_status("Created terrain-profiled street with %d samples." % street.profile_points.size())
	else:
		m_context.set_status("Created street without terrain sampling; no height provider was found.")
	_clear_preview()
	m_path_points = PackedVector3Array()


func _clear_preview() -> void:
	if m_preview != null and is_instance_valid(m_preview):
		m_preview.free()
	m_preview = null


func _selected_street() -> Street3DScript:
	var selection := m_context.editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		if node is Street3DScript:
			return node as Street3DScript
	return null


func _find_terrain_provider() -> Node3D:
	var root := m_context.editor_interface().get_edited_scene_root()
	return _find_terrain_provider_below(root)


func _find_terrain_provider_below(node: Node) -> Node3D:
	if node == null:
		return null
	if node is Node3D and node.has_method("get_world_surface_height"):
		return node as Node3D
	for child in node.get_children():
		var found := _find_terrain_provider_below(child)
		if found != null:
			return found
	return null


func _is_integrated_terrain_provider(provider: Node3D) -> bool:
	return (
		provider != null
		and provider.has_method("request_street_integration_rebuild")
		and provider.has_method("rebuild_from_source")
	)


func _terrain_integration_errors(provider: Node3D) -> Array[String]:
	var result: Array[String] = []
	if provider == null or !provider.has_method("get_street_integration_summary"):
		return result
	var summary: Dictionary = provider.call("get_street_integration_summary")
	var errors: Variant = summary.get("errors", [])
	if errors is Array:
		for error in errors:
			result.append(String(error))
	return result
