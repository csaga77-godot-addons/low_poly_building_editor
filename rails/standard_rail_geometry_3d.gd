@tool
extends RefCounted

enum RailStyle {
	VERTICAL,
	HORIZONTAL,
	GLASS_PANEL,
}

# Translucent tint applied to glass-panel infill vertices. The caller's
# material must enable alpha transparency for the panel to render see-through.
const GLASS_PANEL_COLOR := Color(0.68, 0.84, 0.9, 0.42)

# Shared post-and-bar rail geometry used by the standalone Rail3D tool and by
# Stairs3D's optional side rails. Geometry is authored in a canonical local
# frame -- u (run distance along the rail), h (height), s (side/thickness
# offset) -- and embedded into the caller's own space through explicit
# run/up/side axes plus a linear height "rise" applied across the run. Rise
# 0.0 reproduces a level standard rail; a nonzero rise produces a raked rail
# following a sloped run (for example, alongside a stairs footprint), with
# optional horizontal end sections for newels, without duplicating the
# post/bar assembly logic per caller.
#
# The rise is applied as a shear (each vertex's height gains `rise * u /
# length` before the run/up/side axes are combined), so every authored box
# face stays planar regardless of rise; exact face normals are recomputed
# from the embedded geometry rather than assumed, so lighting stays correct
# for both the level and sloped cases.
#
# Posts are the exception: each post is appended as a genuinely upright
# prism whose bottom edge plane stays flat instead of tilting with the run's
# rise. By default a post's flat base height follows the same rise/length
# diagonal as the bars (matching a level rail's ground plane when rise is
# 0.0); callers supply an explicit `post_base_heights` entry per post so
# newels can land on their structural surface while infills land on a
# lower-rail top or caller-specific fallback surface. Each
# regular post's top edge follows the raked handrail underside across its
# footprint. Callers may instead supply a flat top height for a newel beneath
# a horizontal handrail end section. Every handrail underside segment is
# partitioned around matching post openings, so each post/handrail boundary
# occupies the same positions without overlapping internal faces. The post's
# enclosed top and hidden bottom caps are omitted; its side faces terminate
# on that welded boundary and at the authored base plane.
#
# Every face's winding is chosen so its geometric winding normal is
# antiparallel to its stored vertex normal (Godot's front-face convention),
# but that pairing only holds as authored for a right-handed (positive
# orientation) run/up/side triple like Rail3D's own RIGHT/UP/BACK axes. A
# caller supplying a mirrored triple -- Stairs3D swaps two axes to use
# BACK/UP/RIGHT -- gets geometry with the opposite handedness, so the
# winding is reversed per quad whenever `run_axis.cross(up_axis).dot(
# side_axis)` is negative, keeping the actually-visible (non-culled) face
# on the same side as the stored normal regardless of axis permutation.


static func post_count_for_length(length: float, spacing: float) -> int:
	if length <= 0.001:
		return 0
	return maxi(ceili(length / maxf(spacing, 0.1)) + 1, 2)


static func distribute_post_ratios(length: float, spacing: float) -> PackedFloat32Array:
	var ratios := PackedFloat32Array()
	var count := post_count_for_length(length, spacing)
	if count <= 0:
		return ratios
	for post_index in range(count):
		ratios.append(float(post_index) / float(count - 1))
	return ratios


static func append_rail(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	rail_height: float,
	post_spacing: float,
	post_thickness: float,
	rail_thickness: float,
	lower_rail_height: float,
	color: Color,
	post_positions: PackedFloat32Array = PackedFloat32Array(),
	post_base_heights: PackedFloat32Array = PackedFloat32Array(),
	post_thicknesses: PackedFloat32Array = PackedFloat32Array(),
	post_top_heights: PackedFloat32Array = PackedFloat32Array(),
	lower_horizontal_end: float = -INF,
	upper_horizontal_start: float = INF,
	minimum_run_override: float = NAN,
	maximum_run_override: float = NAN,
	rail_style: int = RailStyle.VERTICAL,
	horizontal_infill_count: int = 2,
	post_base_follows_rise: PackedByteArray = PackedByteArray(),
	distribute_default_posts: bool = true,
	append_continuous_members: bool = true
) -> void:
	if length <= 0.001:
		return

	var height := maxf(rail_height, 0.2)
	var post_size := maxf(post_thickness, 0.02)
	var bar_size := minf(maxf(rail_thickness, 0.02), height * 0.5)
	var top_bottom := maxf(height - bar_size, 0.0)

	var positions := post_positions
	if positions.is_empty() and distribute_default_posts:
		# Callers that own their complete post layout (for example stair
		# transition legs whose only posts are shared with adjacent runs) pass
		# false so an intentionally empty list stays post-free instead of
		# seeding spacing-distributed posts at the run ends.
		for ratio in distribute_post_ratios(length, post_spacing):
			positions.append(length * ratio)

	var bar_minimum_run := -post_size * 0.5
	var bar_maximum_run := length + post_size * 0.5
	for index in range(positions.size()):
		var current_post_size := _post_size_at(index, post_size, post_thicknesses)
		bar_minimum_run = minf(
			bar_minimum_run,
			positions[index] - current_post_size * 0.5
		)
		bar_maximum_run = maxf(
			bar_maximum_run,
			positions[index] + current_post_size * 0.5
		)
	if !is_nan(minimum_run_override):
		bar_minimum_run = minimum_run_override
	if !is_nan(maximum_run_override):
		bar_maximum_run = maximum_run_override

	if append_continuous_members:
		_append_handrail_segments(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise,
			bar_minimum_run, bar_maximum_run, top_bottom, height, bar_size,
			color, positions, post_size, post_thicknesses,
			lower_horizontal_end, upper_horizontal_start
		)

	var normalized_style := clampi(
		rail_style,
		RailStyle.VERTICAL,
		RailStyle.GLASS_PANEL
	)
	var lower_center := lower_rail_top_height(
		rail_height,
		rail_thickness,
		lower_rail_height
	) - bar_size * 0.5
	var has_base_rail := has_lower_rail(
		rail_height,
		rail_thickness,
		lower_rail_height
	)
	if append_continuous_members and has_base_rail:
		_append_sheared_box(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise,
			Vector3(bar_minimum_run, lower_center - bar_size * 0.5, -bar_size * 0.5),
			Vector3(bar_maximum_run, lower_center + bar_size * 0.5, bar_size * 0.5),
			color
		)
	var infill_bottom := lower_center + bar_size * 0.5 if has_base_rail else 0.0
	if append_continuous_members and normalized_style == RailStyle.HORIZONTAL:
		var infill_count := clampi(horizontal_infill_count, 0, 64)
		# Horizontal infill never exceeds the handrail cross-section or the
		# clear height between base rail and handrail.
		var infill_size := minf(
			minf(post_size, bar_size),
			maxf(top_bottom - infill_bottom, 0.02)
		)
		var infill_clear_height := (
			top_bottom
			- infill_bottom
			- infill_size * infill_count
		)
		if infill_count > 0 and infill_clear_height >= 0.0:
			var clear_gap := infill_clear_height / float(infill_count + 1)
			for infill_index in range(infill_count):
				var infill_center := (
					infill_bottom
					+ clear_gap * float(infill_index + 1)
					+ infill_size * (float(infill_index) + 0.5)
				)
				_append_sheared_box(
					vertices, normals, colors, indices,
					origin, run_axis, up_axis, side_axis, length, rise,
					Vector3(
						bar_minimum_run,
						infill_center - infill_size * 0.5,
						-infill_size * 0.5
					),
					Vector3(
						bar_maximum_run,
						infill_center + infill_size * 0.5,
						infill_size * 0.5
					),
					color
				)
	elif append_continuous_members and normalized_style == RailStyle.GLASS_PANEL:
		var panel_thickness := maxf(minf(bar_size, post_size) * 0.5, 0.02)
		if top_bottom - infill_bottom > 0.001:
			_append_sheared_box(
				vertices, normals, colors, indices,
				origin, run_axis, up_axis, side_axis, length, rise,
				Vector3(bar_minimum_run, infill_bottom, -panel_thickness * 0.5),
				Vector3(bar_maximum_run, top_bottom, panel_thickness * 0.5),
				GLASS_PANEL_COLOR
			)

	for index in range(positions.size()):
		var u := positions[index]
		var current_post_size := _post_size_at(index, post_size, post_thicknesses)
		var base_height := 0.0
		if index < post_base_heights.size():
			base_height = post_base_heights[index]
		elif length > 0.001:
			base_height = rise * (u / length)
		var flat_top_height := NAN
		if index < post_top_heights.size():
			flat_top_height = post_top_heights[index]
		var follow_rise_at_base := (
			index < post_base_follows_rise.size()
			and post_base_follows_rise[index] != 0
		)
		_append_upright_post_welded_to_handrail(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise,
			u, base_height, top_bottom, current_post_size, color,
			flat_top_height,
			follow_rise_at_base
		)


static func tread_mid_post_positions(length: float, step_count: int) -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	var steps := maxi(step_count, 1)
	if length <= 0.001:
		return positions
	var tread_depth := length / float(steps)
	for step_index in range(steps):
		positions.append(tread_depth * (float(step_index) + 0.5))
	return positions


static func tread_mid_post_base_heights(rise: float, step_count: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var steps := maxi(step_count, 1)
	var rise_per_step := rise / float(steps)
	for step_index in range(steps):
		# Each post sits at the mid-depth of its tread (see
		# tread_mid_post_positions()), but its base must rest on that
		# tread's actual flat top -- the step *after* it, not the smooth
		# rise/length diagonal a mid-run position would otherwise imply.
		heights.append(rise_per_step * float(step_index + 1))
	return heights


static func apply_infill_count_between_newels(
	positions: PackedFloat32Array,
	base_heights: PackedFloat32Array,
	thicknesses: PackedFloat32Array,
	newel_flags: PackedByteArray,
	infill_count: int,
	regular_size: float
) -> Dictionary:
	var counted_positions := PackedFloat32Array()
	var counted_base_heights := PackedFloat32Array()
	var counted_thicknesses := PackedFloat32Array()
	var counted_newel_flags := PackedByteArray()
	var safe_count := maxi(infill_count, 0)
	var safe_regular_size := maxf(regular_size, 0.02)
	var index := 0
	while index < positions.size():
		counted_positions.append(positions[index])
		counted_base_heights.append(base_heights[index])
		counted_thicknesses.append(thicknesses[index])
		counted_newel_flags.append(newel_flags[index])
		if newel_flags[index] != 0:
			var next_newel_index := -1
			for candidate_index in range(index + 1, positions.size()):
				if newel_flags[candidate_index] != 0:
					next_newel_index = candidate_index
					break
			if next_newel_index >= 0:
				for infill_index in range(safe_count):
					var ratio := (
						float(infill_index + 1)
						/ float(safe_count + 1)
					)
					counted_positions.append(lerpf(
						positions[index],
						positions[next_newel_index],
						ratio
					))
					counted_base_heights.append(0.0)
					counted_thicknesses.append(safe_regular_size)
					counted_newel_flags.append(0)
				index = next_newel_index
				continue
		index += 1
	return {
		"positions": counted_positions,
		"base_heights": counted_base_heights,
		"thicknesses": counted_thicknesses,
		"newel_flags": counted_newel_flags,
	}


static func redistribute_infills_between_newels(
	positions: PackedFloat32Array,
	thicknesses: PackedFloat32Array,
	newel_flags: PackedByteArray
) -> void:
	var previous_newel_index := -1
	for index in range(positions.size()):
		if newel_flags[index] == 0:
			continue
		if previous_newel_index >= 0 and index - previous_newel_index > 1:
			var clear_start := (
				positions[previous_newel_index]
				+ thicknesses[previous_newel_index] * 0.5
			)
			var clear_end := positions[index] - thicknesses[index] * 0.5
			var infill_width_total := 0.0
			for infill_index in range(previous_newel_index + 1, index):
				infill_width_total += thicknesses[infill_index]
			var infill_count := index - previous_newel_index - 1
			var clear_gap := maxf(
				(clear_end - clear_start - infill_width_total)
				/ float(infill_count + 1),
				0.0
			)
			var cursor := clear_start + clear_gap
			for infill_index in range(previous_newel_index + 1, index):
				var infill_width := thicknesses[infill_index]
				positions[infill_index] = cursor + infill_width * 0.5
				cursor += infill_width + clear_gap
		previous_newel_index = index


static func has_lower_rail(
	rail_height: float,
	rail_thickness: float,
	lower_rail_height: float
) -> bool:
	var height := maxf(rail_height, 0.2)
	var bar_size := minf(maxf(rail_thickness, 0.02), height * 0.5)
	var handrail_bottom := height - bar_size
	var lower_center := clampf(
		lower_rail_height,
		bar_size * 0.5,
		handrail_bottom - bar_size * 0.5
	)
	return (
		lower_rail_height > 0.0001
		and handrail_bottom > bar_size
		and lower_center + bar_size * 0.5 < handrail_bottom - 0.001
	)


static func lower_rail_top_height(
	rail_height: float,
	rail_thickness: float,
	lower_rail_height: float
) -> float:
	var height := maxf(rail_height, 0.2)
	var bar_size := minf(maxf(rail_thickness, 0.02), height * 0.5)
	var handrail_bottom := height - bar_size
	var lower_center := clampf(
		lower_rail_height,
		bar_size * 0.5,
		handrail_bottom - bar_size * 0.5
	)
	return lower_center + bar_size * 0.5


static func _post_size_at(
	index: int,
	default_size: float,
	post_thicknesses: PackedFloat32Array
) -> float:
	if index >= 0 and index < post_thicknesses.size():
		return maxf(post_thicknesses[index], 0.02)
	return default_size


static func _embed(
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	local_point: Vector3
) -> Vector3:
	var sheared_height := local_point.y
	if length > 0.001:
		sheared_height += rise * (local_point.x / length)
	return (
		origin
		+ run_axis * local_point.x
		+ up_axis * sheared_height
		+ side_axis * local_point.z
	)


static func _append_sheared_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	minimum: Vector3,
	maximum: Vector3,
	color: Color,
	include_top_face: bool = true,
	include_bottom_face: bool = true,
	include_minimum_run_face: bool = true,
	include_maximum_run_face: bool = true
) -> void:
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3.FORWARD
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3.BACK
	)
	if include_minimum_run_face:
		_append_sheared_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3.LEFT
		)
	if include_maximum_run_face:
		_append_sheared_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
			Vector3.RIGHT
		)
	if include_top_face:
		_append_sheared_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3.UP
		)
	if include_bottom_face:
		_append_sheared_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3.DOWN
		)


static func _append_handrail_segments(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	minimum_run: float,
	maximum_run: float,
	bottom_height: float,
	top_height: float,
	bar_size: float,
	color: Color,
	post_positions: PackedFloat32Array,
	default_post_size: float,
	post_thicknesses: PackedFloat32Array,
	lower_horizontal_end: float,
	upper_horizontal_start: float
) -> void:
	var raked_start := minimum_run
	var raked_end := maximum_run
	if lower_horizontal_end > minimum_run + 0.001:
		raked_start = clampf(lower_horizontal_end, minimum_run, maximum_run)
	if upper_horizontal_start < maximum_run - 0.001:
		raked_end = clampf(upper_horizontal_start, minimum_run, maximum_run)
	if raked_start > raked_end:
		var shared_transition := (raked_start + raked_end) * 0.5
		raked_start = shared_transition
		raked_end = shared_transition

	var has_lower_horizontal := raked_start > minimum_run + 0.001
	var has_raked := raked_end > raked_start + 0.001
	var has_upper_horizontal := maximum_run > raked_end + 0.001
	var half_bar := bar_size * 0.5

	if has_lower_horizontal:
		var anchor_rise := rise * (raked_start / length) if length > 0.001 else 0.0
		_append_sheared_bar_with_bottom_openings(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, 0.0,
			Vector3(minimum_run, bottom_height + anchor_rise, -half_bar),
			Vector3(raked_start, top_height + anchor_rise, half_bar),
			color, post_positions, default_post_size, post_thicknesses,
			true, !has_raked and !has_upper_horizontal
		)

	if has_raked:
		_append_sheared_bar_with_bottom_openings(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise,
			Vector3(raked_start, bottom_height, -half_bar),
			Vector3(raked_end, top_height, half_bar),
			color, post_positions, default_post_size, post_thicknesses,
			!has_lower_horizontal, !has_upper_horizontal
		)

	if has_upper_horizontal:
		var anchor_rise := rise * (raked_end / length) if length > 0.001 else 0.0
		_append_sheared_bar_with_bottom_openings(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, 0.0,
			Vector3(raked_end, bottom_height + anchor_rise, -half_bar),
			Vector3(maximum_run, top_height + anchor_rise, half_bar),
			color, post_positions, default_post_size, post_thicknesses,
			!has_lower_horizontal and !has_raked, true
		)

	# No optional horizontal section: retain the original continuous raked bar.
	if !has_lower_horizontal and !has_raked and !has_upper_horizontal:
		_append_sheared_bar_with_bottom_openings(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise,
			Vector3(minimum_run, bottom_height, -half_bar),
			Vector3(maximum_run, top_height, half_bar),
			color, post_positions, default_post_size, post_thicknesses
		)


static func _append_sheared_bar_with_bottom_openings(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	minimum: Vector3,
	maximum: Vector3,
	color: Color,
	post_positions: PackedFloat32Array,
	default_post_size: float,
	post_thicknesses: PackedFloat32Array,
	include_minimum_run_face: bool = true,
	include_maximum_run_face: bool = true
) -> void:
	_append_sheared_box(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise,
		minimum, maximum, color, true, false,
		include_minimum_run_face, include_maximum_run_face
	)

	if post_positions.is_empty():
		_append_sheared_bottom_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			minimum.x, maximum.x, minimum.y, minimum.z, maximum.z
		)
		return

	# Build a small planar grid from every post boundary. This supports larger
	# newel posts alongside regular posts while keeping all hole edges aligned
	# with the matching post edges and avoiding underside T-junctions.
	var holes: Array[Rect2] = []
	var run_cuts: Array[float] = [minimum.x, maximum.x]
	var side_cuts: Array[float] = [minimum.z, maximum.z]
	for index in range(post_positions.size()):
		var post_size := _post_size_at(index, default_post_size, post_thicknesses)
		var hole_start := maxf(minimum.x, post_positions[index] - post_size * 0.5)
		var hole_end := minf(maximum.x, post_positions[index] + post_size * 0.5)
		var hole_min_side := maxf(minimum.z, -post_size * 0.5)
		var hole_max_side := minf(maximum.z, post_size * 0.5)
		if hole_end - hole_start <= 0.001 or hole_max_side - hole_min_side <= 0.001:
			continue
		holes.append(Rect2(
			Vector2(hole_start, hole_min_side),
			Vector2(hole_end - hole_start, hole_max_side - hole_min_side)
		))
		_append_unique_cut(run_cuts, hole_start)
		_append_unique_cut(run_cuts, hole_end)
		_append_unique_cut(side_cuts, hole_min_side)
		_append_unique_cut(side_cuts, hole_max_side)
	run_cuts.sort()
	side_cuts.sort()

	for run_index in range(run_cuts.size() - 1):
		var minimum_run := run_cuts[run_index]
		var maximum_run := run_cuts[run_index + 1]
		if maximum_run - minimum_run <= 0.001:
			continue
		for side_index in range(side_cuts.size() - 1):
			var minimum_side := side_cuts[side_index]
			var maximum_side := side_cuts[side_index + 1]
			if maximum_side - minimum_side <= 0.001:
				continue
			var center := Vector2(
				(minimum_run + maximum_run) * 0.5,
				(minimum_side + maximum_side) * 0.5
			)
			var inside_post := false
			for hole in holes:
				if hole.has_point(center):
					inside_post = true
					break
			if inside_post:
				continue
			_append_sheared_bottom_quad(
				vertices, normals, colors, indices,
				origin, run_axis, up_axis, side_axis, length, rise, color,
				minimum_run, maximum_run, minimum.y, minimum_side, maximum_side
			)


static func _append_unique_cut(cuts: Array[float], value: float) -> void:
	for existing in cuts:
		if absf(existing - value) <= 0.001:
			return
	cuts.append(value)


static func _append_sheared_bottom_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	color: Color,
	minimum_run: float,
	maximum_run: float,
	height: float,
	minimum_side: float,
	maximum_side: float
) -> void:
	if maximum_run - minimum_run <= 0.001 or maximum_side - minimum_side <= 0.001:
		return
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(minimum_run, height, minimum_side),
		Vector3(minimum_run, height, maximum_side),
		Vector3(maximum_run, height, maximum_side),
		Vector3(maximum_run, height, minimum_side),
		Vector3.DOWN
	)


static func _append_upright_post_welded_to_handrail(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	position: float,
	base_height: float,
	handrail_bottom: float,
	post_size: float,
	color: Color,
	flat_top_height: float = NAN,
	follow_rise_at_base: bool = false
) -> void:
	var minimum_run := position - post_size * 0.5
	var maximum_run := position + post_size * 0.5
	var minimum_side := -post_size * 0.5
	var maximum_side := post_size * 0.5
	var minimum_top := handrail_bottom
	var maximum_top := handrail_bottom
	if !is_nan(flat_top_height):
		minimum_top = flat_top_height
		maximum_top = flat_top_height
	elif length > 0.001:
		minimum_top += rise * (minimum_run / length)
		maximum_top += rise * (maximum_run / length)

	# `base_height` is authored at the post's center position. A flat-based
	# post keeps every bottom corner on that plane; a rise-following base
	# (an infill standing on a raked base rail) shears each bottom corner
	# onto the sloped surface so no corner floats above or sinks into it.
	var minimum_base := base_height
	var maximum_base := base_height
	if follow_rise_at_base and length > 0.001:
		minimum_base += rise * ((minimum_run - position) / length)
		maximum_base += rise * ((maximum_run - position) / length)

	# Use zero shear for the post itself: only its top boundary follows the
	# handrail plane, while the bottom corners stay on the authored base
	# plane (flat or rise-following per the flag above).
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, 0.0, color,
		Vector3(minimum_run, minimum_base, minimum_side),
		Vector3(maximum_run, maximum_base, minimum_side),
		Vector3(maximum_run, maximum_top, minimum_side),
		Vector3(minimum_run, minimum_top, minimum_side),
		Vector3.FORWARD
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, 0.0, color,
		Vector3(minimum_run, minimum_base, maximum_side),
		Vector3(minimum_run, minimum_top, maximum_side),
		Vector3(maximum_run, maximum_top, maximum_side),
		Vector3(maximum_run, maximum_base, maximum_side),
		Vector3.BACK
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, 0.0, color,
		Vector3(minimum_run, minimum_base, minimum_side),
		Vector3(minimum_run, minimum_top, minimum_side),
		Vector3(minimum_run, minimum_top, maximum_side),
		Vector3(minimum_run, minimum_base, maximum_side),
		Vector3.LEFT
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, 0.0, color,
		Vector3(maximum_run, maximum_base, minimum_side),
		Vector3(maximum_run, maximum_base, maximum_side),
		Vector3(maximum_run, maximum_top, maximum_side),
		Vector3(maximum_run, maximum_top, minimum_side),
		Vector3.RIGHT
	)


static func _append_sheared_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	color: Color,
	local_a: Vector3,
	local_b: Vector3,
	local_c: Vector3,
	local_d: Vector3,
	reference_normal: Vector3
) -> void:
	var a := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_a)
	var b := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_b)
	var c := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_c)
	var d := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_d)

	var geometric_normal := (b - a).cross(c - a)
	if geometric_normal.length_squared() <= 0.000001:
		geometric_normal = (c - a).cross(d - a)
	geometric_normal = geometric_normal.normalized()

	var reference_direction := (
		run_axis * reference_normal.x
		+ up_axis * reference_normal.y
		+ side_axis * reference_normal.z
	).normalized()

	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	var use_normal := geometric_normal if geometric_normal.dot(reference_direction) >= 0.0 else -geometric_normal
	for _index in range(4):
		normals.append(use_normal)
		colors.append(color)
	# The winding below is tuned for a right-handed (positive-orientation)
	# run/up/side triple, matching Rail3D's own RIGHT/UP/BACK axes. Stairs3D
	# passes BACK/UP/RIGHT -- an axis swap, which mirrors the triple
	# (negative orientation) -- so the same vertex order would be
	# backface-culled from the wrong side. Reversing the winding whenever
	# the supplied axes are mirrored keeps the visible (culled-in) face on
	# the same side as `use_normal` regardless of which axis permutation
	# the caller supplies.
	if run_axis.cross(up_axis).dot(side_axis) < 0.0:
		indices.append_array(PackedInt32Array([base, base + 3, base + 2, base, base + 2, base + 1]))
	else:
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
