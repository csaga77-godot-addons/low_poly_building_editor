@tool
extends "res://addons/low_poly_building_editor/roofs/roof_style_geometry_3d.gd"


func generated_height(
	size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> float:
	return roof_height_for_angle(roof_run(size, overhang), _angle_degrees(parameters))


func roof_run(size: Vector2, overhang: float) -> float:
	var shortest_depth := minf(maxf(size.x, 0.0), maxf(size.y, 0.0))
	return shortest_depth * 0.5 + maxf(overhang, 0.0)


func surface_height(
	size: Vector2,
	overhang: float,
	local_render_point: Vector2,
	parameters: Dictionary = {}
) -> float:
	var angle_degrees := _angle_degrees(parameters)
	var gable_height_from_peak := float(
		parameters.get("gable_height_from_peak", 0.0)
	)
	var bounds := _bounds(size, overhang)
	var height := generated_height(size, overhang, parameters)
	var x := clampf(local_render_point.x, bounds.x, bounds.y)
	var z := clampf(local_render_point.y, bounds.z, bounds.w)
	var run := minf(bounds.y - bounds.x, bounds.w - bounds.z) * 0.5
	var slope := height / maxf(run, RECT_EPSILON)
	var ridge_extension := _gable_extension(run, height, angle_degrees, gable_height_from_peak)
	var cross_distance := 0.0
	var axis_height := height
	if (bounds.y - bounds.x) >= (bounds.w - bounds.z):
		var ridge_start_x := bounds.x + run - ridge_extension
		var ridge_end_x := bounds.y - run + ridge_extension
		cross_distance = minf(z - bounds.z, bounds.w - z)
		if x < ridge_start_x - RECT_EPSILON:
			axis_height = minf(axis_height, (x - bounds.x) * slope)
		elif x > ridge_end_x + RECT_EPSILON:
			axis_height = minf(axis_height, (bounds.y - x) * slope)
	else:
		var ridge_start_z := bounds.z + run - ridge_extension
		var ridge_end_z := bounds.w - run + ridge_extension
		cross_distance = minf(x - bounds.x, bounds.y - x)
		if z < ridge_start_z - RECT_EPSILON:
			axis_height = minf(axis_height, (z - bounds.z) * slope)
		elif z > ridge_end_z + RECT_EPSILON:
			axis_height = minf(axis_height, (bounds.w - z) * slope)
	return clampf(minf(cross_distance * slope, axis_height), 0.0, height)


func ridge_points(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> PackedVector3Array:
	var bounds := _bounds(size, overhang)
	var render_width := bounds.y - bounds.x
	var render_depth := bounds.w - bounds.z
	var run := minf(render_width, render_depth) * 0.5
	var height := roof_height_for_angle(run, angle_degrees)
	var extension := _gable_extension(run, height, angle_degrees, gable_height_from_peak)
	if render_width >= render_depth:
		var center_z := (bounds.z + bounds.w) * 0.5
		return PackedVector3Array([
			Vector3(bounds.x + run - extension, height, center_z),
			Vector3(bounds.y - run + extension, height, center_z),
		])
	var center_x := (bounds.x + bounds.y) * 0.5
	return PackedVector3Array([
		Vector3(center_x, height, bounds.z + run - extension),
		Vector3(center_x, height, bounds.w - run + extension),
	])


func face_polygons(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> Array[PackedVector3Array]:
	var bounds := _bounds(size, overhang)
	var render_width := bounds.y - bounds.x
	var render_depth := bounds.w - bounds.z
	var run := minf(render_width, render_depth) * 0.5
	var height := roof_height_for_angle(run, angle_degrees)
	var gable_drop := clampf(maxf(gable_height_from_peak, 0.0), 0.0, height)
	var extension := _gable_extension(run, height, angle_degrees, gable_drop)
	var p0 := Vector3(bounds.x, 0.0, bounds.z)
	var p1 := Vector3(bounds.y, 0.0, bounds.z)
	var p2 := Vector3(bounds.y, 0.0, bounds.w)
	var p3 := Vector3(bounds.x, 0.0, bounds.w)
	var ridge := ridge_points(size, overhang, angle_degrees, gable_drop)
	var ridge_start := ridge[0]
	var ridge_end := ridge[1]
	var faces: Array[PackedVector3Array] = []
	if gable_drop <= RECT_EPSILON and ridge_start.distance_to(ridge_end) <= RECT_EPSILON:
		faces.append(PackedVector3Array([p0, ridge_start, p1]))
		faces.append(PackedVector3Array([p1, ridge_start, p2]))
		faces.append(PackedVector3Array([p2, ridge_start, p3]))
		faces.append(PackedVector3Array([p3, ridge_start, p0]))
		return faces
	if gable_drop > RECT_EPSILON and extension > RECT_EPSILON:
		var base_height := height - gable_drop
		if render_width >= render_depth:
			var center_z := (bounds.z + bounds.w) * 0.5
			var left_front := Vector3(ridge_start.x, base_height, center_z - extension)
			var left_back := Vector3(ridge_start.x, base_height, center_z + extension)
			var right_front := Vector3(ridge_end.x, base_height, center_z - extension)
			var right_back := Vector3(ridge_end.x, base_height, center_z + extension)
			faces.append(PackedVector3Array([left_front, ridge_start, ridge_end, right_front, p1, p0]))
			faces.append(PackedVector3Array([p1, right_front, right_back, p2]))
			faces.append(PackedVector3Array([right_back, ridge_end, ridge_start, left_back, p3, p2]))
			faces.append(PackedVector3Array([p0, p3, left_back, left_front]))
			faces.append(PackedVector3Array([left_front, left_back, ridge_start]))
			faces.append(PackedVector3Array([right_front, ridge_end, right_back]))
		else:
			var center_x := (bounds.x + bounds.y) * 0.5
			var front_left := Vector3(center_x - extension, base_height, ridge_start.z)
			var front_right := Vector3(center_x + extension, base_height, ridge_start.z)
			var back_left := Vector3(center_x - extension, base_height, ridge_end.z)
			var back_right := Vector3(center_x + extension, base_height, ridge_end.z)
			faces.append(PackedVector3Array([p0, front_left, front_right, p1]))
			faces.append(PackedVector3Array([front_right, ridge_start, ridge_end, back_right, p2, p1]))
			faces.append(PackedVector3Array([p2, back_right, back_left, p3]))
			faces.append(PackedVector3Array([back_left, ridge_end, ridge_start, front_left, p0, p3]))
			faces.append(PackedVector3Array([front_left, ridge_start, front_right]))
			faces.append(PackedVector3Array([back_left, back_right, ridge_end]))
		return faces
	if render_width >= render_depth:
		faces.append(PackedVector3Array([p0, ridge_start, ridge_end, p1]))
		faces.append(PackedVector3Array([p1, ridge_end, p2]))
		faces.append(PackedVector3Array([p3, p2, ridge_end, ridge_start]))
		faces.append(PackedVector3Array([p0, p3, ridge_start]))
	else:
		faces.append(PackedVector3Array([p0, ridge_start, p1]))
		faces.append(PackedVector3Array([p1, ridge_start, ridge_end, p2]))
		faces.append(PackedVector3Array([p2, ridge_end, p3]))
		faces.append(PackedVector3Array([p0, p3, ridge_end, ridge_start]))
	return faces


func top_triangles(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[PackedVector3Array]:
	var angle_degrees := _angle_degrees(parameters)
	var gable_height_from_peak := float(
		parameters.get("gable_height_from_peak", 0.0)
	)
	var triangles: Array[PackedVector3Array] = []
	for face in face_polygons(full_size, overhang, angle_degrees, gable_height_from_peak):
		triangles.append_array(_triangles_for_face(face))
	return triangles


func top_faces(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[Dictionary]:
	var angle_degrees := _angle_degrees(parameters)
	var gable_height_from_peak := float(
		parameters.get("gable_height_from_peak", 0.0)
	)
	var faces: Array[Dictionary] = []
	for vertices in face_polygons(full_size, overhang, angle_degrees, gable_height_from_peak):
		var plane := _plane_points(vertices)
		if plane.size() == 3:
			faces.append({"vertices": vertices, "plane": plane})
	return faces


static func _gable_extension(
	run: float,
	height: float,
	angle_degrees: float,
	gable_height_from_peak: float
) -> float:
	var drop := clampf(maxf(gable_height_from_peak, 0.0), 0.0, maxf(height, 0.0))
	if drop <= RECT_EPSILON:
		return 0.0
	var slope := tan(deg_to_rad(clampf(angle_degrees, 0.0, MAX_ROOF_ANGLE_DEGREES)))
	if slope <= RECT_EPSILON:
		return 0.0
	return minf(drop / slope, maxf(run, 0.0))
