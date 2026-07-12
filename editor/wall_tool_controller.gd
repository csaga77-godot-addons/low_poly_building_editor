@tool
extends "res://addons/low_poly_building_editor/editor/building_tool_controller.gd"

## Wall tool controller — owns the wall/room dock settings, span drawing with
## optional 8-way locking, segment-aware joint/endpoint/body drag editing,
## room-side resizing, zero-length deletion, and the wall-geometry undo/redo
## helper family (stage 6 of the plugin split). Undo/redo actions bind this
## plugin-lifetime controller, the context, or the edited nodes.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const WallSegmentScript = preload("res://addons/low_poly_building_editor/walls/wall_segment.gd")

const WALL_TYPE_WALL := "wall"
const WALL_TYPE_ROOM := "room"

var m_wall_settings := {
	"grid_step": 0.5,
	"type": WALL_TYPE_WALL,
	"room_sides": 4,
	"base_height": 0.0,
	"height": 2.4,
	"thickness": 0.22,
	"color": Color(0.78, 0.68, 0.54, 1.0),
	"lock_8_way": true,
}
var m_wall_start_local := Vector3.ZERO
var m_wall_end_local := Vector3.ZERO
var m_wall_start_screen_position := Vector2.ZERO
var m_wall_has_valid_preview := false
var m_wall_release_commits_preview := false
var m_is_drawing_wall := false
var m_wall_preview: Wall3DScript
var m_dragging_wall: Wall3DScript
var m_drag_wall_old_start: Vector3
var m_drag_wall_old_end: Vector3
var m_drag_wall_old_segments: Array[WallSegmentScript] = []
var m_drag_wall_opening_anchors: Array = []
var m_drag_wall_anchor_local: Vector3
var m_drag_wall_segment_index := 0
var m_drag_wall_endpoint := -1   # -1=full move, 0=start pt, 1=end pt
var m_drag_wall_joint_origin := Vector3.ZERO
var m_drag_wall_dragging_joint := false
var m_drag_wall_detaching_joint := false
var m_drag_wall_has_connection_snap := false
var m_drag_wall_resizing_room_side := false
var m_drag_wall_hover: Wall3DScript
var m_drag_wall_hover_material: Material
var m_drag_wall_hover_segment := 0
var m_drag_wall_hover_endpoint := -1
var m_drag_wall_hover_has_joint := false
var m_drag_wall_hover_joint_position := Vector3.ZERO
var m_drag_wall_hover_joint_marker: MeshInstance3D
var m_drag_wall_active_material: Material


func apply_settings(settings: Dictionary) -> void:
	var previous_type := _wall_tool_type()
	m_wall_settings = settings.duplicate(true)
	if _wall_tool_type() != previous_type:
		_clear_wall_preview()
		_reset_wall_drawing_state()


func cancel_preview() -> void:
	_cancel_wall_drag()
	_clear_wall_hover()
	_clear_wall_preview()
	_reset_wall_drawing_state()


func handle_input(camera: Camera3D, event: InputEvent) -> int:
	return _handle_wall_input(camera, event)


func _handle_wall_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_wall != null:
		return _handle_wall_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_wall:
			_update_wall_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_wall_start_screen_position) >= DRAG_COMMIT_DISTANCE:
				m_wall_release_commits_preview = true
			return m_context.handled()
		var pick := _find_wall_pick(camera, mouse_motion.position)
		var hover_wall := pick.get("wall") as Wall3DScript
		var hover_segment := int(pick.get("segment", 0))
		var hover_ep := int(pick.get("endpoint", -1))
		var hover_joint_position := Vector3.ZERO
		if pick.has("joint_position"):
			hover_joint_position = Vector3(pick["joint_position"])
		var hover_has_joint := bool(pick.get("joint", false))
		_update_wall_hover(hover_wall, hover_segment, hover_ep, hover_joint_position, hover_has_joint)
		if hover_wall != null:
			m_context.set_status(
				"Drag joint to move connected walls. Option-drag to disconnect." if hover_has_joint
				else "Click and drag endpoint to resize." if hover_ep >= 0
				else "Drag a side to resize the room. Option-drag to move the whole room."
				if hover_wall.is_rectangular_loop(_wall_joint_tolerance(hover_wall))
				else "Click and drag to move wall. Shift-click to add joint."
			)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_wall:
		if !m_wall_release_commits_preview:
			m_context.set_status(
				"Click the opposite corner to place room, or drag from the start point and release."
				if _is_room_wall_mode()
				else "Click another point to place wall, or drag from the start point and release."
			)
			return m_context.handled()
		m_context.set_status("%s mouse release captured." % _wall_draw_label())
		var release_coordinator := _get_active_wall_coordinator()
		if release_coordinator != null:
			var release_end := m_wall_end_local
			if !m_wall_has_valid_preview:
				release_end = _resolve_wall_end_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_wall(release_coordinator, m_wall_start_local, release_end)
		_clear_wall_preview()
		_reset_wall_drawing_state()
		return m_context.handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_wall:
		var pick := _find_wall_pick(camera, mouse_button.position)
		var hit_wall := pick.get("wall") as Wall3DScript
		if hit_wall != null:
			if mouse_button.shift_pressed and int(pick.get("endpoint", -1)) < 0:
				_commit_add_wall_joint(
					hit_wall,
					int(pick.get("segment", 0)),
					Vector3(pick.get("position", hit_wall.global_position))
				)
				return m_context.handled()
			_clear_wall_hover()
			_start_wall_drag(
				hit_wall,
				camera,
				mouse_button.position,
				int(pick.get("segment", 0)),
				int(pick.get("endpoint", -1)),
				bool(mouse_button.alt_pressed)
			)
			return m_context.handled()

	var coordinator := m_context.get_or_create_coordinator(true)
	if coordinator == null:
		m_context.set_status("Open or create a scene before drawing walls.")
		return m_context.handled()

	var snapped_local := _wall_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_wall:
		m_wall_start_local = snapped_local
		m_wall_end_local = snapped_local
		m_wall_start_screen_position = mouse_button.position
		m_wall_has_valid_preview = false
		m_wall_release_commits_preview = false
		m_is_drawing_wall = true
		_create_wall_preview(coordinator)
		_update_wall_preview(camera, mouse_button.position)
		m_context.set_status(
			"%s mouse press captured. Drag and release, or click %s."
			% [
				_wall_draw_label(),
				"the opposite corner" if _is_room_wall_mode() else "another point",
			]
		)
		return m_context.handled()

	var local_end := _constrain_wall_end_on_base(coordinator, m_wall_start_local, snapped_local)
	_commit_wall(coordinator, m_wall_start_local, local_end)
	_clear_wall_preview()
	_reset_wall_drawing_state()
	return m_context.handled()


func _handle_wall_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_wall_drag(camera, (event as InputEventMouseMotion).position)
		return m_context.handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_wall_drag()
			return m_context.handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_wall_drag()
			return m_context.handled()
	return m_context.handled()


func _create_wall_preview(coordinator: Building3DScript) -> void:
	_clear_wall_preview()
	m_wall_preview = Wall3DScript.new() as Wall3DScript
	m_wall_preview.name = "WallPreview"
	m_wall_preview.set_meta(Wall3DScript.PREVIEW_META, true)
	m_wall_preview.wall_height = float(m_wall_settings["height"])
	m_wall_preview.wall_thickness = float(m_wall_settings["thickness"])
	var preview_color := Color(m_wall_settings["color"])
	preview_color.a = 0.48
	m_wall_preview.wall_color = preview_color
	m_wall_preview.generate_collision = false
	coordinator.add_child(m_wall_preview)
	m_wall_preview.owner = null
	m_context.apply_debug_wireframe_to_node(m_wall_preview)


func _update_wall_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_wall_preview == null:
		return
	var coordinator := m_wall_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var local_position := _wall_draw_local_from_mouse(coordinator, camera, mouse_position)
	var local_end := _constrain_wall_end_on_base(coordinator, m_wall_start_local, local_position)
	m_wall_end_local = local_end
	m_wall_has_valid_preview = _is_wall_draw_valid(m_wall_start_local, local_end)
	_set_wall_preview_geometry(m_wall_start_local, local_end)
	if m_wall_has_valid_preview:
		m_context.set_status("Release or click to place room." if _is_room_wall_mode() else "Release or click to place wall.")


func _set_wall_preview_geometry(local_start: Vector3, local_end: Vector3) -> void:
	if m_wall_preview == null:
		return
	if !_is_room_wall_mode():
		m_wall_preview.set_wall_geometry(local_start, local_end, [])
		return
	var segments := BuildingFactoryScript.room_segments_from_corners(
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		float(m_wall_settings["thickness"]),
		m_wall_preview.wall_color,
		_room_side_count()
	)
	var extras: Array[WallSegmentScript] = []
	for index in range(1, segments.size()):
		extras.append(segments[index])
	m_wall_preview.set_wall_geometry(segments[0].start_point, segments[0].end_point, extras)


func _resolve_wall_end_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var local_position := _wall_draw_local_from_mouse(coordinator, camera, mouse_position)
	return _constrain_wall_end_on_base(coordinator, m_wall_start_local, local_position)


func _wall_base_height() -> float:
	return float(m_wall_settings.get("base_height", 0.0))


func _wall_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _wall_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_wall_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := m_context.raycast_world(camera, mouse_position, false)
	return _snap_wall_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_wall_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_wall_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _constrain_wall_end_on_base(
	_coordinator: Building3DScript,
	start_local: Vector3,
	target_local: Vector3
) -> Vector3:
	if _is_room_wall_mode():
		return Vector3(target_local.x, start_local.y, target_local.z)
	var constrained := BuildingFactoryScript.constrain_wall_end(
		start_local,
		target_local,
		float(m_wall_settings["grid_step"]),
		bool(m_wall_settings["lock_8_way"])
	)
	constrained.y = start_local.y
	return constrained


func _get_active_wall_coordinator() -> Building3DScript:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		var preview_parent := m_wall_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return m_context.get_or_create_coordinator(false)


func _commit_wall(coordinator: Building3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_wall_draw_valid(local_start, local_end):
		m_context.set_status("Room is too small." if _is_room_wall_mode() else "Wall is too short.")
		return

	var thickness := float(m_wall_settings["thickness"])
	if _is_room_wall_mode():
		_commit_room(coordinator, local_start, local_end, thickness)
		return
	var merge := coordinator.find_merge_target(
		local_start,
		local_end,
		thickness,
		float(m_wall_settings["height"]),
		m_wall_preview,
		float(m_wall_settings["grid_step"])
	)
	var undo_redo := m_context.undo_redo()
	if !merge.is_empty():
		var target := merge["wall"] as Wall3DScript
		var target_primary := target.get_segment(0)
		if target_primary == null:
			return
		var old_start := target_primary.start_point
		var old_end := target_primary.end_point
		undo_redo.create_action("Merge Wall")
		undo_redo.add_do_method(
			self,
			"_set_wall_endpoints_and_refresh_intersections",
			target,
			merge["start"],
			merge["end"],
			coordinator
		)
		undo_redo.add_undo_method(
			self,
			"_set_wall_endpoints_and_refresh_intersections",
			target,
			old_start,
			old_end,
			coordinator
		)
		undo_redo.commit_action()
		m_context.select_node(target)
		m_context.set_status("Merged wall span.")
		return

	var intersects_existing_wall := false
	var targets := coordinator.find_intersecting_walls(local_start, local_end, thickness, m_wall_preview)
	if !targets.is_empty():
		intersects_existing_wall = true

	var wall := BuildingFactoryScript.create_wall_node(coordinator,
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		thickness,
		Color(m_wall_settings["color"])
	)
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	undo_redo.create_action("Create Wall")
	undo_redo.add_do_reference(wall)
	undo_redo.add_do_method(
		m_context,
		"do_add_node_and_refresh_wall_intersections",
		coordinator,
		wall,
		scene_root,
		true,
		coordinator
	)
	undo_redo.add_undo_method(m_context, "undo_remove_node_and_refresh_wall_intersections", coordinator, wall, coordinator)
	undo_redo.commit_action()
	if intersects_existing_wall:
		m_context.set_status("Created clipped wall: %.2f units." % local_start.distance_to(local_end))
	else:
		m_context.set_status("Created wall: %.2f units." % local_start.distance_to(local_end))


func _commit_room(
	coordinator: Building3DScript,
	local_start: Vector3,
	local_end: Vector3,
	thickness: float
) -> void:
	var wall := BuildingFactoryScript.create_room_node(coordinator,
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		thickness,
		Color(m_wall_settings["color"]),
		_room_side_count()
	)
	var intersects_existing_wall := false
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if !coordinator.find_intersecting_walls(
			segment.start_point,
			segment.end_point,
			segment.thickness,
			m_wall_preview
		).is_empty():
			intersects_existing_wall = true
			break
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Create Room")
	undo_redo.add_do_reference(wall)
	undo_redo.add_do_method(
		m_context,
		"do_add_node_and_refresh_wall_intersections",
		coordinator,
		wall,
		scene_root,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		m_context,
		"undo_remove_node_and_refresh_wall_intersections",
		coordinator,
		wall,
		coordinator
	)
	undo_redo.commit_action()
	var room_size := Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	m_context.set_status(
		"Created clipped room: %.2f x %.2f." % [room_size.x, room_size.y]
		if intersects_existing_wall
		else "Created room: %.2f x %.2f." % [room_size.x, room_size.y]
	)


func _active_grid_step(wall: Wall3DScript) -> float:
	return maxf(float(m_wall_settings["grid_step"]), 0.05)


func _apply_wall_geometry(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	opening_anchors: Array = []
) -> void:
	wall.set_wall_geometry(new_start, new_end, _duplicate_segments(segments), opening_anchors)


func _set_wall_endpoints_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	coordinator: Building3DScript
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	wall.set_wall_endpoints(new_start, new_end)
	m_context.refresh_wall_intersections(coordinator)


func _do_set_wall_geometry(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	_apply_wall_geometry(wall, new_start, new_end, segments)
	if select_after:
		m_context.select_node(wall)


func _do_set_wall_geometry_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool,
	coordinator: Building3DScript
) -> void:
	_do_set_wall_geometry(wall, new_start, new_end, segments, select_after)
	m_context.refresh_wall_intersections(coordinator)


func _do_set_wall_geometry_preserving_children(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	wall.set_wall_geometry_preserving_child_transforms(
		new_start,
		new_end,
		_duplicate_segments(segments)
	)
	if select_after:
		m_context.select_node(wall)


func _do_set_wall_geometry_preserving_children_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool,
	coordinator: Building3DScript
) -> void:
	_do_set_wall_geometry_preserving_children(wall, new_start, new_end, segments, select_after)
	m_context.refresh_wall_intersections(coordinator)


func _duplicate_segments(segments: Array) -> Array[WallSegmentScript]:
	var copies: Array[WallSegmentScript] = []
	for segment in segments:
		var typed_segment := segment as WallSegmentScript
		if typed_segment == null:
			continue
		copies.append(typed_segment.duplicate() as WallSegmentScript)
	return copies


func _duplicate_wall_segments(wall: Wall3DScript) -> Array[WallSegmentScript]:
	var segments: Array[WallSegmentScript] = []
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment == null:
			continue
		segments.append(segment.duplicate() as WallSegmentScript)
	return segments


func _normalized_wall_geometry(wall: Wall3DScript) -> Dictionary:
	var tolerance := maxf(_active_grid_step(wall) * 0.25, 0.03)
	var combined: Array[WallSegmentScript] = []
	for segment in _duplicate_wall_segments(wall):
		WallSegmentScript.merge_into(combined, segment, tolerance, false)
	var split_segments := WallSegmentScript.split_at_intersections(combined, tolerance)
	return _wall_geometry_from_segments(split_segments)


func _wall_geometry_from_segments(segments: Array) -> Dictionary:
	if segments.is_empty():
		return {}
	var primary := segments[0] as WallSegmentScript
	if primary == null:
		return {}
	var extras: Array[WallSegmentScript] = []
	for segment_index in range(1, segments.size()):
		var segment := segments[segment_index] as WallSegmentScript
		if segment == null:
			continue
		extras.append(segment.duplicate() as WallSegmentScript)
	return {
		"start": primary.start_point,
		"end": primary.end_point,
		"segments": extras,
	}


func _wall_geometry_snapshot(wall: Wall3DScript) -> Dictionary:
	if wall == null:
		return {}
	return _wall_geometry_from_segments(_duplicate_wall_segments(wall))


func _wall_segment_zero_epsilon(wall: Wall3DScript) -> float:
	return maxf(_active_grid_step(wall) * 0.01, 0.001)


func _is_dragged_wall_span_zero_length(wall: Wall3DScript) -> bool:
	if wall == null:
		return false
	var segment_index := clampi(m_drag_wall_segment_index, 0, wall.get_segment_count() - 1)
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	return segment.get_length() <= _wall_segment_zero_epsilon(wall)


func _wall_geometry_without_segment(
	wall: Wall3DScript,
	removed_segment_index: int
) -> Dictionary:
	var remaining: Array[WallSegmentScript] = []
	var zero_epsilon := _wall_segment_zero_epsilon(wall)
	for segment_index in range(wall.get_segment_count()):
		if segment_index == removed_segment_index:
			continue
		var segment := wall.get_segment(segment_index).duplicate() as WallSegmentScript
		if segment == null or segment.get_length() <= zero_epsilon:
			continue
		remaining.append(segment)
	if remaining.is_empty():
		return {}
	return _wall_geometry_from_segments(remaining)


func _commit_add_wall_joint(
	wall: Wall3DScript,
	segment_index: int,
	hit_world: Vector3
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	var hit_parent_local := _wall_world_to_parent_local(wall, hit_world)
	var coordinator := m_context.find_coordinator_from_node(wall)
	if coordinator != null:
		hit_parent_local = BuildingFactoryScript.snap_local_position(
			hit_parent_local,
			float(m_wall_settings["grid_step"])
		)
	var minimum_piece_length := maxf(_active_grid_step(wall) * 0.5, 0.1)
	var geometry := wall.split_segment_geometry(segment_index, hit_parent_local, minimum_piece_length)
	if geometry.is_empty():
		m_context.set_status("Joint is too close to an endpoint.")
		return
	var old_geometry := _wall_geometry_snapshot(wall)
	if old_geometry.is_empty():
		return
	var old_start := Vector3(old_geometry["start"])
	var old_end := Vector3(old_geometry["end"])
	var old_segments: Array[WallSegmentScript] = old_geometry["segments"]
	var new_segments: Array[WallSegmentScript] = geometry["segments"]
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Add Wall Joint")
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry_preserving_children_and_refresh_intersections",
		wall,
		Vector3(geometry["start"]),
		Vector3(geometry["end"]),
		new_segments,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_do_set_wall_geometry_preserving_children_and_refresh_intersections",
		wall,
		old_start,
		old_end,
		old_segments,
		true,
		coordinator
	)
	undo_redo.commit_action()
	_clear_wall_hover()
	m_context.set_status("Added wall joint.")


func _wall_world_to_parent_local(wall: Wall3DScript, world_position: Vector3) -> Vector3:
	var wall_parent := wall.get_parent() as Node3D
	if wall_parent != null:
		return wall_parent.to_local(world_position)
	return wall.to_local(world_position)


func _commit_delete_zero_length_wall_segment(
	wall: Wall3DScript,
	geometry: Dictionary,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegmentScript]
) -> void:
	var next_segments: Array[WallSegmentScript] = geometry["segments"]
	var coordinator := m_context.find_coordinator_from_node(wall)
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Delete Wall Segment")
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		Vector3(geometry["start"]),
		Vector3(geometry["end"]),
		next_segments,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		old_start,
		old_end,
		old_segments,
		true,
		coordinator
	)
	undo_redo.commit_action()
	m_context.set_status("Deleted zero-length wall segment.")


func _commit_delete_zero_length_wall(
	wall: Wall3DScript,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegmentScript]
) -> void:
	var parent := wall.get_parent()
	var coordinator := parent as Building3DScript
	var scene_root := m_context.editor_interface().get_edited_scene_root()
	if parent == null or scene_root == null:
		_apply_wall_geometry(wall, old_start, old_end, old_segments)
		m_context.set_status("Wall is too short.")
		return
	_apply_wall_geometry(wall, old_start, old_end, old_segments)
	var undo_redo := m_context.undo_redo()
	undo_redo.create_action("Delete Wall")
	undo_redo.add_undo_reference(wall)
	undo_redo.add_do_method(m_context, "undo_remove_node_and_refresh_wall_intersections", parent, wall, coordinator)
	undo_redo.add_undo_method(
		m_context,
		"do_add_node_and_refresh_wall_intersections",
		parent,
		wall,
		scene_root,
		true,
		coordinator
	)
	undo_redo.commit_action()
	m_context.set_status("Deleted zero-length wall.")


func _apply_drag_wall_endpoint(snapped_position: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	_apply_wall_geometry(
		m_dragging_wall,
		m_drag_wall_old_start,
		m_drag_wall_old_end,
		extras,
		m_drag_wall_opening_anchors
	)
	if m_drag_wall_dragging_joint:
		m_dragging_wall.move_connected_endpoint(
			m_drag_wall_joint_origin,
			snapped_position,
			_wall_joint_tolerance(m_dragging_wall)
		)
		return
	m_dragging_wall.move_segment_endpoint(
		m_drag_wall_segment_index,
		m_drag_wall_endpoint,
		snapped_position
	)


func _translate_drag_wall_geometry(delta: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	for segment in extras:
		segment.start_point += delta
		segment.end_point += delta
	_apply_wall_geometry(
		m_dragging_wall,
		m_drag_wall_old_start + delta,
		m_drag_wall_old_end + delta,
		extras,
		m_drag_wall_opening_anchors
	)


func _resize_drag_room_side(delta: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	_apply_wall_geometry(
		m_dragging_wall,
		m_drag_wall_old_start,
		m_drag_wall_old_end,
		extras,
		m_drag_wall_opening_anchors
	)
	m_dragging_wall.move_rectangular_loop_side(
		m_drag_wall_segment_index,
		delta,
		_wall_joint_tolerance(m_dragging_wall)
	)


func _is_dragged_wall_span_long_enough(wall: Wall3DScript) -> bool:
	if wall == null:
		return false
	var segment_index := clampi(m_drag_wall_segment_index, 0, wall.get_segment_count() - 1)
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	return _is_wall_span_long_enough(segment.start_point, segment.end_point)


func _are_dragged_wall_spans_long_enough(wall: Wall3DScript) -> bool:
	if wall == null:
		return false
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment == null or !_is_wall_span_long_enough(segment.start_point, segment.end_point):
			return false
	return true


func _find_intersecting_targets_for_wall(
	coordinator: Building3DScript,
	wall: Wall3DScript
) -> Array[Wall3DScript]:
	var targets: Array[Wall3DScript] = []
	for segment in _duplicate_wall_segments(wall):
		var hits := coordinator.find_intersecting_walls(
			segment.start_point,
			segment.end_point,
			segment.thickness,
			wall
		)
		for candidate in hits:
			if candidate == wall or targets.has(candidate):
				continue
			targets.append(candidate)
	return targets


func _clear_wall_preview() -> void:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		m_wall_preview.queue_free()
	m_wall_preview = null


func _reset_wall_drawing_state() -> void:
	m_is_drawing_wall = false
	m_wall_has_valid_preview = false
	m_wall_release_commits_preview = false
	m_wall_start_screen_position = Vector2.ZERO


func _find_wall_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var hit := m_context.raycast_world(camera, mouse_pos)
	var wall := m_context.find_wall_from_collider(hit.get("collider"))
	if wall == null:
		return {}
	var hit_world := Vector3(hit["position"])
	var ep_radius := 0.4
	var segment_hint := int(hit.get("segment", 0))
	var wall_parent := wall.get_parent() as Node3D
	var hit_parent_local := wall_parent.to_local(hit_world) if wall_parent != null else wall.to_local(hit_world)
	for offset in range(wall.get_segment_count()):
		var segment_index := (segment_hint + offset) % wall.get_segment_count()
		var segment := wall.get_segment(segment_index)
		if _hit_near_wall_endpoint(hit_parent_local, segment.start_point, segment, ep_radius):
			var start_joint := _wall_joint_info(wall, segment.start_point)
			return {
				"wall": wall,
				"segment": segment_index,
				"endpoint": 0,
				"joint": bool(start_joint["joint"]),
				"joint_position": start_joint["position"],
				"position": hit_world,
			}
		if _hit_near_wall_endpoint(hit_parent_local, segment.end_point, segment, ep_radius):
			var end_joint := _wall_joint_info(wall, segment.end_point)
			return {
				"wall": wall,
				"segment": segment_index,
				"endpoint": 1,
				"joint": bool(end_joint["joint"]),
				"joint_position": end_joint["position"],
				"position": hit_world,
			}
	return {"wall": wall, "segment": segment_hint, "endpoint": -1, "position": hit_world}


func _hit_near_wall_endpoint(
	hit_parent_local: Vector3,
	endpoint: Vector3,
	segment: WallSegmentScript,
	radius: float
) -> bool:
	if hit_parent_local.y < endpoint.y - radius or hit_parent_local.y > endpoint.y + segment.height + radius:
		return false
	var hit_2d := Vector2(hit_parent_local.x, hit_parent_local.z)
	var endpoint_2d := Vector2(endpoint.x, endpoint.z)
	return hit_2d.distance_to(endpoint_2d) <= radius


func _wall_joint_info(wall: Wall3DScript, endpoint: Vector3) -> Dictionary:
	var tolerance := _wall_joint_tolerance(wall)
	var count := 0
	var total := Vector3.ZERO
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment.start_point.distance_to(endpoint) <= tolerance:
			count += 1
			total += segment.start_point
		if segment.end_point.distance_to(endpoint) <= tolerance:
			count += 1
			total += segment.end_point
	var position := endpoint
	if count > 0:
		position = total / float(count)
	return {
		"joint": count >= 2,
		"position": position,
		"count": count,
	}


func _wall_joint_tolerance(wall: Wall3DScript) -> float:
	return maxf(_active_grid_step(wall) * 0.05, 0.03)


func _wall_connection_snap_radius(wall: Wall3DScript) -> float:
	return maxf(maxf(_active_grid_step(wall) * 0.45, wall.wall_thickness * 1.25), 0.08)


func _drag_wall_endpoint_position(
	wall: Wall3DScript,
	segment_index: int,
	endpoint: int
) -> Vector3:
	if wall == null or wall.get_segment_count() <= 0:
		return Vector3.ZERO
	var segment := wall.get_segment(clampi(segment_index, 0, wall.get_segment_count() - 1))
	if segment == null:
		return Vector3.ZERO
	return segment.start_point if endpoint == 0 else segment.end_point


func _snap_drag_wall_endpoint_to_connection(snapped_position: Vector3) -> Vector3:
	m_drag_wall_has_connection_snap = false
	if m_dragging_wall == null or m_drag_wall_endpoint < 0 or m_drag_wall_dragging_joint:
		return snapped_position
	var target := _nearest_wall_connection_endpoint(
		m_dragging_wall,
		snapped_position,
		_wall_connection_snap_radius(m_dragging_wall)
	)
	if target.is_empty():
		return snapped_position
	var target_position := Vector3(target["position"])
	m_drag_wall_has_connection_snap = true
	return Vector3(target_position.x, snapped_position.y, target_position.z)


func _nearest_wall_connection_endpoint(
	wall: Wall3DScript,
	position: Vector3,
	radius: float
) -> Dictionary:
	var candidates: Array[Wall3DScript] = []
	var coordinator := m_context.find_coordinator_from_node(wall)
	if coordinator != null:
		candidates = coordinator.get_wall_nodes()
	else:
		candidates.append(wall)
	var best_distance := radius
	var best_position := Vector3.ZERO
	var found := false
	for candidate_wall in candidates:
		if candidate_wall == null or !is_instance_valid(candidate_wall):
			continue
		if candidate_wall.has_meta(Wall3DScript.PREVIEW_META):
			continue
		for segment_index in range(candidate_wall.get_segment_count()):
			var segment := candidate_wall.get_segment(segment_index)
			var endpoints := [segment.start_point, segment.end_point]
			for endpoint_index in range(endpoints.size()):
				if (
					candidate_wall == wall
					and segment_index == m_drag_wall_segment_index
					and endpoint_index == m_drag_wall_endpoint
				):
					continue
				var endpoint := Vector3(endpoints[endpoint_index])
				if absf(endpoint.y - position.y) > 0.01:
					continue
				var distance := Vector2(endpoint.x - position.x, endpoint.z - position.z).length()
				if distance > best_distance:
					continue
				best_distance = distance
				best_position = endpoint
				found = true
	if !found:
		return {}
	return {
		"position": best_position,
		"distance": best_distance,
	}


func _update_wall_hover(
	wall: Wall3DScript,
	segment_index: int,
	endpoint: int,
	joint_position: Vector3,
	has_joint: bool
) -> void:
	if (
		wall == m_drag_wall_hover
		and segment_index == m_drag_wall_hover_segment
		and endpoint == m_drag_wall_hover_endpoint
		and has_joint == m_drag_wall_hover_has_joint
		and (!has_joint or joint_position.distance_to(m_drag_wall_hover_joint_position) <= 0.001)
	):
		return
	_clear_wall_hover()
	if wall == null:
		return
	m_drag_wall_hover = wall
	m_drag_wall_hover_segment = segment_index
	m_drag_wall_hover_endpoint = endpoint
	m_drag_wall_hover_has_joint = has_joint
	m_drag_wall_hover_joint_position = joint_position
	m_drag_wall_hover_material = wall.material_override
	var color := Color(1.0, 0.85, 0.20, 0.65) if endpoint >= 0 else Color(0.20, 0.60, 1.0, 0.55)
	wall.material_override = m_context.build_preview_material(color)
	if has_joint:
		_show_wall_joint_hover(wall, joint_position)


func _clear_wall_hover() -> void:
	_clear_wall_joint_hover()
	if m_drag_wall_hover == null:
		return
	if is_instance_valid(m_drag_wall_hover):
		m_drag_wall_hover.material_override = m_drag_wall_hover_material
	m_drag_wall_hover = null
	m_drag_wall_hover_material = null
	m_drag_wall_hover_segment = 0
	m_drag_wall_hover_endpoint = -1
	m_drag_wall_hover_has_joint = false
	m_drag_wall_hover_joint_position = Vector3.ZERO


func _show_wall_joint_hover(wall: Wall3DScript, joint_position: Vector3) -> void:
	_clear_wall_joint_hover()
	if wall == null or !is_instance_valid(wall):
		return
	var marker := MeshInstance3D.new()
	marker.name = "WallJointHover"
	marker.set_meta(Wall3DScript.GENERATED_META, true)
	var mesh := SphereMesh.new()
	var radius := maxf(wall.wall_thickness * 0.85, 0.16)
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	marker.mesh = mesh
	marker.material_override = _build_joint_hover_material()
	wall.add_child(marker)
	marker.owner = null
	var display_position := joint_position
	display_position.y += _wall_joint_hover_height(wall, joint_position)
	marker.position = _wall_parent_local_to_wall_local(wall, display_position)
	m_drag_wall_hover_joint_marker = marker


func _clear_wall_joint_hover() -> void:
	if m_drag_wall_hover_joint_marker != null and is_instance_valid(m_drag_wall_hover_joint_marker):
		m_drag_wall_hover_joint_marker.queue_free()
	m_drag_wall_hover_joint_marker = null


func _wall_joint_hover_height(wall: Wall3DScript, joint_position: Vector3) -> float:
	var tolerance := _wall_joint_tolerance(wall)
	var height := 0.0
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if (
			segment.start_point.distance_to(joint_position) <= tolerance
			or segment.end_point.distance_to(joint_position) <= tolerance
		):
			height = maxf(height, segment.height)
	if height <= 0.0:
		height = wall.wall_height
	return height * 0.55


func _wall_parent_local_to_wall_local(wall: Wall3DScript, parent_local_position: Vector3) -> Vector3:
	var wall_parent := wall.get_parent() as Node3D
	if wall_parent == null:
		return wall.to_local(parent_local_position)
	return wall.to_local(wall_parent.to_global(parent_local_position))


func _build_joint_hover_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.46, 0.05, 0.95)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.34, 0.02, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _start_wall_drag(
	wall: Wall3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	segment_index: int,
	endpoint: int,
	alt_modifier: bool = false
) -> void:
	m_dragging_wall = wall
	var old_geometry := _wall_geometry_snapshot(wall)
	if old_geometry.is_empty():
		m_dragging_wall = null
		return
	m_drag_wall_old_start = Vector3(old_geometry["start"])
	m_drag_wall_old_end = Vector3(old_geometry["end"])
	m_drag_wall_old_segments = old_geometry["segments"]
	m_drag_wall_opening_anchors = wall.capture_opening_segment_anchors()
	m_drag_wall_segment_index = clampi(segment_index, 0, wall.get_segment_count() - 1)
	m_drag_wall_endpoint = endpoint
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	var is_room := wall.is_rectangular_loop(_wall_joint_tolerance(wall))
	# Alt/Option-dragging a room body moves the whole room instead of resizing one side.
	m_drag_wall_resizing_room_side = (
		endpoint < 0
		and !alt_modifier
		and is_room
	)
	if endpoint >= 0:
		m_drag_wall_joint_origin = _drag_wall_endpoint_position(wall, m_drag_wall_segment_index, endpoint)
		var is_shared_joint := wall.count_connected_endpoints(
			m_drag_wall_joint_origin,
			_wall_joint_tolerance(wall)
		) >= 2
		m_drag_wall_dragging_joint = is_shared_joint and !alt_modifier
		m_drag_wall_detaching_joint = is_shared_joint and alt_modifier
	m_drag_wall_active_material = wall.material_override
	var coordinator := m_context.find_coordinator_from_node(wall)
	var hit := m_context.raycast_world(camera, mouse_pos, false)
	m_drag_wall_anchor_local = (
		coordinator.to_local(Vector3(hit["position"])) if coordinator != null
		else Vector3(hit["position"])
	)
	var color := (
		Color(1.0, 0.46, 0.05, 0.75) if m_drag_wall_dragging_joint
		else Color(1.0, 0.85, 0.20, 0.75) if endpoint >= 0
		else Color(0.20, 0.60, 1.0, 0.55)
	)
	wall.material_override = m_context.build_preview_material(color)
	var action := (
		"joint"
		if m_drag_wall_dragging_joint
		else "detached endpoint" if m_drag_wall_detaching_joint
		else "endpoint" if endpoint >= 0
		else "room wall" if m_drag_wall_resizing_room_side
		else "room" if is_room
		else "wall"
	)
	m_context.set_status("Dragging %s — release to commit, Escape to cancel." % action)


func _update_wall_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_wall == null or !is_instance_valid(m_dragging_wall):
		m_dragging_wall = null
		m_drag_wall_old_segments.clear()
		m_drag_wall_opening_anchors.clear()
		m_drag_wall_resizing_room_side = false
		return
	var coordinator := m_context.find_coordinator_from_node(m_dragging_wall)
	var hit := m_context.raycast_world(camera, mouse_pos, false)
	var hit_local: Vector3 = (
		coordinator.to_local(Vector3(hit["position"])) if coordinator != null
		else Vector3(hit["position"])
	)
	var step := _active_grid_step(m_dragging_wall)

	if m_drag_wall_endpoint >= 0:
		var snapped := Vector3(
			roundf(hit_local.x / step) * step,
			0.0,
			roundf(hit_local.z / step) * step
		)
		snapped = _snap_drag_wall_endpoint_to_connection(snapped)
		_apply_drag_wall_endpoint(snapped)
		var zero_span := _is_dragged_wall_span_zero_length(m_dragging_wall)
		var valid_span := _is_dragged_wall_span_long_enough(m_dragging_wall)
		var drag_color := Color(1.0, 0.46, 0.05, 0.75) if m_drag_wall_dragging_joint else Color(1.0, 0.85, 0.20, 0.75)
		if zero_span:
			drag_color = Color(1.0, 0.46, 0.05, 0.75)
		elif !valid_span:
			drag_color = Color(0.95, 0.20, 0.16, 0.72)
		elif m_drag_wall_has_connection_snap:
			drag_color = Color(0.20, 0.88, 0.36, 0.75)
		m_dragging_wall.material_override = m_context.build_preview_material(drag_color)
		if zero_span:
			m_context.set_status(
				"Release to delete segment."
				if m_dragging_wall.get_segment_count() > 1
				else "Release to delete wall."
			)
		else:
			var drag_target := "joint" if m_drag_wall_dragging_joint else "endpoint"
			if valid_span:
				if m_drag_wall_has_connection_snap:
					m_context.set_status("Release to connect endpoint.")
				elif m_drag_wall_detaching_joint:
					m_context.set_status("Release to disconnect endpoint.")
				else:
					m_context.set_status("Release to commit %s." % drag_target)
			else:
				m_context.set_status("Wall is too short.")
	else:
		var raw_delta := hit_local - m_drag_wall_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		if m_drag_wall_resizing_room_side:
			_resize_drag_room_side(snapped_delta)
			var room_valid := _are_dragged_wall_spans_long_enough(m_dragging_wall)
			m_dragging_wall.material_override = m_context.build_preview_material(
				Color(0.20, 0.60, 1.0, 0.55)
				if room_valid
				else Color(0.95, 0.20, 0.16, 0.72)
			)
			m_context.set_status("Release to resize room." if room_valid else "Room is too small.")
		else:
			_translate_drag_wall_geometry(snapped_delta)
			m_context.set_status("Release to commit.")


func _commit_wall_drag() -> void:
	if m_dragging_wall == null:
		return
	var wall := m_dragging_wall
	var new_geometry := _wall_geometry_snapshot(wall)
	if new_geometry.is_empty():
		_cancel_wall_drag()
		return
	var new_start := Vector3(new_geometry["start"])
	var new_end := Vector3(new_geometry["end"])
	var new_segments: Array[WallSegmentScript] = new_geometry["segments"]
	var old_start := m_drag_wall_old_start
	var old_end := m_drag_wall_old_end
	var old_segments := _duplicate_segments(m_drag_wall_old_segments)
	var was_joint_drag := m_drag_wall_dragging_joint
	var was_detaching_joint := m_drag_wall_detaching_joint
	var was_connection_snap := m_drag_wall_has_connection_snap
	var was_room_resize := m_drag_wall_resizing_room_side
	m_dragging_wall = null
	wall.material_override = m_drag_wall_active_material
	m_drag_wall_active_material = null
	if m_drag_wall_endpoint >= 0 and _is_dragged_wall_span_zero_length(wall):
		var deletion_geometry := _wall_geometry_without_segment(wall, m_drag_wall_segment_index)
		if deletion_geometry.is_empty():
			_commit_delete_zero_length_wall(wall, old_start, old_end, old_segments)
		else:
			_commit_delete_zero_length_wall_segment(wall, deletion_geometry, old_start, old_end, old_segments)
		m_drag_wall_old_segments.clear()
		m_drag_wall_opening_anchors.clear()
		m_drag_wall_segment_index = 0
		m_drag_wall_endpoint = -1
		m_drag_wall_joint_origin = Vector3.ZERO
		m_drag_wall_dragging_joint = false
		m_drag_wall_detaching_joint = false
		m_drag_wall_has_connection_snap = false
		m_drag_wall_resizing_room_side = false
		return
	var wall_geometry_valid := (
		_are_dragged_wall_spans_long_enough(wall)
		if was_room_resize
		else _is_dragged_wall_span_long_enough(wall)
	)
	if !wall_geometry_valid:
		_apply_wall_geometry(wall, old_start, old_end, old_segments, m_drag_wall_opening_anchors)
		m_drag_wall_old_segments.clear()
		m_drag_wall_opening_anchors.clear()
		m_drag_wall_segment_index = 0
		m_drag_wall_endpoint = -1
		m_drag_wall_joint_origin = Vector3.ZERO
		m_drag_wall_dragging_joint = false
		m_drag_wall_detaching_joint = false
		m_drag_wall_has_connection_snap = false
		m_drag_wall_resizing_room_side = false
		m_context.set_status("Room is too small." if was_room_resize else "Wall is too short.")
		return
	var coordinator := m_context.find_coordinator_from_node(wall)
	var intersects_after_move := false
	if coordinator != null:
		intersects_after_move = !_find_intersecting_targets_for_wall(coordinator, wall).is_empty()
	var normalized_geometry := _normalized_wall_geometry(wall)
	if !normalized_geometry.is_empty():
		new_start = Vector3(normalized_geometry["start"])
		new_end = Vector3(normalized_geometry["end"])
		new_segments = normalized_geometry["segments"]
	var undo_redo := m_context.undo_redo()
	var move_action_name := (
		"Move Room"
		if wall.is_rectangular_loop(_wall_joint_tolerance(wall))
		else "Move Wall"
	)
	undo_redo.create_action("Resize Room" if was_room_resize else move_action_name)
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		new_start,
		new_end,
		new_segments,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		old_start,
		old_end,
		old_segments,
		true,
		coordinator
	)
	undo_redo.commit_action()
	m_drag_wall_old_segments.clear()
	m_drag_wall_opening_anchors.clear()
	m_drag_wall_segment_index = 0
	m_drag_wall_endpoint = -1
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	m_drag_wall_resizing_room_side = false
	if was_room_resize:
		m_context.set_status("Resized room.")
	elif was_connection_snap:
		m_context.set_status("Connected wall endpoint.")
	elif was_detaching_joint:
		m_context.set_status("Disconnected wall endpoint.")
	elif was_joint_drag:
		m_context.set_status("Moved wall joint.")
	elif intersects_after_move:
		m_context.set_status("Moved wall and clipped intersections.")
	else:
		m_context.set_status("Moved wall.")


func _cancel_wall_drag() -> void:
	if m_dragging_wall == null:
		return
	var coordinator := m_context.find_coordinator_from_node(m_dragging_wall)
	if is_instance_valid(m_dragging_wall):
		_apply_wall_geometry(
			m_dragging_wall,
			m_drag_wall_old_start,
			m_drag_wall_old_end,
			m_drag_wall_old_segments,
			m_drag_wall_opening_anchors
		)
		m_dragging_wall.material_override = m_drag_wall_active_material
		if coordinator != null:
			coordinator.refresh_building_geometry_clips()
	m_dragging_wall = null
	m_drag_wall_old_segments.clear()
	m_drag_wall_opening_anchors.clear()
	m_drag_wall_segment_index = 0
	m_drag_wall_endpoint = -1
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	m_drag_wall_resizing_room_side = false
	m_drag_wall_active_material = null


func _is_wall_span_long_enough(local_start: Vector3, local_end: Vector3) -> bool:
	return local_start.distance_to(local_end) >= maxf(float(m_wall_settings["grid_step"]) * 0.5, 0.1)


func _is_wall_draw_valid(local_start: Vector3, local_end: Vector3) -> bool:
	if !_is_room_wall_mode():
		return _is_wall_span_long_enough(local_start, local_end)
	var minimum_size := maxf(float(m_wall_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _wall_tool_type() -> String:
	return str(m_wall_settings.get("type", WALL_TYPE_WALL))


func _is_room_wall_mode() -> bool:
	return _wall_tool_type() == WALL_TYPE_ROOM


func _room_side_count() -> int:
	return maxi(int(m_wall_settings.get("room_sides", 4)), 3)


func _wall_draw_label() -> String:
	return "Room" if _is_room_wall_mode() else "Wall"

