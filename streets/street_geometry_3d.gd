@tool
class_name StreetGeometry3D
extends RefCounted

const EPSILON := 0.00001
const MAX_MITER_SCALE := 3.0


static func build(profile: PackedVector3Array, settings: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var result := {
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices,
		"stair_segment_count": 0,
		"step_count": 0,
		"intersection_cut_count": 0,
		"road_surface_cut_count": 0,
	}
	if profile.size() < 2:
		return result

	var road_half_width := maxf(float(settings.get("road_width", 3.2)) * 0.5, 0.05)
	var kerb_width := maxf(float(settings.get("kerb_width", 0.18)), 0.0)
	var footpath_width := maxf(float(settings.get("footpath_width", 1.1)), 0.0)
	var left_kerb_width := maxf(float(settings.get("left_kerb_width", kerb_width)), 0.0)
	var right_kerb_width := maxf(float(settings.get("right_kerb_width", kerb_width)), 0.0)
	var left_footpath_width := maxf(
		float(settings.get("left_footpath_width", footpath_width)), 0.0
	)
	var right_footpath_width := maxf(
		float(settings.get("right_footpath_width", footpath_width)), 0.0
	)
	var road_thickness := maxf(float(settings.get("road_thickness", 0.18)), 0.01)
	var kerb_height := maxf(float(settings.get("kerb_height", 0.14)), 0.01)
	var footpath_thickness := maxf(float(settings.get("footpath_thickness", 0.16)), 0.01)
	var road_color := Color(settings.get("road_color", Color(0.38, 0.37, 0.34, 1.0)))
	var kerb_color := Color(settings.get("kerb_color", Color(0.66, 0.64, 0.59, 1.0)))
	var footpath_color := Color(settings.get("footpath_color", Color(0.72, 0.67, 0.57, 1.0)))
	var intersection_cuts: Array = settings.get("intersection_cuts", [])
	result["intersection_cut_count"] = intersection_cuts.size()
	for cut: Dictionary in intersection_cuts:
		if bool(cut.get("clip_road", false)):
			result["road_surface_cut_count"] = int(result["road_surface_cut_count"]) + 1

	var road_left := _build_offset_polyline(profile, road_half_width)
	var road_right := _build_offset_polyline(profile, -road_half_width)
	var kerb_left := _build_offset_polyline(profile, road_half_width + left_kerb_width)
	var kerb_right := _build_offset_polyline(profile, -road_half_width - right_kerb_width)
	var foot_left := _build_offset_polyline(
		profile, road_half_width + left_kerb_width + left_footpath_width
	)
	var foot_right := _build_offset_polyline(
		profile, -road_half_width - right_kerb_width - right_footpath_width
	)

	# Snap each participating terminal cross-section onto its canonical junction,
	# then retreat its sides onto the shared corners so the road edge, kerb, and
	# footpath meet their neighbours. The road band is pulled back to the junction
	# boundary here; the centre wedge below fills the remaining gap.
	var side_end_overrides: Dictionary = settings.get("side_end_overrides", {})
	var start_side: Dictionary = side_end_overrides.get("start", {})
	var end_side: Dictionary = side_end_overrides.get("end", {})
	var last_index := profile.size() - 1
	var start_junction := profile[0]
	var end_junction := profile[last_index]
	# Applied inline (not via a helper) so the writes land on these local packed
	# arrays; passing packed arrays into a mutating helper is copy-on-write unsafe.
	var external_junction_surfaces := bool(settings.get("external_junction_surfaces", false))
	if !start_side.is_empty() and !external_junction_surfaces:
		if start_side.has("junction"):
			start_junction = start_side["junction"]
			var start_delta := start_junction - profile[0]
			road_left[0] += start_delta
			road_right[0] += start_delta
			kerb_left[0] += start_delta
			kerb_right[0] += start_delta
			foot_left[0] += start_delta
			foot_right[0] += start_delta
		if start_side.has("left_road"):
			road_left[0] = _override_terminal(road_left[0], start_side["left_road"])
		if start_side.has("right_road"):
			road_right[0] = _override_terminal(road_right[0], start_side["right_road"])
		if start_side.has("left_kerb"):
			kerb_left[0] = _override_terminal(kerb_left[0], start_side["left_kerb"])
		if start_side.has("right_kerb"):
			kerb_right[0] = _override_terminal(kerb_right[0], start_side["right_kerb"])
		if start_side.has("left_foot"):
			foot_left[0] = _override_terminal(foot_left[0], start_side["left_foot"])
		if start_side.has("right_foot"):
			foot_right[0] = _override_terminal(foot_right[0], start_side["right_foot"])
	if !end_side.is_empty() and last_index > 0 and !external_junction_surfaces:
		if end_side.has("junction"):
			end_junction = end_side["junction"]
			var end_delta := end_junction - profile[last_index]
			road_left[last_index] += end_delta
			road_right[last_index] += end_delta
			kerb_left[last_index] += end_delta
			kerb_right[last_index] += end_delta
			foot_left[last_index] += end_delta
			foot_right[last_index] += end_delta
		if end_side.has("left_road"):
			road_left[last_index] = _override_terminal(road_left[last_index], end_side["left_road"])
		if end_side.has("right_road"):
			road_right[last_index] = _override_terminal(road_right[last_index], end_side["right_road"])
		if end_side.has("left_kerb"):
			kerb_left[last_index] = _override_terminal(kerb_left[last_index], end_side["left_kerb"])
		if end_side.has("right_kerb"):
			kerb_right[last_index] = _override_terminal(kerb_right[last_index], end_side["right_kerb"])
		if end_side.has("left_foot"):
			foot_left[last_index] = _override_terminal(foot_left[last_index], end_side["left_foot"])
		if end_side.has("right_foot"):
			foot_right[last_index] = _override_terminal(foot_right[last_index], end_side["right_foot"])

	# Fill the junction centre: a triangle wedge from the junction point out to the
	# two retreated road corners. Adjacent arms' wedges fan around the shared point
	# and tile the intersection with no overlap or hole.
	if !start_side.is_empty():
		_append_road_wedge(
			start_junction, road_left[0], road_right[0], road_thickness, road_color,
			vertices, normals, colors, indices
		)
	if !end_side.is_empty() and last_index > 0:
		_append_road_wedge(
			end_junction, road_left[last_index], road_right[last_index],
			road_thickness, road_color, vertices, normals, colors, indices
		)

	var stair_run_by_start: Dictionary = {}
	var stair_run_members: Dictionary = {}
	for stair_run: Dictionary in plan_stair_runs(profile, settings):
		if int(stair_run.get("step_count", 0)) <= 0:
			continue
		var start_index := int(stair_run["start_index"])
		var end_index := int(stair_run["end_index"])
		stair_run_by_start[start_index] = stair_run
		for segment_index in range(start_index, end_index):
			stair_run_members[segment_index] = start_index

	for segment_index in range(profile.size() - 1):
		var a := profile[segment_index]
		var b := profile[segment_index + 1]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if run <= EPSILON:
			continue
		var side_ranges := _retained_ranges(intersection_cuts, segment_index, false)
		var road_ranges := _retained_ranges(intersection_cuts, segment_index, true)
		_append_sloped_band(
			road_left[segment_index], road_right[segment_index],
			road_left[segment_index + 1], road_right[segment_index + 1],
			road_thickness, road_color, road_ranges, side_ranges,
			vertices, normals, colors, indices
		)
		if stair_run_members.has(segment_index):
			var run_start := int(stair_run_members[segment_index])
			if run_start != segment_index:
				continue
			var stair_run: Dictionary = stair_run_by_start[run_start]
			var run_end := int(stair_run["end_index"])
			var step_count := int(stair_run["step_count"])
			result["stair_segment_count"] = int(result["stair_segment_count"]) + 1
			result["step_count"] = int(result["step_count"]) + step_count
			_append_stepped_side(
				road_left[segment_index], kerb_left[segment_index], foot_left[segment_index],
				road_left[run_end], kerb_left[run_end], foot_left[run_end],
				step_count, kerb_height, footpath_thickness, kerb_color, footpath_color,
				vertices, normals, colors, indices
			)
			_append_stepped_side(
				road_right[segment_index], kerb_right[segment_index], foot_right[segment_index],
				road_right[run_end], kerb_right[run_end], foot_right[run_end],
				step_count, kerb_height, footpath_thickness, kerb_color, footpath_color,
				vertices, normals, colors, indices
			)
		else:
			for retained_range: Vector2 in side_ranges:
				_append_sloped_side(
					road_left[segment_index].lerp(road_left[segment_index + 1], retained_range.x),
					kerb_left[segment_index].lerp(kerb_left[segment_index + 1], retained_range.x),
					foot_left[segment_index].lerp(foot_left[segment_index + 1], retained_range.x),
					road_left[segment_index].lerp(road_left[segment_index + 1], retained_range.y),
					kerb_left[segment_index].lerp(kerb_left[segment_index + 1], retained_range.y),
					foot_left[segment_index].lerp(foot_left[segment_index + 1], retained_range.y),
					kerb_height, footpath_thickness, kerb_color, footpath_color,
					vertices, normals, colors, indices
				)
				_append_sloped_side(
					road_right[segment_index].lerp(road_right[segment_index + 1], retained_range.x),
					kerb_right[segment_index].lerp(kerb_right[segment_index + 1], retained_range.x),
					foot_right[segment_index].lerp(foot_right[segment_index + 1], retained_range.x),
					road_right[segment_index].lerp(road_right[segment_index + 1], retained_range.y),
					kerb_right[segment_index].lerp(kerb_right[segment_index + 1], retained_range.y),
					foot_right[segment_index].lerp(foot_right[segment_index + 1], retained_range.y),
					kerb_height, footpath_thickness, kerb_color, footpath_color,
					vertices, normals, colors, indices
				)

	result["vertices"] = vertices
	result["normals"] = normals
	result["colors"] = colors
	result["indices"] = indices
	return result


## Groups adjacent steep samples into coherent stair runs. The entry/exit
## thresholds provide hysteresis, while minimum run length/rise suppress tiny
## terrain ripples. Runs stop at sharp plan bends so their tread interpolation
## never cuts across a street corner.
static func plan_stair_runs(
	profile: PackedVector3Array, settings: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile.size() < 2:
		return result
	var enter_threshold := clampf(
		float(settings.get("stair_threshold_degrees", 25.0)), 0.0, 89.0
	)
	var exit_threshold := clampf(
		float(settings.get("stair_exit_threshold_degrees", enter_threshold - 3.0)),
		0.0, enter_threshold
	)
	var minimum_run := maxf(float(settings.get("minimum_stair_run_length", 1.0)), 0.1)
	var minimum_rise := maxf(float(settings.get("minimum_stair_run_rise", 0.16)), 0.01)
	var target_riser := maxf(float(settings.get("target_riser_height", 0.16)), 0.02)
	var max_riser := maxf(float(settings.get("max_riser_height", 0.18)), target_riser)
	var min_tread := maxf(float(settings.get("min_tread_depth", 0.24)), 0.05)
	var segment_index := 0
	while segment_index < profile.size() - 1:
		var first_a := profile[segment_index]
		var first_b := profile[segment_index + 1]
		var first_run := Vector2(first_b.x - first_a.x, first_b.z - first_a.z).length()
		var first_rise := first_b.y - first_a.y
		var first_slope := (
			0.0 if first_run <= EPSILON else rad_to_deg(atan2(absf(first_rise), first_run))
		)
		if first_run <= EPSILON or first_slope <= enter_threshold + 0.0001:
			segment_index += 1
			continue
		var rise_sign := signf(first_rise)
		var first_direction := Vector2(
			first_b.x - first_a.x, first_b.z - first_a.z
		).normalized()
		var end_index := segment_index
		var accumulated_run := 0.0
		while end_index < profile.size() - 1:
			var a := profile[end_index]
			var b := profile[end_index + 1]
			var plan_delta := Vector2(b.x - a.x, b.z - a.z)
			var local_run := plan_delta.length()
			if local_run <= EPSILON or signf(b.y - a.y) != rise_sign:
				break
			var slope := rad_to_deg(atan2(absf(b.y - a.y), local_run))
			if end_index > segment_index and slope <= exit_threshold + 0.0001:
				break
			var direction_dot := clampf(
				first_direction.dot(plan_delta.normalized()), -1.0, 1.0
			)
			if rad_to_deg(acos(direction_dot)) > 20.0:
				break
			accumulated_run += local_run
			end_index += 1
		var accumulated_rise := absf(
			profile[end_index].y - profile[segment_index].y
		)
		if accumulated_run >= minimum_run and accumulated_rise >= minimum_rise:
			result.append({
				"start_index": segment_index,
				"end_index": end_index,
				"run": accumulated_run,
				"rise": accumulated_rise,
				"step_count": _choose_step_count(
					accumulated_rise, accumulated_run,
					target_riser, max_riser, min_tread
				),
			})
		segment_index = maxi(end_index, segment_index + 1)
	return result


static func _choose_step_count(
	rise: float,
	run: float,
	target_riser: float,
	max_riser: float,
	min_tread: float
) -> int:
	if rise <= EPSILON or run <= EPSILON:
		return 0
	var minimum_steps := ceili(rise / max_riser)
	var maximum_steps := floori(run / min_tread)
	if minimum_steps > maximum_steps or maximum_steps < 1:
		return 0
	return clampi(roundi(rise / target_riser), minimum_steps, maximum_steps)


## Junction centre fill: one triangle from the junction point out to the two
## retreated road corners, with a matching underside so the road keeps thickness.
static func _append_road_wedge(
	apex: Vector3, corner_left: Vector3, corner_right: Vector3,
	thickness: float, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	if apex.distance_to(corner_left) <= EPSILON or apex.distance_to(corner_right) <= EPSILON:
		return
	if corner_left.distance_to(corner_right) <= EPSILON:
		return
	_append_upward_triangle(apex, corner_left, corner_right, color, vertices, normals, colors, indices)
	var drop := Vector3.UP * thickness
	_append_triangle(
		apex - drop, corner_right - drop, corner_left - drop,
		color.darkened(0.08), vertices, normals, colors, indices
	)


static func _append_triangle(
	a: Vector3, b: Vector3, c: Vector3, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= EPSILON:
		return
	normal = normal.normalized()
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c]))
	for _index in range(3):
		normals.append(normal)
		colors.append(color)
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))


static func _append_upward_triangle(
	a: Vector3, b: Vector3, c: Vector3, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	if (b - a).cross(c - a).y < 0.0:
		_append_triangle(a, c, b, color, vertices, normals, colors, indices)
	else:
		_append_triangle(a, b, c, color, vertices, normals, colors, indices)


static func _override_terminal(_original: Vector3, target: Vector3) -> Vector3:
	return target


static func _build_offset_polyline(profile: PackedVector3Array, offset: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in range(profile.size()):
		var previous_direction := _plan_direction(
			profile[maxi(index - 1, 0)], profile[index if index > 0 else 1]
		)
		var next_direction := _plan_direction(
			profile[index], profile[mini(index + 1, profile.size() - 1)]
		)
		if index == 0:
			previous_direction = next_direction
		elif index == profile.size() - 1:
			next_direction = previous_direction
		var previous_normal := Vector3(-previous_direction.z, 0.0, previous_direction.x)
		var next_normal := Vector3(-next_direction.z, 0.0, next_direction.x)
		var bisector := previous_normal + next_normal
		if bisector.length_squared() <= EPSILON:
			bisector = next_normal
		bisector = bisector.normalized()
		var denominator := absf(bisector.dot(next_normal))
		var scale := 1.0 if denominator <= EPSILON else minf(1.0 / denominator, MAX_MITER_SCALE)
		result.append(profile[index] + bisector * offset * scale)
	return result


static func _plan_direction(a: Vector3, b: Vector3) -> Vector3:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return Vector3.FORWARD if delta.length_squared() <= EPSILON else delta.normalized()


static func _retained_ranges(
	intersection_cuts: Array, segment_index: int, road_surface_only: bool
) -> Array[Vector2]:
	var clipped_ranges: Array[Vector2] = []
	for cut: Dictionary in intersection_cuts:
		if int(cut.get("segment_index", -1)) != segment_index:
			continue
		if road_surface_only and !bool(cut.get("clip_road", false)):
			continue
		var start_t := clampf(float(cut.get("start_t", 0.0)), 0.0, 1.0)
		var end_t := clampf(float(cut.get("end_t", 0.0)), 0.0, 1.0)
		if end_t - start_t > EPSILON:
			clipped_ranges.append(Vector2(start_t, end_t))
	if clipped_ranges.is_empty():
		return [Vector2(0.0, 1.0)]
	clipped_ranges.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.x < second.x)
	var merged: Array[Vector2] = []
	for clipped_range: Vector2 in clipped_ranges:
		if merged.is_empty() or clipped_range.x > merged[-1].y + EPSILON:
			merged.append(clipped_range)
		else:
			var merged_range := merged[-1]
			merged_range.y = maxf(merged_range.y, clipped_range.y)
			merged[-1] = merged_range
	var retained: Array[Vector2] = []
	var cursor := 0.0
	for clipped_range: Vector2 in merged:
		if clipped_range.x > cursor + EPSILON:
			retained.append(Vector2(cursor, clipped_range.x))
		cursor = maxf(cursor, clipped_range.y)
	if cursor < 1.0 - EPSILON:
		retained.append(Vector2(cursor, 1.0))
	return retained


static func _append_sloped_band(
	a_left: Vector3, a_right: Vector3, b_left: Vector3, b_right: Vector3,
	thickness: float, color: Color,
	surface_ranges: Array[Vector2], side_ranges: Array[Vector2],
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	for retained_range: Vector2 in surface_ranges:
		var range_a_left := a_left.lerp(b_left, retained_range.x)
		var range_a_right := a_right.lerp(b_right, retained_range.x)
		var range_b_left := a_left.lerp(b_left, retained_range.y)
		var range_b_right := a_right.lerp(b_right, retained_range.y)
		_append_upward_quad(
			range_a_left, range_b_left, range_b_right, range_a_right,
			color, vertices, normals, colors, indices
		)
		_append_quad(
			range_a_right - Vector3.UP * thickness,
			range_b_right - Vector3.UP * thickness,
			range_b_left - Vector3.UP * thickness,
			range_a_left - Vector3.UP * thickness,
			color.darkened(0.08), vertices, normals, colors, indices
		)
	for retained_range: Vector2 in side_ranges:
		var range_a_left := a_left.lerp(b_left, retained_range.x)
		var range_a_right := a_right.lerp(b_right, retained_range.x)
		var range_b_left := a_left.lerp(b_left, retained_range.y)
		var range_b_right := a_right.lerp(b_right, retained_range.y)
		_append_quad(
			range_a_left - Vector3.UP * thickness,
			range_b_left - Vector3.UP * thickness,
			range_b_left, range_a_left,
			color, vertices, normals, colors, indices
		)
		_append_quad(
			range_a_right, range_b_right,
			range_b_right - Vector3.UP * thickness,
			range_a_right - Vector3.UP * thickness,
			color, vertices, normals, colors, indices
		)


static func _append_sloped_side(
	a_road: Vector3, a_kerb: Vector3, a_outer: Vector3,
	b_road: Vector3, b_kerb: Vector3, b_outer: Vector3,
	kerb_height: float, footpath_thickness: float,
	kerb_color: Color, footpath_color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	var up := Vector3.UP * kerb_height
	_append_upward_quad(a_road + up, b_road + up, b_kerb + up, a_kerb + up, kerb_color, vertices, normals, colors, indices)
	_append_quad(a_road, b_road, b_road + up, a_road + up, kerb_color, vertices, normals, colors, indices)
	_append_upward_quad(a_kerb + up, b_kerb + up, b_outer + up, a_outer + up, footpath_color, vertices, normals, colors, indices)
	_append_quad(
		a_outer + up, b_outer + up,
		b_outer + up - Vector3.UP * footpath_thickness,
		a_outer + up - Vector3.UP * footpath_thickness,
		footpath_color.darkened(0.08), vertices, normals, colors, indices
	)


static func _append_stepped_side(
	a_road: Vector3, a_kerb: Vector3, a_outer: Vector3,
	b_road: Vector3, b_kerb: Vector3, b_outer: Vector3,
	step_count: int, kerb_height: float, footpath_thickness: float,
	kerb_color: Color, footpath_color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	if a_road.y > b_road.y:
		var swap_road := a_road
		a_road = b_road
		b_road = swap_road
		var swap_kerb := a_kerb
		a_kerb = b_kerb
		b_kerb = swap_kerb
		var swap_outer := a_outer
		a_outer = b_outer
		b_outer = swap_outer
	for step_index in range(step_count):
		var t0 := float(step_index) / float(step_count)
		var t1 := float(step_index + 1) / float(step_count)
		var top_y := lerpf(a_road.y, b_road.y, float(step_index + 1) / float(step_count)) + kerb_height
		var road0 := a_road.lerp(b_road, t0)
		var road1 := a_road.lerp(b_road, t1)
		var kerb0 := a_kerb.lerp(b_kerb, t0)
		var kerb1 := a_kerb.lerp(b_kerb, t1)
		var outer0 := a_outer.lerp(b_outer, t0)
		var outer1 := a_outer.lerp(b_outer, t1)
		road0.y = top_y
		road1.y = top_y
		kerb0.y = top_y
		kerb1.y = top_y
		outer0.y = top_y
		outer1.y = top_y
		_append_upward_quad(road0, road1, kerb1, kerb0, kerb_color, vertices, normals, colors, indices)
		_append_upward_quad(kerb0, kerb1, outer1, outer0, footpath_color, vertices, normals, colors, indices)
		var road_base0 := a_road.lerp(b_road, t0)
		var road_base1 := a_road.lerp(b_road, t1)
		_append_quad(road_base0, road_base1, road1, road0, kerb_color, vertices, normals, colors, indices)
		_append_quad(
			outer0, outer1,
			outer1 - Vector3.UP * footpath_thickness,
			outer0 - Vector3.UP * footpath_thickness,
			footpath_color.darkened(0.08), vertices, normals, colors, indices
		)
		if step_index == 0:
			_append_quad(
				road0 - Vector3.UP * footpath_thickness,
				road0, outer0, outer0 - Vector3.UP * footpath_thickness,
				footpath_color.darkened(0.05), vertices, normals, colors, indices
			)
		else:
			var lower_top := top_y - absf(b_road.y - a_road.y) / float(step_count)
			var lower_road := road0
			var lower_outer := outer0
			lower_road.y = lower_top
			lower_outer.y = lower_top
			_append_quad(lower_road, road0, outer0, lower_outer, footpath_color.darkened(0.05), vertices, normals, colors, indices)


static func _append_quad(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() <= EPSILON:
		return
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	for _index in range(4):
		normals.append(normal)
		colors.append(color)
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


static func _append_upward_quad(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	if (b - a).cross(c - a).y < 0.0:
		_append_quad(a, d, c, b, color, vertices, normals, colors, indices)
	else:
		_append_quad(a, b, c, d, color, vertices, normals, colors, indices)
