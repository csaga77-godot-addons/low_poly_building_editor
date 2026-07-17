@tool
class_name StreetCurveSampler
extends RefCounted

const EPSILON := 0.00001
const MAX_RECURSION_DEPTH := 12


static func sample(
	segment: StreetSegmentData,
	start_position: Vector3,
	end_position: Vector3,
	maximum_chord_error := 0.08,
	maximum_tangent_angle_degrees := 8.0
) -> PackedVector3Array:
	if segment == null:
		return PackedVector3Array()
	if segment.terrain_profile.size() >= 2:
		return segment.terrain_profile.duplicate()
	match segment.curve_mode:
		StreetSegmentData.CurveMode.CUBIC_BEZIER:
			return _sample_cubic(
				segment, start_position, end_position,
				maxf(maximum_chord_error, 0.001),
				maxf(maximum_tangent_angle_degrees, 0.1)
			)
		StreetSegmentData.CurveMode.POLYLINE:
			return _sample_polyline(segment, start_position, end_position)
		_:
			return PackedVector3Array([start_position, end_position])


static func _sample_polyline(
	segment: StreetSegmentData,
	start_position: Vector3,
	end_position: Vector3
) -> PackedVector3Array:
	var points := segment.polyline_points.duplicate()
	if points.size() < 2:
		points = PackedVector3Array([start_position, end_position])
	else:
		points[0] = start_position
		points[points.size() - 1] = end_position
	if segment.vertical_mode != StreetSegmentData.VerticalMode.GRADED:
		return points
	var total := 0.0
	var stations := PackedFloat32Array([0.0])
	for index in range(points.size() - 1):
		total += _plan_distance(points[index], points[index + 1])
		stations.append(total)
	if total <= EPSILON:
		return points
	for index in range(points.size()):
		var ratio := float(stations[index]) / total
		points[index].y = lerpf(start_position.y, end_position.y, ratio)
	return points


static func _sample_cubic(
	segment: StreetSegmentData,
	start_position: Vector3,
	end_position: Vector3,
	maximum_chord_error: float,
	maximum_tangent_angle_degrees: float
) -> PackedVector3Array:
	var start_control := start_position + segment.start_handle
	var end_control := end_position + segment.end_handle
	if segment.start_handle.length_squared() <= EPSILON:
		start_control = start_position.lerp(end_position, 1.0 / 3.0)
	if segment.end_handle.length_squared() <= EPSILON:
		end_control = end_position.lerp(start_position, 1.0 / 3.0)
	var result := PackedVector3Array([start_position])
	_append_cubic_interval(
		start_position, start_control, end_control, end_position,
		0.0, 1.0, 0, maximum_chord_error,
		deg_to_rad(maximum_tangent_angle_degrees), segment.vertical_mode, result
	)
	result[result.size() - 1] = end_position
	return result


static func _append_cubic_interval(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	t0: float,
	t1: float,
	depth: int,
	maximum_chord_error: float,
	maximum_tangent_angle: float,
	vertical_mode: int,
	result: PackedVector3Array
) -> void:
	var midpoint_t := (t0 + t1) * 0.5
	var start := _graded_cubic_point(a, b, c, d, t0, vertical_mode)
	var finish := _graded_cubic_point(a, b, c, d, t1, vertical_mode)
	var midpoint := _graded_cubic_point(a, b, c, d, midpoint_t, vertical_mode)
	var chord_midpoint := start.lerp(finish, 0.5)
	var chord_error := _plan_distance(midpoint, chord_midpoint)
	var tangent_angle := _tangent_angle(a, b, c, d, t0, t1)
	if (
		depth >= MAX_RECURSION_DEPTH
		or (chord_error <= maximum_chord_error and tangent_angle <= maximum_tangent_angle)
	):
		result.append(finish)
		return
	_append_cubic_interval(
		a, b, c, d, t0, midpoint_t, depth + 1,
		maximum_chord_error, maximum_tangent_angle, vertical_mode, result
	)
	_append_cubic_interval(
		a, b, c, d, midpoint_t, t1, depth + 1,
		maximum_chord_error, maximum_tangent_angle, vertical_mode, result
	)


static func _graded_cubic_point(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float, vertical_mode: int
) -> Vector3:
	var inverse := 1.0 - t
	var point := (
		a * inverse * inverse * inverse
		+ b * 3.0 * inverse * inverse * t
		+ c * 3.0 * inverse * t * t
		+ d * t * t * t
	)
	if vertical_mode != StreetSegmentData.VerticalMode.MANUAL:
		point.y = lerpf(a.y, d.y, t)
	return point


static func _tangent_angle(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, t0: float, t1: float
) -> float:
	var first := _cubic_plan_tangent(a, b, c, d, t0)
	var second := _cubic_plan_tangent(a, b, c, d, t1)
	if first.length_squared() <= EPSILON or second.length_squared() <= EPSILON:
		return 0.0
	return acos(clampf(first.normalized().dot(second.normalized()), -1.0, 1.0))


static func _cubic_plan_tangent(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float
) -> Vector2:
	var inverse := 1.0 - t
	var derivative := (
		(b - a) * 3.0 * inverse * inverse
		+ (c - b) * 6.0 * inverse * t
		+ (d - c) * 3.0 * t * t
	)
	return Vector2(derivative.x, derivative.z)


static func _plan_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
