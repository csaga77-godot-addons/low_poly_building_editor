@tool
class_name StraightStairs3D
extends "res://addons/low_poly_building_editor/stairs/stairs_3d.gd"


func _append_stair_layout_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps := _effective_step_count()
	var height := maxf(stair_height, 0.05)
	var bottom_y := -maxf(stair_thickness, 0.0)
	var tread_depth := depth / float(steps)
	var rise := height / float(steps)
	var identity_seg := _make_flight_segment(
		Vector3.ZERO, Vector3.BACK, width, depth, steps, rise
	)

	if tread_style == TreadStyle.OPEN:
		_append_open_flight_treads(identity_seg, vertices, normals, colors, indices)
		_append_rail_geometry(width, depth, height, vertices, normals, colors, indices)
		return

	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y0 := rise * float(step_index)
		var y1 := rise * float(step_index + 1)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			Vector3(0.0, y1, z0),
			Vector3(0.0, y1, z1),
			Vector3(width, y1, z1),
			Vector3(width, y1, z0),
			Vector3.UP
		)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			Vector3(0.0, y0, z0),
			Vector3(0.0, y1, z0),
			Vector3(width, y1, z0),
			Vector3(width, y0, z0),
			Vector3.FORWARD
		)

	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		Vector3(0.0, bottom_y, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom_y, 0.0),
		Vector3.FORWARD
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		Vector3(0.0, bottom_y, depth),
		Vector3(width, bottom_y, depth),
		Vector3(width, height, depth),
		Vector3(0.0, height, depth),
		Vector3.BACK
	)
	_append_side_strips(
		vertices, normals, colors, indices,
		depth, height, bottom_y, steps, 0.0, Vector3.LEFT
	)
	_append_side_strips(
		vertices, normals, colors, indices,
		depth, height, bottom_y, steps, width, Vector3.RIGHT
	)
	_append_flight_nosing_lips(identity_seg, vertices, normals, colors, indices)

	_append_rail_geometry(width, depth, height, vertices, normals, colors, indices)


func _append_rail_geometry(
	width: float,
	depth: float,
	height: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if !left_rail_enabled and !right_rail_enabled:
		return
	var steps := _effective_step_count()
	# One post per tread, with optional thicker lower/upper and evenly spaced
	# middle newels.
	# Tread placement replaces the terminal regular post; Floor placement
	# retains it and adds a newel at the corresponding stair-run endpoint.
	var post_layout := _build_rail_post_layout(
		depth,
		height,
		steps,
		lower_newel_enabled,
		upper_newel_enabled,
		middle_newel_post_count,
		lower_newel_placement,
		upper_newel_placement
	)
	var post_positions: PackedFloat32Array = post_layout["positions"]
	var post_base_heights: PackedFloat32Array = post_layout["base_heights"]
	var post_thicknesses: PackedFloat32Array = post_layout["thicknesses"]
	var post_top_heights: PackedFloat32Array = post_layout["top_heights"]
	var post_base_follows_rise: PackedByteArray = post_layout["base_follows_rise"]
	var lower_horizontal_end := float(post_layout["lower_horizontal_end"])
	var upper_horizontal_start := float(post_layout["upper_horizontal_start"])
	var handrail_minimum_run := float(post_layout["handrail_minimum_run"])
	var handrail_maximum_run := float(post_layout["handrail_maximum_run"])
	# Inset each rail from its side edge instead of straddling the exact
	# footprint boundary, clamped so opposing margins cannot cross.
	var margin := minf(rail_edge_margin, width * 0.45)
	if left_rail_enabled:
		StandardRailGeometry.append_rail(
			vertices,
			normals,
			colors,
			indices,
			Vector3(margin, 0.0, 0.0),
			Vector3.BACK,
			Vector3.UP,
			Vector3.RIGHT,
			depth,
			height,
			rail_height,
			1.0, # post_spacing is unused: post_positions overrides it below.
			_clamped_infill_rail_size(),
			rail_thickness,
			rail_lower_height,
			rail_color,
			post_positions,
			post_base_heights,
			post_thicknesses,
			post_top_heights,
			lower_horizontal_end,
			upper_horizontal_start,
			handrail_minimum_run,
			handrail_maximum_run,
			infill_style,
			infill_count_between_newels,
			post_base_follows_rise
		)
	if right_rail_enabled:
		StandardRailGeometry.append_rail(
			vertices,
			normals,
			colors,
			indices,
			Vector3(width - margin, 0.0, 0.0),
			Vector3.BACK,
			Vector3.UP,
			Vector3.RIGHT,
			depth,
			height,
			rail_height,
			1.0, # post_spacing is unused: post_positions overrides it below.
			_clamped_infill_rail_size(),
			rail_thickness,
			rail_lower_height,
			rail_color,
			post_positions,
			post_base_heights,
			post_thicknesses,
			post_top_heights,
			lower_horizontal_end,
			upper_horizontal_start,
			handrail_minimum_run,
			handrail_maximum_run,
			infill_style,
			infill_count_between_newels,
			post_base_follows_rise
		)


func _get_rail_post_layout() -> Dictionary:
	var size := get_stair_size()
	return _build_rail_post_layout(
		size.y,
		maxf(stair_height, 0.05),
		_effective_step_count(),
		lower_newel_enabled,
		upper_newel_enabled,
		middle_newel_post_count,
		lower_newel_placement,
		upper_newel_placement
	)


func _append_side_strips(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	depth: float,
	height: float,
	bottom_y: float,
	steps: int,
	x: float,
	normal: Vector3
) -> void:
	var base := vertices.size()
	var tread_depth := depth / float(steps)
	var rise := height / float(steps)

	# Give every tread-width strip its own bottom endpoints. The old single
	# outline triangulation had only two bottom corners, forcing ear clipping
	# to fan long, needle-like triangles across the full stair run.
	for boundary_index in range(steps + 1):
		vertices.append(Vector3(
			x,
			bottom_y,
			tread_depth * float(boundary_index)
		))
		normals.append(normal)
		colors.append(stair_color)

	var top_base := vertices.size()
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		vertices.append(Vector3(x, y1, z0))
		normals.append(normal)
		colors.append(stair_color)
		vertices.append(Vector3(x, y1, z1))
		normals.append(normal)
		colors.append(stair_color)

	for step_index in range(steps):
		var bottom_left := base + step_index
		var bottom_right := bottom_left + 1
		var top_left := top_base + step_index * 2
		var top_right := top_left + 1
		_append_oriented_triangle(
			vertices, indices, normal,
			bottom_left, top_left, top_right
		)
		_append_oriented_triangle(
			vertices, indices, normal,
			bottom_left, top_right, bottom_right
		)


func _add_stair_collision_shapes(body: StaticBody3D) -> void:
	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return
	var steps := _effective_step_count()
	var rise := maxf(stair_height, 0.05) / float(steps)
	var segment := _make_flight_segment(
		Vector3.ZERO, Vector3.BACK, size.x, size.y, steps, rise
	)
	_add_flight_slope_collision_shape(body, SLOPE_COLLISION_SHAPE_NAME, segment)

	var rail_vertices := PackedVector3Array()
	var rail_normals := PackedVector3Array()
	var rail_colors := PackedColorArray()
	var rail_indices := PackedInt32Array()
	_append_rail_geometry(
		size.x,
		size.y,
		maxf(stair_height, 0.05),
		rail_vertices,
		rail_normals,
		rail_colors,
		rail_indices
	)
	_add_rail_collision_shape(body, rail_vertices, rail_indices)
