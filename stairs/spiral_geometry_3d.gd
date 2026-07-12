@tool
extends "res://addons/low_poly_building_editor/stairs/stair_segment_geometry_3d.gd"

# Internal geometry strategy for spiral stairs: radial wedge treads around a
# low-poly central column and the swept helical rail members. `SpiralStairs3D`
# owns plan construction, mirroring, and collision orchestration; this class
# owns the helical/wedge mesh primitives and the pure radial helpers the
# node's collision pass reuses.

const StandardRailGeometry := preload(
	"res://addons/low_poly_building_editor/rails/standard_rail_geometry_3d.gd"
)

const SPIRAL_COLUMN_SIDES := 8
const SPIRAL_RAIL_MAX_SEGMENT_ANGLE_DEGREES := 7.5


static func radial_direction(theta: float, turn_sign: float) -> Vector2:
	# Radial unit direction at spiral angle theta; theta 0 points toward the
	# footprint front (-Z), positive turn_sign turns toward +X (right turn).
	return Vector2(sin(theta) * turn_sign, -cos(theta))


static func helical_tangent(theta: float, turn_sign: float) -> Vector2:
	# Travel direction along the spiral at angle theta.
	return Vector2(cos(theta) * turn_sign, sin(theta)).normalized()


func helical_rail_member_extents(rail: Dictionary) -> Vector2:
	var length: float = rail["length"]
	var layout: Dictionary = rail["post_layout"]
	var positions: PackedFloat32Array = layout["positions"]
	var thicknesses: PackedFloat32Array = layout["thicknesses"]
	var default_size := clamped_infill_rail_size()
	var minimum_run := -default_size * 0.5
	var maximum_run := length + default_size * 0.5
	for index in range(positions.size()):
		var post_size := (
			thicknesses[index] if index < thicknesses.size() else default_size
		)
		minimum_run = minf(minimum_run, positions[index] - post_size * 0.5)
		maximum_run = maxf(maximum_run, positions[index] + post_size * 0.5)
	var minimum_override := float(layout["handrail_minimum_run"])
	var maximum_override := float(layout["handrail_maximum_run"])
	if !is_nan(minimum_override):
		minimum_run = minimum_override
	if !is_nan(maximum_override):
		maximum_run = maximum_override
	return Vector2(minimum_run, maximum_run)


func helical_rail_frame(rail: Dictionary, run_position: float) -> Dictionary:
	var length := maxf(float(rail["length"]), 0.001)
	var turn_radians: float = rail["turn_radians"]
	var turn_sign: float = rail["turn_sign"]
	var clamped_run := clampf(run_position, 0.0, length)
	var theta := turn_radians * clamped_run / length
	var tangent_2d := helical_tangent(theta, turn_sign)
	var point_2d := (
		Vector2(rail["center"])
		+ radial_direction(theta, turn_sign) * float(rail["radius"])
	)
	if run_position < 0.0:
		point_2d += tangent_2d * run_position
	elif run_position > length:
		point_2d += tangent_2d * (run_position - length)
	var tangent := Vector3(tangent_2d.x, 0.0, tangent_2d.y)
	var side := Vector3.UP.cross(tangent).normalized()
	return {
		"point": Vector3(point_2d.x, 0.0, point_2d.y),
		"tangent": tangent,
		"side": side,
	}


func helical_rail_path_height(
	rail: Dictionary,
	run_position: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float,
	use_horizontal_ends: bool
) -> float:
	var height_run := run_position
	if use_horizontal_ends:
		if run_position < lower_horizontal_end:
			height_run = lower_horizontal_end
		elif run_position > upper_horizontal_start:
			height_run = upper_horizontal_start
	return float(rail["rise"]) * height_run / maxf(float(rail["length"]), 0.001)


func helical_rail_path_slope(
	rail: Dictionary,
	run_position: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float,
	use_horizontal_ends: bool
) -> float:
	if (
		use_horizontal_ends
		and (
			run_position < lower_horizontal_end - 0.0001
			or run_position > upper_horizontal_start + 0.0001
		)
	):
		return 0.0
	return float(rail["rise"]) / maxf(float(rail["length"]), 0.001)


func helical_rail_sample_positions(
	rail: Dictionary,
	minimum_run: float,
	maximum_run: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float
) -> PackedFloat32Array:
	var candidates: Array[float] = [minimum_run, maximum_run]
	var length: float = rail["length"]
	if minimum_run < 0.0 and maximum_run > 0.0:
		candidates.append(0.0)
	if minimum_run < length and maximum_run > length:
		candidates.append(length)
	for transition in [lower_horizontal_end, upper_horizontal_start]:
		if transition > minimum_run and transition < maximum_run:
			candidates.append(transition)
	var segment_count := maxi(
		ceili(
			rad_to_deg(float(rail["turn_radians"]))
			/ SPIRAL_RAIL_MAX_SEGMENT_ANGLE_DEGREES
		),
		1
	)
	for segment_index in range(segment_count + 1):
		var run_position := length * float(segment_index) / float(segment_count)
		if run_position > minimum_run and run_position < maximum_run:
			candidates.append(run_position)
	candidates.sort()
	var samples := PackedFloat32Array()
	for candidate in candidates:
		if samples.is_empty() or absf(candidate - samples[-1]) > 0.0001:
			samples.append(candidate)
	return samples


func append_helical_rail_strip(
	edge_a: PackedVector3Array,
	edge_b: PackedVector3Array,
	normal_a: PackedVector3Array,
	normal_b: PackedVector3Array,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if edge_a.size() < 2 or edge_b.size() != edge_a.size():
		return
	var base := vertices.size()
	for sample_index in range(edge_a.size()):
		vertices.append(edge_a[sample_index])
		vertices.append(edge_b[sample_index])
		normals.append(normal_a[sample_index])
		normals.append(normal_b[sample_index])
		colors.append(color)
		colors.append(color)
	for sample_index in range(edge_a.size() - 1):
		var first := base + sample_index * 2
		var next := first + 2
		var face_normal := (
			normal_a[sample_index]
			+ normal_b[sample_index]
			+ normal_a[sample_index + 1]
			+ normal_b[sample_index + 1]
		).normalized()
		append_oriented_triangle(
			vertices, indices, face_normal, first, next, next + 1
		)
		append_oriented_triangle(
			vertices, indices, face_normal, first, next + 1, first + 1
		)


func append_helical_rail_cap(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	for _index in range(4):
		normals.append(normal)
		colors.append(color)
	append_oriented_triangle(vertices, indices, normal, base, base + 1, base + 2)
	append_oriented_triangle(vertices, indices, normal, base, base + 2, base + 3)


func append_helical_rail_sweep(
	rail: Dictionary,
	minimum_run: float,
	maximum_run: float,
	bottom_height: float,
	top_height: float,
	member_width: float,
	color: Color,
	use_horizontal_ends: bool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if maximum_run - minimum_run <= 0.001 or top_height - bottom_height <= 0.001:
		return
	var layout: Dictionary = rail["post_layout"]
	var lower_horizontal_end := float(layout["lower_horizontal_end"])
	var upper_horizontal_start := float(layout["upper_horizontal_start"])
	var samples := helical_rail_sample_positions(
		rail,
		minimum_run,
		maximum_run,
		lower_horizontal_end,
		upper_horizontal_start
	)
	if samples.size() < 2:
		return
	var half_width := maxf(member_width, 0.01) * 0.5
	var inner_bottom := PackedVector3Array()
	var outer_bottom := PackedVector3Array()
	var inner_top := PackedVector3Array()
	var outer_top := PackedVector3Array()
	var inner_normals := PackedVector3Array()
	var outer_normals := PackedVector3Array()
	var top_normals := PackedVector3Array()
	var bottom_normals := PackedVector3Array()
	for run_position in samples:
		var frame := helical_rail_frame(rail, run_position)
		var point: Vector3 = frame["point"]
		var tangent: Vector3 = frame["tangent"]
		var side: Vector3 = frame["side"]
		var path_height := helical_rail_path_height(
			rail,
			run_position,
			lower_horizontal_end,
			upper_horizontal_start,
			use_horizontal_ends
		)
		var slope := helical_rail_path_slope(
			rail,
			run_position,
			lower_horizontal_end,
			upper_horizontal_start,
			use_horizontal_ends
		)
		var path_tangent := Vector3(tangent.x, slope, tangent.z).normalized()
		var top_normal := path_tangent.cross(side).normalized()
		var bottom_normal := -top_normal
		var inner_offset := -side * half_width
		var outer_offset := side * half_width
		inner_bottom.append(point + inner_offset + Vector3.UP * (path_height + bottom_height))
		outer_bottom.append(point + outer_offset + Vector3.UP * (path_height + bottom_height))
		inner_top.append(point + inner_offset + Vector3.UP * (path_height + top_height))
		outer_top.append(point + outer_offset + Vector3.UP * (path_height + top_height))
		inner_normals.append(-side)
		outer_normals.append(side)
		top_normals.append(top_normal)
		bottom_normals.append(bottom_normal)
	append_helical_rail_strip(
		inner_top, outer_top, top_normals, top_normals, color,
		vertices, normals, colors, indices
	)
	append_helical_rail_strip(
		outer_bottom, inner_bottom, bottom_normals, bottom_normals, color,
		vertices, normals, colors, indices
	)
	append_helical_rail_strip(
		outer_top, outer_bottom, outer_normals, outer_normals, color,
		vertices, normals, colors, indices
	)
	append_helical_rail_strip(
		inner_bottom, inner_top, inner_normals, inner_normals, color,
		vertices, normals, colors, indices
	)
	var start_tangent: Vector3 = helical_rail_frame(rail, samples[0])["tangent"]
	var end_tangent: Vector3 = helical_rail_frame(rail, samples[-1])["tangent"]
	append_helical_rail_cap(
		inner_bottom[0], inner_top[0], outer_top[0], outer_bottom[0],
		-start_tangent, color, vertices, normals, colors, indices
	)
	var last := samples.size() - 1
	append_helical_rail_cap(
		inner_bottom[last], outer_bottom[last], outer_top[last], inner_top[last],
		end_tangent, color, vertices, normals, colors, indices
	)


func append_helical_rail_posts(
	rail: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var layout: Dictionary = rail["post_layout"]
	var positions: PackedFloat32Array = layout["positions"]
	var base_heights: PackedFloat32Array = layout["base_heights"]
	var thicknesses: PackedFloat32Array = layout["thicknesses"]
	var top_heights: PackedFloat32Array = layout["top_heights"]
	var base_follows_rise: PackedByteArray = layout["base_follows_rise"]
	var length := maxf(float(rail["length"]), 0.001)
	var rise_per_run := float(rail["rise"]) / length
	for index in range(positions.size()):
		var run_position := positions[index]
		var frame := helical_rail_frame(rail, run_position)
		var point: Vector3 = frame["point"]
		var path_height := float(rail["rise"]) * run_position / length
		var local_top := NAN
		if index < top_heights.size() and !is_nan(top_heights[index]):
			local_top = top_heights[index] - path_height
		StandardRailGeometry.append_rail(
			vertices, normals, colors, indices,
			Vector3(point.x, path_height, point.z),
			frame["tangent"], Vector3.UP, frame["side"],
			1.0, rise_per_run, rail_height,
			1.0, clamped_infill_rail_size(), rail_thickness, rail_lower_height,
			rail_color,
			PackedFloat32Array([0.0]),
			PackedFloat32Array([base_heights[index] - path_height]),
			PackedFloat32Array([thicknesses[index]]),
			PackedFloat32Array([local_top]),
			-INF, INF, NAN, NAN,
			infill_style, infill_count_between_newels,
			PackedByteArray([
				base_follows_rise[index] if index < base_follows_rise.size() else 0
			]),
			false,
			false
		)


func append_helical_rail_primitive(
	rail: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var extents := helical_rail_member_extents(rail)
	var height := maxf(rail_height, 0.2)
	var bar_size := handrail_width()
	var handrail_bottom := height - bar_size
	append_helical_rail_sweep(
		rail, extents.x, extents.y, handrail_bottom, height, bar_size,
		rail_color, true, vertices, normals, colors, indices
	)

	var has_base_rail := StandardRailGeometry.has_lower_rail(
		rail_height, rail_thickness, rail_lower_height
	)
	var base_rail_top := StandardRailGeometry.lower_rail_top_height(
		rail_height, rail_thickness, rail_lower_height
	)
	var infill_bottom := 0.0
	if has_base_rail:
		var base_center := base_rail_top - bar_size * 0.5
		append_helical_rail_sweep(
			rail, extents.x, extents.y,
			base_center - bar_size * 0.5,
			base_center + bar_size * 0.5,
			bar_size, rail_color, false,
			vertices, normals, colors, indices
		)
		infill_bottom = base_rail_top

	if infill_style == StandardRailGeometry.RailStyle.HORIZONTAL:
		var infill_count := clampi(infill_count_between_newels, 0, 64)
		var infill_size := minf(
			clamped_infill_rail_size(),
			maxf(handrail_bottom - infill_bottom, 0.02)
		)
		var clear_height := (
			handrail_bottom - infill_bottom - infill_size * float(infill_count)
		)
		if infill_count > 0 and clear_height >= 0.0:
			var clear_gap := clear_height / float(infill_count + 1)
			for infill_index in range(infill_count):
				var infill_center := (
					infill_bottom
					+ clear_gap * float(infill_index + 1)
					+ infill_size * (float(infill_index) + 0.5)
				)
				append_helical_rail_sweep(
					rail, extents.x, extents.y,
					infill_center - infill_size * 0.5,
					infill_center + infill_size * 0.5,
					infill_size, rail_color, false,
					vertices, normals, colors, indices
				)
	elif (
		infill_style == StandardRailGeometry.RailStyle.GLASS_PANEL
		and handrail_bottom - infill_bottom > 0.001
	):
		var panel_thickness := maxf(
			minf(bar_size, clamped_infill_rail_size()) * 0.5,
			0.02
		)
		append_helical_rail_sweep(
			rail, extents.x, extents.y,
			infill_bottom, handrail_bottom,
			panel_thickness, StandardRailGeometry.GLASS_PANEL_COLOR, false,
			vertices, normals, colors, indices
		)
	append_helical_rail_posts(rail, vertices, normals, colors, indices)


func append_radial_wedge_sequence_primitive(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var center: Vector2 = seg["center"]
	var outer_radius: float = seg["outer_radius"]
	var inner_radius: float = seg["inner_radius"]
	var turn_radians: float = seg["turn_radians"]
	var turn_sign: float = seg["turn_sign"]
	if steps <= 0 or outer_radius - inner_radius <= 0.001:
		return
	# Wedge tread slabs around the central column. The inner faces are
	# omitted: they sit inside the column, whose circumscribed prism contains
	# the treads' inner circle. Open risers keep each slab floating at the
	# tread slab thickness; Closed (and Nosing, which has no spiral variant)
	# drops each wedge to the previous tread's top minus the slab so
	# consecutive wedges overlap vertically with no gap.
	var slab := tread_slab_thickness()
	for tread_index in range(steps):
		var theta0 := turn_radians * float(tread_index) / float(steps)
		var theta1 := turn_radians * float(tread_index + 1) / float(steps)
		var top := rise * float(tread_index + 1)
		var bottom := top - slab
		if tread_style != TreadStyle.OPEN:
			bottom = rise * float(tread_index) - slab
		var inner0 := center + radial_direction(theta0, turn_sign) * inner_radius
		var inner1 := center + radial_direction(theta1, turn_sign) * inner_radius
		var outer0 := center + radial_direction(theta0, turn_sign) * outer_radius
		var outer1 := center + radial_direction(theta1, turn_sign) * outer_radius
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner0.x, top, inner0.y),
			Vector3(inner1.x, top, inner1.y),
			Vector3(outer1.x, top, outer1.y),
			Vector3(outer0.x, top, outer0.y),
			Vector3.UP
		)
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner0.x, bottom, inner0.y),
			Vector3(inner1.x, bottom, inner1.y),
			Vector3(outer1.x, bottom, outer1.y),
			Vector3(outer0.x, bottom, outer0.y),
			Vector3.DOWN
		)
		var outer_mid := ((outer0 + outer1) * 0.5 - center).normalized()
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(outer0.x, bottom, outer0.y),
			Vector3(outer1.x, bottom, outer1.y),
			Vector3(outer1.x, top, outer1.y),
			Vector3(outer0.x, top, outer0.y),
			Vector3(outer_mid.x, 0.0, outer_mid.y)
		)
		var leading_normal := -helical_tangent(theta0, turn_sign)
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner0.x, bottom, inner0.y),
			Vector3(outer0.x, bottom, outer0.y),
			Vector3(outer0.x, top, outer0.y),
			Vector3(inner0.x, top, inner0.y),
			Vector3(leading_normal.x, 0.0, leading_normal.y)
		)
		var trailing_normal := helical_tangent(theta1, turn_sign)
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner1.x, bottom, inner1.y),
			Vector3(outer1.x, bottom, outer1.y),
			Vector3(outer1.x, top, outer1.y),
			Vector3(inner1.x, top, inner1.y),
			Vector3(trailing_normal.x, 0.0, trailing_normal.y)
		)
	# Central column: a fixed-side prism circumscribing the treads' inner
	# circle, from the underside depth up to the top-floor height, with a
	# visible top cap and an open hidden bottom.
	var column_radius := inner_radius / cos(PI / float(SPIRAL_COLUMN_SIDES))
	var height := maxf(stair_height, 0.05)
	var base_y := -maxf(stair_thickness, 0.0)
	var up_normal := segment_direction(seg, Vector3.UP).normalized()
	for side_index in range(SPIRAL_COLUMN_SIDES):
		var phi0 := TAU * float(side_index) / float(SPIRAL_COLUMN_SIDES)
		var phi1 := TAU * float(side_index + 1) / float(SPIRAL_COLUMN_SIDES)
		var p0 := center + Vector2(cos(phi0), sin(phi0)) * column_radius
		var p1 := center + Vector2(cos(phi1), sin(phi1)) * column_radius
		var face_mid := ((p0 + p1) * 0.5 - center).normalized()
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(p0.x, base_y, p0.y),
			Vector3(p1.x, base_y, p1.y),
			Vector3(p1.x, height, p1.y),
			Vector3(p0.x, height, p0.y),
			Vector3(face_mid.x, 0.0, face_mid.y)
		)
		var triangle_base := vertices.size()
		vertices.append(segment_point(seg, Vector3(center.x, height, center.y)))
		vertices.append(segment_point(seg, Vector3(p0.x, height, p0.y)))
		vertices.append(segment_point(seg, Vector3(p1.x, height, p1.y)))
		for _index in range(3):
			normals.append(up_normal)
			colors.append(stair_color)
		append_oriented_triangle(
			vertices, indices, up_normal,
			triangle_base, triangle_base + 1, triangle_base + 2
		)
