@tool
extends "res://addons/low_poly_building_editor/roofs/roof_style_geometry_3d.gd"

const ANGULAR_SEGMENTS := 16
const RING_COUNT := 5


func generated_height(
	size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> float:
	return roof_height_for_angle(roof_run(size, overhang), _angle_degrees(parameters))


func roof_run(size: Vector2, overhang: float) -> float:
	var bounds := _bounds(size, overhang)
	return minf(bounds.y - bounds.x, bounds.w - bounds.z) * 0.5


func surface_height(
	size: Vector2,
	overhang: float,
	local_render_point: Vector2,
	parameters: Dictionary = {}
) -> float:
	var dome_topology := topology(size, overhang, parameters)
	var points: Array[Vector3] = dome_topology["points"]
	var triangles: Array[PackedInt32Array] = dome_topology["triangles"]
	for triangle in triangles:
		var height := _triangle_height_at_point(
			points[triangle[0]],
			points[triangle[1]],
			points[triangle[2]],
			local_render_point
		)
		if height > -INF:
			return height
	return 0.0


func top_triangles(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[PackedVector3Array]:
	var dome_topology := topology(full_size, overhang, parameters)
	var points: Array[Vector3] = dome_topology["points"]
	var triangles: Array[PackedInt32Array] = dome_topology["triangles"]
	var result: Array[PackedVector3Array] = []
	for triangle in triangles:
		result.append(PackedVector3Array([
			points[triangle[0]],
			points[triangle[1]],
			points[triangle[2]],
		]))
	return result


func top_faces(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	for triangle in top_triangles(full_size, overhang, parameters):
		faces.append({
			"vertices": triangle,
			"plane": triangle,
		})
	return faces


func topology(
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Dictionary:
	var bounds := _bounds(full_size, overhang)
	var center_x := (bounds.x + bounds.y) * 0.5
	var center_z := (bounds.z + bounds.w) * 0.5
	var radius_x := maxf((bounds.y - bounds.x) * 0.5, RECT_EPSILON)
	var radius_z := maxf((bounds.w - bounds.z) * 0.5, RECT_EPSILON)
	var height := generated_height(full_size, overhang, parameters)
	var points: Array[Vector3] = []
	var rings: Array[PackedInt32Array] = []

	for ring_index in range(RING_COUNT):
		var ring := PackedInt32Array()
		var latitude := float(ring_index) / float(RING_COUNT) * PI * 0.5
		var radius_scale := cos(latitude)
		var ring_height := height * sin(latitude)
		for segment_index in range(ANGULAR_SEGMENTS):
			var angle := -PI * 0.5 + TAU * float(segment_index) / float(ANGULAR_SEGMENTS)
			ring.append(points.size())
			points.append(Vector3(
				center_x + cos(angle) * radius_x * radius_scale,
				ring_height,
				center_z + sin(angle) * radius_z * radius_scale
			))
		rings.append(ring)

	var peak_index := points.size()
	points.append(Vector3(center_x, height, center_z))
	var triangles: Array[PackedInt32Array] = []
	for ring_index in range(rings.size() - 1):
		var lower_ring := rings[ring_index]
		var upper_ring := rings[ring_index + 1]
		for segment_index in range(ANGULAR_SEGMENTS):
			var next_index := (segment_index + 1) % ANGULAR_SEGMENTS
			triangles.append(PackedInt32Array([
				lower_ring[segment_index],
				upper_ring[segment_index],
				upper_ring[next_index],
			]))
			triangles.append(PackedInt32Array([
				lower_ring[segment_index],
				upper_ring[next_index],
				lower_ring[next_index],
			]))

	var top_ring := rings[rings.size() - 1]
	for segment_index in range(ANGULAR_SEGMENTS):
		triangles.append(PackedInt32Array([
			top_ring[segment_index],
			peak_index,
			top_ring[(segment_index + 1) % ANGULAR_SEGMENTS],
		]))
	return {
		"points": points,
		"triangles": triangles,
		"boundary": rings[0],
	}


static func _triangle_height_at_point(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	point: Vector2
) -> float:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var c2 := Vector2(c.x, c.z)
	var denominator := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
	if absf(denominator) <= RECT_EPSILON:
		return -INF
	var weight_a := (
		(b2.y - c2.y) * (point.x - c2.x)
		+ (c2.x - b2.x) * (point.y - c2.y)
	) / denominator
	var weight_b := (
		(c2.y - a2.y) * (point.x - c2.x)
		+ (a2.x - c2.x) * (point.y - c2.y)
	) / denominator
	var weight_c := 1.0 - weight_a - weight_b
	if (
		weight_a < -RECT_EPSILON
		or weight_b < -RECT_EPSILON
		or weight_c < -RECT_EPSILON
	):
		return -INF
	return a.y * weight_a + b.y * weight_b + c.y * weight_c
