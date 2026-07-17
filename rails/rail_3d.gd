@tool
class_name Rail3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

const StandardRailGeometry := preload(
	"res://addons/low_poly_building_editor/rails/standard_rail_geometry_3d.gd"
)

const GENERATED_META := &"rail_generated"
const PREVIEW_META := &"building_editor_preview"
const MESH_GEOMETRY_VERSION := 9

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		if !is_equal_approx(end_point.y, value.y):
			end_point = Vector3(end_point.x, value.y, end_point.z)
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 0.0):
	set(value):
		var flattened := Vector3(value.x, start_point.y, value.z)
		if end_point.is_equal_approx(flattened):
			return
		end_point = flattened
		_request_rebuild()

# Exported rail properties follow the same order as Stairs3D's rail group:
# infill style, newel count, infill count, newel thickness, rail height,
# infill rail thickness, rail thickness, lower rail height, color.
@export_enum("Vertical Rail", "Horizontal Rail", "Glass Panel") var infill_style: int = (
	StandardRailGeometry.RailStyle.VERTICAL
):
	set(value):
		var clamped_value := clampi(
			value,
			StandardRailGeometry.RailStyle.VERTICAL,
			StandardRailGeometry.RailStyle.GLASS_PANEL
		)
		if infill_style == clamped_value:
			return
		infill_style = clamped_value
		_request_rebuild()

@export_range(2, 64, 1) var newel_post_count := 2:
	set(value):
		var clamped_value := clampi(value, 2, 64)
		if newel_post_count == clamped_value:
			return
		newel_post_count = clamped_value
		_request_rebuild()

@export_range(0, 64, 1) var infill_count_between_newels := 1:
	set(value):
		var clamped_value := clampi(value, 0, 64)
		if infill_count_between_newels == clamped_value:
			return
		infill_count_between_newels = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var newel_post_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(newel_post_thickness, clamped_value):
			return
		newel_post_thickness = clamped_value
		_request_rebuild()

@export_range(0.2, 4.0, 0.01, "or_greater") var rail_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(rail_height, clamped_value):
			return
		rail_height = clamped_value
		_request_rebuild()

@export_storage var post_spacing := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(post_spacing, clamped_value):
			return
		post_spacing = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var infill_rail_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(infill_rail_thickness, clamped_value):
			return
		infill_rail_thickness = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_thickness, clamped_value):
			return
		rail_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var lower_rail_height := 0.18:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(lower_rail_height, clamped_value):
			return
		lower_rail_height = clamped_value
		_request_rebuild()

@export var rail_color := Color(0.33, 0.28, 0.22, 1.0):
	set(value):
		if rail_color == value:
			return
		rail_color = value
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
	if !build_on_ready:
		return
	_sync_transform_from_points()
	if _generated_mesh_cache_matches(_rail_mesh_source_signature()):
		_sync_rail_material()
		_rebuild_collision_from_cached_mesh()
	else:
		rebuild_rail_mesh()


func set_rail_points(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _rail_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	if _rail_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_rail_mesh()


func get_rail_length() -> float:
	return Vector2(
		end_point.x - start_point.x,
		end_point.z - start_point.z
	).length()


func get_rail_bounds_min() -> Vector3:
	# The run only extends past the span by the endpoint newels; interior
	# infills never reach beyond them, so the infill rail thickness affects
	# side (Z) extent only.
	var side_width := maxf(
		maxf(infill_rail_thickness, newel_post_thickness),
		rail_thickness
	)
	return Vector3(-_clamped_newel_size() * 0.5, 0.0, -side_width * 0.5)


func get_rail_bounds_max() -> Vector3:
	var side_width := maxf(
		maxf(infill_rail_thickness, newel_post_thickness),
		rail_thickness
	)
	return Vector3(
		get_rail_length() + _clamped_newel_size() * 0.5,
		maxf(rail_height, 0.2),
		side_width * 0.5
	)


func get_post_count() -> int:
	var layout := _get_post_layout(get_rail_length())
	var positions: PackedFloat32Array = layout["positions"]
	return positions.size()


func rebuild_rail_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var length := get_rail_length()
	if length <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_standard_rail_geometry(length, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_replace_generated_mesh_surface(arrays)
	_sync_rail_material()
	_record_generated_mesh_cache(_rail_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_rail_mesh")


func _rail_mesh_source_signature() -> int:
	return hash([
		MESH_GEOMETRY_VERSION,
		start_point,
		end_point,
		rail_height,
		post_spacing,
		infill_rail_thickness,
		rail_thickness,
		infill_style,
		newel_post_count,
		infill_count_between_newels,
		newel_post_thickness,
		lower_rail_height,
		rail_color,
	])


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body(_cached_mesh_vertices(), _cached_mesh_indices())


func _sync_transform_from_points() -> void:
	transform = _authored_transform()


func _authored_transform() -> Transform3D:
	var flat_delta := Vector3(
		end_point.x - start_point.x,
		0.0,
		end_point.z - start_point.z
	)
	var direction := Vector3.RIGHT
	if flat_delta.length_squared() > 0.000001:
		direction = flat_delta.normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	return Transform3D(
		Basis(direction, Vector3.UP, side.normalized()).orthonormalized(),
		start_point
	)


func supports_native_transform() -> bool:
	return true


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	var scale := native_delta_scale(delta)
	# Snap the start onto the grid and shift the end by the same offset so the
	# scaled length and orientation are preserved exactly.
	var raw_start := delta * start_point
	var raw_end := delta * end_point
	var offset := grid_snap_offset(raw_start, grid_step)
	rail_height = maxf(rail_height * scale.y, 0.2)
	set_rail_points(raw_start + offset, raw_end + offset)


func capture_native_transform_state() -> Dictionary:
	return {
		"start_point": start_point,
		"end_point": end_point,
		"rail_height": rail_height,
	}


func restore_native_transform_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	rail_height = float(state.get("rail_height", rail_height))
	set_rail_points(
		Vector3(state.get("start_point", start_point)),
		Vector3(state.get("end_point", end_point))
	)


func _append_standard_rail_geometry(
	length: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var layout := _get_post_layout(length)
	# Pin the handrail/base-rail run to the endpoint newels' outer faces.
	# Without these overrides the shared geometry seeds its run extents from
	# the infill rail thickness, so a thick infill would lengthen the
	# handrail past the end newels.
	var newel_size := _clamped_newel_size()
	StandardRailGeometry.append_rail(
		vertices,
		normals,
		colors,
		indices,
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.BACK,
		length,
		0.0,
		rail_height,
		post_spacing,
		_clamped_infill_rail_size(),
		rail_thickness,
		lower_rail_height,
		rail_color,
		layout["positions"],
		layout["base_heights"],
		layout["thicknesses"],
		layout["top_heights"],
		-INF,
		INF,
		-newel_size * 0.5,
		length + newel_size * 0.5,
		infill_style,
		infill_count_between_newels
	)


func _handrail_width() -> float:
	return minf(
		maxf(rail_thickness, 0.02),
		maxf(rail_height, 0.2) * 0.5
	)


func _clamped_newel_size() -> float:
	return minf(maxf(newel_post_thickness, 0.02), _handrail_width())


func _clamped_infill_rail_size() -> float:
	# Like newels, infill geometry never exceeds the handrail cross-section.
	return minf(maxf(infill_rail_thickness, 0.02), _handrail_width())


func _get_post_layout(length: float) -> Dictionary:
	var positions := PackedFloat32Array()
	var base_heights := PackedFloat32Array()
	var thicknesses := PackedFloat32Array()
	var newel_flags := PackedByteArray()
	var newel_size := _clamped_newel_size()
	var count := clampi(newel_post_count, 2, 64)
	for index in range(count):
		positions.append(length * float(index) / float(count - 1))
		base_heights.append(0.0)
		thicknesses.append(newel_size)
		newel_flags.append(1)
	var counted_layout := StandardRailGeometry.apply_infill_count_between_newels(
		positions,
		base_heights,
		thicknesses,
		newel_flags,
		(
			infill_count_between_newels
			if infill_style == StandardRailGeometry.RailStyle.VERTICAL
			else 0
		),
		_clamped_infill_rail_size()
	)
	positions = counted_layout["positions"]
	base_heights = counted_layout["base_heights"]
	thicknesses = counted_layout["thicknesses"]
	newel_flags = counted_layout["newel_flags"]
	StandardRailGeometry.redistribute_infills_between_newels(
		positions,
		thicknesses,
		newel_flags
	)
	if StandardRailGeometry.has_lower_rail(
		rail_height,
		rail_thickness,
		lower_rail_height
	):
		var base_rail_top := StandardRailGeometry.lower_rail_top_height(
			rail_height,
			rail_thickness,
			lower_rail_height
		)
		for index in range(positions.size()):
			if newel_flags[index] == 0:
				base_heights[index] = base_rail_top
	var top_heights := PackedFloat32Array()
	top_heights.resize(positions.size())
	for index in range(top_heights.size()):
		top_heights[index] = NAN
	return {
		"positions": positions,
		"base_heights": base_heights,
		"thicknesses": thicknesses,
		"newel_flags": newel_flags,
		"top_heights": top_heights,
	}


func _rail_material_transparency() -> BaseMaterial3D.Transparency:
	# The glass-panel infill carries its translucency in vertex alpha inside
	# the same surface as the opaque posts and handrail. Plain alpha blending
	# would move the whole mesh into the no-depth-write transparent pass and
	# break depth sorting, so the glass style uses an opaque depth pre-pass:
	# opaque fragments keep correct depth while the panel still blends.
	if infill_style == StandardRailGeometry.RailStyle.GLASS_PANEL:
		return BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	if rail_color.a < 0.99:
		return BaseMaterial3D.TRANSPARENCY_ALPHA
	return BaseMaterial3D.TRANSPARENCY_DISABLED


func _sync_rail_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_rail_material()
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, rail_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = _rail_material_transparency()


func _build_rail_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, rail_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = _rail_material_transparency()
	return material


func _add_collision_body(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var faces := PackedVector3Array()
	for index in range(0, indices.size(), 3):
		faces.append(vertices[indices[index]])
		faces.append(vertices[indices[index + 1]])
		faces.append(vertices[indices[index + 2]])
	if faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	var body := StaticBody3D.new()
	body.name = "RailCollision"
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
