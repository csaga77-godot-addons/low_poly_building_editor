@tool
extends "res://addons/low_poly_building_editor/roofs/roof_style_geometry_3d.gd"

## Shared geometry strategy for hip roofs that rise from a closed base ring to a
## single centered apex (pyramid, hexagonal, and octagonal pavilion hips).
## Subclasses only declare how many base sides they have and, optionally, how the
## ring is projected onto the render bounds. Height derives from the roof run and
## the sloped face angle, matching the other pitched roof styles.


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
	var pavilion_topology := topology(size, overhang, parameters)
	var points: Array[Vector3] = pavilion_topology["points"]
	var triangles: Array[PackedInt32Array] = pavilion_topology["triangles"]
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
	var pavilion_topology := topology(full_size, overhang, parameters)
	var points: Array[Vector3] = pavilion_topology["points"]
	var triangles: Array[PackedInt32Array] = pavilion_topology["triangles"]
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
	var height := generated_height(full_size, overhang, parameters)
	var ring := _base_ring(bounds)
	var points: Array[Vector3] = []
	var ring_indices := PackedInt32Array()
	for ring_point in ring:
		ring_indices.append(points.size())
		points.append(ring_point)
	var apex_index := points.size()
	points.append(Vector3(center_x, height, center_z))
	var triangles: Array[PackedInt32Array] = []
	var side_count := ring_indices.size()
	for segment_index in range(side_count):
		triangles.append(PackedInt32Array([
			ring_indices[segment_index],
			apex_index,
			ring_indices[(segment_index + 1) % side_count],
		]))
	return {
		"points": points,
		"triangles": triangles,
		"boundary": ring_indices,
	}


## Number of base sides for this pavilion hip. Subclasses must override.
func _side_count() -> int:
	return 4


## Angular offset applied to the base ring so the polygon aligns pleasantly with
## the render bounds. Subclasses may override.
func _angle_offset() -> float:
	return 0.0


## Projects one base-ring direction onto the render bounds. The default inscribes
## a regular polygon inside the bounds ellipse; subclasses may override to reach
## the bounds corners instead.
func _projected_offset(
	cos_angle: float,
	sin_angle: float,
	radius_x: float,
	radius_z: float
) -> Vector2:
	return Vector2(cos_angle * radius_x, sin_angle * radius_z)


func _base_ring(bounds: Vector4) -> PackedVector3Array:
	var center_x := (bounds.x + bounds.y) * 0.5
	var center_z := (bounds.z + bounds.w) * 0.5
	var radius_x := maxf((bounds.y - bounds.x) * 0.5, RECT_EPSILON)
	var radius_z := maxf((bounds.w - bounds.z) * 0.5, RECT_EPSILON)
	var side_count := maxi(_side_count(), 3)
	var offset := _angle_offset()
	var ring := PackedVector3Array()
	for segment_index in range(side_count):
		var angle := -PI * 0.5 + offset + TAU * float(segment_index) / float(side_count)
		var projected := _projected_offset(cos(angle), sin(angle), radius_x, radius_z)
		ring.append(Vector3(center_x + projected.x, 0.0, center_z + projected.y))
	return ring


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
