@tool
class_name StreetGeometryResolver
extends RefCounted

const EPSILON := 0.0001
const MIN_CROSS_ANGLE_SINE := 0.05
const VERTICAL_TOLERANCE := 0.02
## Endpoints closer than this in plan share a junction and get mitered together.
const JOIN_TOLERANCE := 0.05
## Keep endpoint joins within the same bounded-miter envelope as ordinary bends.
const MAX_END_MITER_SCALE := 3.0

var m_streets: Array[Street3D] = []
var m_resolve_midspan_crossings := true


func _init(streets: Array, resolve_midspan_crossings := true) -> void:
	m_resolve_midspan_crossings = resolve_midspan_crossings
	for street: Variant in streets:
		if street is Street3D:
			m_streets.append(street)


func refresh_street_intersection_cuts() -> void:
	var cuts_by_street: Dictionary = {}
	var profiles: Array[PackedVector3Array] = []
	var profile_bounds: Array[Rect2] = []
	for street: Street3D in m_streets:
		cuts_by_street[street] = []
		var profile := street.get_geometry_profile()
		profiles.append(profile)
		profile_bounds.append(_profile_plan_bounds(profile))
	if m_resolve_midspan_crossings:
		for first_index in range(m_streets.size()):
			var first := m_streets[first_index]
			var first_profile := profiles[first_index]
			for second_index in range(first_index + 1, m_streets.size()):
				var second := m_streets[second_index]
				if !profile_bounds[first_index].intersects(
					profile_bounds[second_index], true
				):
					continue
				var second_profile := profiles[second_index]
				_append_pair_cuts(first, first_profile, second, second_profile, cuts_by_street)
	var joins_by_street := _compute_end_joins(profiles)
	for street: Street3D in m_streets:
		street.set_intersection_geometry(
			cuts_by_street.get(street, []), joins_by_street.get(street, {})
		)


## Groups coincident street endpoints into junctions and, for each pair of
## angularly adjacent arms, extends their touching road/kerb/footpath edges onto
## a shared miter corner so the kerbs and footpaths connect across the junction.
func _compute_end_joins(profiles: Array[PackedVector3Array]) -> Dictionary:
	var ends: Array[Dictionary] = []
	for street_index in range(m_streets.size()):
		var street := m_streets[street_index]
		var profile := profiles[street_index]
		if profile.size() < 2:
			continue
		ends.append({
			"street": street, "is_start": true,
			"point": profile[0], "dir": _plan_dir(profile[0], profile[1]),
		})
		var last := profile.size() - 1
		ends.append({
			"street": street, "is_start": false,
			"point": profile[last], "dir": _plan_dir(profile[last], profile[last - 1]),
		})

	var result: Dictionary = {}
	var claimed := PackedByteArray()
	claimed.resize(ends.size())
	for i in range(ends.size()):
		if claimed[i] != 0:
			continue
		var group: Array[Dictionary] = [ends[i]]
		claimed[i] = 1
		for j in range(i + 1, ends.size()):
			if claimed[j] != 0:
				continue
			if _points_coincide(ends[i]["point"], ends[j]["point"]):
				group.append(ends[j])
				claimed[j] = 1
		if group.size() < 2:
			continue
		var junction := _canonical_junction(group)
		for group_index in range(group.size()):
			var group_arm := group[group_index]
			group_arm["junction"] = junction
			group[group_index] = group_arm
			_assign_junction(result, group_arm, junction)
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _heading(a["dir"]) < _heading(b["dir"])
		)
		var count := group.size()
		for arm_index in range(count):
			var arm := group[arm_index]
			var next_arm := group[(arm_index + 1) % count]
			if arm["dir"] == Vector3.ZERO or next_arm["dir"] == Vector3.ZERO:
				continue
			var corner_road := _miter_corner(
				arm, next_arm, _ring_offset(arm, 0, true), _ring_offset(next_arm, 0, false)
			)
			var corner_kerb := _miter_corner(
				arm, next_arm, _ring_offset(arm, 1, true), _ring_offset(next_arm, 1, false)
			)
			var corner_foot := _miter_corner(
				arm, next_arm, _ring_offset(arm, 2, true), _ring_offset(next_arm, 2, false)
			)
			if corner_road.is_empty() or corner_kerb.is_empty() or corner_foot.is_empty():
				continue
			# The corner sits on this arm's CCW boundary and the next arm's CW one.
			_assign_corner(result, arm, true, corner_road, corner_kerb, corner_foot)
			_assign_corner(result, next_arm, false, corner_road, corner_kerb, corner_foot)
	return result


func _profile_plan_bounds(profile: PackedVector3Array) -> Rect2:
	if profile.is_empty():
		return Rect2()
	var minimum := Vector2(profile[0].x, profile[0].z)
	var maximum := minimum
	for index in range(1, profile.size()):
		var point := Vector2(profile[index].x, profile[index].z)
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum).grow(EPSILON)


func _canonical_junction(group: Array[Dictionary]) -> Vector3:
	var junction := Vector3.ZERO
	for arm: Dictionary in group:
		junction += arm["point"] as Vector3
	return junction / float(group.size())


func _assign_junction(result: Dictionary, arm: Dictionary, junction: Vector3) -> void:
	var street: Street3D = arm["street"]
	var key := "start" if bool(arm["is_start"]) else "end"
	var entry: Dictionary = result.get(street, {})
	var joins: Dictionary = entry.get(key, {})
	joins["junction"] = junction
	entry[key] = joins
	result[street] = entry


func _ring_offset(arm: Dictionary, ring: int, is_ccw_side: bool) -> float:
	var street: Street3D = arm["street"]
	var side_is_left := is_ccw_side if bool(arm["is_start"]) else !is_ccw_side
	return street.get_ring_offset(side_is_left, ring)


## Intersects arm's CCW boundary line with next_arm's CW boundary line for a
## given ring offset. Returns {} when the boundaries are parallel.
func _miter_corner(arm: Dictionary, next_arm: Dictionary, offset: float, next_offset: float) -> Dictionary:
	var junction: Vector3 = arm.get("junction", arm["point"])
	var arm_dir: Vector3 = arm["dir"]
	var next_dir: Vector3 = next_arm["dir"]
	var arm_ccw_normal := Vector3(-arm_dir.z, 0.0, arm_dir.x)
	var next_cw_normal := Vector3(next_dir.z, 0.0, -next_dir.x)
	var arm_point := junction + arm_ccw_normal * offset
	var next_point := junction + next_cw_normal * next_offset
	var hit := _line_intersection_xz(arm_point, arm_dir, next_point, next_dir)
	if hit.is_empty():
		return {}
	var corner := Vector3(float(hit["x"]), junction.y, float(hit["z"]))
	var delta := Vector2(corner.x - junction.x, corner.z - junction.z)
	var maximum_distance := maxf(offset, next_offset) * MAX_END_MITER_SCALE
	if delta.length() > maximum_distance:
		delta = delta.normalized() * maximum_distance
		corner = Vector3(junction.x + delta.x, junction.y, junction.z + delta.y)
	return {"point": corner}


func _assign_corner(
	result: Dictionary, arm: Dictionary, is_ccw_side: bool,
	corner_road: Dictionary, corner_kerb: Dictionary, corner_foot: Dictionary
) -> void:
	var street: Street3D = arm["street"]
	var key := "start" if bool(arm["is_start"]) else "end"
	# start joins keep the offset polyline's left on the CCW side; end joins are
	# traced back toward the junction, so their left maps to the CW side.
	var side_is_left := is_ccw_side if bool(arm["is_start"]) else !is_ccw_side
	var prefix := "left_" if side_is_left else "right_"
	var entry: Dictionary = result.get(street, {})
	var joins: Dictionary = entry.get(key, {})
	joins[prefix + "road"] = corner_road["point"]
	joins[prefix + "kerb"] = corner_kerb["point"]
	joins[prefix + "foot"] = corner_foot["point"]
	entry[key] = joins
	result[street] = entry


func _line_intersection_xz(
	first_point: Vector3, first_dir: Vector3, second_point: Vector3, second_dir: Vector3
) -> Dictionary:
	var denominator := first_dir.x * second_dir.z - first_dir.z * second_dir.x
	if absf(denominator) <= EPSILON:
		return {}
	var diff_x := second_point.x - first_point.x
	var diff_z := second_point.z - first_point.z
	var first_t := (diff_x * second_dir.z - diff_z * second_dir.x) / denominator
	return {
		"x": first_point.x + first_dir.x * first_t,
		"z": first_point.z + first_dir.z * first_t,
	}


func _points_coincide(a: Vector3, b: Vector3) -> bool:
	return _plan_length(a, b) <= JOIN_TOLERANCE and absf(a.y - b.y) <= VERTICAL_TOLERANCE


func _plan_dir(from_point: Vector3, to_point: Vector3) -> Vector3:
	var delta := Vector3(to_point.x - from_point.x, 0.0, to_point.z - from_point.z)
	return Vector3.ZERO if delta.length_squared() <= EPSILON else delta.normalized()


func _heading(direction: Vector3) -> float:
	return atan2(direction.z, direction.x)


func _append_pair_cuts(
	first: Street3D,
	first_profile: PackedVector3Array,
	second: Street3D,
	second_profile: PackedVector3Array,
	cuts_by_street: Dictionary
) -> void:
	for first_segment in range(first_profile.size() - 1):
		var first_a := first_profile[first_segment]
		var first_b := first_profile[first_segment + 1]
		if _segment_uses_stairs(first, first_a, first_b):
			continue
		for second_segment in range(second_profile.size() - 1):
			var second_a := second_profile[second_segment]
			var second_b := second_profile[second_segment + 1]
			if _segment_uses_stairs(second, second_a, second_b):
				continue
			var hit := _segment_intersection(first_a, first_b, second_a, second_b)
			if hit.is_empty():
				continue
			var first_t := float(hit["first_t"])
			var second_t := float(hit["second_t"])
			var first_height := lerpf(first_a.y, first_b.y, first_t)
			var second_height := lerpf(second_a.y, second_b.y, second_t)
			if absf(first_height - second_height) > VERTICAL_TOLERANCE:
				continue
			var first_through := _street_hit_is_through(
				first_segment, first_profile.size(), first_t
			)
			var second_through := _street_hit_is_through(
				second_segment, second_profile.size(), second_t
			)
			if !first_through and !second_through:
				# Both streets meet at their own endpoints: this is a shared-corner
				# junction handled by kerb/footpath mitering, not by clipping. Cutting
				# here would trim back the very ends the miter joins extend.
				continue
			var first_clips_road := second_through and !first_through
			var second_clips_road := first_through and !second_through
			if first_through and second_through:
				# Scene order owns the coplanar crossing surface, matching wall/roof
				# clipping ownership while both authored paths remain intact.
				second_clips_road = true
			_append_cut(
				cuts_by_street[first], first_segment, first_t,
				second.road_width * 0.5, float(hit["angle_sine"]),
				_plan_length(first_a, first_b), first_clips_road
			)
			_append_cut(
				cuts_by_street[second], second_segment, second_t,
				first.road_width * 0.5, float(hit["angle_sine"]),
				_plan_length(second_a, second_b), second_clips_road
			)


func _street_hit_is_through(segment_index: int, profile_size: int, segment_t: float) -> bool:
	var is_global_start := segment_index == 0 and segment_t <= EPSILON
	var is_global_end := segment_index == profile_size - 2 and segment_t >= 1.0 - EPSILON
	return !is_global_start and !is_global_end


func _append_cut(
	cuts: Array,
	segment_index: int,
	intersection_t: float,
	other_road_half_width: float,
	angle_sine: float,
	segment_length: float,
	clip_road: bool
) -> void:
	if segment_length <= EPSILON or angle_sine < MIN_CROSS_ANGLE_SINE:
		return
	var half_t := other_road_half_width / (segment_length * angle_sine)
	var start_t := clampf(intersection_t - half_t, 0.0, 1.0)
	var end_t := clampf(intersection_t + half_t, 0.0, 1.0)
	for cut_index in range(cuts.size()):
		var existing: Dictionary = cuts[cut_index]
		if int(existing.get("segment_index", -1)) != segment_index:
			continue
		if (
			absf(float(existing.get("start_t", 0.0)) - start_t) > EPSILON
			or absf(float(existing.get("end_t", 0.0)) - end_t) > EPSILON
		):
			continue
		existing["clip_road"] = bool(existing.get("clip_road", false)) or clip_road
		cuts[cut_index] = existing
		return
	cuts.append({
		"segment_index": segment_index,
		"start_t": start_t,
		"end_t": end_t,
		"clip_road": clip_road,
	})


func _segment_intersection(
	first_a: Vector3, first_b: Vector3, second_a: Vector3, second_b: Vector3
) -> Dictionary:
	var first_origin := Vector2(first_a.x, first_a.z)
	var second_origin := Vector2(second_a.x, second_a.z)
	var first_delta := Vector2(first_b.x - first_a.x, first_b.z - first_a.z)
	var second_delta := Vector2(second_b.x - second_a.x, second_b.z - second_a.z)
	var first_length := first_delta.length()
	var second_length := second_delta.length()
	if first_length <= EPSILON or second_length <= EPSILON:
		return {}
	var denominator := first_delta.cross(second_delta)
	var angle_sine := absf(denominator) / (first_length * second_length)
	if angle_sine < MIN_CROSS_ANGLE_SINE:
		return {}
	var between := second_origin - first_origin
	var first_t := between.cross(second_delta) / denominator
	var second_t := between.cross(first_delta) / denominator
	if first_t < -EPSILON or first_t > 1.0 + EPSILON:
		return {}
	if second_t < -EPSILON or second_t > 1.0 + EPSILON:
		return {}
	return {
		"first_t": clampf(first_t, 0.0, 1.0),
		"second_t": clampf(second_t, 0.0, 1.0),
		"angle_sine": angle_sine,
	}


func _segment_uses_stairs(street: Street3D, a: Vector3, b: Vector3) -> bool:
	if !street.supports_footpath_stairs():
		return false
	var run := _plan_length(a, b)
	if run <= EPSILON:
		return false
	return rad_to_deg(atan2(absf(b.y - a.y), run)) > street.stair_threshold_degrees + EPSILON


func _plan_length(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
