@tool
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

enum NewelPlacement {
	TREAD,
	FLOOR,
}

const StairSegmentGeometry := preload(
	"res://addons/low_poly_building_editor/stairs/stair_segment_geometry_3d.gd"
)

# Tread-style and segment-kind values live on the internal geometry-strategy
# base so stair nodes and geometry classes share one definition.
const TreadStyle = StairSegmentGeometry.TreadStyle
const SegmentKind = StairSegmentGeometry.SegmentKind

const StandardRailGeometry := preload(
	"res://addons/low_poly_building_editor/rails/standard_rail_geometry_3d.gd"
)

const GENERATED_META := &"stairs_generated"
const PREVIEW_META := &"building_editor_preview"
const MESH_GEOMETRY_VERSION := 26
const RAIL_SIDE_LEFT := 0
const RAIL_SIDE_RIGHT := 1
const SLOPE_COLLISION_SHAPE_NAME := "SlopeCollisionShape3D"
const RAIL_COLLISION_SHAPE_NAME := "RailCollisionShape3D"
const COLLISION_MINIMUM_THICKNESS := 0.02

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(2.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_range(0.05, 20.0, 0.01, "or_greater") var stair_height := 1.2:
	set(value):
		var clamped_value := maxf(value, 0.05)
		if is_equal_approx(stair_height, clamped_value):
			return
		stair_height = clamped_value
		_request_rebuild()

@export_range(1, 64, 1) var step_count := 6:
	set(value):
		var clamped_value := clampi(value, 1, 64)
		if step_count == clamped_value:
			return
		step_count = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var stair_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(stair_thickness, clamped_value):
			return
		stair_thickness = clamped_value
		_request_rebuild()

# Closed keeps the solid stepped mass; Open floats individual tread slabs with
# no risers or underside; Nosing keeps the closed mass and overhangs each tread
# past the riser below by nosing_depth. Winder fans and spiral treads have no
# nosing variant and treat Nosing as Closed.
@export_enum("Closed", "Open", "Nosing") var tread_style: int = TreadStyle.CLOSED:
	set(value):
		var clamped_value := _normalize_tread_style(value)
		if tread_style == clamped_value:
			return
		tread_style = clamped_value
		_request_rebuild()

@export_range(0.0, 1.0, 0.01, "or_greater") var nosing_depth := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(nosing_depth, clamped_value):
			return
		nosing_depth = clamped_value
		_request_rebuild()

@export_range(-180.0, 180.0, 1.0) var stair_rotation_degrees := 0.0:
	set(value):
		var normalized_value := _normalize_degrees_static(value)
		if is_equal_approx(stair_rotation_degrees, normalized_value):
			return
		stair_rotation_degrees = normalized_value
		_request_rebuild()

@export var stair_color := Color(0.52, 0.46, 0.38, 1.0):
	set(value):
		if stair_color == value:
			return
		stair_color = value
		_request_rebuild()

@export_group("Rails")
@export var left_rail_enabled := false:
	set(value):
		if left_rail_enabled == value:
			return
		left_rail_enabled = value
		_request_rebuild()

@export var right_rail_enabled := false:
	set(value):
		if right_rail_enabled == value:
			return
		right_rail_enabled = value
		_request_rebuild()

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

@export var lower_newel_enabled := false:
	set(value):
		if lower_newel_enabled == value:
			return
		lower_newel_enabled = value
		_request_rebuild()

@export_enum("Tread", "Floor") var lower_newel_placement: int = NewelPlacement.TREAD:
	set(value):
		var normalized_value := clampi(value, NewelPlacement.TREAD, NewelPlacement.FLOOR)
		if lower_newel_placement == normalized_value:
			return
		lower_newel_placement = normalized_value
		_request_rebuild()

@export var upper_newel_enabled := false:
	set(value):
		if upper_newel_enabled == value:
			return
		upper_newel_enabled = value
		_request_rebuild()

@export_enum("Tread", "Floor") var upper_newel_placement: int = NewelPlacement.TREAD:
	set(value):
		var normalized_value := clampi(value, NewelPlacement.TREAD, NewelPlacement.FLOOR)
		if upper_newel_placement == normalized_value:
			return
		upper_newel_placement = normalized_value
		_request_rebuild()

@export_range(0, 64, 1) var middle_newel_post_count := 0:
	set(value):
		var clamped_value := clampi(value, 0, 64)
		if middle_newel_post_count == clamped_value:
			return
		middle_newel_post_count = clamped_value
		_request_rebuild()

@export_range(0, 64, 1) var infill_count_between_newels := 1:
	set(value):
		var clamped_value := clampi(value, 0, 64)
		if infill_count_between_newels == clamped_value:
			return
		infill_count_between_newels = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_newel_post_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_newel_post_thickness, clamped_value):
			return
		rail_newel_post_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var rail_edge_margin := 0.15:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(rail_edge_margin, clamped_value):
			return
		rail_edge_margin = clamped_value
		_request_rebuild()

@export_range(0.2, 4.0, 0.01, "or_greater") var rail_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(rail_height, clamped_value):
			return
		rail_height = clamped_value
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

@export_range(0.0, 4.0, 0.01, "or_greater") var rail_lower_height := 0.18:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(rail_lower_height, clamped_value):
			return
		rail_lower_height = clamped_value
		_request_rebuild()

@export var rail_color := Color(0.33, 0.28, 0.22, 1.0):
	set(value):
		if rail_color == value:
			return
		rail_color = value
		_request_rebuild()

@export_group("")
@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false
var m_segment_geometry: StairSegmentGeometry = null


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		_sync_transform_from_points()
		if _generated_mesh_cache_matches(_stairs_mesh_source_signature()):
			_sync_stairs_material()
			_rebuild_collision_from_cached_mesh()
		else:
			rebuild_stairs_mesh()


func set_stair_corners(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_corners_and_rotation(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float
) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	stair_rotation_degrees = new_rotation_degrees
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_rotation_degrees(new_rotation_degrees: float) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	stair_rotation_degrees = new_rotation_degrees
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_rotation_around_center(new_rotation_degrees: float) -> void:
	var size := get_stair_size()
	var center := get_stair_center_point()
	var normalized_rotation := _normalize_degrees_static(new_rotation_degrees)
	var rotated_anchor := center - _rotation_basis_for_degrees(normalized_rotation) * Vector3(
		size.x * 0.5,
		0.0,
		size.y * 0.5
	)
	set_stair_corners_and_rotation(
		rotated_anchor,
		rotated_anchor + Vector3(size.x, 0.0, size.y),
		normalized_rotation
	)


func get_stair_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func get_stair_anchor_point() -> Vector3:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Vector3(min_x, start_point.y, min_z)


func get_stair_center_point() -> Vector3:
	var size := get_stair_size()
	return get_stair_anchor_point() + _rotation_basis() * Vector3(size.x * 0.5, 0.0, size.y * 0.5)


func get_stair_bounds_min() -> Vector3:
	return Vector3(0.0, -maxf(stair_thickness, 0.0), 0.0)


func get_stair_bounds_max() -> Vector3:
	var size := get_stair_size()
	return Vector3(size.x, maxf(stair_height, 0.05), size.y)


func get_step_rise() -> float:
	return maxf(stair_height, 0.05) / float(_total_rising_step_count())


func get_step_run() -> float:
	return get_stair_size().y / float(_effective_step_count())


func _total_rising_step_count() -> int:
	return _effective_step_count()


func _layout_mesh_source_signature_values() -> Array:
	var script := get_script() as Script
	return [script.resource_path if script != null else ""]


func _normalize_tread_style(value: int) -> int:
	return clampi(value, TreadStyle.CLOSED, TreadStyle.NOSING)


static func stair_corners_from_base_points(base_start: Vector3, base_end: Vector3, rotation_degrees: float) -> Dictionary:
	var basis := Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))
	var flat_delta := Vector3(base_end.x - base_start.x, 0.0, base_end.z - base_start.z)
	var local_delta := basis.inverse() * flat_delta
	var min_x := minf(0.0, local_delta.x)
	var max_x := maxf(0.0, local_delta.x)
	var min_z := minf(0.0, local_delta.z)
	var max_z := maxf(0.0, local_delta.z)
	var anchor := base_start + basis * Vector3(min_x, 0.0, min_z)
	var size := Vector2(max_x - min_x, max_z - min_z)
	return {
		"start": Vector3(anchor.x, base_start.y, anchor.z),
		"end": Vector3(anchor.x + size.x, base_start.y, anchor.z + size.y),
	}


func rebuild_stairs_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_stair_layout_geometry(
		size.x, size.y, vertices, normals, colors, indices
	)
	if vertices.is_empty():
		mesh = null
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_stairs_mesh_resource(arrays)
	_sync_stairs_material()
	_record_generated_mesh_cache(_stairs_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body()


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_stairs_mesh")


func _stairs_mesh_source_signature() -> int:
	var signature: Array = [
		MESH_GEOMETRY_VERSION,
		start_point,
		end_point,
		stair_height,
		step_count,
		stair_thickness,
		tread_style,
		nosing_depth,
		stair_rotation_degrees,
		stair_color,
		left_rail_enabled,
		right_rail_enabled,
		infill_style,
		lower_newel_enabled,
		lower_newel_placement,
		upper_newel_enabled,
		upper_newel_placement,
		middle_newel_post_count,
		infill_count_between_newels,
		rail_newel_post_thickness,
		rail_edge_margin,
		rail_height,
		infill_rail_thickness,
		rail_thickness,
		rail_lower_height,
		rail_color,
	]
	signature.append_array(_layout_mesh_source_signature_values())
	return hash(signature)


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body()


func _sync_transform_from_points() -> void:
	transform = _authored_transform()


func _authored_transform() -> Transform3D:
	return Transform3D(_rotation_basis(), get_stair_anchor_point())


func supports_native_transform() -> bool:
	return true


func _bake_native_delta(delta: Transform3D, grid_step: float) -> void:
	var size := get_stair_size()
	# Effective transform (delta folded onto authored) read in the local frame so
	# a resized rotated stair grows along its own run/width axes.
	var effective := delta * _authored_transform()
	var scale := transform_scale(effective)
	# Snap the placement (anchor) to the grid; keep the scaled footprint exact.
	var new_anchor := snap_vector3_to_grid(effective.origin, grid_step)
	var new_width := maxf(size.x * scale.x, 0.05)
	var new_depth := maxf(size.y * scale.z, 0.05)
	stair_rotation_degrees = _normalize_degrees_static(transform_yaw_degrees(effective))
	stair_height = maxf(stair_height * scale.y, 0.05)
	start_point = new_anchor
	end_point = Vector3(new_anchor.x + new_width, new_anchor.y, new_anchor.z + new_depth)
	rebuild_stairs_mesh()


func capture_native_transform_state() -> Dictionary:
	return {
		"start_point": start_point,
		"end_point": end_point,
		"stair_rotation_degrees": stair_rotation_degrees,
		"stair_height": stair_height,
	}


func restore_native_transform_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	stair_rotation_degrees = float(state.get("stair_rotation_degrees", stair_rotation_degrees))
	stair_height = float(state.get("stair_height", stair_height))
	start_point = Vector3(state.get("start_point", start_point))
	end_point = Vector3(state.get("end_point", end_point))
	rebuild_stairs_mesh()


func _append_stair_layout_geometry(
	_width: float,
	_depth: float,
	_vertices: PackedVector3Array,
	_normals: PackedVector3Array,
	_colors: PackedColorArray,
	_indices: PackedInt32Array
) -> void:
	pass


func _create_segment_geometry() -> StairSegmentGeometry:
	# Concrete layouts substitute their specialized geometry strategy here.
	return StairSegmentGeometry.new()


func _configure_segment_geometry(geometry: StairSegmentGeometry) -> void:
	geometry.stair_color = stair_color
	geometry.stair_thickness = stair_thickness
	geometry.tread_style = tread_style
	geometry.nosing_depth = nosing_depth
	geometry.stair_height = stair_height
	geometry.rail_height = rail_height
	geometry.rail_thickness = rail_thickness
	geometry.rail_lower_height = rail_lower_height
	geometry.rail_color = rail_color
	geometry.infill_style = infill_style
	geometry.infill_count_between_newels = infill_count_between_newels
	geometry.infill_rail_thickness = infill_rail_thickness


func _segment_geometry() -> StairSegmentGeometry:
	if m_segment_geometry == null:
		m_segment_geometry = _create_segment_geometry()
	_configure_segment_geometry(m_segment_geometry)
	return m_segment_geometry


func _handrail_width() -> float:
	return _segment_geometry().handrail_width()


func _clamped_infill_rail_size() -> float:
	return _segment_geometry().clamped_infill_rail_size()


func _build_rail_post_layout(
	depth: float,
	height: float,
	steps: int,
	use_lower_newel: bool,
	use_upper_newel: bool,
	middle_count: int,
	lower_placement: int,
	upper_placement: int,
	force_first_tread_newel: bool = false,
	force_last_tread_newel: bool = false
) -> Dictionary:
	var positions := StandardRailGeometry.tread_mid_post_positions(depth, steps)
	var base_heights := StandardRailGeometry.tread_mid_post_base_heights(height, steps)
	var infill_size := _clamped_infill_rail_size()
	var thicknesses := PackedFloat32Array()
	var newel_flags := PackedByteArray()
	for _index in range(positions.size()):
		thicknesses.append(infill_size)
		newel_flags.append(0)

	# A newel stays no wider than the handrail so its open top is completely
	# covered by the welded handrail underside.
	var newel_size := minf(maxf(rail_newel_post_thickness, 0.02), _handrail_width())
	var post_spacing := depth / float(maxi(steps, 1))
	var lower_newel_index := -1
	var upper_newel_index := -1

	for tread_index in _middle_newel_tread_indices(
		steps, use_lower_newel, use_upper_newel, middle_count,
		lower_placement, upper_placement
	):
		thicknesses[tread_index] = newel_size
		newel_flags[tread_index] = 1

	# Junction newels shared with a layout transition behave like distributed
	# newels: tread-mid position, raked top, and no handrail termination, so
	# the raked handrail runs continuously across the transition boundary.
	if force_first_tread_newel and !positions.is_empty() and newel_flags[0] == 0:
		thicknesses[0] = newel_size
		newel_flags[0] = 1
	if force_last_tread_newel and !positions.is_empty():
		var forced_last_index := positions.size() - 1
		if newel_flags[forced_last_index] == 0:
			thicknesses[forced_last_index] = newel_size
			newel_flags[forced_last_index] = 1

	if use_lower_newel and !positions.is_empty():
		if lower_placement == NewelPlacement.TREAD:
			thicknesses[0] = newel_size
			newel_flags[0] = 1
			lower_newel_index = 0
		else:
			# Continue the regular tread-post cadence by one full interval.
			var floor_positions := PackedFloat32Array([positions[0] - post_spacing])
			floor_positions.append_array(positions)
			positions = floor_positions
			var floor_heights := PackedFloat32Array([0.0])
			floor_heights.append_array(base_heights)
			base_heights = floor_heights
			var floor_thicknesses := PackedFloat32Array([newel_size])
			floor_thicknesses.append_array(thicknesses)
			thicknesses = floor_thicknesses
			var floor_newel_flags := PackedByteArray([1])
			floor_newel_flags.append_array(newel_flags)
			newel_flags = floor_newel_flags
			lower_newel_index = 0

	if use_upper_newel and !positions.is_empty():
		if upper_placement == NewelPlacement.TREAD:
			var last_tread_index := positions.size() - 1
			thicknesses[last_tread_index] = newel_size
			newel_flags[last_tread_index] = 1
			upper_newel_index = last_tread_index
		else:
			# Continue the regular tread-post cadence by one full interval.
			positions.append(positions[positions.size() - 1] + post_spacing)
			base_heights.append(height)
			thicknesses.append(newel_size)
			newel_flags.append(1)
			upper_newel_index = positions.size() - 1

	var lower_newel_position := NAN
	var upper_newel_position := NAN
	if lower_newel_index >= 0:
		lower_newel_position = positions[lower_newel_index]
	if upper_newel_index >= 0:
		upper_newel_position = positions[upper_newel_index]
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
		infill_size
	)
	positions = counted_layout["positions"]
	base_heights = counted_layout["base_heights"]
	thicknesses = counted_layout["thicknesses"]
	newel_flags = counted_layout["newel_flags"]
	lower_newel_index = _find_post_position(positions, lower_newel_position)
	upper_newel_index = _find_post_position(positions, upper_newel_position)
	var lower_newel_is_floor := (
		use_lower_newel
		and lower_placement == NewelPlacement.FLOOR
	)
	var upper_newel_is_floor := (
		use_upper_newel
		and upper_placement == NewelPlacement.FLOOR
	)

	var bar_size := minf(maxf(rail_thickness, 0.02), maxf(rail_height, 0.2) * 0.5)
	var handrail_bottom := maxf(rail_height, 0.2) - bar_size
	var has_base_rail := StandardRailGeometry.has_lower_rail(
		rail_height,
		rail_thickness,
		rail_lower_height
	)
	var safe_depth := maxf(depth, 0.001)
	var base_follows_rise := PackedByteArray()
	base_follows_rise.resize(positions.size())
	if has_base_rail:
		StandardRailGeometry.redistribute_infills_between_newels(
			positions,
			thicknesses,
			newel_flags
		)
		var base_rail_top := StandardRailGeometry.lower_rail_top_height(
			rail_height,
			rail_thickness,
			rail_lower_height
		)
		for index in range(positions.size()):
			if newel_flags[index] != 0:
				continue
			base_heights[index] = (
				base_rail_top
				+ height * (positions[index] / safe_depth)
			)
			# The base-rail top is raked, so this infill's bottom corners
			# must shear along the run instead of staying flat.
			base_follows_rise[index] = 1
	else:
		var tread_depth := depth / float(maxi(steps, 1))
		var rise_per_tread := height / float(maxi(steps, 1))
		for index in range(positions.size()):
			if newel_flags[index] != 0:
				continue
			var tread_index := clampi(
				floori(positions[index] / maxf(tread_depth, 0.001)),
				0,
				steps - 1
			)
			base_heights[index] = rise_per_tread * float(tread_index + 1)

	var lower_horizontal_end := -INF
	var upper_horizontal_start := INF
	if lower_newel_index >= 0:
		if lower_newel_is_floor:
			lower_horizontal_end = 0.0
		else:
			lower_horizontal_end = (
				positions[lower_newel_index]
				+ thicknesses[lower_newel_index] * 0.5
			)
	if upper_newel_index >= 0:
		if upper_newel_is_floor:
			upper_horizontal_start = depth
		else:
			upper_horizontal_start = (
				positions[upper_newel_index]
				- thicknesses[upper_newel_index] * 0.5
			)
	if lower_horizontal_end > upper_horizontal_start:
		var shared_transition := (lower_horizontal_end + upper_horizontal_start) * 0.5
		lower_horizontal_end = shared_transition
		upper_horizontal_start = shared_transition

	var top_heights := PackedFloat32Array()
	top_heights.resize(positions.size())
	for index in range(top_heights.size()):
		top_heights[index] = NAN
	if lower_newel_index >= 0:
		top_heights[lower_newel_index] = (
			handrail_bottom
			+ height * (lower_horizontal_end / safe_depth)
		)
	if upper_newel_index >= 0:
		top_heights[upper_newel_index] = (
			handrail_bottom
			+ height * (upper_horizontal_start / safe_depth)
		)

	var handrail_minimum_run := NAN
	var handrail_maximum_run := NAN
	# Distributed newels only create welded openings in the continuous raked
	# handrail. Explicit lower/upper newels alone may terminate its run.
	if lower_newel_index >= 0:
		handrail_minimum_run = (
			positions[lower_newel_index]
			- thicknesses[lower_newel_index] * 0.5
		)
	if upper_newel_index >= 0:
		handrail_maximum_run = (
			positions[upper_newel_index]
			+ thicknesses[upper_newel_index] * 0.5
		)

	return {
		"positions": positions,
		"base_heights": base_heights,
		"thicknesses": thicknesses,
		"newel_flags": newel_flags,
		"top_heights": top_heights,
		"base_follows_rise": base_follows_rise,
		"lower_horizontal_end": lower_horizontal_end,
		"upper_horizontal_start": upper_horizontal_start,
		"handrail_minimum_run": handrail_minimum_run,
		"handrail_maximum_run": handrail_maximum_run,
	}


func _find_post_position(positions: PackedFloat32Array, target: float) -> int:
	if is_nan(target):
		return -1
	for index in range(positions.size()):
		if is_equal_approx(positions[index], target):
			return index
	return -1


func _middle_newel_tread_indices(
	steps: int,
	use_lower_newel: bool,
	use_upper_newel: bool,
	middle_count: int,
	lower_placement: int,
	upper_placement: int
) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var has_lower_terminal := use_lower_newel
	var has_upper_terminal := use_upper_newel
	var lower_bound := (
		-1
		if has_lower_terminal and lower_placement == NewelPlacement.FLOOR
		else 0
	)
	var upper_bound := (
		steps
		if has_upper_terminal and upper_placement == NewelPlacement.FLOOR
		else steps - 1
	)
	var first_available_tread := (
		1
		if has_lower_terminal and lower_placement == NewelPlacement.TREAD
		else 0
	)
	var last_available_tread := (
		steps - 2
		if has_upper_terminal and upper_placement == NewelPlacement.TREAD
		else steps - 1
	)
	var available_middle_treads := maxi(
		last_available_tread - first_available_tread + 1,
		0
	)
	var explicit_terminal_count := (
		(1 if has_lower_terminal else 0)
		+ (1 if has_upper_terminal else 0)
	)
	var count := clampi(
		middle_count - explicit_terminal_count,
		0,
		available_middle_treads
	)
	if count <= 0:
		return indices

	var lower_padding := 1 if has_lower_terminal else 0
	var upper_padding := 1 if has_upper_terminal else 0
	var interval_count := count - 1 + lower_padding + upper_padding
	if interval_count <= 0:
		indices.append(first_available_tread)
		return indices

	# Divide the actual lower/upper newel interval into equal spans. Missing
	# terminals make the first/last distributed newels occupy the endpoint
	# tread; explicit terminals bound the interval without being duplicated.
	for index in range(count):
		var distributed_index := roundi(
			lerpf(
				float(lower_bound),
				float(upper_bound),
				float(index + lower_padding) / float(interval_count)
			)
		)
		indices.append(clampi(
			distributed_index,
			first_available_tread,
			last_available_tread
		))
	return indices


func _update_stairs_mesh_resource(arrays: Array) -> void:
	_replace_generated_mesh_surface(arrays)


func _stairs_material_transparency(color: Color) -> BaseMaterial3D.Transparency:
	# The glass-panel rail infill carries its translucency in vertex alpha
	# inside the same surface as the opaque steps, posts, and handrail. Plain
	# alpha blending would move the whole stairs mesh into the no-depth-write
	# transparent pass and break depth sorting, so the glass style uses an
	# opaque depth pre-pass: opaque fragments keep correct depth while the
	# panel still blends.
	if (
		(left_rail_enabled or right_rail_enabled)
		and infill_style == StandardRailGeometry.RailStyle.GLASS_PANEL
	):
		return BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	if color.a < 0.99:
		return BaseMaterial3D.TRANSPARENCY_ALPHA
	return BaseMaterial3D.TRANSPARENCY_DISABLED


func _sync_stairs_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_stairs_material(stair_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, stair_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = _stairs_material_transparency(stair_color)


func _build_stairs_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = _stairs_material_transparency(color)
	return material


func _add_collision_body() -> void:
	var body := StaticBody3D.new()
	body.name = "StairsCollision"
	body.set_meta(GENERATED_META, true)
	_add_stair_collision_shapes(body)
	if body.get_child_count() == 0:
		body.free()
		return
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		for child in body.get_children():
			child.owner = null


func _add_stair_collision_shapes(_body: StaticBody3D) -> void:
	# Concrete layouts own their walkable slope and optional rail collision.
	pass


func _add_flight_slope_collision_shape(
	body: StaticBody3D,
	shape_name: String,
	seg: Dictionary
) -> void:
	var width: float = seg["width"]
	var run: float = seg["run"]
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	if width <= 0.001 or run <= 0.001 or steps <= 0:
		return
	var top_start := 0.0
	var top_end := rise * float(steps)
	var bottom_start := minf(_segment_bottom(seg), -COLLISION_MINIMUM_THICKNESS)
	var bottom_end := bottom_start
	if tread_style == TreadStyle.OPEN:
		var slab := _tread_slab_thickness()
		bottom_start = top_start - slab
		bottom_end = top_end - slab
	var points := PackedVector3Array([
		_segment_point(seg, Vector3(0.0, top_start, 0.0)),
		_segment_point(seg, Vector3(width, top_start, 0.0)),
		_segment_point(seg, Vector3(0.0, top_end, run)),
		_segment_point(seg, Vector3(width, top_end, run)),
		_segment_point(seg, Vector3(0.0, bottom_start, 0.0)),
		_segment_point(seg, Vector3(width, bottom_start, 0.0)),
		_segment_point(seg, Vector3(0.0, bottom_end, run)),
		_segment_point(seg, Vector3(width, bottom_end, run)),
	])
	_add_slope_collision_shape(body, shape_name, points)


func _slope_surface_height(
	path_position: float,
	path_length: float,
	steps: int,
	rise: float
) -> float:
	if path_length <= 0.001 or steps <= 0:
		return 0.0
	var progress := clampf(path_position / path_length, 0.0, 1.0)
	return progress * rise * float(steps)


func _add_slope_collision_shape(
	body: StaticBody3D,
	shape_name: String,
	points: PackedVector3Array
) -> void:
	if points.size() < 4:
		return
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = shape_name
	var slope := ConvexPolygonShape3D.new()
	slope.points = points
	collision_shape.shape = slope
	body.add_child(collision_shape)


func _add_box_collision_shape(
	body: StaticBody3D,
	shape_name: String,
	shape_position: Vector3,
	shape_size: Vector3,
	shape_basis := Basis.IDENTITY
) -> void:
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = shape_name
	var box := BoxShape3D.new()
	box.size = shape_size
	collision_shape.shape = box
	collision_shape.transform = Transform3D(shape_basis, shape_position)
	body.add_child(collision_shape)


func _add_rail_collision_shape(
	body: StaticBody3D,
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> void:
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
	collision_shape.name = RAIL_COLLISION_SHAPE_NAME
	collision_shape.shape = shape
	body.add_child(collision_shape)


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()


func _effective_step_count() -> int:
	return clampi(step_count, 1, 64)


func _rotation_basis() -> Basis:
	return _rotation_basis_for_degrees(stair_rotation_degrees)


static func _rotation_basis_for_degrees(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))


static func _normalize_degrees_static(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _make_flight_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float,
	steps: int,
	rise: float
) -> Dictionary:
	return StairSegmentGeometry.make_flight_segment(
		origin, run_dir, width, run_length, steps, rise
	)


func _segment_point(seg: Dictionary, local_point: Vector3) -> Vector3:
	return StairSegmentGeometry.segment_point(seg, local_point)


func _segment_direction(seg: Dictionary, local_direction: Vector3) -> Vector3:
	return StairSegmentGeometry.segment_direction(seg, local_direction)


func _segment_bottom(seg: Dictionary) -> float:
	return _segment_geometry().segment_bottom(seg)


func _landing_bottom(seg: Dictionary) -> float:
	return _segment_geometry().landing_bottom(seg)


func _tread_slab_thickness() -> float:
	return _segment_geometry().tread_slab_thickness()


func _effective_nosing_depth(tread_depth: float) -> float:
	return _segment_geometry().effective_nosing_depth(tread_depth)


func _nosing_lip_thickness(rise: float) -> float:
	return _segment_geometry().nosing_lip_thickness(rise)


func _append_oriented_triangle(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	normal: Vector3,
	first: int,
	second: int,
	third: int
) -> void:
	StairSegmentGeometry.append_oriented_triangle(
		vertices, indices, normal, first, second, third
	)


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
	_segment_geometry().append_quad(
		vertices, normals, colors, indices, a, b, c, d, normal
	)


func _append_embedded_quad(
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
	_segment_geometry().append_embedded_quad(
		vertices, normals, colors, indices, a, b, c, d, normal
	)


func _append_segment_quad(
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
	_segment_geometry().append_segment_quad(
		seg, vertices, normals, colors, indices, a, b, c, d, local_normal
	)


func _append_segment_box(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	box_min: Vector3,
	box_max: Vector3,
	skip_back := false
) -> void:
	_segment_geometry().append_segment_box(
		seg, vertices, normals, colors, indices, box_min, box_max, skip_back
	)


func _append_open_flight_treads(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_segment_geometry().append_open_flight_treads(
		seg, vertices, normals, colors, indices
	)


func _append_flight_nosing_lips(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_segment_geometry().append_flight_nosing_lips(
		seg, vertices, normals, colors, indices
	)


func _append_flight_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_segment_geometry().append_flight_segment_geometry(
		seg, vertices, normals, colors, indices
	)


func _append_segment_side_strips(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	x: float,
	local_normal: Vector3
) -> void:
	_segment_geometry().append_segment_side_strips(
		seg, vertices, normals, colors, indices, x, local_normal
	)


func _append_landing_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_segment_geometry().append_landing_segment_geometry(
		seg, vertices, normals, colors, indices
	)
