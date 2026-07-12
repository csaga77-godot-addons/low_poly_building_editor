extends Node3D

# Verifies that a native Move/Rotate/Scale gizmo edit (simulated by writing the
# node transform directly) is baked back into each block's authored properties,
# snapped to the shared grid, with the node scale reset to 1.

const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const BuildingMeshScript = preload(
	"res://addons/low_poly_building_editor/building_mesh_3d.gd"
)
const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)
const RoundPillar3DScript = preload(
	"res://addons/low_poly_building_editor/pillars/round_pillar_3d.gd"
)
const Rail3DScript = preload(
	"res://addons/low_poly_building_editor/rails/rail_3d.gd"
)
const Floor3DScript = preload(
	"res://addons/low_poly_building_editor/floors/floor_3d.gd"
)
const FlatRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/flat_roof_3d.gd"
)

const GRID := 0.5
var m_failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_validate_static_helpers()
	_validate_roof_translate()
	_validate_roof_scale()
	_validate_roof_rotate()
	_validate_roof_rotated_scale()
	_validate_roof_scale_preserves_size()
	_validate_roof_offgrid_translate_snaps()
	_validate_roof_external_delta()
	_validate_pillar_scale_translate()
	_validate_rail_translate()
	_validate_floor_translate()
	_validate_floor_scale_preserves_anchor()
	_validate_floor_holes_scale()
	_validate_floor_pitch_is_ignored()
	_validate_flat_polygon_roof_translate_preserves_shape()
	_validate_parent_move_preserves_child_local_positions()
	_validate_parent_block_move_preserves_child_local_positions()
	_validate_parent_block_rotate_preserves_child_local_positions()
	_validate_shared_parent_bake_preserves_spacing()
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: Native transform bake smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_static_helpers() -> void:
	if !BuildingMeshScript.native_transform_is_identity(Transform3D.IDENTITY):
		m_failures.append("Identity transform not recognized as identity delta")
	if BuildingMeshScript.native_transform_is_identity(
		Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0))
	):
		m_failures.append("Translated transform wrongly treated as identity delta")
	if !is_equal_approx(BuildingMeshScript.snap_axis_to_grid(1.24, 0.5), 1.0):
		m_failures.append("snap_axis_to_grid did not round to the grid")
	if !is_equal_approx(BuildingMeshScript.snap_axis_to_grid(1.24, 0.0), 1.24):
		m_failures.append("snap_axis_to_grid should pass through when step is 0")
	var yaw := BuildingMeshScript.native_delta_yaw_degrees(
		Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3.ZERO)
	)
	if absf(yaw - 90.0) > 0.01:
		m_failures.append("native_delta_yaw_degrees did not extract 90 degrees")
	var scale := BuildingMeshScript.native_delta_scale(
		Transform3D(Basis.from_scale(Vector3(2.0, 3.0, 4.0)), Vector3.ZERO)
	)
	if scale.distance_to(Vector3(2.0, 3.0, 4.0)) > 0.01:
		m_failures.append("native_delta_scale did not extract per-axis scale")
	var pitch_only := BuildingMeshScript.native_planar_delta(
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0)), Vector3.ZERO)
	)
	if !BuildingMeshScript.native_transform_is_identity(pitch_only):
		m_failures.append("native_planar_delta should flatten pitch-only edits")


func _make_roof():
	var roof := BuildingFactoryScript.create_roof_node(
		self,
		Vector3.ZERO,
		Vector3(4.0, 0.0, 6.0),
		"gable",
		30.0,
		0.12,
		0.2,
		Color(0.5, 0.34, 0.25, 1.0)
	)
	add_child(roof)
	return roof


func _validate_roof_translate() -> void:
	var roof = _make_roof()
	roof.transform = Transform3D(roof.transform.basis, Vector3(2.0, 0.0, 3.0))
	roof.apply_native_transform(GRID)
	if roof.start_point.distance_to(Vector3(2.0, 0.0, 3.0)) > 0.01:
		m_failures.append("Roof translate did not move the anchor start point")
	if roof.end_point.distance_to(Vector3(6.0, 0.0, 9.0)) > 0.01:
		m_failures.append("Roof translate did not move the far corner")
	if roof.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
		m_failures.append("Roof translate did not keep node scale at 1")
	roof.queue_free()


func _validate_roof_scale() -> void:
	var roof = _make_roof()
	roof.transform = Transform3D(
		roof.transform.basis.scaled(Vector3(2.0, 1.0, 2.0)),
		roof.transform.origin
	)
	roof.apply_native_transform(GRID)
	if roof.get_roof_size().distance_to(Vector2(8.0, 12.0)) > 0.01:
		m_failures.append("Roof scale did not bake into the footprint size")
	if roof.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
		m_failures.append("Roof scale did not reset node scale to 1")
	roof.queue_free()


func _validate_roof_rotate() -> void:
	var roof = _make_roof()
	roof.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90.0)) * roof.transform.basis,
		roof.transform.origin
	)
	roof.apply_native_transform(GRID)
	if absf(roof.roof_rotation_degrees - 90.0) > 0.5:
		m_failures.append("Roof rotate did not bake yaw into roof_rotation_degrees")
	if roof.get_roof_size().distance_to(Vector2(4.0, 6.0)) > 0.01:
		m_failures.append("Roof rotate should not change the footprint size")
	roof.queue_free()


func _validate_roof_rotated_scale() -> void:
	# A roof already rotated 90 degrees, then widened along its local X axis, must
	# grow its width (not its depth): the scale has to follow the rotated frame.
	var roof = _make_roof()
	roof.roof_rotation_degrees = 90.0
	var local_x_scale := Basis.from_scale(Vector3(2.0, 1.0, 1.0))
	roof.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90.0)) * local_x_scale,
		roof.transform.origin
	)
	roof.apply_native_transform(GRID)
	if roof.get_roof_size().distance_to(Vector2(8.0, 6.0)) > 0.01:
		m_failures.append(
			"Rotated roof scaled its depth instead of its width: got %s"
			% [roof.get_roof_size()]
		)
	if absf(roof.roof_rotation_degrees - 90.0) > 0.5:
		m_failures.append("Rotated roof scale did not preserve its rotation")
	roof.queue_free()


func _validate_roof_scale_preserves_size() -> void:
	# A non-grid scale must keep the exact scaled footprint; snapping applies to
	# placement, not to the baked size.
	var roof = _make_roof()
	roof.transform = Transform3D(
		roof.transform.basis.scaled(Vector3(1.3, 1.0, 1.3)),
		roof.transform.origin
	)
	roof.apply_native_transform(GRID)
	if roof.get_roof_size().distance_to(Vector2(5.2, 7.8)) > 0.001:
		m_failures.append(
			"Roof scale did not preserve the exact scaled size: got %s"
			% [roof.get_roof_size()]
		)
	if roof.start_point.distance_to(Vector3.ZERO) > 0.001:
		m_failures.append("Roof scale around its pivot should keep the anchor put")
	roof.queue_free()


func _validate_roof_offgrid_translate_snaps() -> void:
	# Moving a block off-grid snaps its placement to the grid while keeping size.
	var roof = _make_roof()
	roof.transform = Transform3D(roof.transform.basis, Vector3(2.3, 0.0, 3.1))
	roof.apply_native_transform(GRID)
	if roof.start_point.distance_to(Vector3(2.5, 0.0, 3.0)) > 0.001:
		m_failures.append(
			"Off-grid roof translate did not snap the placement: got %s"
			% [roof.start_point]
		)
	if roof.get_roof_size().distance_to(Vector2(4.0, 6.0)) > 0.001:
		m_failures.append("Roof translate should not change the footprint size")
	roof.queue_free()


func _validate_roof_external_delta() -> void:
	# A child block's own node transform does not change when an ancestor is
	# gizmo-edited; propagation supplies the ancestor's delta directly, so the
	# bake must resize from the supplied delta rather than the (unchanged) self
	# transform.
	var roof = _make_roof()
	var external_scale := Transform3D(Basis.from_scale(Vector3(2.0, 1.0, 2.0)), Vector3.ZERO)
	roof.bake_external_delta(external_scale, GRID)
	if roof.get_roof_size().distance_to(Vector2(8.0, 12.0)) > 0.01:
		m_failures.append(
			"External delta did not bake scale into a child roof: got %s"
			% [roof.get_roof_size()]
		)
	roof.queue_free()


func _validate_pillar_scale_translate() -> void:
	var pillar := RoundPillar3DScript.new()
	pillar.base_point = Vector3.ZERO
	pillar.pillar_radius = 0.25
	pillar.pillar_height = 2.4
	add_child(pillar)
	pillar.transform = Transform3D(Basis.from_scale(Vector3(2.0, 3.0, 2.0)), Vector3(1.0, 0.0, 1.0))
	pillar.apply_native_transform(GRID)
	if pillar.base_point.distance_to(Vector3(1.0, 0.0, 1.0)) > 0.01:
		m_failures.append("Pillar translate did not move the base point")
	if absf(pillar.pillar_radius - 0.5) > 0.01:
		m_failures.append("Pillar horizontal scale did not bake into radius")
	if absf(pillar.pillar_height - 7.2) > 0.01:
		m_failures.append("Pillar vertical scale did not bake into height")
	if pillar.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
		m_failures.append("Pillar scale did not reset node scale to 1")
	pillar.queue_free()


func _validate_rail_translate() -> void:
	var rail := Rail3DScript.new()
	rail.start_point = Vector3.ZERO
	rail.end_point = Vector3(4.0, 0.0, 0.0)
	add_child(rail)
	rail.transform = Transform3D(rail.transform.basis, rail.transform.origin + Vector3(1.0, 0.0, 1.0))
	rail.apply_native_transform(GRID)
	if rail.start_point.distance_to(Vector3(1.0, 0.0, 1.0)) > 0.01:
		m_failures.append("Rail translate did not move the start point")
	if rail.end_point.distance_to(Vector3(5.0, 0.0, 1.0)) > 0.01:
		m_failures.append("Rail translate did not move the end point")
	rail.queue_free()


func _validate_floor_translate() -> void:
	var floor_node := Floor3DScript.new()
	floor_node.set_floor_corners(Vector3.ZERO, Vector3(4.0, 0.0, 4.0))
	add_child(floor_node)
	floor_node.transform = Transform3D(
		floor_node.transform.basis,
		floor_node.transform.origin + Vector3(2.0, 0.0, 2.0)
	)
	floor_node.apply_native_transform(GRID)
	if floor_node.start_point.distance_to(Vector3(2.0, 0.0, 2.0)) > 0.01:
		m_failures.append("Floor translate did not move the start corner")
	if floor_node.end_point.distance_to(Vector3(6.0, 0.0, 6.0)) > 0.01:
		m_failures.append("Floor translate did not move the far corner")
	floor_node.queue_free()


func _validate_floor_scale_preserves_anchor() -> void:
	# Scaling a floor around its min-corner anchor must keep that anchor put and
	# grid-aligned, and preserve the exact scaled size — even when start_point is
	# the far corner and the scale is off-grid. Snapping the far corner instead
	# would shift the whole slab and move its position.
	var floor_node := Floor3DScript.new()
	# start_point is the max corner; the min corner (anchor) sits on the grid.
	floor_node.set_floor_corners(Vector3(4.0, 0.0, 4.0), Vector3.ZERO)
	add_child(floor_node)
	floor_node.transform = Transform3D(
		floor_node.transform.basis.scaled(Vector3(1.3, 1.0, 1.3)),
		floor_node.transform.origin
	)
	floor_node.apply_native_transform(GRID)
	var min_corner := Vector3(
		minf(floor_node.start_point.x, floor_node.end_point.x),
		floor_node.start_point.y,
		minf(floor_node.start_point.z, floor_node.end_point.z)
	)
	if min_corner.distance_to(Vector3.ZERO) > 0.001:
		m_failures.append(
			"Floor scale moved the min-corner anchor off its position: got %s"
			% [min_corner]
		)
	if floor_node.get_floor_size().distance_to(Vector2(5.2, 5.2)) > 0.001:
		m_failures.append(
			"Floor scale did not preserve the exact scaled size: got %s"
			% [floor_node.get_floor_size()]
		)
	floor_node.queue_free()


func _validate_floor_holes_scale() -> void:
	var floor_node := Floor3DScript.new()
	floor_node.set_floor_corners(Vector3.ZERO, Vector3(4.0, 0.0, 4.0))
	floor_node.set_floor_hole_polygons([
		PackedVector2Array([
			Vector2(1.0, 1.0),
			Vector2(2.0, 1.0),
			Vector2(2.0, 2.0),
			Vector2(1.0, 2.0),
		])
	])
	add_child(floor_node)
	floor_node.transform = Transform3D(Basis.from_scale(Vector3(2.0, 1.0, 2.0)), Vector3.ZERO)
	floor_node.apply_native_transform(GRID)
	var holes := floor_node.get_floor_hole_polygons()
	if holes.size() != 1:
		m_failures.append("Floor native scale did not preserve polygon holes")
	else:
		var expected := PackedVector2Array([
			Vector2(2.0, 2.0),
			Vector2(4.0, 2.0),
			Vector2(4.0, 4.0),
			Vector2(2.0, 4.0),
		])
		if !_polygon2_matches(holes[0], expected, 0.01):
			m_failures.append("Floor native scale did not transform holes with the slab")
	floor_node.queue_free()


func _validate_floor_pitch_is_ignored() -> void:
	var floor_node := Floor3DScript.new()
	floor_node.set_floor_corners(Vector3.ZERO, Vector3(4.0, 0.0, 4.0))
	add_child(floor_node)
	floor_node.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0)), Vector3.ZERO)
	floor_node.apply_native_transform(GRID)
	if floor_node.start_point.distance_to(Vector3.ZERO) > 0.001:
		m_failures.append("Pitch-only native floor edit should not change start_point")
	if floor_node.end_point.distance_to(Vector3(4.0, 0.0, 4.0)) > 0.001:
		m_failures.append("Pitch-only native floor edit should not change end_point")
	if !BuildingMeshScript.native_transform_is_identity(floor_node.transform):
		m_failures.append("Pitch-only native floor edit should reset the raw node transform")
	floor_node.queue_free()


func _validate_flat_polygon_roof_translate_preserves_shape() -> void:
	var roof := FlatRoof3DScript.new()
	roof.set_roof_polygon(PackedVector3Array([
		Vector3.ZERO,
		Vector3(1.3, 0.0, 0.0),
		Vector3(1.3, 0.0, 1.3),
		Vector3(0.0, 0.0, 1.3),
	]))
	add_child(roof)
	roof.transform = Transform3D(roof.transform.basis, roof.transform.origin + Vector3(0.2, 0.0, 0.1))
	roof.apply_native_transform(GRID)
	var points := roof.get_roof_polygon()
	var expected := PackedVector3Array([
		Vector3.ZERO,
		Vector3(1.3, 0.0, 0.0),
		Vector3(1.3, 0.0, 1.3),
		Vector3(0.0, 0.0, 1.3),
	])
	if !_polygon3_matches(points, expected, 0.001):
		m_failures.append("Flat polygon roof native snap changed the authored shape")
	roof.queue_free()


func _validate_parent_move_preserves_child_local_positions() -> void:
	var parent := Building3DScript.new() as Building3DScript
	add_child(parent)
	var first := RoundPillar3DScript.new()
	var second := RoundPillar3DScript.new()
	parent.add_child(first)
	parent.add_child(second)
	first.set_pillar_base_position(Vector3.ZERO)
	second.set_pillar_base_position(Vector3(0.25, 0.0, 2.0))
	var first_local_before := first.transform.origin
	var second_local_before := second.transform.origin
	var first_base_before := first.base_point
	var second_base_before := second.base_point
	parent.transform = Transform3D(parent.transform.basis, Vector3(3.0, 0.0, 4.0))
	if first.transform.origin.distance_to(first_local_before) > 0.001:
		m_failures.append("Parent move changed the first child's local transform")
	if second.transform.origin.distance_to(second_local_before) > 0.001:
		m_failures.append("Parent move changed the second child's local transform")
	if first.base_point.distance_to(first_base_before) > 0.001:
		m_failures.append("Parent move rewrote the first child's authored base point")
	if second.base_point.distance_to(second_base_before) > 0.001:
		m_failures.append("Parent move rewrote the second child's authored base point")
	parent.queue_free()


func _validate_parent_block_move_preserves_child_local_positions() -> void:
	var parent := RoundPillar3DScript.new()
	var child := RoundPillar3DScript.new()
	add_child(parent)
	parent.add_child(child)
	parent.set_pillar_base_position(Vector3(1.0, 0.0, 1.0))
	child.set_pillar_base_position(Vector3(0.25, 0.0, 2.0))
	var child_local_before := child.transform.origin
	var child_base_before := child.base_point
	parent.transform = Transform3D(
		parent.transform.basis,
		parent.transform.origin + Vector3(2.0, 0.0, 0.0)
	)
	parent.apply_native_transform(GRID)
	if parent.base_point.distance_to(Vector3(3.0, 0.0, 1.0)) > 0.001:
		m_failures.append("Parent block move did not bake into the selected block")
	if child.transform.origin.distance_to(child_local_before) > 0.001:
		m_failures.append("Parent block move changed child local transform")
	if child.base_point.distance_to(child_base_before) > 0.001:
		m_failures.append("Parent block move rewrote child authored base point")
	parent.queue_free()


func _validate_parent_block_rotate_preserves_child_local_positions() -> void:
	var parent = _make_roof()
	var child := RoundPillar3DScript.new()
	parent.add_child(child)
	child.set_pillar_base_position(Vector3(0.25, 0.0, 2.0))
	var child_local_before := child.transform.origin
	var child_base_before := child.base_point
	parent.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90.0)) * parent.transform.basis,
		parent.transform.origin
	)
	parent.apply_native_transform(GRID)
	if absf(parent.roof_rotation_degrees - 90.0) > 0.5:
		m_failures.append("Parent block rotate did not bake into the selected block")
	if child.transform.origin.distance_to(child_local_before) > 0.001:
		m_failures.append("Parent block rotate changed child local transform")
	if child.base_point.distance_to(child_base_before) > 0.001:
		m_failures.append("Parent block rotate rewrote child authored base point")
	parent.queue_free()


func _validate_shared_parent_bake_preserves_spacing() -> void:
	var first := RoundPillar3DScript.new()
	var second := RoundPillar3DScript.new()
	first.base_point = Vector3.ZERO
	second.base_point = Vector3(0.25, 0.0, 2.0)
	add_child(first)
	add_child(second)
	var old_delta := second.base_point - first.base_point
	var raw_parent_delta := Transform3D(Basis.IDENTITY, Vector3(0.3, 0.0, 0.0))
	var shared_offset := BuildingMeshScript.grid_snap_offset(raw_parent_delta.origin, GRID)
	var snapped_parent_delta := Transform3D(
		raw_parent_delta.basis,
		raw_parent_delta.origin + shared_offset
	)
	first.bake_external_delta(snapped_parent_delta, 0.0)
	second.bake_external_delta(snapped_parent_delta, 0.0)
	var new_delta := second.base_point - first.base_point
	if new_delta.distance_to(old_delta) > 0.001:
		m_failures.append("Shared parent bake changed child spacing")
	if first.base_point.distance_to(Vector3(0.5, 0.0, 0.0)) > 0.001:
		m_failures.append("Shared parent bake did not snap the group placement")
	first.queue_free()
	second.queue_free()


func _polygon2_matches(
	actual: PackedVector2Array,
	expected: PackedVector2Array,
	tolerance: float
) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		if actual[index].distance_to(expected[index]) > tolerance:
			return false
	return true


func _polygon3_matches(
	actual: PackedVector3Array,
	expected: PackedVector3Array,
	tolerance: float
) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		if actual[index].distance_to(expected[index]) > tolerance:
			return false
	return true
