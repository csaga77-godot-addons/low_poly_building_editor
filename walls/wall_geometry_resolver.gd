@tool
class_name WallGeometryResolver
extends RefCounted

const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const WallSegmentScript = preload("res://addons/low_poly_building_editor/walls/wall_segment.gd")
const MergedWallMeshBuilderScript = preload("res://addons/low_poly_building_editor/walls/merged_wall_mesh_builder.gd")
const RoofGeometryResolverScript = preload("res://addons/low_poly_building_editor/roofs/roof_geometry_resolver.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")

const INTERSECT_BASE_TOLERANCE := 0.01

var m_owner: Node
var m_walls: Array[Wall3D] = []
var m_grid_step := 0.5
var m_roof_resolver: RoofGeometryResolverScript


func _init(
	owner: Node,
	walls: Array[Wall3D],
	grid_step: float,
	roof_resolver: RoofGeometryResolverScript = null
) -> void:
	m_owner = owner
	m_walls = walls
	m_grid_step = grid_step
	m_roof_resolver = roof_resolver


func get_wall_nodes() -> Array[Wall3D]:
	return m_walls


## The roof resolver is created on first use so wall-only queries (merge
## detection, intersection checks, opening validation) never pay for a roof
## child scan they do not need.
func _get_roof_resolver() -> RoofGeometryResolverScript:
	if m_roof_resolver == null:
		var building := m_owner as Building3D
		var roofs: Array[Roof3DScript] = []
		if building != null:
			roofs = building.get_roof_nodes()
		m_roof_resolver = RoofGeometryResolverScript.new(roofs)
	return m_roof_resolver


func refresh_wall_intersection_clips() -> void:
	var walls := get_wall_nodes()
	for wall_index in range(walls.size()):
		var wall := walls[wall_index]
		if wall.has_meta(Wall3DScript.PREVIEW_META):
			wall.clear_intersection_clip_segments()
			continue
		var before_segments: Array[WallSegment] = []
		var after_segments: Array[WallSegment] = []
		var foreign_openings: Array = []
		for other_index in range(walls.size()):
			if other_index == wall_index:
				continue
			var other := walls[other_index]
			if other.has_meta(Wall3DScript.PREVIEW_META):
				continue
			var other_opening_rects := other.get_assigned_opening_rects()
			for segment_index in range(other.get_segment_count()):
				var segment := other.get_segment(segment_index)
				var is_collinear := _wall_has_collinear_overlap(wall, segment)
				if !_wall_clip_segment_relevant(wall, segment):
					continue
				if other_index < wall_index:
					before_segments.append(segment)
				else:
					after_segments.append(segment)
				# Cut a collinear sibling's openings into this wall regardless of
				# scene order. Mesh-wise only the scene-earlier owner renders the
				# shared span, but collision is generated on every collinear wall
				# (it is not sibling-clipped), so each must carry the opening or
				# its solid collision fills the doorway.
				if is_collinear:
					_collect_foreign_openings(
						wall, other, segment_index, other_opening_rects, foreign_openings
					)
		wall.set_geometry_clip_data(
			before_segments,
			after_segments,
			_get_roof_resolver().clip_surfaces_for_wall(wall),
			foreign_openings
		)


## Maps each opening authored on `neighbour`'s `neighbour_segment_index` span
## into `owner`'s collinear segment-local space and appends it to `out` as
## `{ "segment_index": int, "rect": Rect2 }`. Both walls share the coordinator's
## space, so segment frames are compared directly. Only the owner segment that
## is collinear-overlapping the neighbour segment receives the openings.
func _collect_foreign_openings(
	owner: Wall3DScript,
	neighbour: Wall3DScript,
	neighbour_segment_index: int,
	neighbour_opening_rects: Array,
	out: Array
) -> void:
	if neighbour_segment_index < 0 or neighbour_segment_index >= neighbour_opening_rects.size():
		return
	var neighbour_rects: Array = neighbour_opening_rects[neighbour_segment_index]
	if neighbour_rects.is_empty():
		return
	var neighbour_segment := neighbour.get_segment(neighbour_segment_index)
	if neighbour_segment == null:
		return
	var neighbour_frame := neighbour_segment.get_frame()
	var neighbour_axis := neighbour_frame.basis.x
	for owner_index in range(owner.get_segment_count()):
		var owner_segment := owner.get_segment(owner_index)
		if owner_segment == null:
			continue
		if !WallSegmentScript.shares_collinear_overlap(owner_segment, neighbour_segment):
			continue
		var owner_frame := owner_segment.get_frame()
		var owner_axis := owner_frame.basis.x
		var owner_length := owner_segment.get_length()
		var base_delta := neighbour_segment.start_point.y - owner_segment.start_point.y
		for rect_variant in neighbour_rects:
			var rect := rect_variant as Rect2
			var near_point := neighbour_frame.origin + neighbour_axis * rect.position.x
			var far_point := neighbour_frame.origin + neighbour_axis * rect.end.x
			var owner_x_near := (near_point - owner_frame.origin).dot(owner_axis)
			var owner_x_far := (far_point - owner_frame.origin).dot(owner_axis)
			var x_low := clampf(minf(owner_x_near, owner_x_far), 0.0, owner_length)
			var x_high := clampf(maxf(owner_x_near, owner_x_far), 0.0, owner_length)
			if x_high - x_low <= INTERSECT_BASE_TOLERANCE:
				continue
			var y_low := clampf(rect.position.y + base_delta, 0.0, owner_segment.height)
			var y_high := clampf(rect.end.y + base_delta, 0.0, owner_segment.height)
			if y_high - y_low <= INTERSECT_BASE_TOLERANCE:
				continue
			out.append({
				"segment_index": owner_index,
				"rect": Rect2(Vector2(x_low, y_low), Vector2(x_high - x_low, y_high - y_low)),
			})
		return


func find_merge_target(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float,
	height: float,
	ignored_wall: Node = null
) -> Dictionary:
	var new_axis := _flat_direction(local_start, local_end)
	if new_axis == Vector2.ZERO:
		return {}

	var tolerance := maxf(m_grid_step * 0.25, 0.03)
	var new_start_2d := Vector2(local_start.x, local_start.z)
	var new_end_2d := Vector2(local_end.x, local_end.z)
	for wall in get_wall_nodes():
		if wall == ignored_wall:
			continue
		var primary := wall.get_segment(0)
		if primary == null:
			continue
		if absf(primary.start_point.y - local_start.y) > INTERSECT_BASE_TOLERANCE:
			continue
		if !is_equal_approx(primary.thickness, thickness):
			continue
		if !is_equal_approx(primary.height, height):
			continue
		var existing_axis := _flat_direction(primary.start_point, primary.end_point)
		if existing_axis == Vector2.ZERO:
			continue
		if absf(existing_axis.dot(new_axis)) < 0.999:
			continue

		var origin := Vector2(primary.start_point.x, primary.start_point.z)
		var existing_length := Vector2(
			primary.end_point.x - primary.start_point.x,
			primary.end_point.z - primary.start_point.z
		).length()
		var new_start_distance := _line_distance(origin, existing_axis, new_start_2d)
		var new_end_distance := _line_distance(origin, existing_axis, new_end_2d)
		if maxf(new_start_distance, new_end_distance) > tolerance:
			continue

		var new_start_projection := (new_start_2d - origin).dot(existing_axis)
		var new_end_projection := (new_end_2d - origin).dot(existing_axis)
		var new_min := minf(new_start_projection, new_end_projection)
		var new_max := maxf(new_start_projection, new_end_projection)
		if maxf(0.0, new_min) > minf(existing_length, new_max) + tolerance:
			continue

		var merged_min := minf(0.0, new_min)
		var merged_max := maxf(existing_length, new_max)
		var merged_start_2d := origin + existing_axis * merged_min
		var merged_end_2d := origin + existing_axis * merged_max
		return {
			"wall": wall,
			"start": Vector3(merged_start_2d.x, primary.start_point.y, merged_start_2d.y),
			"end": Vector3(merged_end_2d.x, primary.start_point.y, merged_end_2d.y),
		}
	return {}


## Walls whose footprints (primary span or any extra segment) overlap the
## candidate span on the same base plane. Preview-tagged walls are skipped.
func find_intersecting_walls(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float,
	ignored_wall: Node = null
) -> Array[Wall3DScript]:
	var hits: Array[Wall3DScript] = []
	var candidate := MergedWallMeshBuilderScript.footprint_from_points(local_start, local_end, thickness)
	if candidate.is_empty():
		return hits
	for wall in get_wall_nodes():
		if wall == ignored_wall:
			continue
		if wall.has_meta(Wall3DScript.PREVIEW_META):
			continue
		for segment_index in range(wall.get_segment_count()):
			var segment := wall.get_segment(segment_index)
			if absf(segment.start_point.y - local_start.y) > INTERSECT_BASE_TOLERANCE:
				continue
			var footprint := MergedWallMeshBuilderScript.footprint_from_points(
				segment.start_point, segment.end_point, segment.thickness
			)
			if MergedWallMeshBuilderScript.footprints_overlap(candidate, footprint):
				hits.append(wall)
				break
	return hits


func can_place_wall_opening(
	wall: Wall3DScript,
	segment_index: int,
	center: Vector2,
	size: Vector2,
	clearance: float = 0.03,
	ignored_opening: Node = null,
	allow_base_edge: bool = false
) -> bool:
	if wall == null or wall.get_parent() != m_owner:
		return false
	if !wall.can_place_opening(
		center,
		size,
		clearance,
		ignored_opening,
		segment_index,
		allow_base_edge
	):
		return false
	var target := wall.get_segment(segment_index)
	if target == null:
		return false
	var candidate := Rect2(center - size * 0.5, size)
	var candidate_min_y := target.start_point.y + candidate.position.y
	var candidate_max_y := target.start_point.y + candidate.end.y
	var candidate_plan := MergedWallMeshBuilderScript.span_plan_rect(
		target.get_frame(),
		candidate.position.x,
		candidate.end.x,
		target.thickness * 0.5
	)
	var walls := get_wall_nodes()
	for other_wall_index in range(walls.size()):
		var other_wall := walls[other_wall_index]
		if other_wall == wall or other_wall.has_meta(Wall3DScript.PREVIEW_META):
			continue
		for other_index in range(other_wall.get_segment_count()):
			var other := other_wall.get_segment(other_index)
			if other == null:
				continue
			var other_min_y := other.start_point.y
			var other_max_y := other.start_point.y + other.height
			if candidate_max_y <= other_min_y + 0.001 or candidate_min_y >= other_max_y - 0.001:
				continue
			var other_plan := MergedWallMeshBuilderScript.footprint_from_points(
				other.start_point,
				other.end_point,
				other.thickness
			)
			if MergedWallMeshBuilderScript.footprints_overlap(candidate_plan, other_plan):
				# Matching collinear overlap on either wall is fine: the wall that
				# renders the shared span cuts the opening (its own or one
				# propagated from the clipped sibling). Other overlaps still block.
				if WallSegmentScript.shares_collinear_overlap(target, other):
					continue
				return false
	return true


func _wall_clip_segment_relevant(wall: Wall3DScript, clip_segment: WallSegment) -> bool:
	if wall == null or clip_segment == null:
		return false
	for own_index in range(wall.get_segment_count()):
		var own_segment := wall.get_segment(own_index)
		if own_segment == null:
			continue
		if absf(own_segment.start_point.y - clip_segment.start_point.y) <= INTERSECT_BASE_TOLERANCE:
			return true
	return false


func _wall_has_collinear_overlap(wall: Wall3DScript, candidate: WallSegment) -> bool:
	if wall == null or candidate == null:
		return false
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if WallSegmentScript.shares_collinear_overlap(segment, candidate):
			return true
	return false


func _flat_direction(local_start: Vector3, local_end: Vector3) -> Vector2:
	var delta := Vector2(local_end.x - local_start.x, local_end.z - local_start.z)
	if delta.length_squared() <= 0.000001:
		return Vector2.ZERO
	return delta.normalized()


func _line_distance(origin: Vector2, axis: Vector2, point: Vector2) -> float:
	var offset := point - origin
	return absf(offset.x * axis.y - offset.y * axis.x)
