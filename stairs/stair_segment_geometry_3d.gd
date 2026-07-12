@tool
extends RefCounted

# Internal geometry-strategy base for stair layouts, mirroring the roof
# geometry-strategy split: stair nodes own authored state, planning, and
# collision orchestration, while this class owns the reusable segment mesh
# primitives (flights, landings, tread slabs, nosing lips, side strips).
# `Stairs3D` configures one instance per node via
# `_configure_segment_geometry()` and concrete layouts substitute their own
# subclass through `_create_segment_geometry()`.

enum TreadStyle {
	CLOSED,
	OPEN,
	NOSING,
}

enum SegmentKind {
	SEGMENT_FLIGHT,
	SEGMENT_LANDING,
	SEGMENT_LAYOUT_SPECIFIC,
}

var stair_color := Color(0.52, 0.46, 0.38, 1.0)
var stair_thickness := 0.12
var tread_style: int = TreadStyle.CLOSED
var nosing_depth := 0.08
var stair_height := 1.2
var rail_height := 1.0
var rail_thickness := 0.1
var rail_lower_height := 0.18
var rail_color := Color(0.33, 0.28, 0.22, 1.0)
var infill_style := 0
var infill_count_between_newels := 1
var infill_rail_thickness := 0.08


static func make_flight_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float,
	steps: int,
	rise: float
) -> Dictionary:
	return {
		"kind": SegmentKind.SEGMENT_FLIGHT,
		"origin": origin,
		"run_axis": run_dir,
		"width_axis": Vector3.UP.cross(run_dir).normalized(),
		"width": width,
		"run": run_length,
		"steps": maxi(steps, 1),
		"rise": rise,
	}


static func segment_point(seg: Dictionary, local_point: Vector3) -> Vector3:
	return (
		Vector3(seg["origin"])
		+ Vector3(seg["width_axis"]) * local_point.x
		+ Vector3.UP * local_point.y
		+ Vector3(seg["run_axis"]) * local_point.z
	)


static func segment_direction(seg: Dictionary, local_direction: Vector3) -> Vector3:
	return (
		Vector3(seg["width_axis"]) * local_direction.x
		+ Vector3.UP * local_direction.y
		+ Vector3(seg["run_axis"]) * local_direction.z
	)


func segment_bottom(seg: Dictionary) -> float:
	return -maxf(stair_thickness, 0.0) - Vector3(seg["origin"]).y


func landing_bottom(seg: Dictionary) -> float:
	# Open-riser landings float as slabs instead of dropping to the stair base.
	if tread_style == TreadStyle.OPEN:
		return -tread_slab_thickness()
	return segment_bottom(seg)


func handrail_width() -> float:
	return minf(
		maxf(rail_thickness, 0.02),
		maxf(rail_height, 0.2) * 0.5
	)


func clamped_infill_rail_size() -> float:
	# Like newels, infill geometry never exceeds the handrail cross-section.
	return minf(maxf(infill_rail_thickness, 0.02), handrail_width())


func tread_slab_thickness() -> float:
	# Open tread slabs and nosing lips reuse the underside thickness, with a
	# small floor so zero-thickness stairs still produce visible slabs. Matches
	# the spiral tread slab rule.
	return maxf(stair_thickness, 0.05)


func effective_nosing_depth(tread_depth: float) -> float:
	if tread_style != TreadStyle.NOSING:
		return 0.0
	return clampf(nosing_depth, 0.0, tread_depth * 0.45)


func nosing_lip_thickness(rise: float) -> float:
	# Strictly shallower than one rise so the lip underside never becomes
	# coplanar with the tread top below it.
	return minf(maxf(stair_thickness, 0.02), rise * 0.75)


static func append_oriented_triangle(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	normal: Vector3,
	first: int,
	second: int,
	third: int
) -> void:
	var winding_normal := (
		vertices[second] - vertices[first]
	).cross(
		vertices[third] - vertices[first]
	).normalized()
	if winding_normal.dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([first, third, second]))
	else:
		indices.append_array(PackedInt32Array([first, second, third]))


func append_quad(
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
		colors.append(stair_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func append_embedded_quad(
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
		colors.append(stair_color)
	var winding_normal := (b - a).cross(c - a)
	if winding_normal.length_squared() <= 0.000001:
		winding_normal = (c - a).cross(d - a)
	if winding_normal.dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([
			base, base + 2, base + 1, base, base + 3, base + 2
		]))
	else:
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2, base, base + 2, base + 3
		]))


func append_segment_quad(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	local_normal: Vector3
) -> void:
	append_embedded_quad(
		vertices, normals, colors, indices,
		segment_point(seg, a),
		segment_point(seg, b),
		segment_point(seg, c),
		segment_point(seg, d),
		segment_direction(seg, local_normal).normalized()
	)


func append_segment_box(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	box_min: Vector3,
	box_max: Vector3,
	skip_back := false
) -> void:
	# Axis-aligned box in segment-local space; used for floating tread slabs
	# and nosing lips. skip_back omits the +Z face when it abuts a riser plane.
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_max.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_max.z),
		Vector3(box_max.x, box_max.y, box_max.z),
		Vector3(box_max.x, box_max.y, box_min.z),
		Vector3.UP
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_min.y, box_min.z),
		Vector3(box_min.x, box_min.y, box_max.z),
		Vector3(box_max.x, box_min.y, box_max.z),
		Vector3(box_max.x, box_min.y, box_min.z),
		Vector3.DOWN
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_min.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_min.z),
		Vector3(box_max.x, box_max.y, box_min.z),
		Vector3(box_max.x, box_min.y, box_min.z),
		Vector3.FORWARD
	)
	if !skip_back:
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(box_min.x, box_min.y, box_max.z),
			Vector3(box_min.x, box_max.y, box_max.z),
			Vector3(box_max.x, box_max.y, box_max.z),
			Vector3(box_max.x, box_min.y, box_max.z),
			Vector3.BACK
		)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_min.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_max.z),
		Vector3(box_min.x, box_min.y, box_max.z),
		Vector3.LEFT
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_max.x, box_min.y, box_min.z),
		Vector3(box_max.x, box_max.y, box_min.z),
		Vector3(box_max.x, box_max.y, box_max.z),
		Vector3(box_max.x, box_min.y, box_max.z),
		Vector3.RIGHT
	)


func append_open_flight_treads(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	# Open risers: one floating slab per tread, no risers, no solid underside.
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	var tread_depth := run / float(steps)
	var slab := tread_slab_thickness()
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		append_segment_box(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y1 - slab, z0),
			Vector3(width, y1, z1)
		)


func append_flight_nosing_lips(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	# Nosing: a thin lip box overhanging each riser plane. Additive over the
	# closed mass, so the underlying stepped geometry stays unchanged. The lip
	# back face is skipped: it abuts the riser plane it overhangs.
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	var tread_depth := run / float(steps)
	var nose := effective_nosing_depth(tread_depth)
	if nose <= 0.0005:
		return
	var lip := nosing_lip_thickness(rise)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var y1 := rise * float(step_index + 1)
		append_segment_box(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y1 - lip, z0 - nose),
			Vector3(width, y1, z0),
			true
		)


func append_flight_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	if tread_style == TreadStyle.OPEN:
		append_open_flight_treads(seg, vertices, normals, colors, indices)
		return
	var bottom := segment_bottom(seg)
	var top := rise * float(steps)
	var tread_depth := run / float(steps)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y0 := rise * float(step_index)
		var y1 := rise * float(step_index + 1)
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y1, z0),
			Vector3(0.0, y1, z1),
			Vector3(width, y1, z1),
			Vector3(width, y1, z0),
			Vector3.UP
		)
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y0, z0),
			Vector3(0.0, y1, z0),
			Vector3(width, y1, z0),
			Vector3(width, y0, z0),
			Vector3.FORWARD
		)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom, 0.0),
		Vector3.FORWARD
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, run),
		Vector3(width, bottom, run),
		Vector3(width, top, run),
		Vector3(0.0, top, run),
		Vector3.BACK
	)
	append_segment_side_strips(seg, vertices, normals, colors, indices, 0.0, Vector3.LEFT)
	append_segment_side_strips(seg, vertices, normals, colors, indices, width, Vector3.RIGHT)
	append_flight_nosing_lips(seg, vertices, normals, colors, indices)


func append_segment_side_strips(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	x: float,
	local_normal: Vector3
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var run: float = seg["run"]
	var bottom := segment_bottom(seg)
	var tread_depth := run / float(steps)
	var normal := segment_direction(seg, local_normal).normalized()
	var base := vertices.size()
	for boundary_index in range(steps + 1):
		vertices.append(segment_point(seg, Vector3(
			x, bottom, tread_depth * float(boundary_index)
		)))
		normals.append(normal)
		colors.append(stair_color)
	var top_base := vertices.size()
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		vertices.append(segment_point(seg, Vector3(x, y1, z0)))
		normals.append(normal)
		colors.append(stair_color)
		vertices.append(segment_point(seg, Vector3(x, y1, z1)))
		normals.append(normal)
		colors.append(stair_color)
	for step_index in range(steps):
		var bottom_left := base + step_index
		var bottom_right := bottom_left + 1
		var top_left := top_base + step_index * 2
		var top_right := top_left + 1
		append_oriented_triangle(
			vertices, indices, normal,
			bottom_left, top_left, top_right
		)
		append_oriented_triangle(
			vertices, indices, normal,
			bottom_left, top_right, bottom_right
		)


func append_landing_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	var bottom := landing_bottom(seg)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, run),
		Vector3(width, 0.0, run),
		Vector3(width, 0.0, 0.0),
		Vector3.UP
	)
	if tread_style == TreadStyle.OPEN:
		# Floating landing slabs expose their underside.
		append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, bottom, 0.0),
			Vector3(0.0, bottom, run),
			Vector3(width, bottom, run),
			Vector3(width, bottom, 0.0),
			Vector3.DOWN
		)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom, 0.0),
		Vector3.FORWARD
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, run),
		Vector3(width, bottom, run),
		Vector3(width, 0.0, run),
		Vector3(0.0, 0.0, run),
		Vector3.BACK
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, run),
		Vector3(0.0, bottom, run),
		Vector3.LEFT
	)
	append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(width, bottom, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, 0.0, run),
		Vector3(width, bottom, run),
		Vector3.RIGHT
	)
