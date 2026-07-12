@tool
class_name BuildingSpecCompiler
extends RefCounted

const BuildingSpecScript = preload(
	"res://addons/low_poly_building_editor/building_spec.gd"
)
const BuildingGenerationSpecScript = preload(
	"res://addons/low_poly_building_editor/building_generation_spec.gd"
)
const StreetSpecScript = preload(
	"res://addons/low_poly_building_editor/street_spec.gd"
)
const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)
const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const Wall3DScript = preload(
	"res://addons/low_poly_building_editor/walls/wall_3d.gd"
)

const EXTERIOR_FACE_SIGN := -1.0
const OPENING_CLEARANCE := 0.04
const MIN_FOOTPRINT_CELLS := 6


static func load_json_spec(path: String) -> Dictionary:
	var errors: Array[String] = []
	if !FileAccess.file_exists(path):
		errors.append("Spec file does not exist: %s" % path)
		return {"spec": null, "errors": errors}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not open spec file: %s" % path)
		return {"spec": null, "errors": errors}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		errors.append(
			"JSON parse error at line %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)
		return {"spec": null, "errors": errors}
	if !(parser.data is Dictionary):
		errors.append("The building spec JSON root must be an object.")
		return {"spec": null, "errors": errors}
	var type := String(parser.data.get("type", "building")).strip_edges().to_lower()
	var spec: BuildingGenerationSpecScript
	match type:
		"building":
			spec = BuildingSpecScript.new() as BuildingSpecScript
		"street":
			spec = StreetSpecScript.new() as StreetSpecScript
		_:
			errors.append("Unsupported generated asset type '%s'." % type)
			return {"spec": null, "errors": errors}
	errors.append_array(spec.apply_dictionary(parser.data))
	return {
		"spec": spec,
		"errors": errors,
	}


static func compile(spec: BuildingGenerationSpecScript) -> Dictionary:
	if spec == null:
		return _result(null, {}, ["No generation spec was provided."], [])
	if spec is StreetSpecScript:
		return _compile_street(spec as StreetSpecScript)
	if spec is BuildingSpecScript:
		return _compile_building(spec as BuildingSpecScript)
	return _result(null, {}, ["Unsupported generation spec resource."], [])


static func _compile_building(spec: BuildingSpecScript) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if spec == null:
		errors.append("No BuildingSpec was provided.")
		return _result(null, {}, errors, warnings)
	errors.append_array(spec.validate())
	if !errors.is_empty():
		return _result(null, {}, errors, warnings)

	var rng := RandomNumberGenerator.new()
	rng.seed = spec.generation_seed
	var resolved_footprint := _resolve_footprint_cells(spec, rng)
	var resolved_door_style := _resolve_style(
		spec.door_style,
		BuildingFactoryScript.get_door_style_keys(),
		rng
	)
	var resolved_window_style := _resolve_style(
		spec.window_style,
		BuildingFactoryScript.get_window_style_keys(),
		rng
	)
	var resolved_roof_style := _resolve_style(
		spec.roof_style,
		BuildingFactoryScript.get_roof_style_keys(),
		rng
	)
	var resolved_entrance_segment := (
		rng.randi_range(0, 3)
		if spec.entrance_segment < 0
		else spec.entrance_segment
	)
	var footprint_size := Vector2(
		resolved_footprint.x * spec.grid_step,
		resolved_footprint.y * spec.grid_step
	)
	var resolved := {
		"schema_version": spec.schema_version,
		"generator_version": spec.generator_version,
		"seed": spec.generation_seed,
		"building_name": spec.building_name,
		"grid_step": spec.grid_step,
		"footprint_cells": [resolved_footprint.x, resolved_footprint.y],
		"footprint_size": [footprint_size.x, footprint_size.y],
		"door_style": resolved_door_style,
		"window_style": resolved_window_style,
		"roof_style": resolved_roof_style,
		"entrance_segment": resolved_entrance_segment,
	}

	var building := Building3DScript.new() as Building3D
	building.name = _safe_node_name(spec.building_name)

	var floor := BuildingFactoryScript.create_floor_node(
		building,
		Vector3.ZERO,
		Vector3(footprint_size.x, 0.0, footprint_size.y),
		spec.floor_thickness,
		spec.floor_color
	)
	_attach_authored(building, floor, building)

	var room := BuildingFactoryScript.create_room_node(
		building,
		Vector3.ZERO,
		Vector3(footprint_size.x, 0.0, footprint_size.y),
		spec.wall_height,
		spec.wall_thickness,
		spec.wall_color
	)
	_attach_authored(building, room, building)

	var entrance_distance := _snapped_segment_center(
		room,
		resolved_entrance_segment,
		spec.grid_step
	)
	if !_add_entrance(
		building,
		room,
		resolved_entrance_segment,
		entrance_distance,
		resolved_door_style,
		spec
	):
		errors.append("The generated entrance does not fit on its wall segment.")

	var window_count := _add_facade_windows(
		building,
		room,
		resolved_window_style,
		spec
	)
	if spec.window_count_per_wall > 0 and window_count == 0:
		warnings.append("No facade windows fit after opening validation.")

	if spec.porch_pillars and errors.is_empty():
		_add_porch_pillars(
			building,
			room,
			resolved_entrance_segment,
			entrance_distance,
			spec
		)

	room.rebuild_wall_mesh()

	var roof := BuildingFactoryScript.create_roof_node(
		building,
		Vector3(0.0, spec.wall_height, 0.0),
		Vector3(footprint_size.x, spec.wall_height, footprint_size.y),
		resolved_roof_style,
		spec.roof_angle_degrees,
		spec.roof_thickness,
		spec.roof_overhang,
		spec.roof_color
	)
	_attach_authored(building, roof, building)
	building.refresh_building_geometry_clips()

	resolved["window_count"] = window_count
	resolved["node_count"] = _count_authored_nodes(building, building)
	resolved["structural_signature"] = hash(resolved)

	if !errors.is_empty():
		building.free()
		return _result(null, resolved, errors, warnings)
	return _result(building, resolved, errors, warnings)


static func _compile_street(spec: StreetSpecScript) -> Dictionary:
	var errors: Array[String] = spec.validate()
	var warnings: Array[String] = []
	if !errors.is_empty():
		return _result(null, {}, errors, warnings)
	var building := Building3DScript.new() as Building3D
	building.name = _safe_node_name(spec.building_name)
	var street := BuildingFactoryScript.create_street_node(
		building,
		spec.path_points,
		{
			"road_width": spec.road_width,
			"road_thickness": spec.road_thickness,
			"road_color": spec.road_color,
			"kerb_width": spec.kerb_width,
			"kerb_height": spec.kerb_height,
			"kerb_color": spec.kerb_color,
			"footpath_width": spec.footpath_width,
			"footpath_thickness": spec.footpath_thickness,
			"footpath_color": spec.footpath_color,
			"stair_threshold_degrees": spec.stair_threshold_degrees,
			"target_riser_height": spec.target_riser_height,
			"max_riser_height": spec.max_riser_height,
			"min_tread_depth": spec.min_tread_depth,
		}
	)
	var street_errors: Array[String] = street.get_validation_errors()
	if !street_errors.is_empty():
		street.free()
		building.free()
		return _result(null, {}, street_errors, warnings)
	_attach_authored(building, street, building)
	var stats: Dictionary = street.get_last_build_stats()
	var serialized_path: Array[Array] = []
	for point in spec.path_points:
		serialized_path.append([point.x, point.y, point.z])
	var resolved := {
		"type": "street",
		"schema_version": spec.schema_version,
		"generator_version": spec.generator_version,
		"seed": spec.generation_seed,
		"building_name": spec.building_name,
		"grid_step": spec.grid_step,
		"path": serialized_path,
		"path_point_count": spec.path_points.size(),
		"stair_segment_count": int(stats.get("stair_segment_count", 0)),
		"step_count": int(stats.get("step_count", 0)),
		"node_count": _count_authored_nodes(building, building),
	}
	resolved["structural_signature"] = hash(resolved)
	return _result(building, resolved, errors, warnings)


static func save_building(building: Building3D, output_path: String) -> Error:
	if building == null:
		return ERR_INVALID_PARAMETER
	if output_path.get_extension().to_lower() != "tscn":
		return ERR_INVALID_PARAMETER
	var absolute_directory := ProjectSettings.globalize_path(
		output_path.get_base_dir()
	)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		absolute_directory
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var packed := PackedScene.new()
	var pack_error := packed.pack(building)
	if pack_error != OK:
		return pack_error
	var save_error := ResourceSaver.save(packed, output_path)
	if save_error != OK:
		return save_error
	var saved_scene := ResourceLoader.load(
		output_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if saved_scene == null:
		return ERR_FILE_CORRUPT
	var saved_instance := saved_scene.instantiate() as Building3DScript
	if saved_instance == null:
		return ERR_FILE_CORRUPT
	saved_instance.free()
	return OK


static func _add_entrance(
	building: Building3D,
	room: Wall3DScript,
	segment_index: int,
	distance_along_wall: float,
	style: String,
	spec: BuildingSpecScript
) -> bool:
	var size := Vector2(spec.door_width, spec.door_height)
	var center := Vector2(distance_along_wall, spec.door_height * 0.5)
	if !building.can_place_wall_opening(
		room,
		segment_index,
		center,
		size,
		OPENING_CLEARANCE,
		null,
		true
	):
		return false
	var settings := {
		"style": style,
		"node_name": "EntranceDoor",
		"width": spec.door_width,
		"height": spec.door_height,
		"frame_thickness": 0.08,
		"frame_color": spec.frame_color,
		"door_panel_color": spec.door_color,
		"show_bottom_frame": false,
		"allow_base_edge": true,
	}
	var door := BuildingFactoryScript.create_opening_node(
		room,
		segment_index,
		distance_along_wall,
		0.0,
		EXTERIOR_FACE_SIGN,
		settings
	)
	if door == null:
		return false
	_attach_authored(room, door, building)
	return true


static func _add_facade_windows(
	building: Building3D,
	room: Wall3DScript,
	style: String,
	spec: BuildingSpecScript
) -> int:
	var added := 0
	var settings := {
		"style": style,
		"node_name": "Window",
		"width": spec.window_width,
		"height": spec.window_height,
		"frame_thickness": 0.08,
		"frame_color": spec.frame_color,
		"window_pane_color": spec.window_pane_color,
		"show_bottom_frame": true,
		"allow_base_edge": false,
	}
	for segment_index in range(room.get_segment_count()):
		var segment := room.get_segment(segment_index)
		if segment == null:
			continue
		var positions := _evenly_spaced_positions(
			segment.get_length(),
			spec.window_count_per_wall,
			spec.grid_step
		)
		for distance_along_wall in positions:
			var center := Vector2(
				distance_along_wall,
				spec.window_sill_height + spec.window_height * 0.5
			)
			if !building.can_place_wall_opening(
				room,
				segment_index,
				center,
				Vector2(spec.window_width, spec.window_height),
				OPENING_CLEARANCE,
				null,
				false
			):
				continue
			var window := BuildingFactoryScript.create_opening_node(
				room,
				segment_index,
				distance_along_wall,
				spec.window_sill_height,
				EXTERIOR_FACE_SIGN,
				settings
			)
			if window == null:
				continue
			_attach_authored(room, window, building)
			added += 1
	return added


static func _add_porch_pillars(
	building: Building3D,
	room: Wall3DScript,
	segment_index: int,
	entrance_distance: float,
	spec: BuildingSpecScript
) -> void:
	var segment := room.get_segment(segment_index)
	if segment == null:
		return
	var frame := segment.get_frame()
	var entrance_center := frame.origin + frame.basis.x * entrance_distance
	var horizontal_offset := spec.door_width * 0.75 + spec.pillar_radius
	var outward_offset := maxf(spec.roof_overhang, 0.35) + spec.pillar_radius
	for direction in [-1.0, 1.0]:
		var base: Vector3 = (
			entrance_center
			+ frame.basis.x * horizontal_offset * direction
			- frame.basis.z * outward_offset
		)
		base.y = 0.0
		var pillar := BuildingFactoryScript.create_pillar_node(
			building,
			base,
			spec.pillar_radius,
			spec.wall_height,
			8,
			spec.pillar_style,
			spec.frame_color,
			0.08,
			0.04,
			0.08,
			0.04
		)
		_attach_authored(building, pillar, building)


static func _resolve_footprint_cells(
	spec: BuildingSpecScript,
	rng: RandomNumberGenerator
) -> Vector2i:
	var resolved := spec.footprint_cells
	if spec.footprint_jitter_cells.x > 0:
		resolved.x += rng.randi_range(
			-spec.footprint_jitter_cells.x,
			spec.footprint_jitter_cells.x
		)
	if spec.footprint_jitter_cells.y > 0:
		resolved.y += rng.randi_range(
			-spec.footprint_jitter_cells.y,
			spec.footprint_jitter_cells.y
		)
	resolved.x = maxi(resolved.x, MIN_FOOTPRINT_CELLS)
	resolved.y = maxi(resolved.y, MIN_FOOTPRINT_CELLS)
	return resolved


static func _resolve_style(
	requested: String,
	candidates: PackedStringArray,
	rng: RandomNumberGenerator
) -> String:
	var normalized := requested.strip_edges().to_lower()
	if normalized != BuildingSpecScript.RANDOM_STYLE:
		return normalized
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _snapped_segment_center(
	wall: Wall3DScript,
	segment_index: int,
	grid_step: float
) -> float:
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return 0.0
	var step := maxf(grid_step, 0.05)
	return roundf((segment.get_length() * 0.5) / step) * step


static func _evenly_spaced_positions(
	segment_length: float,
	count: int,
	grid_step: float
) -> Array[float]:
	var positions: Array[float] = []
	if count <= 0:
		return positions
	var step := maxf(grid_step, 0.05)
	for index in range(count):
		var raw_position := segment_length * float(index + 1) / float(count + 1)
		var snapped_position := roundf(raw_position / step) * step
		if positions.is_empty() or !is_equal_approx(positions[-1], snapped_position):
			positions.append(snapped_position)
	return positions


static func _attach_authored(parent: Node, node: Node, scene_owner: Node) -> void:
	if parent == null or node == null:
		return
	parent.add_child(node)
	node.owner = scene_owner


static func _count_authored_nodes(root: Node, scene_owner: Node) -> int:
	var count := 1
	for child in root.get_children():
		if child.owner == scene_owner:
			count += _count_authored_nodes(child, scene_owner)
	return count


static func _safe_node_name(source: String) -> String:
	var result := source.strip_edges()
	for forbidden in ["/", ":", "@", "\"", "%"]:
		result = result.replace(forbidden, "_")
	return result if !result.is_empty() else "GeneratedBuilding"


static func _result(
	building: Building3D,
	resolved: Dictionary,
	errors: Array[String],
	warnings: Array[String]
) -> Dictionary:
	return {
		"building": building,
		"resolved": resolved,
		"errors": errors,
		"warnings": warnings,
	}
