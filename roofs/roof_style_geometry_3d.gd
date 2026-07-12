@tool
extends RefCounted

const RECT_EPSILON := 0.001
const MAX_ROOF_ANGLE_DEGREES := 89.0


func generated_height(
	_size: Vector2,
	_overhang: float,
	_parameters: Dictionary = {}
) -> float:
	return 0.0


func roof_run(_size: Vector2, _overhang: float) -> float:
	return 0.0


func surface_height(
	_size: Vector2,
	_overhang: float,
	_local_render_point: Vector2,
	_parameters: Dictionary = {}
) -> float:
	return 0.0


func top_triangles(
	full_size: Vector2,
	overhang: float,
	_parameters: Dictionary = {}
) -> Array[PackedVector3Array]:
	var bounds := _bounds(full_size, overhang)
	var p0 := Vector3(bounds.x, 0.0, bounds.z)
	var p1 := Vector3(bounds.y, 0.0, bounds.z)
	var p2 := Vector3(bounds.y, 0.0, bounds.w)
	var p3 := Vector3(bounds.x, 0.0, bounds.w)
	return [
		PackedVector3Array([p0, p3, p2]),
		PackedVector3Array([p0, p2, p1]),
	]


func top_faces(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[Dictionary]:
	var triangles := top_triangles(full_size, overhang, parameters)
	if triangles.size() < 2:
		return []
	var first := triangles[0]
	var second := triangles[1]
	return [{
		"vertices": PackedVector3Array([first[0], first[1], first[2], second[2]]),
		"plane": PackedVector3Array([first[0], first[1], first[2]]),
	}]


func topology(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Dictionary:
	var triangles := top_triangles(full_size, overhang, parameters)
	var points: Array[Vector3] = []
	var triangle_indices: Array[PackedInt32Array] = []
	for triangle in triangles:
		var indices := PackedInt32Array()
		for point in triangle:
			var point_index := _find_or_append_point(points, point)
			indices.append(point_index)
		triangle_indices.append(indices)
	var bounds := _bounds(full_size, overhang)
	var boundary := PackedInt32Array([
		_find_or_append_point(points, Vector3(bounds.x, 0.0, bounds.z)),
		_find_or_append_point(points, Vector3(bounds.y, 0.0, bounds.z)),
		_find_or_append_point(points, Vector3(bounds.y, 0.0, bounds.w)),
		_find_or_append_point(points, Vector3(bounds.x, 0.0, bounds.w)),
	])
	return {"points": points, "triangles": triangle_indices, "boundary": boundary}


func edge_axis_values(
	_full_size: Vector2,
	start_value: float,
	end_value: float,
	_axis_is_x: bool,
	_include_style_splits: bool
) -> Array[float]:
	var values: Array[float] = [start_value, end_value]
	values.sort()
	if start_value > end_value:
		values.reverse()
	return values


static func roof_height_for_angle(run: float, angle_degrees: float) -> float:
	return maxf(run, 0.0) * tan(deg_to_rad(clampf(angle_degrees, 0.0, MAX_ROOF_ANGLE_DEGREES)))


static func _angle_degrees(parameters: Dictionary) -> float:
	return float(parameters.get("angle_degrees", 0.0))


static func _bounds(size: Vector2, overhang: float) -> Vector4:
	var resolved_overhang := maxf(overhang, 0.0)
	return Vector4(
		-resolved_overhang,
		maxf(size.x, 0.0) + resolved_overhang,
		-resolved_overhang,
		maxf(size.y, 0.0) + resolved_overhang
	)


static func _find_or_append_point(points: Array[Vector3], point: Vector3) -> int:
	for index in range(points.size()):
		if points[index].distance_to(point) <= RECT_EPSILON:
			return index
	points.append(point)
	return points.size() - 1


static func _triangles_for_face(face_vertices: PackedVector3Array) -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	for index in range(1, face_vertices.size() - 1):
		triangles.append(PackedVector3Array([
			face_vertices[0],
			face_vertices[index],
			face_vertices[index + 1],
		]))
	return triangles


static func _plane_points(face_vertices: PackedVector3Array) -> PackedVector3Array:
	for first_index in range(face_vertices.size() - 2):
		for second_index in range(first_index + 1, face_vertices.size() - 1):
			for third_index in range(second_index + 1, face_vertices.size()):
				var first := face_vertices[first_index]
				var second := face_vertices[second_index]
				var third := face_vertices[third_index]
				if (second - first).cross(third - first).length_squared() > RECT_EPSILON * RECT_EPSILON:
					return PackedVector3Array([first, second, third])
	return PackedVector3Array()
