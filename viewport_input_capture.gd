@tool
extends Node

var m_plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	m_plugin = plugin
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if !_is_building_tool_active():
		return
	if m_plugin == null or !is_instance_valid(m_plugin):
		return

	if event is InputEventKey:
		var key_viewport_state := _find_viewport_state(get_viewport().get_mouse_position())
		if key_viewport_state.is_empty():
			return
		var key_camera := key_viewport_state["camera"] as Camera3D
		if key_camera == null:
			return
		if bool(m_plugin.call("handle_viewport_overlay_input", key_camera, event)):
			get_viewport().set_input_as_handled()
		return

	if !(event is InputEventMouse):
		return

	var mouse_event := event as InputEventMouse
	var viewport_state := _find_viewport_state(mouse_event.position)
	if viewport_state.is_empty():
		return
	var camera_3d := viewport_state["camera"] as Camera3D
	if camera_3d == null:
		return

	var local_event := event.duplicate() as InputEvent
	var local_mouse := local_event as InputEventMouse
	if local_mouse != null:
		local_mouse.position = Vector2(viewport_state["local_position"])
		local_mouse.global_position = local_mouse.position

	if bool(m_plugin.call("handle_viewport_overlay_input", camera_3d, local_event)):
		get_viewport().set_input_as_handled()


func _is_building_tool_active() -> bool:
	if m_plugin == null or !is_instance_valid(m_plugin):
		return false
	if !m_plugin.has_method("is_building_tool_active"):
		return false
	return bool(m_plugin.call("is_building_tool_active"))


func _find_viewport_state(mouse_position: Vector2) -> Dictionary:
	for index in range(4):
		var sub_viewport := EditorInterface.get_editor_viewport_3d(index)
		if sub_viewport == null:
			continue
		var control := sub_viewport.get_parent() as Control
		if control == null:
			continue
		# Only the currently shown 3D viewport(s) should capture input. Unused
		# split-view viewports and the whole spatial editor (when another main
		# screen is active) keep stale global rects that can otherwise overlap
		# docks and other panels, so skip anything not visible on screen.
		if !control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if !rect.has_point(mouse_position):
			continue
		var camera := sub_viewport.get_camera_3d()
		if camera == null:
			continue
		return {
			"camera": camera,
			"local_position": mouse_position - rect.position,
		}
	return {}
