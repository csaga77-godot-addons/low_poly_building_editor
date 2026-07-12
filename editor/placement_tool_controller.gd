@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Placement tool controller — one controller registered for the window,
## door, and prop modes (stage 6 of the plugin split). Owns the three dock
## settings dictionaries, wall-mapped opening previews, prop previews with
## R-key rotation, opening move/resize drags, and hover highlighting. The
## active mode is read through `m_context.active_tool_mode()`; opening and
## prop snapping intentionally follow the wall grid via
## `m_context.default_grid_step()`.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/openings/building_opening_3d.gd")

# Tool-mode keys shared with plugin.gd and the dock.
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MODE_DOOR := "door"

# Shared metadata keys; match plugin.gd.
const OPENING_SILL_META := BuildingFactoryScript.OPENING_SILL_META
const OPENING_ALLOW_BASE_META := BuildingFactoryScript.OPENING_ALLOW_BASE_META
const BUILDING_PROP_META := &"low_poly_building_editor_prop"

var m_prop_settings := {
	"scene_path": "",
	"clearance": 0.25,
}
var m_window_settings := {
	"style": "single_window",
	"width": 1.0,
	"height": 1.0,
	"frame_thickness": 0.08,
	"sill_height": 0.9,
	"frame_sides": 0,
	"frame_protrusion": 0.02,
	"frame_color": Color(0.86, 0.92, 0.94, 1.0),
	"window_pane_depth": 0.03,
	"window_pane_color": Color(0.58, 0.82, 0.95, 0.52),
	"pane_grid_rows": 2,
	"pane_grid_cols": 1,
	"muntin_thickness": 0.03,
	"louver_count": 6,
	"louver_depth": 0.03,
	"transom_ratio": 0.28,
	"transom_rail_thickness": 0.03,
	"arch_steps": 3,
}
var m_door_settings := {
	"style": "single_door",
	"width": 0.9,
	"height": 2.1,
	"frame_thickness": 0.08,
	"frame_sides": 0,
	"frame_protrusion": 0.02,
	"frame_color": Color(0.86, 0.92, 0.94, 1.0),
	"door_panel_depth": 0.05,
	"door_panel_color": Color(0.50, 0.34, 0.20, 1.0),
	"door_glazing_ratio": 0.55,
	"door_glass_depth": 0.03,
	"door_glass_color": Color(0.58, 0.82, 0.95, 0.52),
	"pane_grid_rows": 2,
	"pane_grid_cols": 1,
	"muntin_thickness": 0.03,
	"door_inset_rows": 3,
	"door_inset_cols": 2,
}
var m_prop_preview: Node3D
var m_prop_preview_path := ""
var m_prop_rotation_y := 0.0
var m_preview_valid := false
var m_preview_wall: Wall3DScript
var m_dragging_opening: BuildingOpening3DScript
var m_drag_old_position: Vector3
var m_drag_old_segment: int
var m_drag_target_segment: int
var m_drag_face_sign := 1.0
var m_drag_valid := false
var m_drag_opening_edge := -1    # -1=move, 0=left, 1=right, 2=bottom, 3=top
var m_drag_opening_old_width := 0.0
var m_drag_opening_old_height := 0.0
var m_drag_opening_old_frame_color := Color.WHITE
var m_drag_resize_anchor_2d := Vector2.ZERO
var m_drag_resize_center_2d := Vector2.ZERO
var m_drag_hover_opening: BuildingOpening3DScript
var m_drag_hover_old_color: Color
var m_drag_hover_edge := -1


func apply_prop_settings(settings: Dictionary) -> void:
	m_prop_settings = settings.duplicate(true)
	_clear_prop_preview()


func apply_window_settings(settings: Dictionary) -> void:
	m_window_settings = settings.duplicate(true)


func apply_door_settings(settings: Dictionary) -> void:
	m_door_settings = settings.duplicate(true)
	_clear_prop_preview()


func cancel_preview() -> void:
	_cancel_window_drag()
	_clear_drag_hover()
	_clear_prop_preview()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and !key_event.echo
			and key_event.keycode == KEY_R
			and m_context.active_tool_mode() == MODE_PROP
		):
			m_prop_rotation_y += PI * 0.5
			return m_context.handled()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	return _handle_placement_input(camera, event)


func _handle_placement_input(camera: Camera3D, event: InputEvent) -> int:
	if _is_opening_tool() and m_dragging_opening != null:
		return _handle_window_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		if _is_opening_tool():
			var pick := _find_opening_pick(camera, mouse_pos)
			var hover_opening := pick.get("opening") as BuildingOpening3DScript
			var hover_edge := int(pick.get("edge", -1))
			_update_hover_highlight(hover_opening, hover_edge)
			if hover_opening != null:
				_clear_prop_preview()
				m_context.set_status(
					"Click and drag edge to resize." if hover_edge >= 0
					else "Click and drag to move opening."
				)
				return m_context.handled()
			_clear_drag_hover()
		_update_placement_preview(camera, mouse_pos)
		return m_context.handled() if m_prop_preview != null else EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if _is_opening_tool():
		var pick := _find_opening_pick(camera, mouse_button.position)
		var hit_opening := pick.get("opening") as BuildingOpening3DScript
		if hit_opening != null:
			_clear_drag_hover()
			_start_window_drag(hit_opening, int(pick.get("edge", -1)), pick.get("wall") as Wall3DScript)
			return m_context.handled()

	_update_placement_preview(camera, mouse_button.position)
	if m_preview_valid:
		_commit_placement()
	return m_context.handled()


func _handle_window_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_window_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_window_drag()
			return m_context.handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_window_drag()
			return m_context.handled()
	return m_context.handled()


func _update_placement_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	var hit := m_context.raycast_world(camera, mouse_position)
	var wall := m_context.find_wall_from_collider(hit.get("collider"))

	if _is_opening_tool():
		_update_opening_preview(wall, hit)
		return

	_update_prop_preview(wall, hit)


func _update_opening_preview(wall: Wall3DScript, hit: Dictionary) -> void:
	var settings := _active_opening_settings()
	var label := String(settings["label"])
	if wall == null:
		_clear_prop_preview()
		m_context.set_status("%s openings need a wall target." % label)
		m_preview_valid = false
		return
	var segment_index := int(hit.get("segment", 0))
	var segment := wall.get_segment(segment_index)
	var frame := wall.get_segment_local_frame(segment_index)

	var opening_script := _opening_script_for_settings(settings)
	if m_prop_preview == null or m_prop_preview.get_script() != opening_script:
		_clear_prop_preview()
		m_prop_preview = opening_script.new() as BuildingOpening3DScript
		(m_prop_preview as BuildingOpening3DScript).build_on_ready = true
	m_context.set_preview_parent(m_prop_preview, wall)
	m_context.apply_debug_wireframe_to_node(m_prop_preview)

	var opening := m_prop_preview as BuildingOpening3DScript
	opening.name = "%sPreview" % String(settings["node_name"])
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, segment_index)
	_apply_opening_settings(opening, settings, segment.thickness + 0.04)
	var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
	var face_sign := 1.0 if local_hit.z >= 0.0 else -1.0
	var grid_step := m_context.default_grid_step()
	local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
	var sill_height := maxf(float(settings["sill_height"]), 0.0)
	local_hit.y = sill_height + opening.opening_height * 0.5
	local_hit.z = face_sign * (segment.thickness * 0.5 + 0.035)
	opening.transform = Transform3D(_opening_basis_for_face(frame.basis, face_sign), frame * local_hit)
	opening.set_meta(OPENING_SILL_META, sill_height)
	opening.set_meta(OPENING_ALLOW_BASE_META, bool(settings["allow_base_edge"]))
	var center := Vector2(local_hit.x, local_hit.y)
	var size := Vector2(opening.opening_width, opening.opening_height)
	m_preview_valid = m_context.can_place_wall_opening(
		wall,
		segment_index,
		center,
		size,
		0.04,
		opening,
		bool(settings["allow_base_edge"])
	)
	opening.frame_color = Color(0.20, 0.88, 0.36, 0.72) if m_preview_valid else Color(0.95, 0.20, 0.16, 0.72)
	m_preview_wall = wall
	m_context.set_status("%s ready." % label if m_preview_valid else "%s overlaps or leaves the wall span." % label)


func _apply_opening_settings(opening: BuildingOpening3DScript, settings: Dictionary, frame_depth: float) -> void:
	BuildingFactoryScript.apply_opening_settings(
		opening,
		settings,
		maxf(frame_depth - 0.04, 0.0)
	)


func _opening_script_for_settings(settings: Dictionary) -> Script:
	var style := String(settings.get("style", ""))
	return BuildingFactoryScript.get_opening_style(style).get("script") as Script


# The both-sided frame casing (BuildingOpening3D._frame_casing) assumes the wall
# lies in the opening's local -Z half. Openings placed against the far wall face
# only flip their position via face_sign, not their orientation, so without this
# their -Z points away from the wall and the casing protrudes on one face only.
# Rotate 180 deg about local up so -Z always faces into the wall.


func _opening_basis_for_face(basis: Basis, face_sign: float) -> Basis:
	return BuildingFactoryScript.opening_basis_for_face(basis, face_sign)


func _active_opening_settings() -> Dictionary:
	if m_context.active_tool_mode() == MODE_DOOR:
		var style := String(m_door_settings.get("style", "single_door"))
		var is_double := style.begins_with("double")
		var label := "Single Door"
		match style:
			"double_door":
				label = "Double Door"
			"glazed_door":
				label = "Glazed Door"
			"glazed_grid_door":
				label = "Cross Glazed Door"
			"panel_door":
				label = "Panel Door"
			"dutch_door":
				label = "Dutch Door"
			"single_frame":
				label = "Single Door Frame"
			"double_frame":
				label = "Double Door Frame"
		var default_width := 1.6 if is_double else 0.9
		var node_name := label.replace(" ", "") + "Opening"
		return {
			"style": style,
			"label": label,
			"node_name": node_name,
			"width": float(m_door_settings.get("width", default_width)),
			"height": float(m_door_settings.get("height", 2.1)),
			"frame_thickness": float(m_door_settings.get("frame_thickness", 0.08)),
			"frame_sides": int(m_door_settings.get("frame_sides", 0)),
			"frame_protrusion": float(m_door_settings.get("frame_protrusion", 0.02)),
			"frame_color": Color(m_door_settings.get("frame_color", Color(0.86, 0.92, 0.94, 1.0))),
			"door_panel_depth": float(m_door_settings.get("door_panel_depth", 0.05)),
			"door_panel_color": Color(m_door_settings.get("door_panel_color", Color(0.50, 0.34, 0.20, 1.0))),
			"door_glazing_ratio": float(m_door_settings.get("door_glazing_ratio", 0.55)),
			"door_glass_depth": float(m_door_settings.get("door_glass_depth", 0.03)),
			"door_glass_color": Color(m_door_settings.get("door_glass_color", Color(0.58, 0.82, 0.95, 0.52))),
			"pane_grid_rows": int(m_door_settings.get("pane_grid_rows", 2)),
			"pane_grid_cols": int(m_door_settings.get("pane_grid_cols", 1)),
			"muntin_thickness": float(m_door_settings.get("muntin_thickness", 0.03)),
			"door_inset_rows": int(m_door_settings.get("door_inset_rows", 3)),
			"door_inset_cols": int(m_door_settings.get("door_inset_cols", 2)),
			"sill_height": 0.0,
			"show_bottom_frame": false,
			"allow_base_edge": true,
		}

	var style := String(m_window_settings.get("style", "single_window"))
	var is_double := style == "double_window"
	var label := "Single Window"
	match style:
		"double_window":
			label = "Double Window"
		"grid_window":
			label = "Grid Window"
		"louvered_window":
			label = "Louvered Window"
		"transom_window":
			label = "Transom Window"
		"arched_window":
			label = "Arched Window"
		"frame":
			label = "Window Frame"
	var default_width := 1.8 if is_double else 1.0
	var node_name := label.replace(" ", "") + "Opening"
	return {
		"style": style,
		"label": label,
		"node_name": node_name,
		"width": float(m_window_settings.get("width", default_width)),
		"height": float(m_window_settings["height"]),
		"frame_thickness": float(m_window_settings["frame_thickness"]),
		"frame_sides": int(m_window_settings.get("frame_sides", 0)),
		"frame_protrusion": float(m_window_settings.get("frame_protrusion", 0.02)),
		"frame_color": Color(m_window_settings.get("frame_color", Color(0.86, 0.92, 0.94, 1.0))),
		"window_pane_depth": float(m_window_settings.get("window_pane_depth", 0.03)),
		"window_pane_color": Color(m_window_settings.get("window_pane_color", Color(0.58, 0.82, 0.95, 0.52))),
		"pane_grid_rows": int(m_window_settings.get("pane_grid_rows", 2)),
		"pane_grid_cols": int(m_window_settings.get("pane_grid_cols", 1)),
		"muntin_thickness": float(m_window_settings.get("muntin_thickness", 0.03)),
		"louver_count": int(m_window_settings.get("louver_count", 6)),
		"louver_depth": float(m_window_settings.get("louver_depth", 0.03)),
		"transom_ratio": float(m_window_settings.get("transom_ratio", 0.28)),
		"transom_rail_thickness": float(m_window_settings.get("transom_rail_thickness", 0.03)),
		"arch_steps": int(m_window_settings.get("arch_steps", 3)),
		"sill_height": maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0),
		"show_bottom_frame": true,
		"allow_base_edge": false,
	}


func _update_prop_preview(wall: Wall3DScript, hit: Dictionary) -> void:
	var scene_path := String(m_prop_settings["scene_path"])
	if scene_path.is_empty() or !ResourceLoader.exists(scene_path):
		_clear_prop_preview()
		m_context.set_status("Select a prop scene.")
		m_preview_valid = false
		return

	var created_preview := false
	if m_prop_preview == null or m_prop_preview_path != scene_path:
		_clear_prop_preview()
		m_prop_preview = _instantiate_prop(scene_path)
		m_prop_preview_path = scene_path
		if m_prop_preview == null:
			m_preview_valid = false
			m_context.set_status("Prop scene root must be Node3D.")
			return
		m_context.apply_preview_material(m_prop_preview, Color(0.20, 0.88, 0.36, 0.42))
		created_preview = true

	var parent := wall as Node
	if parent == null:
		parent = m_context.get_or_create_coordinator(false)
	if parent == null:
		parent = m_context.editor_interface().get_edited_scene_root()
	if parent == null:
		_clear_prop_preview()
		m_preview_valid = false
		return

	m_context.set_preview_parent(m_prop_preview, parent)
	if created_preview:
		m_context.apply_debug_wireframe_to_node(m_prop_preview)
	if wall != null:
		var segment_index := int(hit.get("segment", 0))
		var segment := wall.get_segment(segment_index)
		var frame := wall.get_segment_local_frame(segment_index)
		var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
		var face_sign := 1.0 if local_hit.z >= 0.0 else -1.0
		local_hit.z = face_sign * (segment.thickness * 0.5 + 0.04)
		m_prop_preview.transform = Transform3D(
			frame.basis * Basis(Vector3.UP, m_prop_rotation_y),
			frame * local_hit
		)
	else:
		var snapped_world := _snap_placement_world_position(Vector3(hit["position"]))
		m_prop_preview.global_position = snapped_world
		m_prop_preview.rotation = Vector3(0.0, m_prop_rotation_y, 0.0)

	m_preview_valid = _validate_prop_preview(parent, m_prop_preview)
	m_context.apply_preview_material(
		m_prop_preview,
		Color(0.20, 0.88, 0.36, 0.42) if m_preview_valid else Color(0.95, 0.20, 0.16, 0.42)
	)
	m_preview_wall = wall
	m_context.set_status("Prop ready." if m_preview_valid else "Prop is too close to another placed item.")


func _commit_placement() -> void:
	if m_prop_preview == null or m_context.m_preview_parent == null:
		return

	if _is_opening_tool():
		var settings := _active_opening_settings()
		var opening_preview := m_prop_preview as BuildingOpening3DScript
		var wall := m_context.m_preview_parent as Wall3DScript
		if opening_preview == null or wall == null:
			return
		var segment_index := int(
			opening_preview.get_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
		)
		var frame := wall.get_segment_local_frame(segment_index)
		var segment_local := frame.affine_inverse() * opening_preview.position
		var sill_height := float(
			opening_preview.get_meta(OPENING_SILL_META, settings["sill_height"])
		)
		var opening := BuildingFactoryScript.create_opening_node(
			wall,
			segment_index,
			segment_local.x,
			sill_height,
			1.0 if segment_local.z >= 0.0 else -1.0,
			settings
		)
		if opening == null:
			m_context.set_status("Could not create the selected opening style.")
			return
		opening.name = String(settings["node_name"])
		var scene_root := m_context.editor_interface().get_edited_scene_root()
		var undo_redo := m_context.undo_redo()
		undo_redo.create_action("Place Wall Opening")
		undo_redo.add_do_reference(opening)
		undo_redo.add_do_method(m_context, "do_add_node_and_rebuild", wall, opening, scene_root, true)
		undo_redo.add_undo_method(m_context, "undo_remove_node_and_rebuild", wall, opening)
		undo_redo.commit_action()
		m_context.set_status("Placed %s." % String(settings["label"]).to_lower())
		return

	var scene_path := String(m_prop_settings["scene_path"])
	var prop := _instantiate_prop(scene_path)
	if prop == null:
		return
	prop.name = scene_path.get_file().get_basename()
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var parent: Node = m_context.m_preview_parent
	if parent == scene_root and !(parent is Building3DScript):
		var coordinator := m_context.get_or_create_coordinator(true)
		if coordinator != null:
			parent = coordinator
	var parent_3d := parent as Node3D
	if parent_3d != null:
		prop.transform = parent_3d.global_transform.affine_inverse() * m_prop_preview.global_transform
	else:
		prop.transform = m_prop_preview.global_transform
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Place Building Prop")
	undo_redo.add_do_reference(prop)
	undo_redo.add_do_method(m_context, "do_add_node", parent, prop, scene_root, true)
	undo_redo.add_undo_method(m_context, "undo_remove_node", parent, prop)
	undo_redo.commit_action()
	m_context.set_status("Placed prop.")


func _instantiate_prop(scene_path: String) -> Node3D:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.set_meta(BUILDING_PROP_META, true)
	return node


func _validate_prop_preview(parent: Node, preview: Node3D) -> bool:
	var clearance := float(m_prop_settings["clearance"])
	if clearance <= 0.0:
		return true
	for child in parent.get_children():
		if child == preview:
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		if child.has_meta(Wall3DScript.GENERATED_META):
			continue
		if child_3d.global_position.distance_to(preview.global_position) < clearance:
			return false
	return true


func _clear_prop_preview() -> void:
	if m_prop_preview != null and is_instance_valid(m_prop_preview):
		m_prop_preview.queue_free()
	m_prop_preview = null
	m_prop_preview_path = ""
	m_context.m_preview_parent = null
	m_preview_wall = null
	m_preview_valid = false


func _find_opening_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var hit := m_context.raycast_world(camera, mouse_pos)
	var wall := m_context.find_wall_from_collider(hit.get("collider"))
	if wall == null:
		return {}
	var hit_world := Vector3(hit["position"])
	for child in wall.get_children():
		if child.has_meta(Wall3DScript.GENERATED_META):
			continue
		var opening := child as BuildingOpening3DScript
		if opening == null or opening == m_prop_preview:
			continue
		var pick_radius := maxf(opening.opening_width, opening.opening_height) * 0.5 + 0.2
		if hit_world.distance_to(opening.global_position) > pick_radius:
			continue
		# Convert hit to opening's segment-local 2D space
		var seg_idx := wall.get_opening_segment_index(opening)
		var frame := wall.get_segment_local_frame(seg_idx)
		var local_hit := frame.affine_inverse() * wall.to_local(hit_world)
		var local_center := frame.affine_inverse() * opening.position
		var rel := Vector2(local_hit.x - local_center.x, local_hit.y - local_center.y)
		var half_w := opening.opening_width * 0.5
		var half_h := opening.opening_height * 0.5
		var edge_zone := minf(0.22, minf(half_w, half_h) * 0.4)
		# Center zone → move
		if absf(rel.x) < half_w - edge_zone and absf(rel.y) < half_h - edge_zone:
			return {"opening": opening, "edge": -1, "wall": wall}
		# Nearest edge
		var candidates := [
			[absf(rel.x + half_w), 0],  # left
			[absf(rel.x - half_w), 1],  # right
			[absf(rel.y + half_h), 2],  # bottom
			[absf(rel.y - half_h), 3],  # top
		]
		var best_edge := 0
		var best_d := INF
		for c in candidates:
			if float(c[0]) < best_d:
				best_d = float(c[0])
				best_edge = int(c[1])
		return {"opening": opening, "edge": best_edge, "wall": wall}
	return {}


func _update_hover_highlight(opening: BuildingOpening3DScript, edge: int) -> void:
	if opening == m_drag_hover_opening and edge == m_drag_hover_edge:
		return
	_clear_drag_hover()
	if opening == null:
		return
	m_drag_hover_opening = opening
	m_drag_hover_old_color = opening.frame_color
	m_drag_hover_edge = edge
	opening.frame_color = (
		Color(1.0, 0.85, 0.20, 0.9) if edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	)


func _clear_drag_hover() -> void:
	if m_drag_hover_opening == null:
		return
	if is_instance_valid(m_drag_hover_opening):
		m_drag_hover_opening.frame_color = m_drag_hover_old_color
	m_drag_hover_opening = null
	m_drag_hover_edge = -1


func _start_window_drag(
	opening: BuildingOpening3DScript,
	edge: int,
	wall_hint: Wall3DScript
) -> void:
	_clear_prop_preview()
	m_dragging_opening = opening
	m_drag_old_position = opening.position
	m_drag_opening_old_width = opening.opening_width
	m_drag_opening_old_height = opening.opening_height
	m_drag_opening_old_frame_color = (
		m_drag_hover_old_color if opening == m_drag_hover_opening else opening.frame_color
	)
	m_drag_old_segment = int(opening.get_meta(Wall3DScript.SEGMENT_INDEX_META, 0))
	m_drag_target_segment = m_drag_old_segment
	m_drag_opening_edge = edge
	m_drag_valid = true
	var wall := opening.get_parent() as Wall3DScript
	if wall == null:
		wall = wall_hint
	if wall != null:
		var frame := wall.get_segment_local_frame(m_drag_target_segment)
		var local_pos := frame.affine_inverse() * opening.position
		m_drag_face_sign = signf(local_pos.z) if absf(local_pos.z) > 0.001 else 1.0
		m_drag_resize_center_2d = Vector2(local_pos.x, local_pos.y)
		m_drag_resize_anchor_2d = m_drag_resize_center_2d
	else:
		m_drag_face_sign = 1.0
	var color := Color(1.0, 0.85, 0.20, 0.9) if edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	opening.frame_color = color
	var action := "edge" if edge >= 0 else "opening"
	m_context.set_status("Dragging %s — release to commit, Escape to cancel." % action)


func _update_window_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_opening == null or !is_instance_valid(m_dragging_opening):
		m_dragging_opening = null
		return
	var wall := m_dragging_opening.get_parent() as Wall3DScript
	if wall == null:
		_cancel_window_drag()
		return
	var hit := m_context.raycast_world(camera, mouse_pos)
	var hit_wall := m_context.find_wall_from_collider(hit.get("collider"))
	if hit_wall != wall:
		m_dragging_opening.frame_color = Color(0.95, 0.20, 0.16, 0.9)
		m_drag_valid = false
		m_context.set_status("Drag within the same wall.")
		return
	var hit_segment := clampi(int(hit.get("segment", m_drag_target_segment)), 0, wall.get_segment_count() - 1)
	if m_drag_opening_edge < 0:
		m_drag_target_segment = hit_segment
	var segment := wall.get_segment(m_drag_target_segment)
	var frame := wall.get_segment_local_frame(m_drag_target_segment)
	var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
	var grid_step := m_context.default_grid_step()

	if m_drag_opening_edge >= 0:
		# Resize mode: adjust width or height based on which edge is dragged
		var hit_2d := Vector2(local_hit.x, local_hit.y)
		var delta := hit_2d - m_drag_resize_anchor_2d
		var new_width := m_drag_opening_old_width
		var new_height := m_drag_opening_old_height
		match m_drag_opening_edge:
			0:  # left edge: moving left increases width
				new_width = maxf(roundf((m_drag_opening_old_width - 2.0 * delta.x) / grid_step) * grid_step, grid_step)
			1:  # right edge: moving right increases width
				new_width = maxf(roundf((m_drag_opening_old_width + 2.0 * delta.x) / grid_step) * grid_step, grid_step)
			2:  # bottom edge: moving down increases height
				new_height = maxf(roundf((m_drag_opening_old_height - 2.0 * delta.y) / grid_step) * grid_step, grid_step)
			3:  # top edge: moving up increases height
				new_height = maxf(roundf((m_drag_opening_old_height + 2.0 * delta.y) / grid_step) * grid_step, grid_step)
		m_dragging_opening.opening_width = new_width
		m_dragging_opening.opening_height = new_height
		# Keep center position fixed (sill constraint: re-apply to Y)
		var sill_height := _opening_sill_height(m_dragging_opening)
		var center_local := Vector3(
			m_drag_resize_center_2d.x,
			sill_height + new_height * 0.5,
			m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
		)
		m_dragging_opening.transform = Transform3D(
			_opening_basis_for_face(frame.basis, m_drag_face_sign), frame * center_local
		)
		var center_2d := Vector2(center_local.x, center_local.y)
		var size := Vector2(new_width, new_height)
		m_drag_valid = m_context.can_place_wall_opening(
			wall,
			m_drag_target_segment,
			center_2d,
			size,
			0.04,
			m_dragging_opening,
			_opening_allow_base_edge(m_dragging_opening)
		)
	else:
		# Move mode
		m_drag_face_sign = signf(local_hit.z) if absf(local_hit.z) > 0.001 else m_drag_face_sign
		local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
		var sill_height := _opening_sill_height(m_dragging_opening)
		local_hit.y = sill_height + m_dragging_opening.opening_height * 0.5
		local_hit.z = m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
		m_dragging_opening.transform = Transform3D(
			_opening_basis_for_face(frame.basis, m_drag_face_sign), frame * local_hit
		)
		var center := Vector2(local_hit.x, local_hit.y)
		var size := Vector2(m_dragging_opening.opening_width, m_dragging_opening.opening_height)
		m_drag_valid = m_context.can_place_wall_opening(
			wall,
			m_drag_target_segment,
			center,
			size,
			0.04,
			m_dragging_opening,
			_opening_allow_base_edge(m_dragging_opening)
		)

	var ok_color := Color(1.0, 0.85, 0.20, 0.9) if m_drag_opening_edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	m_dragging_opening.frame_color = ok_color if m_drag_valid else Color(0.95, 0.20, 0.16, 0.9)
	m_context.set_status("Release to commit." if m_drag_valid else "Position overlaps or is out of bounds.")


func _commit_window_drag() -> void:
	if m_dragging_opening == null:
		return
	var wall := m_dragging_opening.get_parent() as Wall3DScript
	if wall == null or !m_drag_valid:
		_cancel_window_drag()
		if !m_drag_valid:
			m_context.set_status("Cannot place opening there — canceled.")
		return
	var opening := m_dragging_opening
	var new_position := opening.position
	var new_width := opening.opening_width
	var new_height := opening.opening_height
	var old_position := m_drag_old_position
	var old_width := m_drag_opening_old_width
	var old_height := m_drag_opening_old_height
	var old_segment := m_drag_old_segment
	var target_segment := m_drag_target_segment
	m_dragging_opening = null
	var undo_redo := m_context.undo_redo()
	if m_drag_opening_edge >= 0:
		undo_redo.create_action("Resize Wall Opening")
		undo_redo.add_do_method(self, "_do_resize_opening", opening, new_position, new_width, new_height, wall)
		undo_redo.add_undo_method(self, "_do_resize_opening", opening, old_position, old_width, old_height, wall)
	else:
		undo_redo.create_action("Move Wall Opening")
		undo_redo.add_do_method(self, "_do_move_opening", opening, new_position, target_segment, wall)
		undo_redo.add_undo_method(self, "_do_move_opening", opening, old_position, old_segment, wall)
	undo_redo.commit_action()
	opening.frame_color = m_drag_opening_old_frame_color
	m_context.set_status("Resized wall opening." if m_drag_opening_edge >= 0 else "Moved wall opening.")
	m_drag_opening_edge = -1


func _opening_sill_height(opening: BuildingOpening3DScript) -> float:
	if opening != null and opening.has_meta(OPENING_SILL_META):
		return maxf(float(opening.get_meta(OPENING_SILL_META)), 0.0)
	return 0.0 if m_context.active_tool_mode() == MODE_DOOR else maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0)


func _opening_allow_base_edge(opening: BuildingOpening3DScript) -> bool:
	if opening != null and opening.has_meta(OPENING_ALLOW_BASE_META):
		return bool(opening.get_meta(OPENING_ALLOW_BASE_META))
	return m_context.active_tool_mode() == MODE_DOOR


func _cancel_window_drag() -> void:
	if m_dragging_opening == null:
		return
	if is_instance_valid(m_dragging_opening):
		m_dragging_opening.position = m_drag_old_position
		m_dragging_opening.opening_width = m_drag_opening_old_width
		m_dragging_opening.opening_height = m_drag_opening_old_height
		m_dragging_opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, m_drag_old_segment)
		m_dragging_opening.frame_color = m_drag_opening_old_frame_color
		var wall := m_dragging_opening.get_parent() as Wall3DScript
		if wall != null:
			wall.rebuild_wall_mesh()
	m_dragging_opening = null
	m_drag_valid = false
	m_drag_opening_edge = -1


func _do_move_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	segment_index: int,
	wall: Wall3DScript
) -> void:
	opening.position = new_pos
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, segment_index)
	wall.rebuild_wall_mesh()


func _do_resize_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	new_width: float,
	new_height: float,
	wall: Wall3DScript
) -> void:
	opening.position = new_pos
	opening.opening_width = new_width
	opening.opening_height = new_height
	wall.rebuild_wall_mesh()


func _is_opening_tool() -> bool:
	return m_context.active_tool_mode() == MODE_WINDOW or m_context.active_tool_mode() == MODE_DOOR


func _snap_placement_world_position(world_position: Vector3) -> Vector3:
	return m_context.snap_world_position(world_position, m_context.default_grid_step())
