@tool
extends "res://addons/low_poly_building_editor/roofs/roof_style_geometry_3d.gd"


func generated_height(
	size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> float:
	return roof_height_for_angle(roof_run(size, overhang), _angle_degrees(parameters))


func roof_run(size: Vector2, overhang: float) -> float:
	return maxf(size.y, 0.0) * 0.5 + maxf(overhang, 0.0)


func surface_height(
	size: Vector2,
	overhang: float,
	local_render_point: Vector2,
	parameters: Dictionary = {}
) -> float:
	var bounds := _bounds(size, overhang)
	var height := generated_height(size, overhang, parameters)
	var z := clampf(local_render_point.y, bounds.z, bounds.w)
	var center_z := (bounds.z + bounds.w) * 0.5
	var half_depth := maxf((bounds.w - bounds.z) * 0.5, RECT_EPSILON)
	return height * clampf(1.0 - absf(z - center_z) / half_depth, 0.0, 1.0)


func top_triangles(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[PackedVector3Array]:
	var bounds := _bounds(full_size, overhang)
	var height := generated_height(full_size, overhang, parameters)
	var center_z := (bounds.z + bounds.w) * 0.5
	var p0 := Vector3(bounds.x, 0.0, bounds.z)
	var p1 := Vector3(bounds.y, 0.0, bounds.z)
	var p2 := Vector3(bounds.y, 0.0, bounds.w)
	var p3 := Vector3(bounds.x, 0.0, bounds.w)
	var ridge_left := Vector3(bounds.x, height, center_z)
	var ridge_right := Vector3(bounds.y, height, center_z)
	return [
		PackedVector3Array([p0, ridge_left, ridge_right]),
		PackedVector3Array([p0, ridge_right, p1]),
		PackedVector3Array([p3, p2, ridge_right]),
		PackedVector3Array([p3, ridge_right, ridge_left]),
	]


func top_faces(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[Dictionary]:
	var bounds := _bounds(full_size, overhang)
	var height := generated_height(full_size, overhang, parameters)
	var center_z := (bounds.z + bounds.w) * 0.5
	var p0 := Vector3(bounds.x, 0.0, bounds.z)
	var p1 := Vector3(bounds.y, 0.0, bounds.z)
	var p2 := Vector3(bounds.y, 0.0, bounds.w)
	var p3 := Vector3(bounds.x, 0.0, bounds.w)
	var ridge_left := Vector3(bounds.x, height, center_z)
	var ridge_right := Vector3(bounds.y, height, center_z)
	return [
		{
			"vertices": PackedVector3Array([p0, ridge_left, ridge_right, p1]),
			"plane": PackedVector3Array([p0, ridge_left, ridge_right]),
		},
		{
			"vertices": PackedVector3Array([p3, p2, ridge_right, ridge_left]),
			"plane": PackedVector3Array([p3, p2, ridge_right]),
		},
	]


func topology(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Dictionary:
	var bounds := _bounds(full_size, overhang)
	var height := generated_height(full_size, overhang, parameters)
	var center_z := (bounds.z + bounds.w) * 0.5
	var points: Array[Vector3] = [
		Vector3(bounds.x, 0.0, bounds.z),
		Vector3(bounds.y, 0.0, bounds.z),
		Vector3(bounds.y, 0.0, bounds.w),
		Vector3(bounds.x, 0.0, bounds.w),
		Vector3(bounds.x, height, center_z),
		Vector3(bounds.y, height, center_z),
	]
	var triangles: Array[PackedInt32Array] = [
		PackedInt32Array([0, 4, 5]),
		PackedInt32Array([0, 5, 1]),
		PackedInt32Array([3, 2, 5]),
		PackedInt32Array([3, 5, 4]),
	]
	return {
		"points": points,
		"triangles": triangles,
		"boundary": PackedInt32Array([0, 1, 5, 2, 3, 4]),
	}


func edge_axis_values(
	full_size: Vector2,
	start_value: float,
	end_value: float,
	axis_is_x: bool,
	include_style_splits: bool
) -> Array[float]:
	var values := super(full_size, start_value, end_value, axis_is_x, include_style_splits)
	if include_style_splits and !axis_is_x:
		var min_value := minf(start_value, end_value)
		var max_value := maxf(start_value, end_value)
		var center_z := full_size.y * 0.5
		if center_z > min_value + RECT_EPSILON and center_z < max_value - RECT_EPSILON:
			values.append(center_z)
			values.sort()
			if start_value > end_value:
				values.reverse()
	return values
