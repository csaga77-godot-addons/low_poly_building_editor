@tool
class_name WallSegment
extends Resource

signal geometry_changed

## One straight wall span stored inside a Wall3D node. Points are in
## the owning coordinator's parent-local space; the segment's render frame is
## derived from them the same way Wall3D derives its transform.


func _init() -> void:
	resource_local_to_scene = true


@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_emit_geometry_changed()

@export var end_point := Vector3(4.0, 0.0, 0.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_emit_geometry_changed()

@export_range(0.03, 1.0, 0.01, "or_greater") var thickness := 0.22:
	set(value):
		if is_equal_approx(thickness, value):
			return
		thickness = value
		_emit_geometry_changed()

@export_range(0.1, 6.0, 0.05, "or_greater") var height := 2.4:
	set(value):
		if is_equal_approx(height, value):
			return
		height = value
		_emit_geometry_changed()

@export var color := Color(0.78, 0.68, 0.54, 1.0):
	set(value):
		if color == value:
			return
		color = value
		emit_changed()


func _emit_geometry_changed() -> void:
	emit_changed()
	geometry_changed.emit()


func get_length() -> float:
	return Vector2(end_point.x - start_point.x, end_point.z - start_point.z).length()


static func shares_collinear_overlap(
	first: WallSegment,
	second: WallSegment,
	tolerance: float = 0.002
) -> bool:
	if first == null or second == null:
		return false
	if !is_equal_approx(first.thickness, second.thickness):
		return false
	var resolved_tolerance := maxf(tolerance, 0.001)
	if absf(first.start_point.y - second.start_point.y) > resolved_tolerance:
		return false
	var first_start := Vector2(first.start_point.x, first.start_point.z)
	var first_end := Vector2(first.end_point.x, first.end_point.z)
	var second_start := Vector2(second.start_point.x, second.start_point.z)
	var second_end := Vector2(second.end_point.x, second.end_point.z)
	var first_delta := first_end - first_start
	var second_delta := second_end - second_start
	var first_length := first_delta.length()
	var second_length := second_delta.length()
	if first_length <= resolved_tolerance or second_length <= resolved_tolerance:
		return false
	var first_axis := first_delta / first_length
	var second_axis := second_delta / second_length
	if absf(first_axis.dot(second_axis)) < 0.999:
		return false
	if absf((second_start - first_start).cross(first_axis)) > resolved_tolerance:
		return false
	var second_min := minf(
		(second_start - first_start).dot(first_axis),
		(second_end - first_start).dot(first_axis)
	)
	var second_max := maxf(
		(second_start - first_start).dot(first_axis),
		(second_end - first_start).dot(first_axis)
	)
	return minf(first_length, second_max) - maxf(0.0, second_min) > resolved_tolerance


## Collinear-merges `candidate` into an existing entry of `segments` when
## axis, line offset, thickness, height, and base match within tolerance and
## the ranges overlap; otherwise appends it. Returns true when extended.
static func merge_into(
	segments: Array[WallSegment],
	candidate: WallSegment,
	tolerance: float,
	merge_touching: bool = true
) -> bool:
	var candidate_axis := _flat_axis(candidate.start_point, candidate.end_point)
	if candidate_axis == Vector2.ZERO:
		return false
	var candidate_start := Vector2(candidate.start_point.x, candidate.start_point.z)
	var candidate_end := Vector2(candidate.end_point.x, candidate.end_point.z)
	for segment in segments:
		if !is_equal_approx(segment.thickness, candidate.thickness):
			continue
		if !is_equal_approx(segment.height, candidate.height):
			continue
		if absf(segment.start_point.y - candidate.start_point.y) > 0.01:
			continue
		var axis := _flat_axis(segment.start_point, segment.end_point)
		if axis == Vector2.ZERO:
			continue
		if absf(axis.dot(candidate_axis)) < 0.999:
			continue
		var origin := Vector2(segment.start_point.x, segment.start_point.z)
		if _line_distance(origin, axis, candidate_start) > tolerance:
			continue
		if _line_distance(origin, axis, candidate_end) > tolerance:
			continue
		var segment_length := segment.get_length()
		var start_projection := (candidate_start - origin).dot(axis)
		var end_projection := (candidate_end - origin).dot(axis)
		var projected_min := minf(start_projection, end_projection)
		var projected_max := maxf(start_projection, end_projection)
		var overlap_min := maxf(0.0, projected_min)
		var overlap_max := minf(segment_length, projected_max)
		if overlap_min > overlap_max + tolerance:
			continue
		if !merge_touching and overlap_max - overlap_min <= tolerance:
			continue
		var merged_min := minf(0.0, projected_min)
		var merged_max := maxf(segment_length, projected_max)
		var base_y := segment.start_point.y
		var merged_start := origin + axis * merged_min
		var merged_end := origin + axis * merged_max
		segment.start_point = Vector3(merged_start.x, base_y, merged_start.y)
		segment.end_point = Vector3(merged_end.x, base_y, merged_end.y)
		return true
	segments.append(candidate)
	return false


static func split_at_intersections(
	segments: Array[WallSegment],
	tolerance: float
) -> Array[WallSegment]:
	var cuts: Array = []
	for segment in segments:
		var segment_cuts := [0.0, segment.get_length()]
		cuts.append(segment_cuts)

	for first_index in range(segments.size()):
		var first := segments[first_index]
		var first_length := first.get_length()
		if first_length <= tolerance:
			continue
		for second_index in range(first_index + 1, segments.size()):
			var second := segments[second_index]
			var second_length := second.get_length()
			if second_length <= tolerance:
				continue
			if absf(first.start_point.y - second.start_point.y) > 0.01:
				continue
			var hit := _segment_intersection_2d(first, second, tolerance)
			if hit.is_empty():
				continue
			var hit_point := Vector2(hit["point"])
			var first_distance := _distance_along_segment(first, hit_point)
			var second_distance := _distance_along_segment(second, hit_point)
			_append_unique_cut(cuts[first_index], first_distance, first_length, tolerance)
			_append_unique_cut(cuts[second_index], second_distance, second_length, tolerance)

	var pieces: Array[WallSegment] = []
	for segment_index in range(segments.size()):
		var segment := segments[segment_index]
		var segment_length := segment.get_length()
		if segment_length <= tolerance:
			continue
		var segment_cuts: Array = cuts[segment_index]
		segment_cuts.sort()
		for cut_index in range(segment_cuts.size() - 1):
			var from_distance := float(segment_cuts[cut_index])
			var to_distance := float(segment_cuts[cut_index + 1])
			if to_distance - from_distance <= tolerance:
				continue
			var piece := segment.duplicate() as WallSegment
			piece.start_point = _point_along_segment(segment, from_distance)
			piece.end_point = _point_along_segment(segment, to_distance)
			pieces.append(piece)
	return pieces


static func _flat_axis(from_point: Vector3, to_point: Vector3) -> Vector2:
	var delta := Vector2(to_point.x - from_point.x, to_point.z - from_point.z)
	if delta.length_squared() <= 0.000001:
		return Vector2.ZERO
	return delta.normalized()


static func _line_distance(origin: Vector2, axis: Vector2, point: Vector2) -> float:
	var offset := point - origin
	return absf(offset.x * axis.y - offset.y * axis.x)


static func _segment_intersection_2d(
	first: WallSegment,
	second: WallSegment,
	tolerance: float
) -> Dictionary:
	var p := Vector2(first.start_point.x, first.start_point.z)
	var r := Vector2(first.end_point.x - first.start_point.x, first.end_point.z - first.start_point.z)
	var q := Vector2(second.start_point.x, second.start_point.z)
	var s := Vector2(second.end_point.x - second.start_point.x, second.end_point.z - second.start_point.z)
	var denominator := _cross_2d(r, s)
	if absf(denominator) <= 0.000001:
		return {}

	var offset := q - p
	var t := _cross_2d(offset, s) / denominator
	var u := _cross_2d(offset, r) / denominator
	var first_slop := tolerance / maxf(r.length(), tolerance)
	var second_slop := tolerance / maxf(s.length(), tolerance)
	if t < -first_slop or t > 1.0 + first_slop:
		return {}
	if u < -second_slop or u > 1.0 + second_slop:
		return {}

	return {
		"point": p + r * clampf(t, 0.0, 1.0),
	}


static func _append_unique_cut(
	cuts: Array,
	distance: float,
	segment_length: float,
	tolerance: float
) -> void:
	var clamped_distance := clampf(distance, 0.0, segment_length)
	for cut in cuts:
		if absf(cut - clamped_distance) <= tolerance:
			return
	cuts.append(clamped_distance)


static func _distance_along_segment(segment: WallSegment, point: Vector2) -> float:
	var axis := _flat_axis(segment.start_point, segment.end_point)
	if axis == Vector2.ZERO:
		return 0.0
	var origin := Vector2(segment.start_point.x, segment.start_point.z)
	return (point - origin).dot(axis)


static func _point_along_segment(segment: WallSegment, distance: float) -> Vector3:
	var axis := _flat_axis(segment.start_point, segment.end_point)
	var origin := Vector2(segment.start_point.x, segment.start_point.z)
	var point := origin + axis * distance
	return Vector3(point.x, segment.start_point.y, point.y)


static func _cross_2d(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


func get_frame() -> Transform3D:
	var flat_delta := Vector3(end_point.x - start_point.x, 0.0, end_point.z - start_point.z)
	var direction := Vector3.RIGHT
	if flat_delta.length_squared() > 0.000001:
		direction = flat_delta.normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	side = side.normalized()
	return Transform3D(Basis(direction, Vector3.UP, side).orthonormalized(), start_point)
