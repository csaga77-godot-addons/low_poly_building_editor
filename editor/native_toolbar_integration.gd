@tool
extends RefCounted

## Viewport toolbar and native-mode-button integration — stage 2 of the
## plugin split (see `../docs/plugin_split_plan.md`). Owns the building-tools
## toolbar in the 3D viewport menu bar, its generated icons, and the shim
## that keeps Godot's native Transform/Move/Rotate/Scale/Select buttons
## mutually exclusive with the building tools. Internal and path-extended;
## not an editor-creatable type.
##
## Talks back to the plugin only through editor services
## (`add_control_to_container`, `set_process_input`,
## `get_editor_interface`), the dynamic `m_plugin.m_tool_mode` /
## `m_plugin.m_dock` reads, and the `_on_tool_mode_changed` fallback when no
## dock exists. The plugin forwards its `_input` here and keeps thin
## delegations for the five entry points the rest of the plugin calls.

# Temporary diagnostic: writes the 3D toolbar tree to
# native_buttons_debug.log when enabled.
const DEBUG_NATIVE_BUTTONS := false
const NATIVE_ICON_SELECT := &"ToolSelect"
const NATIVE_ICON_TRANSFORM := &"Transform"
const NATIVE_ICON_TRANSFORM_ALTERNATE := &"ToolTriangle"
const NATIVE_ICON_MOVE := &"ToolMove"
const NATIVE_ICON_ROTATE := &"ToolRotate"
const NATIVE_ICON_SCALE := &"ToolScale"
const NATIVE_MODE_TRANSFORM := &"transform"
const NATIVE_MODE_MOVE := &"move"
const NATIVE_MODE_ROTATE := &"rotate"
const NATIVE_MODE_SCALE := &"scale"
const NATIVE_MODE_SELECT := &"select"
const NATIVE_SHORTCUT_TRANSFORM := KEY_Q
const NATIVE_SHORTCUT_MOVE := KEY_W
const NATIVE_SHORTCUT_ROTATE := KEY_E
const NATIVE_SHORTCUT_SCALE := KEY_R
const NATIVE_SHORTCUT_SELECT := KEY_V
const NATIVE_TIPS_SELECT := ["select mode", "select tool"]
const NATIVE_TIPS_TRANSFORM := ["transform mode", "transform"]
const NATIVE_TIPS_MOVE := ["move mode", "move"]
const NATIVE_TIPS_ROTATE := ["rotate mode", "rotate"]
const NATIVE_TIPS_SCALE := ["scale mode", "scale"]
const TOOLBAR_BUTTON_MINIMUM_SIZE := Vector2(32.0, 32.0)
const TOOLBAR_FALLBACK_ICON_SIZE := Vector2i(24, 24)
const BUTTON_STYLEBOX_THEME_ITEMS := [
	&"normal",
	&"hover",
	&"pressed",
	&"disabled",
	&"focus",
	&"hover_pressed",
]
const BUTTON_COLOR_THEME_ITEMS := [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_disabled_color",
	&"font_focus_color",
	&"font_hover_pressed_color",
	&"font_outline_color",
	&"icon_normal_color",
	&"icon_hover_color",
	&"icon_pressed_color",
	&"icon_disabled_color",
	&"icon_focus_color",
	&"icon_hover_pressed_color",
]
const BUTTON_CONSTANT_THEME_ITEMS := [
	&"h_separation",
	&"icon_max_width",
	&"outline_size",
]
const BUTTON_FONT_THEME_ITEMS := [
	&"font",
]
const BUTTON_FONT_SIZE_THEME_ITEMS := [
	&"font_size",
]

# Tool-mode keys shared with plugin.gd and the dock's select_tool_mode path.
const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_FLOOR := "floor"
const MODE_STREET := "street"
const MODE_STAIRS := "stairs"
const MODE_RAIL := "rail"
const MODE_PILLAR := "pillar"
const MODE_ROOF := "roof"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MODE_DOOR := "door"

# The native 3D viewport Select mode is the "no building tool" state, so the
# toolbar only exposes the building tools and stays mutually exclusive with the
# native Transform/Move/Rotate/Scale/Select buttons.
const TOOLBAR_TOOLS := [
	{
		"mode": MODE_WALL,
		"label": "Wall",
		"tooltip": "Draw grid-snapped walls.",
		"generated_icon": true,
	},
	{
		"mode": MODE_FLOOR,
		"label": "Floor",
		"tooltip": "Draw rectangle or polygon floor slabs.",
		"generated_icon": true,
	},
	{
		"mode": MODE_STREET,
		"label": "Street",
		"tooltip": "Draw terrain-profiled roads with kerbs and footpaths.",
		"generated_icon": true,
	},
	{
		"mode": MODE_STAIRS,
		"label": "Stairs",
		"tooltip": "Draw stepped stair blocks.",
		"generated_icon": true,
	},
	{
		"mode": MODE_RAIL,
		"label": "Rail",
		"tooltip": "Draw standard post-and-bar rails.",
		"generated_icon": true,
	},
	{
		"mode": MODE_PILLAR,
		"label": "Pillar",
		"tooltip": "Place low-poly pillars.",
		"generated_icon": true,
	},
	{
		"mode": MODE_ROOF,
		"label": "Roof",
		"tooltip": "Draw low-poly roofs.",
		"generated_icon": true,
	},
	{
		"mode": MODE_DOOR,
		"label": "Door",
		"tooltip": "Cut door openings.",
		"generated_icon": true,
	},
	{
		"mode": MODE_WINDOW,
		"label": "Window",
		"tooltip": "Cut window openings.",
		"generated_icon": true,
	},
	{
		"mode": MODE_PROP,
		"label": "Prop",
		"tooltip": "Place prop scenes.",
		"generated_icon": true,
	},
]

## Owning plugin, typed as the native `EditorPlugin` base (typing it as the
## concrete script would create a cyclic preload with `plugin.gd`).
var m_plugin: EditorPlugin
var m_viewport_toolbar: HBoxContainer
var m_toolbar_buttons := {}
var m_toolbar_icon_cache := {}
var m_toolbar_icon_size := TOOLBAR_FALLBACK_ICON_SIZE
var m_native_tool_buttons: Array[Button] = []
var m_native_select_button: Button
var m_native_active_button: Button
var m_handling_native_click := false


func _init(plugin: EditorPlugin) -> void:
	m_plugin = plugin


func _active_tool_mode() -> String:
	return String(m_plugin.m_tool_mode)


func build_viewport_toolbar() -> void:
	if m_viewport_toolbar != null:
		return
	m_viewport_toolbar = HBoxContainer.new()
	m_viewport_toolbar.name = "LowPolyBuildingEditorToolbar"
	m_viewport_toolbar.mouse_filter = Control.MOUSE_FILTER_PASS

	m_toolbar_buttons.clear()
	for tool_info in TOOLBAR_TOOLS:
		var mode := String(tool_info["mode"])
		var label := String(tool_info["label"])
		var button := Button.new()
		button.name = "LowPolyBuildingEditor%sButton" % label
		button.toggle_mode = true
		button.icon = _get_toolbar_tool_icon(tool_info)
		button.tooltip_text = "%s: %s" % [label, String(tool_info["tooltip"])]
		button.focus_mode = Control.FOCUS_NONE
		_apply_toolbar_button_style(button)
		button.set_pressed_no_signal(mode == _active_tool_mode())
		button.pressed.connect(_on_toolbar_tool_selected.bind(mode))
		m_viewport_toolbar.add_child(button)
		m_toolbar_buttons[mode] = button

	m_plugin.add_control_to_container(
		EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, m_viewport_toolbar
	)
	# Defer so the control is reparented into the spatial editor menu bar before
	# we look up the native Transform/Move/Rotate/Scale/Select buttons beside it.
	_collect_native_tool_buttons.call_deferred()
	m_plugin.set_process_input(true)


func clear_viewport_toolbar() -> void:
	_release_native_tool_buttons()
	if m_viewport_toolbar == null:
		return
	m_plugin.set_process_input(false)
	m_plugin.remove_control_from_container(
		EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, m_viewport_toolbar
	)
	m_viewport_toolbar.queue_free()
	m_viewport_toolbar = null
	m_toolbar_buttons.clear()


## Forwarded from the plugin's `_input()`.
func handle_editor_input(event: InputEvent) -> void:
	if _active_tool_mode() == MODE_SELECT:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if (
			mouse_button.button_index == MOUSE_BUTTON_LEFT
			and mouse_button.pressed
			and _event_hits_native_select_button(mouse_button)
		):
			_on_native_tool_button_chosen(_get_native_select_button())


func _on_toolbar_tool_selected(mode: String) -> void:
	select_tool_mode(mode)


func select_tool_mode(mode: String) -> void:
	if mode.is_empty():
		return
	# Route through the dock so its option button, shortcuts, and visible tool
	# section stay in sync; the dock re-emits tool_mode_changed back to us.
	var dock: Control = m_plugin.m_dock
	if dock != null and dock.has_method("select_tool_mode"):
		dock.call("select_tool_mode", mode)
	else:
		m_plugin._on_tool_mode_changed(mode)


func sync_toolbar_tool_mode(mode: String) -> void:
	# Setting button_pressed without a signal keeps the building buttons a radio
	# set without looping back through "pressed".
	for tool_mode in m_toolbar_buttons:
		var button: Button = m_toolbar_buttons[tool_mode]
		if button != null:
			button.set_pressed_no_signal(tool_mode == mode)
	_sync_native_tool_buttons(mode)


func _collect_native_tool_buttons() -> void:
	# Find the native Transform/Move/Rotate/Scale/Select mode buttons so the
	# building tools can stay mutually exclusive with them. Godot's toolbar
	# layout can move, so match each native button by icon name first, then by
	# its tooltip text, then by its native shortcut.
	_release_native_tool_buttons()
	if m_viewport_toolbar == null:
		return
	var found := _find_native_mode_buttons_from_node_3d_editor()
	m_native_select_button = found.get(NATIVE_MODE_SELECT) as Button
	var native_reference := found.get(NATIVE_MODE_MOVE) as Button
	_apply_native_toolbar_box_layout(native_reference)
	_apply_native_toolbar_icon_size(native_reference)
	_apply_native_toolbar_button_style(native_reference)
	for native_button in _native_button_values(found):
		if m_native_tool_buttons.has(native_button):
			continue
		m_native_tool_buttons.append(native_button)
		var native_pressed := Callable(self, "_on_native_tool_button_chosen").bind(native_button)
		var native_toggled := Callable(self, "_on_native_tool_button_toggled").bind(native_button)
		var native_gui_input := Callable(self, "_on_native_tool_button_gui_input").bind(native_button)
		if not native_button.pressed.is_connected(native_pressed):
			native_button.pressed.connect(native_pressed)
		if not native_button.button_down.is_connected(native_pressed):
			native_button.button_down.connect(native_pressed)
		if not native_button.toggled.is_connected(native_toggled):
			native_button.toggled.connect(native_toggled)
		if not native_button.gui_input.is_connected(native_gui_input):
			native_button.gui_input.connect(native_gui_input)
	if DEBUG_NATIVE_BUTTONS:
		_dump_native_button_debug()
	if m_native_tool_buttons.is_empty():
		push_warning("Low-Poly Building Editor: could not locate the native 3D viewport mode buttons; building-tool exclusivity is disabled.")
		return
	_update_native_active_button()
	_sync_native_tool_buttons(_active_tool_mode())


func _apply_native_toolbar_box_layout(reference_button: Button) -> void:
	if m_viewport_toolbar == null or reference_button == null or !is_instance_valid(reference_button):
		return
	var native_toolbar_parent := _find_toolbar_box_parent(reference_button)
	if native_toolbar_parent == null:
		return
	m_viewport_toolbar.theme = native_toolbar_parent.theme
	m_viewport_toolbar.theme_type_variation = native_toolbar_parent.theme_type_variation
	m_viewport_toolbar.add_theme_constant_override(
		"separation",
		native_toolbar_parent.get_theme_constant("separation")
	)


func _find_toolbar_box_parent(button: Button) -> HBoxContainer:
	var node := button.get_parent()
	while node != null:
		if node is HBoxContainer:
			return node as HBoxContainer
		node = node.get_parent()
	return null


func _apply_native_toolbar_button_style(reference_button: Button) -> void:
	for tool_mode in m_toolbar_buttons:
		_apply_toolbar_button_style(m_toolbar_buttons[tool_mode], reference_button)


func _apply_native_toolbar_icon_size(reference_button: Button) -> void:
	if reference_button == null or !is_instance_valid(reference_button):
		return
	var native_icon_size := _get_native_toolbar_icon_size(reference_button)
	if native_icon_size == m_toolbar_icon_size:
		return
	m_toolbar_icon_size = native_icon_size
	m_toolbar_icon_cache.clear()
	for tool_mode in m_toolbar_buttons:
		var button := m_toolbar_buttons[tool_mode] as Button
		if button != null and is_instance_valid(button):
			button.icon = _make_toolbar_tool_icon(String(tool_mode))


func _get_native_toolbar_icon_size(reference_button: Button) -> Vector2i:
	if reference_button.icon != null:
		var icon_size := reference_button.icon.get_size()
		if icon_size.x > 0.0 and icon_size.y > 0.0:
			return Vector2i(roundi(icon_size.x), roundi(icon_size.y))
	if reference_button.has_theme_constant(&"icon_max_width"):
		var icon_max_width := reference_button.get_theme_constant(&"icon_max_width")
		if icon_max_width > 0:
			return Vector2i(icon_max_width, icon_max_width)
	return TOOLBAR_FALLBACK_ICON_SIZE


func _apply_toolbar_button_style(button: Button, reference_button: Button = null) -> void:
	if button == null:
		return
	button.theme_type_variation = &"ToolButton"
	button.custom_minimum_size = TOOLBAR_BUTTON_MINIMUM_SIZE
	button.flat = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if reference_button == null or !is_instance_valid(reference_button):
		return
	button.theme = reference_button.theme
	button.theme_type_variation = reference_button.theme_type_variation
	button.custom_minimum_size = _get_native_toolbar_button_size(reference_button)
	button.flat = reference_button.flat
	button.alignment = reference_button.alignment
	button.icon_alignment = reference_button.icon_alignment
	button.vertical_icon_alignment = reference_button.vertical_icon_alignment
	button.expand_icon = reference_button.expand_icon
	_copy_button_theme_items(reference_button, button)


func _get_native_toolbar_button_size(reference_button: Button) -> Vector2:
	if reference_button.custom_minimum_size.x > 0.0 and reference_button.custom_minimum_size.y > 0.0:
		return reference_button.custom_minimum_size
	if reference_button.size.x > 0.0 and reference_button.size.y > 0.0:
		return reference_button.size
	var combined_minimum := reference_button.get_combined_minimum_size()
	if combined_minimum.x > 0.0 and combined_minimum.y > 0.0:
		return combined_minimum
	return TOOLBAR_BUTTON_MINIMUM_SIZE


func _copy_button_theme_items(source: Button, target: Button) -> void:
	for item in BUTTON_STYLEBOX_THEME_ITEMS:
		if source.has_theme_stylebox(item):
			target.add_theme_stylebox_override(item, source.get_theme_stylebox(item))
	for item in BUTTON_COLOR_THEME_ITEMS:
		if source.has_theme_color(item):
			target.add_theme_color_override(item, source.get_theme_color(item))
	for item in BUTTON_CONSTANT_THEME_ITEMS:
		if source.has_theme_constant(item):
			target.add_theme_constant_override(item, source.get_theme_constant(item))
	for item in BUTTON_FONT_THEME_ITEMS:
		if source.has_theme_font(item):
			target.add_theme_font_override(item, source.get_theme_font(item))
	for item in BUTTON_FONT_SIZE_THEME_ITEMS:
		if source.has_theme_font_size(item):
			target.add_theme_font_size_override(item, source.get_theme_font_size(item))


func _find_native_mode_buttons_from_node_3d_editor() -> Dictionary:
	var editor_base := m_plugin.get_editor_interface().get_base_control()
	if editor_base == null:
		return {}
	var node_3d_editors := _find_nodes_by_class_name(editor_base, "Node3DEditor")
	for node in node_3d_editors:
		var native_buttons := _find_native_mode_buttons_in_node_3d_editor_node(node)
		if _native_button_map_is_complete(native_buttons):
			return native_buttons
	return {}


func _find_native_mode_buttons_in_node_3d_editor_node(root: Node) -> Dictionary:
	var buttons := _find_buttons(root)
	var native_buttons := {}
	native_buttons[NATIVE_MODE_TRANSFORM] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_TRANSFORM, NATIVE_ICON_TRANSFORM_ALTERNATE],
		NATIVE_TIPS_TRANSFORM,
		NATIVE_SHORTCUT_TRANSFORM
	)

	native_buttons[NATIVE_MODE_MOVE] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_MOVE],
		NATIVE_TIPS_MOVE,
		NATIVE_SHORTCUT_MOVE
	)

	native_buttons[NATIVE_MODE_ROTATE] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_ROTATE],
		NATIVE_TIPS_ROTATE,
		NATIVE_SHORTCUT_ROTATE
	)
	native_buttons[NATIVE_MODE_SCALE] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_SCALE],
		NATIVE_TIPS_SCALE,
		NATIVE_SHORTCUT_SCALE
	)
	native_buttons[NATIVE_MODE_SELECT] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_SELECT],
		NATIVE_TIPS_SELECT,
		NATIVE_SHORTCUT_SELECT
	)
	if !_native_button_map_is_complete(native_buttons):
		return {}
	if !_native_buttons_are_unique(_native_button_values(native_buttons)):
		return {}
	return native_buttons


func _find_button_by_icon_tip_or_shortcut(
	buttons: Array[Button],
	icon_names: Array[StringName],
	tip_patterns: Array,
	shortcut_key: int
) -> Button:
	var icon_button := _find_button_with_icon_names(buttons, icon_names)
	if icon_button != null:
		return icon_button
	var shortcut_button := _find_button_with_shortcut_key(buttons, shortcut_key)
	if shortcut_button != null:
		return shortcut_button
	return _find_button_with_tip_text(buttons, tip_patterns)


func _find_button_with_icon_names(buttons: Array[Button], icon_names: Array[StringName]) -> Button:
	for icon_name in icon_names:
		var button := _find_button_with_icon_name(buttons, icon_name)
		if button != null:
			return button
	return null


func _find_button_with_icon_name(buttons: Array[Button], icon_name: StringName) -> Button:
	for button in buttons:
		if button != null and is_instance_valid(button) and _button_has_icon_name(button, icon_name):
			return button
	return null


func _find_button_with_tip_text(buttons: Array[Button], tip_patterns: Array) -> Button:
	for button in buttons:
		if button != null and is_instance_valid(button) and _button_tip_contains_any(button, tip_patterns):
			return button
	return null


func _find_button_with_shortcut_key(buttons: Array[Button], shortcut_key: int) -> Button:
	for button in buttons:
		if (
			button != null
			and is_instance_valid(button)
			and button.toggle_mode
			and _button_has_unmodified_shortcut_key(button, shortcut_key)
		):
			return button
	return null


func _native_button_map_is_complete(native_buttons: Dictionary) -> bool:
	for mode in [
		NATIVE_MODE_TRANSFORM,
		NATIVE_MODE_MOVE,
		NATIVE_MODE_ROTATE,
		NATIVE_MODE_SCALE,
		NATIVE_MODE_SELECT,
	]:
		if !native_buttons.has(mode):
			return false
		var button := native_buttons[mode] as Button
		if button == null or !is_instance_valid(button):
			return false
	return true


func _native_button_values(native_buttons: Dictionary) -> Array[Button]:
	var buttons: Array[Button] = []
	for mode in native_buttons:
		var button := native_buttons[mode] as Button
		if button != null and is_instance_valid(button):
			buttons.append(button)
	return buttons


func _native_buttons_are_unique(buttons: Array[Button]) -> bool:
	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			if buttons[i] == buttons[j]:
				return false
	return true


func _button_has_icon_name(button: Button, icon_name: StringName) -> bool:
	if button.icon == null:
		return false
	var expected_icon := get_editor_icon(icon_name)
	if expected_icon != null and button.icon == expected_icon:
		return true
	var icon_name_text := String(icon_name).to_lower()
	var icon_resource_name := String(button.icon.resource_name).to_lower()
	var icon_resource_path := button.icon.resource_path.to_lower()
	return icon_resource_name.contains(icon_name_text) or icon_resource_path.contains(icon_name_text)


func _find_nodes_by_class_name(node: Node, class_name_text: String) -> Array[Node]:
	var results: Array[Node] = []
	if node.is_class(class_name_text):
		results.append(node)
	for child in node.get_children():
		results.append_array(_find_nodes_by_class_name(child, class_name_text))
	return results


func _find_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root as Button)
	for child in root.get_children():
		buttons.append_array(_find_buttons(child))
	return buttons


func _is_native_select_button(button: Button) -> bool:
	if _button_has_icon_name(button, NATIVE_ICON_SELECT):
		return true
	if _button_tip_contains_any(button, NATIVE_TIPS_SELECT):
		return true
	return _button_has_unmodified_shortcut_key(button, NATIVE_SHORTCUT_SELECT)


func _find_native_select_button(buttons: Array[Button]) -> Button:
	for button in buttons:
		if button != null and is_instance_valid(button) and _is_native_select_button(button):
			return button
	return null


func _button_tip_contains_any(button: Button, tip_patterns: Array) -> bool:
	if button == null or !button.toggle_mode:
		return false
	var tip_text := "%s\n%s" % [button.tooltip_text, button.get_tooltip(Vector2.ZERO)]
	var tip_lower := tip_text.to_lower()
	for pattern in tip_patterns:
		var pattern_text := String(pattern).to_lower()
		if !pattern_text.is_empty() and tip_lower.contains(pattern_text):
			return true
	return false


func _button_has_unmodified_shortcut_key(button: Button, shortcut_key: int) -> bool:
	if button == null:
		return false
	var shortcut := button.shortcut
	if shortcut == null:
		return false
	for event in shortcut.events:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.shift_pressed or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
				continue
			if key_event.keycode == shortcut_key or key_event.physical_keycode == shortcut_key:
				return true
	return false


func _dump_native_button_debug() -> void:
	var lines := PackedStringArray()
	lines.append("toolbar parent: %s" % str(null if m_viewport_toolbar == null else m_viewport_toolbar.get_parent()))
	lines.append("matched native buttons: %d" % m_native_tool_buttons.size())
	for matched in m_native_tool_buttons:
		lines.append("  MATCH tip='%s' shortcut='%s' icon='%s' pressed=%s" % [
			matched.get_tooltip(Vector2.ZERO),
			"" if matched.shortcut == null else matched.shortcut.get_as_text(),
			_button_icon_debug_text(matched),
			str(matched.button_pressed),
		])
	var ancestor: Node = null if m_viewport_toolbar == null else m_viewport_toolbar.get_parent()
	for i in range(3):
		if ancestor == null:
			break
		lines.append("=== ancestor[%d]: %s (%s) ===" % [i, ancestor.name, ancestor.get_class()])
		_dump_node_tree(ancestor, 0, lines)
		ancestor = ancestor.get_parent()
	var file := FileAccess.open("res://addons/low_poly_building_editor/native_buttons_debug.log", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _dump_node_tree(node: Node, depth: int, lines: PackedStringArray) -> void:
	if depth > 4:
		return
	for child in node.get_children():
		var info := "  ".repeat(depth + 1) + "%s [%s]" % [child.name, child.get_class()]
		if child is Button:
			var btn := child as Button
			info += " toggle=%s pressed=%s text='%s' tip='%s' shortcut='%s' icon='%s'" % [
				str(btn.toggle_mode),
				str(btn.button_pressed),
				btn.text,
				btn.get_tooltip(Vector2.ZERO),
				"" if btn.shortcut == null else btn.shortcut.get_as_text(),
				_button_icon_debug_text(btn),
			]
		lines.append(info)
		_dump_node_tree(child, depth + 1, lines)


func _button_icon_debug_text(button: Button) -> String:
	if button == null or button.icon == null:
		return ""
	return "%s|%s" % [String(button.icon.resource_name), button.icon.resource_path]


func _release_native_tool_buttons() -> void:
	for native_button in m_native_tool_buttons:
		if native_button != null and is_instance_valid(native_button):
			var native_pressed := Callable(self, "_on_native_tool_button_chosen").bind(native_button)
			var native_toggled := Callable(self, "_on_native_tool_button_toggled").bind(native_button)
			var native_gui_input := Callable(self, "_on_native_tool_button_gui_input").bind(native_button)
			if native_button.pressed.is_connected(native_pressed):
				native_button.pressed.disconnect(native_pressed)
			if native_button.button_down.is_connected(native_pressed):
				native_button.button_down.disconnect(native_pressed)
			if native_button.toggled.is_connected(native_toggled):
				native_button.toggled.disconnect(native_toggled)
			if native_button.gui_input.is_connected(native_gui_input):
				native_button.gui_input.disconnect(native_gui_input)
	m_native_tool_buttons.clear()
	m_native_select_button = null
	m_native_active_button = null


func _on_native_tool_button_gui_input(event: InputEvent, native_button: Button) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_on_native_tool_button_chosen(native_button)


func _on_native_tool_button_toggled(toggled_on: bool, native_button: Button) -> void:
	if toggled_on:
		_on_native_tool_button_chosen(native_button)


func _on_native_tool_button_chosen(native_button: Button) -> void:
	# A native viewport selection mode was chosen; deactivate any building tool
	# so the two button sets stay mutually exclusive.
	if native_button != null and is_instance_valid(native_button):
		m_native_active_button = native_button
	else:
		_update_native_active_button()
	if _active_tool_mode() == MODE_SELECT:
		return
	m_handling_native_click = true
	select_tool_mode(MODE_SELECT)
	m_handling_native_click = false


func _update_native_active_button() -> void:
	for native_button in m_native_tool_buttons:
		if native_button != null and is_instance_valid(native_button) and native_button.button_pressed:
			m_native_active_button = native_button
			return


func _sync_native_tool_buttons(mode: String) -> void:
	if m_native_tool_buttons.is_empty():
		return
	if mode == MODE_SELECT:
		# A native click already reflects the user's choice; only restore the
		# native highlight when a building tool is cleared from our own UI.
		if m_handling_native_click:
			return
		var select_button := _get_native_select_button()
		if select_button != null:
			_clear_native_tool_button_highlights()
			select_button.set_pressed_no_signal(true)
			m_native_active_button = select_button
		elif m_native_active_button != null and is_instance_valid(m_native_active_button):
			m_native_active_button.set_pressed_no_signal(true)
	else:
		_queue_native_tool_button_highlight_clear()


func _get_native_select_button() -> Button:
	if m_native_select_button != null and is_instance_valid(m_native_select_button):
		return m_native_select_button
	m_native_select_button = _find_native_select_button(m_native_tool_buttons)
	return m_native_select_button


func _event_hits_native_select_button(mouse_button: InputEventMouseButton) -> bool:
	var select_button := _get_native_select_button()
	if select_button == null or !select_button.is_visible_in_tree():
		return false
	return select_button.get_global_rect().has_point(mouse_button.position)


func _queue_native_tool_button_highlight_clear() -> void:
	_clear_native_tool_button_highlights()
	call_deferred("_clear_native_tool_button_highlights_if_building_tool_active")


func _clear_native_tool_button_highlights_if_building_tool_active() -> void:
	if _active_tool_mode() != MODE_SELECT:
		_clear_native_tool_button_highlights()


func _clear_native_tool_button_highlights() -> void:
	for native_button in m_native_tool_buttons:
		if native_button != null and is_instance_valid(native_button):
			native_button.set_pressed_no_signal(false)


func _get_toolbar_tool_icon(tool_info: Dictionary) -> Texture2D:
	if bool(tool_info.get("generated_icon", false)):
		return _make_toolbar_tool_icon(String(tool_info.get("mode", "")))
	var icon_names: Array = tool_info.get("icons", [])
	for icon_name in icon_names:
		var icon := get_editor_icon(StringName(icon_name), false)
		if icon != null:
			return icon
	return _make_toolbar_tool_icon(String(tool_info.get("mode", "")))


func _make_toolbar_tool_icon(mode: String) -> Texture2D:
	if m_toolbar_icon_cache.has(mode):
		return m_toolbar_icon_cache[mode]
	var image := Image.create(
		TOOLBAR_FALLBACK_ICON_SIZE.x,
		TOOLBAR_FALLBACK_ICON_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var color := Color.WHITE
	match mode:
		MODE_WALL:
			_draw_icon_rect_outline(image, Rect2i(3, 7, 18, 12), color, 2)
			_draw_icon_line(image, Vector2i(4, 11), Vector2i(20, 11), color, 1)
			_draw_icon_line(image, Vector2i(4, 15), Vector2i(20, 15), color, 1)
			_draw_icon_line(image, Vector2i(9, 8), Vector2i(9, 10), color, 1)
			_draw_icon_line(image, Vector2i(15, 8), Vector2i(15, 10), color, 1)
			_draw_icon_line(image, Vector2i(6, 12), Vector2i(6, 14), color, 1)
			_draw_icon_line(image, Vector2i(12, 12), Vector2i(12, 14), color, 1)
			_draw_icon_line(image, Vector2i(18, 12), Vector2i(18, 14), color, 1)
			_draw_icon_line(image, Vector2i(9, 16), Vector2i(9, 18), color, 1)
			_draw_icon_line(image, Vector2i(15, 16), Vector2i(15, 18), color, 1)
		MODE_FLOOR:
			_draw_icon_line(image, Vector2i(12, 4), Vector2i(21, 10), color, 2)
			_draw_icon_line(image, Vector2i(21, 10), Vector2i(12, 17), color, 2)
			_draw_icon_line(image, Vector2i(12, 17), Vector2i(3, 10), color, 2)
			_draw_icon_line(image, Vector2i(3, 10), Vector2i(12, 4), color, 2)
			_draw_icon_line(image, Vector2i(3, 10), Vector2i(21, 10), color, 1)
			_draw_icon_line(image, Vector2i(12, 4), Vector2i(12, 17), color, 1)
		MODE_STREET:
			_draw_icon_line(image, Vector2i(5, 21), Vector2i(9, 3), color, 2)
			_draw_icon_line(image, Vector2i(19, 21), Vector2i(15, 3), color, 2)
			_draw_icon_line(image, Vector2i(12, 20), Vector2i(12, 16), color, 1)
			_draw_icon_line(image, Vector2i(12, 12), Vector2i(12, 8), color, 1)
			_draw_icon_line(image, Vector2i(12, 5), Vector2i(12, 3), color, 1)
		MODE_STAIRS:
			_draw_icon_line(image, Vector2i(4, 18), Vector2i(8, 18), color, 2)
			_draw_icon_line(image, Vector2i(8, 18), Vector2i(8, 14), color, 2)
			_draw_icon_line(image, Vector2i(8, 14), Vector2i(12, 14), color, 2)
			_draw_icon_line(image, Vector2i(12, 14), Vector2i(12, 10), color, 2)
			_draw_icon_line(image, Vector2i(12, 10), Vector2i(16, 10), color, 2)
			_draw_icon_line(image, Vector2i(16, 10), Vector2i(16, 6), color, 2)
			_draw_icon_line(image, Vector2i(16, 6), Vector2i(20, 6), color, 2)
			_draw_icon_line(image, Vector2i(4, 20), Vector2i(20, 20), color, 1)
			_draw_icon_line(image, Vector2i(20, 6), Vector2i(20, 20), color, 1)
		MODE_RAIL:
			_draw_icon_line(image, Vector2i(4, 5), Vector2i(4, 20), color, 2)
			_draw_icon_line(image, Vector2i(20, 5), Vector2i(20, 20), color, 2)
			_draw_icon_line(image, Vector2i(9, 5), Vector2i(9, 20), color, 1)
			_draw_icon_line(image, Vector2i(15, 5), Vector2i(15, 20), color, 1)
			_draw_icon_line(image, Vector2i(3, 5), Vector2i(21, 5), color, 2)
			_draw_icon_line(image, Vector2i(4, 13), Vector2i(20, 13), color, 2)
		MODE_PILLAR:
			_draw_icon_line(image, Vector2i(7, 8), Vector2i(9, 5), color, 2)
			_draw_icon_line(image, Vector2i(9, 5), Vector2i(15, 5), color, 2)
			_draw_icon_line(image, Vector2i(15, 5), Vector2i(17, 8), color, 2)
			_draw_icon_line(image, Vector2i(7, 8), Vector2i(7, 17), color, 2)
			_draw_icon_line(image, Vector2i(17, 8), Vector2i(17, 17), color, 2)
			_draw_icon_line(image, Vector2i(7, 17), Vector2i(9, 20), color, 2)
			_draw_icon_line(image, Vector2i(9, 20), Vector2i(15, 20), color, 2)
			_draw_icon_line(image, Vector2i(15, 20), Vector2i(17, 17), color, 2)
		MODE_ROOF:
			_draw_icon_line(image, Vector2i(3, 14), Vector2i(12, 5), color, 2)
			_draw_icon_line(image, Vector2i(12, 5), Vector2i(21, 14), color, 2)
			_draw_icon_line(image, Vector2i(5, 14), Vector2i(19, 14), color, 2)
			_draw_icon_line(image, Vector2i(7, 14), Vector2i(7, 19), color, 1)
			_draw_icon_line(image, Vector2i(17, 14), Vector2i(17, 19), color, 1)
			_draw_icon_line(image, Vector2i(7, 19), Vector2i(17, 19), color, 1)
		MODE_PROP:
			_draw_icon_cube(image, color)
		MODE_DOOR:
			_draw_icon_line(image, Vector2i(7, 20), Vector2i(7, 8), color, 2)
			_draw_icon_line(image, Vector2i(7, 8), Vector2i(12, 4), color, 2)
			_draw_icon_line(image, Vector2i(12, 4), Vector2i(17, 8), color, 2)
			_draw_icon_line(image, Vector2i(17, 8), Vector2i(17, 20), color, 2)
			_draw_icon_line(image, Vector2i(5, 20), Vector2i(19, 20), color, 2)
			_draw_icon_line(image, Vector2i(10, 9), Vector2i(10, 18), color, 1)
			image.fill_rect(Rect2i(14, 13, 2, 2), color)
		MODE_WINDOW:
			_draw_icon_rect_outline(image, Rect2i(4, 5, 16, 13), color, 2)
			_draw_icon_line(image, Vector2i(12, 6), Vector2i(12, 17), color, 2)
			_draw_icon_line(image, Vector2i(5, 12), Vector2i(19, 12), color, 2)
			_draw_icon_line(image, Vector2i(3, 20), Vector2i(21, 20), color, 2)
			_draw_icon_line(image, Vector2i(5, 18), Vector2i(19, 18), color, 1)
		_:
			_draw_icon_cube(image, color)
	if m_toolbar_icon_size != TOOLBAR_FALLBACK_ICON_SIZE:
		image.resize(m_toolbar_icon_size.x, m_toolbar_icon_size.y, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	m_toolbar_icon_cache[mode] = texture
	return texture


func _draw_icon_cube(image: Image, color: Color) -> void:
	_draw_icon_rect_outline(image, Rect2i(5, 9, 11, 10), color, 2)
	_draw_icon_line(image, Vector2i(5, 9), Vector2i(9, 5), color, 1)
	_draw_icon_line(image, Vector2i(16, 9), Vector2i(20, 5), color, 1)
	_draw_icon_line(image, Vector2i(9, 5), Vector2i(20, 5), color, 1)
	_draw_icon_line(image, Vector2i(20, 5), Vector2i(20, 15), color, 1)
	_draw_icon_line(image, Vector2i(16, 19), Vector2i(20, 15), color, 1)


func _draw_icon_rect_outline(image: Image, rect: Rect2i, color: Color, width := 1) -> void:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x - 1
	var bottom := rect.position.y + rect.size.y - 1
	_draw_icon_line(image, Vector2i(left, top), Vector2i(right, top), color, width)
	_draw_icon_line(image, Vector2i(right, top), Vector2i(right, bottom), color, width)
	_draw_icon_line(image, Vector2i(right, bottom), Vector2i(left, bottom), color, width)
	_draw_icon_line(image, Vector2i(left, bottom), Vector2i(left, top), color, width)


func _draw_icon_line(image: Image, start: Vector2i, end: Vector2i, color: Color, width := 1) -> void:
	var x0 := start.x
	var y0 := start.y
	var x1 := end.x
	var y1 := end.y
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		_draw_icon_dot(image, x0, y0, color, width)
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy


func _draw_icon_dot(image: Image, x: int, y: int, color: Color, width: int) -> void:
	for px in range(x, x + width):
		for py in range(y, y + width):
			if (
				px >= 0
				and py >= 0
				and px < TOOLBAR_FALLBACK_ICON_SIZE.x
				and py < TOOLBAR_FALLBACK_ICON_SIZE.y
			):
				image.set_pixel(px, py, color)


func get_editor_icon(icon_name: StringName, fallback_to_node_3d := true) -> Texture2D:
	var base_control := m_plugin.get_editor_interface().get_base_control()
	if base_control == null:
		return null
	if base_control.has_theme_icon(icon_name, &"EditorIcons"):
		return base_control.get_theme_icon(icon_name, &"EditorIcons")
	if fallback_to_node_3d and base_control.has_theme_icon(&"Node3D", &"EditorIcons"):
		return base_control.get_theme_icon(&"Node3D", &"EditorIcons")
	return null
