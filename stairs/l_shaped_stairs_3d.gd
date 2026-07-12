@tool
class_name LShapedStairs3D
extends "res://addons/low_poly_building_editor/stairs/turning_stairs_3d.gd"


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
		width, depth, minf(width, depth) * 0.5
	)
	var run_lengths := PackedFloat32Array([depth - fw, width - fw])
	var context := _create_turning_plan_context(run_lengths, 0)
	var flight_steps: PackedInt32Array = context["flight_steps"]
	var rise: float = context["rise"]
	var middle_shares: PackedInt32Array = context["middle_shares"]
	var post_spacing: float = context["post_spacing"]
	var segments: Array[Dictionary] = context["segments"]
	var rail_runs: Array[Dictionary] = context["rail_runs"]
	var margin := minf(rail_edge_margin, fw * 0.45)
	var r1 := depth - fw
	var r2 := width - fw
	var n1 := flight_steps[0]
	var n2 := flight_steps[1]
	var h1 := rise * float(n1)

	segments.append(_make_flight_segment(
		Vector3.ZERO, Vector3.BACK, fw, r1, n1, rise
	))
	segments.append(_make_landing_segment(
		Vector3(0.0, h1, r1), Vector3.BACK, fw, fw
	))
	segments.append(_make_flight_segment(
		Vector3(fw, h1, depth), Vector3.RIGHT, fw, r2, n2, rise
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
		h1, 0.0, 0, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(fw, h1, depth - margin), Vector3.RIGHT,
		r2, rise * float(n2), n2, false, true, middle_shares[1]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_RIGHT,
		[
			Vector2(fw - margin, r1),
			Vector2(fw - margin, r1 + margin),
			Vector2(fw, r1 + margin),
		],
		h1, 0.0, 0, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw, h1, r1 + margin), Vector3.RIGHT,
		r2, rise * float(n2), n2, false, true, middle_shares[1]
	))
	return _finish_turning_plan(context, width, fw)
