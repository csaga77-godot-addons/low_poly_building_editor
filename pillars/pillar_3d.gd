@tool
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

const GENERATED_META := &"pillar_generated"
const PREVIEW_META := &"building_editor_preview"

@export var base_point := Vector3.ZERO:
	set(value):
		if base_point.is_equal_approx(value):
			return
		base_point = value
		_request_rebuild()

@export_range(0.05, 4.0, 0.01, "or_greater") var pillar_radius := 0.25:
	set(value):
		var clamped_value := maxf(value, 0.05)
		if is_equal_approx(pillar_radius, clamped_value):
			return
		pillar_radius = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var upper_radius := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(upper_radius, clamped_value):
			return
		upper_radius = clamped_value
		_request_rebuild()

@export_range(0.1, 12.0, 0.05, "or_greater") var pillar_height := 2.4:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(pillar_height, clamped_value):
			return
		pillar_height = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var lower_rim_height := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(lower_rim_height, clamped_value):
			return
		lower_rim_height = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var lower_rim_outset := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(lower_rim_outset, clamped_value):
			return
		lower_rim_outset = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var upper_rim_height := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(upper_rim_height, clamped_value):
			return
		upper_rim_height = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var upper_rim_outset := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(upper_rim_outset, clamped_value):
			return
		upper_rim_outset = clamped_value
		_request_rebuild()

@export var pillar_color := Color(0.70, 0.64, 0.52, 1.0):
	set(value):
		if pillar_color == value:
			return
		pillar_color = value
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
	m_is_ready = true
	if build_on_ready:
		_sync_transform_from_base()
		if _generated_mesh_cache_matches(_pillar_mesh_source_signature()):
			_sync_pillar_material()
			_rebuild_collision_from_cached_mesh()
		else:
			rebuild_pillar_mesh()


func set_pillar_base_position(new_base_point: Vector3) -> void:
	var previous_signature := _pillar_mesh_source_signature()
	base_point = new_base_point
	if _pillar_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_base()
	rebuild_pillar_mesh()


func set_pillar_radius(new_radius: float) -> void:
	var previous_signature := _pillar_mesh_source_signature()
	pillar_radius = new_radius
	if _pillar_mesh_source_signature() != previous_signature:
		rebuild_pillar_mesh()


func set_pillar_base_and_radius(new_base_point: Vector3, new_radius: float) -> void:
	set_pillar_base_and_radii(new_base_point, new_radius, upper_radius)


func set_pillar_base_and_radii(new_base_point: Vector3, new_lower_radius: float, new_upper_radius: float) -> void:
	var previous_signature := _pillar_mesh_source_signature()
	base_point = new_base_point
	pillar_radius = new_lower_radius
	upper_radius = new_upper_radius
	if _pillar_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_base()
	rebuild_pillar_mesh()


func set_pillar_radii(new_lower_radius: float, new_upper_radius: float) -> void:
	var previous_signature := _pillar_mesh_source_signature()
	pillar_radius = new_lower_radius
	upper_radius = new_upper_radius
	if _pillar_mesh_source_signature() != previous_signature:
		rebuild_pillar_mesh()


func set_pillar_rims(
	new_lower_height: float,
	new_lower_outset: float,
	new_upper_height: float,
	new_upper_outset: float
) -> void:
	var previous_signature := _pillar_mesh_source_signature()
	lower_rim_height = new_lower_height
	lower_rim_outset = new_lower_outset
	upper_rim_height = new_upper_height
	upper_rim_outset = new_upper_outset
	if _pillar_mesh_source_signature() != previous_signature:
		rebuild_pillar_mesh()


func get_pillar_style() -> String:
	return ""


func get_outer_radius() -> float:
	var body_radius := maxf(pillar_radius, _effective_top_radius())
	var rim_heights := _effective_rim_heights()
	if _is_lower_rim_enabled(rim_heights.x):
		body_radius = maxf(body_radius, _lower_rim_outer_radius(rim_heights.x))
	if _is_upper_rim_enabled(rim_heights.y):
		body_radius = maxf(body_radius, _upper_rim_outer_radius(rim_heights.y))
	return body_radius


func rebuild_pillar_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_base()
	if rebuild_collision:
		_clear_generated_children()
	if get_pillar_style().is_empty():
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_pillar_geometry(vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_pillar_mesh_resource(arrays)
	_sync_pillar_material()
	_record_generated_mesh_cache(_pillar_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body()


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_pillar_mesh")


func _pillar_mesh_source_signature() -> int:
	return hash([
		get_pillar_style(),
		_effective_side_count(),
		base_point,
		pillar_radius,
		upper_radius,
		pillar_height,
		lower_rim_height,
		lower_rim_outset,
		upper_rim_height,
		upper_rim_outset,
		pillar_color,
	])


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body()


func _sync_transform_from_base() -> void:
	transform = _authored_transform()


func _authored_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, base_point)


func supports_native_transform() -> bool:
	return true


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	var scale := native_delta_scale(delta)
	var horizontal := (scale.x + scale.z) * 0.5
	base_point = snap_vector3_to_grid(delta * base_point, grid_step)
	pillar_radius = maxf(pillar_radius * horizontal, 0.05)
	if upper_radius > 0.0:
		upper_radius = maxf(upper_radius * horizontal, 0.0)
	pillar_height = maxf(pillar_height * scale.y, 0.1)
	rebuild_pillar_mesh()


func capture_native_transform_state() -> Dictionary:
	return {
		"base_point": base_point,
		"pillar_radius": pillar_radius,
		"upper_radius": upper_radius,
		"pillar_height": pillar_height,
	}


func restore_native_transform_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	pillar_radius = float(state.get("pillar_radius", pillar_radius))
	upper_radius = float(state.get("upper_radius", upper_radius))
	pillar_height = float(state.get("pillar_height", pillar_height))
	base_point = Vector3(state.get("base_point", base_point))
	rebuild_pillar_mesh()


func _append_pillar_geometry(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var sides := _effective_side_count()
	var angle_offset := _effective_angle_offset(sides)
	var rim_heights := _effective_rim_heights()
	var lower_rim_enabled := _is_lower_rim_enabled(rim_heights.x)
	var upper_rim_enabled := _is_upper_rim_enabled(rim_heights.y)
	var lower_height := rim_heights.x if lower_rim_enabled else 0.0
	var upper_height := rim_heights.y if upper_rim_enabled else 0.0
	var body_start_y := lower_height
	var body_end_y := maxf(body_start_y, pillar_height - upper_height)
	var body_start_radius := _body_radius_at_y(body_start_y)
	var body_end_radius := _body_radius_at_y(body_end_y)
	var bottom_cap_radius := _lower_rim_outer_radius(lower_height) if lower_rim_enabled else _body_radius_at_y(0.0)
	var top_cap_radius := _upper_rim_outer_radius(upper_height) if upper_rim_enabled else _body_radius_at_y(pillar_height)
	for side_index in range(sides):
		var angle_0 := angle_offset + TAU * float(side_index) / float(sides)
		var angle_1 := angle_offset + TAU * float(side_index + 1) / float(sides)
		if lower_rim_enabled:
			var lower_outer_radius := _lower_rim_outer_radius(lower_height)
			_append_frustum_side(
				vertices,
				normals,
				colors,
				indices,
				angle_0,
				angle_1,
				0.0,
				lower_height,
				lower_outer_radius,
				lower_outer_radius
			)
			_append_annular_face(
				vertices,
				normals,
				colors,
				indices,
				angle_0,
				angle_1,
				lower_height,
				body_start_radius,
				lower_outer_radius,
				Vector3.UP
			)

		if body_end_y > body_start_y + 0.0001:
			_append_frustum_side(
				vertices,
				normals,
				colors,
				indices,
				angle_0,
				angle_1,
				body_start_y,
				body_end_y,
				body_start_radius,
				body_end_radius
			)

		if upper_rim_enabled:
			var upper_outer_radius := _upper_rim_outer_radius(upper_height)
			_append_annular_face(
				vertices,
				normals,
				colors,
				indices,
				angle_0,
				angle_1,
				body_end_y,
				body_end_radius,
				upper_outer_radius,
				Vector3.DOWN
			)
			_append_frustum_side(
				vertices,
				normals,
				colors,
				indices,
				angle_0,
				angle_1,
				body_end_y,
				pillar_height,
				upper_outer_radius,
				upper_outer_radius
			)

		_append_disc_cap(vertices, normals, colors, indices, angle_0, angle_1, pillar_height, top_cap_radius, Vector3.UP)
		_append_disc_cap(vertices, normals, colors, indices, angle_0, angle_1, 0.0, bottom_cap_radius, Vector3.DOWN)


func _ring_point(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


func _effective_side_count() -> int:
	return 0


func _effective_angle_offset(sides: int) -> float:
	if sides <= 0:
		return 0.0
	return PI / float(sides)


func _effective_top_radius() -> float:
	if upper_radius > 0.0001:
		return upper_radius
	return pillar_radius


func _body_radius_at_y(y: float) -> float:
	if pillar_height <= 0.0001:
		return pillar_radius
	var ratio := clampf(y / pillar_height, 0.0, 1.0)
	return lerpf(pillar_radius, _effective_top_radius(), ratio)


func _effective_rim_heights() -> Vector2:
	var lower_height := maxf(lower_rim_height, 0.0)
	var upper_height := maxf(upper_rim_height, 0.0)
	var total_height := lower_height + upper_height
	if total_height > pillar_height and total_height > 0.0001:
		var scale := pillar_height / total_height
		lower_height *= scale
		upper_height *= scale
	return Vector2(lower_height, upper_height)


func _is_lower_rim_enabled(effective_height: float) -> bool:
	return effective_height > 0.0001 and lower_rim_outset > 0.0001


func _is_upper_rim_enabled(effective_height: float) -> bool:
	return effective_height > 0.0001 and upper_rim_outset > 0.0001


func _lower_rim_outer_radius(effective_height: float) -> float:
	return maxf(_body_radius_at_y(0.0), _body_radius_at_y(effective_height)) + lower_rim_outset


func _upper_rim_outer_radius(effective_height: float) -> float:
	var start_y := maxf(pillar_height - effective_height, 0.0)
	return maxf(_body_radius_at_y(start_y), _body_radius_at_y(pillar_height)) + upper_rim_outset


func _append_frustum_side(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	angle_0: float,
	angle_1: float,
	y_0: float,
	y_1: float,
	radius_0: float,
	radius_1: float
) -> void:
	var bottom_0 := _ring_point(angle_0, y_0, radius_0)
	var bottom_1 := _ring_point(angle_1, y_0, radius_0)
	var top_0 := _ring_point(angle_0, y_1, radius_1)
	var top_1 := _ring_point(angle_1, y_1, radius_1)
	var side_normal := (top_0 - bottom_0).cross(bottom_1 - bottom_0).normalized()
	_append_quad(vertices, normals, colors, indices, bottom_0, top_0, top_1, bottom_1, side_normal)


func _append_disc_cap(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	angle_0: float,
	angle_1: float,
	y: float,
	radius: float,
	normal: Vector3
) -> void:
	var center := Vector3(0.0, y, 0.0)
	var point_0 := _ring_point(angle_0, y, radius)
	var point_1 := _ring_point(angle_1, y, radius)
	if normal.y > 0.0:
		_append_triangle(vertices, normals, colors, indices, center, point_1, point_0, normal)
	else:
		_append_triangle(vertices, normals, colors, indices, center, point_0, point_1, normal)


func _append_annular_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	angle_0: float,
	angle_1: float,
	y: float,
	inner_radius: float,
	outer_radius: float,
	normal: Vector3
) -> void:
	if outer_radius <= inner_radius + 0.0001:
		return
	var inner_0 := _ring_point(angle_0, y, inner_radius)
	var inner_1 := _ring_point(angle_1, y, inner_radius)
	var outer_0 := _ring_point(angle_0, y, outer_radius)
	var outer_1 := _ring_point(angle_1, y, outer_radius)
	if normal.y > 0.0:
		_append_quad(vertices, normals, colors, indices, inner_0, inner_1, outer_1, outer_0, normal)
	else:
		_append_quad(vertices, normals, colors, indices, inner_0, outer_0, outer_1, inner_1, normal)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
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
		colors.append(pillar_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colors.append(pillar_color)
	colors.append(pillar_color)
	colors.append(pillar_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1]))


func _update_pillar_mesh_resource(arrays: Array) -> void:
	_replace_generated_mesh_surface(arrays)


func _sync_pillar_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_pillar_material(pillar_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, pillar_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if pillar_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_pillar_material(color: Color) -> StandardMaterial3D:
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


func _add_collision_body() -> void:
	var shape := CylinderShape3D.new()
	shape.height = pillar_height
	shape.radius = get_outer_radius()

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.position = Vector3(0.0, pillar_height * 0.5, 0.0)
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "PillarCollision"
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
