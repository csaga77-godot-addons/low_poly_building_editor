@tool
extends Node3D

signal opening_geometry_changed

const GENERATED_META := &"building_opening_generated"
const BuildingWireframe := preload(
	"res://addons/low_poly_building_editor/building_wireframe.gd"
)

# Gap between the opening node origin and the wall face it is placed against.
# Mirrors the placement offset applied by the editor plugin so the frame casing
# can be positioned relative to both wall faces.
const FRAME_FACE_GAP := 0.035

# Which wall faces the frame casing covers. FRONT keeps the legacy single-sided
# casing on the placement face; BOTH centers the casing in the wall so trim shows
# (and protrudes) on both faces.
enum FrameSides { FRONT, BOTH }

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("_rebuild")

@export_range(0.1, 12.0, 0.01) var opening_width := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(opening_width, clamped_value):
			return
		opening_width = clamped_value
		_request_rebuild()
		opening_geometry_changed.emit()

@export_range(0.1, 12.0, 0.01) var opening_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(opening_height, clamped_value):
			return
		opening_height = clamped_value
		_request_rebuild()
		opening_geometry_changed.emit()

@export_range(0.01, 1.0, 0.01) var frame_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(frame_thickness, clamped_value):
			return
		frame_thickness = clamped_value
		_request_rebuild()

@export_range(0.01, 1.0, 0.01) var frame_depth := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(frame_depth, clamped_value):
			return
		frame_depth = clamped_value
		_request_rebuild()

@export var frame_color := Color(0.86, 0.92, 0.94, 1.0):
	set(value):
		if frame_color == value:
			return
		frame_color = value
		_request_rebuild()

@export var frame_sides: FrameSides = FrameSides.FRONT:
	set(value):
		if frame_sides == value:
			return
		frame_sides = value
		_request_rebuild()

@export_range(0.0, 0.5, 0.005) var frame_protrusion := 0.02:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.5)
		if is_equal_approx(frame_protrusion, clamped_value):
			return
		frame_protrusion = clamped_value
		_request_rebuild()

# Thickness of the wall this opening is mounted in. A value of 0 derives the
# thickness from frame_depth for compatibility with older authored openings.
@export_range(0.0, 4.0, 0.01) var wall_thickness := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(wall_thickness, clamped_value):
			return
		wall_thickness = clamped_value
		_request_rebuild()

@export var show_bottom_frame := true:
	set(value):
		if show_bottom_frame == value:
			return
		show_bottom_frame = value
		_request_rebuild()

@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

@export var build_on_ready := true

var m_is_ready := false
var m_rebuild_queued := false
var m_geometry_rebuild_count := 0
var m_debug_wireframe_enabled := false
var m_debug_wireframe_color := Color(0.05, 0.95, 1.0, 1.0)
var m_debug_wireframe_xray := false
@export_storage var m_generated_part_cache_signature := 0
@export_storage var m_generated_part_cache: Array[Dictionary] = []


func _ready() -> void:
	set_notify_local_transform(true)
	m_is_ready = true
	if build_on_ready:
		if (
			!m_generated_part_cache.is_empty()
			and m_generated_part_cache_signature == _opening_geometry_source_signature()
		):
			_restore_generated_parts_from_cache()
		else:
			_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and m_is_ready:
		opening_geometry_changed.emit()


func get_opening_rect() -> Rect2:
	var size := Vector2(opening_width, opening_height)
	var center := Vector2(position.x, position.y)
	return Rect2(center - size * 0.5, size)


func get_geometry_rebuild_count() -> int:
	return m_geometry_rebuild_count


func set_debug_wireframe(
	enabled: bool,
	color: Color = Color(0.05, 0.95, 1.0, 1.0),
	xray: bool = false
) -> void:
	var was_enabled := m_debug_wireframe_enabled
	var style_changed := (
		m_debug_wireframe_color != color
		or m_debug_wireframe_xray != xray
	)
	m_debug_wireframe_enabled = enabled
	m_debug_wireframe_color = color
	m_debug_wireframe_xray = xray
	if !enabled:
		if was_enabled or BuildingWireframe.is_active(self):
			BuildingWireframe.clear(self)
	elif !was_enabled or !BuildingWireframe.is_active(self):
		_sync_debug_wireframe()
	elif style_changed:
		BuildingWireframe.update_style(self, color, xray)


func _sync_debug_wireframe() -> void:
	BuildingWireframe.sync_recursive(
		self,
		m_debug_wireframe_enabled,
		m_debug_wireframe_color,
		m_debug_wireframe_xray
	)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	m_geometry_rebuild_count += 1
	m_rebuild_queued = false
	BuildingWireframe.clear(self)
	_clear_generated_children()
	m_generated_part_cache.clear()

	var half_width := opening_width * 0.5
	var half_height := opening_height * 0.5
	var bottom_extra := frame_thickness if show_bottom_frame else 0.0
	var side_height := opening_height + frame_thickness + bottom_extra
	var side_y := (frame_thickness - bottom_extra) * 0.5
	var top_width := opening_width + frame_thickness * 2.0
	var casing := _frame_casing()
	var casing_depth: float = casing["depth"]
	var casing_z: float = casing["center_z"]

	_add_box(
		"LeftFrame",
		Vector3(frame_thickness, side_height, casing_depth),
		Vector3(-half_width - frame_thickness * 0.5, side_y, casing_z),
		frame_color
	)
	_add_box(
		"RightFrame",
		Vector3(frame_thickness, side_height, casing_depth),
		Vector3(half_width + frame_thickness * 0.5, side_y, casing_z),
		frame_color
	)
	_add_box(
		"TopFrame",
		Vector3(top_width, frame_thickness, casing_depth),
		Vector3(0.0, half_height + frame_thickness * 0.5, casing_z),
		frame_color
	)
	if show_bottom_frame:
		_add_box(
			"BottomFrame",
			Vector3(top_width, frame_thickness, casing_depth),
			Vector3(0.0, -half_height - frame_thickness * 0.5, casing_z),
			frame_color
		)
	_build_opening_content()
	m_generated_part_cache_signature = _opening_geometry_source_signature()
	_sync_debug_wireframe()


# Implemented by Door3D and Window3D. BuildingOpening3D owns only the frame
# casing and wall-cut dimensions shared by every concrete opening style.
func _build_opening_content() -> void:
	pass


func _frame_casing() -> Dictionary:
	if frame_sides != FrameSides.BOTH:
		return {"depth": frame_depth, "center_z": 0.0}
	var thickness := wall_thickness if wall_thickness > 0.0 else maxf(frame_depth - 0.04, 0.02)
	var front_edge := -FRAME_FACE_GAP + frame_protrusion
	var back_edge := -(thickness + FRAME_FACE_GAP) - frame_protrusion
	return {"depth": front_edge - back_edge, "center_z": (front_edge + back_edge) * 0.5}


func _add_glass(part_name: String, rect: Rect2, depth: float, color: Color) -> void:
	_add_box(part_name, Vector3(rect.size.x, rect.size.y, depth), _rect_center(rect), color)


func _rect_center(rect: Rect2) -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5, 0.0)


func _add_box(
	part_name: String,
	size: Vector3,
	local_position: Vector3,
	color: Color,
	with_collision: bool = true
) -> void:
	_spawn_box(part_name, size, Transform3D(Basis(), local_position), color, with_collision)


func _add_oriented_box(
	part_name: String,
	size: Vector3,
	local_position: Vector3,
	color: Color,
	basis: Basis
) -> void:
	_spawn_box(part_name, size, Transform3D(basis, local_position), color, true)


func _spawn_box(
	part_name: String,
	size: Vector3,
	local_transform: Transform3D,
	color: Color,
	with_collision: bool
) -> void:
	var part_mesh := BoxMesh.new()
	part_mesh.size = size
	part_mesh.resource_local_to_scene = true
	var descriptor := {
		"name": part_name,
		"mesh": part_mesh,
		"transform": local_transform,
		"material": _build_material(color),
		"collision_size": size if with_collision else Vector3.ZERO,
	}
	m_generated_part_cache.append(descriptor)
	_instantiate_generated_part(descriptor)


func _instantiate_generated_part(descriptor: Dictionary) -> void:
	var instance := MeshInstance3D.new()
	instance.name = String(descriptor.get("name", "Part"))
	instance.mesh = descriptor.get("mesh") as Mesh
	instance.transform = Transform3D(descriptor.get("transform", Transform3D.IDENTITY))
	instance.material_override = descriptor.get("material") as Material
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null
	var collision_size := Vector3(descriptor.get("collision_size", Vector3.ZERO))
	if generate_collision and collision_size != Vector3.ZERO:
		_attach_part_collision(instance, collision_size)


func _restore_generated_parts_from_cache() -> void:
	_clear_generated_children()
	for descriptor in m_generated_part_cache:
		_instantiate_generated_part(descriptor)
	_sync_debug_wireframe()


func _opening_geometry_source_signature() -> int:
	var payload := [String(get_script().resource_path)]
	var excluded := {
		&"rebuild": true,
		&"build_on_ready": true,
		&"generate_collision": true,
		&"m_generated_part_cache_signature": true,
		&"m_generated_part_cache": true,
		&"m_debug_wireframe_enabled": true,
		&"m_debug_wireframe_color": true,
		&"m_debug_wireframe_xray": true,
	}
	for property in get_property_list():
		var usage := int(property.get("usage", 0))
		if (
			(usage & PROPERTY_USAGE_STORAGE) == 0
			or (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0
		):
			continue
		var property_name := StringName(property.get("name", ""))
		if excluded.has(property_name):
			continue
		payload.append([property_name, get(property_name)])
	return hash(payload)


func _attach_part_collision(part: Node3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	part.add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _build_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
