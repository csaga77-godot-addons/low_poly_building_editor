@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Street3DScript = preload("res://addons/low_poly_building_editor/streets/street_3d.gd")
const StreetNetwork3DScript = preload(
	"res://addons/low_poly_building_editor/streets/street_network_3d.gd"
)
const StreetSectionProfileScript = preload(
	"res://addons/low_poly_building_editor/streets/street_section_profile.gd"
)

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
var m_drag_network: StreetNetwork3DScript
var m_drag_junction_id := ""
var m_drag_old_state: StreetNetworkData
var m_drag_moved := false


func apply_settings(settings: Dictionary) -> void:
	m_street_settings = settings.duplicate(true)
	if m_preview != null:
		_clear_preview()
	_update_preview()


func cancel_preview() -> void:
	if m_drag_network != null and m_drag_old_state != null:
		m_drag_network.restore_network_state(m_drag_old_state)
	m_drag_network = null
	m_drag_junction_id = ""
	m_drag_old_state = null
	m_drag_moved = false
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
		if coordinator != null:
			var point := _local_from_mouse(
				coordinator, camera, (event as InputEventMouseMotion).position
			)
			if m_drag_network != null and !m_drag_junction_id.is_empty():
				var dragged_junction := m_drag_network.network_data.find_junction(
					m_drag_junction_id
				)
				if dragged_junction != null:
					point.y = dragged_junction.position.y
				m_drag_moved = m_drag_network.move_junction(m_drag_junction_id, point) or m_drag_moved
				m_context.set_status("Moving street junction %s." % m_drag_junction_id)
				return m_context.handled()
			if !m_path_points.is_empty():
				m_hover_point = point
			_update_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if !mouse_button.pressed and m_drag_network != null:
		_finish_junction_drag()
		return m_context.handled()
	if !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing a street.")
		return m_context.handled()
	if mouse_button.double_click and m_path_points.size() >= 2:
		_commit_path()
		return m_context.handled()
	var point := _local_from_mouse(coordinator, camera, mouse_button.position)
	if m_path_points.is_empty():
		var network := _network_for_edit(coordinator)
		if network != null and _begin_network_edit(network, point, mouse_button):
			return m_context.handled()
	if !m_path_points.is_empty():
		var active_network := _network_for_edit(coordinator)
		if active_network != null:
			var snapped := active_network.find_nearest_junction(
				point, float(m_street_settings.get("grid_step", 0.5)) * 0.75
			)
			if !snapped.is_empty():
				point = snapped["position"]
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
	var source: Node = _selected_street_source()
	if source == null:
		m_context.set_status("Select a StreetNetwork3D or Street3D before resampling terrain.")
		return
	var provider := _find_terrain_provider()
	if provider == null:
		m_context.set_status("No terrain height provider was found in the edited scene.")
		return
	var old_state: Variant = (
		source.capture_network_state()
		if source is StreetNetwork3DScript
		else source.capture_native_transform_state()
	)
	var errors: Array[String] = []
	if _is_integrated_terrain_provider(provider):
		provider.call("rebuild_from_source")
		errors = _terrain_integration_errors(provider)
	else:
		errors = source.call("resample_terrain", provider)
	if !errors.is_empty():
		_restore_street_source_state(source, old_state)
		m_context.set_status(String(errors[0]))
		return
	var new_state: Variant = (
		source.capture_network_state()
		if source is StreetNetwork3DScript
		else source.capture_native_transform_state()
	)
	var undo := m_context.undo_redo()
	undo.create_action("Resample Street Terrain")
	if source is StreetNetwork3DScript:
		undo.add_do_method(source, "restore_network_state", new_state)
		undo.add_undo_method(source, "restore_network_state", old_state)
	else:
		undo.add_do_method(source, "restore_native_transform_state", new_state)
		undo.add_undo_method(source, "restore_native_transform_state", old_state)
	undo.commit_action()
	if source is StreetNetwork3DScript:
		m_context.set_status("Resampled the selected street network terrain profiles.")
	else:
		m_context.set_status(
			"Resampled %d street profile points; manual heights were preserved."
			% source.profile_points.size()
		)


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
	var network := _network_for_edit(coordinator)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo := m_context.undo_redo()
	if network == null:
		network = BuildingFactoryScript.create_street_network_node(coordinator)
		network.add_path(m_path_points, _section_profile(), &"editor", true)
		undo.create_action("Create Street Network")
		undo.add_do_reference(network)
		undo.add_do_method(m_context, "do_add_node", coordinator, network, scene_root, true)
		undo.add_undo_method(m_context, "undo_remove_node", coordinator, network)
		undo.commit_action()
	else:
		var old_state := network.capture_network_state()
		network.add_path(m_path_points, _section_profile(), &"editor", true)
		var new_state := network.capture_network_state()
		undo.create_action("Create Street Network Path")
		undo.add_do_method(network, "restore_network_state", new_state)
		undo.add_undo_method(network, "restore_network_state", old_state)
		undo.commit_action()
	var provider := _find_terrain_provider()
	if provider != null:
		var errors: Array[String] = []
		if _is_integrated_terrain_provider(provider):
			provider.call("rebuild_from_source")
			errors = _terrain_integration_errors(provider)
		else:
			var unsampled_state := network.capture_network_state()
			errors = network.resample_terrain(provider)
			if !errors.is_empty():
				network.restore_network_state(unsampled_state)
		if !errors.is_empty():
			m_context.set_status("Created street; terrain sampling failed: %s" % errors[0])
		else:
			m_context.set_status("Created a terrain-profiled street-network segment.")
	else:
		m_context.set_status("Created a street-network segment without terrain sampling.")
	_clear_preview()
	m_path_points = PackedVector3Array()


func _clear_preview() -> void:
	if m_preview != null and is_instance_valid(m_preview):
		m_preview.free()
	m_preview = null


func _selected_street_source() -> Node:
	var selection := m_context.editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		if node is StreetNetwork3DScript:
			return node
		if node is Street3DScript:
			var parent := node.get_parent()
			if parent is StreetNetwork3DScript:
				return parent
			return node
	return null


func _network_for_edit(coordinator: Building3DScript) -> StreetNetwork3DScript:
	var selected := _selected_street_source()
	if selected is StreetNetwork3DScript and selected.get_parent() == coordinator:
		return selected as StreetNetwork3DScript
	for child in coordinator.get_children():
		if child is StreetNetwork3DScript:
			return child as StreetNetwork3DScript
	return null


func _section_profile() -> StreetSectionProfileScript:
	var profile := StreetSectionProfileScript.new() as StreetSectionProfileScript
	profile.road_width = float(m_street_settings.get("road_width", 3.2))
	profile.road_thickness = float(m_street_settings.get("road_thickness", 0.18))
	profile.road_color = Color(m_street_settings.get("road_color", Color(0.38, 0.37, 0.34, 1.0)))
	profile.left_kerb_width = float(m_street_settings.get("kerb_width", 0.18))
	profile.right_kerb_width = profile.left_kerb_width
	profile.kerb_height = float(m_street_settings.get("kerb_height", 0.14))
	profile.kerb_color = Color(m_street_settings.get("kerb_color", Color(0.66, 0.64, 0.59, 1.0)))
	profile.left_footpath_width = float(m_street_settings.get("footpath_width", 1.1))
	profile.right_footpath_width = profile.left_footpath_width
	profile.footpath_thickness = float(m_street_settings.get("footpath_thickness", 0.16))
	profile.footpath_color = Color(m_street_settings.get("footpath_color", Color(0.72, 0.67, 0.57, 1.0)))
	profile.stair_threshold_degrees = float(m_street_settings.get("stair_threshold_degrees", 25.0))
	profile.stair_exit_threshold_degrees = minf(profile.stair_threshold_degrees, 22.0)
	profile.target_riser_height = float(m_street_settings.get("target_riser_height", 0.16))
	profile.max_riser_height = float(m_street_settings.get("max_riser_height", 0.18))
	profile.min_tread_depth = float(m_street_settings.get("min_tread_depth", 0.24))
	profile.terrain_clearance = float(m_street_settings.get("terrain_clearance", 0.025))
	return profile


func _begin_network_edit(
	network: StreetNetwork3DScript,
	point: Vector3,
	mouse_button: InputEventMouseButton
) -> bool:
	var pick_distance := float(m_street_settings.get("grid_step", 0.5)) * 0.75
	var junction := network.find_nearest_junction(point, pick_distance)
	if mouse_button.alt_pressed and !junction.is_empty():
		var old_state := network.capture_network_state()
		if !network.remove_junction(String(junction["junction_id"])):
			return true
		_commit_network_state_action(network, old_state, "Remove Street Junction")
		m_context.set_status("Removed the junction and its connected segments.")
		return true
	if mouse_button.shift_pressed:
		var segment := network.find_nearest_segment(point, pick_distance)
		if segment.is_empty():
			return false
		var old_state := network.capture_network_state()
		var junction_id := network.split_segment(
			String(segment["segment_id"]), Vector3(segment["position"])
		)
		if junction_id.is_empty():
			return true
		_commit_network_state_action(network, old_state, "Split Street Segment")
		m_context.set_status("Split the street segment at junction %s." % junction_id)
		return true
	if !junction.is_empty() and !mouse_button.ctrl_pressed and !mouse_button.meta_pressed:
		m_drag_network = network
		m_drag_junction_id = String(junction["junction_id"])
		m_drag_old_state = network.capture_network_state()
		m_drag_moved = false
		return true
	return false


func _finish_junction_drag() -> void:
	if m_drag_network == null:
		return
	if m_drag_moved and m_drag_old_state != null:
		_commit_network_state_action(
			m_drag_network, m_drag_old_state, "Move Street Junction"
		)
		m_context.set_status("Moved street junction %s." % m_drag_junction_id)
	m_drag_network = null
	m_drag_junction_id = ""
	m_drag_old_state = null
	m_drag_moved = false


func _commit_network_state_action(
	network: StreetNetwork3DScript,
	old_state: StreetNetworkData,
	action_name: String
) -> void:
	var new_state := network.capture_network_state()
	var undo := m_context.undo_redo()
	undo.create_action(action_name)
	undo.add_do_method(network, "restore_network_state", new_state)
	undo.add_undo_method(network, "restore_network_state", old_state)
	undo.commit_action()


func _restore_street_source_state(source: Node, state: Variant) -> void:
	if source is StreetNetwork3DScript:
		source.restore_network_state(state as StreetNetworkData)
	else:
		source.call("restore_native_transform_state", state)


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
