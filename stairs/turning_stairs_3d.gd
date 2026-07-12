@tool
extends "res://addons/low_poly_building_editor/stairs/stairs_3d.gd"

enum TurnDirection {
	LEFT,
	RIGHT,
}

enum RailRunKind {
	RAIL_RUN_FLIGHT,
	RAIL_RUN_PLAIN,
}

@export_group("Layout")
@export_enum("Left", "Right") var turn_direction: int = TurnDirection.RIGHT:
	set(value):
		var clamped_value := clampi(value, TurnDirection.LEFT, TurnDirection.RIGHT)
		if turn_direction == clamped_value:
			return
		turn_direction = clamped_value
		_request_rebuild()

@export_range(0.2, 8.0, 0.01, "or_greater") var flight_width := 1.2:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(flight_width, clamped_value):
			return
		flight_width = clamped_value
		_request_rebuild()


func configure_turning_layout(
	new_turn_direction: int,
	new_flight_width: float
) -> void:
	turn_direction = new_turn_direction
	flight_width = new_flight_width


func _make_landing_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float
) -> Dictionary:
	return {
		"kind": SegmentKind.SEGMENT_LANDING,
		"origin": origin,
		"run_axis": run_dir,
		"width_axis": Vector3.UP.cross(run_dir).normalized(),
		"width": width,
		"run": run_length,
		"steps": 0,
		"rise": 0.0,
	}


func _make_flight_rail_run(
	side: int,
	origin: Vector3,
	run_dir: Vector3,
	length: float,
	rise: float,
	steps: int,
	is_first: bool,
	is_last: bool,
	middle_newels: int
) -> Dictionary:
	return {
		"kind": RailRunKind.RAIL_RUN_FLIGHT,
		"side": side,
		"origin": origin,
		"run_dir": run_dir,
		"length": length,
		"rise": rise,
		"steps": maxi(steps, 1),
		"first": is_first,
		"last": is_last,
		"middle_newels": middle_newels,
	}


func _make_plain_rail_run(
	side: int,
	origin: Vector3,
	run_dir: Vector3,
	length: float,
	rise: float,
	post_spacing: float,
	post_positions := PackedFloat32Array(),
	post_base_heights := PackedFloat32Array(),
	post_thicknesses := PackedFloat32Array(),
	post_base_follows_rise := PackedByteArray(),
	minimum_run_override := NAN,
	maximum_run_override := NAN,
	post_top_heights := PackedFloat32Array(),
	lower_horizontal_end := -INF,
	upper_horizontal_start := INF,
	post_newel_flags := PackedByteArray()
) -> Dictionary:
	return {
		"kind": RailRunKind.RAIL_RUN_PLAIN,
		"side": side,
		"origin": origin,
		"run_dir": run_dir,
		"length": length,
		"rise": rise,
		"post_spacing": post_spacing,
		"post_positions": post_positions,
		"post_base_heights": post_base_heights,
		"post_thicknesses": post_thicknesses,
		"post_base_follows_rise": post_base_follows_rise,
		"minimum_run_override": minimum_run_override,
		"maximum_run_override": maximum_run_override,
		"post_top_heights": post_top_heights,
		"lower_horizontal_end": lower_horizontal_end,
		"upper_horizontal_start": upper_horizontal_start,
		"post_newel_flags": post_newel_flags,
	}


func _append_layout_geometry(
	plan: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	for seg: Dictionary in plan["segments"]:
		match int(seg["kind"]):
			SegmentKind.SEGMENT_FLIGHT:
				_append_flight_segment_geometry(seg, vertices, normals, colors, indices)
			SegmentKind.SEGMENT_LANDING:
				_append_landing_segment_geometry(seg, vertices, normals, colors, indices)
			_:
				_append_layout_specific_segment_geometry(
					seg, vertices, normals, colors, indices
				)
	_append_layout_rail_geometry(plan, vertices, normals, colors, indices)


func _append_layout_specific_segment_geometry(
	_seg: Dictionary,
	_vertices: PackedVector3Array,
	_normals: PackedVector3Array,
	_colors: PackedColorArray,
	_indices: PackedInt32Array
) -> void:
	pass


func _append_layout_rail_geometry(
	plan: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if !left_rail_enabled and !right_rail_enabled:
		return
	for run: Dictionary in plan["rail_runs"]:
		var side: int = run["side"]
		if side == RAIL_SIDE_LEFT and !left_rail_enabled:
			continue
		if side == RAIL_SIDE_RIGHT and !right_rail_enabled:
			continue
		var length: float = run["length"]
		if length <= 0.001:
			continue
		var run_dir: Vector3 = run["run_dir"]
		var side_axis := Vector3.UP.cross(run_dir).normalized()
		if int(run["kind"]) == RailRunKind.RAIL_RUN_FLIGHT:
			# Interior flight ends (the transition side) carry one shared
			# tread-mid junction newel with a raked top, and the raked
			# handrail/base bars are cut flush at the flight boundary where
			# the transition leg's bars continue at the identical height, so
			# the rail stays continuous across every transition.
			var is_first := bool(run["first"])
			var is_last := bool(run["last"])
			var layout := _build_rail_post_layout(
				length,
				run["rise"],
				run["steps"],
				lower_newel_enabled and is_first,
				upper_newel_enabled and is_last,
				int(run["middle_newels"]),
				lower_newel_placement,
				upper_newel_placement,
				!is_first,
				!is_last
			)
			var handrail_minimum: float = layout["handrail_minimum_run"]
			var handrail_maximum: float = layout["handrail_maximum_run"]
			if !is_first:
				handrail_minimum = 0.0
			if !is_last:
				handrail_maximum = length
			StandardRailGeometry.append_rail(
				vertices, normals, colors, indices,
				run["origin"], run_dir, Vector3.UP, side_axis,
				length, run["rise"], rail_height,
				1.0, # post_spacing is unused: post_positions overrides it below.
				_clamped_infill_rail_size(), rail_thickness, rail_lower_height,
				rail_color,
				layout["positions"], layout["base_heights"],
				layout["thicknesses"], layout["top_heights"],
				float(layout["lower_horizontal_end"]),
				float(layout["upper_horizontal_start"]),
				handrail_minimum,
				handrail_maximum,
				infill_style, infill_count_between_newels,
				layout["base_follows_rise"]
			)
		else:
			StandardRailGeometry.append_rail(
				vertices, normals, colors, indices,
				run["origin"], run_dir, Vector3.UP, side_axis,
				length, run["rise"], rail_height,
				float(run["post_spacing"]),
				_clamped_infill_rail_size(), rail_thickness, rail_lower_height,
				rail_color,
				run["post_positions"], run["post_base_heights"],
				run["post_thicknesses"], run["post_top_heights"],
				float(run["lower_horizontal_end"]),
				float(run["upper_horizontal_start"]),
				float(run["minimum_run_override"]),
				float(run["maximum_run_override"]),
				infill_style, infill_count_between_newels,
				run["post_base_follows_rise"],
				false # transition legs own their full post layout; junction
					# posts are shared with the adjacent flight/leg runs.
			)
	_append_layout_specific_rail_geometry(
		plan, vertices, normals, colors, indices
	)


func _append_layout_specific_rail_geometry(
	_plan: Dictionary,
	_vertices: PackedVector3Array,
	_normals: PackedVector3Array,
	_colors: PackedColorArray,
	_indices: PackedInt32Array
) -> void:
	pass


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(turn_direction)
	values.append(flight_width)
	return values


func _clamped_layout_flight_width(
	width: float,
	depth: float,
	maximum_width: float
) -> float:
	return maxf(
		minf(maxf(flight_width, 0.2), minf(maximum_width, minf(width, depth))),
		0.05
	)


func _allocate_layout_steps(
	run_lengths: PackedFloat32Array,
	winder_treads: int
) -> Dictionary:
	var flight_count := run_lengths.size()
	var flight_budget := maxi(_effective_step_count() - winder_treads, flight_count)
	var counts := PackedInt32Array()
	counts.resize(flight_count)
	counts.fill(1)
	var extra := flight_budget - flight_count
	var total_run := 0.0
	for run_length in run_lengths:
		total_run += maxf(run_length, 0.001)
	var assigned := 0
	var remainders: Array[Dictionary] = []
	for index in range(flight_count):
		var share := extra * maxf(run_lengths[index], 0.001) / total_run
		var base := int(floorf(share))
		counts[index] += base
		assigned += base
		remainders.append({"index": index, "fraction": share - float(base)})
	remainders.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["fraction"]) > float(b["fraction"])
	)
	for pass_index in range(extra - assigned):
		counts[int(remainders[pass_index % flight_count]["index"])] += 1
	return {
		"flights": counts,
		"winder": winder_treads,
		"total": flight_budget + winder_treads,
	}


func _distribute_middle_newels(flight_steps: PackedInt32Array) -> PackedInt32Array:
	var shares := PackedInt32Array()
	shares.resize(flight_steps.size())
	var total := 0
	for steps in flight_steps:
		total += steps
	if total <= 0 or middle_newel_post_count <= 0:
		shares.fill(0)
		return shares
	for index in range(flight_steps.size()):
		shares[index] = int(roundf(
			float(middle_newel_post_count) * float(flight_steps[index]) / float(total)
		))
	return shares


func _create_turning_plan_context(
	run_lengths: PackedFloat32Array,
	winder_treads: int
) -> Dictionary:
	var allocation := _allocate_layout_steps(run_lengths, winder_treads)
	var flight_steps: PackedInt32Array = allocation["flights"]
	var total_steps: int = allocation["total"]
	var rise := maxf(stair_height, 0.05) / float(maxi(total_steps, 1))
	var total_flight_run := 0.0
	var total_flight_steps := 0
	for index in range(run_lengths.size()):
		total_flight_run += run_lengths[index]
		total_flight_steps += flight_steps[index]
	return {
		"allocation": allocation,
		"flight_steps": flight_steps,
		"total_steps": total_steps,
		"rise": rise,
		"middle_shares": _distribute_middle_newels(flight_steps),
		"post_spacing": clampf(
			total_flight_run / float(maxi(total_flight_steps, 1)), 0.3, 2.0
		),
		"segments": [] as Array[Dictionary],
		"rail_runs": [] as Array[Dictionary],
	}


func _finish_turning_plan(
	context: Dictionary,
	width: float,
	effective_flight_width: float
) -> Dictionary:
	var plan := {
		"segments": context["segments"],
		"rail_runs": context["rail_runs"],
		"flight_width": effective_flight_width,
		"total_steps": context["total_steps"],
		"rise": context["rise"],
	}
	if turn_direction == TurnDirection.LEFT:
		_mirror_layout_plan(plan, width)
	return plan


func _clamped_newel_size() -> float:
	# Same clamp as flight newels: never wider than the handrail so the welded
	# handrail underside fully covers the post's open top.
	return minf(maxf(rail_newel_post_thickness, 0.02), _handrail_width())


func _stepped_path_surface_height(
	path_position: float,
	path_length: float,
	tread_count: int,
	rise: float
) -> float:
	# Walking-surface height under a path point: the top of the stepped path
	# containing it, with exact tread boundaries resolving to the lower tread.
	if tread_count <= 0 or path_length <= 0.001:
		return 0.0
	var tread_ratio := path_position * float(tread_count) / path_length
	return rise * clampf(ceilf(tread_ratio - 0.0001), 0.0, float(tread_count))


func _add_raked_path_rail_runs(
	rail_runs: Array[Dictionary],
	side: int,
	waypoints: Array[Vector2],
	start_height: float,
	total_rise: float,
	stepped_treads: int,
	rise: float,
	post_spacing: float
) -> void:
	var total_length := 0.0
	for index in range(waypoints.size() - 1):
		total_length += waypoints[index].distance_to(waypoints[index + 1])
	if total_length <= 0.001:
		return
	var newel_size := _clamped_newel_size()
	var infill_size := _clamped_infill_rail_size()
	# At each interior corner both adjacent legs extend their bars past the
	# corner point by half the handrail bar thickness, so the handrail, base
	# rail, and panel outer faces close flush around the corner instead of
	# leaving a sliver where neither leg's cross-section reaches.
	var half_bar := minf(
		maxf(rail_thickness, 0.02),
		maxf(rail_height, 0.2) * 0.5
	) * 0.5
	# The same vertical-rail rule as flights: exactly
	# `infill_count_between_newels` vertical infills per newel span for the
	# Vertical style, and none for Horizontal/Glass (their bars/panel fill the
	# span instead). Each leg is one span bounded by its shared inflection
	# newels.
	var span_infill_count := (
		clampi(infill_count_between_newels, 0, 64)
		if infill_style == StandardRailGeometry.RailStyle.VERTICAL
		else 0
	)
	var has_base_rail := StandardRailGeometry.has_lower_rail(
		rail_height, rail_thickness, rail_lower_height
	)
	var base_rail_top := StandardRailGeometry.lower_rail_top_height(
		rail_height, rail_thickness, rail_lower_height
	)
	var traversed := 0.0
	for index in range(waypoints.size() - 1):
		var from_point := waypoints[index]
		var to_point := waypoints[index + 1]
		var length := from_point.distance_to(to_point)
		if length <= 0.001:
			continue
		var leg_rise := total_rise * length / total_length
		var rise_before := total_rise * traversed / total_length
		var run_dir := Vector3(
			to_point.x - from_point.x,
			0.0,
			to_point.y - from_point.y
		).normalized()
		var is_first_leg := traversed <= 0.001
		var is_last_leg := traversed + length >= total_length - 0.001
		var positions := PackedFloat32Array()
		var base_heights := PackedFloat32Array()
		var thicknesses := PackedFloat32Array()
		var follows_rise := PackedByteArray()
		# Infills between the bounding newel faces with equal clear gaps,
		# matching redistribute_infills_between_newels(). With a base rail they
		# mount on its top with bottoms sheared along the leg's rake; without
		# one they rebase onto the surface beneath (winder tread top, landing
		# floor, or the leg's base diagonal). Legs too short for the requested
		# infills carry only their shared newels. Junction-side spans start at
		# the leg boundary, since the flight's tread-mid junction newel sits
		# beyond it.
		var clear_start := 0.0 if is_first_leg else newel_size * 0.5
		var clear_end := length if is_last_leg else length - newel_size * 0.5
		var infill_clear_total := (
			clear_end - clear_start - infill_size * float(span_infill_count)
		)
		if span_infill_count > 0 and infill_clear_total >= 0.0:
			var clear_gap := infill_clear_total / float(span_infill_count + 1)
			for infill_index in range(span_infill_count):
				var center := (
					clear_start
					+ clear_gap * float(infill_index + 1)
					+ infill_size * (float(infill_index) + 0.5)
				)
				positions.append(center)
				thicknesses.append(infill_size)
				if has_base_rail:
					base_heights.append(base_rail_top + leg_rise * center / length)
					follows_rise.append(1)
				elif stepped_treads > 0:
					base_heights.append(_stepped_path_surface_height(
						traversed + center, total_length, stepped_treads, rise
					) - rise_before)
					follows_rise.append(0)
				else:
					base_heights.append(leg_rise * center / length)
					follows_rise.append(0)
		# One shared newel per interior corner between two legs, owned by the
		# leg that starts there, so adjacent legs never stack duplicate posts.
		# The path's junctions with the adjacent flight rails carry no leg
		# posts at all: the flights own tread-mid junction newels there, and
		# this leg's bars are cut flush at the boundary where the flight's
		# bars end at the identical height, keeping the rail continuous.
		if !is_first_leg:
			positions.append(0.0)
			base_heights.append(
				_stepped_path_surface_height(
					traversed, total_length, stepped_treads, rise
				) - rise_before
			)
			thicknesses.append(newel_size)
			follows_rise.append(0)
		var minimum_override := 0.0 if is_first_leg else -half_bar
		var maximum_override := length if is_last_leg else length + half_bar
		rail_runs.append(_make_plain_rail_run(
			side,
			Vector3(from_point.x, start_height + rise_before, from_point.y),
			run_dir,
			length,
			leg_rise,
			post_spacing,
			positions,
			base_heights,
			thicknesses,
			follows_rise,
			minimum_override,
			maximum_override
		))
		traversed += length


func _build_layout_plan(_width: float, _depth: float) -> Dictionary:
	# Concrete turning-layout classes own their plan construction.
	return {}


func _mirror_layout_plan(plan: Dictionary, width: float) -> void:
	for seg: Dictionary in plan["segments"]:
		var run_axis: Vector3 = seg["run_axis"]
		var width_axis: Vector3 = seg["width_axis"]
		var origin: Vector3 = seg["origin"]
		var segment_width: float = seg["width"]
		var mirrored_run := Vector3(-run_axis.x, run_axis.y, run_axis.z)
		var far_corner := origin + width_axis * segment_width
		seg["run_axis"] = mirrored_run
		seg["width_axis"] = Vector3.UP.cross(mirrored_run).normalized()
		seg["origin"] = Vector3(width - far_corner.x, far_corner.y, far_corner.z)
	for run: Dictionary in plan["rail_runs"]:
		var run_origin: Vector3 = run["origin"]
		var run_dir: Vector3 = run["run_dir"]
		run["origin"] = Vector3(width - run_origin.x, run_origin.y, run_origin.z)
		run["run_dir"] = Vector3(-run_dir.x, run_dir.y, run_dir.z)
		run["side"] = (
			RAIL_SIDE_RIGHT if int(run["side"]) == RAIL_SIDE_LEFT else RAIL_SIDE_LEFT
		)
	_mirror_layout_specific_plan(plan, width)


func _mirror_layout_specific_plan(_plan: Dictionary, _width: float) -> void:
	pass


func _total_rising_step_count() -> int:
	var size := get_stair_size()
	return int(_build_layout_plan(size.x, size.y)["total_steps"])


func _add_side_wall_collision_shapes(body: StaticBody3D) -> void:
	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return
	_add_layout_side_wall_collision_shapes(body, size.x, size.y)


func _add_layout_side_wall_collision_shapes(
	body: StaticBody3D,
	width: float,
	depth: float
) -> void:
	var plan := _build_layout_plan(width, depth)
	var fw: float = plan["flight_width"]
	var wall_thickness := minf(SIDE_WALL_COLLISION_THICKNESS, fw * 0.45)
	var shape_index := 0
	for seg: Dictionary in plan["segments"]:
		match int(seg["kind"]):
			SegmentKind.SEGMENT_FLIGHT:
				shape_index = _add_flight_collision_boxes(
					body, seg, wall_thickness, shape_index
				)
			SegmentKind.SEGMENT_LANDING:
				shape_index = _add_landing_collision_box(body, seg, shape_index)
			_:
				shape_index = _add_layout_specific_collision_boxes(
					body, seg, wall_thickness, shape_index
				)


func _add_layout_specific_collision_boxes(
	_body: StaticBody3D,
	_seg: Dictionary,
	_wall_thickness: float,
	shape_index: int
) -> int:
	return shape_index


func _layout_collision_shape_name(shape_index: int) -> String:
	if shape_index == 0:
		return "LayoutSideCollisionShape3D"
	return "LayoutSideCollisionShape3D_%d" % (shape_index + 1)


func _add_flight_collision_boxes(
	body: StaticBody3D,
	seg: Dictionary,
	wall_thickness: float,
	shape_index: int
) -> int:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return shape_index
	var bottom := _segment_bottom(seg)
	var tread_depth := run / float(steps)
	var thickness := minf(wall_thickness, width * 0.45)
	var seg_basis := Basis(
		Vector3(seg["width_axis"]), Vector3.UP, Vector3(seg["run_axis"])
	)
	for step_index in range(steps):
		var z_center := tread_depth * (float(step_index) + 0.5)
		var top := rise * float(step_index + 1)
		var box_height := top - bottom
		var y_center := bottom + box_height * 0.5
		_add_side_wall_collision_shape(
			body,
			_layout_collision_shape_name(shape_index),
			_segment_point(seg, Vector3(thickness * 0.5, y_center, z_center)),
			Vector3(thickness, box_height, tread_depth),
			seg_basis
		)
		shape_index += 1
		_add_side_wall_collision_shape(
			body,
			_layout_collision_shape_name(shape_index),
			_segment_point(seg, Vector3(width - thickness * 0.5, y_center, z_center)),
			Vector3(thickness, box_height, tread_depth),
			seg_basis
		)
		shape_index += 1
	return shape_index


func _add_landing_collision_box(
	body: StaticBody3D,
	seg: Dictionary,
	shape_index: int
) -> int:
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return shape_index
	var bottom := _landing_bottom(seg)
	var box_height := -bottom
	if box_height <= 0.001:
		return shape_index
	var seg_basis := Basis(
		Vector3(seg["width_axis"]), Vector3.UP, Vector3(seg["run_axis"])
	)
	_add_side_wall_collision_shape(
		body,
		_layout_collision_shape_name(shape_index),
		_segment_point(seg, Vector3(width * 0.5, bottom * 0.5, run * 0.5)),
		Vector3(width, box_height, run),
		seg_basis
	)
	return shape_index + 1
