@tool
class_name StreetNetwork3D
extends Node3D

const Street3DScript = preload("res://addons/low_poly_building_editor/streets/street_3d.gd")
const StreetCurveSamplerScript = preload(
	"res://addons/low_poly_building_editor/streets/street_curve_sampler.gd"
)
const StreetGeometryResolverScript = preload(
	"res://addons/low_poly_building_editor/streets/street_geometry_resolver.gd"
)
const StreetJunction3DScript = preload(
	"res://addons/low_poly_building_editor/streets/street_junction_3d.gd"
)

const GENERATED_META := &"street_network_generated"
const SEGMENT_ID_META := &"street_network_segment_id"
const JUNCTION_ID_META := &"street_network_junction_id"
const EPSILON := 0.00001
const JUNCTION_SNAP_TOLERANCE := 0.05
const CROSSING_HEIGHT_TOLERANCE := 0.03
const MAX_CROSSING_SPLITS := 128

signal network_geometry_changed(changed_segment_ids: PackedStringArray)
signal terrain_corridor_changed()

@export var network_data: StreetNetworkData = StreetNetworkData.new():
	set(value):
		_disconnect_network_data()
		network_data = value if value != null else StreetNetworkData.new()
		_connect_network_data()
		_request_rebuild(PackedStringArray(), true)

@export_group("Curve Sampling")
@export_range(0.005, 2.0, 0.005, "or_greater") var maximum_chord_error := 0.08:
	set(value):
		var normalized := maxf(value, 0.005)
		if is_equal_approx(maximum_chord_error, normalized):
			return
		maximum_chord_error = normalized
		_request_rebuild(PackedStringArray(), true)
@export_range(0.5, 45.0, 0.5) var maximum_tangent_angle_degrees := 8.0:
	set(value):
		var normalized := clampf(value, 0.5, 45.0)
		if is_equal_approx(maximum_tangent_angle_degrees, normalized):
			return
		maximum_tangent_angle_degrees = normalized
		_request_rebuild(PackedStringArray(), true)
@export_range(0.1, 10.0, 0.1, "or_greater") var terrain_sample_spacing := 0.5
@export_range(0, 8, 1) var terrain_smoothing_passes := 1

@export_group("Generation")
@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild(PackedStringArray(), true)

var m_is_ready := false
var m_rebuild_queued := false
var m_full_rebuild_queued := false
var m_dirty_segment_ids: Dictionary = {}
var m_mutating_data := false
var m_last_build_summary: Dictionary = {}


func _ready() -> void:
	m_is_ready = true
	_connect_network_data()
	if build_on_ready:
		rebuild_network()


func _exit_tree() -> void:
	_disconnect_network_data()


func add_path(
	local_points: PackedVector3Array,
	section_profile: StreetSectionProfile = null,
	provenance: StringName = &"authored",
	connect_crossings := true,
	vertical_mode := StreetSegmentData.VerticalMode.GRADED
) -> Array[String]:
	var points := _remove_duplicate_points(local_points)
	if points.size() < 2:
		return [] as Array[String]
	m_mutating_data = true
	var junction_elevation_mode := (
		StreetJunctionData.ElevationMode.FOLLOW_TERRAIN
		if vertical_mode == StreetSegmentData.VerticalMode.FOLLOW_TERRAIN
		else StreetJunctionData.ElevationMode.MANUAL
	)
	var start := _find_or_add_junction(points[0], provenance, junction_elevation_mode)
	var end := _find_or_add_junction(
		points[points.size() - 1], provenance, junction_elevation_mode
	)
	if start == end:
		m_mutating_data = false
		return [] as Array[String]
	var curve_mode := (
		StreetSegmentData.CurveMode.POLYLINE
		if points.size() > 2
		else StreetSegmentData.CurveMode.STRAIGHT
	)
	var segment := network_data.add_segment(
		start.stable_id, end.stable_id, section_profile, "", curve_mode, provenance
	)
	segment.vertical_mode = vertical_mode
	if curve_mode == StreetSegmentData.CurveMode.POLYLINE:
		segment.polyline_points = points
	var changed_ids: Array[String] = [segment.stable_id]
	if connect_crossings:
		changed_ids.append_array(_connect_same_level_crossings_internal())
	m_mutating_data = false
	_request_rebuild(PackedStringArray(changed_ids), false)
	return changed_ids


func add_paths(
	paths: Array[PackedVector3Array],
	section_profile: StreetSectionProfile = null,
	provenance: StringName = &"authored",
	connect_crossings := true,
	vertical_mode := StreetSegmentData.VerticalMode.GRADED
) -> Array[String]:
	var changed: Array[String] = []
	for path in paths:
		changed.append_array(
			add_path(path, section_profile, provenance, false, vertical_mode)
		)
	if connect_crossings:
		m_mutating_data = true
		changed.append_array(_connect_same_level_crossings_internal())
		m_mutating_data = false
	_request_rebuild(PackedStringArray(changed), false)
	return changed


func move_junction(junction_id: String, new_position: Vector3) -> bool:
	var junction := network_data.find_junction(junction_id)
	if junction == null or junction.locked:
		return false
	var dirty := _incident_segment_ids(junction_id)
	m_mutating_data = true
	junction.position = new_position
	for segment_id in dirty:
		var segment := network_data.find_segment(segment_id)
		if segment != null and segment.vertical_mode != StreetSegmentData.VerticalMode.MANUAL:
			segment.terrain_profile = PackedVector3Array()
	m_mutating_data = false
	_request_rebuild(PackedStringArray(dirty), false)
	return true


func set_junction_elevation(junction_id: String, height: float, manual := true) -> bool:
	var junction := network_data.find_junction(junction_id)
	if junction == null or junction.locked:
		return false
	var position_value := junction.position
	position_value.y = height
	m_mutating_data = true
	junction.elevation_mode = (
		StreetJunctionData.ElevationMode.MANUAL
		if manual
		else StreetJunctionData.ElevationMode.FOLLOW_TERRAIN
	)
	junction.position = position_value
	m_mutating_data = false
	var dirty := _incident_segment_ids(junction_id)
	_request_rebuild(PackedStringArray(dirty), false)
	return true


func set_segment_curve(
	segment_id: String,
	curve_mode: int,
	start_handle: Vector3 = Vector3.ZERO,
	end_handle: Vector3 = Vector3.ZERO
) -> bool:
	var segment := network_data.find_segment(segment_id)
	if segment == null or segment.locked:
		return false
	m_mutating_data = true
	segment.curve_mode = curve_mode
	segment.start_handle = start_handle
	segment.end_handle = end_handle
	segment.terrain_profile = PackedVector3Array()
	m_mutating_data = false
	_request_rebuild(PackedStringArray([segment_id]), false)
	return true


func replace_segment_profile(segment_id: String, profile: StreetSectionProfile) -> bool:
	var segment := network_data.find_segment(segment_id)
	if segment == null or segment.locked or profile == null:
		return false
	m_mutating_data = true
	segment.section_profile = profile
	m_mutating_data = false
	_request_rebuild(PackedStringArray([segment_id]), false)
	return true


func reconnect_segment(
	segment_id: String, old_junction_id: String, new_junction_id: String
) -> bool:
	var segment := network_data.find_segment(segment_id)
	if segment == null or segment.locked or network_data.find_junction(new_junction_id) == null:
		return false
	m_mutating_data = true
	if segment.start_junction_id == old_junction_id:
		segment.start_junction_id = new_junction_id
	elif segment.end_junction_id == old_junction_id:
		segment.end_junction_id = new_junction_id
	else:
		m_mutating_data = false
		return false
	segment.terrain_profile = PackedVector3Array()
	m_mutating_data = false
	_request_rebuild(PackedStringArray([segment_id]), false)
	return true


func remove_junction(junction_id: String) -> bool:
	var junction := network_data.find_junction(junction_id)
	if junction == null or junction.locked:
		return false
	var dirty := _neighbor_segment_ids(junction_id)
	m_mutating_data = true
	var removed := network_data.remove_junction(junction_id, true)
	m_mutating_data = false
	_request_rebuild(PackedStringArray(dirty), true)
	return removed


func merge_junctions(target_id: String, removed_id: String) -> bool:
	if target_id == removed_id:
		return true
	var target := network_data.find_junction(target_id)
	var removed := network_data.find_junction(removed_id)
	if target == null or removed == null or target.locked or removed.locked:
		return false
	var dirty: Array[String] = []
	m_mutating_data = true
	for segment: StreetSegmentData in network_data.incident_segments(removed_id):
		if segment.start_junction_id == removed_id:
			segment.start_junction_id = target_id
		if segment.end_junction_id == removed_id:
			segment.end_junction_id = target_id
		dirty.append(segment.stable_id)
	for index in range(network_data.segments.size() - 1, -1, -1):
		var segment := network_data.segments[index]
		if segment.start_junction_id == segment.end_junction_id:
			network_data.remove_segment(segment.stable_id)
	network_data.remove_junction(removed_id, false)
	_remove_duplicate_connections()
	m_mutating_data = false
	_request_rebuild(PackedStringArray(dirty), true)
	return true


func split_segment(segment_id: String, local_position: Vector3) -> String:
	var segment := network_data.find_segment(segment_id)
	if segment == null or segment.locked:
		return ""
	m_mutating_data = true
	var result := _split_segment_with_junction(segment, local_position, "")
	m_mutating_data = false
	if result.is_empty():
		return ""
	_request_rebuild(PackedStringArray(result.get("segment_ids", [])), false)
	return String(result.get("junction_id", ""))


func connect_same_level_crossings() -> Array[String]:
	m_mutating_data = true
	var changed := _connect_same_level_crossings_internal()
	m_mutating_data = false
	_request_rebuild(PackedStringArray(changed), false)
	return changed


func resample_terrain(terrain_provider: Node3D) -> Array[String]:
	var errors: Array[String] = []
	if terrain_provider == null or !terrain_provider.has_method("get_world_surface_height"):
		errors.append("Terrain provider must implement get_world_surface_height(world_position).")
		return errors
	m_mutating_data = true
	for junction: StreetJunctionData in network_data.junctions:
		if junction == null or junction.elevation_mode != StreetJunctionData.ElevationMode.FOLLOW_TERRAIN:
			continue
		var world_point := to_global(junction.position)
		var sampled_y := float(terrain_provider.call("get_world_surface_height", world_point))
		junction.position = to_local(Vector3(world_point.x, sampled_y, world_point.z))
	for segment: StreetSegmentData in network_data.segments:
		if segment == null or segment.vertical_mode != StreetSegmentData.VerticalMode.FOLLOW_TERRAIN:
			continue
		segment.terrain_profile = PackedVector3Array()
		var profile := _densify_profile(
			_sample_segment(segment), maxf(terrain_sample_spacing, 0.1)
		)
		var clearance := (
			segment.section_profile.terrain_clearance
			if segment.section_profile != null
			else 0.025
		)
		for index in range(profile.size()):
			var world_point := to_global(profile[index])
			var sampled_y := float(terrain_provider.call("get_world_surface_height", world_point))
			profile[index] = to_local(
				Vector3(world_point.x, sampled_y + clearance, world_point.z)
			)
		profile = _smooth_profile_heights(profile, terrain_smoothing_passes)
		segment.terrain_profile = profile
	m_mutating_data = false
	_request_rebuild(PackedStringArray(), true)
	errors.append_array(network_data.get_validation_errors())
	return errors


func adapt_stair_constraints(minimum_tread_depth: float) -> void:
	var minimum_tread := maxf(minimum_tread_depth, 0.05)
	m_mutating_data = true
	for segment: StreetSegmentData in network_data.segments:
		if segment == null or segment.section_profile == null:
			continue
		if (
			segment.section_profile.cross_section_mode
			== StreetSectionProfile.CrossSectionMode.ROAD_ONLY
		):
			continue
		var required_maximum_riser := segment.section_profile.max_riser_height
		var profile := _sample_segment(segment)
		for index in range(profile.size() - 1):
			var run := _plan_distance(profile[index], profile[index + 1])
			var rise := absf(profile[index + 1].y - profile[index].y)
			if (
				run <= EPSILON
				or rad_to_deg(atan2(rise, run))
				<= segment.section_profile.stair_threshold_degrees + 0.0001
			):
				continue
			var available_steps := maxi(floori(run / minimum_tread), 1)
			required_maximum_riser = maxf(
				required_maximum_riser,
				rise / float(available_steps) + 0.0001
			)
		segment.section_profile.min_tread_depth = minimum_tread
		segment.section_profile.max_riser_height = required_maximum_riser
	m_mutating_data = false
	_request_rebuild(PackedStringArray(), true)


func capture_network_state() -> StreetNetworkData:
	return network_data.duplicate(true) as StreetNetworkData


func restore_network_state(state: StreetNetworkData) -> void:
	if state == null:
		return
	network_data = state.duplicate(true) as StreetNetworkData
	rebuild_network()


func add_legacy_street(street: Street3D, remove_legacy := false) -> Array[String]:
	if street == null:
		return [] as Array[String]
	var profile := StreetSectionProfile.new()
	profile.cross_section_mode = street.cross_section_mode
	profile.road_width = street.road_width
	profile.road_thickness = street.road_thickness
	profile.road_color = street.road_color
	profile.left_kerb_width = street.get_side_kerb_width(true)
	profile.right_kerb_width = street.get_side_kerb_width(false)
	profile.kerb_height = street.kerb_height
	profile.kerb_color = street.kerb_color
	profile.left_footpath_width = street.get_side_footpath_width(true)
	profile.right_footpath_width = street.get_side_footpath_width(false)
	profile.footpath_thickness = street.footpath_thickness
	profile.footpath_color = street.footpath_color
	profile.stair_threshold_degrees = street.stair_threshold_degrees
	profile.stair_exit_threshold_degrees = street.stair_exit_threshold_degrees
	profile.minimum_stair_run_length = street.minimum_stair_run_length
	profile.minimum_stair_run_rise = street.minimum_stair_run_rise
	profile.target_riser_height = street.target_riser_height
	profile.max_riser_height = street.max_riser_height
	profile.min_tread_depth = street.min_tread_depth
	profile.terrain_clearance = street.terrain_clearance
	var points := street.get_geometry_profile()
	var result := add_path(
		points, profile, &"legacy_street3d", true,
		StreetSegmentData.VerticalMode.MANUAL
	)
	if !result.is_empty():
		var segment := network_data.find_segment(result[0])
		if segment != null:
			segment.terrain_profile = points
	if remove_legacy and street.get_parent() != null:
		street.get_parent().remove_child(street)
		street.queue_free()
	return result


func add_legacy_streets(streets: Array, remove_legacy := false) -> Array[String]:
	var changed: Array[String] = []
	for value: Variant in streets:
		if value is Street3D:
			changed.append_array(add_legacy_street(value as Street3D, remove_legacy))
	_request_rebuild(PackedStringArray(changed), false)
	return changed


func find_nearest_junction(local_position: Vector3, maximum_distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := maxf(maximum_distance, 0.0)
	for junction: StreetJunctionData in network_data.junctions:
		if junction == null:
			continue
		var distance := _plan_distance(local_position, junction.position)
		if distance > best_distance:
			continue
		best_distance = distance
		best = {
			"junction_id": junction.stable_id,
			"position": junction.position,
			"distance": distance,
		}
	return best


func find_nearest_segment(local_position: Vector3, maximum_distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := maxf(maximum_distance, 0.0)
	for segment: StreetSegmentData in network_data.segments:
		var profile := _sample_segment(segment)
		for index in range(profile.size() - 1):
			var closest := _closest_point_on_plan_segment(
				local_position, profile[index], profile[index + 1]
			)
			var distance := _plan_distance(local_position, closest)
			if distance > best_distance:
				continue
			best_distance = distance
			best = {
				"segment_id": segment.stable_id,
				"position": closest,
				"distance": distance,
			}
	return best


func is_terrain_street_source() -> bool:
	return !network_data.segments.is_empty()


func get_world_terrain_corridors() -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	for child in get_children():
		if child is Street3D and child.has_meta(SEGMENT_ID_META):
			var corridor: Dictionary = child.get_world_terrain_corridor()
			if !corridor.is_empty():
				corridor["source"] = self
				corridors.append(corridor)
		elif child is StreetJunction3D and child.has_meta(JUNCTION_ID_META):
			var footprint: PackedVector3Array = child.get_parent_local_footprint()
			if footprint.size() < 3:
				continue
			var world_footprint := PackedVector3Array()
			for point in footprint:
				world_footprint.append(to_global(point))
			var junction_id := String(child.get_meta(JUNCTION_ID_META, ""))
			var section := _junction_surface_profile(junction_id)
			var depth := 0.2
			if section != null:
				depth = maxf(
					section.center_surface_thickness() + section.terrain_clearance, 0.01
				)
			corridors.append({
				"polygon": world_footprint,
				"bed_depth": depth,
				"source": self,
			})
	return corridors


## Legacy single-corridor consumer compatibility. New terrain integrations use
## get_world_terrain_corridors() and receive the complete network.
func get_world_terrain_corridor() -> Dictionary:
	var corridors := get_world_terrain_corridors()
	return corridors[0] if !corridors.is_empty() else {}


func get_last_build_summary() -> Dictionary:
	return m_last_build_summary.duplicate(true)


func rebuild_network() -> void:
	m_rebuild_queued = false
	var full_rebuild := m_full_rebuild_queued
	m_full_rebuild_queued = false
	var dirty := m_dirty_segment_ids.duplicate()
	m_dirty_segment_ids.clear()
	var errors := network_data.get_validation_errors()
	if !errors.is_empty():
		m_last_build_summary = {"errors": errors}
		return
	var existing_segments := _existing_segment_children()
	var active_segment_ids: Dictionary = {}
	var street_nodes: Array[Street3D] = []
	for segment: StreetSegmentData in network_data.segments:
		if segment == null:
			continue
		active_segment_ids[segment.stable_id] = true
		var street: Street3D = existing_segments.get(segment.stable_id)
		var created := false
		if street == null:
			street = Street3DScript.new() as Street3D
			street.build_on_ready = false
			street.set_meta(Street3D.NETWORK_SEGMENT_META, true)
			street.set_meta(SEGMENT_ID_META, segment.stable_id)
			add_child(street)
			_assign_generated_owner(street)
			created = true
		if created or full_rebuild or dirty.has(segment.stable_id):
			_configure_segment_street(street, segment)
		street_nodes.append(street)
	for segment_id: String in existing_segments:
		if active_segment_ids.has(segment_id):
			continue
		var stale: Street3D = existing_segments[segment_id]
		remove_child(stale)
		stale.queue_free()
	StreetGeometryResolverScript.new(street_nodes, false).refresh_street_intersection_cuts()
	_rebuild_junction_nodes(street_nodes)
	m_last_build_summary = {
		"errors": [] as Array[String],
		"junction_count": network_data.junctions.size(),
		"segment_count": network_data.segments.size(),
		"generated_segment_count": street_nodes.size(),
		"generated_junction_count": _existing_junction_children().size(),
		"full_rebuild": full_rebuild,
		"dirty_segment_count": dirty.size(),
	}
	var changed_ids := PackedStringArray(active_segment_ids.keys() if full_rebuild else dirty.keys())
	network_geometry_changed.emit(changed_ids)
	terrain_corridor_changed.emit()


func _configure_segment_street(street: Street3D, segment: StreetSegmentData) -> void:
	var profile := segment.section_profile
	if profile == null:
		profile = StreetSectionProfile.new()
	street.name = "Segment_%s" % segment.stable_id
	street.set_meta(SEGMENT_ID_META, segment.stable_id)
	street.path_points = _sample_segment(segment)
	street.profile_points = []
	street.cross_section_mode = profile.cross_section_mode
	street.road_width = profile.road_width
	street.road_thickness = profile.road_thickness
	street.road_color = profile.road_color
	street.kerb_width = maxf(profile.left_kerb_width, profile.right_kerb_width)
	street.kerb_height = profile.kerb_height
	street.kerb_color = profile.kerb_color
	street.footpath_width = maxf(profile.left_footpath_width, profile.right_footpath_width)
	street.footpath_thickness = profile.footpath_thickness
	street.footpath_color = profile.footpath_color
	street.use_asymmetric_cross_section = true
	street.left_kerb_width = profile.left_kerb_width
	street.right_kerb_width = profile.right_kerb_width
	street.left_footpath_width = profile.left_footpath_width
	street.right_footpath_width = profile.right_footpath_width
	street.stair_threshold_degrees = profile.stair_threshold_degrees
	street.stair_exit_threshold_degrees = profile.stair_exit_threshold_degrees
	street.minimum_stair_run_length = profile.minimum_stair_run_length
	street.minimum_stair_run_rise = profile.minimum_stair_run_rise
	street.target_riser_height = profile.target_riser_height
	street.max_riser_height = profile.max_riser_height
	street.min_tread_depth = profile.min_tread_depth
	street.terrain_clearance = profile.terrain_clearance
	street.generate_collision = generate_collision
	street.external_junction_surfaces = true
	street.rebuild_street_mesh()


func _rebuild_junction_nodes(streets: Array[Street3D]) -> void:
	var segment_nodes: Dictionary = {}
	for street: Street3D in streets:
		segment_nodes[String(street.get_meta(SEGMENT_ID_META, ""))] = street
	var existing := _existing_junction_children()
	var active: Dictionary = {}
	for junction: StreetJunctionData in network_data.junctions:
		if junction == null:
			continue
		var incident_segments := network_data.incident_segments(junction.stable_id)
		var road_corners := PackedVector3Array()
		var foot_corners := PackedVector3Array()
		for segment: StreetSegmentData in incident_segments:
			var street: Street3D = segment_nodes.get(segment.stable_id)
			if street == null:
				continue
			var key := "start" if segment.start_junction_id == junction.stable_id else "end"
			var joins: Dictionary = street.get_end_joins().get(key, {})
			if joins.is_empty():
				continue
			for left_side: bool in [true, false]:
				var prefix := "left_" if left_side else "right_"
				var road_field := prefix + "road"
				var foot_field := prefix + "foot"
				if joins.has(road_field):
					road_corners.append(Vector3(joins[road_field]))
				elif incident_segments.size() >= 3:
					road_corners.append(
						_terminal_ring_point(street, key, left_side, 0, junction.position)
					)
				if joins.has(foot_field):
					foot_corners.append(Vector3(joins[foot_field]))
				elif incident_segments.size() >= 3:
					foot_corners.append(
						_terminal_ring_point(street, key, left_side, 2, junction.position)
					)
		if road_corners.size() < 2:
			continue
		var section := _junction_surface_profile(junction.stable_id)
		if section == null:
			section = StreetSectionProfile.new()
		var node: StreetJunction3D = existing.get(junction.stable_id)
		if node == null:
			node = StreetJunction3DScript.new() as StreetJunction3D
			node.set_meta(GENERATED_META, true)
			node.set_meta(JUNCTION_ID_META, junction.stable_id)
			add_child(node)
			_assign_generated_owner(node)
		active[junction.stable_id] = true
		node.configure(
			junction.stable_id, junction.position, road_corners, foot_corners,
			section.center_surface_thickness(), section.center_surface_color(), generate_collision
		)
	for junction_id: String in existing:
		if active.has(junction_id):
			continue
		var stale: StreetJunction3D = existing[junction_id]
		remove_child(stale)
		stale.queue_free()


func _terminal_ring_point(
	street: Street3D,
	end_key: String,
	left_side: bool,
	ring: int,
	junction_position: Vector3
) -> Vector3:
	var profile := street.get_geometry_profile()
	if profile.size() < 2:
		return junction_position
	var direction := Vector3.ZERO
	if end_key == "start":
		direction = _plan_direction(profile[0], profile[1])
	else:
		var last := profile.size() - 1
		direction = _plan_direction(profile[last - 1], profile[last])
	var normal := Vector3(-direction.z, 0.0, direction.x)
	var signed_offset := street.get_ring_offset(left_side, ring)
	if !left_side:
		signed_offset *= -1.0
	return junction_position + normal * signed_offset


func _connect_same_level_crossings_internal() -> Array[String]:
	var changed: Array[String] = []
	for _iteration in range(MAX_CROSSING_SPLITS):
		var crossing := _find_first_same_level_crossing()
		if crossing.is_empty():
			break
		var first_id := String(crossing["first_segment_id"])
		var second_id := String(crossing["second_segment_id"])
		var first := network_data.find_segment(first_id)
		var second := network_data.find_segment(second_id)
		if first == null or second == null:
			break
		if first_id == second_id:
			var self_result := _split_self_crossing_segment(first, crossing)
			if self_result.is_empty():
				break
			changed.append_array(self_result.get("segment_ids", []))
			continue
		var point: Vector3 = crossing["point"]
		var junction_id := _crossing_junction_at(first, second, point)
		if junction_id.is_empty():
			junction_id = network_data.add_junction(
				point, "", StreetJunctionData.ElevationMode.MANUAL, &"auto_intersection"
			).stable_id
		else:
			var existing_junction := network_data.find_junction(junction_id)
			if existing_junction != null:
				# Split against the canonical centre. The intersected endpoint arm then
				# remains intact, while the crossing section bends into that junction
				# instead of producing a second, overlapping junction nearby.
				point = existing_junction.position
		var first_result := _split_segment_with_junction(first, point, junction_id)
		var refreshed_second := network_data.find_segment(second.stable_id)
		var second_result: Dictionary = {}
		if refreshed_second != null:
			second_result = _split_segment_with_junction(refreshed_second, point, junction_id)
		if first_result.is_empty() and second_result.is_empty():
			var first_endpoint := _endpoint_junction_at(first, point)
			var second_endpoint := _endpoint_junction_at(second, point)
			if !first_endpoint.is_empty() and !second_endpoint.is_empty():
				merge_junctions(first_endpoint, second_endpoint)
				changed.append_array(_incident_segment_ids(first_endpoint))
				continue
			break
		changed.append_array(first_result.get("segment_ids", []))
		changed.append_array(second_result.get("segment_ids", []))
	return changed


func _find_first_same_level_crossing() -> Dictionary:
	for first_index in range(network_data.segments.size()):
		var first := network_data.segments[first_index]
		var first_profile := _sample_segment(first)
		var self_crossing := _find_segment_self_crossing(first, first_profile)
		if !self_crossing.is_empty():
			return self_crossing
		for second_index in range(first_index + 1, network_data.segments.size()):
			var second := network_data.segments[second_index]
			var second_profile := _sample_segment(second)
			for first_line in range(first_profile.size() - 1):
				for second_line in range(second_profile.size() - 1):
					var hit := _segment_intersection(
						first_profile[first_line], first_profile[first_line + 1],
						second_profile[second_line], second_profile[second_line + 1]
					)
					if hit.is_empty():
						continue
					var first_t := float(hit["first_t"])
					var second_t := float(hit["second_t"])
					var first_point := first_profile[first_line].lerp(
						first_profile[first_line + 1], first_t
					)
					var second_point := second_profile[second_line].lerp(
						second_profile[second_line + 1], second_t
					)
					if absf(first_point.y - second_point.y) > CROSSING_HEIGHT_TOLERANCE:
						continue
					var point := Vector3(
						first_point.x, (first_point.y + second_point.y) * 0.5, first_point.z
					)
					if _segments_share_junction_at(first, second, point):
						continue
					return {
						"first_segment_id": first.stable_id,
						"second_segment_id": second.stable_id,
						"point": point,
					}
	return {}


func _find_segment_self_crossing(
	segment: StreetSegmentData, profile: PackedVector3Array
) -> Dictionary:
	if segment == null or profile.size() < 4:
		return {}
	for first_line in range(profile.size() - 1):
		for second_line in range(first_line + 2, profile.size() - 1):
			var hit := _segment_intersection(
				profile[first_line], profile[first_line + 1],
				profile[second_line], profile[second_line + 1]
			)
			if hit.is_empty():
				continue
			var first_point := profile[first_line].lerp(
				profile[first_line + 1], float(hit["first_t"])
			)
			var second_point := profile[second_line].lerp(
				profile[second_line + 1], float(hit["second_t"])
			)
			if absf(first_point.y - second_point.y) > CROSSING_HEIGHT_TOLERANCE:
				continue
			return {
				"first_segment_id": segment.stable_id,
				"second_segment_id": segment.stable_id,
				"first_line": first_line,
				"second_line": second_line,
				"point": Vector3(
					first_point.x, (first_point.y + second_point.y) * 0.5, first_point.z
				),
			}
	return {}


func _split_self_crossing_segment(
	segment: StreetSegmentData, crossing: Dictionary
) -> Dictionary:
	if segment == null:
		return {}
	var profile := _sample_segment(segment)
	var first_line := int(crossing.get("first_line", -1))
	var second_line := int(crossing.get("second_line", -1))
	if (
		first_line < 0
		or second_line < first_line + 2
		or second_line >= profile.size() - 1
	):
		return {}
	var point: Vector3 = crossing["point"]
	var loop_split_index := -1
	var loop_split_distance := JUNCTION_SNAP_TOLERANCE
	for index in range(first_line + 1, second_line + 1):
		var distance := _plan_distance(point, profile[index])
		if distance <= loop_split_distance:
			continue
		loop_split_distance = distance
		loop_split_index = index
	if loop_split_index < 0:
		return {}

	var prefix := PackedVector3Array()
	for index in range(first_line + 1):
		prefix.append(profile[index])
	prefix.append(point)
	prefix = _remove_duplicate_points(prefix)
	var loop_first := PackedVector3Array([point])
	for index in range(first_line + 1, loop_split_index + 1):
		loop_first.append(profile[index])
	loop_first = _remove_duplicate_points(loop_first)
	var loop_second := PackedVector3Array([profile[loop_split_index]])
	for index in range(loop_split_index + 1, second_line + 1):
		loop_second.append(profile[index])
	loop_second.append(point)
	loop_second = _remove_duplicate_points(loop_second)
	var suffix := PackedVector3Array([point])
	for index in range(second_line + 1, profile.size()):
		suffix.append(profile[index])
	suffix = _remove_duplicate_points(suffix)
	if loop_first.size() < 2 or loop_second.size() < 2:
		return {}

	var elevation_mode := (
		StreetJunctionData.ElevationMode.FOLLOW_TERRAIN
		if segment.vertical_mode == StreetSegmentData.VerticalMode.FOLLOW_TERRAIN
		else StreetJunctionData.ElevationMode.MANUAL
	)
	var junction_id := _endpoint_junction_at(segment, point)
	if junction_id.is_empty():
		junction_id = network_data.add_junction(
			point, "", elevation_mode, &"auto_self_intersection"
		).stable_id
	var loop_junction := network_data.add_junction(
		profile[loop_split_index], "", elevation_mode, &"self_intersection_split"
	)
	var pieces: Array[Dictionary] = []
	if segment.start_junction_id != junction_id and prefix.size() >= 2:
		pieces.append({
			"start_id": segment.start_junction_id,
			"end_id": junction_id,
			"points": prefix,
		})
	pieces.append({
		"start_id": junction_id,
		"end_id": loop_junction.stable_id,
		"points": loop_first,
	})
	pieces.append({
		"start_id": loop_junction.stable_id,
		"end_id": junction_id,
		"points": loop_second,
	})
	if segment.end_junction_id != junction_id and suffix.size() >= 2:
		pieces.append({
			"start_id": junction_id,
			"end_id": segment.end_junction_id,
			"points": suffix,
		})
	var original_id := segment.stable_id
	var section := segment.section_profile
	var vertical_mode := segment.vertical_mode
	var provenance := segment.provenance
	var locked := segment.locked
	network_data.remove_segment(original_id)
	var segment_ids: Array[String] = []
	for piece_index in range(pieces.size()):
		var piece := pieces[piece_index]
		var split_segment := network_data.add_segment(
			String(piece["start_id"]), String(piece["end_id"]), section,
			original_id if piece_index == 0 else "",
			StreetSegmentData.CurveMode.POLYLINE, provenance
		)
		split_segment.polyline_points = piece["points"] as PackedVector3Array
		split_segment.vertical_mode = vertical_mode
		split_segment.locked = locked
		segment_ids.append(split_segment.stable_id)
	return {
		"junction_id": junction_id,
		"segment_ids": segment_ids,
	}


func _split_segment_with_junction(
	segment: StreetSegmentData, local_position: Vector3, existing_junction_id: String
) -> Dictionary:
	if segment == null:
		return {}
	var profile := _sample_segment(segment)
	if profile.size() < 2:
		return {}
	var nearest := _nearest_profile_location(profile, local_position)
	if nearest.is_empty():
		return {}
	var point: Vector3 = nearest["point"]
	if _plan_distance(point, profile[0]) <= JUNCTION_SNAP_TOLERANCE:
		return {
			"junction_id": segment.start_junction_id,
			"segment_ids": [segment.stable_id],
		}
	if _plan_distance(point, profile[profile.size() - 1]) <= JUNCTION_SNAP_TOLERANCE:
		return {
			"junction_id": segment.end_junction_id,
			"segment_ids": [segment.stable_id],
		}
	var junction_id := existing_junction_id
	if junction_id.is_empty():
		junction_id = network_data.add_junction(
			point, "", StreetJunctionData.ElevationMode.MANUAL, &"segment_split"
		).stable_id
	var split_index := int(nearest["segment_index"])
	var first_points := PackedVector3Array()
	for index in range(split_index + 1):
		first_points.append(profile[index])
	first_points.append(point)
	var second_points := PackedVector3Array([point])
	for index in range(split_index + 1, profile.size()):
		second_points.append(profile[index])
	var original_id := segment.stable_id
	var start_id := segment.start_junction_id
	var end_id := segment.end_junction_id
	var section := segment.section_profile
	var vertical_mode := segment.vertical_mode
	var provenance := segment.provenance
	var locked := segment.locked
	network_data.remove_segment(original_id)
	var first := network_data.add_segment(
		start_id, junction_id, section, original_id,
		StreetSegmentData.CurveMode.POLYLINE, provenance
	)
	first.polyline_points = first_points
	first.vertical_mode = vertical_mode
	first.locked = locked
	var second := network_data.add_segment(
		junction_id, end_id, section, "",
		StreetSegmentData.CurveMode.POLYLINE, provenance
	)
	second.polyline_points = second_points
	second.vertical_mode = vertical_mode
	second.locked = locked
	return {
		"junction_id": junction_id,
		"segment_ids": [first.stable_id, second.stable_id],
	}


func _find_or_add_junction(
	local_position: Vector3,
	provenance: StringName,
	elevation_mode := StreetJunctionData.ElevationMode.MANUAL
) -> StreetJunctionData:
	var nearest := find_nearest_junction(local_position, JUNCTION_SNAP_TOLERANCE)
	if !nearest.is_empty():
		return network_data.find_junction(String(nearest["junction_id"]))
	return network_data.add_junction(
		local_position, "", elevation_mode, provenance
	)


func _sample_segment(segment: StreetSegmentData) -> PackedVector3Array:
	if segment == null:
		return PackedVector3Array()
	var start := network_data.find_junction(segment.start_junction_id)
	var end := network_data.find_junction(segment.end_junction_id)
	if start == null or end == null:
		return PackedVector3Array()
	return StreetCurveSamplerScript.sample(
		segment, start.position, end.position,
		maximum_chord_error, maximum_tangent_angle_degrees
	)


func _request_rebuild(segment_ids: PackedStringArray, full_rebuild: bool) -> void:
	for segment_id in segment_ids:
		m_dirty_segment_ids[segment_id] = true
	m_full_rebuild_queued = m_full_rebuild_queued or full_rebuild
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_network")


func _connect_network_data() -> void:
	if network_data != null and !network_data.changed.is_connected(_on_network_data_changed):
		network_data.changed.connect(_on_network_data_changed)


func _disconnect_network_data() -> void:
	if network_data != null and network_data.changed.is_connected(_on_network_data_changed):
		network_data.changed.disconnect(_on_network_data_changed)


func _on_network_data_changed() -> void:
	if m_mutating_data:
		return
	_request_rebuild(PackedStringArray(), true)


func _existing_segment_children() -> Dictionary:
	var result: Dictionary = {}
	for child in get_children():
		if child is Street3D and child.has_meta(SEGMENT_ID_META):
			result[String(child.get_meta(SEGMENT_ID_META))] = child
	return result


func _existing_junction_children() -> Dictionary:
	var result: Dictionary = {}
	for child in get_children():
		if child is StreetJunction3D and child.has_meta(JUNCTION_ID_META):
			result[String(child.get_meta(JUNCTION_ID_META))] = child
	return result


func _assign_generated_owner(child: Node) -> void:
	child.set_meta(GENERATED_META, true)
	if Engine.is_editor_hint() and owner != null:
		child.owner = owner


func _junction_surface_profile(junction_id: String) -> StreetSectionProfile:
	var incident := network_data.incident_segments(junction_id)
	incident.sort_custom(func(a: StreetSegmentData, b: StreetSegmentData) -> bool:
		return a.stable_id < b.stable_id
	)
	var first_footpath: StreetSectionProfile = null
	for segment: StreetSegmentData in incident:
		var profile := segment.section_profile
		if profile == null:
			continue
		if profile.cross_section_mode != StreetSectionProfile.CrossSectionMode.FOOTPATH_ONLY:
			return profile
		if first_footpath == null:
			first_footpath = profile
	return first_footpath


func _incident_segment_ids(junction_id: String) -> Array[String]:
	var result: Array[String] = []
	for segment: StreetSegmentData in network_data.incident_segments(junction_id):
		result.append(segment.stable_id)
	return result


func _neighbor_segment_ids(junction_id: String) -> Array[String]:
	var result: Array[String] = []
	for segment: StreetSegmentData in network_data.incident_segments(junction_id):
		var other := (
			segment.end_junction_id
			if segment.start_junction_id == junction_id
			else segment.start_junction_id
		)
		for neighbor: StreetSegmentData in network_data.incident_segments(other):
			if !result.has(neighbor.stable_id):
				result.append(neighbor.stable_id)
	return result


func _remove_duplicate_connections() -> void:
	var seen: Dictionary = {}
	for index in range(network_data.segments.size() - 1, -1, -1):
		var segment := network_data.segments[index]
		var pair := [segment.start_junction_id, segment.end_junction_id]
		pair.sort()
		var key := "%s|%s" % [pair[0], pair[1]]
		if seen.has(key):
			network_data.remove_segment(segment.stable_id)
		else:
			seen[key] = true


func _segments_share_junction(a: StreetSegmentData, b: StreetSegmentData) -> bool:
	return (
		a.start_junction_id == b.start_junction_id
		or a.start_junction_id == b.end_junction_id
		or a.end_junction_id == b.start_junction_id
		or a.end_junction_id == b.end_junction_id
	)


func _segments_share_junction_at(
	a: StreetSegmentData, b: StreetSegmentData, point: Vector3
) -> bool:
	if !_segments_share_junction(a, b):
		return false
	var first_id := _endpoint_junction_at(a, point)
	return !first_id.is_empty() and first_id == _endpoint_junction_at(b, point)


func _endpoint_junction_at(segment: StreetSegmentData, point: Vector3) -> String:
	var start := network_data.find_junction(segment.start_junction_id)
	if start != null and _plan_distance(start.position, point) <= JUNCTION_SNAP_TOLERANCE:
		return start.stable_id
	var end := network_data.find_junction(segment.end_junction_id)
	if end != null and _plan_distance(end.position, point) <= JUNCTION_SNAP_TOLERANCE:
		return end.stable_id
	return ""


func _crossing_junction_at(
	first: StreetSegmentData, second: StreetSegmentData, point: Vector3
) -> String:
	var exact := _endpoint_junction_at(first, point)
	if exact.is_empty():
		exact = _endpoint_junction_at(second, point)
	if !exact.is_empty():
		return exact
	var snap_distance := JUNCTION_SNAP_TOLERANCE
	for segment: StreetSegmentData in [first, second]:
		if segment != null and segment.section_profile != null:
			snap_distance = maxf(
				snap_distance, segment.section_profile.maximum_half_width()
			)
	var best_id := ""
	var best_distance := INF
	for segment: StreetSegmentData in [first, second]:
		if segment == null:
			continue
		for junction_id: String in [segment.start_junction_id, segment.end_junction_id]:
			var junction := network_data.find_junction(junction_id)
			if junction == null or absf(junction.position.y - point.y) > CROSSING_HEIGHT_TOLERANCE:
				continue
			var distance := _plan_distance(junction.position, point)
			if distance > snap_distance or distance >= best_distance:
				continue
			best_distance = distance
			best_id = junction.stable_id
	return best_id


func _nearest_profile_location(profile: PackedVector3Array, point: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var best_distance := INF
	for index in range(profile.size() - 1):
		var closest := _closest_point_on_plan_segment(point, profile[index], profile[index + 1])
		var distance := _plan_distance(point, closest)
		if distance >= best_distance:
			continue
		best_distance = distance
		result = {
			"segment_index": index,
			"point": closest,
			"distance": distance,
		}
	return result


func _closest_point_on_plan_segment(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var origin := Vector2(a.x, a.z)
	var direction := Vector2(b.x - a.x, b.z - a.z)
	var length_squared := direction.length_squared()
	if length_squared <= EPSILON:
		return a
	var target := Vector2(point.x, point.z)
	var t := clampf((target - origin).dot(direction) / length_squared, 0.0, 1.0)
	return a.lerp(b, t)


func _segment_intersection(
	first_a: Vector3, first_b: Vector3, second_a: Vector3, second_b: Vector3
) -> Dictionary:
	var first_origin := Vector2(first_a.x, first_a.z)
	var second_origin := Vector2(second_a.x, second_a.z)
	var first_delta := Vector2(first_b.x - first_a.x, first_b.z - first_a.z)
	var second_delta := Vector2(second_b.x - second_a.x, second_b.z - second_a.z)
	var denominator := first_delta.cross(second_delta)
	if absf(denominator) <= EPSILON:
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
	}


func _remove_duplicate_points(points: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in points:
		if result.is_empty() or _plan_distance(result[result.size() - 1], point) > EPSILON:
			result.append(point)
	return result


func _densify_profile(
	profile: PackedVector3Array, maximum_spacing: float
) -> PackedVector3Array:
	if profile.size() < 2:
		return profile
	var result := PackedVector3Array([profile[0]])
	for index in range(profile.size() - 1):
		var a := profile[index]
		var b := profile[index + 1]
		var run := _plan_distance(a, b)
		var interval_count := maxi(ceili(run / maximum_spacing), 1)
		for interval in range(1, interval_count + 1):
			result.append(a.lerp(b, float(interval) / float(interval_count)))
	return result


func _smooth_profile_heights(
	profile: PackedVector3Array, pass_count: int
) -> PackedVector3Array:
	var result := profile.duplicate()
	if result.size() < 3:
		return result
	for _pass in range(maxi(pass_count, 0)):
		var previous := result.duplicate()
		for index in range(1, result.size() - 1):
			result[index].y = (
				previous[index - 1].y
				+ previous[index].y * 2.0
				+ previous[index + 1].y
			) * 0.25
	return result


func _plan_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


func _plan_direction(a: Vector3, b: Vector3) -> Vector3:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return Vector3.ZERO if delta.length_squared() <= EPSILON else delta.normalized()
