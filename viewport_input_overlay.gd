@tool
extends Control

var m_plugin: EditorPlugin
var m_is_active := false


func setup(plugin: EditorPlugin) -> void:
	m_plugin = plugin
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	z_index = 4096
	set_active(
		m_plugin != null
		and is_instance_valid(m_plugin)
		and m_plugin.has_method("is_building_tool_active")
		and bool(m_plugin.call("is_building_tool_active"))
	)


func _ready() -> void:
	var parent := get_parent()
	if parent != null and !parent.child_order_changed.is_connected(_on_parent_child_order_changed):
		parent.child_order_changed.connect(_on_parent_child_order_changed)
	_ensure_front()


func _exit_tree() -> void:
	var parent := get_parent()
	if parent != null and parent.child_order_changed.is_connected(_on_parent_child_order_changed):
		parent.child_order_changed.disconnect(_on_parent_child_order_changed)


func set_active(active: bool) -> void:
	m_is_active = active
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	if active:
		_ensure_front()


func _on_parent_child_order_changed() -> void:
	_ensure_front()


func _ensure_front() -> void:
	if !m_is_active or get_parent() == null:
		return
	if get_index() != get_parent().get_child_count() - 1:
		move_to_front()


func _gui_input(event: InputEvent) -> void:
	if !m_is_active:
		return
	if m_plugin == null or !is_instance_valid(m_plugin):
		return
	if event is InputEventMouseButton and m_plugin.has_method("notify_viewport_overlay_event"):
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			m_plugin.call(
				"notify_viewport_overlay_event",
				"press" if mouse_button.pressed else "release"
			)
	var camera := _get_sub_viewport_camera()
	if camera == null:
		return
	var handled := bool(m_plugin.call("handle_viewport_overlay_input", camera, event))
	if handled:
		accept_event()


func _get_sub_viewport_camera() -> Camera3D:
	var viewport_control := get_parent()
	if viewport_control == null:
		return null
	for child in viewport_control.get_children():
		if child is SubViewport:
			var sub_viewport := child as SubViewport
			return sub_viewport.get_camera_3d()
	return null
