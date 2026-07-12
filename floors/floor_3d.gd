@tool
class_name Floor3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

const GENERATED_META := &"floor_generated"
const PREVIEW_META := &"building_editor_preview"
const FLOOR_HOLE_EDGE_EPSILON := 0.001
const FLOOR_HOLE_MIN_SIZE := 0.001
const PolygonPrismGeometry := preload(
	"res://addons/low_poly_building_editor/polygon_prism_geometry_3d.gd"
)

var m_floor_holes: Array[Rect2] = []
var m_floor_hole_polygons: Array[PackedVector2Array] = []
var m_polygon_points: PackedVector3Array = PackedVector3Array()

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_floor_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export var polygon_points: PackedVector3Array = PackedVector3Array():
	set(value):
		var sanitized := _sanitize_polygon_points(value)
		if m_polygon_points == sanitized:
			return
		m_polygon_points = sanitized
		if is_polygon_floor():
			m_floor_holes.clear()
			_sync_legacy_corners_from_polygon()
		_request_rebuild()
	get:
		return m_polygon_points.duplicate()

@export var floor_holes: Array[Rect2] = []:
	set(value):
		var sanitized: Array[Rect2] = []
		if !is_polygon_floor():
			sanitized = _sanitize_floor_holes(value, get_floor_size())
		if _floor_hole_arrays_equal(m_floor_holes, sanitized):
			return
		m_floor_holes = sanitized
		_request_rebuild()
	get:
		return get_floor_holes()

@export var floor_hole_polygons: Array[PackedVector2Array] = []:
	set(value):
		var sanitized := _sanitize_floor_hole_polygons(value)
		if _floor_hole_polygon_arrays_equal(m_floor_hole_polygons, sanitized):
			return
		m_floor_hole_polygons = sanitized
		_request_rebuild()
	get:
		return get_floor_hole_polygons()

@export_range(0.01, 2.0, 0.01, "or_greater") var floor_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(floor_thickness, clamped_value):
			return
		floor_thickness = clamped_value
		_request_rebuild()

@export var floor_color := Color(0.46, 0.40, 0.32, 1.0):
	set(value):
		if floor_color == value:
			return
		floor_color = value
		_request_rebuild()

@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	if is_polygon_floor():
		_sync_legacy_corners_from_polygon()
	m_is_ready = true
	if build_on_ready:
		_sync_transform_from_points()
		if _generated_mesh_cache_matches(_floor_mesh_source_signature()):
			_sync_floor_material()
			_rebuild_collision_from_cached_mesh()
		else:
			rebuild_floor_mesh()


func set_floor_corners(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _floor_mesh_source_signature()
	m_polygon_points = PackedVector3Array()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	if _floor_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_floor_mesh()


func set_floor_polygon(new_points: PackedVector3Array) -> void:
	var sanitized := _sanitize_polygon_points(new_points)
	var previous_signature := _floor_mesh_source_signature()
	m_polygon_points = sanitized
	m_floor_holes.clear()
	m_floor_hole_polygons = _sanitize_floor_hole_polygons(m_floor_hole_polygons)
	_sync_legacy_corners_from_polygon()
	if _floor_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_floor_mesh()


func get_floor_polygon() -> PackedVector3Array:
	return m_polygon_points.duplicate()


func is_polygon_floor() -> bool:
	return !m_polygon_points.is_empty()


func is_floor_polygon_valid(points: PackedVector3Array = PackedVector3Array()) -> bool:
	var candidate := _sanitize_polygon_points(points if !points.is_empty() else m_polygon_points)
	if candidate.size() < 3:
		return false
	var local_polygon := _parent_points_to_plan_polygon(candidate)
	if absf(_signed_polygon_area(local_polygon)) <= FLOOR_HOLE_MIN_SIZE:
		return false
	return !Geometry2D.triangulate_polygon(local_polygon).is_empty()


func get_floor_area() -> float:
	if is_polygon_floor():
		return absf(_signed_polygon_area(_parent_points_to_plan_polygon(m_polygon_points)))
	var size := get_floor_size()
	return size.x * size.y


func contains_local_plan_point(local_point: Vector2) -> bool:
	if !is_polygon_floor():
		var size := get_floor_size()
		return (
			local_point.x >= -FLOOR_HOLE_EDGE_EPSILON
			and local_point.y >= -FLOOR_HOLE_EDGE_EPSILON
			and local_point.x <= size.x + FLOOR_HOLE_EDGE_EPSILON
			and local_point.y <= size.y + FLOOR_HOLE_EDGE_EPSILON
		)
	return Geometry2D.is_point_in_polygon(local_point, _get_local_footprint_polygon())


func set_floor_corners_and_holes(
	new_start: Vector3,
	new_end: Vector3,
	new_holes: Array[Rect2]
) -> void:
	var previous_signature := _floor_mesh_source_signature()
	m_polygon_points = PackedVector3Array()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	m_floor_holes = _sanitize_floor_holes(new_holes, get_floor_size())
	if _floor_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_floor_mesh()


func set_floor_holes(new_holes: Array[Rect2]) -> void:
	var sanitized: Array[Rect2] = []
	if !is_polygon_floor():
		sanitized = _sanitize_floor_holes(new_holes, get_floor_size())
	if _floor_hole_arrays_equal(m_floor_holes, sanitized):
		return
	m_floor_holes = sanitized
	rebuild_floor_mesh()


func set_floor_hole_polygons(new_holes: Array[PackedVector2Array]) -> void:
	var sanitized := _sanitize_floor_hole_polygons(new_holes)
	if _floor_hole_polygon_arrays_equal(m_floor_hole_polygons, sanitized):
		return
	m_floor_hole_polygons = sanitized
	rebuild_floor_mesh()


func get_floor_hole_polygons() -> Array[PackedVector2Array]:
	var holes: Array[PackedVector2Array] = []
	for hole in m_floor_hole_polygons:
		holes.append(hole.duplicate())
	return holes


func get_all_floor_hole_polygons() -> Array[PackedVector2Array]:
	var holes := get_floor_hole_polygons()
	for rect in m_floor_holes:
		holes.append(_rect_to_polygon(rect))
	return holes


func has_any_floor_holes() -> bool:
	return !m_floor_holes.is_empty() or !m_floor_hole_polygons.is_empty()


func can_add_floor_hole_polygon(polygon: PackedVector2Array) -> bool:
	var candidate := _sanitize_plan_polygon(polygon)
	return _is_floor_hole_polygon_valid(candidate, get_all_floor_hole_polygons())


func can_set_floor_hole_polygon(index: int, polygon: PackedVector2Array) -> bool:
	if index < 0 or index >= m_floor_hole_polygons.size():
		return false
	var existing: Array[PackedVector2Array] = []
	for rect in m_floor_holes:
		existing.append(_rect_to_polygon(rect))
	for hole_index in range(m_floor_hole_polygons.size()):
		if hole_index != index:
			existing.append(m_floor_hole_polygons[hole_index])
	return _is_floor_hole_polygon_valid(_sanitize_plan_polygon(polygon), existing)


func get_floor_hole_polygon_from_parent_points(
	parent_points: PackedVector3Array
) -> PackedVector2Array:
	var local_polygon := PackedVector2Array()
	var floor_origin := Vector2(position.x, position.z)
	for point in parent_points:
		local_polygon.append(Vector2(point.x, point.z) - floor_origin)
	return local_polygon


func get_floor_hole_polygons_with_added(
	polygon: PackedVector2Array
) -> Array[PackedVector2Array]:
	var holes := get_floor_hole_polygons()
	holes.append(polygon)
	return _sanitize_floor_hole_polygons(holes)


func get_floor_holes() -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for hole in m_floor_holes:
		holes.append(hole)
	return holes


func get_floor_hole_rect_from_parent_corners(parent_start: Vector3, parent_end: Vector3) -> Rect2:
	var floor_min_x := minf(start_point.x, end_point.x)
	var floor_min_z := minf(start_point.z, end_point.z)
	var rect := _rect_from_parent_corners(parent_start, parent_end)
	rect.position -= Vector2(floor_min_x, floor_min_z)
	return rect


func can_add_floor_hole_from_parent_corners(parent_start: Vector3, parent_end: Vector3) -> bool:
	return can_add_floor_hole_rect(get_floor_hole_rect_from_parent_corners(parent_start, parent_end))


func can_add_floor_hole_rect(rect: Rect2) -> bool:
	if is_polygon_floor():
		return false
	var normalized := _normalized_rect(rect)
	return _is_floor_hole_rect_valid_for_size(normalized, get_floor_size())


func get_floor_holes_merged_with_rect(rect: Rect2) -> Array[Rect2]:
	var holes := get_floor_holes()
	holes.append(rect)
	return _sanitize_floor_holes(holes, get_floor_size())


func floor_hole_rect_intersects_existing(rect: Rect2) -> bool:
	var normalized := _normalized_rect(rect)
	for hole in m_floor_holes:
		if _rects_overlap(normalized, hole):
			return true
	return false


func floor_holes_fit_size(size: Vector2) -> bool:
	if is_polygon_floor():
		return m_floor_holes.is_empty()
	return _floor_hole_arrays_equal(m_floor_holes, _sanitize_floor_holes(m_floor_holes, size))


func has_floor_hole_at_local_point(local_point: Vector2) -> bool:
	for hole in m_floor_holes:
		var hole_end := _rect_end(hole)
		if (
			local_point.x > hole.position.x + FLOOR_HOLE_EDGE_EPSILON
			and local_point.x < hole_end.x - FLOOR_HOLE_EDGE_EPSILON
			and local_point.y > hole.position.y + FLOOR_HOLE_EDGE_EPSILON
			and local_point.y < hole_end.y - FLOOR_HOLE_EDGE_EPSILON
		):
			return true
	for hole in m_floor_hole_polygons:
		if Geometry2D.is_point_in_polygon(local_point, hole):
			return true
	return false


func get_floor_size() -> Vector2:
	if is_polygon_floor() and !m_polygon_points.is_empty():
		var bounds := _polygon_parent_bounds(m_polygon_points)
		return bounds.size
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func rebuild_floor_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_floor_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return
	if is_polygon_floor() and !is_floor_polygon_valid():
		mesh = null
		return
	var mesh_holes: Array[Rect2] = []
	if !is_polygon_floor():
		mesh_holes = _sanitize_floor_holes(m_floor_holes, size)
	var polygon_holes := get_all_floor_hole_polygons()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	if !m_floor_hole_polygons.is_empty():
		_append_polygon_floor_geometry_with_holes(
			_get_local_outer_polygon(),
			polygon_holes,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)
	elif is_polygon_floor():
		_append_polygon_floor_geometry(
			_get_local_footprint_polygon(),
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)
	else:
		_append_floor_geometry(
			size.x,
			size.y,
			mesh_holes,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_floor_mesh_resource(arrays)
	_sync_floor_material()
	_record_generated_mesh_cache(_floor_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body(collision_faces)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_floor_mesh")


func _floor_mesh_source_signature() -> int:
	return hash([
		start_point,
		end_point,
		m_polygon_points,
		get_floor_holes(),
		get_floor_hole_polygons(),
		floor_thickness,
		floor_color,
	])


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body(_cached_mesh_triangle_faces())


func _sync_transform_from_points() -> void:
	transform = _authored_transform()


func _authored_transform() -> Transform3D:
	if is_polygon_floor() and !m_polygon_points.is_empty():
		var bounds := _polygon_parent_bounds(m_polygon_points)
		return Transform3D(
			Basis.IDENTITY,
			Vector3(bounds.position.x, m_polygon_points[0].y, bounds.position.y)
		)
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Transform3D(Basis.IDENTITY, Vector3(min_x, start_point.y, min_z))


func supports_native_transform() -> bool:
	return true


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	# Snap the placement to the grid via one shared offset so the scaled/rotated
	# footprint keeps its exact size and shape. The floor derives its node
	# transform from its minimum X/Z corner, so the offset must snap that anchor
	# onto the grid — snapping any other corner would shift the anchor off the
	# grid and move the slab's position (e.g. when start_point is the far corner
	# or the scale is off-grid).
	var hole_parent_polygons := _floor_hole_parent_polygons()
	if is_polygon_floor():
		var polygon := get_floor_polygon()
		var raw_polygon := PackedVector3Array()
		for point in polygon:
			raw_polygon.append(delta * point)
		var polygon_offset := (
			grid_snap_offset(_parent_points_anchor(raw_polygon), grid_step)
			if raw_polygon.size() > 0 else Vector3.ZERO
		)
		var new_polygon := PackedVector3Array()
		for point in raw_polygon:
			new_polygon.append(point + polygon_offset)
		set_floor_polygon(new_polygon)
		_restore_transformed_floor_holes(hole_parent_polygons, delta, polygon_offset)
		return
	# A rotated native edit promotes the rectangle to polygon storage, matching
	# how manual rectangle reshaping already promotes to polygon points.
	if absf(native_delta_yaw_degrees(delta)) > 0.5:
		var corners := PackedVector3Array([
			Vector3(start_point.x, start_point.y, start_point.z),
			Vector3(end_point.x, start_point.y, start_point.z),
			Vector3(end_point.x, start_point.y, end_point.z),
			Vector3(start_point.x, start_point.y, end_point.z),
		])
		var raw_corners := PackedVector3Array()
		for corner in corners:
			raw_corners.append(delta * corner)
		var corner_offset := grid_snap_offset(_parent_points_anchor(raw_corners), grid_step)
		var promoted := PackedVector3Array()
		for corner in raw_corners:
			promoted.append(corner + corner_offset)
		set_floor_polygon(promoted)
		_restore_transformed_floor_holes(hole_parent_polygons, delta, corner_offset)
		return
	var raw_start := delta * start_point
	var raw_end := delta * end_point
	var raw_anchor := Vector3(
		minf(raw_start.x, raw_end.x),
		raw_start.y,
		minf(raw_start.z, raw_end.z)
	)
	var offset := grid_snap_offset(raw_anchor, grid_step)
	set_floor_corners(raw_start + offset, raw_end + offset)
	_restore_transformed_floor_holes(hole_parent_polygons, delta, offset)


## Parent-space anchor (minimum X/Z corner) of a set of transformed footprint
## points. Mirrors how `_authored_transform()` places the node origin, so the
## grid snap moves that same anchor and keeps the slab's position stable.
func _parent_points_anchor(points: PackedVector3Array) -> Vector3:
	var bounds := _polygon_parent_bounds(points)
	return Vector3(bounds.position.x, points[0].y, bounds.position.y)


func capture_native_transform_state() -> Dictionary:
	if is_polygon_floor():
		return {
			"polygon_points": get_floor_polygon(),
			"floor_holes": get_floor_holes(),
			"floor_hole_polygons": get_floor_hole_polygons(),
		}
	return {
		"start_point": start_point,
		"end_point": end_point,
		"floor_holes": get_floor_holes(),
		"floor_hole_polygons": get_floor_hole_polygons(),
	}


func restore_native_transform_state(state: Dictionary) -> void:
	if state.has("polygon_points"):
		set_floor_polygon(PackedVector3Array(state["polygon_points"]))
	elif state.has("start_point"):
		set_floor_corners(Vector3(state["start_point"]), Vector3(state["end_point"]))
	_restore_floor_holes_from_state(state)


func _floor_hole_parent_polygons() -> Array[PackedVector3Array]:
	var parent_polygons: Array[PackedVector3Array] = []
	if !has_any_floor_holes():
		return parent_polygons
	var origin := _authored_transform().origin
	for hole in get_all_floor_hole_polygons():
		var parent_polygon := PackedVector3Array()
		for point in hole:
			parent_polygon.append(Vector3(origin.x + point.x, origin.y, origin.z + point.y))
		parent_polygons.append(parent_polygon)
	return parent_polygons


func _restore_transformed_floor_holes(
	hole_parent_polygons: Array[PackedVector3Array],
	delta: Transform3D,
	offset: Vector3
) -> void:
	if hole_parent_polygons.is_empty():
		m_floor_holes.clear()
		m_floor_hole_polygons.clear()
		return
	var origin := _authored_transform().origin
	var local_holes: Array[PackedVector2Array] = []
	for parent_polygon in hole_parent_polygons:
		var local_hole := PackedVector2Array()
		for point in parent_polygon:
			var transformed := delta * point + offset
			local_hole.append(Vector2(transformed.x - origin.x, transformed.z - origin.z))
		local_holes.append(local_hole)
	m_floor_holes.clear()
	set_floor_hole_polygons(local_holes)


func _restore_floor_holes_from_state(state: Dictionary) -> void:
	var rect_holes: Array[Rect2] = []
	for rect in state.get("floor_holes", []):
		rect_holes.append(Rect2(rect))
	var polygon_holes: Array[PackedVector2Array] = []
	for hole in state.get("floor_hole_polygons", []):
		polygon_holes.append(PackedVector2Array(hole))
	m_floor_holes = _sanitize_floor_holes(rect_holes, get_floor_size()) if !is_polygon_floor() else []
	m_floor_hole_polygons = _sanitize_floor_hole_polygons(polygon_holes)
	rebuild_floor_mesh()


func _append_polygon_floor_geometry(
	polygon: PackedVector2Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	PolygonPrismGeometry.append_prism(
		polygon,
		floor_thickness,
		floor_color,
		vertices,
		normals,
		colors,
		indices,
		collision_faces
	)


func _append_polygon_floor_geometry_with_holes(
	outer_polygon: PackedVector2Array,
	holes: Array[PackedVector2Array],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var normalized_outer := _counter_clockwise_polygon(outer_polygon)
	var visible_polygons: Array[PackedVector2Array] = [normalized_outer]
	var outer_bounds := _plan_polygon_bounds(normalized_outer)
	for hole in holes:
		var cutter := _hole_polygon_with_render_slit(hole, outer_bounds)
		var next_visible: Array[PackedVector2Array] = []
		for visible in visible_polygons:
			for clipped in Geometry2D.clip_polygons(visible, cutter):
				var normalized_clip := _sanitize_plan_polygon(clipped)
				if normalized_clip.size() >= 3 and absf(_signed_polygon_area(normalized_clip)) > FLOOR_HOLE_MIN_SIZE:
					next_visible.append(_counter_clockwise_polygon(normalized_clip))
		visible_polygons = next_visible

	for visible in visible_polygons:
		_append_polygon_horizontal_faces(
			visible,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)
	_append_polygon_boundary_sides(
		normalized_outer,
		false,
		vertices,
		normals,
		colors,
		indices,
		collision_faces
	)
	var merged_outlines := _merge_hole_outlines(holes)
	for index in range(merged_outlines.size()):
		# A hole outline nested inside another outline is an enclosed solid
		# floor island, so its walls face outward like the floor's outer edge.
		var nested := false
		for other_index in range(merged_outlines.size()):
			if other_index == index:
				continue
			if _polygon_contains_polygon(merged_outlines[other_index], merged_outlines[index]):
				nested = !nested
		_append_polygon_boundary_sides(
			_counter_clockwise_polygon(merged_outlines[index]),
			!nested,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


func _append_polygon_horizontal_faces(
	polygon: PackedVector2Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var triangle_indices := Geometry2D.triangulate_polygon(polygon)
	for triangle_start in range(0, triangle_indices.size(), 3):
		var a_2d := polygon[triangle_indices[triangle_start]]
		var b_2d := polygon[triangle_indices[triangle_start + 1]]
		var c_2d := polygon[triangle_indices[triangle_start + 2]]
		var top_a := Vector3(a_2d.x, 0.0, a_2d.y)
		var top_b := Vector3(b_2d.x, 0.0, b_2d.y)
		var top_c := Vector3(c_2d.x, 0.0, c_2d.y)
		_append_triangle(
			vertices, normals, colors, indices, collision_faces,
			top_a, top_b, top_c, Vector3.UP
		)
		_append_triangle(
			vertices, normals, colors, indices, collision_faces,
			top_a + Vector3.DOWN * floor_thickness,
			top_c + Vector3.DOWN * floor_thickness,
			top_b + Vector3.DOWN * floor_thickness,
			Vector3.DOWN
		)


func _append_polygon_boundary_sides(
	polygon: PackedVector2Array,
	invert: bool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	for point_index in range(polygon.size()):
		var next_index := (point_index + 1) % polygon.size()
		var a_2d := polygon[point_index]
		var b_2d := polygon[next_index]
		var edge := b_2d - a_2d
		var outward := Vector3(edge.y, 0.0, -edge.x).normalized()
		var top_a := Vector3(a_2d.x, 0.0, a_2d.y)
		var top_b := Vector3(b_2d.x, 0.0, b_2d.y)
		if invert:
			_append_quad(
				vertices, normals, colors, indices, collision_faces,
				top_b,
				top_a,
				top_a + Vector3.DOWN * floor_thickness,
				top_b + Vector3.DOWN * floor_thickness,
				-outward
			)
		else:
			_append_quad(
				vertices, normals, colors, indices, collision_faces,
				top_a,
				top_b,
				top_b + Vector3.DOWN * floor_thickness,
				top_a + Vector3.DOWN * floor_thickness,
				outward
			)


func _hole_polygon_with_render_slit(
	hole: PackedVector2Array,
	outer_bounds: Rect2
) -> PackedVector2Array:
	var normalized := _counter_clockwise_polygon(hole)
	var rightmost := normalized[0]
	for point in normalized:
		if point.x > rightmost.x or (is_equal_approx(point.x, rightmost.x) and point.y < rightmost.y):
			rightmost = point
	var slit_half_width := 0.00001
	var slit := PackedVector2Array([
		Vector2(rightmost.x - slit_half_width, rightmost.y - slit_half_width),
		Vector2(outer_bounds.end.x + 0.01, rightmost.y - slit_half_width),
		Vector2(outer_bounds.end.x + 0.01, rightmost.y + slit_half_width),
		Vector2(rightmost.x - slit_half_width, rightmost.y + slit_half_width),
	])
	var merged := Geometry2D.merge_polygons(normalized, slit)
	return merged[0] if !merged.is_empty() else normalized


func _merge_hole_outlines(holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Combine holes that overlap or share an edge so the shared internal edge is
	# never walled, leaving one clean opening instead of a stray interior wall.
	var outlines: Array[PackedVector2Array] = []
	for hole in holes:
		if hole.size() >= 3:
			outlines.append(hole.duplicate())
	var changed := true
	while changed:
		changed = false
		for i in range(outlines.size()):
			for j in range(i + 1, outlines.size()):
				var union := Geometry2D.merge_polygons(outlines[i], outlines[j])
				if !_hole_outlines_connected(union):
					continue
				var combined: Array[PackedVector2Array] = []
				for piece in union:
					if piece.size() >= 3:
						combined.append(piece)
				outlines.remove_at(j)
				outlines.remove_at(i)
				outlines.append_array(combined)
				changed = true
				break
			if changed:
				break
	return outlines


func _hole_outlines_connected(union: Array[PackedVector2Array]) -> bool:
	# Only treat holes as merged when their union collapses to a single simple
	# polygon. Disjoint holes return two boundaries, and a ring of holes returns
	# an outer boundary plus an enclosed floor island; both must stay separate so
	# their walls are preserved.
	return union.size() == 1 and union[0].size() >= 3


func _polygon_contains_polygon(outer: PackedVector2Array, inner: PackedVector2Array) -> bool:
	if outer.size() < 3 or inner.is_empty():
		return false
	for point in inner:
		if !Geometry2D.is_point_in_polygon(point, outer):
			return false
	return true


func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c]))
	for _index in range(3):
		normals.append(normal)
		colors.append(floor_color)
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	collision_faces.append_array(PackedVector3Array([a, b, c]))


func _get_local_footprint_polygon() -> PackedVector2Array:
	var bounds := _polygon_parent_bounds(m_polygon_points)
	var polygon := PackedVector2Array()
	for point in m_polygon_points:
		polygon.append(Vector2(point.x - bounds.position.x, point.z - bounds.position.y))
	return polygon


func _get_local_outer_polygon() -> PackedVector2Array:
	if is_polygon_floor():
		return _get_local_footprint_polygon()
	var size := get_floor_size()
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])


func _parent_points_to_plan_polygon(points: PackedVector3Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(point.x, point.z))
	return polygon


func _polygon_parent_bounds(points: PackedVector3Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := Vector2(points[0].x, points[0].z)
	var max_point := min_point
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.z)
	return Rect2(min_point, max_point - min_point)


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


func _sanitize_plan_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var sanitized := PackedVector2Array()
	for point in points:
		if !sanitized.is_empty() and sanitized[sanitized.size() - 1].distance_to(point) <= FLOOR_HOLE_EDGE_EPSILON:
			continue
		sanitized.append(point)
	if sanitized.size() > 1 and sanitized[0].distance_to(sanitized[sanitized.size() - 1]) <= FLOOR_HOLE_EDGE_EPSILON:
		sanitized.resize(sanitized.size() - 1)
	return sanitized


func _sanitize_floor_hole_polygons(
	holes: Array[PackedVector2Array]
) -> Array[PackedVector2Array]:
	var sanitized: Array[PackedVector2Array] = []
	var occupied: Array[PackedVector2Array] = []
	for rect in m_floor_holes:
		occupied.append(_rect_to_polygon(rect))
	for hole in holes:
		var candidate := _sanitize_plan_polygon(hole)
		if !_is_floor_hole_polygon_valid(candidate, occupied):
			continue
		candidate = _counter_clockwise_polygon(candidate)
		sanitized.append(candidate)
		occupied.append(candidate)
	return sanitized


func _is_floor_hole_polygon_valid(
	candidate: PackedVector2Array,
	_existing: Array[PackedVector2Array]
) -> bool:
	# Holes may overlap or touch each other; overlapping holes are merged into a
	# single opening at mesh time (see _merge_hole_outlines), matching the union
	# behavior of legacy rect holes. A hole only has to stay inside the floor
	# slab and clear of its outer edge.
	if candidate.size() < 3 or Geometry2D.triangulate_polygon(candidate).is_empty():
		return false
	var candidate_area := absf(_signed_polygon_area(candidate))
	if candidate_area <= FLOOR_HOLE_MIN_SIZE:
		return false
	var outer := _counter_clockwise_polygon(_get_local_outer_polygon())
	var intersection_area := 0.0
	for clipped in Geometry2D.intersect_polygons(candidate, outer):
		intersection_area += absf(_signed_polygon_area(clipped))
	if absf(intersection_area - candidate_area) > FLOOR_HOLE_EDGE_EPSILON:
		return false
	for point in candidate:
		if _distance_to_polygon_boundary(point, outer) <= FLOOR_HOLE_EDGE_EPSILON:
			return false
	return true


func _distance_to_polygon_boundary(point: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for index in range(polygon.size()):
		var edge_start := polygon[index]
		var edge_end := polygon[(index + 1) % polygon.size()]
		var edge := edge_end - edge_start
		var length_squared := edge.length_squared()
		var closest := edge_start
		if length_squared > FLOOR_HOLE_MIN_SIZE:
			var ratio := clampf((point - edge_start).dot(edge) / length_squared, 0.0, 1.0)
			closest = edge_start + edge * ratio
		best = minf(best, point.distance_to(closest))
	return best


func _rect_to_polygon(rect: Rect2) -> PackedVector2Array:
	var rect_end := rect.end
	return PackedVector2Array([
		rect.position,
		Vector2(rect_end.x, rect.position.y),
		rect_end,
		Vector2(rect.position.x, rect_end.y),
	])


func _plan_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_point := polygon[0]
	var max_point := polygon[0]
	for point in polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _floor_hole_polygon_arrays_equal(
	a: Array[PackedVector2Array],
	b: Array[PackedVector2Array]
) -> bool:
	if a.size() != b.size():
		return false
	for hole_index in range(a.size()):
		if a[hole_index].size() != b[hole_index].size():
			return false
		for point_index in range(a[hole_index].size()):
			if a[hole_index][point_index].distance_to(b[hole_index][point_index]) > FLOOR_HOLE_EDGE_EPSILON:
				return false
	return true


func _sync_legacy_corners_from_polygon() -> void:
	if m_polygon_points.is_empty():
		return
	var bounds := _polygon_parent_bounds(m_polygon_points)
	var base_y := m_polygon_points[0].y
	start_point = Vector3(bounds.position.x, base_y, bounds.position.y)
	end_point = Vector3(bounds.end.x, base_y, bounds.end.y)


func _signed_polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for index in range(polygon.size()):
		var point := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += point.x * next.y - next.x * point.y
	return twice_area * 0.5


func _counter_clockwise_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var normalized := polygon.duplicate()
	if _signed_polygon_area(normalized) < 0.0:
		normalized.reverse()
	return normalized


func _append_floor_geometry(
	width: float,
	depth: float,
	holes: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var visible_rects := _visible_floor_rects(Vector2(width, depth), holes)
	for rect in visible_rects:
		_append_horizontal_rect(
			rect,
			0.0,
			Vector3.UP,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)
		_append_horizontal_rect(
			rect,
			-floor_thickness,
			Vector3.DOWN,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	_append_outer_floor_sides(width, depth, vertices, normals, colors, indices, collision_faces)
	_append_floor_hole_boundary_sides(holes, vertices, normals, colors, indices, collision_faces)


func _append_outer_floor_sides(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var top_min_min := Vector3.ZERO
	var top_max_min := Vector3(width, 0.0, 0.0)
	var top_max_max := Vector3(width, 0.0, depth)
	var top_min_max := Vector3(0.0, 0.0, depth)
	var bottom_min_min := Vector3(0.0, -floor_thickness, 0.0)
	var bottom_max_min := Vector3(width, -floor_thickness, 0.0)
	var bottom_max_max := Vector3(width, -floor_thickness, depth)
	var bottom_min_max := Vector3(0.0, -floor_thickness, depth)

	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_min_min,
		bottom_min_min,
		bottom_min_max,
		top_min_max,
		Vector3.LEFT
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_max_min,
		top_max_max,
		bottom_max_max,
		bottom_max_min,
		Vector3.RIGHT
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_min_min,
		top_max_min,
		bottom_max_min,
		bottom_min_min,
		Vector3.FORWARD
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_min_max,
		bottom_min_max,
		bottom_max_max,
		top_max_max,
		Vector3.BACK
	)


func _append_horizontal_rect(
	rect: Rect2,
	y: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var rect_end := _rect_end(rect)
	if normal.dot(Vector3.UP) > 0.0:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(rect.position.x, y, rect.position.y),
			Vector3(rect.position.x, y, rect_end.y),
			Vector3(rect_end.x, y, rect_end.y),
			Vector3(rect_end.x, y, rect.position.y),
			normal
		)
	else:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(rect.position.x, y, rect.position.y),
			Vector3(rect_end.x, y, rect.position.y),
			Vector3(rect_end.x, y, rect_end.y),
			Vector3(rect.position.x, y, rect_end.y),
			normal
		)


func _append_floor_hole_boundary_sides(
	holes: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	for hole in holes:
		_append_floor_hole_boundary_for_rect(
			hole,
			holes,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


func _append_floor_hole_boundary_for_rect(
	hole: Rect2,
	holes: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var hole_end := _rect_end(hole)
	var intervals := _visible_hole_edge_intervals(hole.position.y, hole_end.y, _hole_left_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_x_side(
			hole.position.x,
			interval.x,
			interval.y,
			Vector3.RIGHT,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	intervals = _visible_hole_edge_intervals(hole.position.y, hole_end.y, _hole_right_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_x_side(
			hole_end.x,
			interval.x,
			interval.y,
			Vector3.LEFT,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	intervals = _visible_hole_edge_intervals(hole.position.x, hole_end.x, _hole_min_z_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_z_side(
			hole.position.y,
			interval.x,
			interval.y,
			Vector3.BACK,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	intervals = _visible_hole_edge_intervals(hole.position.x, hole_end.x, _hole_max_z_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_z_side(
			hole_end.y,
			interval.x,
			interval.y,
			Vector3.FORWARD,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


func _append_floor_hole_x_side(
	x: float,
	z_start: float,
	z_end: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	if normal.dot(Vector3.RIGHT) > 0.0:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x, 0.0, z_start),
			Vector3(x, 0.0, z_end),
			Vector3(x, -floor_thickness, z_end),
			Vector3(x, -floor_thickness, z_start),
			normal
		)
	else:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x, 0.0, z_start),
			Vector3(x, -floor_thickness, z_start),
			Vector3(x, -floor_thickness, z_end),
			Vector3(x, 0.0, z_end),
			normal
		)


func _append_floor_hole_z_side(
	z: float,
	x_start: float,
	x_end: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	if normal.dot(Vector3.BACK) > 0.0:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x_start, 0.0, z),
			Vector3(x_start, -floor_thickness, z),
			Vector3(x_end, -floor_thickness, z),
			Vector3(x_end, 0.0, z),
			normal
		)
	else:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x_start, 0.0, z),
			Vector3(x_end, 0.0, z),
			Vector3(x_end, -floor_thickness, z),
			Vector3(x_start, -floor_thickness, z),
			normal
		)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	for _index in range(4):
		normals.append(normal)
		colors.append(floor_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	collision_faces.append(a)
	collision_faces.append(c)
	collision_faces.append(b)
	collision_faces.append(a)
	collision_faces.append(d)
	collision_faces.append(c)


func _visible_floor_rects(size: Vector2, holes: Array[Rect2]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append(Rect2(Vector2.ZERO, size))
	for hole in holes:
		var next_rects: Array[Rect2] = []
		for rect in rects:
			_append_rect_difference(next_rects, rect, hole)
		rects = next_rects
	return rects


func _append_rect_difference(output: Array[Rect2], rect: Rect2, cutter: Rect2) -> void:
	var rect_end := _rect_end(rect)
	var cutter_end := _rect_end(cutter)
	var intersect_min_x := maxf(rect.position.x, cutter.position.x)
	var intersect_min_y := maxf(rect.position.y, cutter.position.y)
	var intersect_max_x := minf(rect_end.x, cutter_end.x)
	var intersect_max_y := minf(rect_end.y, cutter_end.y)
	if (
		intersect_max_x <= intersect_min_x + FLOOR_HOLE_MIN_SIZE
		or intersect_max_y <= intersect_min_y + FLOOR_HOLE_MIN_SIZE
	):
		output.append(rect)
		return

	_append_rect_if_area(
		output,
		Rect2(
			rect.position,
			Vector2(intersect_min_x - rect.position.x, rect.size.y)
		)
	)
	_append_rect_if_area(
		output,
		Rect2(
			Vector2(intersect_max_x, rect.position.y),
			Vector2(rect_end.x - intersect_max_x, rect.size.y)
		)
	)
	_append_rect_if_area(
		output,
		Rect2(
			Vector2(intersect_min_x, rect.position.y),
			Vector2(intersect_max_x - intersect_min_x, intersect_min_y - rect.position.y)
		)
	)
	_append_rect_if_area(
		output,
		Rect2(
			Vector2(intersect_min_x, intersect_max_y),
			Vector2(intersect_max_x - intersect_min_x, rect_end.y - intersect_max_y)
		)
	)


func _append_rect_if_area(output: Array[Rect2], rect: Rect2) -> void:
	if rect.size.x <= FLOOR_HOLE_MIN_SIZE or rect.size.y <= FLOOR_HOLE_MIN_SIZE:
		return
	output.append(rect)


func _sanitize_floor_holes(holes: Array[Rect2], size: Vector2) -> Array[Rect2]:
	var valid_holes: Array[Rect2] = []
	if size.x <= FLOOR_HOLE_MIN_SIZE or size.y <= FLOOR_HOLE_MIN_SIZE:
		return valid_holes
	for hole in holes:
		var normalized := _normalized_rect(hole)
		if !_is_floor_hole_rect_valid_for_size(normalized, size):
			continue
		valid_holes.append(normalized)
	return _floor_hole_union_rects(valid_holes)


func _is_floor_hole_rect_valid_for_size(rect: Rect2, size: Vector2) -> bool:
	var rect_end := _rect_end(rect)
	return (
		rect.size.x > FLOOR_HOLE_MIN_SIZE
		and rect.size.y > FLOOR_HOLE_MIN_SIZE
		and rect.position.x > FLOOR_HOLE_EDGE_EPSILON
		and rect.position.y > FLOOR_HOLE_EDGE_EPSILON
		and rect_end.x < size.x - FLOOR_HOLE_EDGE_EPSILON
		and rect_end.y < size.y - FLOOR_HOLE_EDGE_EPSILON
	)


func _floor_hole_union_rects(holes: Array[Rect2]) -> Array[Rect2]:
	var union_rects: Array[Rect2] = []
	if holes.is_empty():
		return union_rects

	var x_values := _sorted_hole_coordinates(holes, true)
	var y_values := _sorted_hole_coordinates(holes, false)
	var active_rects: Array[Rect2] = []
	for y_index in range(y_values.size() - 1):
		var y_start := float(y_values[y_index])
		var y_end := float(y_values[y_index + 1])
		if y_end <= y_start + FLOOR_HOLE_MIN_SIZE:
			continue
		var row_runs := _floor_hole_row_runs(holes, x_values, y_start, y_end)
		if row_runs.is_empty():
			union_rects.append_array(active_rects)
			active_rects.clear()
			continue
		var next_active: Array[Rect2] = []
		var consumed_active: Array[bool] = []
		consumed_active.resize(active_rects.size())
		for index in range(consumed_active.size()):
			consumed_active[index] = false
		for row_run in row_runs:
			var merged := false
			for active_index in range(active_rects.size()):
				if consumed_active[active_index]:
					continue
				var active := active_rects[active_index]
				if (
					_rect_spans_match_x(active, row_run)
					and is_equal_approx(_rect_end(active).y, row_run.position.y)
				):
					active.size.y += row_run.size.y
					next_active.append(active)
					consumed_active[active_index] = true
					merged = true
					break
			if !merged:
				next_active.append(row_run)
		for active_index in range(active_rects.size()):
			if !consumed_active[active_index]:
				union_rects.append(active_rects[active_index])
		active_rects = next_active
	union_rects.append_array(active_rects)
	union_rects.sort_custom(_sort_floor_hole_rects)
	return union_rects


func _floor_hole_row_runs(
	holes: Array[Rect2],
	x_values: Array[float],
	y_start: float,
	y_end: float
) -> Array[Rect2]:
	var runs: Array[Rect2] = []
	var run_start := 0.0
	var in_run := false
	for x_index in range(x_values.size() - 1):
		var x_start := float(x_values[x_index])
		var x_end := float(x_values[x_index + 1])
		if x_end <= x_start + FLOOR_HOLE_MIN_SIZE:
			continue
		var center := Vector2((x_start + x_end) * 0.5, (y_start + y_end) * 0.5)
		var filled := _point_inside_any_hole(center, holes)
		if filled and !in_run:
			run_start = x_start
			in_run = true
		elif !filled and in_run:
			runs.append(Rect2(Vector2(run_start, y_start), Vector2(x_start - run_start, y_end - y_start)))
			in_run = false
	if in_run:
		var x_end := float(x_values[x_values.size() - 1])
		runs.append(Rect2(Vector2(run_start, y_start), Vector2(x_end - run_start, y_end - y_start)))
	return runs


func _point_inside_any_hole(point: Vector2, holes: Array[Rect2]) -> bool:
	for hole in holes:
		var hole_end := _rect_end(hole)
		if (
			point.x > hole.position.x - FLOOR_HOLE_EDGE_EPSILON
			and point.x < hole_end.x + FLOOR_HOLE_EDGE_EPSILON
			and point.y > hole.position.y - FLOOR_HOLE_EDGE_EPSILON
			and point.y < hole_end.y + FLOOR_HOLE_EDGE_EPSILON
		):
			return true
	return false


func _sorted_hole_coordinates(holes: Array[Rect2], use_x: bool) -> Array[float]:
	var values: Array[float] = []
	for hole in holes:
		var hole_end := _rect_end(hole)
		values.append(hole.position.x if use_x else hole.position.y)
		values.append(hole_end.x if use_x else hole_end.y)
	values.sort()
	var unique_values: Array[float] = []
	for value in values:
		if unique_values.is_empty():
			unique_values.append(value)
			continue
		if absf(value - float(unique_values[unique_values.size() - 1])) > FLOOR_HOLE_EDGE_EPSILON:
			unique_values.append(value)
	return unique_values


func _rect_spans_match_x(a: Rect2, b: Rect2) -> bool:
	var a_end := _rect_end(a)
	var b_end := _rect_end(b)
	return (
		is_equal_approx(a.position.x, b.position.x)
		and is_equal_approx(a_end.x, b_end.x)
	)


func _hole_left_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	for other in holes:
		if _rects_equal(hole, other):
			continue
		var other_end := _rect_end(other)
		if absf(other_end.x - hole.position.x) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.y, _rect_end(hole).y, other.position.y, other_end.y)
	return cutters


func _hole_right_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	var hole_end := _rect_end(hole)
	for other in holes:
		if _rects_equal(hole, other):
			continue
		if absf(other.position.x - hole_end.x) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.y, hole_end.y, other.position.y, _rect_end(other).y)
	return cutters


func _hole_min_z_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	for other in holes:
		if _rects_equal(hole, other):
			continue
		var other_end := _rect_end(other)
		if absf(other_end.y - hole.position.y) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.x, _rect_end(hole).x, other.position.x, other_end.x)
	return cutters


func _hole_max_z_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	var hole_end := _rect_end(hole)
	for other in holes:
		if _rects_equal(hole, other):
			continue
		if absf(other.position.y - hole_end.y) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.x, hole_end.x, other.position.x, _rect_end(other).x)
	return cutters


func _append_overlap_interval(
	intervals: Array[Vector2],
	base_start: float,
	base_end: float,
	cutter_start: float,
	cutter_end: float
) -> void:
	var overlap_start := maxf(base_start, cutter_start)
	var overlap_end := minf(base_end, cutter_end)
	if overlap_end <= overlap_start + FLOOR_HOLE_MIN_SIZE:
		return
	intervals.append(Vector2(overlap_start, overlap_end))


func _visible_hole_edge_intervals(start: float, end: float, cutters: Array[Vector2]) -> Array[Vector2]:
	var visible: Array[Vector2] = []
	if end <= start + FLOOR_HOLE_MIN_SIZE:
		return visible
	if cutters.is_empty():
		visible.append(Vector2(start, end))
		return visible
	cutters.sort_custom(_sort_intervals)
	var cursor := start
	for cutter in cutters:
		var cutter_start := clampf(cutter.x, start, end)
		var cutter_end := clampf(cutter.y, start, end)
		if cutter_end <= cursor + FLOOR_HOLE_MIN_SIZE:
			continue
		if cutter_start > cursor + FLOOR_HOLE_MIN_SIZE:
			visible.append(Vector2(cursor, cutter_start))
		cursor = maxf(cursor, cutter_end)
	if cursor < end - FLOOR_HOLE_MIN_SIZE:
		visible.append(Vector2(cursor, end))
	return visible


func _sort_intervals(a: Vector2, b: Vector2) -> bool:
	if !is_equal_approx(a.x, b.x):
		return a.x < b.x
	return a.y < b.y


func _floor_hole_arrays_equal(a: Array[Rect2], b: Array[Rect2]) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if !_rects_equal(a[index], b[index]):
			return false
	return true


func _rects_equal(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.distance_to(b.position) <= FLOOR_HOLE_EDGE_EPSILON
		and a.size.distance_to(b.size) <= FLOOR_HOLE_EDGE_EPSILON
	)


func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	var a_end := _rect_end(a)
	var b_end := _rect_end(b)
	return (
		a.position.x < b_end.x - FLOOR_HOLE_EDGE_EPSILON
		and a_end.x > b.position.x + FLOOR_HOLE_EDGE_EPSILON
		and a.position.y < b_end.y - FLOOR_HOLE_EDGE_EPSILON
		and a_end.y > b.position.y + FLOOR_HOLE_EDGE_EPSILON
	)


func _sort_floor_hole_rects(a: Rect2, b: Rect2) -> bool:
	if !is_equal_approx(a.position.x, b.position.x):
		return a.position.x < b.position.x
	if !is_equal_approx(a.position.y, b.position.y):
		return a.position.y < b.position.y
	if !is_equal_approx(a.size.x, b.size.x):
		return a.size.x < b.size.x
	return a.size.y < b.size.y


func _rect_from_parent_corners(parent_start: Vector3, parent_end: Vector3) -> Rect2:
	var min_x := minf(parent_start.x, parent_end.x)
	var max_x := maxf(parent_start.x, parent_end.x)
	var min_z := minf(parent_start.z, parent_end.z)
	var max_z := maxf(parent_start.z, parent_end.z)
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))


func _normalized_rect(rect: Rect2) -> Rect2:
	var rect_end := rect.position + rect.size
	var min_x := minf(rect.position.x, rect_end.x)
	var max_x := maxf(rect.position.x, rect_end.x)
	var min_y := minf(rect.position.y, rect_end.y)
	var max_y := maxf(rect.position.y, rect_end.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _rect_end(rect: Rect2) -> Vector2:
	return rect.position + rect.size


func _update_floor_mesh_resource(arrays: Array) -> void:
	_replace_generated_mesh_surface(arrays)


func _sync_floor_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_floor_material(floor_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, floor_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if floor_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_floor_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_collision_body(collision_faces: PackedVector3Array) -> void:
	if collision_faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "FloorCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
