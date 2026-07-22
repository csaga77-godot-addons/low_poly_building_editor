@tool
class_name SpiralStairs3D
extends "res://addons/low_poly_building_editor/stairs/turning_stairs_3d.gd"

const SpiralGeometry := preload(
	"res://addons/low_poly_building_editor/stairs/spiral_geometry_3d.gd"
)

const SPIRAL_MAX_TREAD_ANGLE_DEGREES := 45.0

@export_range(45.0, 1080.0, 1.0) var spiral_turn_degrees := 360.0:
	set(value):
		var clamped_value := clampf(value, 45.0, 1080.0)
		if is_equal_approx(spiral_turn_degrees, clamped_value):
			return
		spiral_turn_degrees = clamped_value
		_request_rebuild()


func _create_segment_geometry() -> StairSegmentGeometry:
	return SpiralGeometry.new()


func _spiral_geometry() -> SpiralGeometry:
	return _segment_geometry() as SpiralGeometry


func _append_stair_layout_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_append_layout_geometry(
		_build_layout_plan(width, depth), vertices, normals, colors, indices
	)


func _build_layout_plan(width: float, depth: float) -> Dictionary:
	var fw := _clamped_layout_flight_width(
		width, depth, minf(width, depth) * 0.5 - 0.05
	)
	var outer_radius := minf(width, depth) * 0.5
	var inner_radius := clampf(outer_radius - fw, 0.05, outer_radius - 0.05)
	var minimum_steps := ceili(
		spiral_turn_degrees / SPIRAL_MAX_TREAD_ANGLE_DEGREES
	)
	var steps := maxi(_effective_step_count(), minimum_steps)
	var rise := maxf(stair_height, 0.05) / float(maxi(steps, 1))
	var margin := minf(rail_edge_margin, fw * 0.45)
	var turn_radians := deg_to_rad(spiral_turn_degrees)
	var center := Vector2(width * 0.5, depth * 0.5)
	var segments: Array[Dictionary] = [{
		"kind": SegmentKind.SEGMENT_LAYOUT_SPECIFIC,
		"origin": Vector3.ZERO,
		"run_axis": Vector3.BACK,
		"width_axis": Vector3.UP.cross(Vector3.BACK).normalized(),
		"width": width,
		"run": depth,
		"steps": steps,
		"rise": rise,
		"center": center,
		"outer_radius": outer_radius,
		"inner_radius": inner_radius,
		"turn_radians": turn_radians,
		"turn_sign": 1.0,
	}]
	var rail_radius := maxf(outer_radius - margin, inner_radius + 0.02)
	var rail_length := rail_radius * turn_radians
	var spiral_rail := {
		"side": RAIL_SIDE_LEFT,
		"center": center,
		"radius": rail_radius,
		"turn_radians": turn_radians,
		"turn_sign": 1.0,
		"length": rail_length,
		"rise": maxf(stair_height, 0.05),
		"steps": steps,
		"post_layout": _build_rail_post_layout(
			rail_length,
			maxf(stair_height, 0.05),
			steps,
			lower_newel_enabled,
			upper_newel_enabled,
			middle_newel_post_count,
			lower_newel_placement,
			upper_newel_placement
		),
	}
	var plan := {
		"segments": segments,
		"rail_runs": [] as Array[Dictionary],
		"spiral_rail": spiral_rail,
		"flight_width": fw,
		"total_steps": steps,
		"rise": rise,
	}
	if turn_direction == TurnDirection.LEFT:
		_mirror_layout_plan(plan, width)
	return plan


func _append_layout_specific_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_spiral_geometry().append_radial_wedge_sequence_primitive(
		seg, vertices, normals, colors, indices
	)


func _append_layout_specific_rail_geometry(
	plan: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if !plan.has("spiral_rail"):
		return
	var rail: Dictionary = plan["spiral_rail"]
	var side: int = rail["side"]
	if (
		(side == RAIL_SIDE_LEFT and left_rail_enabled)
		or (side == RAIL_SIDE_RIGHT and right_rail_enabled)
	):
		_append_helical_rail_primitive(
			rail, vertices, normals, colors, indices
		)


func _add_layout_specific_slope_collision_shapes(
	body: StaticBody3D,
	seg: Dictionary,
	shape_index: int
) -> int:
	return _add_radial_wedge_slope_collision_shapes(
		body, seg, shape_index
	)


func configure_spiral_layout(
	new_turn_direction: int,
	new_flight_width: float,
	new_spiral_turn_degrees: float
) -> void:
	configure_turning_layout(new_turn_direction, new_flight_width)
	spiral_turn_degrees = new_spiral_turn_degrees


func _mirror_layout_specific_plan(plan: Dictionary, width: float) -> void:
	for seg: Dictionary in plan["segments"]:
		if !seg.has("center"):
			continue
		var segment_width: float = seg["width"]
		var center: Vector2 = seg["center"]
		seg["center"] = Vector2(segment_width - center.x, center.y)
		seg["turn_sign"] = -float(seg["turn_sign"])
	if !plan.has("spiral_rail"):
		return
	var spiral_rail: Dictionary = plan["spiral_rail"]
	var rail_center: Vector2 = spiral_rail["center"]
	spiral_rail["center"] = Vector2(width - rail_center.x, rail_center.y)
	spiral_rail["turn_sign"] = -float(spiral_rail["turn_sign"])
	spiral_rail["side"] = (
		RAIL_SIDE_RIGHT
			if int(spiral_rail["side"]) == RAIL_SIDE_LEFT
			else RAIL_SIDE_LEFT
	)


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(spiral_turn_degrees)
	return values


func _normalize_tread_style(value: int) -> int:
	return TreadStyle.OPEN if value == TreadStyle.OPEN else TreadStyle.CLOSED


func _validate_property(property: Dictionary) -> void:
	var property_name := StringName(property.get("name", &""))
	if property_name == &"tread_style":
		property["hint"] = PROPERTY_HINT_ENUM
		property["hint_string"] = "Closed,Open"
	elif property_name == &"nosing_depth":
		property["usage"] = int(property.get("usage", 0)) & ~PROPERTY_USAGE_EDITOR


func _add_radial_wedge_slope_collision_shapes(
	body: StaticBody3D,
	seg: Dictionary,
	shape_index: int
) -> int:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var center: Vector2 = seg["center"]
	var outer_radius: float = seg["outer_radius"]
	var inner_radius: float = seg["inner_radius"]
	var turn_radians: float = seg["turn_radians"]
	var turn_sign: float = seg["turn_sign"]
	if steps <= 0:
		return shape_index
	var slab := _tread_slab_thickness()
	for tread_index in range(steps):
		var theta0 := turn_radians * float(tread_index) / float(steps)
		var theta1 := turn_radians * float(tread_index + 1) / float(steps)
		var inner0 := center + _radial_direction(theta0, turn_sign) * inner_radius
		var inner1 := center + _radial_direction(theta1, turn_sign) * inner_radius
		var outer0 := center + _radial_direction(theta0, turn_sign) * outer_radius
		var outer1 := center + _radial_direction(theta1, turn_sign) * outer_radius
		var top0 := _slope_surface_height(
			theta0, turn_radians, steps, rise
		)
		var top1 := _slope_surface_height(
			theta1, turn_radians, steps, rise
		)
		var bottom0 := top0 - slab
		var bottom1 := top1 - slab
		var points := PackedVector3Array([
			_segment_point(seg, Vector3(inner0.x, top0, inner0.y)),
			_segment_point(seg, Vector3(outer0.x, top0, outer0.y)),
			_segment_point(seg, Vector3(inner1.x, top1, inner1.y)),
			_segment_point(seg, Vector3(outer1.x, top1, outer1.y)),
			_segment_point(seg, Vector3(inner0.x, bottom0, inner0.y)),
			_segment_point(seg, Vector3(outer0.x, bottom0, outer0.y)),
			_segment_point(seg, Vector3(inner1.x, bottom1, inner1.y)),
			_segment_point(seg, Vector3(outer1.x, bottom1, outer1.y)),
		])
		_add_slope_collision_shape(
			body, _layout_collision_shape_name(shape_index), points
		)
		shape_index += 1

	var column_radius := inner_radius / cos(
		PI / float(SpiralGeometry.SPIRAL_COLUMN_SIDES)
	)
	var column_bottom := -maxf(stair_thickness, 0.0)
	var column_top := maxf(stair_height, 0.05)
	var column_points := PackedVector3Array()
	for side_index in range(SpiralGeometry.SPIRAL_COLUMN_SIDES):
		var angle := TAU * float(side_index) / float(SpiralGeometry.SPIRAL_COLUMN_SIDES)
		var point := center + Vector2(cos(angle), sin(angle)) * column_radius
		column_points.append(
			_segment_point(seg, Vector3(point.x, column_bottom, point.y))
		)
		column_points.append(
			_segment_point(seg, Vector3(point.x, column_top, point.y))
		)
	_add_slope_collision_shape(body, "ColumnCollisionShape3D", column_points)
	return shape_index


func _radial_direction(theta: float, turn_sign: float) -> Vector2:
	return SpiralGeometry.radial_direction(theta, turn_sign)


func _helical_rail_member_extents(rail: Dictionary) -> Vector2:
	return _spiral_geometry().helical_rail_member_extents(rail)


func _helical_rail_sample_positions(
	rail: Dictionary,
	minimum_run: float,
	maximum_run: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float
) -> PackedFloat32Array:
	return _spiral_geometry().helical_rail_sample_positions(
		rail, minimum_run, maximum_run, lower_horizontal_end, upper_horizontal_start
	)


func _append_helical_rail_primitive(
	rail: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_spiral_geometry().append_helical_rail_primitive(
		rail, vertices, normals, colors, indices
	)
