@tool
class_name StreetGeometryResolver
extends RefCounted

const EPSILON := 0.0001
const MIN_CROSS_ANGLE_SINE := 0.05
const VERTICAL_TOLERANCE := 0.02
## Endpoints closer than this in plan share a junction and get mitered together.
const JOIN_TOLERANCE := 0.05

var m_streets: Array[Street3D] = []


func _init(streets: Array) -> void:
	for street: Variant in streets:
		if street is Street3D:
			m_streets.append(street)


func refresh_street_intersection_cuts() -> void:
	var cuts_by_street: Dictionary = {}
	for street: Street3D in m_streets:
		cuts_by_street[street] = []
	for first_index in range(m_streets.size()):
		var first := m_streets[first_index]
		var first_profile := first.get_geometry_profile()
		for second_index in range(first_index + 1, m_streets.size()):
			var second := m_streets[second_index]
			var second_profile := second.get_geometry_profile()
			_append_pair_cuts(first, first_profile, second, second_profile, cuts_by_street)
	var joins_by_street := _compute_end_joins()
	for street: Street3D in m_streets:
		street.set_intersection_geometry(
			cuts_by_street.get(street, []), joins_by_street.get(street, {})
		)


## Groups coincident street endpoints into junctions and, for each pair of
## angularly adjacent arms, extends their touching road/kerb/footpath edges onto
## a shared miter corner so the kerbs and footpaths connect across the junction.
func _compute_end_joins() -> Dictionary:
	var ends: Array[Dictionary] = []
	for street: Street3D in m_streets:
		var profile := street.get_geometry_profile()
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
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _heading(a["dir"]) < _heading(b["dir"])
		)
		var count := group.size()
		for arm_index in range(count):
			var arm := group[arm_index]
			var next_arm := group[(arm_index + 1) % count]
			if arm["dir"] == Vector3.ZERO or next_arm["dir"] == Vector3.ZERO:
				continue
			var corner_road := _miter_corner(arm, next_arm, _ring_offset(arm, 0), _ring_offset(next_arm, 0))
			var corner_kerb := _miter_corner(arm, next_arm, _ring_offset(arm, 1), _ring_offset(next_arm, 1))
			var corner_foot := _miter_corner(arm, next_arm, _ring_offset(arm, 2), _ring_offset(next_arm, 2))
			if corner_road.is_empty() or corner_kerb.is_empty() or corner_foot.is_empty():
				continue
			# The corner sits on this arm's CCW boundary and the next arm's CW one.
			_assign_corner(result, arm, true, corner_road, corner_kerb, corner_foot)
			_assign_corner(result, next_arm, false, corner_road, corner_kerb, corner_foot)
	return result


func _ring_offset(arm: Dictionary, ring: int) -> float:
	var street: Street3D = arm["street"]
	var half_width := street.road_width * 0.5
	if ring == 0:
		return half_width
	if ring == 1:
		return half_width + street.kerb_width
	return half_width + street.kerb_width + street.footpath_width


## Intersects arm's CCW boundary line with next_arm's CW boundary line for a
## given ring offset. Returns {} when the boundaries are parallel.
func _miter_corner(arm: Dictionary, next_arm: Dictionary, offset: float, next_offset: float) -> Dictionary:
	var junction: Vector3 = arm["point"]
	var arm_dir: Vector3 = arm["dir"]
	var next_dir: Vector3 = next_arm["dir"]
	var arm_ccw_normal := Vector3(-arm_dir.z, 0.0, arm_dir.x)
	var next_cw_normal := Vector3(next_dir.z, 0.0, -next_dir.x)
	var arm_point := junction + arm_ccw_normal * offset
	var next_point := junction + next_cw_normal * next_offset
	var hit := _line_intersection_xz(arm_point, arm_dir, next_point, next_dir)
	if hit.is_empty():
		return {}
	return {"point": Vector3(float(hit["x"]), junction.y, float(hit["z"]))}


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
			var first_through := first_t > EPSILON and first_t < 1.0 - EPSILON
			var second_through := second_t > EPSILON and second_t < 1.0 - EPSILON
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
	cuts.append({
		"segment_index": segment_index,
		"start_t": clampf(intersection_t - half_t, 0.0, 1.0),
		"end_t": clampf(intersection_t + half_t, 0.0, 1.0),
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
	var run := _plan_length(a, b)
	if run <= EPSILON:
		return false
	return rad_to_deg(atan2(absf(b.y - a.y), run)) > street.stair_threshold_degrees + EPSILON


func _plan_length(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
