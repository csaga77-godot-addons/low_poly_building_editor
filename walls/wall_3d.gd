@tool
class_name Wall3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

signal source_geometry_changed

const GENERATED_META := &"wall_generated"
const PREVIEW_META := &"building_editor_preview"
const OPENING_META := &"building_editor_opening"
const SEGMENT_INDEX_META := &"wall_segment_index"
const MESH_GEOMETRY_VERSION := 2
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/openings/building_opening_3d.gd")
const WallSegmentScript = preload("res://addons/low_poly_building_editor/walls/wall_segment.gd")
const MergedWallMeshBuilderScript = preload("res://addons/low_poly_building_editor/walls/merged_wall_mesh_builder.gd")

const SEGMENT_ASSIGN_MARGIN := 0.25
const SEGMENT_ASSIGN_DEPTH := 0.2
const EDITOR_REBUILD_DELAY_SECONDS := 0.12
const COLLISION_MIN_SPAN := 0.001
const ROOF_COLLISION_CLIP_INFINITY := 999999.0

var m_legacy_start_point := Vector3.ZERO
var m_legacy_end_point := Vector3(4.0, 0.0, 0.0)
var m_legacy_extra_segments: Array[WallSegment] = []
var m_syncing_legacy_defaults := false

## Canonical authored geometry. Segment zero supplies the node transform;
## an empty array is a valid wall with no generated mesh or collision.
@export var segments: Array[WallSegment] = []:
	set(value):
		_disconnect_segment_signals(segments)
		segments = value
		_connect_segment_signals(segments)
		_sync_legacy_defaults_from_primary()
		_request_rebuild()
		source_geometry_changed.emit()

## Hidden compatibility aliases for scenes authored before `segments` became
## canonical. New scenes serialize only the exported `segments` array.
var start_point := Vector3.ZERO:
	get:
		return (
			segments[0].start_point
			if !segments.is_empty() and segments[0] != null
			else m_legacy_start_point
		)
	set(value):
		m_legacy_start_point = value
		_ensure_legacy_primary_segment()
		segments[0].start_point = value
		_request_rebuild()

var end_point := Vector3(4.0, 0.0, 0.0):
	get:
		return (
			segments[0].end_point
			if !segments.is_empty() and segments[0] != null
			else m_legacy_end_point
		)
	set(value):
		m_legacy_end_point = value
		_ensure_legacy_primary_segment()
		segments[0].end_point = value
		_request_rebuild()

@export_range(0.1, 6.0, 0.05, "or_greater") var wall_height := 2.4:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if (
			is_equal_approx(wall_height, clamped_value)
			and (m_syncing_legacy_defaults or _segments_have_height(clamped_value))
		):
			return
		wall_height = clamped_value
		if !m_syncing_legacy_defaults:
			for segment in segments:
				if segment != null:
					segment.height = clamped_value
		_request_rebuild()

@export_range(0.03, 1.0, 0.01, "or_greater") var wall_thickness := 0.22:
	set(value):
		var clamped_value := maxf(value, 0.03)
		if (
			is_equal_approx(wall_thickness, clamped_value)
			and (m_syncing_legacy_defaults or _segments_have_thickness(clamped_value))
		):
			return
		wall_thickness = clamped_value
		if !m_syncing_legacy_defaults:
			for segment in segments:
				if segment != null:
					segment.thickness = clamped_value
		_request_rebuild()

@export var wall_color := Color(0.78, 0.68, 0.54, 1.0):
	set(value):
		if (
			wall_color == value
			and (m_syncing_legacy_defaults or _segments_have_color(value))
		):
			return
		wall_color = value
		if !m_syncing_legacy_defaults:
			for segment in segments:
				if segment != null:
					segment.color = value
		_request_rebuild()

var extra_segments: Array[WallSegment] = []:
	get:
		var extras: Array[WallSegment] = []
		for index in range(1, segments.size()):
			extras.append(segments[index])
		return extras
	set(value):
		m_legacy_extra_segments = value
		_ensure_legacy_primary_segment()
		var updated_segments: Array[WallSegment] = [segments[0]]
		for segment in value:
			updated_segments.append(segment)
		self.segments = updated_segments

@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

@export_range(0.0, 1.0, 0.01) var opening_padding := 0.02:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(opening_padding, clamped_value):
			return
		opening_padding = clamped_value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false
var m_visual_rebuild_pending := false
var m_editor_rebuild_revision := 0
var m_is_rebuilding := false
var m_intersection_clip_segments_before: Array[WallSegment] = []
var m_intersection_clip_segments_after: Array[WallSegment] = []
var m_roof_clip_surfaces: Array[Dictionary] = []
var m_clip_data_initialized := false
var m_current_clip_signature := 0
## Openings authored on collinear-overlapping sibling walls whose shared span
## this wall renders. Each entry is `{ "segment_index": int, "rect": Rect2 }`
## in this wall's own segment-local space, so the wall that owns the overlap
## cuts the neighbour's door/window even though the opening node lives on the
## clipped sibling. Transient rebuild data; never serialized.
var m_foreign_opening_rects: Array = []


func _ready() -> void:
	m_is_ready = true
	_connect_segment_signals(segments)
	for child in get_children():
		_connect_opening_signal(child)
	if !child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	if !child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.connect(_on_child_exiting_tree)
	if build_on_ready:
		_sync_transform_from_points()
		if _saved_mesh_matches_current_authored_geometry():
			_sync_wall_material()
			_rebuild_collision_from_cached_mesh()
		else:
			rebuild_wall_mesh()


func _exit_tree() -> void:
	m_editor_rebuild_revision += 1
	m_visual_rebuild_pending = false
	_disconnect_segment_signals(segments)
	for child in get_children():
		_disconnect_opening_signal(child)
	if child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.disconnect(_on_child_entered_tree)
	if child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.disconnect(_on_child_exiting_tree)


func _ensure_legacy_primary_segment() -> void:
	if !segments.is_empty() and segments[0] != null:
		return
	var primary := WallSegmentScript.new() as WallSegment
	primary.start_point = m_legacy_start_point
	primary.end_point = m_legacy_end_point
	primary.height = wall_height
	primary.thickness = wall_thickness
	primary.color = wall_color
	if segments.is_empty():
		var initial_segments: Array[WallSegment] = [primary]
		self.segments = initial_segments
	else:
		var updated_segments := segments.duplicate()
		updated_segments[0] = primary
		self.segments = updated_segments


func _sync_legacy_defaults_from_primary() -> void:
	if segments.is_empty() or segments[0] == null:
		return
	var primary := segments[0]
	m_legacy_start_point = primary.start_point
	m_legacy_end_point = primary.end_point
	m_syncing_legacy_defaults = true
	wall_height = primary.height
	wall_thickness = primary.thickness
	wall_color = primary.color
	m_syncing_legacy_defaults = false


func _segments_have_height(value: float) -> bool:
	for segment in segments:
		if segment != null and !is_equal_approx(segment.height, value):
			return false
	return true


func _segments_have_thickness(value: float) -> bool:
	for segment in segments:
		if segment != null and !is_equal_approx(segment.thickness, value):
			return false
	return true


func _segments_have_color(value: Color) -> bool:
	for segment in segments:
		if segment != null and segment.color != value:
			return false
	return true


func set_wall_endpoints(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _authored_mesh_source_signature()
	var opening_anchors := capture_opening_segment_anchors()
	_ensure_legacy_primary_segment()
	start_point = new_start
	end_point = new_end
	if _authored_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	restore_opening_segment_anchors(opening_anchors)
	rebuild_wall_mesh()


func get_wall_length() -> float:
	var primary := get_segment(0)
	return primary.get_length() if primary != null else 0.0


func get_wall_direction() -> Vector3:
	var primary := get_segment(0)
	if primary == null:
		return Vector3.RIGHT
	var flat_delta := Vector3(
		primary.end_point.x - primary.start_point.x,
		0.0,
		primary.end_point.z - primary.start_point.z
	)
	if flat_delta.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return flat_delta.normalized()


func get_segment_count() -> int:
	return segments.size()


func get_segment(index: int) -> WallSegmentScript:
	if index < 0 or index >= segments.size():
		return null
	return segments[index]


func is_rectangular_loop(tolerance: float = 0.001) -> bool:
	if get_segment_count() != 4:
		return false
	var resolved_tolerance := maxf(tolerance, 0.001)
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var base_y := get_segment(0).start_point.y
	for index in range(get_segment_count()):
		var segment := get_segment(index)
		if segment == null:
			return false
		if (
			absf(segment.start_point.y - base_y) > resolved_tolerance
			or absf(segment.end_point.y - base_y) > resolved_tolerance
		):
			return false
		min_x = minf(min_x, minf(segment.start_point.x, segment.end_point.x))
		max_x = maxf(max_x, maxf(segment.start_point.x, segment.end_point.x))
		min_z = minf(min_z, minf(segment.start_point.z, segment.end_point.z))
		max_z = maxf(max_z, maxf(segment.start_point.z, segment.end_point.z))
	if max_x - min_x <= resolved_tolerance or max_z - min_z <= resolved_tolerance:
		return false

	var corners: Array[Vector3] = [
		Vector3(min_x, base_y, min_z),
		Vector3(max_x, base_y, min_z),
		Vector3(max_x, base_y, max_z),
		Vector3(min_x, base_y, max_z),
	]
	for corner in corners:
		if count_connected_endpoints(corner, resolved_tolerance) != 2:
			return false
	for index in range(get_segment_count()):
		var segment := get_segment(index)
		var horizontal := (
			absf(segment.start_point.z - segment.end_point.z) <= resolved_tolerance
			and absf(absf(segment.end_point.x - segment.start_point.x) - (max_x - min_x))
			<= resolved_tolerance
			and (
				absf(segment.start_point.z - min_z) <= resolved_tolerance
				or absf(segment.start_point.z - max_z) <= resolved_tolerance
			)
		)
		var vertical := (
			absf(segment.start_point.x - segment.end_point.x) <= resolved_tolerance
			and absf(absf(segment.end_point.z - segment.start_point.z) - (max_z - min_z))
			<= resolved_tolerance
			and (
				absf(segment.start_point.x - min_x) <= resolved_tolerance
				or absf(segment.start_point.x - max_x) <= resolved_tolerance
			)
		)
		if !horizontal and !vertical:
			return false
	return true


func move_rectangular_loop_side(
	segment_index: int,
	offset: Vector3,
	tolerance: float = 0.001
) -> bool:
	if !is_rectangular_loop(tolerance):
		return false
	if segment_index < 0 or segment_index >= get_segment_count():
		return false
	var selected := get_segment(segment_index)
	var direction := Vector3(
		selected.end_point.x - selected.start_point.x,
		0.0,
		selected.end_point.z - selected.start_point.z
	)
	if direction.length_squared() <= 0.000001:
		return false
	direction = direction.normalized()
	var perpendicular := Vector3(-direction.z, 0.0, direction.x)
	var projected_offset := perpendicular * offset.dot(perpendicular)
	var selected_start := selected.start_point
	var selected_end := selected.end_point
	var opening_anchors := capture_opening_segment_anchors()
	for segment in segments:
		if segment == null:
			continue
		segment.start_point = _offset_room_corner(
			segment.start_point,
			selected_start,
			selected_end,
			projected_offset,
			tolerance
		)
		segment.end_point = _offset_room_corner(
			segment.end_point,
			selected_start,
			selected_end,
			projected_offset,
			tolerance
		)
	_sync_transform_from_points()
	restore_opening_segment_anchors(opening_anchors)
	rebuild_wall_mesh()
	return true


func set_intersection_clip_segments(before_segments: Array, after_segments: Array) -> void:
	set_geometry_clip_data(
		before_segments,
		after_segments,
		m_roof_clip_surfaces,
		m_foreign_opening_rects
	)


func set_geometry_clip_data(
	before_segments: Array,
	after_segments: Array,
	roof_surfaces: Array,
	foreign_openings: Array = []
) -> void:
	var next_clip_signature := _geometry_clip_data_signature(
		before_segments,
		after_segments,
		roof_surfaces,
		foreign_openings
	)
	var clip_data_changed := (
		!m_clip_data_initialized
		or next_clip_signature != m_current_clip_signature
	)
	var mesh_is_current := (
		mesh != null
		and m_generated_mesh_source_signature == _authored_mesh_source_signature()
		and m_generated_mesh_clip_signature == next_clip_signature
	)
	m_intersection_clip_segments_before = _duplicate_segment_resources(before_segments)
	m_intersection_clip_segments_after = _duplicate_segment_resources(after_segments)
	m_roof_clip_surfaces = _duplicate_roof_clip_surfaces(roof_surfaces)
	m_foreign_opening_rects = _duplicate_foreign_openings(foreign_openings)
	m_current_clip_signature = next_clip_signature
	m_clip_data_initialized = true
	if !mesh_is_current:
		rebuild_wall_mesh()
	elif clip_data_changed:
		_rebuild_collision_from_cached_mesh()


func clear_intersection_clip_segments() -> void:
	set_geometry_clip_data([], [], [], [])


func get_intersection_clip_segment_count() -> int:
	return m_intersection_clip_segments_before.size() + m_intersection_clip_segments_after.size()


func get_roof_clip_surface_count() -> int:
	return m_roof_clip_surfaces.size()


func count_connected_endpoints(endpoint: Vector3, tolerance: float) -> int:
	var count := 0
	for segment in segments:
		if segment == null:
			continue
		if _endpoint_matches(segment.start_point, endpoint, tolerance):
			count += 1
		if _endpoint_matches(segment.end_point, endpoint, tolerance):
			count += 1
	return count


func move_connected_endpoint(old_endpoint: Vector3, new_endpoint: Vector3, tolerance: float) -> int:
	var opening_anchors := capture_opening_segment_anchors()
	var moved_count := 0
	for segment in segments:
		if segment == null:
			continue
		if _endpoint_matches(segment.start_point, old_endpoint, tolerance):
			segment.start_point = _endpoint_with_preserved_height(segment.start_point, new_endpoint)
			moved_count += 1
		if _endpoint_matches(segment.end_point, old_endpoint, tolerance):
			segment.end_point = _endpoint_with_preserved_height(segment.end_point, new_endpoint)
			moved_count += 1
	if moved_count > 0:
		_sync_transform_from_points()
		restore_opening_segment_anchors(opening_anchors)
		rebuild_wall_mesh()
	return moved_count


func move_segment_endpoint(segment_index: int, endpoint: int, new_endpoint: Vector3) -> bool:
	if endpoint != 0 and endpoint != 1:
		return false
	if segment_index < 0 or segment_index >= segments.size():
		return false
	var opening_anchors := capture_opening_segment_anchors()
	var segment := segments[segment_index]
	if segment == null:
		return false
	if endpoint == 0:
		segment.start_point = _endpoint_with_preserved_height(segment.start_point, new_endpoint)
	else:
		segment.end_point = _endpoint_with_preserved_height(segment.end_point, new_endpoint)
	_sync_transform_from_points()
	restore_opening_segment_anchors(opening_anchors)
	rebuild_wall_mesh()
	return true


func set_wall_geometry(
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment],
	opening_anchors: Array = []
) -> void:
	var anchors := opening_anchors
	if anchors.is_empty():
		anchors = capture_opening_segment_anchors()
	var primary := _segment_for_updated_span(new_start, new_end)
	var all_segments: Array[WallSegment] = [primary]
	all_segments.append_array(segments)
	self.segments = all_segments
	_sync_transform_from_points()
	restore_opening_segment_anchors(anchors)
	rebuild_wall_mesh()


func set_wall_geometry_preserving_child_transforms(
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment]
) -> void:
	var child_transforms := _capture_direct_child_global_transforms()
	var primary := _segment_for_updated_span(new_start, new_end)
	var all_segments: Array[WallSegment] = [primary]
	all_segments.append_array(segments)
	self.segments = all_segments
	_sync_transform_from_points()
	_restore_direct_child_global_transforms(child_transforms)
	rebuild_wall_mesh()


func split_segment_geometry(
	segment_index: int,
	split_point: Vector3,
	minimum_piece_length: float = 0.001
) -> Dictionary:
	if segment_index < 0 or segment_index >= get_segment_count():
		return {}
	var source_segment := get_segment(segment_index)
	if source_segment == null:
		return {}
	var split_on_segment := _project_point_to_segment(source_segment, split_point)
	var first_length := _flat_distance(source_segment.start_point, split_on_segment)
	var second_length := _flat_distance(split_on_segment, source_segment.end_point)
	if first_length < minimum_piece_length or second_length < minimum_piece_length:
		return {}

	var split_segments: Array[WallSegment] = []
	for index in range(get_segment_count()):
		var segment := get_segment(index).duplicate() as WallSegmentScript
		if segment == null:
			continue
		if index != segment_index:
			split_segments.append(segment)
			continue
		var first := segment.duplicate() as WallSegmentScript
		first.end_point = split_on_segment
		var second := segment.duplicate() as WallSegmentScript
		second.start_point = split_on_segment
		split_segments.append(first)
		split_segments.append(second)
	return _geometry_from_segment_list(split_segments)


func split_segment_at_point(
	segment_index: int,
	split_point: Vector3,
	minimum_piece_length: float = 0.001
) -> bool:
	var geometry := split_segment_geometry(segment_index, split_point, minimum_piece_length)
	if geometry.is_empty():
		return false
	set_wall_geometry_preserving_child_transforms(
		Vector3(geometry["start"]),
		Vector3(geometry["end"]),
		geometry["segments"]
	)
	return true


func capture_opening_segment_anchors() -> Array:
	var anchors := []
	for child in get_children():
		if child.has_meta(GENERATED_META):
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var size := _opening_size_from_child(child)
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		var segment_index := get_opening_segment_index(child)
		var frame := get_segment_local_frame(segment_index)
		anchors.append({
			"node": child,
			"segment_index": segment_index,
			"local_position": frame.affine_inverse() * child_3d.position,
		})
	return anchors


func restore_opening_segment_anchors(opening_anchors: Array) -> void:
	if segments.is_empty():
		return
	for anchor in opening_anchors:
		var child := anchor.get("node") as Node
		if child == null or !is_instance_valid(child) or child.get_parent() != self:
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var segment_index := clampi(
			int(anchor.get("segment_index", 0)),
			0,
			maxi(get_segment_count() - 1, 0)
		)
		var local_position: Vector3 = anchor.get("local_position", Vector3.ZERO)
		local_position = _clamped_opening_local_position(child, segment_index, local_position)
		var frame := get_segment_local_frame(segment_index)
		child_3d.transform = Transform3D(frame.basis, frame * local_position)
		child.set_meta(SEGMENT_INDEX_META, segment_index)


## Frame of a segment expressed in this node's local space. Segment 0 is the
## identity because the node transform is derived from the primary span.
func get_segment_local_frame(index: int) -> Transform3D:
	if index < 0 or index >= segments.size():
		return Transform3D.IDENTITY
	if index == 0:
		return Transform3D.IDENTITY
	return transform.affine_inverse() * segments[index].get_frame()


func can_place_opening(
	center: Vector2,
	size: Vector2,
	clearance: float = 0.03,
	ignored_node: Node = null,
	segment_index: int = 0,
	allow_base_edge: bool = false
) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var segment := get_segment(segment_index)
	if segment == null:
		return false
	var segment_length := segment.get_length()
	var candidate := Rect2(center - size * 0.5, size)
	if candidate.position.x < clearance:
		return false
	if candidate.end.x > segment_length - clearance:
		return false
	if allow_base_edge:
		if candidate.position.y < -0.001:
			return false
	elif candidate.position.y < clearance:
		return false
	if candidate.end.y > segment.height - clearance:
		return false

	var frame := get_segment_local_frame(segment_index)
	var opening_plan := MergedWallMeshBuilderScript.span_plan_rect(
		frame, candidate.position.x, candidate.end.x, segment.thickness * 0.5
	)
	for other_index in range(get_segment_count()):
		if other_index == segment_index:
			continue
		var other := get_segment(other_index)
		if candidate.position.y >= other.height - 0.001:
			continue
		var other_frame := get_segment_local_frame(other_index)
		if MergedWallMeshBuilderScript.footprints_overlap(
			opening_plan,
			MergedWallMeshBuilderScript.segment_footprint(other, other_frame)
		):
			return false
	# Collinear overlaps on either side are allowed: the wall that renders the
	# shared span cuts the opening (its own, or one propagated from the clipped
	# sibling), so placement no longer depends on scene order. Non-collinear
	# crossings still block, since that solid mass would fill the hole.
	if _opening_overlaps_clip_segments(
		candidate.position.y,
		opening_plan,
		segment,
		m_intersection_clip_segments_before,
		true
	):
		return false
	if _opening_overlaps_clip_segments(
		candidate.position.y,
		opening_plan,
		segment,
		m_intersection_clip_segments_after,
		true
	):
		return false

	var rects_per_segment := _assigned_opening_rects(ignored_node)
	var rects: Array[Rect2] = rects_per_segment[clampi(segment_index, 0, rects_per_segment.size() - 1)]
	for opening in rects:
		if candidate.grow(clearance).intersects(opening):
			return false
	return true


func _opening_overlaps_clip_segments(
	opening_min_y: float,
	opening_plan: PackedVector2Array,
	target_segment: WallSegment,
	clip_segments: Array[WallSegment],
	allow_owned_collinear_overlap: bool
) -> bool:
	for clip_segment in clip_segments:
		if clip_segment == null:
			continue
		if (
			allow_owned_collinear_overlap
			and WallSegmentScript.shares_collinear_overlap(target_segment, clip_segment)
		):
			continue
		if opening_min_y >= clip_segment.height - 0.001:
			continue
		var clip_frame := transform.affine_inverse() * clip_segment.get_frame()
		if MergedWallMeshBuilderScript.footprints_overlap(
			opening_plan,
			MergedWallMeshBuilderScript.segment_footprint(clip_segment, clip_frame)
		):
			return true
	return false


func rebuild_wall_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_editor_rebuild_revision += 1
		m_rebuild_queued = false
		m_visual_rebuild_pending = false
	m_is_rebuilding = true
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()
	if segments.is_empty():
		mesh = null
		m_is_rebuilding = false
		return

	var compiled_segments: Array[WallSegment] = []
	var frames: Array[Transform3D] = []
	var opening_rects: Array = []
	var render_segment_indices: Array[int] = []
	for clip_segment in m_intersection_clip_segments_before:
		if clip_segment == null:
			continue
		compiled_segments.append(clip_segment)
		frames.append(transform.affine_inverse() * clip_segment.get_frame())
		var empty_rects: Array[Rect2] = []
		opening_rects.append(empty_rects)
	var own_segment_start_index := compiled_segments.size()
	var assigned_openings := _assigned_opening_rects(null, true)
	for index in range(get_segment_count()):
		compiled_segments.append(get_segment(index))
		frames.append(get_segment_local_frame(index))
		if index < assigned_openings.size():
			opening_rects.append(assigned_openings[index])
		else:
			var empty_own_rects: Array[Rect2] = []
			opening_rects.append(empty_own_rects)
		render_segment_indices.append(own_segment_start_index + index)
	for clip_segment in m_intersection_clip_segments_after:
		if clip_segment == null:
			continue
		compiled_segments.append(clip_segment)
		frames.append(transform.affine_inverse() * clip_segment.get_frame())
		var empty_after_rects: Array[Rect2] = []
		opening_rects.append(empty_after_rects)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	MergedWallMeshBuilderScript.append_segments(
		compiled_segments,
		frames,
		opening_rects,
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		render_segment_indices,
		m_roof_clip_surfaces
	)

	if vertices.is_empty():
		mesh = null
		m_is_rebuilding = false
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_wall_mesh_resource(arrays)
	_sync_wall_material()
	var source_signature := _authored_mesh_source_signature()
	var clip_signature := _geometry_clip_data_signature(
		m_intersection_clip_segments_before,
		m_intersection_clip_segments_after,
		m_roof_clip_surfaces,
		m_foreign_opening_rects
	)
	_record_generated_mesh_cache(
		source_signature,
		clip_signature,
		1 if !m_roof_clip_surfaces.is_empty() else 0
	)
	m_current_clip_signature = clip_signature

	if rebuild_collision and generate_collision:
		_add_collision_body(collision_faces)

	m_is_rebuilding = false


func _request_rebuild() -> void:
	if !m_is_ready:
		return
	if Engine.is_editor_hint():
		m_rebuild_queued = true
		m_editor_rebuild_revision += 1
		var revision := m_editor_rebuild_revision
		if !m_visual_rebuild_pending:
			m_visual_rebuild_pending = true
			call_deferred("_flush_editor_visual_rebuild")
		var timer := get_tree().create_timer(EDITOR_REBUILD_DELAY_SECONDS)
		timer.timeout.connect(_on_editor_rebuild_timeout.bind(revision))
		return
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_wall_mesh")


func _flush_editor_visual_rebuild() -> void:
	if !m_rebuild_queued or !m_visual_rebuild_pending:
		return
	m_visual_rebuild_pending = false
	rebuild_wall_mesh(false)


func _on_editor_rebuild_timeout(revision: int) -> void:
	if revision != m_editor_rebuild_revision or !m_rebuild_queued:
		return
	rebuild_wall_mesh()


func _update_wall_mesh_resource(arrays: Array) -> void:
	_replace_generated_mesh_surface(arrays)


func _sync_wall_material() -> void:
	var primary := get_segment(0)
	var material_color := primary.color if primary != null else wall_color
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_wall_material(material_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, material_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if material_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _endpoint_matches(first: Vector3, second: Vector3, tolerance: float) -> bool:
	return first.distance_to(second) <= maxf(tolerance, 0.0)


func _endpoint_with_preserved_height(endpoint: Vector3, target: Vector3) -> Vector3:
	return Vector3(target.x, endpoint.y, target.z)


func _segment_for_updated_span(new_start: Vector3, new_end: Vector3) -> WallSegment:
	for source in segments:
		if source == null:
			continue
		if !_point_on_segment_span(source, new_start) or !_point_on_segment_span(source, new_end):
			continue
		var preserved := source.duplicate() as WallSegment
		preserved.start_point = new_start
		preserved.end_point = new_end
		return preserved
	var primary := WallSegmentScript.new() as WallSegment
	primary.start_point = new_start
	primary.end_point = new_end
	primary.height = wall_height
	primary.thickness = wall_thickness
	primary.color = wall_color
	return primary


func _point_on_segment_span(segment: WallSegment, point: Vector3) -> bool:
	if absf(segment.start_point.y - point.y) > 0.01:
		return false
	var start := Vector2(segment.start_point.x, segment.start_point.z)
	var end := Vector2(segment.end_point.x, segment.end_point.z)
	var target := Vector2(point.x, point.z)
	var span := end - start
	var length_squared := span.length_squared()
	if length_squared <= 0.000001:
		return target.distance_to(start) <= 0.001
	var projection := (target - start).dot(span) / length_squared
	if projection < -0.001 or projection > 1.001:
		return false
	return target.distance_to(start + span * clampf(projection, 0.0, 1.0)) <= 0.001


func _offset_room_corner(
	point: Vector3,
	first_corner: Vector3,
	second_corner: Vector3,
	offset: Vector3,
	tolerance: float
) -> Vector3:
	if _endpoint_matches(point, first_corner, tolerance) or _endpoint_matches(point, second_corner, tolerance):
		return point + offset
	return point


func _flat_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(second.x - first.x, second.z - first.z).length()


func _project_point_to_segment(segment: WallSegmentScript, point: Vector3) -> Vector3:
	var length := segment.get_length()
	if length <= 0.000001:
		return segment.start_point
	var start_2d := Vector2(segment.start_point.x, segment.start_point.z)
	var end_2d := Vector2(segment.end_point.x, segment.end_point.z)
	var axis := (end_2d - start_2d).normalized()
	var point_2d := Vector2(point.x, point.z)
	var distance := clampf((point_2d - start_2d).dot(axis), 0.0, length)
	var projected := start_2d + axis * distance
	return Vector3(projected.x, segment.start_point.y, projected.y)


func _geometry_from_segment_list(segments: Array[WallSegment]) -> Dictionary:
	if segments.is_empty():
		return {}
	var primary := segments[0] as WallSegmentScript
	if primary == null:
		return {}
	var extras: Array[WallSegment] = []
	for index in range(1, segments.size()):
		var segment := segments[index] as WallSegmentScript
		if segment == null:
			continue
		extras.append(segment.duplicate() as WallSegmentScript)
	return {
		"start": primary.start_point,
		"end": primary.end_point,
		"segments": extras,
	}


func _duplicate_segment_resources(segments: Array) -> Array[WallSegment]:
	var copies: Array[WallSegment] = []
	for segment in segments:
		var typed_segment := segment as WallSegmentScript
		if typed_segment == null:
			continue
		copies.append(typed_segment.duplicate() as WallSegmentScript)
	return copies


func _saved_mesh_matches_current_authored_geometry() -> bool:
	if mesh == null:
		return false
	if m_generated_mesh_source_signature != _authored_mesh_source_signature():
		return false
	if get_parent() is Building3D:
		return true
	return m_generated_mesh_clip_signature == _geometry_clip_data_signature([], [], [], [])


func _authored_mesh_source_signature() -> int:
	var segment_payload := []
	for segment in segments:
		if segment == null:
			segment_payload.append(null)
			continue
		segment_payload.append([
			segment.start_point,
			segment.end_point,
			segment.height,
			segment.thickness,
			segment.color,
		])
	return hash([
		MESH_GEOMETRY_VERSION,
		segment_payload,
		_assigned_opening_rects(),
	])


func _geometry_clip_data_signature(
	before_segments: Array,
	after_segments: Array,
	roof_surfaces: Array,
	foreign_openings: Array
) -> int:
	var roof_payload := []
	for surface_variant in roof_surfaces:
		if !(surface_variant is Dictionary):
			continue
		var surface := surface_variant as Dictionary
		var visible_polygons := []
		for polygon_variant in surface.get("visible_polygons", []):
			visible_polygons.append(PackedVector2Array(polygon_variant))
		roof_payload.append([
			Vector3(surface.get("origin", Vector3.ZERO)),
			float(surface.get("origin_y", 0.0)),
			Basis(surface.get("basis", Basis.IDENTITY)),
			String(surface.get("style", "")),
			Vector2(surface.get("size", Vector2.ZERO)),
			float(surface.get("overhang", 0.0)),
			float(surface.get("angle_degrees", 0.0)),
			float(surface.get("hip_gable_height", 0.0)),
			float(surface.get("thickness", 0.0)),
			visible_polygons,
		])
	var foreign_payload := []
	for entry_variant in foreign_openings:
		if !(entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		foreign_payload.append([
			int(entry.get("segment_index", -1)),
			Rect2(entry.get("rect", Rect2())),
		])
	return hash([
		_segment_clip_signature_payload(before_segments),
		_segment_clip_signature_payload(after_segments),
		roof_payload,
		foreign_payload,
	])


func _segment_clip_signature_payload(source_segments: Array) -> Array:
	var payload := []
	for segment_variant in source_segments:
		var segment := segment_variant as WallSegmentScript
		if segment == null:
			continue
		payload.append([
			segment.start_point,
			segment.end_point,
			segment.height,
			segment.thickness,
			segment.color,
		])
	return payload


func _duplicate_foreign_openings(entries: Array) -> Array:
	var copies: Array = []
	for entry in entries:
		if !(entry is Dictionary):
			continue
		var segment_index := int((entry as Dictionary).get("segment_index", -1))
		var rect_variant: Variant = (entry as Dictionary).get("rect", null)
		if segment_index < 0 or !(rect_variant is Rect2):
			continue
		copies.append({
			"segment_index": segment_index,
			"rect": rect_variant as Rect2,
		})
	return copies


## Per-segment opening rects authored directly on this wall (no propagated
## sibling openings), in each segment's local space. Used by the coordinator to
## forward this wall's openings onto a collinear sibling that renders the
## shared span.
func get_assigned_opening_rects() -> Array:
	return _assigned_opening_rects()


## Per-segment opening rects actually cut into the rendered mesh for a segment,
## including openings propagated from collinear sibling walls.
func get_render_opening_rects(segment_index: int) -> Array[Rect2]:
	var per_segment := _assigned_opening_rects(null, true)
	if segment_index < 0 or segment_index >= per_segment.size():
		var empty: Array[Rect2] = []
		return empty
	var result: Array[Rect2] = per_segment[segment_index]
	return result


func _duplicate_roof_clip_surfaces(surfaces: Array) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for surface in surfaces:
		if !(surface is Dictionary):
			continue
		copies.append((surface as Dictionary).duplicate(true))
	return copies


func _all_intersection_clip_segments() -> Array[WallSegment]:
	var segments: Array[WallSegment] = []
	segments.append_array(m_intersection_clip_segments_before)
	segments.append_array(m_intersection_clip_segments_after)
	return segments


func _capture_direct_child_global_transforms() -> Array:
	var transforms := []
	for child in get_children():
		if child.has_meta(GENERATED_META):
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		transforms.append({
			"node": child_3d,
			"global_transform": child_3d.global_transform,
		})
	return transforms


func _restore_direct_child_global_transforms(child_transforms: Array) -> void:
	for entry in child_transforms:
		var child := entry.get("node") as Node3D
		if child == null or !is_instance_valid(child) or child.get_parent() != self:
			continue
		child.global_transform = entry.get("global_transform", child.global_transform)
		if _opening_size_from_child(child).x > 0.0:
			child.set_meta(SEGMENT_INDEX_META, get_opening_segment_index(child))


func _sync_transform_from_points() -> void:
	transform = _authored_transform()


func _authored_transform() -> Transform3D:
	var primary := get_segment(0)
	if primary == null:
		return Transform3D.IDENTITY
	var direction := get_wall_direction()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	side = side.normalized()
	var basis := Basis(direction, Vector3.UP, side).orthonormalized()
	return Transform3D(basis, primary.start_point)


func supports_native_transform() -> bool:
	return true


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	var vertical_scale := native_delta_scale(delta).y
	# Snap the primary span start onto the grid and shift every segment by the
	# same offset, so scaled span lengths and the wall shape are preserved.
	var primary := get_segment(0)
	var offset := Vector3.ZERO
	if primary != null:
		offset = grid_snap_offset(delta * primary.start_point, grid_step)
	for segment in segments:
		if segment == null:
			continue
		segment.start_point = delta * segment.start_point + offset
		segment.end_point = delta * segment.end_point + offset
		segment.height = maxf(segment.height * vertical_scale, 0.1)
	_sync_transform_from_points()
	rebuild_wall_mesh()


func capture_native_transform_state() -> Dictionary:
	var segment_states: Array = []
	for segment in segments:
		if segment == null:
			segment_states.append(null)
			continue
		segment_states.append({
			"start_point": segment.start_point,
			"end_point": segment.end_point,
			"height": segment.height,
		})
	return {"segments": segment_states}


func restore_native_transform_state(state: Dictionary) -> void:
	var segment_states: Array = state.get("segments", [])
	for index in range(mini(segment_states.size(), segments.size())):
		var segment_state = segment_states[index]
		if segment_state == null or segments[index] == null:
			continue
		segments[index].start_point = Vector3(segment_state["start_point"])
		segments[index].end_point = Vector3(segment_state["end_point"])
		segments[index].height = float(segment_state["height"])
	_sync_transform_from_points()
	rebuild_wall_mesh()


## One Array[Rect2] per segment, mapping each child opening to the nearest
## segment face. Rects are padded by opening_padding and clamped to the
## segment span, ready for mesh-cut consumption.
func _assigned_opening_rects(ignored_node: Node = null, include_foreign: bool = false) -> Array:
	var rects_per_segment: Array = []
	for index in range(get_segment_count()):
		var empty: Array[Rect2] = []
		rects_per_segment.append(empty)
	if rects_per_segment.is_empty():
		return rects_per_segment
	for child in get_children():
		if child == ignored_node:
			continue
		if child.has_meta(GENERATED_META):
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var size := _opening_size_from_child(child)
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		var segment_index := _segment_index_for_child(child, child_3d.position)
		var segment := get_segment(segment_index)
		var frame := get_segment_local_frame(segment_index)
		var local := frame.affine_inverse() * child_3d.position
		var padded := Rect2(
			Vector2(local.x, local.y) - size * 0.5 - Vector2(opening_padding, opening_padding),
			size + Vector2(opening_padding * 2.0, opening_padding * 2.0)
		)
		var segment_length := segment.get_length()
		var x0 := clampf(padded.position.x, 0.0, segment_length)
		var x1 := clampf(padded.end.x, 0.0, segment_length)
		var y0 := clampf(padded.position.y, 0.0, segment.height)
		var y1 := clampf(padded.end.y, 0.0, segment.height)
		if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
			continue
		var rects: Array[Rect2] = rects_per_segment[segment_index]
		rects.append(Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0)))
	if include_foreign:
		_append_foreign_opening_rects(rects_per_segment)
	return rects_per_segment


## Merge openings propagated from collinear sibling walls into the per-segment
## rects, clamped to each owning segment's span. Lets the wall that renders a
## shared collinear span cut a door/window authored on the clipped sibling.
func _append_foreign_opening_rects(rects_per_segment: Array) -> void:
	for entry in m_foreign_opening_rects:
		if !(entry is Dictionary):
			continue
		var segment_index := int((entry as Dictionary).get("segment_index", -1))
		if segment_index < 0 or segment_index >= rects_per_segment.size():
			continue
		var segment := get_segment(segment_index)
		if segment == null:
			continue
		var rect: Rect2 = (entry as Dictionary)["rect"]
		var segment_length := segment.get_length()
		var x0 := clampf(rect.position.x, 0.0, segment_length)
		var x1 := clampf(rect.end.x, 0.0, segment_length)
		var y0 := clampf(rect.position.y, 0.0, segment.height)
		var y1 := clampf(rect.end.y, 0.0, segment.height)
		if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
			continue
		var rects: Array[Rect2] = rects_per_segment[segment_index]
		rects.append(Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0)))


## Public lookup used by tools and tests: which segment does a child opening
## belong to? Prefers a valid pinned SEGMENT_INDEX_META, then the segment
## whose face shell the position sits closest to.
func get_opening_segment_index(child: Node) -> int:
	var child_3d := child as Node3D
	if child_3d == null:
		return 0
	return _segment_index_for_child(child, child_3d.position)


func _segment_index_for_child(child: Node, local_position: Vector3) -> int:
	var pinned := int(child.get_meta(SEGMENT_INDEX_META, -1))
	if pinned >= 0 and pinned < get_segment_count() and _segment_matches_position(local_position, pinned):
		return pinned
	return _best_segment_for_position(local_position)


func _best_segment_for_position(local_position: Vector3) -> int:
	var best_index := 0
	var best_score := INF
	for index in range(get_segment_count()):
		if !_segment_matches_position(local_position, index):
			continue
		var segment := get_segment(index)
		var frame := get_segment_local_frame(index)
		var local := frame.affine_inverse() * local_position
		# Distance to the face shell, not the centerline: an opening sitting
		# on this segment's face scores ~0 here but ~thickness/2 against a
		# crossing segment whose centerline it happens to touch.
		var score := absf(absf(local.z) - segment.thickness * 0.5)
		if score < best_score:
			best_score = score
			best_index = index
	return best_index


func _segment_matches_position(local_position: Vector3, index: int) -> bool:
	var segment := get_segment(index)
	if segment == null:
		return false
	var frame := get_segment_local_frame(index)
	var local := frame.affine_inverse() * local_position
	if local.x < -SEGMENT_ASSIGN_MARGIN or local.x > segment.get_length() + SEGMENT_ASSIGN_MARGIN:
		return false
	if local.y < -SEGMENT_ASSIGN_MARGIN or local.y > segment.height + SEGMENT_ASSIGN_MARGIN:
		return false
	return absf(local.z) <= segment.thickness * 0.5 + SEGMENT_ASSIGN_DEPTH


func _opening_size_from_child(child: Node) -> Vector2:
	if child is BuildingOpening3DScript:
		var typed_opening := child as BuildingOpening3DScript
		return Vector2(typed_opening.opening_width, typed_opening.opening_height)
	if child.has_meta(OPENING_META):
		var width := float(child.get_meta(&"opening_width", 1.0))
		var height := float(child.get_meta(&"opening_height", 1.0))
		return Vector2(maxf(width, 0.0), maxf(height, 0.0))
	return Vector2.ZERO


func _clamped_opening_local_position(
	child: Node,
	segment_index: int,
	local_position: Vector3
) -> Vector3:
	var segment := get_segment(segment_index)
	var size := _opening_size_from_child(child)
	if segment == null or size.x <= 0.0 or size.y <= 0.0:
		return local_position
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	if segment.get_length() > size.x:
		local_position.x = clampf(local_position.x, half_width, segment.get_length() - half_width)
	else:
		local_position.x = segment.get_length() * 0.5
	if segment.height > size.y:
		local_position.y = clampf(local_position.y, half_height, segment.height - half_height)
	else:
		local_position.y = segment.height * 0.5
	var face_sign := signf(local_position.z) if absf(local_position.z) > 0.001 else 1.0
	local_position.z = face_sign * maxf(absf(local_position.z), segment.thickness * 0.5)
	return local_position


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if !generate_collision or mesh == null:
		return
	_add_collision_body(
		_cached_mesh_triangle_faces(),
		_generated_mesh_cache_has_flag(1) or !m_roof_clip_surfaces.is_empty()
	)


func _add_collision_body(
	collision_faces: PackedVector3Array,
	use_roof_clipped_faces := false
) -> void:
	var body := StaticBody3D.new()
	body.name = "WallCollision"
	body.set_meta(GENERATED_META, true)
	var shape_count := 0
	if use_roof_clipped_faces or !m_roof_clip_surfaces.is_empty():
		shape_count = _add_roof_clipped_collision_shape(body, collision_faces)
	else:
		shape_count = _add_collision_shapes_for_wall_cells(body)
	if shape_count <= 0:
		body.free()
		return
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null


func _add_roof_clipped_collision_shape(
	body: StaticBody3D,
	collision_faces: PackedVector3Array
) -> int:
	if collision_faces.size() < 3:
		return 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	if Engine.is_editor_hint():
		collision_shape.owner = null
	return 1


func _add_collision_shapes_for_wall_cells(body: StaticBody3D) -> int:
	var assigned_openings := _assigned_opening_rects(null, true)
	var shape_count := 0
	for segment_index in range(get_segment_count()):
		var segment := get_segment(segment_index)
		if segment == null:
			continue
		var segment_length := segment.get_length()
		if (
			segment_length <= COLLISION_MIN_SPAN
			or segment.height <= COLLISION_MIN_SPAN
			or segment.thickness <= COLLISION_MIN_SPAN
		):
			continue
		var opening_rects: Array[Rect2] = []
		if segment_index < assigned_openings.size():
			opening_rects = assigned_openings[segment_index]
		var x_cuts := _collision_cut_values(opening_rects, segment_length, true)
		var y_cuts := _collision_cut_values(opening_rects, segment.height, false)
		var frame := get_segment_local_frame(segment_index)
		for x_index in range(x_cuts.size() - 1):
			var x0 := x_cuts[x_index]
			var x1 := x_cuts[x_index + 1]
			if x1 - x0 <= COLLISION_MIN_SPAN:
				continue
			for y_index in range(y_cuts.size() - 1):
				var y0 := y_cuts[y_index]
				var y1 := y_cuts[y_index + 1]
				if y1 - y0 <= COLLISION_MIN_SPAN:
					continue
				var center := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
				if _collision_point_inside_opening(center, opening_rects):
					continue
				y1 = _clip_collision_cell_top_to_roofs(frame, x0, x1, y0, y1, segment.thickness)
				if y1 - y0 <= COLLISION_MIN_SPAN:
					continue
				_add_collision_box_shape(
					body,
					frame,
					x0,
					x1,
					y0,
					y1,
					segment.thickness,
					shape_count
				)
				shape_count += 1
	return shape_count


func _clip_collision_cell_top_to_roofs(
	frame: Transform3D,
	x0: float,
	x1: float,
	y0: float,
	y1: float,
	thickness: float
) -> float:
	if m_roof_clip_surfaces.is_empty():
		return y1
	var half_thickness := thickness * 0.5
	var samples := [
		Vector2((x0 + x1) * 0.5, 0.0),
		Vector2(x0, -half_thickness),
		Vector2(x0, half_thickness),
		Vector2(x1, -half_thickness),
		Vector2(x1, half_thickness),
	]
	var clipped_top := y1
	for sample in samples:
		var local_point := frame * Vector3(sample.x, 0.0, sample.y)
		var plan_point := Vector2(local_point.x, local_point.z)
		var wall_local_clip_y := MergedWallMeshBuilderScript._roof_clip_height_at_plan_point(
			plan_point,
			m_roof_clip_surfaces
		)
		if wall_local_clip_y >= ROOF_COLLISION_CLIP_INFINITY:
			continue
		clipped_top = minf(clipped_top, wall_local_clip_y - frame.origin.y)
	return maxf(clipped_top, y0)


func _add_collision_box_shape(
	body: StaticBody3D,
	frame: Transform3D,
	x0: float,
	x1: float,
	y0: float,
	y1: float,
	thickness: float,
	shape_index: int
) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1 - x0, y1 - y0, thickness)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = (
		"CollisionShape3D" if shape_index == 0
		else "CollisionShape3D%d" % (shape_index + 1)
	)
	collision_shape.shape = shape
	collision_shape.transform = Transform3D(
		frame.basis,
		frame * Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0)
	)
	collision_shape.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	if Engine.is_editor_hint():
		collision_shape.owner = null


func _collision_cut_values(openings: Array[Rect2], max_value: float, horizontal: bool) -> Array[float]:
	var values: Array[float] = [0.0, max_value]
	for opening in openings:
		if horizontal:
			values.append(clampf(opening.position.x, 0.0, max_value))
			values.append(clampf(opening.end.x, 0.0, max_value))
		else:
			values.append(clampf(opening.position.y, 0.0, max_value))
			values.append(clampf(opening.end.y, 0.0, max_value))
	values.sort()
	var result: Array[float] = []
	for value in values:
		if result.is_empty() or absf(result[result.size() - 1] - value) > COLLISION_MIN_SPAN:
			result.append(value)
	return result


func _collision_point_inside_opening(point: Vector2, openings: Array[Rect2]) -> bool:
	for opening in openings:
		if opening.has_point(point):
			return true
	return false


func _build_wall_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()


func _connect_segment_signals(source_segments: Array[WallSegment]) -> void:
	for segment in source_segments:
		if segment == null:
			continue
		if !segment.changed.is_connected(_on_segment_resource_changed):
			segment.changed.connect(_on_segment_resource_changed)
		if !segment.geometry_changed.is_connected(_on_segment_geometry_changed):
			segment.geometry_changed.connect(_on_segment_geometry_changed)


func _disconnect_segment_signals(source_segments: Array[WallSegment]) -> void:
	for segment in source_segments:
		if segment == null:
			continue
		if segment.changed.is_connected(_on_segment_resource_changed):
			segment.changed.disconnect(_on_segment_resource_changed)
		if segment.geometry_changed.is_connected(_on_segment_geometry_changed):
			segment.geometry_changed.disconnect(_on_segment_geometry_changed)


func _connect_opening_signal(child: Node) -> void:
	var opening := child as BuildingOpening3DScript
	if opening == null:
		return
	if !opening.opening_geometry_changed.is_connected(_on_opening_geometry_changed):
		opening.opening_geometry_changed.connect(_on_opening_geometry_changed)


func _disconnect_opening_signal(child: Node) -> void:
	var opening := child as BuildingOpening3DScript
	if opening == null:
		return
	if opening.opening_geometry_changed.is_connected(_on_opening_geometry_changed):
		opening.opening_geometry_changed.disconnect(_on_opening_geometry_changed)


func _on_segment_resource_changed() -> void:
	_request_rebuild()


func _on_segment_geometry_changed() -> void:
	source_geometry_changed.emit()


func _on_opening_geometry_changed() -> void:
	_request_rebuild()
	source_geometry_changed.emit()


func _on_child_entered_tree(child: Node) -> void:
	if m_is_rebuilding:
		return
	if child == null or child.has_meta(GENERATED_META):
		return
	_connect_opening_signal(child)
	_request_rebuild()
	if child is BuildingOpening3DScript:
		source_geometry_changed.emit()


func _on_child_exiting_tree(child: Node) -> void:
	if m_is_rebuilding:
		return
	if child == null or child.has_meta(GENERATED_META):
		return
	_disconnect_opening_signal(child)
	_request_rebuild()
	if child is BuildingOpening3DScript:
		source_geometry_changed.emit()
