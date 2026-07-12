@tool
extends RefCounted

const POLYGON_EPSILON := 0.000001
const DEFAULT_MITER_LIMIT := 4.0


static func append_prism(
	polygon: PackedVector2Array,
	thickness: float,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var normalized := counter_clockwise_polygon(polygon)
	var triangle_indices := Geometry2D.triangulate_polygon(normalized)
	var bottom_offset := Vector3.DOWN * maxf(thickness, 0.0)
	for triangle_start in range(0, triangle_indices.size(), 3):
		var a_2d := normalized[triangle_indices[triangle_start]]
		var b_2d := normalized[triangle_indices[triangle_start + 1]]
		var c_2d := normalized[triangle_indices[triangle_start + 2]]
		var top_a := Vector3(a_2d.x, 0.0, a_2d.y)
		var top_b := Vector3(b_2d.x, 0.0, b_2d.y)
		var top_c := Vector3(c_2d.x, 0.0, c_2d.y)
		_append_triangle(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			top_a,
			top_b,
			top_c,
			Vector3.UP,
			color
		)
		_append_triangle(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			top_a + bottom_offset,
			top_c + bottom_offset,
			top_b + bottom_offset,
			Vector3.DOWN,
			color
		)

	for point_index in range(normalized.size()):
		var next_index := (point_index + 1) % normalized.size()
		var a_2d := normalized[point_index]
		var b_2d := normalized[next_index]
		var edge := b_2d - a_2d
		if edge.length_squared() <= POLYGON_EPSILON:
			continue
		var outward := Vector3(edge.y, 0.0, -edge.x).normalized()
		var top_a := Vector3(a_2d.x, 0.0, a_2d.y)
		var top_b := Vector3(b_2d.x, 0.0, b_2d.y)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			top_a,
			top_b,
			top_b + bottom_offset,
			top_a + bottom_offset,
			outward,
			color
		)


static func offset_polygon_preserving_vertices(
	polygon: PackedVector2Array,
	distance: float,
	miter_limit: float = DEFAULT_MITER_LIMIT
) -> PackedVector2Array:
	var normalized := counter_clockwise_polygon(polygon)
	if normalized.size() < 3 or distance <= POLYGON_EPSILON:
		return normalized
	var offset := _offset_polygon_once(normalized, distance, miter_limit)
	if !Geometry2D.triangulate_polygon(offset).is_empty():
		return offset
	var minimum_distance := 0.0
	var maximum_distance := distance
	var best := normalized
	for _iteration in range(12):
		var candidate_distance := (minimum_distance + maximum_distance) * 0.5
		var candidate := _offset_polygon_once(
			normalized,
			candidate_distance,
			miter_limit
		)
		if Geometry2D.triangulate_polygon(candidate).is_empty():
			maximum_distance = candidate_distance
		else:
			minimum_distance = candidate_distance
			best = candidate
	return best


static func _offset_polygon_once(
	polygon: PackedVector2Array,
	distance: float,
	miter_limit: float
) -> PackedVector2Array:
	var offset := PackedVector2Array()
	var maximum_miter := maxf(absf(distance) * maxf(miter_limit, 1.0), absf(distance))
	for point_index in range(polygon.size()):
		var previous := polygon[(point_index - 1 + polygon.size()) % polygon.size()]
		var current := polygon[point_index]
		var next := polygon[(point_index + 1) % polygon.size()]
		var previous_edge := current - previous
		var next_edge := next - current
		if (
			previous_edge.length_squared() <= POLYGON_EPSILON
			or next_edge.length_squared() <= POLYGON_EPSILON
		):
			offset.append(current)
			continue
		previous_edge = previous_edge.normalized()
		next_edge = next_edge.normalized()
		var previous_outward := Vector2(previous_edge.y, -previous_edge.x)
		var next_outward := Vector2(next_edge.y, -next_edge.x)
		var previous_line_point := current + previous_outward * distance
		var next_line_point := current + next_outward * distance
		var denominator := previous_edge.cross(next_edge)
		var offset_point := current + (previous_outward + next_outward).normalized() * distance
		if absf(denominator) > POLYGON_EPSILON:
			var line_ratio := (
				(next_line_point - previous_line_point).cross(next_edge)
				/ denominator
			)
			offset_point = previous_line_point + previous_edge * line_ratio
		var miter := offset_point - current
		if miter.length() > maximum_miter:
			offset_point = current + miter.normalized() * maximum_miter
		offset.append(offset_point)
	return offset


static func counter_clockwise_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var normalized := polygon.duplicate()
	if signed_polygon_area(normalized) < 0.0:
		normalized.reverse()
	return normalized


static func signed_polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for index in range(polygon.size()):
		var point := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += point.x * next.y - next.x * point.y
	return twice_area * 0.5


static func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c]))
	for _index in range(3):
		normals.append(normal)
		colors.append(color)
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	collision_faces.append_array(PackedVector3Array([a, b, c]))


static func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	for _index in range(4):
		normals.append(normal)
		colors.append(color)
	indices.append_array(PackedInt32Array([
		base,
		base + 2,
		base + 1,
		base,
		base + 3,
		base + 2,
	]))
	collision_faces.append_array(PackedVector3Array([
		a,
		c,
		b,
		a,
		d,
		c,
	]))
