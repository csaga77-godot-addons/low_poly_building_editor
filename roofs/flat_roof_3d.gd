@tool
class_name FlatRoof3D
extends "res://addons/low_poly_building_editor/roofs/roof_3d.gd"

const StyleGeometry := preload("res://addons/low_poly_building_editor/roofs/roof_style_geometry_3d.gd")
const PolygonPrismGeometry := preload(
	"res://addons/low_poly_building_editor/polygon_prism_geometry_3d.gd"
)

var m_polygon_points := PackedVector3Array()

@export var polygon_points: PackedVector3Array = PackedVector3Array():
	set(value):
		set_roof_polygon(value)
	get:
		return get_roof_polygon()


func get_roof_style() -> String:
	return "flat"


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()


func set_roof_polygon(new_points: PackedVector3Array) -> void:
	var sanitized := _sanitize_polygon_points(new_points)
	var previous_signature := _roof_mesh_source_signature()
	m_polygon_points = sanitized
	if !m_polygon_points.is_empty():
		var bounds := _roof_polygon_parent_bounds(m_polygon_points)
		var base_y := m_polygon_points[0].y
		start_point = Vector3(bounds.position.x, base_y, bounds.position.y)
		end_point = Vector3(bounds.end.x, base_y, bounds.end.y)
		roof_rotation_degrees = 0.0
	if _roof_mesh_source_signature() == previous_signature:
		return
	# Do not rebuild while the scene is still loading. `polygon_points` deserializes
	# before `roof_thickness`/`roof_overhang` (and other roof state), so rebuilding
	# here would bake the mesh with those properties at their defaults; the saved
	# cache signature (recorded from the final values) would then still match and
	# `_ready` would reuse this stale default-geometry mesh, leaving the roof looking
	# like it lost its overhang/thickness even though the inspector shows the saved
	# values. When not ready, just store the polygon and let `_ready` build (or reuse
	# the correctly cached mesh) once every property is deserialized.
	if !m_is_ready:
		return
	_sync_transform_from_points()
	rebuild_roof_mesh()
	source_geometry_changed.emit()


func get_roof_polygon() -> PackedVector3Array:
	return m_polygon_points.duplicate()


func is_polygon_roof() -> bool:
	return !m_polygon_points.is_empty()


func is_roof_polygon_valid(
	points: PackedVector3Array = PackedVector3Array()
) -> bool:
	var candidate := points if !points.is_empty() else m_polygon_points
	if candidate.size() < 3:
		return false
	var local_polygon := PackedVector2Array()
	for point in candidate:
		local_polygon.append(Vector2(point.x, point.z))
	return !Geometry2D.triangulate_polygon(local_polygon).is_empty()


func get_roof_render_polygons() -> Array[PackedVector2Array]:
	if !is_polygon_roof():
		return super.get_roof_render_polygons()
	var bounds := _roof_polygon_parent_bounds(m_polygon_points)
	var local_polygon := PackedVector2Array()
	for point in m_polygon_points:
		local_polygon.append(Vector2(point.x - bounds.position.x, point.z - bounds.position.y))
	if roof_overhang <= RECT_EPSILON:
		return [PolygonPrismGeometry.counter_clockwise_polygon(local_polygon)]
	var offset_polygon := PolygonPrismGeometry.offset_polygon_preserving_vertices(
		local_polygon,
		roof_overhang
	)
	return [offset_polygon]


func get_roof_render_rect() -> Rect2:
	if !is_polygon_roof():
		return super.get_roof_render_rect()
	var result := Rect2()
	var has_bounds := false
	for polygon in get_roof_render_polygons():
		for point in polygon:
			if !has_bounds:
				result = Rect2(point, Vector2.ZERO)
				has_bounds = true
			else:
				result = result.expand(point)
	return result


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	if !is_polygon_roof():
		super(delta, grid_step)
		return
	var raw_points := PackedVector3Array()
	for point in m_polygon_points:
		raw_points.append(delta * point)
	var offset := grid_snap_offset(raw_points[0], grid_step) if raw_points.size() > 0 else Vector3.ZERO
	var new_points := PackedVector3Array()
	for point in raw_points:
		new_points.append(point + offset)
	set_roof_polygon(new_points)


func capture_native_transform_state() -> Dictionary:
	if is_polygon_roof():
		return {"polygon_points": get_roof_polygon()}
	return super()


func restore_native_transform_state(state: Dictionary) -> void:
	if state.has("polygon_points"):
		set_roof_polygon(PackedVector3Array(state["polygon_points"]))
		return
	super(state)


func _clear_custom_footprint() -> void:
	m_polygon_points = PackedVector3Array()


func _has_custom_footprint() -> bool:
	return is_polygon_roof()


func _get_custom_footprint_points() -> PackedVector3Array:
	return get_roof_polygon()


func _is_custom_footprint_valid() -> bool:
	return is_roof_polygon_valid()


func _append_custom_footprint_geometry(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var collision_faces := PackedVector3Array()
	for polygon in get_roof_render_polygons():
		PolygonPrismGeometry.append_prism(
			polygon,
			roof_thickness,
			roof_color,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


func _sanitize_polygon_points(points: PackedVector3Array) -> PackedVector3Array:
	var sanitized := PackedVector3Array()
	if points.is_empty():
		return sanitized
	var base_y := points[0].y
	for point in points:
		var flattened := Vector3(point.x, base_y, point.z)
		if !sanitized.is_empty() and sanitized[sanitized.size() - 1].is_equal_approx(flattened):
			continue
		sanitized.append(flattened)
	if sanitized.size() > 1 and sanitized[0].is_equal_approx(sanitized[sanitized.size() - 1]):
		sanitized.resize(sanitized.size() - 1)
	return sanitized
