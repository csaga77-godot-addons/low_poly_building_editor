@tool
extends MeshInstance3D

const BuildingWireframe := preload(
	"res://addons/low_poly_building_editor/building_wireframe.gd"
)

var m_mesh_rebuild_count := 0
var m_debug_wireframe_enabled := false
var m_debug_wireframe_color := Color(0.05, 0.95, 1.0, 1.0)
var m_debug_wireframe_xray := false
@export_storage var m_generated_mesh_source_signature := 0
@export_storage var m_generated_mesh_clip_signature := 0
@export_storage var m_generated_mesh_cache_flags := 0


func get_mesh_rebuild_count() -> int:
	return m_mesh_rebuild_count


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


func is_debug_wireframe_enabled() -> bool:
	return m_debug_wireframe_enabled


func get_debug_wireframe_color() -> Color:
	return m_debug_wireframe_color


func is_debug_wireframe_xray() -> bool:
	return m_debug_wireframe_xray


func _sync_debug_wireframe() -> void:
	var meshes: Array[MeshInstance3D] = [self]
	BuildingWireframe.sync(
		self,
		meshes,
		m_debug_wireframe_enabled,
		m_debug_wireframe_color,
		m_debug_wireframe_xray
	)


func _begin_generated_mesh_rebuild() -> void:
	m_mesh_rebuild_count += 1
	BuildingWireframe.clear(self)


func _generated_mesh_cache_matches(source_signature: int, clip_signature: int = 0) -> bool:
	return (
		mesh != null
		and m_generated_mesh_source_signature == source_signature
		and m_generated_mesh_clip_signature == clip_signature
	)


func _record_generated_mesh_cache(
	source_signature: int,
	clip_signature: int = 0,
	cache_flags: int = 0
) -> void:
	m_generated_mesh_source_signature = source_signature
	m_generated_mesh_clip_signature = clip_signature
	m_generated_mesh_cache_flags = cache_flags


func _generated_mesh_cache_has_flag(flag: int) -> bool:
	return (m_generated_mesh_cache_flags & flag) != 0


func _cached_mesh_vertices() -> PackedVector3Array:
	if mesh == null or mesh.get_surface_count() <= 0:
		return PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


func _cached_mesh_indices() -> PackedInt32Array:
	if mesh == null or mesh.get_surface_count() <= 0:
		return PackedInt32Array()
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_INDEX]


func _cached_mesh_triangle_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	var vertices := _cached_mesh_vertices()
	for index in _cached_mesh_indices():
		faces.append(vertices[index])
	return faces


func _replace_generated_mesh_surface(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null or !array_mesh.resource_local_to_scene:
		array_mesh = ArrayMesh.new()
		array_mesh.resource_local_to_scene = true
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sync_debug_wireframe()


func _scene_local_material_for_write(
	material: StandardMaterial3D
) -> StandardMaterial3D:
	if material == null or material.resource_local_to_scene:
		return material
	var local_material := material.duplicate() as StandardMaterial3D
	local_material.resource_local_to_scene = true
	material_override = local_material
	return local_material


# --- Native gizmo transform reconciliation ---------------------------------
# Every block derives its node transform from authored parent-local properties
# (start/end points, base point, segments, ...). When the user edits a block
# with Godot's native Move/Rotate/Scale gizmos only the node transform changes,
# so the plugin calls apply_native_transform() to bake that edit back into the
# authored properties (snapping translations/sizes to the shared grid) and reset
# the node scale to 1. Concrete blocks override _authored_transform(),
# _bake_native_delta(), and the capture/restore hooks.

const NATIVE_TRANSFORM_EPSILON := 0.0005


## Transform this node would have purely from its authored properties. This is
## the value _sync_transform_from_points()/_sync_transform_from_base() assigns.
## Concrete blocks override it so a native gizmo edit can be measured as a delta.
func _authored_transform() -> Transform3D:
	return transform


## Parent-space transform introduced by a native gizmo edit: the difference
## between the current node transform and the transform implied by the authored
## properties (which have not changed yet).
func native_transform_delta() -> Transform3D:
	return transform * _authored_transform().affine_inverse()


## Bakes this block's own native gizmo edit back into authored properties,
## snapping placement to grid_step (0 disables snapping) then rebuilding. Returns
## true when authored state actually changed.
func apply_native_transform(grid_step: float) -> bool:
	var delta := native_transform_delta()
	if native_transform_is_identity(delta):
		return false
	var planar_delta := native_planar_delta(delta)
	if native_transform_is_identity(planar_delta):
		transform = _authored_transform()
		return false
	_bake_native_delta(planar_delta, maxf(grid_step, 0.0))
	return true


## Bakes a supplied parent-frame delta into this block's authored properties.
## Used both for the block's own edit and to propagate an ancestor's edit down to
## a descendant block whose own node transform did not change.
func bake_external_delta(delta: Transform3D, grid_step: float) -> void:
	if native_transform_is_identity(delta):
		return
	var planar_delta := native_planar_delta(delta)
	if native_transform_is_identity(planar_delta):
		transform = _authored_transform()
		return
	_bake_native_delta(planar_delta, maxf(grid_step, 0.0))


## True when this node is a building block that supports native-gizmo baking.
func supports_native_transform() -> bool:
	return false


func _bake_native_delta(_delta: Transform3D, _grid_step: float) -> void:
	pass


## Authored-state snapshot used for undo/redo of a native transform edit.
func capture_native_transform_state() -> Dictionary:
	return {}


func restore_native_transform_state(_state: Dictionary) -> void:
	pass


static func native_transform_is_identity(delta: Transform3D) -> bool:
	return (
		delta.origin.length() <= NATIVE_TRANSFORM_EPSILON
		and (delta.basis.x - Vector3.RIGHT).length() <= NATIVE_TRANSFORM_EPSILON
		and (delta.basis.y - Vector3.UP).length() <= NATIVE_TRANSFORM_EPSILON
		and (delta.basis.z - Vector3.BACK).length() <= NATIVE_TRANSFORM_EPSILON
	)


static func snap_axis_to_grid(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return roundf(value / step) * step


static func snap_vector3_to_grid(value: Vector3, step: float) -> Vector3:
	return Vector3(
		snap_axis_to_grid(value.x, step),
		snap_axis_to_grid(value.y, step),
		snap_axis_to_grid(value.z, step)
	)


## Offset that moves `reference` onto the grid. Adding it to a whole point group
## snaps the group's placement to the grid while preserving the relative shape
## and size exactly, so a scaled block keeps its scaled geometry.
static func grid_snap_offset(reference: Vector3, step: float) -> Vector3:
	if step <= 0.0:
		return Vector3.ZERO
	return snap_vector3_to_grid(reference, step) - reference


## Yaw (rotation about Y, in degrees) carried by a native transform delta.
static func native_delta_yaw_degrees(delta: Transform3D) -> float:
	return rad_to_deg(delta.basis.orthonormalized().get_euler().y)


## Per-axis scale factors carried by a native transform delta.
static func native_delta_scale(delta: Transform3D) -> Vector3:
	return Vector3(
		delta.basis.x.length(),
		delta.basis.y.length(),
		delta.basis.z.length()
	)


## Native building edits support translation, yaw, and scale. Pitch/roll are
## intentionally flattened so unsupported rotations cannot leave blocks tilted
## away from their authored horizontal construction plane.
static func native_planar_delta(delta: Transform3D) -> Transform3D:
	var yaw := native_delta_yaw_degrees(delta)
	var scale := native_delta_scale(delta)
	var planar_basis := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.from_scale(scale)
	return Transform3D(planar_basis, delta.origin)


## Per-axis scale of a transform measured along its own local axes. Blocks that
## map scale onto a scalar size plus a separate rotation field use this on their
## effective transform (delta * authored) instead of native_delta_scale(): a
## parent-frame delta scale lands on the wrong axis once the block is rotated, so
## a widened rotated roof would deepen instead.
static func transform_scale(effective: Transform3D) -> Vector3:
	return Vector3(
		effective.basis.x.length(),
		effective.basis.y.length(),
		effective.basis.z.length()
	)


## Absolute yaw (degrees) of a transform, robust to non-uniform scale because the
## basis is orthonormalized before the euler read.
static func transform_yaw_degrees(effective: Transform3D) -> float:
	return rad_to_deg(effective.basis.orthonormalized().get_euler().y)
