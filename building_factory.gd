@tool
class_name BuildingFactory
extends RefCounted

const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const WallSegmentScript = preload("res://addons/low_poly_building_editor/walls/wall_segment.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floors/floor_3d.gd")
const Street3DScript = preload("res://addons/low_poly_building_editor/streets/street_3d.gd")
const StreetNetwork3DScript = preload(
	"res://addons/low_poly_building_editor/streets/street_network_3d.gd"
)
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs/stairs_3d.gd")
const Rail3DScript = preload("res://addons/low_poly_building_editor/rails/rail_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillars/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")
const FlatRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/flat_roof_3d.gd"
)
const SlopedRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/sloped_roof_3d.gd"
)
const HipRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/hip_roof_3d.gd"
)
const BuildingOpening3DScript = preload(
	"res://addons/low_poly_building_editor/openings/building_opening_3d.gd"
)

const StraightStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/straight_stairs_3d.gd"
)
const TurningStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/turning_stairs_3d.gd"
)
const WinderStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/winder_stairs_3d.gd"
)
const SpiralStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/spiral_stairs_3d.gd"
)
const STAIR_LAYOUTS := [
	{"key": "straight", "label": "Straight", "script": StraightStairs3DScript},
	{"key": "l_shaped", "label": "L Shaped", "script": preload("res://addons/low_poly_building_editor/stairs/l_shaped_stairs_3d.gd")},
	{"key": "double_l_shaped", "label": "Double L Shaped", "script": preload("res://addons/low_poly_building_editor/stairs/double_l_shaped_stairs_3d.gd")},
	{"key": "u_shaped", "label": "U Shaped", "script": preload("res://addons/low_poly_building_editor/stairs/u_shaped_stairs_3d.gd")},
	{"key": "winder", "label": "Winder", "script": WinderStairs3DScript},
	{"key": "spiral", "label": "Spiral", "script": SpiralStairs3DScript},
]
const PILLAR_STYLES := [
	{"key": "round", "label": "Round", "script": preload("res://addons/low_poly_building_editor/pillars/round_pillar_3d.gd")},
	{"key": "square", "label": "Square", "script": preload("res://addons/low_poly_building_editor/pillars/square_pillar_3d.gd")},
	{"key": "octagonal", "label": "Octagonal", "script": preload("res://addons/low_poly_building_editor/pillars/octagonal_pillar_3d.gd")},
	{"key": "tapered", "label": "Tapered", "script": preload("res://addons/low_poly_building_editor/pillars/tapered_pillar_3d.gd")},
]
const ROOF_STYLES := [
	{"key": "flat", "label": "Flat", "script": FlatRoof3DScript},
	{"key": "shed", "label": "Shed", "script": preload("res://addons/low_poly_building_editor/roofs/shed_roof_3d.gd")},
	{"key": "gable", "label": "Gable", "script": preload("res://addons/low_poly_building_editor/roofs/gable_roof_3d.gd")},
	{"key": "hip", "label": "Hip", "script": HipRoof3DScript},
	{"key": "dome", "label": "Dome", "script": preload("res://addons/low_poly_building_editor/roofs/dome_roof_3d.gd")},
]
const OPENING_STYLES := [
	{"key": "single_window", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/single_window_3d.gd")},
	{"key": "double_window", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/double_window_3d.gd")},
	{"key": "grid_window", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/grid_window_3d.gd")},
	{"key": "louvered_window", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/louvered_window_3d.gd")},
	{"key": "transom_window", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/transom_window_3d.gd")},
	{"key": "arched_window", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/arched_window_3d.gd")},
	{"key": "frame", "category": "window", "script": preload("res://addons/low_poly_building_editor/openings/window_frame_3d.gd")},
	{"key": "single_door", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/single_door_3d.gd")},
	{"key": "double_door", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/double_door_3d.gd")},
	{"key": "glazed_door", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/glazed_door_3d.gd")},
	{"key": "glazed_grid_door", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/glazed_grid_door_3d.gd")},
	{"key": "panel_door", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/panel_door_3d.gd")},
	{"key": "dutch_door", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/dutch_door_3d.gd")},
	{"key": "single_frame", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/single_door_frame_3d.gd")},
	{"key": "double_frame", "category": "door", "script": preload("res://addons/low_poly_building_editor/openings/double_door_frame_3d.gd")},
]
const OPENING_STYLE_PROPERTY_NAMES: Array[StringName] = [
	&"window_pane_depth",
	&"window_pane_color",
	&"pane_grid_rows",
	&"pane_grid_cols",
	&"muntin_thickness",
	&"louver_count",
	&"louver_depth",
	&"transom_ratio",
	&"transom_rail_thickness",
	&"arch_steps",
	&"door_panel_depth",
	&"door_panel_color",
	&"door_glazing_ratio",
	&"door_glass_depth",
	&"door_glass_color",
	&"door_inset_rows",
	&"door_inset_cols",
]


static func get_building_style_custom_types() -> Array[Dictionary]:
	var custom_types: Array[Dictionary] = []
	for layout: Dictionary in STAIR_LAYOUTS:
		custom_types.append(_custom_type_for_script(layout["script"]))
	for style: Dictionary in PILLAR_STYLES:
		custom_types.append(_custom_type_for_script(style["script"]))
	for style: Dictionary in ROOF_STYLES:
		custom_types.append(_custom_type_for_script(style["script"]))
	return custom_types


static func get_opening_custom_types() -> Array[Dictionary]:
	var custom_types: Array[Dictionary] = []
	for style: Dictionary in OPENING_STYLES:
		custom_types.append(_custom_type_for_script(style["script"]))
	return custom_types


static func _custom_type_for_script(script: Script) -> Dictionary:
	return {"name": script.get_global_name(), "script": script}
const OPENING_SILL_META := &"building_opening_sill_height"
const OPENING_ALLOW_BASE_META := &"building_opening_allow_base_edge"


static func snap_local_position(local_position: Vector3, grid_step: float) -> Vector3:
	var step := maxf(grid_step, 0.05)
	return Vector3(
		roundf(local_position.x / step) * step,
		roundf(local_position.y / step) * step,
		roundf(local_position.z / step) * step
	)


static func snap_world_position(building: Node3D, world_position: Vector3, grid_step: float) -> Vector3:
	if building == null:
		return snap_local_position(world_position, grid_step)
	return building.to_global(snap_local_position(building.to_local(world_position), grid_step))


static func constrain_wall_end(
	start_local: Vector3,
	target_local: Vector3,
	grid_step: float,
	lock_to_8_way: bool
) -> Vector3:
	var snapped_target := snap_local_position(target_local, grid_step)
	if !lock_to_8_way:
		return snapped_target

	var flat_delta := Vector2(snapped_target.x - start_local.x, snapped_target.z - start_local.z)
	if flat_delta.length_squared() <= 0.000001:
		return start_local

	var angle_step := PI * 0.25
	var angle := atan2(flat_delta.y, flat_delta.x)
	var locked_angle := roundf(angle / angle_step) * angle_step
	var step := maxf(grid_step, 0.05)
	var length := roundf(flat_delta.length() / step) * step
	var locked := Vector3(cos(locked_angle) * length, 0.0, sin(locked_angle) * length)
	return snap_local_position(start_local + locked, step)


static func create_wall_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	height: float = 2.4,
	thickness: float = 0.22,
	color: Color = Color(0.78, 0.68, 0.54, 1.0)
) -> Wall3DScript:
	var segment := WallSegmentScript.new() as WallSegment
	segment.start_point = local_start
	segment.end_point = local_end
	segment.height = height
	segment.thickness = thickness
	segment.color = color
	var wall_segments: Array[WallSegment] = [segment]
	return _create_wall_node_with_segments(
		building,
		"Wall3D",
		wall_segments,
		height,
		thickness,
		color
	)


static func _create_wall_node_with_segments(
	building: Node,
	name_prefix: String,
	wall_segments: Array[WallSegment],
	height: float,
	thickness: float,
	color: Color
) -> Wall3DScript:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = _unique_child_name(building, name_prefix)
	wall.wall_height = height
	wall.wall_thickness = thickness
	wall.wall_color = color
	wall.segments = wall_segments
	wall.build_on_ready = true
	wall.generate_collision = true
	wall.rebuild_wall_mesh()
	return wall


static func room_segments_from_corners(
	local_start: Vector3,
	local_end: Vector3,
	height: float,
	thickness: float,
	color: Color,
	side_count: int = 4
) -> Array[WallSegment]:
	var base_y := local_start.y
	var resolved_side_count := maxi(side_count, 3)
	var corners: Array[Vector3] = []
	if resolved_side_count == 4:
		corners.assign([
			Vector3(local_start.x, base_y, local_start.z),
			Vector3(local_end.x, base_y, local_start.z),
			Vector3(local_end.x, base_y, local_end.z),
			Vector3(local_start.x, base_y, local_end.z),
		])
	else:
		var center := Vector3(
			(local_start.x + local_end.x) * 0.5,
			base_y,
			(local_start.z + local_end.z) * 0.5
		)
		var radius_x := absf(local_end.x - local_start.x) * 0.5
		var radius_z := absf(local_end.z - local_start.z) * 0.5
		for index in range(resolved_side_count):
			var angle := -PI * 0.5 + TAU * float(index) / float(resolved_side_count)
			corners.append(
				center + Vector3(cos(angle) * radius_x, 0.0, sin(angle) * radius_z)
			)
	var segments: Array[WallSegment] = []
	for index in range(corners.size()):
		var segment := WallSegmentScript.new() as WallSegment
		segment.start_point = corners[index]
		segment.end_point = corners[(index + 1) % corners.size()]
		segment.height = height
		segment.thickness = thickness
		segment.color = color
		segments.append(segment)
	return segments


static func create_room_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	height: float = 2.4,
	thickness: float = 0.22,
	color: Color = Color(0.78, 0.68, 0.54, 1.0),
	side_count: int = 4
) -> Wall3DScript:
	var segments := room_segments_from_corners(
		local_start,
		local_end,
		height,
		thickness,
		color,
		side_count
	)
	return _create_wall_node_with_segments(
		building,
		"Room3D",
		segments,
		height,
		thickness,
		color
	)


static func create_floor_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	thickness: float = 0.12,
	color: Color = Color(0.46, 0.40, 0.32, 1.0)
) -> Floor3DScript:
	var floor := Floor3DScript.new() as Floor3DScript
	floor.name = _unique_child_name(building, "Floor3D")
	floor.start_point = local_start
	floor.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	floor.floor_thickness = thickness
	floor.floor_color = color
	floor.build_on_ready = true
	floor.generate_collision = true
	floor.rebuild_floor_mesh()
	return floor


static func create_floor_polygon_node(
	building: Node,
	local_points: PackedVector3Array,
	thickness: float = 0.12,
	color: Color = Color(0.46, 0.40, 0.32, 1.0)
) -> Floor3DScript:
	var floor := Floor3DScript.new() as Floor3DScript
	floor.name = _unique_child_name(building, "Floor3D")
	floor.floor_thickness = thickness
	floor.floor_color = color
	floor.build_on_ready = true
	floor.generate_collision = true
	floor.set_floor_polygon(local_points)
	return floor


## Creates one multi-point street with a continuously sloped carriageway and
## independently generated kerb/footpath bands. Terrain sampling is an explicit
## later authoring operation on the returned Street3D.
static func create_street_node(
	building: Node,
	local_path_points: PackedVector3Array,
	settings: Dictionary = {}
) -> Street3DScript:
	var street := Street3DScript.new() as Street3DScript
	street.name = _unique_child_name(building, "Street3D")
	street.path_points = local_path_points
	street.road_width = float(settings.get("road_width", 3.2))
	street.road_thickness = float(settings.get("road_thickness", 0.18))
	street.road_color = Color(settings.get("road_color", Color(0.38, 0.37, 0.34, 1.0)))
	street.kerb_width = float(settings.get("kerb_width", 0.18))
	street.kerb_height = float(settings.get("kerb_height", 0.14))
	street.kerb_color = Color(settings.get("kerb_color", Color(0.66, 0.64, 0.59, 1.0)))
	street.footpath_width = float(settings.get("footpath_width", 1.1))
	street.footpath_thickness = float(settings.get("footpath_thickness", 0.16))
	street.footpath_color = Color(settings.get("footpath_color", Color(0.72, 0.67, 0.57, 1.0)))
	street.stair_threshold_degrees = float(settings.get("stair_threshold_degrees", 25.0))
	street.target_riser_height = float(settings.get("target_riser_height", 0.16))
	street.max_riser_height = float(settings.get("max_riser_height", 0.18))
	street.min_tread_depth = float(settings.get("min_tread_depth", 0.24))
	street.terrain_sample_spacing = float(settings.get("terrain_sample_spacing", 0.5))
	street.terrain_clearance = float(settings.get("terrain_clearance", 0.025))
	street.build_on_ready = true
	street.generate_collision = bool(settings.get("generate_collision", true))
	street.rebuild_street_mesh()
	return street


## Creates the canonical design-time street network used by new editor
## placement. Legacy Street3D construction stays available for old scenes and
## deterministic street specs.
static func create_street_network_node(building: Node) -> StreetNetwork3DScript:
	var network := StreetNetwork3DScript.new() as StreetNetwork3DScript
	network.name = _unique_child_name(building, "StreetNetwork3D")
	network.build_on_ready = true
	network.generate_collision = true
	return network


## Creates a configured stairs node from one optional `settings` dictionary,
## mirroring the opening-settings pattern. Missing keys fall back to the
## defaults below, so `{}` produces plain straight stairs. Recognized keys:
## `height`, `step_count`, `thickness`, `color`, `rotation_degrees`,
## `tread_style`, `nosing_depth`, `layout_script` (concrete stair `Script`,
## layout key, or script path — see `instantiate_stair_layout()`),
## `turn_direction`, `winder_turn`, `flight_width`, `spiral_turn_degrees`,
## `left_rail_enabled`, `right_rail_enabled`, `rail_height`,
## `infill_rail_thickness`, `rail_thickness`, `rail_lower_height`,
## `rail_color`, `rail_edge_margin`, `lower_newel_enabled`,
## `lower_newel_placement`, `upper_newel_enabled`, `upper_newel_placement`,
## `rail_newel_post_thickness`, `middle_newel_post_count`,
## `infill_count_between_newels`, and `infill_style`.
static func create_stairs_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	settings: Dictionary = {}
) -> Stairs3DScript:
	var stairs := instantiate_stair_layout(
		settings.get("layout_script", StraightStairs3DScript)
	)
	stairs.name = _unique_child_name(building, "Stairs3D")
	configure_stair_layout(
		stairs,
		int(settings.get(
			"turn_direction", TurningStairs3DScript.TurnDirection.RIGHT
		)),
		int(settings.get("winder_turn", WinderStairs3DScript.WinderTurn.TURN_90)),
		float(settings.get("flight_width", 1.2)),
		float(settings.get("spiral_turn_degrees", 360.0))
	)
	stairs.start_point = local_start
	stairs.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	stairs.stair_height = float(settings.get("height", 1.2))
	stairs.step_count = int(settings.get("step_count", 6))
	stairs.stair_thickness = float(settings.get("thickness", 0.12))
	stairs.tread_style = int(settings.get(
		"tread_style", Stairs3DScript.TreadStyle.CLOSED
	))
	stairs.nosing_depth = float(settings.get("nosing_depth", 0.08))
	stairs.stair_color = Color(settings.get(
		"color", Color(0.52, 0.46, 0.38, 1.0)
	))
	stairs.stair_rotation_degrees = float(settings.get("rotation_degrees", 0.0))
	stairs.left_rail_enabled = bool(settings.get("left_rail_enabled", false))
	stairs.right_rail_enabled = bool(settings.get("right_rail_enabled", false))
	stairs.lower_newel_enabled = bool(settings.get("lower_newel_enabled", false))
	stairs.lower_newel_placement = int(settings.get(
		"lower_newel_placement", Stairs3DScript.NewelPlacement.TREAD
	))
	stairs.upper_newel_enabled = bool(settings.get("upper_newel_enabled", false))
	stairs.upper_newel_placement = int(settings.get(
		"upper_newel_placement", Stairs3DScript.NewelPlacement.TREAD
	))
	stairs.middle_newel_post_count = int(settings.get(
		"middle_newel_post_count", 0
	))
	stairs.infill_count_between_newels = int(settings.get(
		"infill_count_between_newels", 1
	))
	stairs.infill_style = int(settings.get("infill_style", 0))
	stairs.rail_newel_post_thickness = float(settings.get(
		"rail_newel_post_thickness", 0.1
	))
	stairs.rail_edge_margin = float(settings.get("rail_edge_margin", 0.15))
	stairs.rail_height = float(settings.get("rail_height", 1.0))
	stairs.infill_rail_thickness = float(settings.get(
		"infill_rail_thickness", 0.08
	))
	stairs.rail_thickness = float(settings.get("rail_thickness", 0.1))
	stairs.rail_lower_height = float(settings.get("rail_lower_height", 0.18))
	stairs.rail_color = Color(settings.get(
		"rail_color", Color(0.33, 0.28, 0.22, 1.0)
	))
	stairs.build_on_ready = true
	stairs.generate_collision = true
	stairs.rebuild_stairs_mesh()
	return stairs


static func instantiate_stair_layout(layout_selection: Variant) -> Stairs3DScript:
	var stairs_script: Script
	if layout_selection is Script:
		stairs_script = layout_selection as Script
	elif layout_selection is String or layout_selection is StringName:
		var selection := String(layout_selection)
		for layout: Dictionary in STAIR_LAYOUTS:
			var candidate := layout["script"] as Script
			if String(layout["key"]) == selection or candidate.resource_path == selection:
				stairs_script = candidate
				break
	if stairs_script == null or get_stair_layout(stairs_script).is_empty():
		stairs_script = StraightStairs3DScript
	return stairs_script.new() as Stairs3DScript


static func get_stair_layout(script: Script) -> Dictionary:
	for layout: Dictionary in STAIR_LAYOUTS:
		if layout["script"] == script:
			return layout
	return {}


static func configure_stair_layout(
	stairs: Stairs3DScript,
	turn_direction: int,
	winder_turn: int,
	flight_width: float,
	spiral_turn_degrees: float
) -> void:
	if stairs is WinderStairs3DScript:
		(stairs as WinderStairs3DScript).configure_winder_layout(
			turn_direction, flight_width, winder_turn
		)
	elif stairs is SpiralStairs3DScript:
		(stairs as SpiralStairs3DScript).configure_spiral_layout(
			turn_direction, flight_width, spiral_turn_degrees
		)
	elif stairs is TurningStairs3DScript:
		(stairs as TurningStairs3DScript).configure_turning_layout(
			turn_direction, flight_width
		)


static func create_rail_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	height: float = 1.0,
	post_spacing: float = 1.0,
	infill_rail_thickness: float = 0.08,
	rail_thickness: float = 0.1,
	lower_rail_height: float = 0.18,
	color: Color = Color(0.33, 0.28, 0.22, 1.0),
	newel_post_count: int = 2,
	infill_count_between_newels: int = 1,
	newel_post_thickness: float = 0.1,
	infill_style: int = 0
) -> Rail3DScript:
	var rail := Rail3DScript.new() as Rail3DScript
	rail.name = _unique_child_name(building, "Rail3D")
	rail.start_point = local_start
	rail.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	rail.rail_height = height
	rail.post_spacing = post_spacing
	rail.infill_rail_thickness = infill_rail_thickness
	rail.rail_thickness = rail_thickness
	rail.newel_post_count = newel_post_count
	rail.infill_count_between_newels = infill_count_between_newels
	rail.newel_post_thickness = newel_post_thickness
	rail.infill_style = infill_style
	rail.lower_rail_height = lower_rail_height
	rail.rail_color = color
	rail.build_on_ready = true
	rail.generate_collision = true
	rail.rebuild_rail_mesh()
	return rail


static func create_pillar_node(
	building: Node,
	local_base: Vector3,
	radius: float = 0.25,
	height: float = 2.4,
	sides: int = 8,
	style: String = "round",
	color: Color = Color(0.70, 0.64, 0.52, 1.0),
	lower_rim_height: float = 0.0,
	lower_rim_outset: float = 0.0,
	upper_rim_height: float = 0.0,
	upper_rim_outset: float = 0.0,
	upper_radius: float = 0.0
) -> Pillar3DScript:
	var normalized_style := style.strip_edges().to_lower()
	var pillar := instantiate_pillar_style(normalized_style)
	pillar.name = _unique_child_name(building, "Pillar3D")
	pillar.base_point = local_base
	pillar.pillar_radius = radius
	pillar.upper_radius = upper_radius
	pillar.pillar_height = height
	if normalized_style == "round" or normalized_style == "tapered":
		pillar.set(&"side_count", sides)
	pillar.pillar_color = color
	pillar.lower_rim_height = lower_rim_height
	pillar.lower_rim_outset = lower_rim_outset
	pillar.upper_rim_height = upper_rim_height
	pillar.upper_rim_outset = upper_rim_outset
	pillar.build_on_ready = true
	pillar.generate_collision = true
	pillar.rebuild_pillar_mesh()
	return pillar


static func instantiate_pillar_style(style: String) -> Pillar3DScript:
	var style_record := _style_record(PILLAR_STYLES, style, "round")
	var pillar_script := style_record["script"] as Script
	return pillar_script.new() as Pillar3DScript


static func create_roof_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	style: String = "gable",
	height: float = 40.0,
	thickness: float = 0.12,
	overhang: float = 0.2,
	color: Color = Color(0.50, 0.34, 0.25, 1.0),
	rotation_degrees: float = 0.0,
	hip_gable_height: float = 0.0,
	hip_shape: int = 0
) -> Roof3DScript:
	var roof := instantiate_roof_style(style)
	roof.name = _unique_child_name(building, "Roof3D")
	roof.start_point = local_start
	roof.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	configure_roof_style(roof, height, hip_gable_height, hip_shape)
	roof.roof_thickness = thickness
	roof.roof_overhang = overhang
	roof.roof_color = color
	roof.roof_rotation_degrees = rotation_degrees
	roof.build_on_ready = true
	roof.generate_collision = true
	roof.rebuild_roof_mesh()
	return roof


static func create_flat_roof_polygon_node(
	building: Node,
	local_points: PackedVector3Array,
	thickness: float = 0.12,
	overhang: float = 0.2,
	color: Color = Color(0.50, 0.34, 0.25, 1.0)
) -> FlatRoof3DScript:
	var roof := instantiate_roof_style("flat") as FlatRoof3DScript
	roof.name = _unique_child_name(building, "Roof3D")
	roof.roof_thickness = thickness
	roof.roof_overhang = overhang
	roof.roof_color = color
	roof.build_on_ready = true
	roof.generate_collision = true
	roof.set_roof_polygon(local_points)
	return roof


static func instantiate_roof_style(style: String) -> Roof3DScript:
	var style_record := _style_record(ROOF_STYLES, style, "gable")
	var roof_script := style_record["script"] as Script
	return roof_script.new() as Roof3DScript


static func configure_roof_style(
	roof: Roof3DScript,
	angle_degrees: float,
	hip_gable_height: float = 0.0,
	hip_shape: int = 0
) -> void:
	if roof is SlopedRoof3DScript:
		(roof as SlopedRoof3DScript).set_roof_angle_degrees(angle_degrees)
	if roof is HipRoof3DScript:
		(roof as HipRoof3DScript).set_hip_gable_height(hip_gable_height)
		(roof as HipRoof3DScript).set_hip_shape(hip_shape)


static func get_roof_style_parameters(roof: Roof3DScript) -> Dictionary:
	if roof == null:
		return {}
	return roof.get_style_geometry_parameters()


static func get_roof_angle_degrees(roof: Roof3DScript) -> float:
	return float(get_roof_style_parameters(roof).get("angle_degrees", 0.0))


static func get_roof_hip_gable_height(roof: Roof3DScript) -> float:
	return float(get_roof_style_parameters(roof).get(
		"gable_height_from_peak", 0.0
	))


static func get_roof_hip_shape(roof: Roof3DScript) -> int:
	return int(get_roof_style_parameters(roof).get("hip_shape", 0))


static func get_pillar_style_keys() -> PackedStringArray:
	return _style_keys(PILLAR_STYLES)


static func get_roof_style_keys() -> PackedStringArray:
	return _style_keys(ROOF_STYLES)


static func _style_keys(styles: Array) -> PackedStringArray:
	var keys := PackedStringArray()
	for style: Dictionary in styles:
		keys.append(String(style["key"]))
	return keys


static func _style_record(styles: Array, key: String, fallback_key: String = "") -> Dictionary:
	var normalized_key := key.strip_edges().to_lower()
	var fallback: Dictionary = {}
	for style: Dictionary in styles:
		if String(style["key"]) == normalized_key:
			return style
		if String(style["key"]) == fallback_key:
			fallback = style
	return fallback


static func get_opening_style_keys() -> PackedStringArray:
	return _opening_style_keys_for_category("")


static func get_window_style_keys() -> PackedStringArray:
	return _opening_style_keys_for_category("window")


static func get_door_style_keys() -> PackedStringArray:
	return _opening_style_keys_for_category("door")


static func _opening_style_keys_for_category(category: String) -> PackedStringArray:
	var keys := PackedStringArray()
	for style: Dictionary in OPENING_STYLES:
		if category.is_empty() or String(style["category"]) == category:
			keys.append(String(style["key"]))
	return keys


static func get_opening_style(style_key: String) -> Dictionary:
	var normalized_key := style_key.strip_edges().to_lower()
	for style: Dictionary in OPENING_STYLES:
		if String(style["key"]) == normalized_key:
			return style
	return {}


static func is_pillar_style_supported(style: String) -> bool:
	return !_style_record(PILLAR_STYLES, style).is_empty()


static func is_roof_style_supported(style: String) -> bool:
	return !_style_record(ROOF_STYLES, style).is_empty()


static func is_opening_style_supported(style: String) -> bool:
	return !get_opening_style(style).is_empty()


static func is_window_style_supported(style: String) -> bool:
	return String(get_opening_style(style).get("category", "")) == "window"


static func is_door_style_supported(style: String) -> bool:
	return String(get_opening_style(style).get("category", "")) == "door"


static func instantiate_opening_style(style: String) -> BuildingOpening3DScript:
	var normalized_style := style.strip_edges().to_lower()
	var style_record := get_opening_style(normalized_style)
	if style_record.is_empty():
		return null
	var opening_script := style_record["script"] as Script
	return opening_script.new() as BuildingOpening3DScript


static func apply_opening_settings(
	opening: BuildingOpening3DScript,
	settings: Dictionary,
	wall_thickness: float
) -> void:
	if opening == null:
		return
	opening.opening_width = float(settings.get("width", opening.opening_width))
	opening.opening_height = float(settings.get("height", opening.opening_height))
	opening.frame_thickness = float(
		settings.get("frame_thickness", opening.frame_thickness)
	)
	opening.frame_depth = maxf(wall_thickness, 0.0) + 0.04
	opening.wall_thickness = maxf(wall_thickness, 0.0)
	opening.frame_sides = int(settings.get("frame_sides", opening.frame_sides))
	opening.frame_protrusion = float(
		settings.get("frame_protrusion", opening.frame_protrusion)
	)
	opening.frame_color = Color(settings.get("frame_color", opening.frame_color))
	opening.show_bottom_frame = bool(
		settings.get("show_bottom_frame", opening.show_bottom_frame)
	)
	for property_name in OPENING_STYLE_PROPERTY_NAMES:
		var setting_key := String(property_name)
		if settings.has(setting_key) and _object_has_property(opening, property_name):
			opening.set(property_name, settings[setting_key])


static func configure_opening_placement(
	opening: BuildingOpening3DScript,
	wall: Wall3DScript,
	segment_index: int,
	distance_along_wall: float,
	sill_height: float,
	face_sign: float,
	allow_base_edge: bool
) -> bool:
	if opening == null or wall == null:
		return false
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	var resolved_face_sign := 1.0 if face_sign >= 0.0 else -1.0
	var frame := wall.get_segment_local_frame(segment_index)
	var local_position := Vector3(
		distance_along_wall,
		maxf(sill_height, 0.0) + opening.opening_height * 0.5,
		resolved_face_sign * (
			segment.thickness * 0.5 + BuildingOpening3DScript.FRAME_FACE_GAP
		)
	)
	opening.transform = Transform3D(
		opening_basis_for_face(frame.basis, resolved_face_sign),
		frame * local_position
	)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, segment_index)
	opening.set_meta(OPENING_SILL_META, maxf(sill_height, 0.0))
	opening.set_meta(OPENING_ALLOW_BASE_META, allow_base_edge)
	return true


static func create_opening_node(
	wall: Wall3DScript,
	segment_index: int,
	distance_along_wall: float,
	sill_height: float,
	face_sign: float,
	settings: Dictionary
) -> BuildingOpening3DScript:
	if wall == null:
		return null
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return null
	var style := String(settings.get("style", ""))
	var opening := instantiate_opening_style(style)
	if opening == null:
		return null
	var name_prefix := String(settings.get("node_name", "BuildingOpening3D"))
	opening.name = _unique_child_name(wall, name_prefix)
	apply_opening_settings(opening, settings, segment.thickness)
	var allow_base_edge := bool(settings.get("allow_base_edge", false))
	if !configure_opening_placement(
		opening,
		wall,
		segment_index,
		distance_along_wall,
		sill_height,
		face_sign,
		allow_base_edge
	):
		opening.free()
		return null
	opening.build_on_ready = true
	opening.generate_collision = true
	return opening


static func opening_basis_for_face(basis: Basis, face_sign: float) -> Basis:
	if face_sign < 0.0:
		return basis * Basis(Vector3.UP, PI)
	return basis


static func _object_has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


static func _unique_child_name(building: Node, prefix: String) -> String:
	var index := 1
	var candidate := "%s%d" % [prefix, index]
	if building == null:
		return candidate
	var used_names := {}
	for child in building.get_children():
		used_names[String(child.name)] = true
	while used_names.has(candidate):
		index += 1
		candidate = "%s%d" % [prefix, index]
	return candidate
