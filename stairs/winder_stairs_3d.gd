@tool
class_name WinderStairs3D
extends "res://addons/low_poly_building_editor/stairs/turning_stairs_3d.gd"

enum WinderTurn {
	TURN_90,
	TURN_180,
}

const WINDER_TREADS_90 := 3
const WINDER_TREADS_180 := 6

const WinderFanGeometry := preload(
	"res://addons/low_poly_building_editor/stairs/winder_fan_geometry_3d.gd"
)

@export_enum("90 Degrees", "180 Degrees") var winder_turn: int = WinderTurn.TURN_90:
	set(value):
		var clamped_value := clampi(value, WinderTurn.TURN_90, WinderTurn.TURN_180)
		if winder_turn == clamped_value:
			return
		winder_turn = clamped_value
		_request_rebuild()


func _create_segment_geometry() -> StairSegmentGeometry:
	return WinderFanGeometry.new()


func _fan_geometry() -> WinderFanGeometry:
	return _segment_geometry() as WinderFanGeometry


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
	if winder_turn == WinderTurn.TURN_180:
		return _build_180_degree_winder_plan(width, depth)
	return _build_90_degree_winder_plan(width, depth)


func _append_layout_specific_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_fan_geometry().append_radial_fan_segment_primitive(
		seg, vertices, normals, colors, indices
	)


func _add_layout_specific_slope_collision_shapes(
	body: StaticBody3D,
	seg: Dictionary,
	shape_index: int
) -> int:
	return _add_radial_fan_slope_collision_shapes(
		body, seg, shape_index
	)


func _build_90_degree_winder_plan(width: float, depth: float) -> Dictionary:
	var fw := _clamped_layout_flight_width(
		width, depth, minf(width, depth) * 0.5
	)
	var r1 := depth - fw
	var r2 := width - fw
	var context := _create_turning_plan_context(
		PackedFloat32Array([r1, r2]), WINDER_TREADS_90
	)
	var flight_steps: PackedInt32Array = context["flight_steps"]
	var rise: float = context["rise"]
	var middle_shares: PackedInt32Array = context["middle_shares"]
	var post_spacing: float = context["post_spacing"]
	var segments: Array[Dictionary] = context["segments"]
	var rail_runs: Array[Dictionary] = context["rail_runs"]
	var margin := minf(rail_edge_margin, fw * 0.45)
	var n1 := flight_steps[0]
	var n2 := flight_steps[1]
	var h1 := rise * float(n1)
	var hw := rise * float(WINDER_TREADS_90)
	var turn_height := h1 + hw
	var no_extra_walls: Array[Dictionary] = []

	segments.append(_make_flight_segment(
		Vector3.ZERO, Vector3.BACK, fw, r1, n1, rise
	))
	segments.append(_make_winder_segment(
		Vector3(0.0, h1, r1), Vector3.BACK, fw, fw,
		WINDER_TREADS_90, rise,
		Vector2(fw, 0.0),
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(0.0, fw),
			Vector2(fw, fw),
		]),
		no_extra_walls
	))
	segments.append(_make_flight_segment(
		Vector3(fw, turn_height, depth), Vector3.RIGHT, fw, r2, n2, rise
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw - margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_LEFT,
		[
			Vector2(margin, r1),
			Vector2(margin, depth - margin),
			Vector2(fw, depth - margin),
		],
		h1, hw, WINDER_TREADS_90, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(fw, turn_height, depth - margin), Vector3.RIGHT,
		r2, rise * float(n2), n2, false, true, middle_shares[1]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_RIGHT,
		[
			Vector2(fw - margin, r1),
			Vector2(fw - margin, r1 + margin),
			Vector2(fw, r1 + margin),
		],
		h1, hw, 0, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw, turn_height, r1 + margin), Vector3.RIGHT,
		r2, rise * float(n2), n2, false, true, middle_shares[1]
	))
	return _finish_turning_plan(context, width, fw)


func _build_180_degree_winder_plan(width: float, depth: float) -> Dictionary:
	var fw := _clamped_layout_flight_width(
		width, depth, minf(width * 0.5, depth * 0.5)
	)
	var r1 := depth - fw
	var context := _create_turning_plan_context(
		PackedFloat32Array([r1, r1]), WINDER_TREADS_180
	)
	var flight_steps: PackedInt32Array = context["flight_steps"]
	var rise: float = context["rise"]
	var middle_shares: PackedInt32Array = context["middle_shares"]
	var post_spacing: float = context["post_spacing"]
	var segments: Array[Dictionary] = context["segments"]
	var rail_runs: Array[Dictionary] = context["rail_runs"]
	var margin := minf(rail_edge_margin, fw * 0.45)
	var n1 := flight_steps[0]
	var n2 := flight_steps[1]
	var h1 := rise * float(n1)
	var hw := rise * float(WINDER_TREADS_180)
	var turn_height := h1 + hw
	var extra_walls: Array[Dictionary] = [
		{
			"a": Vector2(fw, 0.0),
			"b": Vector2(width * 0.5, 0.0),
			"top": 0.0,
			"normal": Vector2(0.0, -1.0),
		},
		{
			"a": Vector2(width * 0.5, 0.0),
			"b": Vector2(width - fw, 0.0),
			"top": hw,
			"normal": Vector2(0.0, -1.0),
		},
	]

	segments.append(_make_flight_segment(
		Vector3.ZERO, Vector3.BACK, fw, r1, n1, rise
	))
	segments.append(_make_winder_segment(
		Vector3(0.0, h1, r1), Vector3.BACK, width, fw,
		WINDER_TREADS_180, rise,
		Vector2(width * 0.5, 0.0),
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(0.0, fw),
			Vector2(width, fw),
			Vector2(width, 0.0),
		]),
		extra_walls
	))
	segments.append(_make_flight_segment(
		Vector3(width, turn_height, r1), Vector3.FORWARD, fw, r1, n2, rise
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw - margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_LEFT,
		[
			Vector2(margin, r1),
			Vector2(margin, depth - margin),
			Vector2(width - margin, depth - margin),
			Vector2(width - margin, r1),
		],
		h1, hw, WINDER_TREADS_180, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(width - margin, turn_height, r1), Vector3.FORWARD,
		r1, rise * float(n2), n2, false, true, middle_shares[1]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_RIGHT,
		[
			Vector2(fw - margin, r1),
			Vector2(fw - margin, r1 + margin),
			Vector2(width - fw + margin, r1 + margin),
			Vector2(width - fw + margin, r1),
		],
		h1, hw, 0, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(width - fw + margin, turn_height, r1), Vector3.FORWARD,
		r1, rise * float(n2), n2, false, true, middle_shares[1]
	))
	return _finish_turning_plan(context, width, fw)


func configure_winder_layout(
	new_turn_direction: int,
	new_flight_width: float,
	new_winder_turn: int,
) -> void:
	configure_turning_layout(new_turn_direction, new_flight_width)
	winder_turn = new_winder_turn


func _make_winder_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float,
	steps: int,
	rise: float,
	pivot: Vector2,
	perimeter: PackedVector2Array,
	extra_walls: Array[Dictionary]
) -> Dictionary:
	return {
		"kind": SegmentKind.SEGMENT_LAYOUT_SPECIFIC,
		"origin": origin,
		"run_axis": run_dir,
		"width_axis": Vector3.UP.cross(run_dir).normalized(),
		"width": width,
		"run": run_length,
		"steps": maxi(steps, 1),
		"rise": rise,
		"pivot": pivot,
		"perimeter": perimeter,
		"extra_walls": extra_walls,
	}


func _mirror_layout_specific_plan(plan: Dictionary, _width: float) -> void:
	for seg: Dictionary in plan["segments"]:
		if !seg.has("pivot"):
			continue
		var segment_width: float = seg["width"]
		var pivot: Vector2 = seg["pivot"]
		seg["pivot"] = Vector2(segment_width - pivot.x, pivot.y)
		var perimeter: PackedVector2Array = seg["perimeter"]
		var mirrored_perimeter := PackedVector2Array()
		for point in perimeter:
			mirrored_perimeter.append(Vector2(segment_width - point.x, point.y))
		seg["perimeter"] = mirrored_perimeter
		for wall: Dictionary in seg["extra_walls"]:
			var a: Vector2 = wall["a"]
			var b: Vector2 = wall["b"]
			wall["a"] = Vector2(segment_width - a.x, a.y)
			wall["b"] = Vector2(segment_width - b.x, b.y)


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(winder_turn)
	return values


func _add_radial_fan_slope_collision_shapes(
	body: StaticBody3D,
	seg: Dictionary,
	shape_index: int
) -> int:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var pivot: Vector2 = seg["pivot"]
	var perimeter: PackedVector2Array = seg["perimeter"]
	var cumulative := WinderFanGeometry.radial_fan_perimeter_cumulative(perimeter)
	var total_length := cumulative[cumulative.size() - 1]
	if total_length <= 0.001:
		return shape_index
	var slab := _tread_slab_thickness()
	for tread_index in range(steps):
		var t0 := total_length * float(tread_index) / float(steps)
		var t1 := total_length * float(tread_index + 1) / float(steps)
		var edge_samples: Array[Dictionary] = [{
			"distance": t0,
			"point": WinderFanGeometry.radial_fan_point_at(
				perimeter, cumulative, t0
			),
		}]
		for corner_index in range(1, perimeter.size() - 1):
			var corner_distance := cumulative[corner_index]
			if corner_distance > t0 + 0.0001 and corner_distance < t1 - 0.0001:
				edge_samples.append({
					"distance": corner_distance,
					"point": perimeter[corner_index],
				})
		edge_samples.append({
			"distance": t1,
			"point": WinderFanGeometry.radial_fan_point_at(
				perimeter, cumulative, t1
			),
		})
		for edge_index in range(edge_samples.size() - 1):
			var start_sample: Dictionary = edge_samples[edge_index]
			var end_sample: Dictionary = edge_samples[edge_index + 1]
			var q0: Vector2 = start_sample["point"]
			var q1: Vector2 = end_sample["point"]
			if q0.distance_to(q1) <= 0.0001:
				continue
			var top0 := _slope_surface_height(
				float(start_sample["distance"]), total_length, steps, rise
			)
			var top1 := _slope_surface_height(
				float(end_sample["distance"]), total_length, steps, rise
			)
			var bottom0 := minf(_segment_bottom(seg), -COLLISION_MINIMUM_THICKNESS)
			var bottom1 := bottom0
			if tread_style == TreadStyle.OPEN:
				bottom0 = top0 - slab
				bottom1 = top1 - slab
			var points := PackedVector3Array([
				_segment_point(seg, Vector3(pivot.x, top0, pivot.y)),
				_segment_point(seg, Vector3(q0.x, top0, q0.y)),
				_segment_point(seg, Vector3(pivot.x, top1, pivot.y)),
				_segment_point(seg, Vector3(q1.x, top1, q1.y)),
				_segment_point(seg, Vector3(pivot.x, bottom0, pivot.y)),
				_segment_point(seg, Vector3(q0.x, bottom0, q0.y)),
				_segment_point(seg, Vector3(pivot.x, bottom1, pivot.y)),
				_segment_point(seg, Vector3(q1.x, bottom1, q1.y)),
			])
			_add_slope_collision_shape(
				body, _layout_collision_shape_name(shape_index), points
			)
			shape_index += 1
	return shape_index
