@tool
class_name StreetJunction3D
extends MeshInstance3D

const GENERATED_META := &"street_network_generated"
const EPSILON := 0.00001

var junction_id := ""
var m_parent_local_footprint := PackedVector3Array()
var m_generate_collision := true


func configure(
	stable_id: String,
	parent_local_center: Vector3,
	parent_local_road_corners: PackedVector3Array,
	parent_local_footprint: PackedVector3Array,
	road_thickness: float,
	road_color: Color,
	generate_collision: bool
) -> void:
	junction_id = stable_id
	name = "Junction_%s" % stable_id
	position = parent_local_center
	m_parent_local_footprint = _sorted_unique_points(
		parent_local_footprint, parent_local_center
	)
	m_generate_collision = generate_collision
	_build_mesh(
		_sorted_unique_points(parent_local_road_corners, parent_local_center),
		parent_local_center,
		maxf(road_thickness, 0.01),
		road_color
	)


func get_parent_local_footprint() -> PackedVector3Array:
	return m_parent_local_footprint.duplicate()


func _build_mesh(
	parent_local_corners: PackedVector3Array,
	parent_local_center: Vector3,
	thickness: float,
	color: Color
) -> void:
	_clear_collision()
	if parent_local_corners.size() < 2:
		mesh = null
		return
	var local_corners := PackedVector3Array()
	for corner in parent_local_corners:
		local_corners.append(corner - parent_local_center)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var boundary := local_corners
	if local_corners.size() == 2:
		boundary = PackedVector3Array([Vector3.ZERO, local_corners[0], local_corners[1]])
		_append_upward_triangle(
			Vector3.ZERO, local_corners[0], local_corners[1], color,
			vertices, normals, colors, indices
		)
	else:
		for index in range(local_corners.size()):
			_append_upward_triangle(
				Vector3.ZERO,
				local_corners[index],
				local_corners[(index + 1) % local_corners.size()],
				color, vertices, normals, colors, indices
			)
	var drop := Vector3.DOWN * thickness
	if local_corners.size() == 2:
		_append_triangle(
			drop, local_corners[1] + drop, local_corners[0] + drop,
			color.darkened(0.08), vertices, normals, colors, indices
		)
	else:
		for index in range(local_corners.size()):
			_append_triangle(
				drop,
				local_corners[(index + 1) % local_corners.size()] + drop,
				local_corners[index] + drop,
				color.darkened(0.08), vertices, normals, colors, indices
			)
	for index in range(boundary.size()):
		var a := boundary[index]
		var b := boundary[(index + 1) % boundary.size()]
		_append_quad(
			a, b, b + drop, a + drop, color.darkened(0.06),
			vertices, normals, colors, indices
		)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	if m_generate_collision:
		_add_collision(vertices, indices)


func _sorted_unique_points(
	points: PackedVector3Array, center: Vector3
) -> PackedVector3Array:
	var unique: Array[Vector3] = []
	for point in points:
		var normalized := Vector3(point.x, center.y, point.z)
		var duplicate_found := false
		for existing in unique:
			if Vector2(existing.x - normalized.x, existing.z - normalized.z).length() <= 0.001:
				duplicate_found = true
				break
		if !duplicate_found:
			unique.append(normalized)
	unique.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2(a.z - center.z, a.x - center.x) < atan2(b.z - center.z, b.x - center.x)
	)
	return PackedVector3Array(unique)


func _append_upward_triangle(
	a: Vector3, b: Vector3, c: Vector3, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	if (b - a).cross(c - a).y < 0.0:
		_append_triangle(a, c, b, color, vertices, normals, colors, indices)
	else:
		_append_triangle(a, b, c, color, vertices, normals, colors, indices)


func _append_quad(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	colors: PackedColorArray, indices: PackedInt32Array
) -> void:
	_append_triangle(a, b, c, color, vertices, normals, colors, indices)
	_append_triangle(a, c, d, color, vertices, normals, colors, indices)


func _append_triangle(
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
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	colors.append_array(PackedColorArray([color, color, color]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))


func _add_collision(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var faces := PackedVector3Array()
	for index in indices:
		faces.append(vertices[index])
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	var body := StaticBody3D.new()
	body.name = "JunctionCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)


func _clear_collision() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.free()
