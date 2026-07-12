@tool
extends "res://addons/low_poly_building_editor/stairs/stair_segment_geometry_3d.gd"

# Internal geometry strategy for winder stairs: fanned tread meshes around a
# pivot corner. `WinderStairs3D` owns plan construction, mirroring, and
# collision orchestration; this class owns the radial-fan mesh primitives and
# the pure perimeter-sampling helpers the node's collision pass reuses.


static func radial_fan_perimeter_cumulative(perimeter: PackedVector2Array) -> PackedFloat32Array:
	var cumulative := PackedFloat32Array([0.0])
	for index in range(perimeter.size() - 1):
		cumulative.append(
			cumulative[index] + perimeter[index].distance_to(perimeter[index + 1])
		)
	return cumulative


static func radial_fan_point_at(
	perimeter: PackedVector2Array,
	cumulative: PackedFloat32Array,
	target: float
) -> Vector2:
	for index in range(perimeter.size() - 1):
		if target <= cumulative[index + 1] + 0.0001:
			var leg_length := cumulative[index + 1] - cumulative[index]
			if leg_length <= 0.0001:
				continue
			var ratio := clampf((target - cumulative[index]) / leg_length, 0.0, 1.0)
			return perimeter[index].lerp(perimeter[index + 1], ratio)
	return perimeter[perimeter.size() - 1]


func append_radial_fan_segment_primitive(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var pivot: Vector2 = seg["pivot"]
	var perimeter: PackedVector2Array = seg["perimeter"]
	var bottom := segment_bottom(seg)
	var cumulative := radial_fan_perimeter_cumulative(perimeter)
	var total_length := cumulative[cumulative.size() - 1]
	if total_length <= 0.001:
		return
	var up_normal := segment_direction(seg, Vector3.UP).normalized()
	# Open risers turn each fanned tread into a floating wedge slab: a bottom
	# fan and per-tread radial faces replace the shared closed underside,
	# boundary risers, and extra walls. Nosing has no winder-fan variant and
	# falls back to the closed mass.
	var use_open := tread_style == TreadStyle.OPEN
	var slab := tread_slab_thickness()
	for tread_index in range(steps):
		var t0 := total_length * float(tread_index) / float(steps)
		var t1 := total_length * float(tread_index + 1) / float(steps)
		var tread_top := rise * float(tread_index + 1)
		var tread_bottom := tread_top - slab if use_open else bottom
		var edge_points: Array[Vector2] = [
			radial_fan_point_at(perimeter, cumulative, t0),
		]
		for corner_index in range(1, perimeter.size() - 1):
			var corner_distance := cumulative[corner_index]
			if corner_distance > t0 + 0.0001 and corner_distance < t1 - 0.0001:
				edge_points.append(perimeter[corner_index])
		edge_points.append(radial_fan_point_at(perimeter, cumulative, t1))
		for edge_index in range(edge_points.size() - 1):
			var q0 := edge_points[edge_index]
			var q1 := edge_points[edge_index + 1]
			if q0.distance_to(q1) <= 0.0001:
				continue
			var triangle_base := vertices.size()
			vertices.append(segment_point(seg, Vector3(pivot.x, tread_top, pivot.y)))
			vertices.append(segment_point(seg, Vector3(q0.x, tread_top, q0.y)))
			vertices.append(segment_point(seg, Vector3(q1.x, tread_top, q1.y)))
			for _index in range(3):
				normals.append(up_normal)
				colors.append(stair_color)
			append_oriented_triangle(
				vertices, indices, up_normal,
				triangle_base, triangle_base + 1, triangle_base + 2
			)
			if use_open:
				var down_normal := -up_normal
				var bottom_base := vertices.size()
				vertices.append(segment_point(seg, Vector3(
					pivot.x, tread_bottom, pivot.y
				)))
				vertices.append(segment_point(seg, Vector3(q0.x, tread_bottom, q0.y)))
				vertices.append(segment_point(seg, Vector3(q1.x, tread_bottom, q1.y)))
				for _index in range(3):
					normals.append(down_normal)
					colors.append(stair_color)
				append_oriented_triangle(
					vertices, indices, down_normal,
					bottom_base, bottom_base + 1, bottom_base + 2
				)
			var edge_dir := (q1 - q0).normalized()
			var outward := Vector2(-edge_dir.y, edge_dir.x)
			var edge_mid := (q0 + q1) * 0.5
			if outward.dot(edge_mid - pivot) < 0.0:
				outward = -outward
			append_segment_quad(
				seg, vertices, normals, colors, indices,
				Vector3(q0.x, tread_bottom, q0.y),
				Vector3(q1.x, tread_bottom, q1.y),
				Vector3(q1.x, tread_top, q1.y),
				Vector3(q0.x, tread_top, q0.y),
				Vector3(outward.x, 0.0, outward.y)
			)
		if use_open:
			var interior := radial_fan_point_at(
				perimeter, cumulative, (t0 + t1) * 0.5
			)
			append_radial_fan_face(
				seg, vertices, normals, colors, indices,
				pivot, edge_points[0], tread_bottom, tread_top, interior
			)
			append_radial_fan_face(
				seg, vertices, normals, colors, indices,
				pivot, edge_points[edge_points.size() - 1],
				tread_bottom, tread_top, interior
			)
	if use_open:
		return
	for boundary_index in range(steps):
		var boundary_t := total_length * float(boundary_index) / float(steps)
		var boundary_point := radial_fan_point_at(perimeter, cumulative, boundary_t)
		var radial := boundary_point - pivot
		if radial.length() <= 0.0001:
			continue
		var riser_low := rise * float(boundary_index)
		var riser_high := rise * float(boundary_index + 1)
		var riser_normal := Vector2(-radial.y, radial.x).normalized()
		var sample := radial_fan_point_at(
			perimeter, cumulative, minf(boundary_t + total_length * 0.01, total_length)
		)
		var edge_mid := (pivot + boundary_point) * 0.5
		if riser_normal.dot(sample - edge_mid) > 0.0:
			riser_normal = -riser_normal
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(pivot.x, riser_low, pivot.y),
			Vector3(boundary_point.x, riser_low, boundary_point.y),
			Vector3(boundary_point.x, riser_high, boundary_point.y),
			Vector3(pivot.x, riser_high, pivot.y),
			Vector3(riser_normal.x, 0.0, riser_normal.y)
		)
	for wall: Dictionary in seg["extra_walls"]:
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		if a.distance_to(b) <= 0.001:
			continue
		var wall_top: float = wall["top"]
		var wall_normal: Vector2 = wall["normal"]
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(a.x, bottom, a.y),
			Vector3(b.x, bottom, b.y),
			Vector3(b.x, wall_top, b.y),
			Vector3(a.x, wall_top, a.y),
			Vector3(wall_normal.x, 0.0, wall_normal.y)
		)


func append_radial_fan_face(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	pivot: Vector2,
	boundary_point: Vector2,
	y0: float,
	y1: float,
	away_from: Vector2
) -> void:
	# Radial face of one floating winder tread, from pivot to a fan boundary,
	# facing away from the tread interior sample point.
	var radial := boundary_point - pivot
	if radial.length() <= 0.0001 or y1 - y0 <= 0.0001:
		return
	var face_normal := Vector2(-radial.y, radial.x).normalized()
	var edge_mid := (pivot + boundary_point) * 0.5
	if face_normal.dot(away_from - edge_mid) > 0.0:
		face_normal = -face_normal
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(pivot.x, y0, pivot.y),
		Vector3(boundary_point.x, y0, boundary_point.y),
		Vector3(boundary_point.x, y1, boundary_point.y),
		Vector3(pivot.x, y1, pivot.y),
		Vector3(face_normal.x, 0.0, face_normal.y)
	)
