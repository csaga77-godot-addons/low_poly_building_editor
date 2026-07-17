@tool
extends EditorPlugin

const _DOCK_SLOT := EditorDock.DOCK_SLOT_RIGHT_UL
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
const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const BuildingMeshScript = preload("res://addons/low_poly_building_editor/building_mesh_3d.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floors/floor_3d.gd")
const Street3DScript = preload("res://addons/low_poly_building_editor/streets/street_3d.gd")
const StreetNetwork3DScript = preload(
	"res://addons/low_poly_building_editor/streets/street_network_3d.gd"
)
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs/stairs_3d.gd")
const Rail3DScript = preload("res://addons/low_poly_building_editor/rails/rail_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillars/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/openings/building_opening_3d.gd")
const BuildingWireframeScript = preload("res://addons/low_poly_building_editor/building_wireframe.gd")
const Window3DScript = preload("res://addons/low_poly_building_editor/openings/window_3d.gd")
const Door3DScript = preload("res://addons/low_poly_building_editor/openings/door_3d.gd")
const DockScript = preload("res://addons/low_poly_building_editor/low_poly_building_editor_dock.gd")
const ViewportInputOverlayScript = preload("res://addons/low_poly_building_editor/viewport_input_overlay.gd")
const ViewportInputCaptureScript = preload("res://addons/low_poly_building_editor/viewport_input_capture.gd")
const BuildingToolContextScript = preload("res://addons/low_poly_building_editor/editor/building_tool_context.gd")
const NativeToolbarIntegrationScript = preload("res://addons/low_poly_building_editor/editor/native_toolbar_integration.gd")
const BuildingToolControllerScript = preload("res://addons/low_poly_building_editor/editor/building_tool_controller.gd")
const PillarToolControllerScript = preload("res://addons/low_poly_building_editor/editor/pillar_tool_controller.gd")
const RailToolControllerScript = preload("res://addons/low_poly_building_editor/editor/rail_tool_controller.gd")
const StairsToolControllerScript = preload("res://addons/low_poly_building_editor/editor/stairs_tool_controller.gd")
const FloorToolControllerScript = preload("res://addons/low_poly_building_editor/editor/floor_tool_controller.gd")
const StreetToolControllerScript = preload("res://addons/low_poly_building_editor/editor/street_tool_controller.gd")
const RoofToolControllerScript = preload("res://addons/low_poly_building_editor/editor/roof_tool_controller.gd")
const WallToolControllerScript = preload("res://addons/low_poly_building_editor/editor/wall_tool_controller.gd")
const PlacementToolControllerScript = preload("res://addons/low_poly_building_editor/editor/placement_tool_controller.gd")
const BUILDING_PROP_META := &"low_poly_building_editor_prop"

var m_dock: Control
var m_editor_dock: EditorDock
var m_input_capture: Node
var m_viewport_overlays: Array[Control] = []
var m_tool_mode := MODE_SELECT
var m_context: BuildingToolContextScript
var m_native_toolbar: NativeToolbarIntegrationScript
var m_tool_controllers := {}
## Cached wall grid step for cross-tool snapping (prop placement follows
## the wall grid); updated by _on_wall_settings_changed.
var m_wall_grid_step := 0.5
## Shared grid step applied when a building block is edited with the native
## Move/Rotate/Scale gizmos; updated by _on_transform_snap_changed.
var m_transform_snap_step := 0.5
## Pre-drag authored snapshots for blocks being edited with native gizmos, keyed
## by node. Captured on left-press in SELECT mode and consumed on release.
var m_native_edit_snapshots := {}
var m_active_coordinator: Building3DScript
var m_display_settings := {
	"wireframe": false,
	"wireframe_xray": false,
	"wireframe_color": Color(0.05, 0.95, 1.0, 1.0),
}
var m_opening_custom_types: Array[Dictionary] = []
var m_building_style_custom_types: Array[Dictionary] = []


func _enter_tree() -> void:
	m_context = BuildingToolContextScript.new(self)
	m_native_toolbar = NativeToolbarIntegrationScript.new(self)
	m_tool_controllers[MODE_PILLAR] = PillarToolControllerScript.new(m_context)
	m_tool_controllers[MODE_RAIL] = RailToolControllerScript.new(m_context)
	m_tool_controllers[MODE_STAIRS] = StairsToolControllerScript.new(m_context)
	m_tool_controllers[MODE_FLOOR] = FloorToolControllerScript.new(m_context)
	m_tool_controllers[MODE_STREET] = StreetToolControllerScript.new(m_context)
	m_tool_controllers[MODE_ROOF] = RoofToolControllerScript.new(m_context)
	m_tool_controllers[MODE_WALL] = WallToolControllerScript.new(m_context)
	var placement_controller := PlacementToolControllerScript.new(m_context)
	m_tool_controllers[MODE_WINDOW] = placement_controller
	m_tool_controllers[MODE_DOOR] = placement_controller
	m_tool_controllers[MODE_PROP] = placement_controller
	m_opening_custom_types = BuildingFactoryScript.get_opening_custom_types()
	m_building_style_custom_types = BuildingFactoryScript.get_building_style_custom_types()
	add_custom_type(
		"Building3D",
		"Node3D",
		Building3DScript,
		_get_editor_icon(&"Node3D")
	)
	add_custom_type(
		"Wall3D",
		"MeshInstance3D",
		Wall3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"Floor3D",
		"MeshInstance3D",
		Floor3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"Street3D",
		"MeshInstance3D",
		Street3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"StreetNetwork3D",
		"Node3D",
		StreetNetwork3DScript,
		_get_editor_icon(&"Node3D")
	)
	add_custom_type(
		"Rail3D",
		"MeshInstance3D",
		Rail3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	for style_type: Dictionary in m_building_style_custom_types:
		add_custom_type(
			String(style_type["name"]),
			"MeshInstance3D",
			style_type["script"],
			_get_editor_icon(&"MeshInstance3D")
		)
	for opening_type: Dictionary in m_opening_custom_types:
		add_custom_type(
			String(opening_type["name"]),
			"Node3D",
			opening_type["script"],
			_get_editor_icon(&"Window")
		)
	set_input_event_forwarding_always_enabled()

	m_dock = DockScript.new() as Control
	m_dock.name = "Building Editor"
	if m_dock.has_method("setup"):
		m_dock.setup(get_editor_interface())
	m_dock.connect("tool_mode_changed", Callable(self, "_on_tool_mode_changed"))
	m_dock.connect("display_settings_changed", Callable(self, "_on_display_settings_changed"))
	m_dock.connect("transform_snap_changed", Callable(self, "_on_transform_snap_changed"))
	m_dock.connect("wall_settings_changed", Callable(self, "_on_wall_settings_changed"))
	m_dock.connect("floor_settings_changed", Callable(self, "_on_floor_settings_changed"))
	m_dock.connect("street_settings_changed", Callable(self, "_on_street_settings_changed"))
	m_dock.connect("street_resample_requested", Callable(self, "_on_street_resample_requested"))
	m_dock.connect("stair_settings_changed", Callable(self, "_on_stair_settings_changed"))
	m_dock.connect("rail_settings_changed", Callable(self, "_on_rail_settings_changed"))
	m_dock.connect("pillar_settings_changed", Callable(self, "_on_pillar_settings_changed"))
	m_dock.connect("roof_settings_changed", Callable(self, "_on_roof_settings_changed"))
	m_dock.connect("prop_settings_changed", Callable(self, "_on_prop_settings_changed"))
	m_dock.connect("window_settings_changed", Callable(self, "_on_window_settings_changed"))
	m_dock.connect("door_settings_changed", Callable(self, "_on_door_settings_changed"))
	m_dock.connect("create_coordinator_requested", Callable(self, "_on_create_coordinator_requested"))

	m_editor_dock = EditorDock.new()
	m_editor_dock.name = "Low-Poly Building Editor"
	m_editor_dock.title = "Low-Poly Building Editor"
	m_editor_dock.default_slot = _DOCK_SLOT
	m_editor_dock.layout_key = "low_poly_building_editor"
	m_editor_dock.add_child(m_dock)
	add_dock(m_editor_dock)
	_build_viewport_toolbar()
	scene_changed.connect(_on_scene_changed)
	_connect_editor_selection()
	_refresh_dock_context()
	_attach_input_capture()
	_attach_viewport_overlays.call_deferred()


func _exit_tree() -> void:
	_cancel_tool_controller_previews()
	m_display_settings["wireframe"] = false
	_apply_debug_wireframe_to_scene()
	_clear_viewport_overlays()
	_clear_viewport_toolbar()
	_clear_input_capture()
	_disconnect_editor_selection()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if m_editor_dock != null:
		remove_dock(m_editor_dock)
		m_editor_dock.queue_free()
		m_editor_dock = null
		m_dock = null
	elif m_dock != null:
		m_dock.queue_free()
		m_dock = null
	for type_index in range(m_opening_custom_types.size() - 1, -1, -1):
		remove_custom_type(String(m_opening_custom_types[type_index]["name"]))
	for type_index in range(m_building_style_custom_types.size() - 1, -1, -1):
		remove_custom_type(String(m_building_style_custom_types[type_index]["name"]))
	remove_custom_type("Rail3D")
	remove_custom_type("Floor3D")
	remove_custom_type("StreetNetwork3D")
	remove_custom_type("Street3D")
	remove_custom_type("Wall3D")
	remove_custom_type("Building3D")
	m_tool_controllers.clear()
	m_context = null
	m_native_toolbar = null


func _handles(object: Object) -> bool:
	return object is Node3D


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if m_tool_mode == MODE_SELECT:
		_track_native_transform_edit(event)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and !key_event.echo:
			if key_event.keycode == KEY_ESCAPE:
				_cancel_active_preview()
				return _handled()

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_active_preview()
			return _handled()

	var tool_controller: BuildingToolControllerScript = m_tool_controllers.get(m_tool_mode)
	if tool_controller != null:
		return tool_controller.handle_input(camera, event)
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func is_building_tool_active() -> bool:
	return m_tool_mode != MODE_SELECT


func handle_viewport_overlay_input(camera: Camera3D, event: InputEvent) -> bool:
	if m_tool_mode == MODE_SELECT:
		return false
	return _forward_3d_gui_input(camera, event) != EditorPlugin.AFTER_GUI_INPUT_PASS


func notify_viewport_overlay_event(event_name: String) -> void:
	_set_status("Viewport overlay captured %s." % event_name)


func _get_or_create_coordinator(create_if_missing: bool) -> Building3DScript:
	return m_context.get_or_create_coordinator(create_if_missing)


func _create_coordinator() -> Building3DScript:
	return m_context.create_coordinator()


func _find_selected_coordinator() -> Building3DScript:
	return m_context.find_selected_coordinator()


func _attach_viewport_overlays() -> void:
	_clear_viewport_overlays()
	for index in range(4):
		var sub_viewport := EditorInterface.get_editor_viewport_3d(index)
		if sub_viewport == null:
			continue
		var viewport_control := sub_viewport.get_parent() as Control
		if viewport_control == null:
			continue
		var overlay := ViewportInputOverlayScript.new() as Control
		overlay.name = "LowPolyBuildingEditorInputOverlay%d" % index
		if overlay.has_method("setup"):
			overlay.setup(self)
		viewport_control.add_child(overlay)
		m_viewport_overlays.append(overlay)
		if overlay.has_method("set_active"):
			overlay.call("set_active", m_tool_mode != MODE_SELECT)


func _attach_input_capture() -> void:
	_clear_input_capture()
	m_input_capture = ViewportInputCaptureScript.new()
	m_input_capture.name = "LowPolyBuildingEditorInputCapture"
	if m_input_capture.has_method("setup"):
		m_input_capture.setup(self)
	get_tree().root.add_child(m_input_capture)


func _clear_input_capture() -> void:
	if m_input_capture != null and is_instance_valid(m_input_capture):
		m_input_capture.queue_free()
	m_input_capture = null


func _clear_viewport_overlays() -> void:
	for overlay in m_viewport_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	m_viewport_overlays.clear()


func _cancel_tool_controller_previews() -> void:
	for mode in m_tool_controllers:
		m_tool_controllers[mode].cancel_preview()


func _cancel_active_preview() -> void:
	_cancel_tool_controller_previews()
	_set_status("Tool preview canceled.")


func _connect_editor_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	if !selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.connect(_on_editor_selection_changed)


func _disconnect_editor_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	if selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.disconnect(_on_editor_selection_changed)


func _tool_mode_for_selected_building_node() -> String:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return ""
	for node in selection.get_selected_nodes():
		var mode := _tool_mode_for_building_node(node)
		if !mode.is_empty():
			return mode
	return ""


func _tool_mode_for_building_node(node: Node) -> String:
	if node == null:
		return ""
	if node is Wall3DScript:
		return MODE_WALL
	if node is Floor3DScript:
		return MODE_FLOOR
	if node is Street3DScript:
		return MODE_STREET
	if node is StreetNetwork3DScript:
		return MODE_STREET
	if node is Stairs3DScript:
		return MODE_STAIRS
	if node is Rail3DScript:
		return MODE_RAIL
	if node is Pillar3DScript:
		return MODE_PILLAR
	if node is Roof3DScript:
		return MODE_ROOF
	if node is BuildingOpening3DScript:
		return _tool_mode_for_opening_node(node as BuildingOpening3DScript)
	if node.has_meta(BUILDING_PROP_META):
		return MODE_PROP
	return ""


func _tool_mode_for_opening_node(opening: BuildingOpening3DScript) -> String:
	if opening == null:
		return ""
	if opening is Door3DScript:
		return MODE_DOOR
	if opening is Window3DScript:
		return MODE_WINDOW
	return ""


func _build_viewport_toolbar() -> void:
	m_native_toolbar.build_viewport_toolbar()


func _clear_viewport_toolbar() -> void:
	if m_native_toolbar != null:
		m_native_toolbar.clear_viewport_toolbar()


func _input(event: InputEvent) -> void:
	if m_native_toolbar != null:
		m_native_toolbar.handle_editor_input(event)


func _select_tool_mode(mode: String) -> void:
	m_native_toolbar.select_tool_mode(mode)


func _sync_toolbar_tool_mode(mode: String) -> void:
	m_native_toolbar.sync_toolbar_tool_mode(mode)


func _get_editor_icon(icon_name: StringName, fallback_to_node_3d := true) -> Texture2D:
	return m_native_toolbar.get_editor_icon(icon_name, fallback_to_node_3d)


func _handled() -> int:
	return m_context.handled()


func _set_status(text: String) -> void:
	m_context.set_status(text)


func _refresh_dock_context() -> void:
	if m_dock == null or !m_dock.has_method("set_active_coordinator_path"):
		return
	var coordinator := _get_or_create_coordinator(false)
	if coordinator == null:
		m_dock.set_active_coordinator_path("")
	else:
		m_dock.set_active_coordinator_path(str(coordinator.get_path()))


func _on_tool_mode_changed(mode: String) -> void:
	m_tool_mode = mode
	_sync_toolbar_tool_mode(mode)
	_sync_viewport_overlay_state()
	_cancel_active_preview()
	if m_tool_mode != MODE_SELECT:
		_activate_3d_editor_context()
	_set_status("Select a tool." if mode == MODE_SELECT else "Active tool: %s" % mode.capitalize())


func _on_display_settings_changed(settings: Dictionary) -> void:
	m_display_settings = settings.duplicate(true)
	_apply_debug_wireframe_to_scene()


func _on_transform_snap_changed(step: float) -> void:
	m_transform_snap_step = maxf(step, 0.0)


## In SELECT mode the native Move/Rotate/Scale gizmos edit the raw node
## transform. We snapshot the authored state of any selected building block on
## left-press and, after the gizmo finalizes, bake the transform back into
## authored properties (grid-snapped) with an undoable action.
func _track_native_transform_edit(event: InputEvent) -> void:
	if !(event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_button.pressed:
		_snapshot_native_transform_targets()
	else:
		call_deferred("_commit_native_transform_edits")


func _snapshot_native_transform_targets() -> void:
	m_native_edit_snapshots.clear()
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	var selected_nodes := selection.get_selected_nodes()
	var selected_roots: Array = []
	var roots_with_selected_descendants := {}
	for node in selected_nodes:
		if !(node is Node3D):
			continue
		var selected_ancestor := _top_selected_node_ancestor(node, selected_nodes)
		if selected_ancestor != null:
			roots_with_selected_descendants[selected_ancestor] = true
			selection.remove_node(node)
			continue
		selected_roots.append(node)
	for node in selected_roots:
		var selected_node := node as Node3D
		var selected_parent := selected_node.get_parent() as Node3D
		var blocks := _descendant_blocks(node)
		if blocks.is_empty():
			continue
		var block_snapshots: Array = []
		for block in blocks:
			var block_parent := block.get_parent() as Node3D
			block_snapshots.append({
				"block": block,
				"before": block.call("capture_native_transform_state"),
				"parent_global_before": (
					block_parent.global_transform if block_parent != null
					else Transform3D.IDENTITY
				),
			})
		m_native_edit_snapshots[node] = {
			"is_block": _is_native_transform_block(node),
			"global_before": selected_node.global_transform,
			"transform_before": selected_node.transform,
			"parent_global_before": (
				selected_parent.global_transform if selected_parent != null else Transform3D.IDENTITY
			),
			"had_selected_descendant": roots_with_selected_descendants.has(node),
			"blocks": block_snapshots,
			"coordinator": _coordinator_for_node(node),
		}


## Applies native gizmo deltas to authored block geometry where needed. A pure
## move on a non-block parent remains on that parent so child local positions do
## not change; parent scale/rotate still bakes into descendant blocks.
func _commit_native_transform_edits() -> void:
	if m_native_edit_snapshots.is_empty():
		return
	var undo_redo := get_undo_redo()
	var coordinators_to_refresh := {}
	for node in m_native_edit_snapshots:
		if node == null or !is_instance_valid(node):
			continue
		var snapshot: Dictionary = m_native_edit_snapshots[node]
		var node3d := node as Node3D
		var global_before: Transform3D = snapshot["global_before"]
		var world_delta: Transform3D = node3d.global_transform * global_before.affine_inverse()
		if BuildingMeshScript.native_transform_is_identity(world_delta):
			continue
		var block_grid_step := m_transform_snap_step
		if !bool(snapshot["is_block"]):
			if _native_delta_is_translation_only(world_delta):
				if bool(snapshot.get("had_selected_descendant", false)):
					_restore_block_snapshots(snapshot["blocks"])
				continue
			var parent_global_before: Transform3D = snapshot["parent_global_before"]
			var snap_offset := BuildingMeshScript.grid_snap_offset(
				node3d.transform.origin,
				m_transform_snap_step
			)
			var world_snap_offset := parent_global_before.basis * snap_offset
			world_delta = Transform3D(world_delta.basis, world_delta.origin + world_snap_offset)
			block_grid_step = 0.0
		var block_snapshots_to_bake: Array = snapshot["blocks"]
		if bool(snapshot["is_block"]) and _native_delta_is_placement_only(world_delta):
			var selected_block_split := _split_selected_block_snapshots(
				block_snapshots_to_bake,
				node3d
			)
			block_snapshots_to_bake = selected_block_split["selected"]
			if bool(snapshot.get("had_selected_descendant", false)):
				_restore_block_snapshots(selected_block_split["descendants"])
		# One undo action covers every baked block plus the container reset for
		# this edit, so a single undo reverts the whole thing.
		if undo_redo != null:
			undo_redo.create_action("Transform building blocks")
		for block_snapshot in block_snapshots_to_bake:
			var block = block_snapshot["block"]
			if block == null or !is_instance_valid(block):
				continue
			var parent_global: Transform3D = block_snapshot["parent_global_before"]
			var parent_delta: Transform3D = parent_global.affine_inverse() * world_delta * parent_global
			block.call("bake_external_delta", parent_delta, block_grid_step)
			var after_state: Dictionary = block.call("capture_native_transform_state")
			if undo_redo != null:
				undo_redo.add_do_method(block, "restore_native_transform_state", after_state)
				undo_redo.add_undo_method(
					block, "restore_native_transform_state", block_snapshot["before"]
				)
			_apply_debug_wireframe_to_node(block)
		# A container (non-block) keeps riding the gizmo transform, so reset it to
		# its pre-edit transform (recorded in the same undo action).
		if !bool(snapshot["is_block"]):
			var transform_before: Transform3D = snapshot["transform_before"]
			node3d.transform = transform_before
			if undo_redo != null:
				undo_redo.add_do_property(node3d, "transform", transform_before)
				undo_redo.add_undo_property(node3d, "transform", transform_before)
		var coordinator = snapshot.get("coordinator")
		if coordinator != null and is_instance_valid(coordinator):
			coordinators_to_refresh[coordinator] = true
			if undo_redo != null:
				undo_redo.add_do_method(coordinator, "refresh_building_geometry_clips")
				undo_redo.add_undo_method(coordinator, "refresh_building_geometry_clips")
		if undo_redo != null:
			# The bake is already applied; commit without re-running the do steps.
			undo_redo.commit_action(false)
	for coordinator in coordinators_to_refresh:
		coordinator.refresh_building_geometry_clips()
	m_native_edit_snapshots.clear()


func _native_delta_is_translation_only(delta: Transform3D) -> bool:
	return BuildingMeshScript.native_transform_is_identity(
		Transform3D(delta.basis, Vector3.ZERO)
	)


func _native_delta_is_placement_only(delta: Transform3D) -> bool:
	var scale := BuildingMeshScript.native_delta_scale(delta)
	return scale.distance_to(Vector3.ONE) <= BuildingMeshScript.NATIVE_TRANSFORM_EPSILON


func _top_selected_node_ancestor(node: Node, selected_nodes: Array) -> Node:
	var selected_ancestor: Node = null
	var current := node.get_parent()
	while current != null:
		if selected_nodes.has(current):
			selected_ancestor = current
		current = current.get_parent()
	return selected_ancestor


func _split_selected_block_snapshots(block_snapshots: Array, selected_node: Node) -> Dictionary:
	var selected_snapshots: Array = []
	var descendant_snapshots: Array = []
	for block_snapshot in block_snapshots:
		if block_snapshot["block"] == selected_node:
			selected_snapshots.append(block_snapshot)
		else:
			descendant_snapshots.append(block_snapshot)
	return {
		"selected": selected_snapshots,
		"descendants": descendant_snapshots,
	}


func _restore_block_snapshots(block_snapshots: Array) -> void:
	for block_snapshot in block_snapshots:
		var block = block_snapshot["block"]
		if block == null or !is_instance_valid(block):
			continue
		block.call("restore_native_transform_state", block_snapshot["before"])
		_apply_debug_wireframe_to_node(block)


## Every building block in the subtree rooted at `node`, including `node` itself.
func _descendant_blocks(node: Node) -> Array:
	var blocks: Array = []
	if _is_native_transform_block(node):
		blocks.append(node)
	for child in node.get_children():
		blocks.append_array(_descendant_blocks(child))
	return blocks


func _is_native_transform_block(node: Object) -> bool:
	return (
		node is Node3D
		and node.has_method("supports_native_transform")
		and bool(node.call("supports_native_transform"))
	)


func _coordinator_for_node(node: Node) -> Building3DScript:
	var current := node
	while current != null:
		if current is Building3DScript:
			return current
		current = current.get_parent()
	return null


func _apply_debug_wireframe_to_scene() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root != null:
		_apply_debug_wireframe_recursive(scene_root)


func _apply_debug_wireframe_to_node(node: Node) -> void:
	if node == null or !is_instance_valid(node):
		return
	var enabled := bool(m_display_settings.get("wireframe", false))
	var color := Color(
		m_display_settings.get(
			"wireframe_color",
			Color(0.05, 0.95, 1.0, 1.0)
		)
	)
	var xray := bool(m_display_settings.get("wireframe_xray", false))
	if node.has_method("set_debug_wireframe"):
		node.call("set_debug_wireframe", enabled, color, xray)
	elif node is Node3D and node.has_meta(BUILDING_PROP_META):
		var prop_root := node as Node3D
		if (
			!enabled
			or !BuildingWireframeScript.update_style(prop_root, color, xray)
		):
			BuildingWireframeScript.sync_recursive(prop_root, enabled, color, xray)


func _apply_debug_wireframe_recursive(node: Node) -> void:
	if node == null or node.has_meta(BuildingWireframeScript.GENERATED_META):
		return
	_apply_debug_wireframe_to_node(node)
	if node.has_meta(BUILDING_PROP_META):
		return
	for child in node.get_children():
		_apply_debug_wireframe_recursive(child)


func _sync_viewport_overlay_state() -> void:
	var active := m_tool_mode != MODE_SELECT
	for overlay in m_viewport_overlays:
		if is_instance_valid(overlay) and overlay.has_method("set_active"):
			overlay.call("set_active", active)


func _on_wall_settings_changed(settings: Dictionary) -> void:
	m_wall_grid_step = maxf(float(settings.get("grid_step", m_wall_grid_step)), 0.05)
	m_tool_controllers[MODE_WALL].apply_settings(settings)


func _on_floor_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_FLOOR].apply_settings(settings)


func _on_street_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_STREET].apply_settings(settings)


func _on_street_resample_requested() -> void:
	m_tool_controllers[MODE_STREET].resample_selected_street()


func _on_stair_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_STAIRS].apply_settings(settings)


func _on_rail_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_RAIL].apply_settings(settings)


func _on_pillar_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_PILLAR].apply_settings(settings)


func _on_roof_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_ROOF].apply_settings(settings)


func _on_prop_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_PROP].apply_prop_settings(settings)


func _on_window_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_WINDOW].apply_window_settings(settings)


func _on_door_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_DOOR].apply_door_settings(settings)


func _on_create_coordinator_requested() -> void:
	_cancel_active_preview()
	var coordinator := _create_coordinator()
	if coordinator != null:
		_set_status("%s ready." % coordinator.name)


func _on_scene_changed(_scene_root: Node) -> void:
	m_active_coordinator = null
	_cancel_active_preview()
	_refresh_dock_context()
	_apply_debug_wireframe_to_scene()


func _on_editor_selection_changed() -> void:
	var selected_coordinator := _find_selected_coordinator()
	if selected_coordinator != null and selected_coordinator != m_active_coordinator:
		_cancel_active_preview()
		m_active_coordinator = selected_coordinator
	_refresh_dock_context()
	var selected_tool_mode := _tool_mode_for_selected_building_node()
	if selected_tool_mode.is_empty() or selected_tool_mode == m_tool_mode:
		return
	_select_tool_mode(selected_tool_mode)


func _activate_3d_editor_context() -> void:
	EditorInterface.set_main_screen_editor("3D")
	var selection := get_editor_interface().get_selection()
	for node in selection.get_selected_nodes():
		if node is Node3D:
			return
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root is Node3D:
		selection.clear()
		selection.add_node(scene_root)
