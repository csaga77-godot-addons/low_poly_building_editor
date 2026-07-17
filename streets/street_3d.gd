@tool
class_name Street3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

const StreetGeometry := preload(
	"res://addons/low_poly_building_editor/streets/street_geometry_3d.gd"
)
const StreetProfilePointScript := preload(
	"res://addons/low_poly_building_editor/streets/street_profile_point.gd"
)

const GENERATED_META := &"street_generated"
const PREVIEW_META := &"building_editor_preview"
const MESH_GEOMETRY_VERSION := 3
const EPSILON := 0.00001

signal terrain_profile_resampled(sample_count: int)
signal terrain_corridor_changed()
signal source_geometry_changed

@export var rebuild := false:
	set(value):
		if value:
			call_deferred("rebuild_street_mesh")

## Parent-local plan path. Y is used until a baked profile exists and remains
## the editable control-point height when terrain sampling is not requested.
@export var path_points := PackedVector3Array([
	Vector3.ZERO,
	Vector3(0.0, 0.0, 8.0),
]):
	set(value):
		if path_points == value:
			return
		path_points = value
		if m_is_ready and !m_preserve_profile_on_path_change and !profile_points.is_empty():
			profile_points = []
		_request_rebuild()
		_notify_terrain_corridor_changed()

## Dense, serialized terrain profile. Individual resources expose a Manual
## Height flag so explicit edits survive later terrain resampling.
@export var profile_points: Array[StreetProfilePoint] = []:
	set(value):
		_disconnect_profile_points()
		profile_points = value
		_connect_profile_points()
		_request_rebuild()
		_notify_terrain_corridor_changed()

@export_group("Road")
@export_range(0.1, 20.0, 0.05, "or_greater") var road_width := 3.2:
	set(value):
		road_width = maxf(value, 0.1)
		_request_rebuild()
		_notify_terrain_corridor_changed()
@export_range(0.01, 2.0, 0.01, "or_greater") var road_thickness := 0.18:
	set(value):
		road_thickness = maxf(value, 0.01)
		_request_rebuild()
		_notify_terrain_corridor_changed()
@export var road_color := Color(0.38, 0.37, 0.34, 1.0):
	set(value):
		road_color = value
		_request_rebuild()

@export_group("Kerb")
@export_range(0.01, 2.0, 0.01, "or_greater") var kerb_width := 0.18:
	set(value):
		kerb_width = maxf(value, 0.01)
		_request_rebuild()
		_notify_terrain_corridor_changed()
@export_range(0.01, 1.0, 0.01, "or_greater") var kerb_height := 0.14:
	set(value):
		kerb_height = maxf(value, 0.01)
		_request_rebuild()
@export var kerb_color := Color(0.66, 0.64, 0.59, 1.0):
	set(value):
		kerb_color = value
		_request_rebuild()

@export_group("Footpath")
@export_range(0.05, 10.0, 0.05, "or_greater") var footpath_width := 1.1:
	set(value):
		footpath_width = maxf(value, 0.05)
		_request_rebuild()
		_notify_terrain_corridor_changed()
@export_range(0.01, 2.0, 0.01, "or_greater") var footpath_thickness := 0.16:
	set(value):
		footpath_thickness = maxf(value, 0.01)
		_request_rebuild()
@export var footpath_color := Color(0.72, 0.67, 0.57, 1.0):
	set(value):
		footpath_color = value
		_request_rebuild()

@export_group("Automatic Footpath Stairs")
@export_range(0.0, 89.0, 0.1) var stair_threshold_degrees := 25.0:
	set(value):
		stair_threshold_degrees = clampf(value, 0.0, 89.0)
		_request_rebuild()
		if m_is_ready:
			source_geometry_changed.emit()
@export_range(0.02, 1.0, 0.01, "or_greater") var target_riser_height := 0.16:
	set(value):
		target_riser_height = maxf(value, 0.02)
		if max_riser_height < target_riser_height:
			max_riser_height = target_riser_height
		_request_rebuild()
@export_range(0.02, 1.0, 0.01, "or_greater") var max_riser_height := 0.18:
	set(value):
		max_riser_height = maxf(value, target_riser_height)
		_request_rebuild()
@export_range(0.05, 2.0, 0.01, "or_greater") var min_tread_depth := 0.24:
	set(value):
		min_tread_depth = maxf(value, 0.05)
		_request_rebuild()

@export_group("Terrain Profile")
@export_range(0.1, 10.0, 0.1, "or_greater") var terrain_sample_spacing := 0.5
@export_range(-1.0, 2.0, 0.005) var terrain_clearance := 0.025:
	set(value):
		if is_equal_approx(terrain_clearance, value):
			return
		terrain_clearance = value
		_notify_terrain_corridor_changed()

@export_group("Generation")
@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false
var m_last_build_stats := {}
var m_preserve_profile_on_path_change := false
var m_intersection_cuts: Array[Dictionary] = []
# Miter targets that extend a terminal cross-section so a street's road edge,
# kerb, and footpath reach the shared junction corners of its neighbours. Keyed
# "start"/"end"; each side holds one canonical junction plus left_/right_
# road/kerb/foot Vector3s in the parent-local frame. Recomputed by the resolver,
# never serialized.
var m_end_joins: Dictionary = {}


func _ready() -> void:
	m_is_ready = true
	_connect_profile_points()
	_sync_transform_from_path()
	if !build_on_ready:
		return
	if _generated_mesh_cache_matches(_street_mesh_source_signature()):
		_sync_street_material()
		_rebuild_collision_from_cached_mesh()
	else:
		rebuild_street_mesh()


func set_path_points(points: PackedVector3Array, clear_profile := true) -> void:
	path_points = points
	if clear_profile:
		profile_points = []
	_sync_transform_from_path()
	rebuild_street_mesh()


func get_geometry_profile() -> PackedVector3Array:
	var result := PackedVector3Array()
	if profile_points.size() >= 2:
		for point: StreetProfilePoint in profile_points:
			if point != null:
				result.append(point.position)
	if result.size() >= 2:
		return result
	return path_points.duplicate()


func get_last_build_stats() -> Dictionary:
	return m_last_build_stats.duplicate(true)


func set_intersection_cuts(cuts: Array) -> void:
	set_intersection_geometry(cuts, m_end_joins)


## Applies both the crossing cuts (mid-span clipping) and the endpoint miter
## joins (corner extensions) in a single rebuild.
func set_intersection_geometry(cuts: Array, end_joins: Dictionary) -> void:
	var normalized_cuts := _normalize_intersection_cuts(cuts)
	var normalized_joins := _normalize_end_joins(end_joins)
	if (
		hash(normalized_cuts) == hash(m_intersection_cuts)
		and hash(normalized_joins) == hash(m_end_joins)
	):
		return
	m_intersection_cuts = normalized_cuts
	m_end_joins = normalized_joins
	rebuild_street_mesh()


func _normalize_intersection_cuts(cuts: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for cut: Dictionary in cuts:
		normalized.append({
			"segment_index": int(cut.get("segment_index", -1)),
			"start_t": clampf(float(cut.get("start_t", 0.0)), 0.0, 1.0),
			"end_t": clampf(float(cut.get("end_t", 0.0)), 0.0, 1.0),
			"clip_road": bool(cut.get("clip_road", false)),
		})
	return normalized


func _normalize_end_joins(end_joins: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key: String in ["start", "end"]:
		var side: Dictionary = end_joins.get(key, {})
		if side.is_empty():
			continue
		var entry: Dictionary = {}
		for field: String in [
			"junction",
			"left_road", "left_kerb", "left_foot",
			"right_road", "right_kerb", "right_foot",
		]:
			if side.has(field):
				entry[field] = Vector3(side[field])
		if !entry.is_empty():
			normalized[key] = entry
	return normalized


func get_intersection_cuts() -> Array[Dictionary]:
	return m_intersection_cuts.duplicate(true)


func get_end_joins() -> Dictionary:
	return m_end_joins.duplicate(true)


## Generic terrain-generation contract. LowPolyTerrain3D discovers sources by
## method presence, so the terrain module does not import this editor add-on.
func is_terrain_street_source() -> bool:
	return !has_meta(PREVIEW_META) and path_points.size() >= 2


func get_world_terrain_corridor() -> Dictionary:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return {}
	var world_path := PackedVector3Array()
	for point in get_geometry_profile():
		world_path.append(parent_3d.to_global(point))
	if world_path.size() < 2:
		return {}
	var parent_scale := parent_3d.global_transform.basis.get_scale()
	var horizontal_scale := maxf(absf(parent_scale.x), absf(parent_scale.z))
	return {
		"path": world_path,
		"half_width": (
			road_width * 0.5 + kerb_width + footpath_width
		) * horizontal_scale,
		"bed_depth": maxf(road_thickness + terrain_clearance, 0.01) * absf(parent_scale.y),
		"source": self,
	}


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var profile := get_geometry_profile()
	if profile.size() < 2:
		errors.append("Street3D requires at least two path/profile points.")
		return errors
	for index in range(profile.size() - 1):
		var a := profile[index]
		var b := profile[index + 1]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if run <= EPSILON:
			errors.append("Street profile segment %d has zero horizontal length." % index)
			continue
		var rise := absf(b.y - a.y)
		var slope := rad_to_deg(atan2(rise, run))
		if slope <= stair_threshold_degrees + 0.0001:
			continue
		var minimum_steps := ceili(rise / max_riser_height)
		var maximum_steps := floori(run / min_tread_depth)
		if minimum_steps > maximum_steps or maximum_steps < 1:
			errors.append(
				"Street profile segment %d is too steep for max riser %.3f and min tread %.3f."
				% [index, max_riser_height, min_tread_depth]
			)
	return errors


func rebuild_street_mesh(rebuild_collision := true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
		_clear_generated_children()
	_sync_transform_from_path()
	var errors := get_validation_errors()
	if !errors.is_empty():
		mesh = null
		m_last_build_stats = {"errors": errors}
		return
	var origin := transform.origin
	var local_profile := PackedVector3Array()
	for point in get_geometry_profile():
		local_profile.append(point - origin)
	var result := StreetGeometry.build(local_profile, _geometry_settings())
	var vertices: PackedVector3Array = result["vertices"]
	var indices: PackedInt32Array = result["indices"]
	if vertices.is_empty() or indices.is_empty():
		mesh = null
		m_last_build_stats = {"errors": ["Street geometry produced no faces."]}
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = result["normals"]
	arrays[Mesh.ARRAY_COLOR] = result["colors"]
	arrays[Mesh.ARRAY_INDEX] = indices
	_replace_generated_mesh_surface(arrays)
	_sync_street_material()
	_record_generated_mesh_cache(_street_mesh_source_signature())
	m_last_build_stats = result.duplicate(true)
	m_last_build_stats["errors"] = []
	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func resample_terrain(terrain_provider: Node3D) -> Array[String]:
	var errors: Array[String] = []
	if terrain_provider == null or !terrain_provider.has_method("get_world_surface_height"):
		errors.append("Terrain provider must implement get_world_surface_height(world_position).")
		return errors
	if path_points.size() < 2:
		errors.append("Street path requires at least two control points before sampling terrain.")
		return errors
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		errors.append("Street3D must be parented under a Node3D before terrain sampling.")
		return errors
	var old_manual: Array[StreetProfilePoint] = []
	for old_point: StreetProfilePoint in profile_points:
		if old_point != null and old_point.manual_height:
			old_manual.append(old_point)
	var sampled: Array[StreetProfilePoint] = []
	var distance := 0.0
	for segment_index in range(path_points.size() - 1):
		var a := path_points[segment_index]
		var b := path_points[segment_index + 1]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if run <= EPSILON:
			continue
		var interval_count := maxi(ceili(run / maxf(terrain_sample_spacing, 0.1)), 1)
		var first_interval := 0 if segment_index == 0 else 1
		for interval_index in range(first_interval, interval_count + 1):
			var t := float(interval_index) / float(interval_count)
			var local_point := a.lerp(b, t)
			var station := distance + run * t
			var profile_point := StreetProfilePointScript.new() as StreetProfilePoint
			profile_point.path_distance = station
			var manual_match := _find_manual_profile_match(old_manual, station, local_point)
			if manual_match != null:
				profile_point.position = Vector3(local_point.x, manual_match.position.y, local_point.z)
				profile_point.manual_height = true
			else:
				var world_point := parent_3d.to_global(local_point)
				var sampled_y := float(terrain_provider.call("get_world_surface_height", world_point))
				var sampled_local := parent_3d.to_local(Vector3(world_point.x, sampled_y + terrain_clearance, world_point.z))
				profile_point.position = Vector3(local_point.x, sampled_local.y, local_point.z)
			sampled.append(profile_point)
		distance += run
	profile_points = sampled
	rebuild_street_mesh()
	terrain_profile_resampled.emit(profile_points.size())
	errors.append_array(get_validation_errors())
	return errors


func _find_manual_profile_match(
	manual_points: Array[StreetProfilePoint],
	station: float,
	local_point: Vector3
) -> StreetProfilePoint:
	var tolerance := maxf(terrain_sample_spacing * 0.25, 0.02)
	for point: StreetProfilePoint in manual_points:
		if absf(point.path_distance - station) > tolerance:
			continue
		if Vector2(point.position.x - local_point.x, point.position.z - local_point.z).length() <= tolerance:
			return point
	return null


func _geometry_settings() -> Dictionary:
	return {
		"road_width": road_width,
		"road_thickness": road_thickness,
		"road_color": road_color,
		"kerb_width": kerb_width,
		"kerb_height": kerb_height,
		"kerb_color": kerb_color,
		"footpath_width": footpath_width,
		"footpath_thickness": footpath_thickness,
		"footpath_color": footpath_color,
		"stair_threshold_degrees": stair_threshold_degrees,
		"target_riser_height": target_riser_height,
		"max_riser_height": max_riser_height,
		"min_tread_depth": min_tread_depth,
		"intersection_cuts": m_intersection_cuts,
		"side_end_overrides": _local_side_end_overrides(),
	}


## Converts the parent-local miter joins into the node-local build frame (the
## same frame rebuild_street_mesh uses for the profile) so build() can extend the
## terminal cross-section to them.
func _local_side_end_overrides() -> Dictionary:
	if m_end_joins.is_empty():
		return {}
	var origin := transform.origin
	var result: Dictionary = {}
	for key: String in m_end_joins:
		var side: Dictionary = m_end_joins[key]
		var local_side: Dictionary = {}
		for field: String in side:
			local_side[field] = (side[field] as Vector3) - origin
		result[key] = local_side
	return result


func _street_mesh_source_signature() -> int:
	var serialized_profile: Array = []
	for point: StreetProfilePoint in profile_points:
		if point != null:
			serialized_profile.append([point.path_distance, point.position, point.manual_height])
	return hash([
		MESH_GEOMETRY_VERSION, path_points, serialized_profile,
		road_width, road_thickness, road_color,
		kerb_width, kerb_height, kerb_color,
		footpath_width, footpath_thickness, footpath_color,
		stair_threshold_degrees, target_riser_height, max_riser_height, min_tread_depth,
		m_intersection_cuts, m_end_joins,
	])


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_street_mesh")


func _connect_profile_points() -> void:
	for point: StreetProfilePoint in profile_points:
		if point != null and !point.changed.is_connected(_on_profile_point_changed):
			point.changed.connect(_on_profile_point_changed)


func _disconnect_profile_points() -> void:
	for point: StreetProfilePoint in profile_points:
		if point != null and point.changed.is_connected(_on_profile_point_changed):
			point.changed.disconnect(_on_profile_point_changed)


func _on_profile_point_changed() -> void:
	_request_rebuild()
	_notify_terrain_corridor_changed()


func _notify_terrain_corridor_changed() -> void:
	if m_is_ready:
		terrain_corridor_changed.emit()
		source_geometry_changed.emit()


func _sync_transform_from_path() -> void:
	transform = _authored_transform()


func _authored_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, path_points[0] if !path_points.is_empty() else Vector3.ZERO)


func supports_native_transform() -> bool:
	return true


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	var moved_path := PackedVector3Array()
	for point in path_points:
		moved_path.append(delta * point)
	if !moved_path.is_empty():
		var offset := grid_snap_offset(moved_path[0], grid_step)
		for index in range(moved_path.size()):
			moved_path[index] += offset
		for point: StreetProfilePoint in profile_points:
			if point != null:
				point.position = delta * point.position + offset
	m_preserve_profile_on_path_change = true
	path_points = moved_path
	m_preserve_profile_on_path_change = false
	_sync_transform_from_path()
	rebuild_street_mesh()


func capture_native_transform_state() -> Dictionary:
	var serialized_profile: Array[Dictionary] = []
	for point: StreetProfilePoint in profile_points:
		if point != null:
			serialized_profile.append({
				"path_distance": point.path_distance,
				"position": point.position,
				"manual_height": point.manual_height,
			})
	return {"path_points": path_points, "profile_points": serialized_profile}


func restore_native_transform_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	m_preserve_profile_on_path_change = true
	path_points = PackedVector3Array(state.get("path_points", path_points))
	var restored: Array[StreetProfilePoint] = []
	for entry: Dictionary in state.get("profile_points", []):
		var point := StreetProfilePointScript.new() as StreetProfilePoint
		point.path_distance = float(entry.get("path_distance", 0.0))
		point.position = Vector3(entry.get("position", Vector3.ZERO))
		point.manual_height = bool(entry.get("manual_height", false))
		restored.append(point)
	profile_points = restored
	m_preserve_profile_on_path_change = false
	_sync_transform_from_path()
	rebuild_street_mesh()


func _sync_street_material() -> void:
	var material := _scene_local_material_for_write(material_override as StandardMaterial3D)
	if material == null:
		material = StandardMaterial3D.new()
		material.resource_local_to_scene = true
		material_override = material
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Street side strips are viewed from both the road and surrounding terrain;
	# keeping them double-sided avoids one-sided gaps at mirrored left/right bends.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body(_cached_mesh_vertices(), _cached_mesh_indices())


func _add_collision_body(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var faces := PackedVector3Array()
	for index in indices:
		faces.append(vertices[index])
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	var body := StaticBody3D.new()
	body.name = "StreetCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _clear_generated_children() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.free()
