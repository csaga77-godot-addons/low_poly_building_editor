@tool
extends Node3D

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingMesh3DScript = preload(
	"res://addons/low_poly_building_editor/building_mesh_3d.gd"
)
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const BuildingWireframeScript = preload(
	"res://addons/low_poly_building_editor/building_wireframe.gd"
)
const BuildingSpecScript = preload("res://addons/low_poly_building_editor/building_spec.gd")
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const BuildingThumbnailRendererScript = preload(
	"res://addons/low_poly_building_editor/building_thumbnail_renderer.gd"
)
const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floors/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs/stairs_3d.gd")
const TurningStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/turning_stairs_3d.gd"
)
const StraightStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/straight_stairs_3d.gd"
)
const LShapedStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/l_shaped_stairs_3d.gd"
)
const DoubleLShapedStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/double_l_shaped_stairs_3d.gd"
)
const UShapedStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/u_shaped_stairs_3d.gd"
)
const WinderStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/winder_stairs_3d.gd"
)
const SpiralStairs3DScript = preload(
	"res://addons/low_poly_building_editor/stairs/spiral_stairs_3d.gd"
)
const Rail3DScript = preload("res://addons/low_poly_building_editor/rails/rail_3d.gd")
const StandardRailGeometryScript = preload(
	"res://addons/low_poly_building_editor/rails/standard_rail_geometry_3d.gd"
)
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillars/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")
const RoofStyleGeometryFactory := preload(
	"res://addons/low_poly_building_editor/roofs/roof_style_geometry_factory_3d.gd"
)
const RoundPillar3DScript = preload("res://addons/low_poly_building_editor/pillars/round_pillar_3d.gd")
const SquarePillar3DScript = preload("res://addons/low_poly_building_editor/pillars/square_pillar_3d.gd")
const FlatRoof3DScript = preload("res://addons/low_poly_building_editor/roofs/flat_roof_3d.gd")
const SlopedRoof3DScript = preload("res://addons/low_poly_building_editor/roofs/sloped_roof_3d.gd")
const GableRoof3DScript = preload("res://addons/low_poly_building_editor/roofs/gable_roof_3d.gd")
const HipRoof3DScript = preload("res://addons/low_poly_building_editor/roofs/hip_roof_3d.gd")
const PyramidHipGeometryScript = preload("res://addons/low_poly_building_editor/roofs/pyramid_hip_geometry_3d.gd")
const HexagonalHipGeometryScript = preload("res://addons/low_poly_building_editor/roofs/hexagonal_hip_geometry_3d.gd")
const OctagonHipGeometryScript = preload("res://addons/low_poly_building_editor/roofs/octagon_hip_geometry_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/openings/building_opening_3d.gd")
const Window3DScript = preload("res://addons/low_poly_building_editor/openings/window_3d.gd")
const Door3DScript = preload("res://addons/low_poly_building_editor/openings/door_3d.gd")
const SingleWindow3DScript = preload("res://addons/low_poly_building_editor/openings/single_window_3d.gd")
const DoubleWindow3DScript = preload("res://addons/low_poly_building_editor/openings/double_window_3d.gd")
const GridWindow3DScript = preload("res://addons/low_poly_building_editor/openings/grid_window_3d.gd")
const LouveredWindow3DScript = preload("res://addons/low_poly_building_editor/openings/louvered_window_3d.gd")
const TransomWindow3DScript = preload("res://addons/low_poly_building_editor/openings/transom_window_3d.gd")
const ArchedWindow3DScript = preload("res://addons/low_poly_building_editor/openings/arched_window_3d.gd")
const WindowFrame3DScript = preload("res://addons/low_poly_building_editor/openings/window_frame_3d.gd")
const SingleDoor3DScript = preload("res://addons/low_poly_building_editor/openings/single_door_3d.gd")
const DoubleDoor3DScript = preload("res://addons/low_poly_building_editor/openings/double_door_3d.gd")
const GlazedDoor3DScript = preload("res://addons/low_poly_building_editor/openings/glazed_door_3d.gd")
const GlazedGridDoor3DScript = preload("res://addons/low_poly_building_editor/openings/glazed_grid_door_3d.gd")
const PanelDoor3DScript = preload("res://addons/low_poly_building_editor/openings/panel_door_3d.gd")
const DutchDoor3DScript = preload("res://addons/low_poly_building_editor/openings/dutch_door_3d.gd")
const SingleDoorFrame3DScript = preload("res://addons/low_poly_building_editor/openings/single_door_frame_3d.gd")
const DoubleDoorFrame3DScript = preload("res://addons/low_poly_building_editor/openings/double_door_frame_3d.gd")
const WallSegmentScript = preload("res://addons/low_poly_building_editor/walls/wall_segment.gd")
const HUMAN_BODY_3D_SCENE := preload("res://characters/human_body_3d.tscn")
const TEST_ROOF_ANGLE_DEGREES := 40.0
const TEST_ROOF_ALT_ANGLE_DEGREES := 30.0
const WALL_COLLISION_TEST_ORIGIN := Vector3(24.0, 0.0, 36.0)
const WALL_COLLISION_PROBE_SPEED := 4.0
const WALL_COLLISION_PROBE_FRAMES := 90
const WALL_COLLISION_MAX_TRAVEL := 1.85
const WALL_COLLISION_MAX_NORMAL_Y := 0.75
const WALL_COLLISION_SLIDE_FRAMES := 56
const WALL_COLLISION_SLIDE_MIN_TOTAL_PARALLEL_TRAVEL := 1.6
const WALL_COLLISION_SLIDE_MIN_CONTACT_PARALLEL_TRAVEL := 0.45
const STAIRS_SIDE_COLLISION_TEST_ORIGIN := Vector3(36.0, 0.0, 36.0)
const STAIRS_SIDE_COLLISION_PROBE_SPEED := 4.0
const STAIRS_SIDE_COLLISION_PROBE_FRAMES := 90
const STAIRS_SIDE_COLLISION_MAX_TRAVEL := 1.25
const STAIRS_SIDE_COLLISION_MAX_CLIMB := 0.2
const STAIRS_SIDE_COLLISION_MAX_NORMAL_Y := 0.75
const STAIRS_FRONT_CLIMB_PROBE_FRAMES := 100
const STAIRS_FRONT_CLIMB_MIN_TRAVEL := 3.0
const STAIRS_FRONT_CLIMB_MIN_HEIGHT := 0.9
const STAIRS_SIDE_EXIT_PROBE_FRAMES := 45
const STAIRS_SIDE_EXIT_MIN_TRAVEL := 1.8

var m_failures: Array[String] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	_validate_empty_wall_segments()
	_validate_building_root_ownership()
	_validate_multiple_building_roots()
	_validate_serialized_building_mesh_caches()
	_validate_opening_factory()
	_validate_building_spec_compiler()
	_validate_building_contact_sheet()
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "Building3D"
	add_child(coordinator)

	var wall := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3.ZERO,
		Vector3(4.0, 0.0, 0.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	coordinator.add_child(wall)

	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "WindowOpening"
	opening.opening_width = 1.0
	opening.opening_height = 1.0
	opening.position = Vector3(2.0, 1.1, 0.12)
	wall.add_child(opening)
	wall.rebuild_wall_mesh()

	_validate_wall_mesh(wall)
	_validate_opening_rules(wall)
	_validate_opening_class_hierarchy()
	_validate_door_style_property_ownership()
	_validate_window_style_property_ownership()
	_validate_pillar_style_property_ownership()
	_validate_roof_style_property_ownership()
	_validate_stair_layout_class_hierarchy()
	_validate_door_opening_rules(wall)
	_validate_window_style_visuals()
	_validate_new_opening_style_visuals()
	_validate_frame_sides()
	_validate_opening_follows_wall_segment()
	_validate_snapping(coordinator)
	_validate_wall_base_height(coordinator)
	_validate_room_node(coordinator)
	_validate_floor_node(coordinator)
	_validate_stairs_node(coordinator)
	_validate_spiral_stairs(coordinator)
	_validate_stair_tread_styles(coordinator)
	_validate_stairs_optional_rails(coordinator)
	_validate_standard_rail_geometry_post_base_heights()
	_validate_rail_node(coordinator)
	_validate_pillar_node(coordinator)
	_validate_roof_node(coordinator)
	_validate_shared_debug_wireframes(coordinator)
	_validate_merge_detection(coordinator)
	_validate_intersection_merge()
	_validate_wall_instance_intersection_clipping()
	_validate_roof_wall_clipping()
	_validate_add_wall_joint()
	_validate_joint_endpoint_drag()
	_validate_joint_disconnect_connect()
	_validate_mitered_joint()
	_validate_miter_draw_direction_invariance()
	_validate_connected_wall_top_caps()
	_validate_multi_wall_joint_fill()
	_validate_enclosed_wall_loop_caps()
	_validate_overlapping_room_wall_clipping()
	_validate_collinear_overlap_opening_propagation()
	await _validate_event_driven_geometry_refresh()
	await _validate_wall_collision_blocks_character(coordinator)
	await _validate_stairs_side_collision_blocks_character(coordinator)

	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: LowPolyBuilding3D smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_building_root_ownership() -> void:
	var building := Building3DScript.new() as Building3DScript
	var editor_default_names := [
		&"grid_step",
		&"lock_to_8_way",
		&"default_wall_height",
		&"default_floor_thickness",
		&"default_stair_height",
		&"default_pillar_height",
		&"default_roof_style",
	]
	for property in building.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if editor_default_names.has(property_name):
			m_failures.append("Building3D still exposes editor default property %s" % property_name)
	var detached_wall := BuildingFactoryScript.create_wall_node(
		building,
		Vector3.ZERO,
		Vector3.RIGHT
	)
	if detached_wall.get_parent() != null:
		m_failures.append("BuildingFactory parented a wall instead of returning a detached node")
	detached_wall.free()
	building.free()


func _validate_opening_factory() -> void:
	if !BuildingFactoryScript.is_window_style_supported("grid_window"):
		m_failures.append("BuildingFactory did not publish its window style registry")
	if !BuildingFactoryScript.is_door_style_supported("glazed_door"):
		m_failures.append("BuildingFactory did not publish its door style registry")
	if BuildingFactoryScript.is_opening_style_supported("imaginary_window"):
		m_failures.append("BuildingFactory accepted an unknown opening style")

	var building := Building3DScript.new() as Building3DScript
	var room := BuildingFactoryScript.create_room_node(
		building,
		Vector3.ZERO,
		Vector3(6.0, 0.0, 5.0)
	)
	building.add_child(room)
	var settings := {
		"style": "grid_window",
		"node_name": "FactoryWindow",
		"width": 1.2,
		"height": 1.1,
		"frame_color": Color(0.92, 0.94, 0.96, 1.0),
		"window_pane_color": Color(0.4, 0.7, 0.9, 0.5),
		"pane_grid_rows": 3,
		"pane_grid_cols": 2,
		"show_bottom_frame": true,
		"allow_base_edge": false,
	}
	var opening := BuildingFactoryScript.create_opening_node(
		room,
		1,
		2.0,
		0.9,
		-1.0,
		settings
	)
	if opening == null:
		m_failures.append("BuildingFactory could not create a valid typed opening")
	else:
		if opening.get_script() != GridWindow3DScript:
			m_failures.append("BuildingFactory opening style did not select GridWindow3D")
		if opening.get_parent() != null:
			m_failures.append("BuildingFactory parented an opening instead of returning it detached")
		if int(opening.get_meta(Wall3DScript.SEGMENT_INDEX_META, -1)) != 1:
			m_failures.append("BuildingFactory opening did not retain its target wall segment")
		if !is_equal_approx(
			float(opening.get_meta(BuildingFactoryScript.OPENING_SILL_META, -1.0)),
			0.9
		):
			m_failures.append("BuildingFactory opening did not retain its sill height")
		if opening.frame_depth <= room.get_segment(1).thickness:
			m_failures.append("BuildingFactory opening frame did not span the target wall")
		opening.free()
	var invalid := BuildingFactoryScript.create_opening_node(
		room,
		0,
		2.0,
		0.9,
		-1.0,
		{"style": "imaginary_window"}
	)
	if invalid != null:
		m_failures.append("BuildingFactory opening creation accepted an unknown style")
		invalid.free()
	building.free()


func _validate_building_spec_compiler() -> void:
	var file_load_result := BuildingSpecCompilerScript.load_json_spec(
		"res://addons/low_poly_building_editor/examples/seeded_villa.json"
	)
	var file_load_errors: Array = file_load_result.get("errors", [])
	if !file_load_errors.is_empty() or file_load_result.get("spec") == null:
		m_failures.append(
			"BuildingSpecCompiler could not load the documented JSON example: %s"
			% file_load_errors
		)
	var data := {
		"schema_version": 1,
		"generator_version": 1,
		"name": "CompilerTestBuilding",
		"seed": 90210,
		"grid_step": 0.5,
		"footprint_cells": [16, 12],
		"storeys": 1,
		"variation": {"footprint_jitter_cells": [2, 2]},
		"facade": {
			"door_style": "glazed_door",
			"entrance_segment": -1,
			"window_style": "random",
			"window_count_per_wall": 2,
			"porch_pillars": true,
			"pillar_style": "square",
		},
		"roof": {"style": "random"},
	}
	var first_spec := BuildingSpecScript.new() as BuildingSpecScript
	var parse_errors := first_spec.apply_dictionary(data)
	if !parse_errors.is_empty():
		m_failures.append("BuildingSpec rejected a valid generator spec: %s" % parse_errors)
		return
	var first_result := BuildingSpecCompilerScript.compile(first_spec)
	var first_errors: Array = first_result.get("errors", [])
	var first_building := first_result.get("building") as Building3DScript
	if !first_errors.is_empty() or first_building == null:
		m_failures.append("BuildingSpecCompiler failed a valid spec: %s" % first_errors)
		return

	var second_spec := BuildingSpecScript.new() as BuildingSpecScript
	second_spec.apply_dictionary(data)
	var second_result := BuildingSpecCompilerScript.compile(second_spec)
	var second_building := second_result.get("building") as Building3DScript
	if second_building == null:
		m_failures.append("BuildingSpecCompiler could not repeat a valid generation")
		first_building.free()
		return
	var first_resolved: Dictionary = first_result.get("resolved", {})
	var second_resolved: Dictionary = second_result.get("resolved", {})
	if first_resolved != second_resolved:
		m_failures.append("BuildingSpecCompiler produced different output for the same seed")
	if first_building.get_wall_nodes().size() != 1:
		m_failures.append("BuildingSpecCompiler did not create one exterior room shell")
	if first_building.get_roof_nodes().size() != 1:
		m_failures.append("BuildingSpecCompiler did not create one roof")
	var generated_room := first_building.get_wall_nodes()[0]
	var door_count := 0
	var window_count := 0
	for child in generated_room.get_children():
		if child is Door3DScript:
			door_count += 1
		elif child is Window3DScript:
			window_count += 1
	if door_count != 1:
		m_failures.append("BuildingSpecCompiler did not create exactly one entrance")
	if window_count <= 0:
		m_failures.append("BuildingSpecCompiler did not create facade windows")

	var packed := PackedScene.new()
	if packed.pack(first_building) != OK:
		m_failures.append("BuildingSpecCompiler result could not be packed as a scene")
	else:
		var instance := packed.instantiate() as Building3DScript
		if instance == null or instance.get_wall_nodes().size() != 1:
			m_failures.append("Packed generated building did not restore its authored shell")
		if instance != null:
			instance.free()

	var invalid_spec := BuildingSpecScript.new() as BuildingSpecScript
	var invalid_errors := invalid_spec.apply_dictionary({
		"facade": {"window_style": "imaginary_window"},
	})
	if invalid_errors.is_empty():
		m_failures.append("BuildingSpec accepted an unsupported window style")
	first_building.free()
	second_building.free()


func _validate_building_contact_sheet() -> void:
	var first_path := "user://__building_thumbnail_rgb.png"
	var second_path := "user://__building_thumbnail_rgba.png"
	var sheet_path := "user://__building_thumbnail_sheet.png"
	var first := Image.create(8, 6, false, Image.FORMAT_RGB8)
	first.fill(Color(0.8, 0.3, 0.2, 1.0))
	var second := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	second.fill(Color(0.2, 0.4, 0.8, 1.0))
	if first.save_png(first_path) != OK or second.save_png(second_path) != OK:
		m_failures.append("Could not create contact-sheet test images")
	else:
		var error := BuildingThumbnailRendererScript.create_contact_sheet(
			PackedStringArray([first_path, second_path]),
			sheet_path,
			2
		)
		if error != OK:
			m_failures.append(
				"BuildingThumbnailRenderer could not compose mixed-format images"
			)
		else:
			var sheet := Image.load_from_file(
				ProjectSettings.globalize_path(sheet_path)
			)
			if sheet == null or sheet.get_size() != Vector2i(52, 30):
				m_failures.append(
					"BuildingThumbnailRenderer contact sheet has the wrong size"
				)
	for path in [first_path, second_path, sheet_path]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute_path)


func _validate_multiple_building_roots() -> void:
	var scene := Node3D.new()
	scene.name = "MultipleBuildingScene"
	add_child(scene)
	var first := Building3DScript.new() as Building3DScript
	first.name = "Building3D"
	scene.add_child(first)
	var second := Building3DScript.new() as Building3DScript
	second.name = "Building3D2"
	scene.add_child(second)
	var first_wall := BuildingFactoryScript.create_wall_node(
		first,
		Vector3(0.0, 0.0, 0.2),
		Vector3(4.0, 0.0, 0.2),
		4.0
	)
	first.add_child(first_wall)
	var second_wall := BuildingFactoryScript.create_wall_node(
		second,
		Vector3(0.0, 0.0, 0.2),
		Vector3(4.0, 0.0, 0.2),
		4.0
	)
	second.add_child(second_wall)
	var second_roof := BuildingFactoryScript.create_roof_node(
		second,
		Vector3(0.0, 2.4, 0.0),
		Vector3(4.0, 2.4, 4.0),
		"gable"
	)
	second.add_child(second_roof)
	first.refresh_building_geometry_clips()
	second.refresh_building_geometry_clips()
	if first.get_wall_nodes() != [first_wall] or first.get_roof_nodes().size() != 0:
		m_failures.append("Building3D included parts owned by a sibling building root")
	if second.get_wall_nodes() != [second_wall] or second.get_roof_nodes() != [second_roof]:
		m_failures.append("Building3D did not retain its own independently authored parts")
	if first_wall.get_roof_clip_surface_count() != 0:
		m_failures.append("A roof clipped a wall owned by another Building3D root")
	if second_wall.get_roof_clip_surface_count() != 1:
		m_failures.append("A Building3D roof did not clip a wall in the same root")
	scene.queue_free()


func _validate_empty_wall_segments() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "EmptyWall"
	wall.build_on_ready = false
	add_child(wall)
	wall.rebuild_wall_mesh()
	if wall.get_segment_count() != 0 or !wall.segments.is_empty():
		m_failures.append("Wall3D did not allow an empty canonical segments array")
	if wall.mesh != null or wall.get_node_or_null("WallCollision") != null:
		m_failures.append("Wall3D generated geometry for an empty segments array")
	var has_exported_segments := false
	var has_exported_extra_segments := false
	for property in wall.get_property_list():
		var property_name := String(property.get("name", ""))
		var usage := int(property.get("usage", 0))
		if property_name == "segments" and (usage & PROPERTY_USAGE_EDITOR) != 0:
			has_exported_segments = true
		if property_name == "extra_segments" and (usage & PROPERTY_USAGE_EDITOR) != 0:
			has_exported_extra_segments = true
	if !has_exported_segments:
		m_failures.append("Wall3D segments property is not exported in the inspector")
	if has_exported_extra_segments:
		m_failures.append("Wall3D still exports the legacy Extra Segments property")
	var authored_segment := WallSegmentScript.new() as WallSegment
	authored_segment.start_point = Vector3.ZERO
	authored_segment.end_point = Vector3(4.0, 0.0, 0.0)
	authored_segment.height = 3.1
	authored_segment.thickness = 0.35
	authored_segment.color = Color(0.24, 0.52, 0.74, 1.0)
	var authored_segments: Array[WallSegment] = [authored_segment]
	wall.segments = authored_segments
	var split_geometry := wall.split_segment_geometry(0, Vector3(2.0, 0.0, 0.0), 0.1)
	wall.set_wall_geometry(
		Vector3(split_geometry["start"]),
		Vector3(split_geometry["end"]),
		split_geometry["segments"]
	)
	if wall.get_segment_count() != 2:
		m_failures.append("Wall3D canonical segments did not retain a split wall")
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if (
			!is_equal_approx(segment.height, 3.1)
			or !is_equal_approx(segment.thickness, 0.35)
			or segment.color != authored_segment.color
		):
			m_failures.append("Wall3D geometry edit lost per-segment authored properties")


func _validate_wall_mesh(wall: Wall3DScript) -> void:
	if wall.mesh == null:
		m_failures.append("Wall3D did not generate a mesh")
		return
	if wall.mesh.get_surface_count() <= 0:
		m_failures.append("Wall3D mesh has no surfaces")
		return
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("Wall3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("Wall3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Wall3D mesh is missing per-vertex color data")
	for vertex_index in range(vertices.size()):
		if (
			absf(vertices[vertex_index].y) <= 0.001
			and normals[vertex_index].dot(Vector3.DOWN) > 0.98
		):
			m_failures.append("Wall3D mesh retained hidden bottom triangles")
			break
	if !normals.is_empty() and normals[0].dot(Vector3.BACK) < 0.999:
		m_failures.append("Wall3D primary outside face normal is inverted")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Wall3D triangle winding does not match Godot BoxMesh convention")
	if wall.get_node_or_null("WallCollision") == null:
		m_failures.append("Wall3D did not generate collision for editor raycasts")


func _validate_room_node(coordinator: Building3DScript) -> void:
	var room := BuildingFactoryScript.create_room_node(coordinator,
		Vector3(8.0, 0.5, 8.0),
		Vector3(12.0, 0.5, 11.0),
		2.8,
		0.3,
		Color(0.62, 0.54, 0.44, 1.0)
	)
	coordinator.add_child(room)
	if !room.name.begins_with("Room3D"):
		m_failures.append("Building3D did not give an enclosed room a room name")
	if room.get_segment_count() != 4:
		m_failures.append("Building3D room did not create four wall spans")
	if room.segments.size() != 4:
		m_failures.append("Building3D room did not store every span in Wall3D.segments")
	var expected_corners: Array[Vector3] = [
		Vector3(8.0, 0.5, 8.0),
		Vector3(12.0, 0.5, 8.0),
		Vector3(12.0, 0.5, 11.0),
		Vector3(8.0, 0.5, 11.0),
	]
	for corner in expected_corners:
		if room.count_connected_endpoints(corner, 0.001) != 2:
			m_failures.append("Building3D room walls are not enclosed at %s" % corner)
	for segment_index in range(room.get_segment_count()):
		var segment := room.get_segment(segment_index)
		if !is_equal_approx(segment.height, 2.8):
			m_failures.append("Building3D room wall lost its configured height")
		if !is_equal_approx(segment.thickness, 0.3):
			m_failures.append("Building3D room wall lost its configured thickness")
	room.wall_height = 3.2
	for segment_index in range(room.get_segment_count()):
		if !is_equal_approx(room.get_segment(segment_index).height, 3.2):
			m_failures.append("Wall3D room height change did not update every wall span")
	room.get_segment(2).height = 2.8
	room.wall_height = 3.2
	if !is_equal_approx(room.get_segment(2).height, 3.2):
		m_failures.append("Wall3D room height did not repair a stale wall span")
	if room.mesh == null:
		m_failures.append("Building3D room did not generate a wall mesh")
	if room.get_node_or_null("WallCollision") == null:
		m_failures.append("Building3D room did not generate wall collision")

	var triangular_room := BuildingFactoryScript.create_room_node(
		coordinator,
		Vector3(14.0, 0.5, 8.0),
		Vector3(18.0, 0.5, 12.0),
		2.8,
		0.3,
		Color(0.62, 0.54, 0.44, 1.0),
		2
	)
	if triangular_room.get_segment_count() != 3:
		m_failures.append("BuildingFactory did not enforce the three-side room minimum")
	for segment_index in range(triangular_room.get_segment_count()):
		var segment := triangular_room.get_segment(segment_index)
		if triangular_room.count_connected_endpoints(segment.start_point, 0.001) != 2:
			m_failures.append("BuildingFactory triangular room is not enclosed")
	triangular_room.free()

	var pentagonal_room := BuildingFactoryScript.create_room_node(
		coordinator,
		Vector3(20.0, 0.5, 8.0),
		Vector3(25.0, 0.5, 13.0),
		2.8,
		0.3,
		Color(0.62, 0.54, 0.44, 1.0),
		5
	)
	if pentagonal_room.get_segment_count() != 5:
		m_failures.append("BuildingFactory did not create the configured room side count")
	for segment_index in range(pentagonal_room.get_segment_count()):
		var segment := pentagonal_room.get_segment(segment_index)
		if pentagonal_room.count_connected_endpoints(segment.start_point, 0.001) != 2:
			m_failures.append("BuildingFactory pentagonal room is not enclosed")
	pentagonal_room.free()
	if !room.is_rectangular_loop():
		m_failures.append("Wall3D did not recognize a generated room as a rectangular loop")
	var room_opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	room_opening.name = "RoomResizeWindow"
	room_opening.opening_width = 0.8
	room_opening.opening_height = 0.8
	room_opening.position = room.get_segment_local_frame(1) * Vector3(1.5, 1.1, 0.185)
	room_opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 1)
	room.add_child(room_opening)
	room.rebuild_wall_mesh()
	var old_opening_parent_position := room.transform * room_opening.position
	if !room.move_rectangular_loop_side(1, Vector3(1.0, 0.0, 1.0)):
		m_failures.append("Wall3D could not resize a rectangular room from one wall")
	else:
		var expected_resized_corners: Array[Vector3] = [
			Vector3(8.0, 0.5, 8.0),
			Vector3(13.0, 0.5, 8.0),
			Vector3(13.0, 0.5, 11.0),
			Vector3(8.0, 0.5, 11.0),
		]
		for corner in expected_resized_corners:
			if room.count_connected_endpoints(corner, 0.001) != 2:
				m_failures.append("Room side resize did not preserve corner connection at %s" % corner)
		if room.count_connected_endpoints(Vector3(12.0, 0.5, 8.0), 0.001) != 0:
			m_failures.append("Room side resize moved along the selected wall instead of only perpendicular to it")
		var opening_parent_position := room.transform * room_opening.position
		if opening_parent_position.distance_to(old_opening_parent_position + Vector3.RIGHT) > 0.001:
			m_failures.append("Room side resize did not preserve the opening anchor on the moved wall")


func _validate_opening_rules(wall: Wall3DScript) -> void:
	var overlapping_center := Vector2(2.0, 1.1)
	var open_center := Vector2(3.35, 1.1)
	if wall.can_place_opening(overlapping_center, Vector2(0.8, 0.8)):
		m_failures.append("Wall3D allowed an overlapping window opening")
	if !wall.can_place_opening(open_center, Vector2(0.6, 0.8)):
		m_failures.append("Wall3D rejected a valid non-overlapping opening")


func _validate_opening_class_hierarchy() -> void:
	var opening_base := BuildingOpening3DScript.new() as BuildingOpening3DScript
	for method_name in [&"_leaf_spans", &"_leaf_part_name"]:
		if opening_base.has_method(method_name):
			m_failures.append(
				"BuildingOpening3D exposes pane/leaf-only helper %s" % method_name
			)
	opening_base.free()
	var window_styles: Array[Script] = [
		SingleWindow3DScript,
		DoubleWindow3DScript,
		GridWindow3DScript,
		LouveredWindow3DScript,
		TransomWindow3DScript,
		ArchedWindow3DScript,
		WindowFrame3DScript,
	]
	for style_script in window_styles:
		var window: Node = style_script.new() as Node
		if !(window is Window3DScript) or !(window is BuildingOpening3DScript):
			m_failures.append("%s does not inherit through Window3D" % style_script.resource_path)
		window.free()

	var door_styles: Array[Script] = [
		SingleDoor3DScript,
		DoubleDoor3DScript,
		GlazedDoor3DScript,
		GlazedGridDoor3DScript,
		PanelDoor3DScript,
		DutchDoor3DScript,
		SingleDoorFrame3DScript,
		DoubleDoorFrame3DScript,
	]
	for style_script in door_styles:
		var door: Node = style_script.new() as Node
		if !(door is Door3DScript) or !(door is BuildingOpening3DScript):
			m_failures.append("%s does not inherit through Door3D" % style_script.resource_path)
		door.free()


func _validate_door_style_property_ownership() -> void:
	var opening_base := BuildingOpening3DScript.new() as BuildingOpening3DScript
	for property_name in [
		&"door_panel_count",
		&"door_panel_depth",
		&"door_panel_color",
	]:
		if _has_property(opening_base, property_name):
			m_failures.append(
				"BuildingOpening3D retains removed door property %s" % property_name
			)
	opening_base.free()

	var base_door := Door3DScript.new() as Door3DScript
	var style_only_properties: Array[StringName] = [
		&"door_panel_count",
		&"door_panel_depth",
		&"door_panel_color",
		&"door_glazing_ratio",
		&"door_glass_depth",
		&"door_glass_color",
		&"pane_grid_rows",
		&"pane_grid_cols",
		&"muntin_thickness",
		&"door_inset_rows",
		&"door_inset_cols",
		&"door_split",
	]
	for property_name in style_only_properties:
		if _has_editor_property(base_door, property_name):
			m_failures.append("Door3D still exposes style-only property %s" % property_name)
	base_door.free()

	var single_door := SingleDoor3DScript.new() as Door3DScript
	for property_name in [&"door_panel_depth", &"door_panel_color"]:
		if !_has_editor_property(single_door, property_name):
			m_failures.append("SingleDoor3D is missing shared leaf property %s" % property_name)
	single_door.free()

	var door_frame := DoubleDoorFrame3DScript.new() as Door3DScript
	for property_name in [&"door_panel_depth", &"door_panel_color"]:
		if _has_editor_property(door_frame, property_name):
			m_failures.append("DoubleDoorFrame3D exposes unused leaf property %s" % property_name)
	door_frame.free()

	var glazed_door := GlazedDoor3DScript.new() as Door3DScript
	for property_name in [&"door_glazing_ratio", &"door_glass_depth", &"door_glass_color"]:
		if !_has_editor_property(glazed_door, property_name):
			m_failures.append("GlazedDoor3D is missing style property %s" % property_name)
	glazed_door.free()

	var grid_door := GlazedGridDoor3DScript.new() as Door3DScript
	for property_name in [&"pane_grid_rows", &"pane_grid_cols", &"muntin_thickness"]:
		if !_has_editor_property(grid_door, property_name):
			m_failures.append("GlazedGridDoor3D is missing style property %s" % property_name)
	grid_door.free()

	var panel_door := PanelDoor3DScript.new() as Door3DScript
	for property_name in [&"door_inset_rows", &"door_inset_cols"]:
		if !_has_editor_property(panel_door, property_name):
			m_failures.append("PanelDoor3D is missing style property %s" % property_name)
	panel_door.free()


func _validate_window_style_property_ownership() -> void:
	var base_window := Window3DScript.new() as Window3DScript
	var style_only_properties: Array[StringName] = [
		&"window_pane_count",
		&"window_pane_depth",
		&"window_pane_color",
		&"pane_grid_rows",
		&"pane_grid_cols",
		&"muntin_thickness",
		&"louver_count",
		&"louver_depth",
		&"arch_steps",
		&"transom_ratio",
	]
	for property_name in style_only_properties:
		if _has_editor_property(base_window, property_name):
			m_failures.append("Window3D still exposes style-only property %s" % property_name)
	base_window.free()

	var single_window := SingleWindow3DScript.new() as Window3DScript
	for property_name in [&"window_pane_depth", &"window_pane_color"]:
		if !_has_editor_property(single_window, property_name):
			m_failures.append("SingleWindow3D is missing shared pane property %s" % property_name)
	single_window.free()

	var window_frame := WindowFrame3DScript.new() as Window3DScript
	for property_name in [&"window_pane_depth", &"window_pane_color"]:
		if _has_editor_property(window_frame, property_name):
			m_failures.append("WindowFrame3D exposes unused pane property %s" % property_name)
	window_frame.free()

	var grid_window := GridWindow3DScript.new() as Window3DScript
	for property_name in [&"pane_grid_rows", &"pane_grid_cols", &"muntin_thickness"]:
		if !_has_editor_property(grid_window, property_name):
			m_failures.append("GridWindow3D is missing style property %s" % property_name)
	grid_window.free()

	var louvered_window := LouveredWindow3DScript.new() as Window3DScript
	for property_name in [&"louver_count", &"louver_depth"]:
		if !_has_editor_property(louvered_window, property_name):
			m_failures.append("LouveredWindow3D is missing style property %s" % property_name)
	if _has_editor_property(louvered_window, &"window_pane_color"):
		m_failures.append("LouveredWindow3D exposes an unused pane color")
	louvered_window.free()

	var transom_window := TransomWindow3DScript.new() as Window3DScript
	if !_has_editor_property(transom_window, &"transom_ratio"):
		m_failures.append("TransomWindow3D is missing its transom ratio")
	transom_window.free()

	var arched_window := ArchedWindow3DScript.new() as Window3DScript
	if !_has_editor_property(arched_window, &"arch_steps"):
		m_failures.append("ArchedWindow3D is missing its arch steps")
	arched_window.free()


func _has_editor_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", &"")) != property_name:
			continue
		return (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0
	return false


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false


func _validate_pillar_style_property_ownership() -> void:
	var base_pillar := Pillar3DScript.new() as Pillar3DScript
	var round_pillar := RoundPillar3DScript.new() as Pillar3DScript
	var square_pillar := SquarePillar3DScript.new() as Pillar3DScript
	if _has_editor_property(base_pillar, &"side_count"):
		m_failures.append("Pillar3D still exposes variable-sided style property side_count")
	base_pillar.rebuild_pillar_mesh()
	if base_pillar.mesh != null:
		m_failures.append("Pillar3D base generated concrete style geometry")
	if !_has_editor_property(round_pillar, &"side_count"):
		m_failures.append("RoundPillar3D is missing variable-sided property side_count")
	if _has_editor_property(square_pillar, &"side_count"):
		m_failures.append("SquarePillar3D exposes unused variable-sided property side_count")
	var coordinator := Building3DScript.new() as Building3DScript
	var factory_square := BuildingFactoryScript.instantiate_pillar_style("square")
	if factory_square.get_script() != SquarePillar3DScript:
		m_failures.append("Pillar style factory did not instantiate SquarePillar3D")
	factory_square.free()
	coordinator.free()
	base_pillar.free()
	round_pillar.free()
	square_pillar.free()


func _validate_roof_style_property_ownership() -> void:
	var base_roof := Roof3DScript.new() as Roof3DScript
	var flat_roof := FlatRoof3DScript.new() as Roof3DScript
	var gable_roof := GableRoof3DScript.new() as Roof3DScript
	var hip_roof := HipRoof3DScript.new() as Roof3DScript
	for property_name in [&"roof_style_index", &"roof_height", &"hip_gable_height", &"hip_shape"]:
		if _has_editor_property(base_roof, property_name):
			m_failures.append("Roof3D still exposes style-only property %s" % property_name)
	base_roof.rebuild_roof_mesh()
	if base_roof.mesh != null:
		m_failures.append("Roof3D base generated concrete style geometry")
	if _has_editor_property(flat_roof, &"roof_height"):
		m_failures.append("FlatRoof3D exposes unused sloped-roof property roof_height")
	if !_has_editor_property(gable_roof, &"roof_height"):
		m_failures.append("GableRoof3D is missing shared sloped-roof property roof_height")
	if _has_editor_property(gable_roof, &"hip_gable_height"):
		m_failures.append("GableRoof3D exposes hip-only property hip_gable_height")
	if !_has_editor_property(hip_roof, &"hip_gable_height"):
		m_failures.append("HipRoof3D is missing hip-only property hip_gable_height")
	for method_name in [
		&"set_roof_polygon",
		&"get_roof_polygon",
		&"is_polygon_roof",
		&"is_roof_polygon_valid",
		&"get_roof_angle_degrees",
		&"set_roof_angle_degrees",
		&"get_hip_gable_height",
		&"set_hip_gable_height",
	]:
		if base_roof.has_method(method_name):
			m_failures.append("Roof3D exposes style-only method %s" % method_name)
	for method_name in [
		&"set_roof_polygon",
		&"get_roof_polygon",
		&"is_polygon_roof",
		&"is_roof_polygon_valid",
	]:
		if !flat_roof.has_method(method_name):
			m_failures.append("FlatRoof3D is missing polygon method %s" % method_name)
	if !gable_roof.has_method(&"get_roof_angle_degrees"):
		m_failures.append("GableRoof3D is missing sloped-roof angle access")
	if !hip_roof.has_method(&"get_hip_gable_height"):
		m_failures.append("HipRoof3D is missing hip gable-height access")
	# Hip shape is an authored substyle of the single hip roof class, not a
	# separate serialized style. Standard keeps the ridge and gable drop; the
	# pavilion shapes select their apex geometry strategy.
	if !_has_editor_property(hip_roof, &"hip_shape"):
		m_failures.append("HipRoof3D is missing the hip_shape substyle property")
	if _has_editor_property(gable_roof, &"hip_shape"):
		m_failures.append("GableRoof3D exposes hip-only property hip_shape")
	if base_roof.has_method(&"get_hip_shape") or base_roof.has_method(&"set_hip_shape"):
		m_failures.append("Roof3D exposes style-only hip shape accessors")
	var hip_shape_geometry := {
		HipRoof3DScript.HipShape.PYRAMID: PyramidHipGeometryScript,
		HipRoof3DScript.HipShape.HEXAGONAL: HexagonalHipGeometryScript,
		HipRoof3DScript.HipShape.OCTAGON: OctagonHipGeometryScript,
	}
	for shape in hip_shape_geometry:
		var shaped_hip := HipRoof3DScript.new() as HipRoof3DScript
		shaped_hip.set_hip_shape(int(shape))
		if shaped_hip.get_roof_style() != "hip":
			m_failures.append("Hip shape %d changed the serialized roof style" % shape)
		if shaped_hip.get_hip_shape() != int(shape):
			m_failures.append("HipRoof3D did not retain hip shape %d" % shape)
		if shaped_hip._get_style_geometry().get_script() != hip_shape_geometry[shape]:
			m_failures.append("Hip shape %d selected the wrong geometry strategy" % shape)
		if int(shaped_hip.get_style_geometry_parameters().get("hip_shape", -1)) != int(shape):
			m_failures.append("Hip shape %d is not published through style parameters" % shape)
		shaped_hip.free()
	var coordinator := Building3DScript.new() as Building3DScript
	var factory_flat := BuildingFactoryScript.instantiate_roof_style("flat")
	var factory_hip := BuildingFactoryScript.instantiate_roof_style("hip")
	if factory_flat.get_script() != FlatRoof3DScript:
		m_failures.append("Roof style factory did not instantiate FlatRoof3D")
	if factory_hip.get_script() != HipRoof3DScript:
		m_failures.append("Roof style factory did not instantiate HipRoof3D")
	factory_flat.free()
	factory_hip.free()
	coordinator.free()
	base_roof.free()
	flat_roof.free()
	gable_roof.free()
	hip_roof.free()


func _validate_stair_layout_class_hierarchy() -> void:
	var base_stairs := Stairs3DScript.new() as Stairs3DScript
	for property_name in [
		&"layout_style",
		&"turn_direction",
		&"winder_turn",
		&"flight_width",
		&"spiral_turn_degrees",
	]:
		if _has_editor_property(base_stairs, property_name):
			m_failures.append("Stairs3D exposes layout-only property %s" % property_name)
	base_stairs.rebuild_stairs_mesh()
	if base_stairs.mesh != null:
		m_failures.append("Stairs3D base generated concrete layout geometry")
	for method_name in [
		&"configure_stair_layout",
		&"configure_turning_layout",
		&"configure_winder_layout",
		&"configure_spiral_layout",
		&"_allocate_layout_steps",
		&"_distribute_middle_newels",
		&"_stepped_path_surface_height",
		&"_add_raked_path_rail_runs",
		&"_mirror_layout_plan",
		&"_make_landing_segment",
		&"_make_flight_rail_run",
		&"_append_layout_geometry",
		&"_append_layout_rail_geometry",
		&"_add_layout_side_wall_collision_shapes",
		&"_append_stair_geometry",
		&"_append_rail_geometry",
		&"_get_rail_post_layout",
		&"_append_side_strips",
	]:
		if base_stairs.has_method(method_name):
			m_failures.append("Stairs3D exposes layout-only method %s" % method_name)
	base_stairs.free()

	var layout_entries: Array[Dictionary] = [
		{
			"script": StraightStairs3DScript,
		},
		{
			"script": LShapedStairs3DScript,
		},
		{
			"script": DoubleLShapedStairs3DScript,
		},
		{
			"script": UShapedStairs3DScript,
		},
		{
			"script": WinderStairs3DScript,
		},
		{
			"script": SpiralStairs3DScript,
		},
	]
	for entry: Dictionary in layout_entries:
		var style_script := entry["script"] as Script
		var stairs := style_script.new() as Stairs3DScript
		if stairs == null:
			m_failures.append("%s does not inherit through Stairs3D" % style_script.resource_path)
			continue
		var factory_stairs := BuildingFactoryScript.instantiate_stair_layout(style_script)
		if factory_stairs.get_script() != style_script:
			m_failures.append(
				"Stair layout factory selected the wrong class for %s" % style_script.resource_path
			)
		factory_stairs.free()
		stairs.free()

	var straight := StraightStairs3DScript.new() as Stairs3DScript
	for property_name in [&"turn_direction", &"flight_width"]:
		if _has_editor_property(straight, property_name):
			m_failures.append("StraightStairs3D exposes unused property %s" % property_name)
	if straight.has_method(&"configure_turning_layout"):
		m_failures.append("StraightStairs3D exposes turning-layout configuration")
	straight.free()

	var l_shaped := LShapedStairs3DScript.new() as Stairs3DScript
	for property_name in [&"turn_direction", &"flight_width"]:
		if !_has_editor_property(l_shaped, property_name):
			m_failures.append("LShapedStairs3D is missing layout property %s" % property_name)
	for property_name in [&"winder_turn", &"spiral_turn_degrees"]:
		if _has_editor_property(l_shaped, property_name):
			m_failures.append("LShapedStairs3D exposes unused property %s" % property_name)
	if !l_shaped.has_method(&"configure_turning_layout"):
		m_failures.append("LShapedStairs3D is missing turning-layout configuration")
	l_shaped.free()

	var winder := WinderStairs3DScript.new() as Stairs3DScript
	if !_has_editor_property(winder, &"winder_turn"):
		m_failures.append("WinderStairs3D is missing its winder turn property")
	if _has_editor_property(winder, &"spiral_turn_degrees"):
		m_failures.append("WinderStairs3D exposes the spiral turn property")
	if !winder.has_method(&"configure_winder_layout"):
		m_failures.append("WinderStairs3D is missing winder-layout configuration")
	if winder.has_method(&"configure_spiral_layout"):
		m_failures.append("WinderStairs3D exposes spiral-layout configuration")
	winder.free()

	var spiral := SpiralStairs3DScript.new() as Stairs3DScript
	if !_has_editor_property(spiral, &"spiral_turn_degrees"):
		m_failures.append("SpiralStairs3D is missing its spiral turn property")
	if _has_editor_property(spiral, &"winder_turn"):
		m_failures.append("SpiralStairs3D exposes the winder turn property")
	if !spiral.has_method(&"configure_spiral_layout"):
		m_failures.append("SpiralStairs3D is missing spiral-layout configuration")
	if spiral.has_method(&"configure_winder_layout"):
		m_failures.append("SpiralStairs3D exposes winder-layout configuration")
	if _has_editor_property(spiral, &"nosing_depth"):
		m_failures.append("SpiralStairs3D exposes unsupported nosing depth")
	for property: Dictionary in spiral.get_property_list():
		if StringName(property.get("name", &"")) != &"tread_style":
			continue
		if String(property.get("hint_string", "")) != "Closed,Open":
			m_failures.append("SpiralStairs3D exposes the unsupported Nosing tread style")
		break
	spiral.tread_style = Stairs3DScript.TreadStyle.NOSING
	if spiral.tread_style != Stairs3DScript.TreadStyle.CLOSED:
		m_failures.append("SpiralStairs3D retained unsupported Nosing state")
	spiral.free()

	var expected_style_type_count := 15
	var building_custom_types := BuildingFactoryScript.get_building_style_custom_types()
	var opening_custom_types := BuildingFactoryScript.get_opening_custom_types()
	if building_custom_types.size() != expected_style_type_count:
		m_failures.append("BuildingFactory concrete style registry has the wrong size")
	if opening_custom_types.size() != 15:
		m_failures.append("BuildingFactory concrete opening registry has the wrong size")
	for internal_script: Script in [
		BuildingMesh3DScript,
		Stairs3DScript,
		Pillar3DScript,
		Roof3DScript,
		BuildingOpening3DScript,
		Window3DScript,
		Door3DScript,
	]:
		if !internal_script.get_global_name().is_empty():
			m_failures.append(
				"Internal building base remains globally named: %s"
				% internal_script.resource_path
			)
	for custom_type: Dictionary in building_custom_types:
		var registered_script := custom_type.get("script") as Script
		if registered_script == null:
			m_failures.append("BuildingFactory style registry contains a missing script")
			continue
		var registered_node := registered_script.new() as Node
		if registered_node == null:
			m_failures.append(
				"BuildingFactory style registry contains a non-node script %s"
				% registered_script.resource_path
			)
			continue
		registered_node.free()
	for custom_type: Dictionary in opening_custom_types:
		var registered_script := custom_type.get("script") as Script
		var registered_opening := registered_script.new() as BuildingOpening3DScript
		if registered_opening == null:
			m_failures.append(
				"BuildingFactory opening registry contains an invalid script: %s"
				% custom_type.get("name", "")
			)
			continue
		registered_opening.free()


func _validate_door_opening_rules(wall: Wall3DScript) -> void:
	var door_center := Vector2(0.8, 1.05)
	var door_size := Vector2(0.9, 2.1)
	if wall.can_place_opening(door_center, door_size, 0.03, null, 0):
		m_failures.append("Wall3D allowed a floor-touching door without base-edge allowance")
	if !wall.can_place_opening(door_center, door_size, 0.03, null, 0, true):
		m_failures.append("Wall3D rejected a valid floor-touching door opening")

	var door := DoubleDoor3DScript.new() as Door3DScript
	door.name = "DoubleDoorOpening"
	door.opening_width = 1.6
	door.opening_height = 2.1
	add_child(door)
	if door.get_node_or_null("BottomFrame") != null:
		m_failures.append("BuildingOpening3D generated a bottom frame for a door frame")
	if door.get_node_or_null("LeftDoorPanel") == null or door.get_node_or_null("RightDoorPanel") == null:
		m_failures.append("BuildingOpening3D did not generate double door panels")


func _validate_window_style_visuals() -> void:
	var double_window := DoubleWindow3DScript.new() as Window3DScript
	double_window.name = "DoubleWindowOpening"
	double_window.opening_width = 1.8
	double_window.opening_height = 1.0
	add_child(double_window)
	if double_window.get_node_or_null("BottomFrame") == null:
		m_failures.append("BuildingOpening3D did not keep bottom frame for a window")
	if (
		double_window.get_node_or_null("LeftWindowPane") == null
		or double_window.get_node_or_null("RightWindowPane") == null
	):
		m_failures.append("BuildingOpening3D did not generate double window panes")

	var window_frame := WindowFrame3DScript.new() as Window3DScript
	window_frame.name = "WindowFrameOpening"
	add_child(window_frame)
	if window_frame.get_node_or_null("WindowPane") != null:
		m_failures.append("BuildingOpening3D generated panes for a frame-only window")


func _validate_new_opening_style_visuals() -> void:
	# Grid window: a single pane with muntin bars subdividing the glass.
	var grid_window := GridWindow3DScript.new() as Window3DScript
	grid_window.name = "GridWindowOpening"
	grid_window.opening_width = 1.0
	grid_window.opening_height = 1.2
	add_child(grid_window)
	if grid_window.get_node_or_null("WindowPane") == null:
		m_failures.append("BuildingOpening3D did not generate the grid window glass pane")
	if (
		grid_window.get_node_or_null("WindowPaneMuntinH0") == null
		or grid_window.get_node_or_null("WindowPaneMuntinV0") == null
	):
		m_failures.append("BuildingOpening3D did not generate grid window muntin bars")

	# Louvered window: tilted slats replace the flat glass pane.
	var louvered_window := LouveredWindow3DScript.new() as Window3DScript
	louvered_window.name = "LouveredWindowOpening"
	add_child(louvered_window)
	if louvered_window.get_node_or_null("WindowPaneSlat0") == null:
		m_failures.append("BuildingOpening3D did not generate louver slats")
	if louvered_window.get_node_or_null("WindowPane") != null:
		m_failures.append("BuildingOpening3D kept a flat pane on a louvered window")

	# Transom window: a horizontal rail splits an upper light from the glass.
	var transom_window := TransomWindow3DScript.new() as Window3DScript
	transom_window.name = "TransomWindowOpening"
	add_child(transom_window)
	if transom_window.get_node_or_null("WindowPaneTransomRail") == null:
		m_failures.append("BuildingOpening3D did not generate the transom rail")

	# Arched window: stepped corner fillers fake a low-poly arch top.
	var arched_window := ArchedWindow3DScript.new() as Window3DScript
	arched_window.name = "ArchedWindowOpening"
	arched_window.opening_width = 1.0
	arched_window.opening_height = 1.4
	add_child(arched_window)
	if (
		arched_window.get_node_or_null("WindowPaneArchL0") == null
		or arched_window.get_node_or_null("WindowPaneArchR0") == null
	):
		m_failures.append("BuildingOpening3D did not generate arched window corner fillers")

	# Glazed door: solid lower panel, a rail, and an upper glass lite.
	var glazed_door := GlazedDoor3DScript.new() as Door3DScript
	glazed_door.name = "GlazedDoorOpening"
	glazed_door.opening_width = 0.9
	glazed_door.opening_height = 2.1
	add_child(glazed_door)
	if (
		glazed_door.get_node_or_null("DoorPanelPanel") == null
		or glazed_door.get_node_or_null("DoorPanelGlass") == null
		or glazed_door.get_node_or_null("DoorPanelRail") == null
	):
		m_failures.append("BuildingOpening3D did not generate glazed door parts")

	# Cross glazed door: the glazed lite is divided by muntin bars.
	var cross_door := GlazedGridDoor3DScript.new() as Door3DScript
	cross_door.name = "CrossGlazedDoorOpening"
	cross_door.opening_width = 0.9
	cross_door.opening_height = 2.1
	add_child(cross_door)
	if (
		cross_door.get_node_or_null("DoorPanelGlassMuntinH0") == null
		or cross_door.get_node_or_null("DoorPanelGlassMuntinV0") == null
	):
		m_failures.append("BuildingOpening3D did not generate cross glazed door muntins")

	# Panel door: raised recessed-panel insets on the solid face.
	var panel_door := PanelDoor3DScript.new() as Door3DScript
	panel_door.name = "PanelDoorOpening"
	panel_door.opening_width = 0.9
	panel_door.opening_height = 2.1
	add_child(panel_door)
	if panel_door.get_node_or_null("DoorPanel") == null:
		m_failures.append("BuildingOpening3D did not generate the panel door face")
	if panel_door.get_node_or_null("DoorPanelInset0_0") == null:
		m_failures.append("BuildingOpening3D did not generate panel door insets")

	# Dutch door: the panel splits into two stacked leaves with a mid rail.
	var dutch_door := DutchDoor3DScript.new() as Door3DScript
	dutch_door.name = "DutchDoorOpening"
	dutch_door.opening_width = 0.9
	dutch_door.opening_height = 2.1
	add_child(dutch_door)
	if (
		dutch_door.get_node_or_null("DoorPanelLower") == null
		or dutch_door.get_node_or_null("DoorPanelUpper") == null
		or dutch_door.get_node_or_null("DoorPanelMidRail") == null
	):
		m_failures.append("BuildingOpening3D did not generate split Dutch door leaves")


func _validate_frame_sides() -> void:
	var thickness := 0.3
	var protrusion := 0.02
	var face_gap: float = BuildingOpening3DScript.FRAME_FACE_GAP

	# Default FRONT casing keeps the legacy single-sided depth.
	var front_opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	front_opening.name = "FrontFrameOpening"
	front_opening.frame_depth = thickness + 0.04
	front_opening.wall_thickness = thickness
	add_child(front_opening)
	var front_frame := front_opening.get_node_or_null("LeftFrame") as MeshInstance3D
	if front_frame == null:
		m_failures.append("BuildingOpening3D did not generate a frame for a front-sided opening")
	elif !is_equal_approx((front_frame.mesh as BoxMesh).size.z, thickness + 0.04):
		m_failures.append("Front-sided frame casing changed its legacy depth")

	# BOTH casing spans the wall and protrudes past both faces.
	var both_opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	both_opening.name = "BothFrameOpening"
	both_opening.frame_depth = thickness + 0.04
	both_opening.wall_thickness = thickness
	both_opening.frame_protrusion = protrusion
	both_opening.frame_sides = BuildingOpening3DScript.FrameSides.BOTH
	add_child(both_opening)
	var both_frame := both_opening.get_node_or_null("LeftFrame") as MeshInstance3D
	if both_frame == null:
		m_failures.append("BuildingOpening3D did not generate a frame for a both-sided opening")
		return
	var depth: float = (both_frame.mesh as BoxMesh).size.z
	var center_z := both_frame.position.z
	var front_extent := center_z + depth * 0.5
	var back_extent := center_z - depth * 0.5
	if front_extent <= -face_gap + 0.0001:
		m_failures.append("Both-sided frame casing does not protrude past the placed wall face")
	if back_extent >= -(thickness + face_gap) - 0.0001:
		m_failures.append("Both-sided frame casing does not protrude past the far wall face")


func _validate_opening_follows_wall_segment() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "OpeningFollowWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(4.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var branch := WallSegmentScript.new()
	branch.start_point = Vector3(2.0, 0.0, 0.0)
	branch.end_point = Vector3(2.0, 0.0, 2.0)
	branch.height = wall.wall_height
	branch.thickness = wall.wall_thickness
	branch.color = wall.wall_color
	var extras: Array[WallSegmentScript] = [branch]
	wall.extra_segments = extras

	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "FollowingOpening"
	opening.opening_width = 0.5
	opening.opening_height = 0.5
	var opening_anchor := Vector3(1.0, 1.1, wall.wall_thickness * 0.5 + 0.035)
	var old_frame := wall.get_segment_local_frame(1)
	wall.add_child(opening)
	opening.transform = Transform3D(old_frame.basis, old_frame * opening_anchor)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 1)
	wall.rebuild_wall_mesh()

	var old_position := opening.position
	if !wall.move_segment_endpoint(1, 1, Vector3(3.0, 0.0, 2.0)):
		m_failures.append("Wall3D could not move an opening-bearing segment endpoint")
		return
	var new_frame := wall.get_segment_local_frame(1)
	var local_after := new_frame.affine_inverse() * opening.position
	if local_after.distance_to(opening_anchor) > 0.001:
		m_failures.append("Window opening did not preserve its segment-local anchor after wall edit")
	var expected_position := new_frame * opening_anchor
	if opening.position.distance_to(expected_position) > 0.001:
		m_failures.append("Window opening did not follow the edited wall segment")
	if opening.position.distance_to(old_position) <= 0.001:
		m_failures.append("Window opening stayed in its old wall-local position after segment rotation")
	if wall.get_opening_segment_index(opening) != 1:
		m_failures.append("Window opening lost its segment assignment after wall edit")


func _validate_snapping(coordinator: Building3DScript) -> void:
	var snapped := BuildingFactoryScript.snap_local_position(Vector3(0.26, 0.0, 0.74), 0.5)
	if snapped != Vector3(0.5, 0.0, 0.5):
		m_failures.append("BuildingFactory grid snapping returned %s" % str(snapped))
	var constrained := BuildingFactoryScript.constrain_wall_end(
		Vector3.ZERO,
		Vector3(1.1, 0.0, 0.8),
		0.5,
		true
	)
	if !is_equal_approx(absf(constrained.x), absf(constrained.z)):
		m_failures.append("BuildingFactory did not constrain diagonal drawing to 45 degrees")


func _validate_wall_base_height(coordinator: Building3DScript) -> void:
	var base_y := 1.25
	var elevated := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(0.0, base_y, 8.0),
		Vector3(4.0, base_y, 8.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	coordinator.add_child(elevated)
	if absf(elevated.start_point.y - base_y) > 0.001 or absf(elevated.end_point.y - base_y) > 0.001:
		m_failures.append("Wall3D did not preserve elevated wall base endpoints")
	if absf(elevated.position.y - base_y) > 0.001:
		m_failures.append("Wall3D did not place wall transform at elevated base height")


func _validate_wall_collision_blocks_character(coordinator: Building3DScript) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "WallCollisionProbeFloor"
	floor_body.set_meta(&"test_generated", true)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.1, 8.0)
	floor_shape.shape = floor_box
	floor_shape.position = WALL_COLLISION_TEST_ORIGIN + Vector3(0.0, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var wall := BuildingFactoryScript.create_wall_node(coordinator,
		WALL_COLLISION_TEST_ORIGIN + Vector3(2.0, 0.0, -2.0),
		WALL_COLLISION_TEST_ORIGIN + Vector3(2.0, 0.0, 2.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	coordinator.add_child(wall)

	var collision_body := wall.get_node_or_null("WallCollision") as StaticBody3D
	if collision_body == null:
		m_failures.append("Wall3D did not generate solid collision for the character")
		floor_body.queue_free()
		return
	var collision_shape := collision_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or !(collision_shape.shape is BoxShape3D):
		m_failures.append("Wall3D solid character collision did not use a box blocker")
		floor_body.queue_free()
		return

	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		m_failures.append("Wall3D character collision probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		return
	probe.name = "WallCollisionHumanBody3DProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)
	await get_tree().physics_frame

	probe.global_position = WALL_COLLISION_TEST_ORIGIN + Vector3(0.0, 0.1, 0.0)
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var saw_wall_collision := false
	for i in range(WALL_COLLISION_PROBE_FRAMES):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.RIGHT, WALL_COLLISION_PROBE_SPEED)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= WALL_COLLISION_MAX_NORMAL_Y:
				saw_wall_collision = true
		await get_tree().physics_frame

	var probe_travel := start_position.distance_to(probe.global_position)
	if probe_travel > WALL_COLLISION_MAX_TRAVEL:
		m_failures.append("HumanBody3D moved through solid Wall3D collision by %.2f units" % probe_travel)
	if !saw_wall_collision:
		m_failures.append("HumanBody3D did not report a slide collision against Wall3D")

	probe.global_position = WALL_COLLISION_TEST_ORIGIN + Vector3(0.0, 0.1, -1.5)
	probe.velocity = Vector3.ZERO
	await get_tree().physics_frame
	for i in range(8):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var slide_start_position := probe.global_position
	var slide_direction := Vector3(1.0, 0.0, 1.0).normalized()
	var saw_slide_wall_collision := false
	var first_slide_contact_z := slide_start_position.z
	var max_parallel_after_contact := 0.0
	for i in range(WALL_COLLISION_SLIDE_FRAMES):
		probe.velocity.y = -0.5
		probe.move_with_speed(slide_direction, WALL_COLLISION_PROBE_SPEED)
		var frame_saw_wall_collision := false
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= WALL_COLLISION_MAX_NORMAL_Y:
				frame_saw_wall_collision = true
		if frame_saw_wall_collision:
			if !saw_slide_wall_collision:
				first_slide_contact_z = probe.global_position.z
			saw_slide_wall_collision = true
		if saw_slide_wall_collision:
			max_parallel_after_contact = maxf(
				max_parallel_after_contact,
				probe.global_position.z - first_slide_contact_z
			)
		await get_tree().physics_frame

	var slide_parallel_travel := probe.global_position.z - slide_start_position.z
	var slide_blocked_x := WALL_COLLISION_TEST_ORIGIN.x + WALL_COLLISION_MAX_TRAVEL
	if probe.global_position.x > slide_blocked_x:
		m_failures.append("HumanBody3D moved through Wall3D while sliding along it")
	if !saw_slide_wall_collision:
		m_failures.append("HumanBody3D did not report a diagonal slide collision against Wall3D")
	if slide_parallel_travel < WALL_COLLISION_SLIDE_MIN_TOTAL_PARALLEL_TRAVEL:
		m_failures.append("HumanBody3D only moved %.2f units parallel to Wall3D while sliding" % slide_parallel_travel)
	if max_parallel_after_contact < WALL_COLLISION_SLIDE_MIN_CONTACT_PARALLEL_TRAVEL:
		m_failures.append(
			"HumanBody3D only moved %.2f units parallel to Wall3D after contact"
			% max_parallel_after_contact
		)

	probe.queue_free()
	floor_body.queue_free()


func _validate_floor_node(coordinator: Building3DScript) -> void:
	var top_y := 1.25
	var floor := BuildingFactoryScript.create_floor_node(coordinator,
		Vector3(0.0, top_y, 12.0),
		Vector3(3.0, top_y, 14.0),
		0.18,
		Color(0.46, 0.40, 0.32, 1.0)
	)
	coordinator.add_child(floor)
	for property in floor.get_property_list():
		if StringName(property.get("name", "")) == &"floor_style":
			m_failures.append("Floor3D still exposes the removed floor_style property")
	if floor.mesh == null:
		m_failures.append("Floor3D did not generate a mesh")
		return
	if floor.mesh.get_surface_count() <= 0:
		m_failures.append("Floor3D mesh has no surfaces")
		return

	var size := floor.get_floor_size()
	if absf(size.x - 3.0) > 0.001 or absf(size.y - 2.0) > 0.001:
		m_failures.append("Floor3D returned the wrong footprint size: %s" % str(size))
	if floor.position.distance_to(Vector3(0.0, top_y, 12.0)) > 0.001:
		m_failures.append("Floor3D did not place its transform at the floor top corner")

	var arrays := floor.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("Floor3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("Floor3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Floor3D mesh is missing per-vertex color data")
	if !normals.is_empty() and normals[0].dot(Vector3.UP) < 0.999:
		m_failures.append("Floor3D top face normal is not upward")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Floor3D triangle winding does not match Godot BoxMesh convention")
	var min_y := INF
	var max_y := -INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	if absf(max_y) > 0.001 or absf(min_y + 0.18) > 0.001:
		m_failures.append("Floor3D did not extend thickness downward from the top surface")
	if floor.get_node_or_null("FloorCollision") == null:
		m_failures.append("Floor3D did not generate collision for placed floors")

	var floor_holes: Array[Rect2] = [Rect2(Vector2(1.0, 0.5), Vector2(1.0, 0.75))]
	if !floor.can_add_floor_hole_rect(floor_holes[0]):
		m_failures.append("Floor3D rejected a valid interior floor hole")
	floor.set_floor_holes(floor_holes)
	if floor.get_floor_holes().size() != 1:
		m_failures.append("Floor3D did not store a valid floor hole")
	var holed_mesh := floor.mesh as ArrayMesh
	if _has_horizontal_face_covering_plan_point(holed_mesh, Vector2(1.5, 0.9), 0.0):
		m_failures.append("Floor3D kept a top face over a floor hole")
	if !_has_horizontal_face_covering_plan_point(holed_mesh, Vector2(0.5, 0.3), 0.0):
		m_failures.append("Floor3D removed solid top floor geometry outside the hole")
	if !_has_mesh_vertex_with_normal_near(holed_mesh, Vector3(1.0, 0.0, 0.5), Vector3.RIGHT, 0.001):
		m_failures.append("Floor3D hole is missing its inner left side face")
	if !_has_mesh_vertex_with_normal_near(holed_mesh, Vector3(2.0, 0.0, 0.5), Vector3.LEFT, 0.001):
		m_failures.append("Floor3D hole is missing its inner right side face")
	var intersecting_hole := Rect2(Vector2(1.5, 0.75), Vector2(1.0, 0.75))
	if !floor.can_add_floor_hole_rect(intersecting_hole):
		m_failures.append("Floor3D rejected an intersecting mergeable floor hole")
	floor.set_floor_holes([floor_holes[0], intersecting_hole])
	var merged_holes := floor.get_floor_holes()
	if merged_holes.size() != 3:
		m_failures.append("Floor3D did not preserve merged floor hole shape")
	else:
		if !_has_rect_near(merged_holes, Rect2(Vector2(1.0, 0.5), Vector2(1.0, 0.25))):
			m_failures.append("Floor3D merged floor hole lost the lower-left run")
		if !_has_rect_near(merged_holes, Rect2(Vector2(1.0, 0.75), Vector2(1.5, 0.5))):
			m_failures.append("Floor3D merged floor hole lost the shared middle run")
		if !_has_rect_near(merged_holes, Rect2(Vector2(1.5, 1.25), Vector2(1.0, 0.25))):
			m_failures.append("Floor3D merged floor hole lost the upper-right run")
	var merged_mesh := floor.mesh as ArrayMesh
	if !_has_horizontal_face_covering_plan_point(merged_mesh, Vector2(2.25, 0.6), 0.0):
		m_failures.append("Floor3D overcut a solid corner while merging floor holes")
	if !_has_horizontal_face_covering_plan_point(merged_mesh, Vector2(1.25, 1.4), 0.0):
		m_failures.append("Floor3D overcut the opposite solid corner while merging floor holes")
	if _has_horizontal_face_covering_plan_point(merged_mesh, Vector2(2.25, 1.4), 0.0):
		m_failures.append("Floor3D kept a top face over a merged floor hole")
	if !_has_mesh_vertex_with_normal_near(merged_mesh, Vector3(2.5, 0.0, 0.75), Vector3.LEFT, 0.001):
		m_failures.append("Floor3D merged hole is missing its outer right side face")
	if (
		_has_vertical_face_covering_plan_edge_point(merged_mesh, Vector2(1.25, 0.75), Vector3.FORWARD)
		or _has_vertical_face_covering_plan_edge_point(merged_mesh, Vector2(1.25, 0.75), Vector3.BACK)
	):
		m_failures.append("Floor3D kept an internal side face between merged floor holes")
	if floor.can_add_floor_hole_rect(Rect2(Vector2(0.0, 0.5), Vector2(0.5, 0.5))):
		m_failures.append("Floor3D allowed a hole touching the outer floor edge")
	if !floor.floor_holes_fit_size(floor.get_floor_size()):
		m_failures.append("Floor3D reported its valid stored hole as outside the floor")
	if floor.floor_holes_fit_size(Vector2(1.5, 1.0)):
		m_failures.append("Floor3D did not detect a resize that would invalidate a stored hole")

	# A polygon hole may overlap a rect hole; the two merge into one opening just
	# like overlapping rect holes do.
	floor.set_floor_holes([Rect2(Vector2(1.0, 0.5), Vector2(0.75, 0.75))])
	var rect_overlap_poly := PackedVector2Array([
		Vector2(1.5, 0.5),
		Vector2(2.25, 0.5),
		Vector2(2.25, 1.25),
		Vector2(1.5, 1.25),
	])
	if !floor.can_add_floor_hole_polygon(rect_overlap_poly):
		m_failures.append("Floor3D rejected a polygon hole overlapping a rect hole")
	var mixed_polygon_holes: Array[PackedVector2Array] = [rect_overlap_poly]
	floor.set_floor_hole_polygons(mixed_polygon_holes)
	if floor.get_floor_hole_polygons().size() != 1:
		m_failures.append("Floor3D did not store a polygon hole overlapping a rect hole")
	var mixed_mesh := floor.mesh as ArrayMesh
	if _has_horizontal_face_covering_plan_point(mixed_mesh, Vector2(1.6, 0.8), 0.0):
		m_failures.append("Floor3D kept a top face over a merged rect and polygon hole")
	if _has_horizontal_face_covering_plan_point(mixed_mesh, Vector2(2.0, 0.8), 0.0):
		m_failures.append("Floor3D kept a top face over the polygon part of a merged hole")
	if !_has_horizontal_face_covering_plan_point(mixed_mesh, Vector2(2.7, 0.8), 0.0):
		m_failures.append("Floor3D overcut solid floor beside a merged rect and polygon hole")
	if (
		_has_vertical_face_covering_plan_edge_point(mixed_mesh, Vector2(1.75, 0.8), Vector3.RIGHT)
		or _has_vertical_face_covering_plan_edge_point(mixed_mesh, Vector2(1.75, 0.8), Vector3.LEFT)
		or _has_vertical_face_covering_plan_edge_point(mixed_mesh, Vector2(1.5, 0.8), Vector3.RIGHT)
		or _has_vertical_face_covering_plan_edge_point(mixed_mesh, Vector2(1.5, 0.8), Vector3.LEFT)
	):
		m_failures.append("Floor3D kept a stray internal wall where a rect and polygon hole merge")
	if !_has_vertical_face_covering_plan_edge_point(mixed_mesh, Vector2(1.0, 0.8), Vector3.RIGHT):
		m_failures.append("Floor3D merged rect and polygon hole lost its outer left wall")
	if !_has_vertical_face_covering_plan_edge_point(mixed_mesh, Vector2(2.25, 0.8), Vector3.LEFT):
		m_failures.append("Floor3D merged rect and polygon hole lost its outer right wall")
	var cleared_rect_holes: Array[Rect2] = []
	floor.set_floor_holes(cleared_rect_holes)
	var cleared_polygon_holes: Array[PackedVector2Array] = []
	floor.set_floor_hole_polygons(cleared_polygon_holes)

	floor.set_floor_corners(Vector3(1.0, top_y, 12.5), Vector3(4.5, top_y, 15.0))
	var edited_size := floor.get_floor_size()
	if absf(edited_size.x - 3.5) > 0.001 or absf(edited_size.y - 2.5) > 0.001:
		m_failures.append("Floor3D did not resize from edited corners: %s" % str(edited_size))
	if floor.position.distance_to(Vector3(1.0, top_y, 12.5)) > 0.001:
		m_failures.append("Floor3D did not move transform after edited corners")

	var editable_rectangle := BuildingFactoryScript.create_floor_node(
		coordinator,
		Vector3(12.0, top_y, 12.0),
		Vector3(15.0, top_y, 14.0)
	)
	coordinator.add_child(editable_rectangle)
	var editable_rectangle_points := PackedVector3Array([
		Vector3(12.0, top_y, 12.0),
		Vector3(15.0, top_y, 12.0),
		Vector3(16.0, top_y, 15.0),
		Vector3(12.0, top_y, 14.0),
	])
	editable_rectangle.set_floor_polygon(editable_rectangle_points)
	if !editable_rectangle.is_polygon_floor():
		m_failures.append("Floor3D rectangle shape edit did not convert to shared polygon editing")
	if editable_rectangle.get_floor_polygon() != editable_rectangle_points:
		m_failures.append("Floor3D rectangle shape edit did not preserve its four edited vertices")

	var polygon_points := PackedVector3Array([
		Vector3(6.0, top_y, 12.0),
		Vector3(10.0, top_y, 12.0),
		Vector3(10.0, top_y, 13.0),
		Vector3(8.0, top_y, 13.0),
		Vector3(8.0, top_y, 15.0),
		Vector3(6.0, top_y, 15.0),
	])
	var polygon_floor := BuildingFactoryScript.create_floor_polygon_node(
		coordinator,
		polygon_points,
		0.2,
		Color(0.42, 0.38, 0.30, 1.0)
	)
	coordinator.add_child(polygon_floor)
	if !polygon_floor.is_polygon_floor():
		m_failures.append("Floor3D polygon factory did not preserve the polygon style")
	if polygon_floor.get_floor_polygon() != polygon_points:
		m_failures.append("Floor3D polygon factory did not preserve authored vertices")
	if polygon_floor.position.distance_to(Vector3(6.0, top_y, 12.0)) > 0.001:
		m_failures.append("Floor3D polygon transform did not use its minimum footprint corner")
	if polygon_floor.get_floor_size().distance_to(Vector2(4.0, 3.0)) > 0.001:
		m_failures.append("Floor3D polygon returned the wrong footprint bounds")
	if absf(polygon_floor.get_floor_area() - 8.0) > 0.001:
		m_failures.append("Floor3D polygon returned the wrong concave footprint area")
	if !polygon_floor.contains_local_plan_point(Vector2(1.0, 2.0)):
		m_failures.append("Floor3D polygon picking rejected a solid footprint point")
	if polygon_floor.contains_local_plan_point(Vector2(3.0, 2.0)):
		m_failures.append("Floor3D polygon picking accepted a point inside the concave notch")
	if polygon_floor.mesh == null or polygon_floor.mesh.get_surface_count() == 0:
		m_failures.append("Floor3D polygon did not generate a mesh")
	else:
		var polygon_mesh := polygon_floor.mesh as ArrayMesh
		var polygon_arrays := polygon_mesh.surface_get_arrays(0)
		var polygon_vertices: PackedVector3Array = polygon_arrays[Mesh.ARRAY_VERTEX]
		var polygon_normals: PackedVector3Array = polygon_arrays[Mesh.ARRAY_NORMAL]
		var polygon_indices: PackedInt32Array = polygon_arrays[Mesh.ARRAY_INDEX]
		if !polygon_normals.is_empty() and polygon_normals[0].dot(Vector3.UP) < 0.999:
			m_failures.append("Floor3D polygon top face normal is not upward")
		if polygon_indices.size() >= 3:
			var polygon_a := polygon_vertices[polygon_indices[0]]
			var polygon_b := polygon_vertices[polygon_indices[1]]
			var polygon_c := polygon_vertices[polygon_indices[2]]
			var polygon_winding := (polygon_b - polygon_a).cross(polygon_c - polygon_a).normalized()
			if polygon_winding.dot(polygon_normals[polygon_indices[0]]) > -0.999:
				m_failures.append("Floor3D polygon winding does not match the mesh convention")
		if !_has_horizontal_face_covering_plan_point(polygon_mesh, Vector2(1.0, 2.0), 0.0):
			m_failures.append("Floor3D polygon lost a solid concave-footprint region")
		if _has_horizontal_face_covering_plan_point(polygon_mesh, Vector2(3.0, 2.0), 0.0):
			m_failures.append("Floor3D polygon filled its concave footprint notch")
	if polygon_floor.get_node_or_null("FloorCollision") == null:
		m_failures.append("Floor3D polygon did not generate collision")
	var polygon_hole := PackedVector2Array([
		Vector2(0.5, 0.75),
		Vector2(1.75, 0.75),
		Vector2(1.1, 2.0),
	])
	if !polygon_floor.can_add_floor_hole_polygon(polygon_hole):
		m_failures.append("Floor3D polygon rejected a valid polygon hole")
	else:
		var polygon_holes: Array[PackedVector2Array] = [polygon_hole]
		polygon_floor.set_floor_hole_polygons(polygon_holes)
		if polygon_floor.get_floor_hole_polygons().size() != 1:
			m_failures.append("Floor3D did not store a polygon hole")
		var polygon_hole_mesh := polygon_floor.mesh as ArrayMesh
		if _has_horizontal_face_covering_plan_point(polygon_hole_mesh, Vector2(1.1, 1.1), 0.0):
			m_failures.append("Floor3D kept a top face over a polygon hole")
		if !_has_horizontal_face_covering_plan_point(polygon_hole_mesh, Vector2(0.25, 0.25), 0.0):
			m_failures.append("Floor3D polygon hole removed solid floor outside its outline")
		if !polygon_floor.has_floor_hole_at_local_point(Vector2(1.1, 1.1)):
			m_failures.append("Floor3D polygon hole picking missed its interior")
		var inserted_hole := polygon_hole.duplicate()
		inserted_hole.insert(1, Vector2(1.125, 0.75))
		if !polygon_floor.can_set_floor_hole_polygon(0, inserted_hole):
			m_failures.append("Floor3D polygon hole rejected an inserted edge vertex")
		else:
			var edited_holes: Array[PackedVector2Array] = [inserted_hole]
			polygon_floor.set_floor_hole_polygons(edited_holes)
			var reshaped_hole := inserted_hole.duplicate()
			reshaped_hole[1] = Vector2(1.125, 0.5)
			if !polygon_floor.can_set_floor_hole_polygon(0, reshaped_hole):
				m_failures.append("Floor3D polygon hole rejected a dragged vertex")
			else:
				edited_holes[0] = reshaped_hole
				polygon_floor.set_floor_hole_polygons(edited_holes)
				if polygon_floor.get_floor_hole_polygons()[0][1].distance_to(Vector2(1.125, 0.5)) > 0.001:
					m_failures.append("Floor3D polygon hole did not preserve its edited vertex")
	var adjacent_hole_a := PackedVector2Array([
		Vector2(0.5, 0.5),
		Vector2(1.0, 0.5),
		Vector2(1.0, 2.0),
		Vector2(0.5, 2.0),
	])
	var adjacent_hole_b := PackedVector2Array([
		Vector2(1.0, 0.5),
		Vector2(1.5, 0.5),
		Vector2(1.5, 2.0),
		Vector2(1.0, 2.0),
	])
	var adjacent_holes: Array[PackedVector2Array] = [adjacent_hole_a, adjacent_hole_b]
	polygon_floor.set_floor_hole_polygons(adjacent_holes)
	if polygon_floor.get_floor_hole_polygons().size() != 2:
		m_failures.append("Floor3D did not store two adjacent polygon holes")
	var adjacent_hole_mesh := polygon_floor.mesh as ArrayMesh
	if _has_horizontal_face_covering_plan_point(adjacent_hole_mesh, Vector2(0.75, 1.25), 0.0):
		m_failures.append("Floor3D kept a top face over a merged polygon hole")
	if _has_horizontal_face_covering_plan_point(adjacent_hole_mesh, Vector2(1.25, 1.25), 0.0):
		m_failures.append("Floor3D kept a top face over the second merged polygon hole")
	if (
		_has_vertical_face_covering_plan_edge_point(adjacent_hole_mesh, Vector2(1.0, 1.25), Vector3.RIGHT)
		or _has_vertical_face_covering_plan_edge_point(adjacent_hole_mesh, Vector2(1.0, 1.25), Vector3.LEFT)
	):
		m_failures.append("Floor3D kept a stray internal wall between merged polygon holes")
	if !_has_vertical_face_covering_plan_edge_point(adjacent_hole_mesh, Vector2(0.5, 1.25), Vector3.RIGHT):
		m_failures.append("Floor3D merged polygon hole lost its outer left wall")
	if !_has_vertical_face_covering_plan_edge_point(adjacent_hole_mesh, Vector2(1.5, 1.25), Vector3.LEFT):
		m_failures.append("Floor3D merged polygon hole lost its outer right wall")
	var cleared_holes: Array[PackedVector2Array] = []
	polygon_floor.set_floor_hole_polygons(cleared_holes)
	var inserted_polygon_points := PackedVector3Array()
	for point_index in range(polygon_points.size()):
		inserted_polygon_points.append(polygon_points[point_index])
		if point_index == 0:
			inserted_polygon_points.append(Vector3(8.0, top_y, 12.0))
	polygon_floor.set_floor_polygon(inserted_polygon_points)
	if polygon_floor.get_floor_polygon().size() != polygon_points.size() + 1:
		m_failures.append("Floor3D polygon did not preserve an inserted edge vertex")
	if absf(polygon_floor.get_floor_area() - 8.0) > 0.001:
		m_failures.append("Floor3D polygon edge insertion changed the footprint area")
	var reshaped_polygon_points := polygon_floor.get_floor_polygon()
	reshaped_polygon_points[1] = Vector3(8.0, top_y, 11.0)
	if !polygon_floor.is_floor_polygon_valid(reshaped_polygon_points):
		m_failures.append("Floor3D polygon rejected a valid dragged vertex shape")
	else:
		polygon_floor.set_floor_polygon(reshaped_polygon_points)
		if absf(polygon_floor.get_floor_area() - 10.0) > 0.001:
			m_failures.append("Floor3D polygon vertex drag did not reshape the footprint")
	var removed_polygon_points := PackedVector3Array()
	for point_index in range(reshaped_polygon_points.size()):
		if point_index != 1:
			removed_polygon_points.append(reshaped_polygon_points[point_index])
	if !polygon_floor.is_floor_polygon_valid(removed_polygon_points):
		m_failures.append("Floor3D polygon rejected a valid vertex removal")
	else:
		polygon_floor.set_floor_polygon(removed_polygon_points)
		if polygon_floor.get_floor_polygon().size() != polygon_points.size():
			m_failures.append("Floor3D polygon did not remove the selected vertex")
	var edge_dragged_polygon_points := polygon_floor.get_floor_polygon()
	edge_dragged_polygon_points[0] += Vector3(0.0, 0.0, -1.0)
	edge_dragged_polygon_points[1] += Vector3(0.0, 0.0, -1.0)
	if !polygon_floor.is_floor_polygon_valid(edge_dragged_polygon_points):
		m_failures.append("Floor3D polygon rejected a valid dragged edge shape")
	else:
		polygon_floor.set_floor_polygon(edge_dragged_polygon_points)
		if absf(polygon_floor.get_floor_area() - 12.0) > 0.001:
			m_failures.append("Floor3D polygon edge drag did not reshape the footprint")
	var self_intersecting_polygon := PackedVector3Array([
		Vector3(0.0, top_y, 0.0),
		Vector3(2.0, top_y, 2.0),
		Vector3(0.0, top_y, 2.0),
		Vector3(2.0, top_y, 0.0),
	])
	if polygon_floor.is_floor_polygon_valid(self_intersecting_polygon):
		m_failures.append("Floor3D accepted a self-intersecting polygon")


func _validate_stairs_node(coordinator: Building3DScript) -> void:
	var base_y := 0.75
	var stairs := BuildingFactoryScript.create_stairs_node(coordinator,
		Vector3(0.0, base_y, 16.0),
		Vector3(3.0, base_y, 20.0),
		{
			"height": 1.2,
			"step_count": 4,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
		}
	)
	coordinator.add_child(stairs)
	if stairs.mesh == null:
		m_failures.append("Stairs3D did not generate a mesh")
		return
	if stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Stairs3D mesh has no surfaces")
		return

	var size := stairs.get_stair_size()
	if absf(size.x - 3.0) > 0.001 or absf(size.y - 4.0) > 0.001:
		m_failures.append("Stairs3D returned the wrong footprint size: %s" % str(size))
	if stairs.position.distance_to(Vector3(0.0, base_y, 16.0)) > 0.001:
		m_failures.append("Stairs3D did not place its transform at the lower footprint corner")
	if absf(stairs.get_step_rise() - 0.3) > 0.001:
		m_failures.append("Stairs3D calculated the wrong step rise")
	if absf(stairs.get_step_run() - 1.0) > 0.001:
		m_failures.append("Stairs3D calculated the wrong step run")

	var arrays := stairs.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("Stairs3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("Stairs3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Stairs3D mesh is missing per-vertex color data")
	if _mesh_vertex_count(stairs) != 66:
		m_failures.append("Stairs3D generated the wrong stepped vertex count")
	if !_has_normal_near(normals, Vector3.UP):
		m_failures.append("Stairs3D mesh is missing tread normals")
	if !_has_normal_near(normals, Vector3.FORWARD):
		m_failures.append("Stairs3D mesh is missing riser normals")
	if !_has_normal_near(normals, Vector3.LEFT) or !_has_normal_near(normals, Vector3.RIGHT):
		m_failures.append("Stairs3D mesh is missing side normals")
	var side_triangle_count := 0
	var side_triangle_crosses_treads := false
	for triangle_start in range(0, indices.size(), 3):
		var first_index := indices[triangle_start]
		if absf(normals[first_index].x) < 0.999:
			continue
		side_triangle_count += 1
		var first_z := vertices[first_index].z
		var second_z := vertices[indices[triangle_start + 1]].z
		var third_z := vertices[indices[triangle_start + 2]].z
		var triangle_run := (
			maxf(first_z, maxf(second_z, third_z))
			- minf(first_z, minf(second_z, third_z))
		)
		if triangle_run > stairs.get_step_run() + 0.001:
			side_triangle_crosses_treads = true
	if side_triangle_count != stairs.step_count * 4:
		m_failures.append("Stairs3D sides did not generate two triangles per tread strip")
	if side_triangle_crosses_treads:
		m_failures.append("Stairs3D side triangulation retained long cross-tread triangles")
	if _has_normal_near(normals, Vector3.DOWN):
		m_failures.append("Stairs3D mesh retained its hidden underside face")
	if !_has_mesh_vertex_y_near(stairs, 1.2, 0.001):
		m_failures.append("Stairs3D mesh did not reach the configured stair height")
	if !_has_mesh_vertex_y_near(stairs, -0.16, 0.001):
		m_failures.append("Stairs3D mesh did not extend underside thickness downward")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Stairs3D triangle winding does not match Godot BoxMesh convention")
	# The riser is the second quad appended per step (indices 6..11 for the
	# first step), right after the tread's UP-facing quad (indices 0..5).
	# Its winding must independently match the same convention so the riser
	# actually renders forward-facing instead of being backface-culled.
	if indices.size() >= 12 and normals.size() > indices[6]:
		var riser_a := vertices[indices[6]]
		var riser_b := vertices[indices[7]]
		var riser_c := vertices[indices[8]]
		var riser_winding_normal := (riser_b - riser_a).cross(riser_c - riser_a).normalized()
		if riser_winding_normal.dot(normals[indices[6]]) > -0.999:
			m_failures.append("Stairs3D riser triangle winding does not face forward")
		if !normals[indices[6]].is_equal_approx(Vector3.FORWARD):
			m_failures.append("Stairs3D riser normal is not Vector3.FORWARD")
	if stairs.get_node_or_null("StairsCollision") == null:
		m_failures.append("Stairs3D did not generate collision for placed stairs")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate left side-wall collision")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate right side-wall collision")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s_4" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate stepped left side-wall collision")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s_4" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate stepped right side-wall collision")
	var first_side_box := _box_collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME
	)
	var first_left_side_shape := _collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME
	)
	var first_right_side_box := _box_collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME
	)
	var first_right_side_shape := _collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME
	)
	var last_side_box := _box_collision_shape(
		stairs,
		"StairsCollision/%s_4" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME
	)
	if first_side_box != null:
		var expected_first_side_height := stairs.get_step_rise() + maxf(stairs.stair_thickness, 0.0)
		if absf(first_side_box.size.y - expected_first_side_height) > 0.001:
			m_failures.append("Stairs3D first side-wall collision does not follow first step height")
		if absf(first_side_box.size.z - stairs.get_step_run()) > 0.001:
			m_failures.append("Stairs3D first side-wall collision does not follow first step run")
	if first_side_box != null and first_left_side_shape != null:
		var left_side_outer_x := first_left_side_shape.position.x - first_side_box.size.x * 0.5
		if absf(left_side_outer_x) > 0.001:
			m_failures.append("Stairs3D left side-wall collision extends outside the stair footprint")
	if first_right_side_box != null and first_right_side_shape != null:
		var right_side_outer_x := first_right_side_shape.position.x + first_right_side_box.size.x * 0.5
		if absf(right_side_outer_x - size.x) > 0.001:
			m_failures.append("Stairs3D right side-wall collision extends outside the stair footprint")
	if last_side_box != null:
		var expected_last_side_height := maxf(stairs.stair_height, 0.05) + maxf(stairs.stair_thickness, 0.0)
		if absf(last_side_box.size.y - expected_last_side_height) > 0.001:
			m_failures.append("Stairs3D final side-wall collision does not follow top step height")
		if absf(last_side_box.size.z - stairs.get_step_run()) > 0.001:
			m_failures.append("Stairs3D final side-wall collision does not follow final step run")

	stairs.set_stair_corners(Vector3(1.0, base_y, 16.5), Vector3(4.5, base_y, 21.0))
	var edited_size := stairs.get_stair_size()
	if absf(edited_size.x - 3.5) > 0.001 or absf(edited_size.y - 4.5) > 0.001:
		m_failures.append("Stairs3D did not resize from edited corners: %s" % str(edited_size))
	if stairs.position.distance_to(Vector3(1.0, base_y, 16.5)) > 0.001:
		m_failures.append("Stairs3D did not move transform after edited corners")
	var old_stair_center := stairs.get_stair_center_point()
	stairs.set_stair_rotation_around_center(90.0)
	if absf(angle_difference(deg_to_rad(stairs.stair_rotation_degrees), deg_to_rad(90.0))) > deg_to_rad(0.5):
		m_failures.append("Stairs3D did not store edited stair rotation")
	if stairs.get_stair_center_point().distance_to(old_stair_center) > 0.001:
		m_failures.append("Stairs3D did not preserve footprint center when rotating")
	if stairs.transform.basis.is_equal_approx(Basis.IDENTITY):
		m_failures.append("Stairs3D did not apply rotation to its transform")


func _validate_spiral_stairs(coordinator: Building3DScript) -> void:
	var spiral := BuildingFactoryScript.create_stairs_node(
		coordinator,
		Vector3(6.0, 0.75, 16.0),
		Vector3(10.0, 0.75, 20.0),
		{
			"height": 3.0,
			"step_count": 12,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
			"infill_style": StandardRailGeometryScript.RailStyle.VERTICAL,
			"layout_script": SpiralStairs3DScript,
			"turn_direction": TurningStairs3DScript.TurnDirection.RIGHT,
			"flight_width": 1.25,
			"spiral_turn_degrees": 360.0,
		}
	) as SpiralStairs3DScript
	coordinator.add_child(spiral)
	if (
		spiral.get_script() != SpiralStairs3DScript
			or absf(spiral.spiral_turn_degrees - 360.0) > 0.001
			or absf(spiral.flight_width - 1.25) > 0.001
	):
		m_failures.append("BuildingFactory did not apply the spiral stair settings")
	if spiral.mesh == null or spiral.mesh.get_surface_count() <= 0:
		m_failures.append("Spiral Stairs3D did not generate a mesh")
		return
	var plan := spiral._build_layout_plan(4.0, 4.0)
	var segments: Array = plan["segments"]
	if (
		segments.size() != 1
			or int(segments[0]["kind"])
				!= Stairs3DScript.SegmentKind.SEGMENT_LAYOUT_SPECIFIC
		or int(plan["total_steps"]) != 12
		or absf(float(plan["rise"]) - 0.25) > 0.001
	):
		m_failures.append("Spiral Stairs3D generated the wrong radial segment plan")
	else:
		var segment: Dictionary = segments[0]
		if (
			Vector2(segment["center"]).distance_to(Vector2(2.0, 2.0)) > 0.001
			or absf(float(segment["outer_radius"]) - 2.0) > 0.001
			or absf(float(segment["inner_radius"]) - 0.75) > 0.001
		):
			m_failures.append("Spiral Stairs3D did not fit its column and treads to the footprint")
		var quarter_point := (
			Vector2(segment["center"])
			+ spiral._radial_direction(PI * 0.5, float(segment["turn_sign"]))
			* float(segment["outer_radius"])
		)
		if quarter_point.distance_to(Vector2(4.0, 2.0)) > 0.001:
			m_failures.append("Right-turn Spiral Stairs3D wound in the wrong direction")
	if !_has_mesh_vertex_y_near(spiral, 3.0, 0.001):
		m_failures.append("Spiral Stairs3D did not reach the configured height")
	if !_has_mesh_vertex_y_near(spiral, -0.16, 0.001):
		m_failures.append("Spiral Stairs3D did not preserve the tread underside thickness")
	var arrays := spiral.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or normals.size() != vertices.size():
		m_failures.append("Spiral Stairs3D is missing mesh vertex or normal data")
	for triangle_start in range(0, indices.size(), 3):
		var a := vertices[indices[triangle_start]]
		var b := vertices[indices[triangle_start + 1]]
		var c := vertices[indices[triangle_start + 2]]
		var winding_normal := (b - a).cross(c - a)
		if winding_normal.length_squared() <= 0.000001:
			m_failures.append("Spiral Stairs3D generated a degenerate triangle")
			break
		if winding_normal.normalized().dot(normals[indices[triangle_start]]) > -0.999:
			m_failures.append("Spiral Stairs3D triangle winding does not match its normal")
			break
	if !_has_box_collision_shape(
		spiral,
		"StairsCollision/LayoutSideCollisionShape3D_12"
	):
		m_failures.append("Spiral Stairs3D did not generate one outer collision blocker per tread")

	var base_vertex_count := _mesh_vertex_count(spiral)
	spiral.lower_newel_enabled = true
	spiral.lower_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	spiral.upper_newel_enabled = true
	spiral.upper_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	spiral.middle_newel_post_count = 4
	spiral.infill_count_between_newels = 2
	spiral.rail_newel_post_thickness = 0.14
	spiral.infill_rail_thickness = 0.06
	spiral.left_rail_enabled = true
	spiral.right_rail_enabled = true
	spiral.rebuild_stairs_mesh()
	if _mesh_vertex_count(spiral) <= base_vertex_count:
		m_failures.append("Spiral Stairs3D did not append its outer rail geometry")
	var newel_plan := spiral._build_layout_plan(4.0, 4.0)
	var spiral_path_runs: Array = newel_plan["rail_runs"]
	var spiral_rail: Dictionary = newel_plan["spiral_rail"]
	var member_extents: Vector2 = spiral._helical_rail_member_extents(spiral_rail)
	var post_layout: Dictionary = spiral_rail["post_layout"]
	var smooth_samples := spiral._helical_rail_sample_positions(
		spiral_rail,
		member_extents.x,
		member_extents.y,
		float(post_layout["lower_horizontal_end"]),
		float(post_layout["upper_horizontal_start"])
	)
	if (
		!spiral_path_runs.is_empty()
		or newel_plan.has("rail_joints")
		or smooth_samples.size() <= int(newel_plan["total_steps"]) + 1
	):
		m_failures.append(
			"Spiral Stairs3D did not replace chord joints with one smooth sampled rail"
		)
	var vertical_rail_vertices := _spiral_rail_vertex_count(
		spiral,
		spiral_rail,
		StandardRailGeometryScript.RailStyle.VERTICAL
	)
	var horizontal_rail_vertices := _spiral_rail_vertex_count(
		spiral,
		spiral_rail,
		StandardRailGeometryScript.RailStyle.HORIZONTAL
	)
	var glass_rail_vertices := _spiral_rail_vertex_count(
		spiral,
		spiral_rail,
		StandardRailGeometryScript.RailStyle.GLASS_PANEL
	)
	spiral.infill_style = StandardRailGeometryScript.RailStyle.VERTICAL
	if (
		vertical_rail_vertices <= 0
		or glass_rail_vertices <= vertical_rail_vertices
		or horizontal_rail_vertices <= glass_rail_vertices
	):
		m_failures.append(
			"Spiral Stairs3D smooth sweep did not cover every continuous rail style"
		)
	var spiral_path_length: float = spiral_rail["length"]
	var expected_layout := spiral._build_rail_post_layout(
		spiral_path_length,
		spiral.stair_height,
		int(newel_plan["total_steps"]),
		spiral.lower_newel_enabled,
		spiral.upper_newel_enabled,
		spiral.middle_newel_post_count,
		spiral.lower_newel_placement,
		spiral.upper_newel_placement
	)
	var projected_positions: PackedFloat32Array = post_layout["positions"]
	var expected_positions: PackedFloat32Array = expected_layout["positions"]
	var projected_bases: PackedFloat32Array = post_layout["base_heights"]
	var expected_bases: PackedFloat32Array = expected_layout["base_heights"]
	var projected_thicknesses: PackedFloat32Array = post_layout["thicknesses"]
	var expected_thicknesses: PackedFloat32Array = expected_layout["thicknesses"]
	var projected_tops: PackedFloat32Array = post_layout["top_heights"]
	var expected_tops: PackedFloat32Array = expected_layout["top_heights"]
	var projected_flags: PackedByteArray = post_layout["newel_flags"]
	var expected_flags: PackedByteArray = expected_layout["newel_flags"]
	var projection_matches := (
		projected_positions.size() == expected_positions.size()
		and projected_bases.size() == expected_bases.size()
		and projected_thicknesses.size() == expected_thicknesses.size()
		and projected_tops.size() == expected_tops.size()
		and projected_flags == expected_flags
	)
	if projection_matches:
		for post_index in range(expected_positions.size()):
			var projected_top := projected_tops[post_index]
			var expected_top := expected_tops[post_index]
			var tops_match := (
				is_nan(projected_top) and is_nan(expected_top)
			) or absf(projected_top - expected_top) <= 0.001
			if (
				absf(projected_positions[post_index] - expected_positions[post_index]) > 0.001
				or absf(projected_bases[post_index] - expected_bases[post_index]) > 0.001
				or absf(
					projected_thicknesses[post_index]
					- expected_thicknesses[post_index]
				) > 0.001
				or !tops_match
			):
				projection_matches = false
				break
	if !projection_matches:
		m_failures.append("Spiral Stairs3D did not project the shared newel layout onto its rail")
	var projected_newel_count := 0
	for flag in projected_flags:
		if flag != 0:
			projected_newel_count += 1
	if (
		projected_newel_count != 4
		or projected_positions.is_empty()
		or projected_positions[0] >= 0.0
		or projected_positions[projected_positions.size() - 1] >= spiral_path_length
	):
		m_failures.append(
			"Spiral Stairs3D did not preserve floor/tread terminals and total newel count"
		)
	for post_index in range(1, projected_flags.size()):
		if projected_flags[post_index] == 0:
			continue
		var previous_newel := post_index - 1
		while previous_newel >= 0 and projected_flags[previous_newel] == 0:
			previous_newel -= 1
		if previous_newel >= 0 and post_index - previous_newel - 1 != 2:
			m_failures.append("Spiral Stairs3D did not keep the exact infill count per newel span")
			break
	spiral.lower_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	spiral.upper_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	var opposite_terminal_plan := spiral._build_layout_plan(4.0, 4.0)
	var opposite_rail: Dictionary = opposite_terminal_plan["spiral_rail"]
	var opposite_terminal_layout: Dictionary = opposite_rail["post_layout"]
	var opposite_positions: PackedFloat32Array = opposite_terminal_layout["positions"]
	var opposite_path_length: float = opposite_rail["length"]
	if (
		opposite_positions.is_empty()
		or opposite_positions[0] <= 0.0
		or opposite_positions[opposite_positions.size() - 1] <= opposite_path_length
	):
		m_failures.append("Spiral Stairs3D did not preserve tread/floor terminal placement")

	spiral.configure_spiral_layout(
		TurningStairs3DScript.TurnDirection.LEFT,
		spiral.flight_width,
		spiral.spiral_turn_degrees
	)
	spiral.rebuild_stairs_mesh()
	var left_plan := spiral._build_layout_plan(4.0, 4.0)
	var left_segment: Dictionary = left_plan["segments"][0]
	var left_quarter_point := (
		Vector2(left_segment["center"])
		+ spiral._radial_direction(PI * 0.5, float(left_segment["turn_sign"]))
		* float(left_segment["outer_radius"])
	)
	if left_quarter_point.distance_to(Vector2(0.0, 2.0)) > 0.001:
		m_failures.append("Left-turn Spiral Stairs3D did not mirror its winding direction")

	spiral.step_count = 4
	spiral.configure_spiral_layout(
		spiral.turn_direction,
		spiral.flight_width,
		1080.0
	)
	spiral.rebuild_stairs_mesh()
	var dense_plan := spiral._build_layout_plan(4.0, 4.0)
	if (
		int(dense_plan["total_steps"]) != 24
		or absf(spiral.get_step_rise() - 0.125) > 0.001
	):
		m_failures.append("Spiral Stairs3D did not cap sparse tread angles at 45 degrees")


func _spiral_rail_vertex_count(
	stairs: SpiralStairs3DScript,
	spiral_rail: Dictionary,
	style: int
) -> int:
	stairs.infill_style = style
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	stairs._append_helical_rail_primitive(
		spiral_rail,
		vertices,
		normals,
		colors,
		indices
	)
	return vertices.size()


func _create_tread_style_stairs(
	coordinator: Building3DScript,
	anchor: Vector3,
	layout_script: Script,
	tread_style: int,
	nosing_depth: float
) -> Stairs3DScript:
	return BuildingFactoryScript.create_stairs_node(
		coordinator,
		anchor,
		anchor + Vector3(2.0, 0.0, 4.0),
		{
			"height": 1.2,
			"step_count": 6,
			"thickness": 0.12,
			"color": Color(0.52, 0.46, 0.38, 1.0),
			"layout_script": layout_script,
			"tread_style": tread_style,
			"nosing_depth": nosing_depth,
		}
	)


func _validate_stair_tread_styles(coordinator: Building3DScript) -> void:
	# Height 1.2 over 6 steps: rise 0.2; thickness 0.12 is both the closed
	# underside depth and the open/nosing slab thickness.
	var open_stairs := _create_tread_style_stairs(
		coordinator,
		Vector3(40.0, 0.0, 16.0),
		StraightStairs3DScript,
		Stairs3DScript.TreadStyle.OPEN,
		0.0
	)
	coordinator.add_child(open_stairs)
	if open_stairs.tread_style != Stairs3DScript.TreadStyle.OPEN:
		m_failures.append("BuildingFactory did not apply the open tread style")
	if open_stairs.mesh == null or open_stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Open-tread Stairs3D did not generate a mesh")
	else:
		if !_has_mesh_vertex_y_near(open_stairs, 1.2, 0.001):
			m_failures.append("Open-tread Stairs3D did not reach the configured height")
		if !_has_mesh_vertex_y_near(open_stairs, 0.08, 0.001):
			m_failures.append(
				"Open-tread Stairs3D is missing the first floating tread underside"
			)
		if _has_mesh_vertex_y_near(open_stairs, -0.12, 0.001):
			m_failures.append("Open-tread Stairs3D still generated the closed underside")
	open_stairs.tread_style = Stairs3DScript.TreadStyle.CLOSED
	open_stairs.rebuild_stairs_mesh()
	if !_has_mesh_vertex_y_near(open_stairs, -0.12, 0.001):
		m_failures.append(
			"Stairs3D did not rebuild the closed underside after a tread style change"
		)

	var nosing_stairs := _create_tread_style_stairs(
		coordinator,
		Vector3(44.0, 0.0, 16.0),
		StraightStairs3DScript,
		Stairs3DScript.TreadStyle.NOSING,
		0.08
	)
	coordinator.add_child(nosing_stairs)
	if nosing_stairs.mesh == null or nosing_stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Nosing Stairs3D did not generate a mesh")
	else:
		if !_has_mesh_vertex_y_near(nosing_stairs, -0.12, 0.001):
			m_failures.append("Nosing Stairs3D did not retain the closed underside")
		var arrays := nosing_stairs.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var minimum_z := INF
		for vertex in vertices:
			minimum_z = minf(minimum_z, vertex.z)
		if absf(minimum_z + 0.08) > 0.001:
			m_failures.append(
				"Nosing Stairs3D lip does not overhang the first riser by the nosing depth"
			)

	var open_l_stairs := _create_tread_style_stairs(
		coordinator,
		Vector3(48.0, 0.0, 16.0),
		LShapedStairs3DScript,
		Stairs3DScript.TreadStyle.OPEN,
		0.0
	)
	coordinator.add_child(open_l_stairs)
	if open_l_stairs.mesh == null or open_l_stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Open-tread L-shaped Stairs3D did not generate a mesh")
	elif _has_mesh_vertex_y_near(open_l_stairs, -0.12, 0.001):
		m_failures.append(
			"Open-tread L-shaped Stairs3D still generated closed-mass underside geometry"
		)


func _validate_stairs_optional_rails(coordinator: Building3DScript) -> void:
	var base_y := 2.5
	var no_rail_stairs := BuildingFactoryScript.create_stairs_node(coordinator,
		Vector3(0.0, base_y, 32.0),
		Vector3(3.0, base_y, 36.0),
		{
			"height": 1.2,
			"step_count": 4,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
		}
	)
	coordinator.add_child(no_rail_stairs)
	if no_rail_stairs.left_rail_enabled or no_rail_stairs.right_rail_enabled:
		m_failures.append("Stairs3D enabled rails by default")
	var base_vertex_count := _mesh_vertex_count(no_rail_stairs)
	if base_vertex_count != 66:
		m_failures.append("Stairs3D without rails changed its baseline stepped vertex count")

	var one_rail_stairs := BuildingFactoryScript.create_stairs_node(coordinator,
		Vector3(6.0, base_y, 32.0),
		Vector3(9.0, base_y, 36.0),
		{
			"height": 1.2,
			"step_count": 4,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
			"left_rail_enabled": true,
			"right_rail_enabled": false,
			"rail_height": 1.0,
			"infill_rail_thickness": 0.08,
			"rail_thickness": 0.1,
			"rail_lower_height": 0.18,
			"rail_color": Color(0.33, 0.28, 0.22, 1.0),
		}
	)
	coordinator.add_child(one_rail_stairs)
	if !one_rail_stairs.left_rail_enabled or one_rail_stairs.right_rail_enabled:
		m_failures.append("BuildingFactory did not apply the requested single-side rail flags")
	# The shared standard-rail strategy generates a 200-vertex post/bar assembly
	# for this 4-unit run with these dimensions: one top bar box, one lower bar
	# box, and one 16-vertex open-ended post per tread (4 steps) centered in the
	# depth direction instead of Rail3D's evenly-spaced distribution. The top
	# bar's underside is partitioned into 23 aligned quads around the four post
	# openings, replacing its former single overlapping underside quad without
	# leaving T-junctions at the welded edges.
	if _mesh_vertex_count(one_rail_stairs) != base_vertex_count + 200:
		m_failures.append(
			"Stairs3D single side rail did not append the shared standard-rail vertex count"
		)
	if one_rail_stairs.get_node_or_null("StairsCollision") == null:
		m_failures.append("Stairs3D with a rail enabled did not generate collision")

	# With the default 0.15 edge margin, rail_thickness 0.1, the left rail's
	# bar sits with its faces at x = 0.15 +/- 0.05 (0.10 and 0.20), never at
	# the unmargined x = 0.05 a bar straddling the exact footprint edge
	# would have produced.
	if absf(one_rail_stairs.rail_edge_margin - 0.15) > 0.001:
		m_failures.append("Stairs3D did not default rail_edge_margin to 0.15")
	var one_rail_arrays := one_rail_stairs.mesh.surface_get_arrays(0)
	var one_rail_vertices: PackedVector3Array = one_rail_arrays[Mesh.ARRAY_VERTEX]
	var found_margined_bar_edge := false
	var found_unmargined_bar_edge := false
	for vertex in one_rail_vertices:
		if absf(vertex.x - 0.10) <= 0.001:
			found_margined_bar_edge = true
		if absf(vertex.x - 0.05) <= 0.001:
			found_unmargined_bar_edge = true
	if !found_margined_bar_edge:
		m_failures.append("Stairs3D left rail bar did not inset by rail_edge_margin")
	if found_unmargined_bar_edge:
		m_failures.append("Stairs3D left rail bar still straddles the unmargined footprint edge")

	one_rail_stairs.rail_lower_height = 0.0
	one_rail_stairs.rebuild_stairs_mesh()
	if _mesh_vertex_count(one_rail_stairs) != base_vertex_count + 176:
		m_failures.append("Stairs3D retained base-rail geometry when its height was zero")
	var no_base_rail_layout: Dictionary = one_rail_stairs._get_rail_post_layout()
	var tread_based_infill_heights: PackedFloat32Array = no_base_rail_layout["base_heights"]
	if (
		tread_based_infill_heights.size() != 4
		or absf(tread_based_infill_heights[0] - 0.3) > 0.001
		or absf(tread_based_infill_heights[1] - 0.6) > 0.001
		or absf(tread_based_infill_heights[2] - 0.9) > 0.001
		or absf(tread_based_infill_heights[3] - 1.2) > 0.001
	):
		m_failures.append("Stairs3D infills did not fall back to tread bases without a base rail")

	var both_rail_stairs := BuildingFactoryScript.create_stairs_node(coordinator,
		Vector3(12.0, base_y, 32.0),
		Vector3(15.0, base_y, 36.0),
		{
			"height": 1.2,
			"step_count": 4,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
			"left_rail_enabled": true,
			"right_rail_enabled": true,
			"rail_height": 1.0,
			"infill_rail_thickness": 0.08,
			"rail_thickness": 0.1,
			"rail_lower_height": 0.18,
			"rail_color": Color(0.33, 0.28, 0.22, 1.0),
		}
	)
	coordinator.add_child(both_rail_stairs)
	if _mesh_vertex_count(both_rail_stairs) != base_vertex_count + 200 * 2:
		m_failures.append(
			"Stairs3D with both side rails did not append two shared standard-rail vertex counts"
		)
	var both_arrays := both_rail_stairs.mesh.surface_get_arrays(0)
	var both_normals: PackedVector3Array = both_arrays[Mesh.ARRAY_NORMAL]
	var both_colors: PackedColorArray = both_arrays[Mesh.ARRAY_COLOR]
	var both_vertices: PackedVector3Array = both_arrays[Mesh.ARRAY_VERTEX]
	if both_normals.size() != both_vertices.size() or both_colors.size() != both_vertices.size():
		m_failures.append("Stairs3D with rails is missing per-vertex normal or color data")
	if !_has_normal_near(both_normals, Vector3.UP):
		m_failures.append("Stairs3D rails are missing top-facing rail surfaces")

	var expected_post_positions := StandardRailGeometryScript.tread_mid_post_positions(4.0, 4)
	if (
		expected_post_positions.size() != 4
		or absf(expected_post_positions[0] - 0.5) > 0.001
		or absf(expected_post_positions[3] - 3.5) > 0.001
	):
		m_failures.append("Stairs3D rail posts are not centered on each tread's depth span")

	# Tread heights remain the structural bases used when one of these posts
	# becomes a newel.
	var expected_post_base_heights := StandardRailGeometryScript.tread_mid_post_base_heights(1.2, 4)
	if (
		expected_post_base_heights.size() != 4
		or absf(expected_post_base_heights[0] - 0.3) > 0.001
		or absf(expected_post_base_heights[3] - 1.2) > 0.001
	):
		m_failures.append("Stairs3D rail posts are not based on their tread's actual height")
	# Regular infills instead begin on the top of the raked base rail. With
	# a 0.18 center and 0.10 thickness, that top is 0.23 above the rail slope.
	var default_rail_layout: Dictionary = both_rail_stairs._get_rail_post_layout()
	var default_infill_bases: PackedFloat32Array = default_rail_layout["base_heights"]
	if (
		default_infill_bases.size() != 4
		or absf(default_infill_bases[0] - 0.38) > 0.001
		or absf(default_infill_bases[3] - 1.28) > 0.001
	):
		m_failures.append("Stairs3D infills do not sit on top of the raked base rail")

	if (
		both_rail_stairs.lower_newel_enabled
		or both_rail_stairs.upper_newel_enabled
		or both_rail_stairs.middle_newel_post_count != 0
	):
		m_failures.append("Stairs3D enabled newel posts by default")
	if both_rail_stairs.infill_count_between_newels != 1:
		m_failures.append("Stairs3D did not default to one infill per newel span")
	both_rail_stairs.middle_newel_post_count = 2
	var fallback_terminal_layout: Dictionary = both_rail_stairs._get_rail_post_layout()
	var fallback_terminal_positions: PackedFloat32Array = fallback_terminal_layout["positions"]
	var fallback_terminal_top_heights: PackedFloat32Array = fallback_terminal_layout["top_heights"]
	if (
		fallback_terminal_positions.size() != 3
		or absf(fallback_terminal_positions[0] - 0.5) > 0.001
		or absf(fallback_terminal_positions[2] - 3.5) > 0.001
		or !is_nan(fallback_terminal_top_heights[0])
		or !is_nan(fallback_terminal_top_heights[2])
		or !is_nan(float(fallback_terminal_layout["handrail_minimum_run"]))
		or !is_nan(float(fallback_terminal_layout["handrail_maximum_run"]))
		or float(fallback_terminal_layout["lower_horizontal_end"]) != -INF
		or float(fallback_terminal_layout["upper_horizontal_start"]) != INF
	):
		m_failures.append(
			"Stairs3D distributed newels changed terminal handrail behavior"
		)
	both_rail_stairs.middle_newel_post_count = 0
	both_rail_stairs.lower_newel_enabled = true
	both_rail_stairs.lower_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	both_rail_stairs.upper_newel_enabled = true
	both_rail_stairs.upper_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	both_rail_stairs.middle_newel_post_count = 4
	both_rail_stairs.rail_newel_post_thickness = 0.14
	both_rail_stairs.rebuild_stairs_mesh()
	# The configured 0.14 newel is clamped to this rail's 0.10 handrail width
	# in the generated layout, keeping the welded open top fully covered.
	var floor_lower_layout: Dictionary = both_rail_stairs._get_rail_post_layout()
	var floor_lower_positions: PackedFloat32Array = floor_lower_layout["positions"]
	var floor_lower_heights: PackedFloat32Array = floor_lower_layout["base_heights"]
	var floor_lower_thicknesses: PackedFloat32Array = floor_lower_layout["thicknesses"]
	var floor_lower_newel_flags: PackedByteArray = floor_lower_layout["newel_flags"]
	var floor_lower_top_heights: PackedFloat32Array = floor_lower_layout["top_heights"]
	if (
		floor_lower_positions.size() != 7
		or absf(floor_lower_positions[0] + 0.5) > 0.001
		or absf(floor_lower_positions[1]) > 0.001
		or absf(floor_lower_heights[0]) > 0.001
		or absf(floor_lower_thicknesses[0] - 0.1) > 0.001
		or absf(floor_lower_top_heights[0] - 0.9) > 0.001
		or floor_lower_newel_flags[0] == 0
		or absf(float(floor_lower_layout["lower_horizontal_end"])) > 0.001
		or absf(float(floor_lower_layout["handrail_minimum_run"]) + 0.55) > 0.001
		or absf(floor_lower_positions[6] - 3.5) > 0.001
		or absf(floor_lower_heights[6] - 1.2) > 0.001
		or absf(floor_lower_thicknesses[6] - 0.1) > 0.001
		or absf(floor_lower_top_heights[6] - 1.935) > 0.001
		or floor_lower_newel_flags[6] == 0
		or absf(float(floor_lower_layout["handrail_maximum_run"]) - 3.55) > 0.001
	):
		m_failures.append(
			"Stairs3D did not place lower-floor and upper-tread newels correctly"
		)
	if (
		absf(floor_lower_positions[2] - 0.5) > 0.001
		or absf(floor_lower_positions[4] - 2.5) > 0.001
		or absf(floor_lower_thicknesses[2] - 0.1) > 0.001
		or absf(floor_lower_thicknesses[4] - 0.1) > 0.001
		or floor_lower_newel_flags[2] == 0
		or floor_lower_newel_flags[4] == 0
		or !is_nan(floor_lower_top_heights[2])
		or !is_nan(floor_lower_top_heights[4])
	):
		m_failures.append(
			"Stairs3D middle newels are not tread-centered with sloped tops"
		)
	both_rail_stairs.middle_newel_post_count = 5
	var distributed_middle_indices: PackedInt32Array = (
		both_rail_stairs._middle_newel_tread_indices(
			7,
			both_rail_stairs.lower_newel_enabled,
			both_rail_stairs.upper_newel_enabled,
			both_rail_stairs.middle_newel_post_count,
			both_rail_stairs.lower_newel_placement,
			both_rail_stairs.upper_newel_placement
		)
	)
	if distributed_middle_indices != PackedInt32Array([1, 3, 4]):
		m_failures.append(
			"Stairs3D did not distribute middle newels across the terminal interval"
		)
	both_rail_stairs.lower_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	both_rail_stairs.upper_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	both_rail_stairs.middle_newel_post_count = 4
	var tread_terminal_middle_indices: PackedInt32Array = (
		both_rail_stairs._middle_newel_tread_indices(
			6,
			both_rail_stairs.lower_newel_enabled,
			both_rail_stairs.upper_newel_enabled,
			both_rail_stairs.middle_newel_post_count,
			both_rail_stairs.lower_newel_placement,
			both_rail_stairs.upper_newel_placement
		)
	)
	both_rail_stairs.lower_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	both_rail_stairs.upper_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	var floor_terminal_middle_indices: PackedInt32Array = (
		both_rail_stairs._middle_newel_tread_indices(
			6,
			both_rail_stairs.lower_newel_enabled,
			both_rail_stairs.upper_newel_enabled,
			both_rail_stairs.middle_newel_post_count,
			both_rail_stairs.lower_newel_placement,
			both_rail_stairs.upper_newel_placement
		)
	)
	if (
		tread_terminal_middle_indices != PackedInt32Array([2, 3])
		or floor_terminal_middle_indices != PackedInt32Array([1, 4])
	):
		m_failures.append("Stairs3D middle newels ignored terminal newel positions")
	both_rail_stairs.lower_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	both_rail_stairs.upper_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	both_rail_stairs.middle_newel_post_count = 4
	both_rail_stairs.infill_count_between_newels = 3
	var counted_infill_layout := StandardRailGeometryScript.apply_infill_count_between_newels(
		PackedFloat32Array([0.0, 1.0, 2.0, 4.0]),
		PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
		PackedFloat32Array([0.2, 0.1, 0.1, 0.4]),
		PackedByteArray([1, 0, 0, 1]),
		3,
		0.08
	)
	var counted_infill_positions: PackedFloat32Array = counted_infill_layout["positions"]
	var counted_infill_flags: PackedByteArray = counted_infill_layout["newel_flags"]
	if (
		counted_infill_positions.size() != 5
		or counted_infill_flags != PackedByteArray([1, 0, 0, 0, 1])
	):
		m_failures.append("Stairs3D did not generate the requested infill count per span")
	both_rail_stairs.infill_count_between_newels = 1
	var redistributed_positions := PackedFloat32Array([0.0, 1.0, 2.0, 4.0])
	var redistributed_thicknesses := PackedFloat32Array([0.2, 0.1, 0.1, 0.4])
	var redistributed_newel_flags := PackedByteArray([1, 0, 0, 1])
	StandardRailGeometryScript.redistribute_infills_between_newels(
		redistributed_positions,
		redistributed_thicknesses,
		redistributed_newel_flags
	)
	var first_clear_gap := redistributed_positions[1] - 0.05 - 0.1
	var middle_clear_gap := redistributed_positions[2] - 0.05 - (
		redistributed_positions[1] + 0.05
	)
	var final_clear_gap := 3.8 - (redistributed_positions[2] + 0.05)
	if (
		absf(first_clear_gap - middle_clear_gap) > 0.001
		or absf(middle_clear_gap - final_clear_gap) > 0.001
	):
		m_failures.append("Stairs3D infills are not evenly spaced between newel faces")
	if !_has_mesh_vertex_with_normal_near(
		both_rail_stairs.mesh as ArrayMesh,
		Vector3(0.10, 1.0, -0.55),
		Vector3.UP,
		0.002
	):
		m_failures.append("Stairs3D lower-floor newel handrail is not horizontal")
	if !_has_mesh_vertex_with_normal_near(
		both_rail_stairs.mesh as ArrayMesh,
		Vector3(0.10, 2.035, 3.55),
		Vector3.UP,
		0.002
	):
		m_failures.append("Stairs3D upper-tread newel handrail is not horizontal")

	both_rail_stairs.lower_newel_placement = Stairs3DScript.NewelPlacement.TREAD
	both_rail_stairs.upper_newel_placement = Stairs3DScript.NewelPlacement.FLOOR
	both_rail_stairs.rebuild_stairs_mesh()
	var floor_upper_layout: Dictionary = both_rail_stairs._get_rail_post_layout()
	var floor_upper_positions: PackedFloat32Array = floor_upper_layout["positions"]
	var floor_upper_heights: PackedFloat32Array = floor_upper_layout["base_heights"]
	var floor_upper_thicknesses: PackedFloat32Array = floor_upper_layout["thicknesses"]
	var floor_upper_top_heights: PackedFloat32Array = floor_upper_layout["top_heights"]
	if (
		floor_upper_positions.size() != 7
		or absf(floor_upper_positions[0] - 0.5) > 0.001
		or absf(floor_upper_heights[0] - 0.3) > 0.001
		or absf(floor_upper_thicknesses[0] - 0.1) > 0.001
		or absf(floor_upper_top_heights[0] - 1.065) > 0.001
		or absf(float(floor_upper_layout["handrail_minimum_run"]) - 0.45) > 0.001
		or absf(floor_upper_positions[6] - 4.5) > 0.001
		or absf(floor_upper_positions[5] - 4.0) > 0.001
		or absf(floor_upper_heights[6] - 1.2) > 0.001
		or absf(floor_upper_thicknesses[6] - 0.1) > 0.001
		or absf(floor_upper_top_heights[6] - 2.1) > 0.001
		or absf(float(floor_upper_layout["upper_horizontal_start"]) - 4.0) > 0.001
		or absf(float(floor_upper_layout["handrail_maximum_run"]) - 4.55) > 0.001
	):
		m_failures.append(
			"Stairs3D did not place lower-tread and upper-floor newels correctly"
		)
	if !_has_mesh_vertex_with_normal_near(
		both_rail_stairs.mesh as ArrayMesh,
		Vector3(0.10, 1.165, 0.45),
		Vector3.UP,
		0.002
	):
		m_failures.append("Stairs3D lower-tread newel handrail is not horizontal")
	if !_has_mesh_vertex_with_normal_near(
		both_rail_stairs.mesh as ArrayMesh,
		Vector3(0.10, 2.2, 4.55),
		Vector3.UP,
		0.002
	):
		m_failures.append("Stairs3D upper-floor newel handrail is not horizontal")
	if both_rail_stairs.mesh == null or both_rail_stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Stairs3D newel configuration did not generate rail geometry")

	both_rail_stairs.left_rail_enabled = false
	both_rail_stairs.right_rail_enabled = false
	both_rail_stairs.rebuild_stairs_mesh()
	if _mesh_vertex_count(both_rail_stairs) != base_vertex_count:
		m_failures.append("Stairs3D did not remove rail geometry after disabling both rails")

	# A footprint narrower than twice the configured margin must clamp the
	# margin instead of letting the two rails cross or the mesh go invalid.
	var narrow_stairs := BuildingFactoryScript.create_stairs_node(coordinator,
		Vector3(18.0, base_y, 32.0),
		Vector3(18.2, base_y, 34.0),
		{
			"height": 1.2,
			"step_count": 2,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
			"left_rail_enabled": true,
			"right_rail_enabled": true,
			"rail_height": 1.0,
			"infill_rail_thickness": 0.08,
			"rail_thickness": 0.1,
			"rail_lower_height": 0.18,
			"rail_color": Color(0.33, 0.28, 0.22, 1.0),
			"rail_edge_margin": 0.15,
			"lower_newel_enabled": true,
			"lower_newel_placement": Stairs3DScript.NewelPlacement.FLOOR,
			"upper_newel_enabled": true,
			"upper_newel_placement": Stairs3DScript.NewelPlacement.TREAD,
			"rail_newel_post_thickness": 0.14,
			"middle_newel_post_count": 2,
			"infill_count_between_newels": 3,
			"infill_style": StandardRailGeometryScript.RailStyle.HORIZONTAL,
		}
	)
	coordinator.add_child(narrow_stairs)
	if narrow_stairs.mesh == null or narrow_stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Stairs3D with a clamped rail margin on a narrow footprint did not build a mesh")
	if (
		!narrow_stairs.lower_newel_enabled
		or narrow_stairs.lower_newel_placement != Stairs3DScript.NewelPlacement.FLOOR
		or !narrow_stairs.upper_newel_enabled
		or narrow_stairs.upper_newel_placement != Stairs3DScript.NewelPlacement.TREAD
		or narrow_stairs.middle_newel_post_count != 2
		or narrow_stairs.infill_count_between_newels != 3
		or narrow_stairs.infill_style != StandardRailGeometryScript.RailStyle.HORIZONTAL
		or absf(narrow_stairs.rail_newel_post_thickness - 0.14) > 0.001
	):
		m_failures.append("BuildingFactory did not apply the requested stair newel settings")


func _validate_standard_rail_geometry_post_base_heights() -> void:
	# Whitebox check directly against the shared geometry strategy: with an
	# explicit post_base_heights array, each post must be a flat, upright
	# open-ended box whose side-face bottom edges sit exactly at the given
	# height (not sheared or offset by the run's rise), independent of the
	# larger Stairs3D assembly.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var positions := PackedFloat32Array([0.5, 1.5])
	var base_heights := PackedFloat32Array([0.3, 0.6])
	StandardRailGeometryScript.append_rail(
		vertices,
		normals,
		colors,
		indices,
		Vector3.ZERO,
		Vector3.BACK,
		Vector3.UP,
		Vector3.RIGHT,
		2.0,
		0.6,
		1.0,
		1.0,
		0.08,
		0.1,
		0.0,
		Color.WHITE,
		positions,
		base_heights
	)
	# Layout: the top bar occupies vertices [0..71] (20 vertices for its
	# outer faces plus 52 for thirteen underside quads around two post openings;
	# lower rail is disabled via lower_rail_height 0.0). Each post then
	# contributes 16 vertices in FORWARD/BACK/LEFT/RIGHT face order. Its
	# enclosed UP and hidden DOWN faces are not emitted.
	var first_post_start := 72
	var second_post_start := 88
	if vertices.size() != 104:
		m_failures.append(
			"StandardRailGeometry generated an unexpected vertex count for this post layout"
		)
		return
	var bottom_edge_offsets := PackedInt32Array([0, 1, 4, 7, 8, 11, 12, 13])
	for offset in bottom_edge_offsets:
		if absf(vertices[first_post_start + offset].y - 0.3) > 0.001:
			m_failures.append("StandardRailGeometry first post base is not flat at its tread height")
		if absf(vertices[second_post_start + offset].y - 0.6) > 0.001:
			m_failures.append("StandardRailGeometry second post base is not flat at its tread height")

	# The bar's underside follows the rise/length diagonal. Each post's two
	# run-side top edges now land on that plane independently: 1.038/1.062
	# around u=0.5 and 1.338/1.362 around u=1.5. The matching handrail
	# underside rectangles are absent, creating an exact seam rather than an
	# overlap or wedge gap.
	var minimum_run_top_offsets := PackedInt32Array([3, 5, 9, 10])
	var maximum_run_top_offsets := PackedInt32Array([2, 6, 14, 15])
	for offset in minimum_run_top_offsets:
		if absf(vertices[first_post_start + offset].y - 1.038) > 0.001:
			m_failures.append("StandardRailGeometry first post minimum edge is not welded to the bar")
		if absf(vertices[second_post_start + offset].y - 1.338) > 0.001:
			m_failures.append("StandardRailGeometry second post minimum edge is not welded to the bar")
	for offset in maximum_run_top_offsets:
		if absf(vertices[first_post_start + offset].y - 1.062) > 0.001:
			m_failures.append("StandardRailGeometry first post maximum edge is not welded to the bar")
		if absf(vertices[second_post_start + offset].y - 1.362) > 0.001:
			m_failures.append("StandardRailGeometry second post maximum edge is not welded to the bar")
	for triangle_start in range(0, indices.size(), 3):
		var first_index := indices[triangle_start]
		if normals[first_index].dot(Vector3.DOWN) < 0.999:
			continue
		var centroid := (
			vertices[first_index]
			+ vertices[indices[triangle_start + 1]]
			+ vertices[indices[triangle_start + 2]]
		) / 3.0
		for post_position in positions:
			if (
				absf(centroid.z - post_position) < 0.039
				and absf(centroid.x) < 0.039
			):
				m_failures.append(
					"StandardRailGeometry retained a handrail underside triangle inside a post weld"
				)
				break
	for normal_index in range(first_post_start, first_post_start + 16):
		if normals[normal_index].dot(Vector3.UP) > 0.999:
			m_failures.append("StandardRailGeometry first post retained an enclosed top face")
			break
		if normals[normal_index].dot(Vector3.DOWN) > 0.999:
			m_failures.append("StandardRailGeometry first post retained a hidden bottom face")
			break
	for normal_index in range(second_post_start, second_post_start + 16):
		if normals[normal_index].dot(Vector3.UP) > 0.999:
			m_failures.append("StandardRailGeometry second post retained an enclosed top face")
			break
		if normals[normal_index].dot(Vector3.DOWN) > 0.999:
			m_failures.append("StandardRailGeometry second post retained a hidden bottom face")
			break

	# With base_follows_rise flags, each post bottom must shear onto the
	# raked base-rail top: corners move by rise * (corner_run - position) /
	# length = 0.6 * (+/-0.04) / 2.0 = +/-0.012 around each authored base.
	var raked_vertices := PackedVector3Array()
	var raked_normals := PackedVector3Array()
	var raked_colors := PackedColorArray()
	var raked_indices := PackedInt32Array()
	StandardRailGeometryScript.append_rail(
		raked_vertices,
		raked_normals,
		raked_colors,
		raked_indices,
		Vector3.ZERO,
		Vector3.BACK,
		Vector3.UP,
		Vector3.RIGHT,
		2.0,
		0.6,
		1.0,
		1.0,
		0.08,
		0.1,
		0.0,
		Color.WHITE,
		positions,
		base_heights,
		PackedFloat32Array(),
		PackedFloat32Array(),
		-INF,
		INF,
		NAN,
		NAN,
		StandardRailGeometryScript.RailStyle.VERTICAL,
		1,
		PackedByteArray([1, 1])
	)
	if raked_vertices.size() != vertices.size():
		m_failures.append(
			"StandardRailGeometry rise-following bases changed the post vertex layout"
		)
		return
	var minimum_run_bottom_offsets := PackedInt32Array([0, 4, 8, 11])
	var maximum_run_bottom_offsets := PackedInt32Array([1, 7, 12, 13])
	for offset in minimum_run_bottom_offsets:
		if absf(raked_vertices[first_post_start + offset].y - 0.288) > 0.001:
			m_failures.append("StandardRailGeometry first post bottom did not follow the base-rail rake")
		if absf(raked_vertices[second_post_start + offset].y - 0.588) > 0.001:
			m_failures.append("StandardRailGeometry second post bottom did not follow the base-rail rake")
	for offset in maximum_run_bottom_offsets:
		if absf(raked_vertices[first_post_start + offset].y - 0.312) > 0.001:
			m_failures.append("StandardRailGeometry first post bottom did not follow the base-rail rake")
		if absf(raked_vertices[second_post_start + offset].y - 0.612) > 0.001:
			m_failures.append("StandardRailGeometry second post bottom did not follow the base-rail rake")

	# Stairs3D's axis triple (run=BACK, up=UP, side=RIGHT) is an axis swap
	# from Rail3D's (run=RIGHT, up=UP, side=BACK), which mirrors it
	# (negative orientation). The bar's first face (its FORWARD quad, the
	# mesh's very first triangle) must still satisfy the same Godot winding
	# convention Rail3D's own geometry does: the geometric winding normal
	# should be antiparallel to the stored vertex normal, so the visible,
	# non-culled face actually matches where the normal points.
	if normals.size() >= 3:
		var winding_a := vertices[indices[0]]
		var winding_b := vertices[indices[1]]
		var winding_c := vertices[indices[2]]
		var winding_normal := (winding_b - winding_a).cross(winding_c - winding_a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append(
				"StandardRailGeometry winding does not match Godot convention for a mirrored axis triple"
			)


func _validate_rail_node(coordinator: Building3DScript) -> void:
	var base_y := 1.25
	var rail := BuildingFactoryScript.create_rail_node(
		coordinator,
		Vector3(2.0, base_y, 24.0),
		Vector3(6.0, base_y, 24.0),
		1.1,
		1.0,
		0.08,
		0.1,
		0.2,
		Color(0.33, 0.28, 0.22, 1.0)
	)
	if rail.get_parent() != null:
		m_failures.append("BuildingFactory parented a rail instead of returning a detached node")
	coordinator.add_child(rail)
	if rail.mesh == null or rail.mesh.get_surface_count() <= 0:
		m_failures.append("Rail3D did not generate a mesh")
		return
	if rail.position.distance_to(Vector3(2.0, base_y, 24.0)) > 0.001:
		m_failures.append("Rail3D did not place its transform at the start point")
	if absf(rail.get_rail_length() - 4.0) > 0.001:
		m_failures.append("Rail3D did not preserve its authored span length")
	if rail.get_post_count() != 3:
		m_failures.append("Rail3D did not generate endpoint newels and its configured infill span")
	var rail_layout := rail._get_post_layout(4.0)
	var rail_positions: PackedFloat32Array = rail_layout["positions"]
	var rail_base_heights: PackedFloat32Array = rail_layout["base_heights"]
	var rail_newel_flags: PackedByteArray = rail_layout["newel_flags"]
	if (
		rail_positions != PackedFloat32Array([0.0, 2.0, 4.0])
		or rail_newel_flags != PackedByteArray([1, 0, 1])
		or absf(rail_base_heights[0]) > 0.001
		or absf(rail_base_heights[1] - 0.25) > 0.001
		or absf(rail_base_heights[2]) > 0.001
	):
		m_failures.append("Rail3D did not share the newel/base-rail infill layout")

	var arrays := rail.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != 124:
		m_failures.append("Rail3D generated the wrong standard rail vertex count")
	if normals.size() != vertices.size():
		m_failures.append("Rail3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Rail3D mesh is missing per-vertex color data")
	if !_has_normal_near(normals, Vector3.UP):
		m_failures.append("Rail3D mesh is missing top-facing rail surfaces")
	if !_has_normal_near(normals, Vector3.FORWARD):
		m_failures.append("Rail3D mesh is missing front-facing rail surfaces")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Rail3D triangle winding does not match Godot BoxMesh convention")
	if rail.get_node_or_null("RailCollision") == null:
		m_failures.append("Rail3D did not generate collision")
	rail.lower_rail_height = 0.0
	rail.rebuild_rail_mesh()
	var no_base_layout := rail._get_post_layout(4.0)
	var no_base_heights: PackedFloat32Array = no_base_layout["base_heights"]
	if (
		_mesh_vertex_count(rail) != 100
		or absf(no_base_heights[1]) > 0.001
	):
		m_failures.append("Rail3D did not remove its base rail and rebase infills")
	rail.newel_post_count = 3
	rail.infill_count_between_newels = 2
	rail.rebuild_rail_mesh()
	if rail.get_post_count() != 7:
		m_failures.append("Rail3D did not apply shared per-newel-span infill counts")
	rail.lower_rail_height = 0.2
	rail.newel_post_count = 2
	rail.infill_count_between_newels = 2
	rail.infill_style = StandardRailGeometryScript.RailStyle.HORIZONTAL
	rail.rebuild_rail_mesh()
	var horizontal_bar_size := minf(rail.rail_thickness, rail.rail_height * 0.5)
	var horizontal_base_top := StandardRailGeometryScript.lower_rail_top_height(
		rail.rail_height,
		rail.rail_thickness,
		rail.lower_rail_height
	)
	var horizontal_handrail_bottom := rail.rail_height - horizontal_bar_size
	var horizontal_infill_size := minf(
		rail.infill_rail_thickness,
		maxf(horizontal_handrail_bottom - horizontal_base_top, 0.02)
	)
	var horizontal_clear_gap := (
		horizontal_handrail_bottom
		- horizontal_base_top
		- horizontal_infill_size * 2.0
	) / 3.0
	var horizontal_first_bottom := horizontal_base_top + horizontal_clear_gap
	var horizontal_first_top := horizontal_first_bottom + horizontal_infill_size
	var horizontal_second_bottom := horizontal_first_top + horizontal_clear_gap
	var horizontal_second_top := horizontal_second_bottom + horizontal_infill_size
	if (
		rail.get_post_count() != 2
		or !_has_mesh_vertex_y_near(rail, horizontal_first_bottom, 0.001)
		or !_has_mesh_vertex_y_near(rail, horizontal_first_top, 0.001)
		or !_has_mesh_vertex_y_near(rail, horizontal_second_bottom, 0.001)
		or !_has_mesh_vertex_y_near(rail, horizontal_second_top, 0.001)
	):
		m_failures.append("Rail3D horizontal infill did not follow the configured count and thickness")
	rail.infill_style = StandardRailGeometryScript.RailStyle.GLASS_PANEL
	rail.rebuild_rail_mesh()
	var glass_material := rail.material_override as StandardMaterial3D
	var glass_arrays: Array = rail.mesh.surface_get_arrays(0)
	var glass_colors: PackedColorArray = glass_arrays[Mesh.ARRAY_COLOR]
	var has_translucent_glass_vertex := false
	for glass_color in glass_colors:
		if glass_color.a < 0.9:
			has_translucent_glass_vertex = true
			break
	if (
		!_has_mesh_vertex_y_near(rail, horizontal_base_top, 0.001)
		or !_has_mesh_vertex_y_near(rail, horizontal_handrail_bottom, 0.001)
		or !has_translucent_glass_vertex
		or glass_material == null
		or glass_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	):
		m_failures.append("Rail3D glass panel did not span base rail to handrail with depth-pre-pass alpha transparency")
	rail.infill_style = StandardRailGeometryScript.RailStyle.VERTICAL
	rail.infill_count_between_newels = 1
	rail.rebuild_rail_mesh()

	# The handrail run is pinned to the endpoint newels' outer faces, so a
	# thicker infill rail must not lengthen the handrail.
	rail.infill_rail_thickness = 0.3
	rail.rebuild_rail_mesh()
	var thick_infill_arrays: Array = rail.mesh.surface_get_arrays(0)
	var thick_infill_vertices: PackedVector3Array = (
		thick_infill_arrays[Mesh.ARRAY_VERTEX]
	)
	var thick_run_minimum := INF
	var thick_run_maximum := -INF
	var thick_side_maximum := 0.0
	for thick_infill_vertex in thick_infill_vertices:
		thick_run_minimum = minf(thick_run_minimum, thick_infill_vertex.x)
		thick_run_maximum = maxf(thick_run_maximum, thick_infill_vertex.x)
		thick_side_maximum = maxf(thick_side_maximum, absf(thick_infill_vertex.z))
	var expected_newel_size := minf(
		maxf(rail.newel_post_thickness, 0.02),
		minf(maxf(rail.rail_thickness, 0.02), maxf(rail.rail_height, 0.2) * 0.5)
	)
	if (
		thick_run_minimum < -expected_newel_size * 0.5 - 0.001
		or thick_run_maximum > (
			rail.get_rail_length() + expected_newel_size * 0.5 + 0.001
		)
	):
		m_failures.append("Rail3D handrail length changed with the infill rail thickness")
	# Infill geometry is clamped to the handrail cross-section, so no vertex
	# may stick out sideways past the handrail width.
	var expected_handrail_width := minf(
		maxf(rail.rail_thickness, 0.02),
		maxf(rail.rail_height, 0.2) * 0.5
	)
	if thick_side_maximum > expected_handrail_width * 0.5 + 0.001:
		m_failures.append("Rail3D infill geometry exceeded the handrail width")
	rail.infill_rail_thickness = 0.08
	rail.rebuild_rail_mesh()

	rail.set_rail_points(
		Vector3(3.0, base_y, 25.0),
		Vector3(7.0, base_y, 29.0)
	)
	if rail.position.distance_to(Vector3(3.0, base_y, 25.0)) > 0.001:
		m_failures.append("Rail3D did not move its transform after endpoint editing")
	if absf(rail.get_rail_length() - sqrt(32.0)) > 0.001:
		m_failures.append("Rail3D did not resize after endpoint editing")
	if rail.transform.basis.is_equal_approx(Basis.IDENTITY):
		m_failures.append("Rail3D did not orient its local frame along a diagonal span")


func _has_box_collision_shape(root: Node, path: String) -> bool:
	return _box_collision_shape(root, path) != null


func _box_collision_shape(root: Node, path: String) -> BoxShape3D:
	var collision_shape := _collision_shape(root, path)
	if collision_shape == null:
		return null
	return collision_shape.shape as BoxShape3D


func _collision_shape(root: Node, path: String) -> CollisionShape3D:
	return root.get_node_or_null(path) as CollisionShape3D


func _validate_stairs_side_collision_blocks_character(coordinator: Building3DScript) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "StairsSideCollisionProbeFloor"
	floor_body.set_meta(&"test_generated", true)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.1, 8.0)
	floor_shape.shape = floor_box
	floor_shape.position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(2.5, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var stairs := BuildingFactoryScript.create_stairs_node(coordinator,
		STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(2.0, 0.0, -2.0),
		STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(5.0, 0.0, 2.0),
		{
			"height": 1.2,
			"step_count": 4,
			"thickness": 0.16,
			"color": Color(0.52, 0.46, 0.38, 1.0),
		}
	)
	coordinator.add_child(stairs)

	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		m_failures.append("Stairs3D side collision probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		stairs.queue_free()
		return
	probe.name = "StairsSideCollisionHumanBody3DProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)
	await get_tree().physics_frame

	probe.global_position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(0.6, 0.1, 0.0)
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var saw_side_collision := false
	for i in range(STAIRS_SIDE_COLLISION_PROBE_FRAMES):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.RIGHT, STAIRS_SIDE_COLLISION_PROBE_SPEED)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= STAIRS_SIDE_COLLISION_MAX_NORMAL_Y:
				saw_side_collision = true
		await get_tree().physics_frame

	var side_travel := probe.global_position.x - start_position.x
	var side_climb := probe.global_position.y - start_position.y
	if side_travel > STAIRS_SIDE_COLLISION_MAX_TRAVEL:
		m_failures.append("HumanBody3D moved %.2f units into Stairs3D side wall" % side_travel)
	if side_climb > STAIRS_SIDE_COLLISION_MAX_CLIMB:
		m_failures.append("HumanBody3D climbed %.2f units onto stairs from the side" % side_climb)
	if !saw_side_collision:
		m_failures.append("HumanBody3D did not report side-wall collision against Stairs3D")

	probe.queue_free()

	var climb_probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if climb_probe == null:
		m_failures.append("Stairs3D front climb probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		stairs.queue_free()
		return
	climb_probe.name = "StairsFrontClimbHumanBody3DProbe"
	climb_probe.visible = false
	climb_probe.body_radius = 0.28
	climb_probe.body_height = 1.72
	add_child(climb_probe)
	await get_tree().physics_frame

	climb_probe.global_position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(3.5, 0.1, -2.7)
	climb_probe.velocity = Vector3.ZERO
	for i in range(8):
		climb_probe.velocity.y = -0.5
		climb_probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var climb_start_position := climb_probe.global_position
	for i in range(STAIRS_FRONT_CLIMB_PROBE_FRAMES):
		climb_probe.velocity.y = -0.5
		climb_probe.move_with_speed(Vector3.BACK, STAIRS_SIDE_COLLISION_PROBE_SPEED)
		await get_tree().physics_frame

	var front_travel := climb_probe.global_position.z - climb_start_position.z
	var front_climb := climb_probe.global_position.y - climb_start_position.y
	if front_travel < STAIRS_FRONT_CLIMB_MIN_TRAVEL:
		m_failures.append("HumanBody3D only advanced %.2f units up Stairs3D from the front" % front_travel)
	if front_climb < STAIRS_FRONT_CLIMB_MIN_HEIGHT:
		m_failures.append("HumanBody3D only climbed %.2f units up Stairs3D from the front" % front_climb)

	climb_probe.queue_free()

	var exit_probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if exit_probe == null:
		m_failures.append("Stairs3D side exit probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		stairs.queue_free()
		return
	exit_probe.name = "StairsSideExitHumanBody3DProbe"
	exit_probe.visible = false
	exit_probe.body_radius = 0.28
	exit_probe.body_height = 1.72
	add_child(exit_probe)
	await get_tree().physics_frame

	exit_probe.global_position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(3.5, 1.22, 1.5)
	exit_probe.velocity = Vector3.ZERO
	for i in range(10):
		exit_probe.velocity.y = -0.5
		exit_probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var exit_start_position := exit_probe.global_position
	exit_probe.jump()
	for i in range(STAIRS_SIDE_EXIT_PROBE_FRAMES):
		exit_probe.move_with_speed(Vector3.LEFT, STAIRS_SIDE_COLLISION_PROBE_SPEED)
		await get_tree().physics_frame

	var side_exit_travel := exit_start_position.x - exit_probe.global_position.x
	if side_exit_travel < STAIRS_SIDE_EXIT_MIN_TRAVEL:
		m_failures.append("HumanBody3D only moved %.2f units when jumping off Stairs3D side" % side_exit_travel)

	exit_probe.queue_free()
	floor_body.queue_free()
	stairs.queue_free()


func _validate_pillar_node(coordinator: Building3DScript) -> void:
	var base_y := 0.75
	var pillar := BuildingFactoryScript.create_pillar_node(coordinator,
		Vector3(6.0, base_y, 12.0),
		0.35,
		2.8,
		6,
		"round",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(pillar)
	if pillar.mesh == null:
		m_failures.append("Pillar3D did not generate a mesh")
		return
	if pillar.mesh.get_surface_count() <= 0:
		m_failures.append("Pillar3D mesh has no surfaces")
		return
	if pillar.position.distance_to(Vector3(6.0, base_y, 12.0)) > 0.001:
		m_failures.append("Pillar3D did not place its transform at the base point")

	var arrays := pillar.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != pillar._effective_side_count() * 10:
		m_failures.append("Pillar3D generated the wrong low-poly vertex count")
	if normals.size() != vertices.size():
		m_failures.append("Pillar3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Pillar3D mesh is missing per-vertex color data")
	if !_has_normal_near(normals, Vector3.UP):
		m_failures.append("Pillar3D mesh is missing top normals")
	if !_has_normal_near(normals, Vector3.DOWN):
		m_failures.append("Pillar3D mesh is missing bottom normals")
	if !_has_horizontal_pillar_normal(normals):
		m_failures.append("Pillar3D mesh is missing side normals")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Pillar3D triangle winding does not match Godot BoxMesh convention")
	if pillar.get_node_or_null("PillarCollision") == null:
		m_failures.append("Pillar3D did not generate collision for placed pillars")

	pillar.set_pillar_base_and_radius(Vector3(7.0, base_y, 13.0), 0.5)
	if pillar.position.distance_to(Vector3(7.0, base_y, 13.0)) > 0.001:
		m_failures.append("Pillar3D did not move transform after edited base point")
	if absf(pillar.pillar_radius - 0.5) > 0.001:
		m_failures.append("Pillar3D did not resize edited radius")

	var square := BuildingFactoryScript.create_pillar_node(coordinator,
		Vector3(8.0, base_y, 12.0),
		0.4,
		2.4,
		12,
		"square",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(square)
	if square.get_pillar_style() != "square":
		m_failures.append("Pillar3D did not store square style")
	if _mesh_vertex_count(square) != 40:
		m_failures.append("Pillar3D square style did not force four low-poly sides")

	var octagonal := BuildingFactoryScript.create_pillar_node(coordinator,
		Vector3(9.0, base_y, 12.0),
		0.4,
		2.4,
		5,
		"octagonal",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(octagonal)
	if _mesh_vertex_count(octagonal) != 80:
		m_failures.append("Pillar3D octagonal style did not force eight low-poly sides")

	var tapered := BuildingFactoryScript.create_pillar_node(coordinator,
		Vector3(10.0, base_y, 12.0),
		0.5,
		2.4,
		8,
		"tapered",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(tapered)
	if _pillar_max_radius_at_y(tapered, 2.4) >= _pillar_max_radius_at_y(tapered, 0.0):
		m_failures.append("Pillar3D tapered style did not narrow the top radius")

	var custom_radii := BuildingFactoryScript.create_pillar_node(coordinator,
		Vector3(10.5, base_y, 12.0),
		0.45,
		2.4,
		8,
		"round",
		Color(0.70, 0.64, 0.52, 1.0),
		0.0,
		0.0,
		0.0,
		0.0,
		0.18
	)
	coordinator.add_child(custom_radii)
	if absf(custom_radii.upper_radius - 0.18) > 0.001:
		m_failures.append("Pillar3D did not store custom upper radius")
	if _pillar_max_radius_at_y(custom_radii, 2.4) >= _pillar_max_radius_at_y(custom_radii, 0.0):
		m_failures.append("Pillar3D custom upper radius did not narrow the top")
	if absf(_pillar_max_radius_at_y(custom_radii, 2.4) - 0.18) > 0.001:
		m_failures.append("Pillar3D custom upper radius did not generate the requested top radius")

	var rimmed := BuildingFactoryScript.create_pillar_node(coordinator,
		Vector3(11.0, base_y, 12.0),
		0.35,
		2.4,
		8,
		"round",
		Color(0.70, 0.64, 0.52, 1.0),
		0.16,
		0.08,
		0.20,
		0.10
	)
	coordinator.add_child(rimmed)
	if _mesh_vertex_count(rimmed) != rimmed._effective_side_count() * 26:
		m_failures.append("Pillar3D rimmed style did not add expected rim geometry")
	if _pillar_max_radius_at_y(rimmed, 0.0) <= rimmed.pillar_radius:
		m_failures.append("Pillar3D lower rim did not expand the base radius")
	if _pillar_max_radius_at_y(rimmed, 2.4) <= rimmed.pillar_radius:
		m_failures.append("Pillar3D upper rim did not expand the top radius")
	if rimmed.get_outer_radius() <= rimmed.pillar_radius:
		m_failures.append("Pillar3D outer radius did not include rim outsets")
	var rim_collision_shape := rimmed.get_node_or_null("PillarCollision/CollisionShape3D") as CollisionShape3D
	var rim_collision: CylinderShape3D = null
	if rim_collision_shape != null:
		rim_collision = rim_collision_shape.shape as CylinderShape3D
	if rim_collision == null or rim_collision.radius + 0.001 < rimmed.get_outer_radius():
		m_failures.append("Pillar3D rimmed collision did not cover the outer rim")


func _validate_roof_node(coordinator: Building3DScript) -> void:
	var base_y := 3.0
	var roof := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(12.0, base_y, 12.0),
		Vector3(16.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	) as GableRoof3DScript
	coordinator.add_child(roof)
	if roof.mesh == null:
		m_failures.append("Roof3D did not generate a mesh")
		return
	if roof.mesh.get_surface_count() <= 0:
		m_failures.append("Roof3D mesh has no surfaces")
		return
	if roof.position.distance_to(Vector3(12.0, base_y, 12.0)) > 0.001:
		m_failures.append("Roof3D did not place its transform at the minimum footprint corner")

	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != 48:
		m_failures.append("Roof3D gable style generated the wrong low-poly vertex count")
	if normals.size() != vertices.size():
		m_failures.append("Roof3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Roof3D mesh is missing per-vertex color data")
	if !_has_roof_upward_normal(normals):
		m_failures.append("Roof3D mesh is missing upward roof normals")
	if !_has_roof_downward_normal(normals):
		m_failures.append("Roof3D mesh is missing underside normals")
	if !_roof_underside_normals_are_down(roof):
		m_failures.append("Roof3D underside triangle normals are inverted")
	if !_has_horizontal_pillar_normal(normals):
		m_failures.append("Roof3D mesh is missing fascia normals")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Roof3D triangle winding does not match Godot BoxMesh convention")
	if roof.get_node_or_null("RoofCollision") == null:
		m_failures.append("Roof3D did not generate collision for placed roofs")
	if roof.get_roof_bounds_min().distance_to(Vector3(-0.25, -0.16, -0.25)) > 0.001:
		m_failures.append("Roof3D bounds did not include overhang and thickness")
	var expected_roof_ridge_height := RoofStyleGeometryFactory.gable_height_for_angle_degrees(
		roof.get_roof_size().y,
		roof.roof_overhang,
		roof.get_roof_angle_degrees()
	)
	if roof.get_roof_bounds_max().distance_to(Vector3(4.25, expected_roof_ridge_height, 3.25)) > 0.001:
		m_failures.append("Roof3D bounds did not include overhang and gable ridge height")
	roof.roof_thickness = 0.38
	roof.rebuild_roof_mesh()
	if absf(roof.get_roof_bounds_min().y + 0.38) > 0.001:
		m_failures.append("Roof3D bounds did not react to roof thickness changes")
	if !_has_mesh_vertex_y_near(roof, -0.38, 0.001):
		m_failures.append("Roof3D mesh did not react to roof thickness changes")
	roof.roof_thickness = 0.16
	roof.rebuild_roof_mesh()

	roof.set_roof_corners(Vector3(13.0, base_y, 12.5), Vector3(17.0, base_y, 16.0))
	if roof.position.distance_to(Vector3(13.0, base_y, 12.5)) > 0.001:
		m_failures.append("Roof3D did not move transform after edited corners")
	if roof.get_roof_size().distance_to(Vector2(4.0, 3.5)) > 0.001:
		m_failures.append("Roof3D did not resize edited footprint")
	var old_roof_center := roof.get_roof_center_point()
	roof.set_roof_rotation_around_center(90.0)
	if absf(angle_difference(deg_to_rad(roof.roof_rotation_degrees), deg_to_rad(90.0))) > deg_to_rad(0.5):
		m_failures.append("Roof3D did not store edited roof rotation")
	if roof.get_roof_center_point().distance_to(old_roof_center) > 0.001:
		m_failures.append("Roof3D did not preserve footprint center when rotating")
	if roof.transform.basis.is_equal_approx(Basis.IDENTITY):
		m_failures.append("Roof3D did not apply rotation to its transform")

	var drawn_base_start := Vector3(18.0, base_y, 16.0)
	var drawn_base_end := Vector3(21.0, base_y, 20.0)
	var drawn_base_points := Roof3DScript.roof_corners_from_base_points(
		drawn_base_start,
		drawn_base_end,
		45.0
	)
	var drawn_base_roof := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(drawn_base_points["start"]),
		Vector3(drawn_base_points["end"]),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.12,
		0.2,
		Color(0.50, 0.34, 0.25, 1.0),
		45.0
	)
	coordinator.add_child(drawn_base_roof)
	if !_roof_base_has_corner_near(drawn_base_roof, drawn_base_start):
		m_failures.append("Roof3D rotated draw base did not preserve the first draw point")
	if !_roof_base_has_corner_near(drawn_base_roof, drawn_base_end):
		m_failures.append("Roof3D rotated draw base did not preserve the current draw point")

	var flat := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(18.0, base_y, 12.0),
		Vector3(21.0, base_y, 14.0),
		"flat",
		1.0,
		0.14,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(flat)
	if flat.get_roof_style() != "flat":
		m_failures.append("Roof3D did not store flat style")
	if _mesh_vertex_count(flat) != 28:
		m_failures.append("Roof3D flat style generated the wrong vertex count")
	var flat_arrays := flat.mesh.surface_get_arrays(0)
	var flat_normals: PackedVector3Array = flat_arrays[Mesh.ARRAY_NORMAL]
	if !_has_normal_near(flat_normals, Vector3.UP):
		m_failures.append("Roof3D flat style is missing a flat top normal")

	var polygon_roof_points := PackedVector3Array([
		Vector3(40.0, base_y, 12.0),
		Vector3(44.0, base_y, 12.0),
		Vector3(44.0, base_y, 14.0),
		Vector3(42.0, base_y, 14.0),
		Vector3(42.0, base_y, 16.0),
		Vector3(40.0, base_y, 16.0),
	])
	var polygon_roof := BuildingFactoryScript.create_flat_roof_polygon_node(
		coordinator,
		polygon_roof_points,
		0.14,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(polygon_roof)
	if !polygon_roof.is_polygon_roof():
		m_failures.append("FlatRoof3D did not store its polygon footprint")
	if polygon_roof.get_roof_polygon() != polygon_roof_points:
		m_failures.append("FlatRoof3D returned the wrong polygon footprint")
	if polygon_roof.position.distance_to(Vector3(40.0, base_y, 12.0)) > 0.001:
		m_failures.append("FlatRoof3D polygon transform did not use its minimum footprint corner")
	if polygon_roof.get_roof_size().distance_to(Vector2(4.0, 4.0)) > 0.001:
		m_failures.append("FlatRoof3D polygon returned the wrong footprint bounds")
	var polygon_render_rect := polygon_roof.get_roof_render_rect()
	if (
		polygon_render_rect.position.distance_to(Vector2(-0.25, -0.25)) > 0.001
		or polygon_render_rect.end.distance_to(Vector2(4.25, 4.25)) > 0.001
	):
		m_failures.append("FlatRoof3D polygon overhang did not offset its outline")
	if polygon_roof.mesh == null:
		m_failures.append("FlatRoof3D polygon did not generate a mesh")
	elif !_roof_underside_normals_are_down(polygon_roof):
		m_failures.append("FlatRoof3D polygon underside normals are inverted")
	if polygon_roof.get_node_or_null("RoofCollision") == null:
		m_failures.append("FlatRoof3D polygon did not generate collision")
	if !polygon_roof.contains_local_plan_point(Vector2(1.0, 3.0)):
		m_failures.append("FlatRoof3D polygon rejected a solid footprint point")
	if polygon_roof.contains_local_plan_point(Vector2(3.0, 3.0)):
		m_failures.append("FlatRoof3D polygon filled its concave footprint notch")

	var reshaped_roof_points := polygon_roof.get_roof_polygon()
	reshaped_roof_points[1] = Vector3(45.0, base_y, 12.0)
	if !polygon_roof.is_roof_polygon_valid(reshaped_roof_points):
		m_failures.append("FlatRoof3D rejected a valid vertex edit")
	else:
		polygon_roof.set_roof_polygon(reshaped_roof_points)
		if polygon_roof.get_roof_size().x < 4.99:
			m_failures.append("FlatRoof3D vertex edit did not reshape the footprint")
	var inserted_roof_points := polygon_roof.get_roof_polygon()
	inserted_roof_points.insert(1, Vector3(42.5, base_y, 12.0))
	polygon_roof.set_roof_polygon(inserted_roof_points)
	if polygon_roof.get_roof_polygon().size() != polygon_roof_points.size() + 1:
		m_failures.append("FlatRoof3D did not add a footprint vertex")
	inserted_roof_points.remove_at(1)
	polygon_roof.set_roof_polygon(inserted_roof_points)
	if polygon_roof.get_roof_polygon().size() != polygon_roof_points.size():
		m_failures.append("FlatRoof3D did not remove a footprint vertex")

	var acute_roof_points := PackedVector3Array([
		Vector3(120.0, base_y, 12.0),
		Vector3(124.0, base_y, 12.0),
		Vector3(122.2, base_y, 12.2),
		Vector3(124.0, base_y, 16.0),
		Vector3(120.0, base_y, 16.0),
	])
	var acute_roof := BuildingFactoryScript.create_flat_roof_polygon_node(
		coordinator,
		acute_roof_points,
		0.14,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(acute_roof)
	var acute_render_polygons := acute_roof.get_roof_render_polygons()
	if (
		acute_render_polygons.size() != 1
		or acute_render_polygons[0].size() != acute_roof_points.size()
	):
		m_failures.append("FlatRoof3D acute overhang added render-outline vertices")
	elif acute_render_polygons[0][1].distance_to(Vector2(4.0, 0.0)) > 1.001:
		m_failures.append("FlatRoof3D acute overhang exceeded its bounded miter")
	if acute_roof.mesh == null:
		m_failures.append("FlatRoof3D acute polygon did not generate a mesh")

	var promoted_flat := BuildingFactoryScript.create_roof_node(
		coordinator,
		Vector3(46.0, base_y, 12.0),
		Vector3(49.0, base_y, 15.0),
		"flat"
	) as FlatRoof3DScript
	coordinator.add_child(promoted_flat)
	if promoted_flat.is_polygon_roof():
		m_failures.append("FlatRoof3D rectangle unexpectedly stored polygon points")
	promoted_flat.set_roof_polygon(PackedVector3Array([
		Vector3(46.0, base_y, 12.0),
		Vector3(49.0, base_y, 12.0),
		Vector3(49.0, base_y, 15.0),
		Vector3(46.0, base_y, 15.0),
	]))
	if !promoted_flat.is_polygon_roof():
		m_failures.append("FlatRoof3D rectangle did not promote to shared polygon editing")
	promoted_flat.set_roof_corners(
		Vector3(46.0, base_y, 12.0),
		Vector3(50.0, base_y, 16.0)
	)
	if promoted_flat.is_polygon_roof():
		m_failures.append("FlatRoof3D rectangle setter did not restore rectangle representation")

	var shed := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(22.0, base_y, 12.0),
		Vector3(25.0, base_y, 14.0),
		"shed",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.12,
		0.1,
		Color(0.50, 0.34, 0.25, 1.0)
	) as SlopedRoof3DScript
	coordinator.add_child(shed)
	if _mesh_vertex_count(shed) != 28:
		m_failures.append("Roof3D shed style generated the wrong vertex count")
	if !_has_roof_sloped_normal(shed):
		m_failures.append("Roof3D shed style is missing sloped roof normals")
	var expected_shed_height := RoofStyleGeometryFactory.shed_height_for_angle_degrees(
		shed.get_roof_size().y,
		shed.roof_overhang,
		shed.get_roof_angle_degrees()
	)
	if !_has_mesh_vertex_y_near(shed, expected_shed_height, 0.001):
		m_failures.append("Roof3D shed style did not calculate height from angle degrees")

	var hip := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(26.0, base_y, 12.0),
		Vector3(31.0, base_y, 15.0),
		"hip",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.12,
		0.15,
		Color(0.50, 0.34, 0.25, 1.0)
	) as HipRoof3DScript
	coordinator.add_child(hip)
	if _mesh_vertex_count(hip) != 52:
		m_failures.append("Roof3D hip style generated the wrong vertex count")
	if !_has_roof_sloped_normal(hip):
		m_failures.append("Roof3D hip style is missing sloped roof normals")
	var expected_hip_height := RoofStyleGeometryFactory.hip_height_for_angle_degrees(
		hip.get_roof_size(),
		hip.roof_overhang,
		hip.get_roof_angle_degrees()
	)
	if !_has_mesh_vertex_y_near(hip, expected_hip_height, 0.001):
		m_failures.append("Roof3D hip style did not calculate height from angle degrees")
	var hip_ridge_points := RoofStyleGeometryFactory.hip_roof_ridge_points_for_size(
		hip.get_roof_size(),
		hip.roof_overhang,
		hip.get_roof_angle_degrees()
	)
	if hip_ridge_points.size() != 2:
		m_failures.append("Roof3D hip style did not report a ridge line")
	else:
		if absf(hip_ridge_points[0].y - hip_ridge_points[1].y) > 0.001:
			m_failures.append("Roof3D hip ridge is not horizontal")
		if hip_ridge_points[0].distance_to(hip_ridge_points[1]) <= 0.001:
			m_failures.append("Roof3D rectangular hip roof collapsed to one apex")
		if !_has_mesh_vertex_near(hip.mesh as ArrayMesh, hip_ridge_points[0], 0.001):
			m_failures.append("Roof3D hip mesh is missing the first ridge endpoint")
		if !_has_mesh_vertex_near(hip.mesh as ArrayMesh, hip_ridge_points[1], 0.001):
			m_failures.append("Roof3D hip mesh is missing the second ridge endpoint")
	var hip_faces := RoofStyleGeometryFactory.roof_top_faces_for_style(
		"hip",
		hip.get_roof_size(),
		hip.roof_overhang,
		{"angle_degrees": hip.get_roof_angle_degrees()}
	)
	var triangular_hip_faces := 0
	var trapezoid_hip_faces := 0
	for hip_face in hip_faces:
		var hip_face_vertices := PackedVector3Array(hip_face["vertices"])
		if hip_face_vertices.size() == 3:
			triangular_hip_faces += 1
		elif hip_face_vertices.size() == 4:
			trapezoid_hip_faces += 1
		var hip_face_angle := _roof_face_angle_degrees(PackedVector3Array(hip_face["plane"]))
		if absf(hip_face_angle - TEST_ROOF_ALT_ANGLE_DEGREES) > 0.01:
			m_failures.append("Roof3D hip face angle changed from configured degrees")
	if triangular_hip_faces != 2 or trapezoid_hip_faces != 2:
		m_failures.append("Roof3D hip style did not generate two triangular and two trapezoid faces")

	var half_hip := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(46.0, base_y, 12.0),
		Vector3(51.0, base_y, 15.0),
		"hip",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.12,
		0.15,
		Color(0.50, 0.34, 0.25, 1.0),
		0.0,
		0.4
	) as HipRoof3DScript
	coordinator.add_child(half_hip)
	if _mesh_vertex_count(half_hip) != 100:
		m_failures.append("Roof3D half-hip style generated the wrong vertex count")
	if !_roof_surface_normals_are_not_down(half_hip):
		m_failures.append("Roof3D half-hip visible surface normals point downward")
	var plain_half_hip_ridge := RoofStyleGeometryFactory.hip_roof_ridge_points_for_size(
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees()
	)
	var clipped_half_hip_ridge := RoofStyleGeometryFactory.hip_roof_ridge_points_for_size(
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees(),
		half_hip.get_hip_gable_height()
	)
	if clipped_half_hip_ridge.size() != 2:
		m_failures.append("Roof3D half-hip style did not report a ridge line")
	else:
		if clipped_half_hip_ridge[0].x >= plain_half_hip_ridge[0].x:
			m_failures.append("Roof3D half-hip did not extend the ridge start")
		if clipped_half_hip_ridge[1].x <= plain_half_hip_ridge[1].x:
			m_failures.append("Roof3D half-hip did not extend the ridge end")
		if !_has_mesh_vertex_near(half_hip.mesh as ArrayMesh, clipped_half_hip_ridge[0], 0.001):
			m_failures.append("Roof3D half-hip mesh is missing the first extended ridge endpoint")
		if !_has_mesh_vertex_near(half_hip.mesh as ArrayMesh, clipped_half_hip_ridge[1], 0.001):
			m_failures.append("Roof3D half-hip mesh is missing the second extended ridge endpoint")
	var half_hip_height := RoofStyleGeometryFactory.hip_height_for_angle_degrees(
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees()
	)
	var half_hip_extension := half_hip.get_hip_gable_height() / tan(deg_to_rad(half_hip.get_roof_angle_degrees()))
	var half_hip_center_z := half_hip.get_roof_size().y * 0.5
	var half_hip_gable_base := Vector3(
		clipped_half_hip_ridge[0].x,
		half_hip_height - half_hip.get_hip_gable_height(),
		half_hip_center_z - half_hip_extension
	)
	if !_has_mesh_vertex_near(half_hip.mesh as ArrayMesh, half_hip_gable_base, 0.001):
		m_failures.append("Roof3D half-hip mesh is missing the clipped gable base")
	if absf(half_hip.get_roof_height_at_local_render_point(Vector2(clipped_half_hip_ridge[0].x, half_hip_center_z)) - half_hip_height) > 0.001:
		m_failures.append("Roof3D half-hip ridge height changed from the hip peak")
	if absf(half_hip.get_roof_height_at_local_render_point(Vector2(half_hip_gable_base.x, half_hip_gable_base.z)) - half_hip_gable_base.y) > 0.001:
		m_failures.append("Roof3D half-hip clipped gable base does not follow configured drop")
	var half_hip_faces := RoofStyleGeometryFactory.roof_top_faces_for_style(
		"hip",
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		{
			"angle_degrees": half_hip.get_roof_angle_degrees(),
			"gable_height_from_peak": half_hip.get_hip_gable_height(),
		}
	)
	var half_hip_sloped_faces := 0
	var half_hip_vertical_faces := 0
	for half_hip_face in half_hip_faces:
		var half_hip_face_angle := _roof_face_angle_degrees(PackedVector3Array(half_hip_face["plane"]))
		if half_hip_face_angle > 89.0:
			half_hip_vertical_faces += 1
		else:
			half_hip_sloped_faces += 1
			if absf(half_hip_face_angle - TEST_ROOF_ALT_ANGLE_DEGREES) > 0.01:
				m_failures.append("Roof3D half-hip sloped face angle changed from configured degrees")
	if half_hip_sloped_faces != 4 or half_hip_vertical_faces != 2:
		m_failures.append("Roof3D half-hip did not generate four sloped faces and two clipped gables")

	var angle_roof := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(40.0, base_y, 16.0),
		Vector3(44.0, base_y, 19.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.12,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	) as GableRoof3DScript
	coordinator.add_child(angle_roof)
	var original_angle_degrees := angle_roof.get_roof_angle_degrees()
	var preserved_angle_covers: Array[Rect2] = []
	angle_roof.set_roof_corners_rotation_parameters_and_covers(
		angle_roof.start_point,
		angle_roof.start_point + Vector3(4.0, 0.0, 6.0),
		angle_roof.roof_rotation_degrees,
		{"angle_degrees": angle_roof.get_roof_angle_degrees()},
		preserved_angle_covers
	)
	var expected_resized_ridge_height := RoofStyleGeometryFactory.gable_height_for_angle_degrees(
		angle_roof.get_roof_size().y,
		angle_roof.roof_overhang,
		original_angle_degrees
	)
	if absf(angle_roof.get_roof_angle_degrees() - original_angle_degrees) > 0.001:
		m_failures.append("Roof3D gable angle changed after depth-preserving resize")
	if !is_equal_approx(angle_roof.get_roof_angle_degrees(), original_angle_degrees):
		m_failures.append("Roof3D did not keep the stored gable angle")
	if !_has_mesh_vertex_y_near(angle_roof, expected_resized_ridge_height, 0.001):
		m_failures.append("Roof3D did not recalculate gable ridge height from angle degrees")

	var merge_color := Color(0.42, 0.30, 0.22, 1.0)
	var merge_target := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(30.0, base_y, 12.0),
		Vector3(34.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	) as GableRoof3DScript
	coordinator.add_child(merge_target)
	var merge_candidate_start := Vector3(33.0, base_y, 13.0)
	var merge_candidate_end := Vector3(36.0, base_y, 17.0)
	var merge := coordinator.find_roof_merge_target(
		merge_candidate_start,
		merge_candidate_end,
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if merge.is_empty():
		m_failures.append("Roof3D did not detect an intersecting roof merge target")
	else:
		var covered_rects: Array[Rect2] = []
		for rect in merge["covered_rects"]:
			covered_rects.append(rect)
		var typed_covered_polygons: Array[PackedVector2Array] = []
		for polygon in merge["covered_polygons"]:
			typed_covered_polygons.append(PackedVector2Array(polygon))
		var covered_polygons: Array = merge["covered_polygons"]
		var expected_overlap := Rect2(Vector2(-0.25, -0.25), Vector2(1.5, 2.5))
		var covered_overlap_area := _covered_polygon_area(covered_polygons)
		if covered_overlap_area <= 0.001:
			m_failures.append("Roof3D merge cover did not include any expected under-roof area")
		if covered_overlap_area >= expected_overlap.get_area() - 0.001:
			m_failures.append("Roof3D merge cover removed the whole overlap instead of only the under-roof area")
		if covered_polygons.is_empty():
			m_failures.append("Roof3D merge cover did not report polygon regions")
		if covered_polygons.size() > 8 or _polygon_vertex_count(covered_polygons) > 48:
			m_failures.append(
				"Roof3D merge cover created too many small polygon pieces: %d polygons, %d vertices"
				% [covered_polygons.size(), _polygon_vertex_count(covered_polygons)]
			)
		if !_cover_polygons_sample_under_other_roof(
			covered_polygons,
			merge_candidate_start,
			merge_candidate_end,
			"gable",
			TEST_ROOF_ANGLE_DEGREES,
			0.25,
			0.0,
			coordinator.get_roof_nodes()
		):
			m_failures.append("Roof3D merge cover removed sampled roof surface above another roof")
		var clipped_merge_roof := BuildingFactoryScript.create_roof_node(coordinator,
			merge_candidate_start,
			merge_candidate_end,
			"gable",
			TEST_ROOF_ANGLE_DEGREES,
			0.42,
			0.25,
			merge_color
		)
		clipped_merge_roof.set_covered_regions(covered_rects, typed_covered_polygons)
		if !_has_internal_roof_fascia_facing_cover(clipped_merge_roof, typed_covered_polygons):
			m_failures.append("Roof3D clipped roof intersection-cut normals point the wrong way")
		if !_roof_underside_normals_are_down(clipped_merge_roof):
			m_failures.append("Roof3D clipped roof underside normals are inverted")
		if !_has_mesh_vertex_y_near(clipped_merge_roof, -0.42, 0.001):
			m_failures.append("Roof3D clipped roof mesh did not use configured thickness")
		clipped_merge_roof.free()

	var angle_merge := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 13.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		merge_target.get_roof_angle_degrees(),
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if angle_merge.is_empty():
		m_failures.append("Roof3D did not clip gables with matching angle")
	var angle_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 13.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if angle_mismatch.is_empty():
		m_failures.append("Roof3D did not clip gables with different angles")

	var clipped := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(37.0, base_y, 12.0),
		Vector3(40.0, base_y, 15.0),
		"flat",
		0.0,
		0.12,
		0.0,
		merge_color
	)
	var clipped_covers: Array[Rect2] = [Rect2(Vector2(1.0, 1.0), Vector2(1.0, 1.0))]
	clipped.set_covered_rects(clipped_covers)
	coordinator.add_child(clipped)
	if clipped.get_covered_rects().size() != 1:
		m_failures.append("Roof3D did not store covered roof footprint areas")
	if clipped.get_visible_footprint_rects().size() != 4:
		m_failures.append("Roof3D did not report the visible clipped footprint pieces")
	if _mesh_vertex_count(clipped) <= 28:
		m_failures.append("Roof3D did not split clipped roof geometry into visible pieces")

	var clipped_gable := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(37.0, base_y, 16.0),
		Vector3(41.0, base_y, 20.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.12,
		0.2,
		merge_color
	) as GableRoof3DScript
	var clipped_gable_covers: Array[Rect2] = [Rect2(Vector2.ZERO, Vector2(1.0, 1.0))]
	clipped_gable.set_covered_rects(clipped_gable_covers)
	coordinator.add_child(clipped_gable)
	if !_has_roof_sloped_normal(clipped_gable):
		m_failures.append("Roof3D clipped gable lost its sloped roof normals")
	var clipped_gable_ridge_height := RoofStyleGeometryFactory.gable_height_for_angle_degrees(
		clipped_gable.get_roof_size().y,
		clipped_gable.roof_overhang,
		clipped_gable.get_roof_angle_degrees()
	)
	if !_has_mesh_vertex_y_near(clipped_gable, clipped_gable_ridge_height, 0.001):
		m_failures.append("Roof3D clipped gable lost its ridge-height vertices")

	var mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"hip",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if mismatch.is_empty():
		m_failures.append("Roof3D did not clip roofs with different styles")
	var rotation_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	if rotation_mismatch.is_empty():
		m_failures.append("Roof3D did not clip roofs with different rotations")
	else:
		var rotation_polygons: Array = rotation_mismatch["covered_polygons"]
		if rotation_polygons.is_empty():
			m_failures.append("Roof3D rotated intersection did not report polygon cover regions")
		if !_cover_polygons_have_non_axis_edge(rotation_polygons):
			m_failures.append("Roof3D rotated intersection kept a zigzag axis-aligned cover edge")
		if rotation_polygons.size() > 8 or _polygon_vertex_count(rotation_polygons) > 48:
			m_failures.append(
				"Roof3D rotated intersection created too many small polygon pieces: %d polygons, %d vertices"
				% [rotation_polygons.size(), _polygon_vertex_count(rotation_polygons)]
			)
	var near_rotation_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.25
	)
	if near_rotation_mismatch.is_empty():
		m_failures.append("Roof3D did not clip roofs with near-but-not-equal rotations")

	var rotated_merge_target := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(40.0, base_y, 12.0),
		Vector3(44.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	coordinator.add_child(rotated_merge_target)
	var rotated_basis := Basis(Vector3.UP, deg_to_rad(90.0))
	var rotated_new_start := rotated_merge_target.get_roof_anchor_point() + rotated_basis * Vector3(1.0, 0.0, 1.0)
	var rotated_merge := coordinator.find_roof_merge_target(
		rotated_new_start,
		rotated_new_start + Vector3(4.0, 0.0, 3.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	if rotated_merge.is_empty():
		m_failures.append("Roof3D did not detect an intersecting rotated roof merge target")
	else:
		if rotated_merge["roof"] != rotated_merge_target:
			m_failures.append("Roof3D rotated merge target selected the wrong roof")
		if absf(angle_difference(deg_to_rad(float(rotated_merge["rotation_degrees"])), deg_to_rad(90.0))) > deg_to_rad(0.5):
			m_failures.append("Roof3D rotated merge did not preserve roof rotation")
		var rotated_covers: Array = rotated_merge["covered_rects"]
		if rotated_covers.is_empty():
			m_failures.append("Roof3D rotated merge did not report covered roof geometry")

	var full_cover_target := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(50.0, base_y, 20.0),
		Vector3(54.0, base_y, 24.0),
		"flat",
		0.0,
		0.12,
		0.2,
		merge_color
	)
	coordinator.add_child(full_cover_target)
	var full_cover := coordinator.find_roof_merge_target(
		Vector3(50.0, base_y, 20.0),
		Vector3(54.0, base_y, 24.0),
		"flat",
		0.0,
		0.12,
		0.2,
		merge_color,
		0.0
	)
	if full_cover.is_empty():
		m_failures.append("Roof3D did not detect fully covered matching roof geometry")
	else:
		var full_cover_rects: Array[Rect2] = []
		var full_cover_polygons: Array[PackedVector2Array] = []
		var full_cover_values: Array = full_cover["covered_rects"]
		for rect in full_cover_values:
			full_cover_rects.append(rect)
		var full_cover_polygon_values: Array = full_cover["covered_polygons"]
		for polygon in full_cover_polygon_values:
			full_cover_polygons.append(PackedVector2Array(polygon))
		if coordinator.roof_has_visible_cover_area(
			Vector3(50.0, base_y, 20.0),
			Vector3(54.0, base_y, 24.0),
			0.2,
			full_cover_rects,
			full_cover_polygons
		):
			m_failures.append("Roof3D treated fully covered roof geometry as visible")
		var duplicate_full_cover := BuildingFactoryScript.create_roof_node(coordinator,
			Vector3(50.0, base_y, 20.0),
			Vector3(54.0, base_y, 24.0),
			"flat",
			0.0,
			0.12,
			0.2,
			merge_color
		)
		duplicate_full_cover.set_covered_regions(full_cover_rects, full_cover_polygons)
		if duplicate_full_cover.has_visible_roof_geometry():
			m_failures.append("Roof3D generated visible mesh for a fully covered roof")
		duplicate_full_cover.free()

	var touch_target := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(50.0, base_y, 12.0),
		Vector3(54.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	)
	coordinator.add_child(touch_target)
	var touch_merge := coordinator.find_roof_merge_target(
		Vector3(54.0, base_y, 12.0),
		Vector3(58.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if touch_merge.is_empty():
		m_failures.append("Roof3D did not merge touching roof overhang geometry")
	else:
		var touch_values: Array = touch_merge["covered_rects"]
		var touch_cover: Rect2 = touch_values[0]
		if absf(touch_cover.position.x + 0.25) > 0.001 or absf(touch_cover.size.x - 0.5) > 0.001:
			m_failures.append("Roof3D touching overhang cover has the wrong X range")

	var gap_merge := coordinator.find_roof_merge_target(
		Vector3(54.3, base_y, 12.0),
		Vector3(58.3, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if gap_merge.is_empty():
		m_failures.append("Roof3D did not merge separated but overlapping roof overhang geometry")
	else:
		var gap_values: Array = gap_merge["covered_rects"]
		var gap_cover: Rect2 = gap_values[0]
		if absf(gap_cover.position.x + 0.25) > 0.001 or absf(gap_cover.size.x - 0.2) > 0.001:
			m_failures.append("Roof3D separated overhang cover has the wrong X range")

	var stale_covering := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(60.0, base_y, 12.0),
		Vector3(64.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	)
	coordinator.add_child(stale_covering)
	var stale_clipped := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(63.0, base_y, 14.0),
		Vector3(66.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	) as GableRoof3DScript
	var stale_cover_regions := coordinator.compute_roof_cover_regions(
		stale_clipped.start_point,
		stale_clipped.end_point,
		stale_clipped.get_roof_style(),
		stale_clipped.get_roof_angle_degrees(),
		stale_clipped.roof_thickness,
		stale_clipped.roof_overhang,
		stale_clipped.roof_color,
		stale_clipped.roof_rotation_degrees
	)
	var stale_rects: Array[Rect2] = []
	for rect in stale_cover_regions.get("covered_rects", []):
		stale_rects.append(rect)
	var stale_polygons: Array[PackedVector2Array] = []
	for polygon in stale_cover_regions.get("covered_polygons", []):
		stale_polygons.append(PackedVector2Array(polygon))
	stale_clipped.set_covered_regions(stale_rects, stale_polygons)
	coordinator.add_child(stale_clipped)
	if stale_clipped.get_covered_rects().is_empty():
		m_failures.append("Roof3D stale-cover setup did not create an initial clip")
	stale_covering.set_roof_corners(Vector3(70.0, base_y, 12.0), Vector3(74.0, base_y, 15.0))
	coordinator.refresh_roof_covered_rects()
	if !stale_clipped.get_covered_rects().is_empty():
		m_failures.append("Roof3D did not clear stale roof covers after refresh")


func _validate_merge_detection(coordinator: Building3DScript) -> void:
	var merge: Dictionary = coordinator.find_merge_target(Vector3(2.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0), 0.22, 2.4)
	if merge.is_empty():
		m_failures.append("Building3D did not find an overlapping collinear merge target")
		return
	var merged_end := Vector3(merge["end"])
	if merged_end.distance_to(Vector3(6.0, 0.0, 0.0)) > 0.001:
		m_failures.append("Building3D merge target did not extend to the outer end point")

	var height_mismatch: Dictionary = coordinator.find_merge_target(
		Vector3(2.0, 0.0, 0.0),
		Vector3(6.0, 0.0, 0.0),
		0.22,
		3.0
	)
	if !height_mismatch.is_empty():
		m_failures.append("Building3D merged walls with mismatched heights")

	var base_mismatch: Dictionary = coordinator.find_merge_target(
		Vector3(2.0, 1.25, 0.0),
		Vector3(6.0, 1.25, 0.0),
		0.22,
		2.4
	)
	if !base_mismatch.is_empty():
		m_failures.append("Building3D merged walls with mismatched base heights")

	var preview := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(8.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		2.4,
		0.22,
		Color.WHITE
	)
	preview.name = "WallPreview"
	coordinator.add_child(preview)
	var ignored_merge: Dictionary = coordinator.find_merge_target(
		Vector3(8.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		0.22,
		2.4,
		preview
	)
	coordinator.remove_child(preview)
	preview.queue_free()
	if !ignored_merge.is_empty():
		m_failures.append("Building3D treated the active wall preview as a merge target")


func _validate_intersection_merge() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "MergeCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 40.0)
	add_child(coordinator)

	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var survivor := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(survivor)

	var crossing_hits: Array = coordinator.find_intersecting_walls(
		Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 2.0), 0.22
	)
	if crossing_hits.size() != 1 or crossing_hits[0] != survivor:
		m_failures.append("Building3D did not detect a crossing wall span as intersecting")
	var far_hits: Array = coordinator.find_intersecting_walls(
		Vector3(10.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 0.22
	)
	if !far_hits.is_empty():
		m_failures.append("Building3D flagged a distant wall span as intersecting")

	var crossing := WallSegmentScript.new()
	crossing.start_point = Vector3(0.0, 0.0, -2.0)
	crossing.end_point = Vector3(0.0, 0.0, 2.0)
	crossing.thickness = 0.22
	crossing.height = 2.4
	crossing.color = wall_color
	var split_source: Array[WallSegmentScript] = [survivor.get_segment(0), crossing]
	var split_segments := WallSegmentScript.split_at_intersections(split_source, 0.125)
	if split_segments.size() != 4:
		m_failures.append("WallSegment did not split a crossing into four editable spans")
	if _endpoint_count(split_segments, Vector3.ZERO) != 4:
		m_failures.append("WallSegment did not create shared endpoints at the crossing point")
	if _endpoint_count_for_axis(split_segments, Vector3.ZERO, Vector2.RIGHT) != 2:
		m_failures.append("WallSegment did not add endpoints to the intersected horizontal segment")
	if _endpoint_count_for_axis(split_segments, Vector3.ZERO, Vector2.DOWN) != 2:
		m_failures.append("WallSegment did not add endpoints to the crossing vertical segment")
	var split_primary := split_segments[0]
	var split_extras: Array[WallSegmentScript] = []
	for split_index in range(1, split_segments.size()):
		split_extras.append(split_segments[split_index])
	survivor.set_wall_endpoints(split_primary.start_point, split_primary.end_point)
	survivor.extra_segments = split_extras
	survivor.rebuild_wall_mesh()

	if survivor.get_segment_count() != 4:
		m_failures.append("Wall3D did not keep the split absorbed crossing segments")
	if survivor.mesh == null or survivor.mesh.get_surface_count() <= 0:
		m_failures.append("Multi-segment Wall3D did not generate a merged mesh")
		return
	if survivor.get_node_or_null("WallCollision") == null:
		m_failures.append("Multi-segment Wall3D did not generate collision")

	var top_area := _up_facing_area(survivor.mesh as ArrayMesh, 2.4)
	var expected_area := 4.0 * 0.22 + 4.0 * 0.22 - 0.22 * 0.22
	if absf(top_area - expected_area) > 0.05:
		m_failures.append(
			"Merged wall top cap area %.4f deviates from expected %.4f" % [top_area, expected_area]
		)

	var collinear_segments: Array[WallSegmentScript] = []
	var span_a := WallSegmentScript.new()
	span_a.start_point = Vector3.ZERO
	span_a.end_point = Vector3(4.0, 0.0, 0.0)
	collinear_segments.append(span_a)
	var span_b := WallSegmentScript.new()
	span_b.start_point = Vector3(2.0, 0.0, 0.0)
	span_b.end_point = Vector3(6.0, 0.0, 0.0)
	WallSegmentScript.merge_into(collinear_segments, span_b, 0.125)
	if collinear_segments.size() != 1:
		m_failures.append("WallSegment.merge_into did not extend a collinear overlapping span")
	elif collinear_segments[0].end_point.distance_to(Vector3(6.0, 0.0, 0.0)) > 0.001:
		m_failures.append("WallSegment.merge_into did not extend to the outer end point")

	var opening_frame: Transform3D = survivor.get_segment_local_frame(1)
	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "MergedSegmentOpening"
	opening.opening_width = 1.0
	opening.opening_height = 1.0
	opening.position = opening_frame * Vector3(1.0, 1.1, 0.145)
	survivor.add_child(opening)
	survivor.rebuild_wall_mesh()

	if survivor.can_place_opening(Vector2(1.0, 1.1), Vector2(0.8, 0.8), 0.03, null, 1):
		m_failures.append("Multi-segment wall allowed an overlapping opening on an extra segment")
	if !survivor.can_place_opening(Vector2(1.8, 1.1), Vector2(0.25, 0.8), 0.03, null, 1):
		m_failures.append("Multi-segment wall rejected a valid opening on an extra segment")

	# Openings sitting on the primary span's face near the junction must stay
	# assigned to the primary span, not the crossing segment whose centerline
	# they happen to be close to (wall-local junction is at x = 2).
	var junction_opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	junction_opening.name = "JunctionOpening"
	junction_opening.opening_width = 0.6
	junction_opening.opening_height = 0.6
	junction_opening.position = Vector3(2.05, 1.1, 0.145)
	survivor.add_child(junction_opening)
	if survivor.get_opening_segment_index(junction_opening) != 0:
		m_failures.append("Opening near a junction was assigned to the crossing segment")
	survivor.remove_child(junction_opening)
	junction_opening.free()

	# A window straddling the junction would be blocked by the crossing
	# segment's solid mass, so placement must be rejected.
	if survivor.can_place_opening(Vector2(2.0, 1.1), Vector2(0.8, 0.8), 0.03, null, 0):
		m_failures.append("Opening straddling a junction was not rejected")
	if !survivor.can_place_opening(Vector2(0.8, 1.1), Vector2(0.6, 0.8), 0.03, null, 0):
		m_failures.append("Valid primary-span opening away from the junction was rejected")


func _validate_wall_instance_intersection_clipping() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "WallClipCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 48.0)
	add_child(coordinator)

	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var horizontal := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(horizontal)
	var vertical := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 2.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(vertical)
	coordinator.refresh_wall_intersection_clips()

	if horizontal.get_parent() != coordinator or vertical.get_parent() != coordinator:
		m_failures.append("Intersecting wall clipping removed a wall instance")
	if horizontal.get_segment_count() != 1 or vertical.get_segment_count() != 1:
		m_failures.append("Intersecting wall clipping absorbed segments into a wall instance")
	if horizontal.get_intersection_clip_segment_count() != 1:
		m_failures.append("Horizontal wall did not receive the crossing wall as geometry-only clip data")
	if vertical.get_intersection_clip_segment_count() != 1:
		m_failures.append("Vertical wall did not receive the crossing wall as geometry-only clip data")
	if horizontal.mesh == null or vertical.mesh == null:
		m_failures.append("Geometry-only intersecting wall clipping did not generate both meshes")
		return

	var total_top_area := (
		_up_facing_area(horizontal.mesh as ArrayMesh, horizontal.wall_height)
		+ _up_facing_area(vertical.mesh as ArrayMesh, vertical.wall_height)
	)
	var expected_top_area := 4.0 * 0.22 + 4.0 * 0.22 - 0.22 * 0.22
	if absf(total_top_area - expected_top_area) > 0.02:
		m_failures.append(
			"Separate intersecting wall top caps %.4f deviate from clipped expected %.4f"
			% [total_top_area, expected_top_area]
		)
	if horizontal.can_place_opening(Vector2(2.0, 1.1), Vector2(0.4, 0.6), 0.03, null, 0):
		m_failures.append("Separate intersecting wall allowed an opening through sibling wall geometry")
	if !horizontal.can_place_opening(Vector2(0.6, 1.1), Vector2(0.3, 0.6), 0.03, null, 0):
		m_failures.append("Separate intersecting wall rejected an opening away from sibling geometry")


func _validate_serialized_building_mesh_caches() -> void:
	var source_root := Building3DScript.new() as Building3DScript
	source_root.name = "CachedBuildingParts"
	var source_wall := BuildingFactoryScript.create_wall_node(
		source_root,
		Vector3.ZERO,
		Vector3(4.0, 0.0, 0.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	source_wall.name = "CachedWall"
	source_root.add_child(source_wall)
	source_wall.owner = source_root
	var source_floor := BuildingFactoryScript.create_floor_node(
		source_root,
		Vector3(0.0, 0.0, 2.0),
		Vector3(3.0, 0.0, 5.0)
	)
	source_floor.name = "CachedFloor"
	source_root.add_child(source_floor)
	source_floor.owner = source_root
	var source_polygon_floor := BuildingFactoryScript.create_floor_polygon_node(
		source_root,
		PackedVector3Array([
			Vector3(0.0, 0.0, 7.0),
			Vector3(3.0, 0.0, 7.0),
			Vector3(2.0, 0.0, 9.0),
			Vector3(0.0, 0.0, 9.0),
		])
	)
	source_polygon_floor.name = "CachedPolygonFloor"
	source_root.add_child(source_polygon_floor)
	source_polygon_floor.owner = source_root
	var cached_source_holes: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(0.5, 0.5),
			Vector2(1.5, 0.5),
			Vector2(1.0, 1.2),
		])
	]
	source_polygon_floor.set_floor_hole_polygons(cached_source_holes)
	var source_stairs := BuildingFactoryScript.create_stairs_node(
		source_root,
		Vector3(5.0, 0.0, 0.0),
		Vector3(7.0, 0.0, 4.0)
	)
	source_stairs.name = "CachedStairs"
	source_root.add_child(source_stairs)
	source_stairs.owner = source_root
	var source_rail := BuildingFactoryScript.create_rail_node(
		source_root,
		Vector3(9.0, 0.0, 0.0),
		Vector3(13.0, 0.0, 0.0)
	)
	source_rail.name = "CachedRail"
	source_root.add_child(source_rail)
	source_rail.owner = source_root
	var source_pillar := BuildingFactoryScript.create_pillar_node(
		source_root,
		Vector3(15.0, 0.0, 0.0),
		0.3,
		2.4,
		8,
		"round"
	)
	source_pillar.name = "CachedPillar"
	source_root.add_child(source_pillar)
	source_pillar.owner = source_root
	var source_roof := BuildingFactoryScript.create_roof_node(
		source_root,
		Vector3(17.0, 2.4, 0.0),
		Vector3(21.0, 2.4, 4.0),
		"gable"
	)
	source_roof.name = "CachedRoof"
	source_root.add_child(source_roof)
	source_roof.owner = source_root
	var source_opening := SingleWindow3DScript.new() as BuildingOpening3DScript
	source_opening.name = "CachedOpening"
	source_opening._rebuild()
	source_root.add_child(source_opening)
	source_opening.owner = source_root
	var packed_scene := PackedScene.new()
	if packed_scene.pack(source_root) != OK:
		m_failures.append("Could not pack the serialized building-mesh cache regression scene")
		source_root.free()
		return
	source_root.free()

	var cached_instance := packed_scene.instantiate() as Node3D
	add_child(cached_instance)
	var cached_mesh_nodes := [
		cached_instance.get_node("CachedWall"),
		cached_instance.get_node("CachedFloor"),
		cached_instance.get_node("CachedPolygonFloor"),
		cached_instance.get_node("CachedStairs"),
		cached_instance.get_node("CachedRail"),
		cached_instance.get_node("CachedPillar"),
		cached_instance.get_node("CachedRoof"),
	]
	for cached_node in cached_mesh_nodes:
		if cached_node.get_mesh_rebuild_count() != 0:
			m_failures.append(
				"Loading an unchanged serialized %s rebuilt its cached mesh"
				% cached_node.get_class()
			)
	var cached_opening := cached_instance.get_node("CachedOpening") as BuildingOpening3DScript
	if cached_opening.get_geometry_rebuild_count() != 0:
		m_failures.append("Loading an unchanged opening rebuilt its cached part geometry")
	if cached_opening.get_node_or_null("WindowPane") == null:
		m_failures.append("Loading a cached window did not restore its generated pane")
	var cached_wall := cached_instance.get_node("CachedWall") as Wall3DScript
	var cached_floor := cached_instance.get_node("CachedFloor") as Floor3DScript
	var cached_polygon_floor := cached_instance.get_node("CachedPolygonFloor") as Floor3DScript
	if cached_polygon_floor.get_floor_hole_polygons().size() != 1:
		m_failures.append("Loading a cached polygon floor did not restore its polygon hole")
	var cached_stairs := cached_instance.get_node("CachedStairs") as Stairs3DScript
	var cached_rail := cached_instance.get_node("CachedRail") as Rail3DScript
	var cached_pillar := cached_instance.get_node("CachedPillar") as Pillar3DScript
	var cached_roof := cached_instance.get_node("CachedRoof") as Roof3DScript
	cached_wall.set_wall_endpoints(cached_wall.start_point, cached_wall.end_point)
	cached_floor.set_floor_corners(cached_floor.start_point, cached_floor.end_point)
	cached_polygon_floor.set_floor_polygon(cached_polygon_floor.get_floor_polygon())
	cached_polygon_floor.set_floor_hole_polygons(cached_polygon_floor.get_floor_hole_polygons())
	cached_stairs.set_stair_rotation_degrees(cached_stairs.stair_rotation_degrees)
	cached_rail.set_rail_points(cached_rail.start_point, cached_rail.end_point)
	cached_pillar.set_pillar_radius(cached_pillar.pillar_radius)
	cached_roof.set_covered_regions(
		cached_roof.get_covered_rects(),
		cached_roof.get_covered_polygons()
	)
	for cached_node in cached_mesh_nodes:
		if cached_node.get_mesh_rebuild_count() != 0:
			m_failures.append(
				"An unchanged %s setter rebuilt cached geometry"
				% cached_node.get_class()
			)

	var changed_instance := packed_scene.instantiate() as Node3D
	var changed_wall := changed_instance.get_node("CachedWall") as Wall3DScript
	var cached_segment := cached_wall.get_segment(0)
	var changed_segment := changed_wall.get_segment(0)
	if cached_segment == changed_segment:
		m_failures.append("Packed Building3D instances shared a WallSegment resource")
	changed_segment.end_point = Vector3(5.0, 0.0, 0.0)
	if cached_segment.end_point.is_equal_approx(changed_segment.end_point):
		m_failures.append("Editing one Building3D instance changed another instance's wall")
	var changed_floor := changed_instance.get_node("CachedFloor") as Floor3DScript
	changed_floor.floor_thickness += 0.05
	var changed_polygon_floor := changed_instance.get_node("CachedPolygonFloor") as Floor3DScript
	var changed_polygon_points := changed_polygon_floor.get_floor_polygon()
	changed_polygon_points[2].x += 0.5
	changed_polygon_floor.set_floor_polygon(changed_polygon_points)
	var changed_stairs := changed_instance.get_node("CachedStairs") as Stairs3DScript
	changed_stairs.step_count += 1
	var changed_rail := changed_instance.get_node("CachedRail") as Rail3DScript
	changed_rail.post_spacing += 0.1
	var changed_pillar := changed_instance.get_node("CachedPillar") as Pillar3DScript
	changed_pillar.pillar_radius += 0.05
	var changed_roof := changed_instance.get_node("CachedRoof") as Roof3DScript
	changed_roof.roof_overhang += 0.05
	var changed_opening := changed_instance.get_node("CachedOpening") as SingleWindow3DScript
	changed_opening.window_pane_depth += 0.02
	add_child(changed_instance)
	var changed_mesh_nodes := [
		changed_wall,
		changed_floor,
		changed_polygon_floor,
		changed_stairs,
		changed_rail,
		changed_pillar,
		changed_roof,
	]
	for changed_node in changed_mesh_nodes:
		if changed_node.get_mesh_rebuild_count() == 0:
			m_failures.append(
				"Loading a changed %s reused stale cached geometry"
				% changed_node.get_class()
			)
	for index in range(cached_mesh_nodes.size()):
		if cached_mesh_nodes[index].mesh == changed_mesh_nodes[index].mesh:
			m_failures.append(
				"Rebuilding %s mutated a mesh resource shared with another scene instance"
				% changed_mesh_nodes[index].get_class()
			)
	if changed_opening.get_geometry_rebuild_count() == 0:
		m_failures.append("Loading a changed opening reused stale cached part geometry")
	var cached_pane := cached_opening.get_node_or_null("WindowPane") as MeshInstance3D
	var changed_pane := changed_opening.get_node_or_null("WindowPane") as MeshInstance3D
	if cached_pane != null and changed_pane != null and cached_pane.mesh == changed_pane.mesh:
		m_failures.append("Rebuilding an opening reused a part mesh from another scene instance")


func _validate_event_driven_geometry_refresh() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "EventDrivenGeometryCoordinator"
	add_child(coordinator)
	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var horizontal := BuildingFactoryScript.create_wall_node(
		coordinator,
		Vector3(-2.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
		4.0,
		0.22,
		wall_color
	)
	var horizontal_build_count := horizontal.get_mesh_rebuild_count()
	coordinator.add_child(horizontal)
	if horizontal.get_mesh_rebuild_count() != horizontal_build_count:
		m_failures.append("Wall3D rebuilt an already-current serialized mesh in _ready()")
	var vertical := BuildingFactoryScript.create_wall_node(
		coordinator,
		Vector3(0.0, 0.0, -2.0),
		Vector3(0.0, 0.0, 2.0),
		4.0,
		0.22,
		wall_color
	)
	coordinator.add_child(vertical)
	await _wait_for_geometry_refresh()
	if horizontal.get_intersection_clip_segment_count() != 1:
		m_failures.append("Signal-driven refresh did not assign an intersecting wall clip")
	var unchanged_horizontal_build_count := horizontal.get_mesh_rebuild_count()
	var unchanged_vertical_build_count := vertical.get_mesh_rebuild_count()
	coordinator.refresh_building_geometry_clips()
	if (
		horizontal.get_mesh_rebuild_count() != unchanged_horizontal_build_count
		or vertical.get_mesh_rebuild_count() != unchanged_vertical_build_count
	):
		m_failures.append("Unchanged clipping conditions rebuilt wall meshes")

	var vertical_segment := vertical.get_segment(0)
	vertical_segment.start_point = Vector3(6.0, 8.0, -2.0)
	vertical_segment.end_point = Vector3(6.0, 8.0, 2.0)
	await _wait_for_geometry_refresh()
	if horizontal.get_intersection_clip_segment_count() != 0:
		m_failures.append("Segment geometry signal did not clear a stale wall clip")
	if horizontal.get_mesh_rebuild_count() <= unchanged_horizontal_build_count:
		m_failures.append("Changed wall clipping conditions did not rebuild the affected mesh")

	var roof := BuildingFactoryScript.create_roof_node(
		coordinator,
		Vector3(-2.0, 2.4, -2.0),
		Vector3(2.0, 2.4, 2.0),
		"gable",
		40.0,
		0.2,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(roof)
	await _wait_for_geometry_refresh()
	if horizontal.get_roof_clip_surface_count() == 0:
		m_failures.append("Signal-driven refresh did not assign a roof clip surface")
	var roof_clipped_build_count := horizontal.get_mesh_rebuild_count()
	var unchanged_roof_build_count := roof.get_mesh_rebuild_count()
	coordinator.refresh_building_geometry_clips()
	if horizontal.get_mesh_rebuild_count() != roof_clipped_build_count:
		m_failures.append("Unchanged roof clipping conditions rebuilt a wall mesh")
	if roof.get_mesh_rebuild_count() != unchanged_roof_build_count:
		m_failures.append("Unchanged roof cover conditions rebuilt a roof mesh")
	roof.set_roof_corners(Vector3(8.0, 2.4, -2.0), Vector3(12.0, 2.4, 2.0))
	await _wait_for_geometry_refresh()
	if horizontal.get_roof_clip_surface_count() != 0:
		m_failures.append("Roof geometry signal did not clear a stale wall clip surface")
	if horizontal.get_mesh_rebuild_count() <= roof_clipped_build_count:
		m_failures.append("Changed roof clipping conditions did not rebuild the affected mesh")

	var owner_wall := BuildingFactoryScript.create_wall_node(
		coordinator,
		Vector3(0.0, 0.0, 8.0),
		Vector3(6.0, 0.0, 8.0),
		2.4,
		0.22,
		wall_color
	)
	coordinator.add_child(owner_wall)
	var clipped_wall := BuildingFactoryScript.create_wall_node(
		coordinator,
		Vector3(3.0, 0.0, 8.0),
		Vector3(9.0, 0.0, 8.0),
		2.4,
		0.22,
		wall_color
	)
	coordinator.add_child(clipped_wall)
	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.opening_width = 0.8
	opening.opening_height = 0.8
	opening.position = Vector3(1.5, 1.1, 0.145)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
	clipped_wall.add_child(opening)
	await _wait_for_geometry_refresh()
	var initial_rects := owner_wall.get_render_opening_rects(0)
	if initial_rects.is_empty():
		m_failures.append("Opening child signal did not propagate a collinear wall cut")
		return
	var initial_center_x := initial_rects[0].get_center().x
	opening.position.x += 0.5
	await _wait_for_geometry_refresh()
	var moved_rects := owner_wall.get_render_opening_rects(0)
	if moved_rects.is_empty():
		m_failures.append("Opening transform signal removed its propagated wall cut")
	elif absf(moved_rects[0].get_center().x - initial_center_x - 0.5) > 0.001:
		m_failures.append("Opening transform signal did not move its propagated wall cut")


func _wait_for_geometry_refresh() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _validate_roof_wall_clipping() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "RoofWallClipCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 56.0)
	add_child(coordinator)

	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var wall := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(0.0, 0.0, 0.2),
		Vector3(4.0, 0.0, 0.2),
		4.0,
		0.22,
		wall_color
	)
	coordinator.add_child(wall)
	var roof := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(0.0, 2.4, 0.0),
		Vector3(4.0, 2.4, 4.0),
		"gable",
		45.0,
		0.20,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(roof)
	coordinator.refresh_building_geometry_clips()

	if wall.get_roof_clip_surface_count() != 1:
		m_failures.append("Wall3D did not receive roof underside clip data")
	if _wall_has_vertex_above_roof_underside(wall, roof, 0.025):
		m_failures.append("Wall3D kept geometry above the intersecting roof underside")
	if wall.get_node_or_null("WallCollision") == null:
		m_failures.append("Roof-clipped Wall3D lost generated collision")

	var gable_end_wall := BuildingFactoryScript.create_wall_node(
		coordinator,
		Vector3(18.0, 0.0, 0.2),
		Vector3(18.0, 0.0, 3.8),
		5.0,
		0.22,
		wall_color
	)
	coordinator.add_child(gable_end_wall)
	var gable_end_roof := BuildingFactoryScript.create_roof_node(
		coordinator,
		Vector3(16.0, 2.4, 0.0),
		Vector3(20.0, 2.4, 4.0),
		"gable",
		45.0,
		0.20,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(gable_end_roof)
	coordinator.refresh_building_geometry_clips()
	if _wall_has_sloped_up_face(gable_end_wall):
		m_failures.append("Gable-end wall generated hidden roof-closure triangles")
	var retained_surface_samples := [
		{
			"point": coordinator.to_global(Vector3(17.89, 1.0, 0.6)),
			"normal": Vector3.LEFT,
		},
		{
			"point": coordinator.to_global(Vector3(17.89, 3.5, 2.0)),
			"normal": Vector3.LEFT,
		},
		{
			"point": coordinator.to_global(Vector3(17.89, 1.0, 3.4)),
			"normal": Vector3.LEFT,
		},
		{
			"point": coordinator.to_global(Vector3(18.11, 1.0, 0.6)),
			"normal": Vector3.RIGHT,
		},
		{
			"point": coordinator.to_global(Vector3(18.11, 3.5, 2.0)),
			"normal": Vector3.RIGHT,
		},
		{
			"point": coordinator.to_global(Vector3(18.11, 1.0, 3.4)),
			"normal": Vector3.RIGHT,
		},
	]
	for retained_sample in retained_surface_samples:
		var retained_point: Vector3 = retained_sample["point"]
		var retained_normal: Vector3 = retained_sample["normal"]
		if !_wall_mesh_contains_surface_point(gable_end_wall, retained_point):
			m_failures.append(
				"Gable clipping removed wall geometry below the roof at %s"
				% retained_point
			)
		elif !_wall_mesh_contains_surface_point(
			gable_end_wall,
			retained_point,
			0.002,
			retained_normal
		):
			m_failures.append(
				"Gable-clipped exterior wall face has the wrong normal at %s"
				% retained_point
			)
	if (
		!_wall_face_winding_matches_normal(gable_end_wall, Vector3.LEFT)
		or !_wall_face_winding_matches_normal(gable_end_wall, Vector3.RIGHT)
	):
		m_failures.append("Gable-clipped exterior wall face winding does not match its normal")
	var gable_collision := gable_end_wall.get_node_or_null(
		"WallCollision/CollisionShape3D"
	) as CollisionShape3D
	if (
		gable_collision == null
		or !(gable_collision.shape is ConcavePolygonShape3D)
	):
		m_failures.append("Gable-clipped wall collision did not preserve the sloped wall volume")

	var partial_wall := BuildingFactoryScript.create_wall_node(
		coordinator,
		Vector3(0.0, 0.0, 12.0),
		Vector3(10.0, 0.0, 12.0),
		4.0,
		0.22,
		wall_color
	)
	coordinator.add_child(partial_wall)
	var partial_roof := BuildingFactoryScript.create_roof_node(
		coordinator,
		Vector3(3.0, 2.5, 11.0),
		Vector3(7.0, 2.5, 13.0),
		"flat",
		0.0,
		0.20,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(partial_roof)
	coordinator.refresh_building_geometry_clips()
	for exposed_x in [1.0, 9.0]:
		var exposed_point := coordinator.to_global(Vector3(exposed_x, 3.5, 11.89))
		if !_wall_mesh_contains_surface_point(partial_wall, exposed_point):
			m_failures.append(
				"Middle roof clipping damaged the uncovered wall at x=%s"
				% exposed_x
			)
	var covered_high_point := coordinator.to_global(Vector3(5.0, 3.5, 11.89))
	if _wall_mesh_contains_surface_point(partial_wall, covered_high_point):
		m_failures.append("Middle roof clipping kept wall geometry above the roof")
	var covered_low_point := coordinator.to_global(Vector3(5.0, 2.0, 11.89))
	if !_wall_mesh_contains_surface_point(partial_wall, covered_low_point):
		m_failures.append("Middle roof clipping removed the retained wall below the roof")

	roof.set_roof_corners(Vector3(8.0, 2.4, 0.0), Vector3(12.0, 2.4, 4.0))
	coordinator.refresh_building_geometry_clips()
	if wall.get_roof_clip_surface_count() != 0:
		m_failures.append("Wall3D kept stale roof clip data after roof moved away")
	if !_has_mesh_vertex_y_near(wall, 4.0, 0.001):
		m_failures.append("Wall3D did not restore full height after roof clip cleared")

	var eave_wall := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0),
		2.8,
		0.22,
		wall_color
	)
	coordinator.add_child(eave_wall)
	var eave_roof := BuildingFactoryScript.create_roof_node(coordinator,
		Vector3(0.0, 2.4, 0.0),
		Vector3(4.0, 2.4, 4.0),
		"gable",
		45.0,
		0.20,
		0.20,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(eave_roof)
	coordinator.refresh_building_geometry_clips()
	if eave_wall.get_roof_clip_surface_count() != 1:
		m_failures.append("Wall3D did not receive roof clip data for an eave-line wall")
	if _wall_has_vertex_above_roof_underside(eave_wall, eave_roof, 0.025):
		m_failures.append("Wall3D kept eave-line geometry above the roof underside")


func _validate_add_wall_joint() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "AddJointWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(4.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "JointSplitOpening"
	opening.opening_width = 0.5
	opening.opening_height = 0.5
	opening.position = Vector3(3.0, 1.1, wall.wall_thickness * 0.5 + 0.035)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
	wall.add_child(opening)
	wall.rebuild_wall_mesh()

	var old_opening_position := opening.global_position
	if !wall.split_segment_at_point(0, Vector3(2.0, 0.0, 0.0), 0.1):
		m_failures.append("Wall3D could not add a joint to a wall span")
		return
	if wall.get_segment_count() != 2:
		m_failures.append("Wall3D joint insertion did not split the wall into two segments")
	if wall.count_connected_endpoints(Vector3(2.0, 0.0, 0.0), 0.03) != 2:
		m_failures.append("Wall3D joint insertion did not create a shared endpoint")
	if opening.global_position.distance_to(old_opening_position) > 0.001:
		m_failures.append("Wall3D joint insertion moved an existing window opening")
	if wall.get_opening_segment_index(opening) != 1:
		m_failures.append("Wall3D joint insertion did not reassign opening to split segment")

	var moved_joint := Vector3(2.0, 0.0, 1.0)
	var moved_count := wall.move_connected_endpoint(Vector3(2.0, 0.0, 0.0), moved_joint, 0.03)
	if moved_count != 2:
		m_failures.append("Wall3D added joint moved %d endpoints instead of 2" % moved_count)
	if wall.count_connected_endpoints(moved_joint, 0.03) != 2:
		m_failures.append("Wall3D added joint did not stay editable after dragging")

	var touching_segments: Array[WallSegmentScript] = []
	var first := WallSegmentScript.new()
	first.start_point = Vector3.ZERO
	first.end_point = Vector3(2.0, 0.0, 0.0)
	touching_segments.append(first)
	var second := WallSegmentScript.new()
	second.start_point = Vector3(2.0, 0.0, 0.0)
	second.end_point = Vector3(4.0, 0.0, 0.0)
	WallSegmentScript.merge_into(touching_segments, second, 0.125, false)
	if touching_segments.size() != 2:
		m_failures.append("WallSegment collapsed an intentional end-to-end joint")


func _validate_mitered_joint() -> void:
	var corner := Wall3DScript.new() as Wall3DScript
	corner.name = "MiteredCorner"
	corner.build_on_ready = false
	corner.start_point = Vector3.ZERO
	corner.end_point = Vector3(2.0, 0.0, 0.0)
	corner.wall_height = 2.4
	corner.wall_thickness = 0.22
	corner.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(corner)

	var extra := WallSegmentScript.new()
	extra.start_point = Vector3.ZERO
	extra.end_point = Vector3(0.0, 0.0, 2.0)
	extra.height = corner.wall_height
	extra.thickness = corner.wall_thickness
	extra.color = corner.wall_color
	var extras: Array[WallSegmentScript] = [extra]
	corner.extra_segments = extras
	corner.rebuild_wall_mesh()

	if corner.mesh == null or corner.mesh.get_surface_count() <= 0:
		m_failures.append("Mitered wall joint did not generate a mesh")
		return
	var half_thickness := corner.wall_thickness * 0.5
	var start_start_plus_intersection := Vector3(
		half_thickness,
		corner.wall_height,
		half_thickness
	)
	var start_start_minus_intersection := Vector3(
		-half_thickness,
		corner.wall_height,
		-half_thickness
	)
	if !_has_mesh_vertex_near(
		corner.mesh as ArrayMesh,
		start_start_plus_intersection,
		0.004
	):
		m_failures.append("Mitered wall joint did not create the plus-side miter corner")
	if !_has_mesh_vertex_near(
		corner.mesh as ArrayMesh,
		start_start_minus_intersection,
		0.004
	):
		m_failures.append("Mitered wall joint did not create the minus-side miter corner")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_plus_intersection,
		Vector3.BACK,
		0.004
	):
		m_failures.append("Mitered wall side did not extend to the plus-side intersection")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_minus_intersection,
		Vector3.FORWARD,
		0.004
	):
		m_failures.append("Mitered wall side did not extend to the minus-side intersection")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_plus_intersection,
		Vector3.RIGHT,
		0.004
	):
		m_failures.append("Mitered partner side did not extend to the plus-side intersection")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_minus_intersection,
		Vector3.LEFT,
		0.004
	):
		m_failures.append("Mitered partner side did not extend to the minus-side intersection")
	if _has_diagonal_wall_normal(corner.mesh as ArrayMesh):
		m_failures.append("Mitered wall joint generated an unwanted diagonal joint cap")

	var end_start_corner := Wall3DScript.new() as Wall3DScript
	end_start_corner.name = "MiteredEndStartCorner"
	end_start_corner.build_on_ready = false
	end_start_corner.start_point = Vector3(-2.0, 0.0, 0.0)
	end_start_corner.end_point = Vector3.ZERO
	end_start_corner.wall_height = 2.4
	end_start_corner.wall_thickness = 0.22
	end_start_corner.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(end_start_corner)

	var end_start_extra := WallSegmentScript.new()
	end_start_extra.start_point = Vector3.ZERO
	end_start_extra.end_point = Vector3(0.0, 0.0, 2.0)
	end_start_extra.height = end_start_corner.wall_height
	end_start_extra.thickness = end_start_corner.wall_thickness
	end_start_extra.color = end_start_corner.wall_color
	var end_start_extras: Array[WallSegmentScript] = [end_start_extra]
	end_start_corner.extra_segments = end_start_extras
	end_start_corner.rebuild_wall_mesh()

	if end_start_corner.mesh == null or end_start_corner.mesh.get_surface_count() <= 0:
		m_failures.append("End-start mitered wall joint did not generate a mesh")
		return
	var end_start_primary_plus_intersection := Vector3(
		2.0 - half_thickness,
		end_start_corner.wall_height,
		half_thickness
	)
	var end_start_primary_minus_intersection := Vector3(
		2.0 + half_thickness,
		end_start_corner.wall_height,
		-half_thickness
	)
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_plus_intersection,
		Vector3.BACK,
		0.004
	):
		m_failures.append("End-start primary side did not extend to the plus-side miter point")
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_minus_intersection,
		Vector3.FORWARD,
		0.004
	):
		m_failures.append("End-start primary side did not extend to the minus-side miter point")
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_plus_intersection,
		Vector3.LEFT,
		0.004
	):
		m_failures.append("End-start partner side did not extend to the plus-side miter point")
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_minus_intersection,
		Vector3.RIGHT,
		0.004
	):
		m_failures.append("End-start partner side did not extend to the minus-side miter point")


func _validate_miter_draw_direction_invariance() -> void:
	var cases := [
		{
			"name": "ForwardCorner",
			"primary_start": Vector3.ZERO,
			"primary_end": Vector3(2.0, 0.0, 0.0),
			"partner_start": Vector3.ZERO,
			"partner_end": Vector3(0.0, 0.0, 2.0),
		},
		{
			"name": "ReversedPrimaryCorner",
			"primary_start": Vector3(2.0, 0.0, 0.0),
			"primary_end": Vector3.ZERO,
			"partner_start": Vector3.ZERO,
			"partner_end": Vector3(0.0, 0.0, 2.0),
		},
		{
			"name": "ReversedPartnerCorner",
			"primary_start": Vector3.ZERO,
			"primary_end": Vector3(2.0, 0.0, 0.0),
			"partner_start": Vector3(0.0, 0.0, 2.0),
			"partner_end": Vector3.ZERO,
		},
		{
			"name": "ReversedBothCorner",
			"primary_start": Vector3(2.0, 0.0, 0.0),
			"primary_end": Vector3.ZERO,
			"partner_start": Vector3(0.0, 0.0, 2.0),
			"partner_end": Vector3.ZERO,
		},
	]
	for case_data in cases:
		var case_name := String(case_data["name"])
		var primary_start: Vector3 = case_data["primary_start"]
		var primary_end: Vector3 = case_data["primary_end"]
		var partner_start: Vector3 = case_data["partner_start"]
		var partner_end: Vector3 = case_data["partner_end"]
		var corner := _create_miter_test_wall(
			case_name,
			primary_start,
			primary_end,
			partner_start,
			partner_end
		)
		if corner.mesh == null or corner.mesh.get_surface_count() <= 0:
			m_failures.append("%s did not generate a mesh" % case_name)
			continue
		var half_thickness := corner.wall_thickness * 0.5
		var expected_a := Vector3(half_thickness, corner.wall_height, half_thickness)
		var expected_b := Vector3(-half_thickness, corner.wall_height, -half_thickness)
		if !_has_world_mesh_vertex_near(corner, expected_a, 0.004):
			m_failures.append("%s missed the draw-direction-invariant first miter point" % case_name)
		if !_has_world_mesh_vertex_near(corner, expected_b, 0.004):
			m_failures.append("%s missed the draw-direction-invariant second miter point" % case_name)
		if _has_world_diagonal_wall_normal(corner):
			m_failures.append("%s generated a direction-dependent diagonal joint cap" % case_name)
		var boundary_edge_count := _world_nonbase_boundary_edge_count(corner)
		if boundary_edge_count > 0:
			m_failures.append(
				"%s left %d open miter boundary edges above the wall base"
				% [case_name, boundary_edge_count]
			)


func _create_miter_test_wall(
	wall_name: String,
	primary_start: Vector3,
	primary_end: Vector3,
	partner_start: Vector3,
	partner_end: Vector3
) -> Wall3DScript:
	var corner := Wall3DScript.new() as Wall3DScript
	corner.name = wall_name
	corner.build_on_ready = false
	corner.start_point = primary_start
	corner.end_point = primary_end
	corner.wall_height = 2.4
	corner.wall_thickness = 0.22
	corner.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(corner)

	var extra := WallSegmentScript.new()
	extra.start_point = partner_start
	extra.end_point = partner_end
	extra.height = corner.wall_height
	extra.thickness = corner.wall_thickness
	extra.color = corner.wall_color
	var extras: Array[WallSegmentScript] = [extra]
	corner.extra_segments = extras
	corner.rebuild_wall_mesh()
	return corner


func _validate_joint_endpoint_drag() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "JointDragWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(2.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var north := WallSegmentScript.new()
	north.start_point = Vector3.ZERO
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = wall.wall_height
	north.thickness = wall.wall_thickness
	north.color = wall.wall_color
	var west := WallSegmentScript.new()
	west.start_point = Vector3.ZERO
	west.end_point = Vector3(-2.0, 0.0, 0.0)
	west.height = wall.wall_height
	west.thickness = wall.wall_thickness
	west.color = wall.wall_color
	var isolated := WallSegmentScript.new()
	isolated.start_point = Vector3(4.0, 0.0, 0.0)
	isolated.end_point = Vector3(6.0, 0.0, 0.0)
	isolated.height = wall.wall_height
	isolated.thickness = wall.wall_thickness
	isolated.color = wall.wall_color
	var extras: Array[WallSegmentScript] = [north, west, isolated]
	wall.extra_segments = extras

	var moved_joint := Vector3(1.0, 0.0, 1.0)
	var moved_count := wall.move_connected_endpoint(Vector3.ZERO, moved_joint, 0.03)
	if moved_count != 3:
		m_failures.append("Wall3D joint drag moved %d endpoints instead of 3" % moved_count)
	if wall.count_connected_endpoints(moved_joint, 0.03) != 3:
		m_failures.append("Wall3D joint drag did not preserve a shared editable endpoint")
	if wall.start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("Wall3D joint drag did not move the primary endpoint")
	if wall.extra_segments[0].start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("Wall3D joint drag did not move the first connected segment")
	if wall.extra_segments[1].start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("Wall3D joint drag did not move the second connected segment")
	if wall.end_point.distance_to(Vector3(2.0, 0.0, 0.0)) > 0.001:
		m_failures.append("Wall3D joint drag moved an unconnected primary endpoint")
	if wall.extra_segments[2].start_point.distance_to(Vector3(4.0, 0.0, 0.0)) > 0.001:
		m_failures.append("Wall3D joint drag moved an unrelated segment endpoint")


func _validate_joint_disconnect_connect() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "JointConnectWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(2.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var north := WallSegmentScript.new()
	north.start_point = Vector3.ZERO
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = wall.wall_height
	north.thickness = wall.wall_thickness
	north.color = wall.wall_color
	var west := WallSegmentScript.new()
	west.start_point = Vector3.ZERO
	west.end_point = Vector3(-2.0, 0.0, 0.0)
	west.height = wall.wall_height
	west.thickness = wall.wall_thickness
	west.color = wall.wall_color
	var extras: Array[WallSegmentScript] = [north, west]
	wall.extra_segments = extras

	var detached := Vector3(1.0, 0.0, 1.0)
	if !wall.move_segment_endpoint(1, 0, detached):
		m_failures.append("Wall3D could not detach a single endpoint from a joint")
	if wall.count_connected_endpoints(Vector3.ZERO, 0.03) != 2:
		m_failures.append("Wall3D detach did not leave the other joint endpoints connected")
	if wall.count_connected_endpoints(detached, 0.03) != 1:
		m_failures.append("Wall3D detach did not isolate the moved endpoint")
	if wall.extra_segments[1].start_point.distance_to(Vector3.ZERO) > 0.001:
		m_failures.append("Wall3D detach moved a different connected endpoint")

	if !wall.move_segment_endpoint(1, 0, Vector3.ZERO):
		m_failures.append("Wall3D could not reconnect a single endpoint to a joint")
	if wall.count_connected_endpoints(Vector3.ZERO, 0.03) != 3:
		m_failures.append("Wall3D reconnect did not restore the shared joint")


func _validate_connected_wall_top_caps() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "ConnectedTopCaps"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(0.5, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var start_partner := WallSegmentScript.new()
	start_partner.start_point = Vector3.ZERO
	start_partner.end_point = Vector3(0.0, 0.0, -1.5)
	start_partner.height = wall.wall_height
	start_partner.thickness = wall.wall_thickness
	start_partner.color = wall.wall_color
	var end_partner := WallSegmentScript.new()
	end_partner.start_point = Vector3(0.5, 0.0, 0.0)
	end_partner.end_point = Vector3(0.5, 0.0, 1.5)
	end_partner.height = wall.wall_height
	end_partner.thickness = wall.wall_thickness
	end_partner.color = wall.wall_color
	var extras: Array[WallSegmentScript] = [start_partner, end_partner]
	wall.extra_segments = extras
	wall.rebuild_wall_mesh()

	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		m_failures.append("Connected top-cap wall did not generate a mesh")
		return
	var mesh := wall.mesh as ArrayMesh
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(0.25, 0.0), wall.wall_height):
		m_failures.append("Connected short wall span lost its top face")
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(0.0, -0.75), wall.wall_height):
		m_failures.append("Connected start partner wall lost its top face")
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(0.5, 0.75), wall.wall_height):
		m_failures.append("Connected end partner wall lost its top face")


func _validate_multi_wall_joint_fill() -> void:
	var joint := Wall3DScript.new() as Wall3DScript
	joint.name = "ThreeWallJoint"
	joint.build_on_ready = false
	joint.start_point = Vector3.ZERO
	joint.end_point = Vector3(2.0, 0.0, 0.0)
	joint.wall_height = 2.4
	joint.wall_thickness = 0.22
	joint.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(joint)

	var north := WallSegmentScript.new()
	north.start_point = Vector3.ZERO
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = joint.wall_height
	north.thickness = joint.wall_thickness
	north.color = joint.wall_color
	var west := WallSegmentScript.new()
	west.start_point = Vector3.ZERO
	west.end_point = Vector3(-2.0, 0.0, 0.0)
	west.height = joint.wall_height
	west.thickness = joint.wall_thickness
	west.color = joint.wall_color
	var extras: Array[WallSegmentScript] = [north, west]
	joint.extra_segments = extras
	joint.rebuild_wall_mesh()

	if joint.mesh == null or joint.mesh.get_surface_count() <= 0:
		m_failures.append("Three-wall mitered joint did not generate a mesh")
		return
	var half_thickness := joint.wall_thickness * 0.5
	if !_has_horizontal_face_covering_plan_point(
		joint.mesh as ArrayMesh,
		Vector2(-half_thickness * 0.5, 0.0),
		joint.wall_height
	):
		m_failures.append("Three-wall joint did not fill the central join top")
	if !_has_horizontal_face_covering_plan_point(
		joint.mesh as ArrayMesh,
		Vector2(half_thickness * 0.5, -half_thickness * 0.5),
		joint.wall_height
	):
		m_failures.append("Three-wall joint did not fill the continuous wall side of the join")
	if !_has_horizontal_face_covering_plan_point(
		joint.mesh as ArrayMesh,
		Vector2(0.0, half_thickness * 0.5),
		joint.wall_height
	):
		m_failures.append("Three-wall joint did not fill the branch wall side of the join")
	if _has_diagonal_wall_normal(joint.mesh as ArrayMesh):
		m_failures.append("Three-wall joint generated internal vertical cap geometry")


func _validate_enclosed_wall_loop_caps() -> void:
	var loop := Wall3DScript.new() as Wall3DScript
	loop.name = "EnclosedWallLoop"
	loop.build_on_ready = false
	loop.start_point = Vector3.ZERO
	loop.end_point = Vector3(2.0, 0.0, 0.0)
	loop.wall_height = 2.4
	loop.wall_thickness = 0.22
	loop.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(loop)

	var east := WallSegmentScript.new()
	east.start_point = Vector3(2.0, 0.0, 0.0)
	east.end_point = Vector3(2.0, 0.0, 2.0)
	east.height = loop.wall_height
	east.thickness = loop.wall_thickness
	east.color = loop.wall_color
	var north := WallSegmentScript.new()
	north.start_point = Vector3(2.0, 0.0, 2.0)
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = loop.wall_height
	north.thickness = loop.wall_thickness
	north.color = loop.wall_color
	var west := WallSegmentScript.new()
	west.start_point = Vector3(0.0, 0.0, 2.0)
	west.end_point = Vector3.ZERO
	west.height = loop.wall_height
	west.thickness = loop.wall_thickness
	west.color = loop.wall_color
	var extras: Array[WallSegmentScript] = [east, north, west]
	loop.extra_segments = extras
	loop.rebuild_wall_mesh()

	if loop.mesh == null or loop.mesh.get_surface_count() <= 0:
		m_failures.append("Enclosed wall loop did not generate a mesh")
		return
	var mesh := loop.mesh as ArrayMesh
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(1.0, -loop.wall_thickness * 0.25), loop.wall_height):
		m_failures.append("Enclosed wall loop lost the south wall top cap")
	if _has_horizontal_face_covering_plan_point(mesh, Vector2(1.0, 1.0), loop.wall_height):
		m_failures.append("Enclosed wall loop filled the room interior instead of keeping only walls")


func _validate_overlapping_room_wall_clipping() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "OverlappingRoomCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 72.0)
	add_child(coordinator)
	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var first_room := BuildingFactoryScript.create_room_node(coordinator,
		Vector3.ZERO,
		Vector3(6.0, 0.0, 4.0),
		2.4,
		0.22,
		wall_color
	)
	coordinator.add_child(first_room)
	var second_room := BuildingFactoryScript.create_room_node(coordinator,
		Vector3(3.0, 0.0, 4.0),
		Vector3(8.0, 0.0, 8.0),
		2.4,
		0.22,
		wall_color
	)
	coordinator.add_child(second_room)
	coordinator.refresh_wall_intersection_clips()

	var shared_wall_point := Vector3(4.5, 0.0, 4.0)
	var first_local := first_room.transform.affine_inverse() * shared_wall_point
	var second_local := second_room.transform.affine_inverse() * shared_wall_point
	if !_has_horizontal_face_covering_plan_point(
		first_room.mesh as ArrayMesh,
		Vector2(first_local.x, first_local.z),
		first_room.wall_height
	):
		m_failures.append("Earlier room lost the shared overlapping wall geometry")
	if _has_horizontal_face_covering_plan_point(
		second_room.mesh as ArrayMesh,
		Vector2(second_local.x, second_local.z),
		second_room.wall_height
	):
		m_failures.append("Later room kept duplicate geometry along the shared overlapping wall")
	if !coordinator.can_place_wall_opening(
		first_room,
		2,
		Vector2(1.5, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("Building3D rejected an opening on the first room's shared wall")
	if !coordinator.can_place_wall_opening(
		second_room,
		0,
		Vector2(1.5, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("Building3D blocked an opening on the clipped collinear shared wall")
	if !coordinator.can_place_wall_opening(
		first_room,
		0,
		Vector2(2.0, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("Building3D rejected an opening on a non-overlapping room wall")
	coordinator.refresh_wall_intersection_clips()
	if !coordinator.can_place_wall_opening(
		first_room,
		2,
		Vector2(1.5, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("Shared room wall rejected an opening after intersection clipping refresh")
	if _has_horizontal_face_covering_plan_point(
		second_room.mesh as ArrayMesh,
		Vector2(second_local.x, second_local.z),
		second_room.wall_height
	):
		m_failures.append("Shared room wall duplicate returned when generic intersection clipping was disabled")


func _up_facing_area(array_mesh: ArrayMesh, expected_height: float) -> float:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return 0.0
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area := 0.0
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if normals[i0].dot(Vector3.UP) < 0.9:
			continue
		if absf(vertices[i0].y - expected_height) > 0.01:
			continue
		var a := vertices[i0]
		var b := vertices[i1]
		var c := vertices[i2]
		area += ((b - a).cross(c - a)).length() * 0.5
	return area


func _has_mesh_vertex_near(array_mesh: ArrayMesh, expected: Vector3, tolerance: float) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		if vertex.distance_to(expected) <= tolerance:
			return true
	return false


func _has_world_mesh_vertex_near(
	wall: Wall3DScript,
	expected: Vector3,
	tolerance: float
) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		var world_vertex := wall.global_transform * vertex
		if world_vertex.distance_to(expected) <= tolerance:
			return true
	return false


func _has_mesh_vertex_with_normal_near(
	array_mesh: ArrayMesh,
	expected: Vector3,
	expected_normal: Vector3,
	tolerance: float
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in range(vertices.size()):
		if vertices[index].distance_to(expected) > tolerance:
			continue
		if normals[index].dot(expected_normal) > 0.98:
			return true
	return false


func _has_rect_near(rects: Array[Rect2], expected: Rect2) -> bool:
	for rect in rects:
		if rect.position.distance_to(expected.position) > 0.001:
			continue
		if rect.size.distance_to(expected.size) <= 0.001:
			return true
	return false


func _has_vertical_face_covering_plan_edge_point(
	array_mesh: ArrayMesh,
	point: Vector2,
	expected_normal: Vector3
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if normals[i0].dot(expected_normal) < 0.98:
			continue
		var a := vertices[i0]
		var b := vertices[i1]
		var c := vertices[i2]
		if absf(expected_normal.x) > 0.9:
			if (
				absf(a.x - point.x) > 0.001
				or absf(b.x - point.x) > 0.001
				or absf(c.x - point.x) > 0.001
			):
				continue
			if _triangle_range_contains(a.z, b.z, c.z, point.y) and _triangle_range_spans_y(a, b, c):
				return true
		elif absf(expected_normal.z) > 0.9:
			if (
				absf(a.z - point.y) > 0.001
				or absf(b.z - point.y) > 0.001
				or absf(c.z - point.y) > 0.001
			):
				continue
			if _triangle_range_contains(a.x, b.x, c.x, point.x) and _triangle_range_spans_y(a, b, c):
				return true
	return false


func _triangle_range_contains(a: float, b: float, c: float, value: float) -> bool:
	return value >= minf(a, minf(b, c)) - 0.001 and value <= maxf(a, maxf(b, c)) + 0.001


func _triangle_range_spans_y(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var min_y := minf(a.y, minf(b.y, c.y))
	var max_y := maxf(a.y, maxf(b.y, c.y))
	return min_y < -0.01 and max_y > -0.001


func _has_normal_near(normals: PackedVector3Array, expected_normal: Vector3) -> bool:
	for normal in normals:
		if normal.dot(expected_normal) > 0.98:
			return true
	return false


func _has_roof_upward_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if normal.y > 0.45:
			return true
	return false


func _has_roof_downward_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if normal.y < -0.45:
			return true
	return false


func _roof_face_angle_degrees(plane_points: PackedVector3Array) -> float:
	if plane_points.size() < 3:
		return -1.0
	var normal := (plane_points[1] - plane_points[0]).cross(plane_points[2] - plane_points[0]).normalized()
	return rad_to_deg(acos(clampf(absf(normal.y), 0.0, 1.0)))


func _mesh_vertex_count(mesh_instance: MeshInstance3D) -> int:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return 0
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()


func _has_mesh_vertex_y_near(mesh_instance: MeshInstance3D, expected_y: float, tolerance: float) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		if absf(vertex.y - expected_y) <= tolerance:
			return true
	return false


func _wall_has_vertex_above_roof_underside(
	wall: Wall3DScript,
	roof: Roof3DScript,
	tolerance: float
) -> bool:
	if wall == null or roof == null:
		return false
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var roof_basis := Basis(Vector3.UP, deg_to_rad(roof.roof_rotation_degrees))
	var roof_inverse := roof_basis.inverse()
	var roof_anchor := roof.get_roof_anchor_point()
	var roof_rect := roof.get_roof_render_rect()
	for vertex in vertices:
		var parent_point := wall.transform * vertex
		var roof_local := roof_inverse * (parent_point - roof_anchor)
		var roof_plan := Vector2(roof_local.x, roof_local.z)
		if !_rect_contains_point_with_tolerance(roof_rect, roof_plan, 0.001):
			continue
		var underside_y := (
			roof.start_point.y
			+ roof.get_roof_height_at_local_render_point(roof_plan)
			- roof.roof_thickness
		)
		if parent_point.y > underside_y + tolerance:
			return true
	return false


func _rect_contains_point_with_tolerance(rect: Rect2, point: Vector2, tolerance: float) -> bool:
	var rect_max := rect.position + rect.size
	return (
		point.x >= rect.position.x - tolerance
		and point.y >= rect.position.y - tolerance
		and point.x <= rect_max.x + tolerance
		and point.y <= rect_max.y + tolerance
	)


func _validate_shared_debug_wireframes(coordinator: Building3DScript) -> void:
	var test_root := Node3D.new()
	test_root.name = "DebugWireframeTestRoot"
	coordinator.add_child(test_root)
	var nodes: Array[Node3D] = []

	var wall := BuildingFactoryScript.create_wall_node(
		test_root,
		Vector3.ZERO,
		Vector3(3.0, 0.0, 0.0)
	)
	test_root.add_child(wall)
	nodes.append(wall)
	var floor := BuildingFactoryScript.create_floor_node(
		test_root,
		Vector3(4.0, 0.0, 0.0),
		Vector3(7.0, 0.0, 2.0)
	)
	test_root.add_child(floor)
	nodes.append(floor)
	var stairs := BuildingFactoryScript.create_stairs_node(
		test_root,
		Vector3(8.0, 0.0, 0.0),
		Vector3(11.0, 0.0, 2.0)
	)
	test_root.add_child(stairs)
	nodes.append(stairs)
	var rail := BuildingFactoryScript.create_rail_node(
		test_root,
		Vector3(12.0, 0.0, 0.0),
		Vector3(15.0, 0.0, 0.0)
	)
	test_root.add_child(rail)
	nodes.append(rail)
	var pillar := BuildingFactoryScript.create_pillar_node(
		test_root,
		Vector3(16.0, 0.0, 0.0),
		0.3,
		2.4
	)
	test_root.add_child(pillar)
	nodes.append(pillar)
	var roof := BuildingFactoryScript.create_roof_node(
		test_root,
		Vector3(18.0, 2.4, 0.0),
		Vector3(22.0, 2.4, 3.0)
	)
	test_root.add_child(roof)
	nodes.append(roof)
	var opening := GridWindow3DScript.new() as BuildingOpening3DScript
	opening.build_on_ready = false
	opening._rebuild()
	test_root.add_child(opening)
	nodes.append(opening)

	for node in nodes:
		_validate_debug_wireframe_node(node)
	test_root.queue_free()


func _validate_debug_wireframe_node(node: Node3D) -> void:
	var label := node.get_class()
	var rebuild_before := _debug_wireframe_rebuild_count(node)
	var child_ids_before := _non_wireframe_descendant_ids(node)
	node.call(
		"set_debug_wireframe",
		true,
		Color(0.12, 0.84, 0.96, 1.0),
		false
	)
	if !BuildingWireframeScript.is_active(node):
		m_failures.append("%s did not generate the shared debug wireframe" % label)
		return
	var sources := BuildingWireframeScript.get_overlay_sources(node)
	if sources.is_empty():
		m_failures.append("%s debug wireframe did not apply to a source mesh" % label)
		return
	if node is MeshInstance3D and sources[0] != node:
		m_failures.append("%s debug wireframe did not reuse its source mesh instance" % label)
	var source_ids: Array[int] = []
	for source in sources:
		source_ids.append(source.get_instance_id())
	var material := BuildingWireframeScript.get_debug_material(node, sources[0])
	var previous_overlay := material.next_pass if material != null else null
	if (
		material == null
		or material.shader == null
		or material.shader.code.contains("depth_test_disabled")
		or material.shader.code.contains("cull_disabled")
		or !material.shader.code.contains("cull_back")
		or BuildingWireframeScript.is_xray(node)
	):
		m_failures.append("%s debug wireframe was not depth-tested by default" % label)
	node.call(
		"set_debug_wireframe",
		true,
		Color(1.0, 0.32, 0.12, 0.8),
		true
	)
	sources = BuildingWireframeScript.get_overlay_sources(node)
	var styled_source_ids: Array[int] = []
	for source in sources:
		styled_source_ids.append(source.get_instance_id())
	if styled_source_ids != source_ids:
		m_failures.append("%s debug style changes replaced source geometry" % label)
	material = (
		BuildingWireframeScript.get_debug_material(node, sources[0])
		if !sources.is_empty()
		else null
	)
	if (
		material == null
		or material.shader == null
		or !material.shader.code.contains("depth_test_disabled")
		or material.shader.code.contains("cull_disabled")
		or !material.shader.code.contains("cull_back")
		or !BuildingWireframeScript.is_xray(node)
	):
		m_failures.append("%s debug wireframe x-ray mode did not disable depth testing" % label)
	if _debug_wireframe_rebuild_count(node) != rebuild_before:
		m_failures.append("%s debug display changes rebuilt source geometry" % label)
	if _non_wireframe_descendant_ids(node) != child_ids_before:
		m_failures.append("%s debug display changes replaced generated geometry or collision" % label)
	node.call(
		"set_debug_wireframe",
		false,
		Color(1.0, 0.32, 0.12, 0.8),
		true
	)
	if BuildingWireframeScript.is_active(node):
		m_failures.append("%s did not clear the shared debug wireframe" % label)
	if !sources.is_empty() and sources[0].material_overlay != previous_overlay:
		m_failures.append("%s did not restore the previous material overlay" % label)
	if _debug_wireframe_rebuild_count(node) != rebuild_before:
		m_failures.append("%s wireframe removal rebuilt source geometry" % label)


func _debug_wireframe_rebuild_count(node: Node) -> int:
	if node.has_method("get_mesh_rebuild_count"):
		return int(node.call("get_mesh_rebuild_count"))
	if node.has_method("get_geometry_rebuild_count"):
		return int(node.call("get_geometry_rebuild_count"))
	return -1


func _non_wireframe_descendant_ids(node: Node) -> Array[int]:
	var ids: Array[int] = []
	for child in node.get_children():
		if child.has_meta(BuildingWireframeScript.GENERATED_META):
			continue
		ids.append(child.get_instance_id())
		ids.append_array(_non_wireframe_descendant_ids(child))
	return ids


func _covered_polygon_area(polygons: Array) -> float:
	var area := 0.0
	for polygon_variant in polygons:
		area += absf(_polygon_area(_polygon_from_variant(polygon_variant)))
	return area


func _polygon_vertex_count(polygons: Array) -> int:
	var count := 0
	for polygon_variant in polygons:
		count += _polygon_from_variant(polygon_variant).size()
	return count


func _cover_polygons_have_non_axis_edge(polygons: Array) -> bool:
	for polygon_variant in polygons:
		var polygon := _polygon_from_variant(polygon_variant)
		for index in range(polygon.size()):
			var current := polygon[index]
			var next := polygon[(index + 1) % polygon.size()]
			var edge := next - current
			if absf(edge.x) > 0.01 and absf(edge.y) > 0.01:
				return true
	return false


func _cover_polygons_sample_under_other_roof(
	polygons: Array,
	candidate_start: Vector3,
	candidate_end: Vector3,
	candidate_style: String,
	candidate_angle_degrees: float,
	candidate_overhang: float,
	candidate_rotation_degrees: float,
	other_roofs: Array[Roof3DScript]
) -> bool:
	var candidate_size := Vector2(absf(candidate_end.x - candidate_start.x), absf(candidate_end.z - candidate_start.z))
	var candidate_anchor := Vector3(
		minf(candidate_start.x, candidate_end.x),
		candidate_start.y,
		minf(candidate_start.z, candidate_end.z)
	)
	var candidate_basis := Basis(Vector3.UP, deg_to_rad(candidate_rotation_degrees))
	for polygon_variant in polygons:
		var polygon := _polygon_from_variant(polygon_variant)
		for point in _polygon_sample_points(polygon):
			var candidate_height := RoofStyleGeometryFactory.roof_surface_height_for_style(
				candidate_style,
				candidate_size,
				candidate_overhang,
				point,
				{"angle_degrees": candidate_angle_degrees}
			)
			var parent_point := candidate_anchor + candidate_basis * Vector3(point.x, 0.0, point.y)
			if !_sample_is_under_any_roof(parent_point, candidate_start.y + candidate_height, other_roofs):
				return false
	return true


func _polygon_from_variant(value) -> PackedVector2Array:
	if value is PackedVector2Array:
		return PackedVector2Array(value)
	var polygon := PackedVector2Array()
	for point in value:
		polygon.append(Vector2(point))
	return polygon


func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _polygon_sample_points(polygon: PackedVector2Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if polygon.is_empty():
		return points
	var centroid := Vector2.ZERO
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		points.append(current)
		points.append((current + next) * 0.5)
		centroid += current
	points.append(centroid / float(polygon.size()))
	return points


func _sample_is_under_any_roof(
	parent_point: Vector3,
	candidate_top_y: float,
	other_roofs: Array[Roof3DScript]
) -> bool:
	for other_roof in other_roofs:
		var other_basis_inverse := Basis(Vector3.UP, deg_to_rad(other_roof.roof_rotation_degrees)).inverse()
		var other_local := other_basis_inverse * (parent_point - other_roof.get_roof_anchor_point())
		var other_point := Vector2(other_local.x, other_local.z)
		if !_rect_contains_point_inclusive(other_roof.get_roof_render_rect(), other_point):
			continue
		var other_height := other_roof.get_roof_height_at_local_render_point(other_point)
		if other_roof.start_point.y + other_height >= candidate_top_y - 0.01:
			return true
	return false


func _rect_contains_point_inclusive(rect: Rect2, point: Vector2) -> bool:
	var max_point := rect.position + rect.size
	return (
		point.x >= rect.position.x - 0.001
		and point.y >= rect.position.y - 0.001
		and point.x <= max_point.x + 0.001
		and point.y <= max_point.y + 0.001
	)


func _roof_underside_normals_are_down(roof: Roof3DScript) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found_underside := false
	for index in range(0, indices.size(), 3):
		var first := vertices[indices[index]]
		var second := vertices[indices[index + 1]]
		var third := vertices[indices[index + 2]]
		if (
			!_roof_vertex_is_on_underside(roof, first)
			or !_roof_vertex_is_on_underside(roof, second)
			or !_roof_vertex_is_on_underside(roof, third)
		):
			continue
		found_underside = true
		if normals[indices[index]].y >= -0.25:
			return false
	return found_underside


func _roof_surface_normals_are_not_down(roof: Roof3DScript) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found_surface := false
	for index in range(0, indices.size(), 3):
		var first := vertices[indices[index]]
		var second := vertices[indices[index + 1]]
		var third := vertices[indices[index + 2]]
		if (
			_roof_vertex_is_on_underside(roof, first)
			and _roof_vertex_is_on_underside(roof, second)
			and _roof_vertex_is_on_underside(roof, third)
		):
			continue
		found_surface = true
		if normals[indices[index]].y < -0.01:
			return false
	return found_surface


func _roof_vertex_is_on_underside(roof: Roof3DScript, vertex: Vector3) -> bool:
	var surface_height := roof.get_roof_height_at_local_render_point(Vector2(vertex.x, vertex.z))
	return absf(vertex.y - (surface_height - roof.roof_thickness)) <= 0.002


func _has_internal_roof_fascia_facing_cover(
	roof: Roof3DScript,
	cover_polygons: Array[PackedVector2Array]
) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var render_rect := roof.get_roof_render_rect()
	for index in range(vertices.size()):
		var normal := normals[index]
		if absf(normal.y) > 0.05:
			continue
		var point := Vector2(vertices[index].x, vertices[index].z)
		if !_point_on_rect_boundary(render_rect, point):
			var normal_2d := Vector2(normal.x, normal.z)
			if normal_2d.length_squared() <= 0.0001:
				continue
			var outward_sample := point + normal_2d.normalized() * 0.03
			if _point_is_inside_any_polygon(outward_sample, cover_polygons):
				return true
	return false


func _point_is_inside_any_polygon(point: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if _point_is_inside_polygon(point, polygon):
			return true
	return false


func _point_is_inside_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for current_index in range(polygon.size()):
		var current := polygon[current_index]
		var previous := polygon[previous_index]
		var denominator := previous.y - current.y
		var crosses := false
		if absf(denominator) > 0.000001:
			crosses = (
				(current.y > point.y) != (previous.y > point.y)
				and point.x < (previous.x - current.x) * (point.y - current.y) / denominator + current.x
			)
		if crosses:
			inside = !inside
		previous_index = current_index
	return inside


func _point_on_rect_boundary(rect: Rect2, point: Vector2) -> bool:
	if !_rect_contains_point_inclusive(rect, point):
		return false
	var max_point := rect.position + rect.size
	return (
		absf(point.x - rect.position.x) <= 0.001
		or absf(point.x - max_point.x) <= 0.001
		or absf(point.y - rect.position.y) <= 0.001
		or absf(point.y - max_point.y) <= 0.001
	)


func _has_roof_sloped_normal(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if normal.y > 0.25 and normal.y < 0.98:
			return true
	return false


func _roof_base_has_corner_near(roof: Roof3DScript, expected_corner: Vector3) -> bool:
	var basis := Basis(Vector3.UP, deg_to_rad(roof.roof_rotation_degrees))
	var size := roof.get_roof_size()
	var anchor := roof.get_roof_anchor_point()
	var corners := [
		anchor,
		anchor + basis * Vector3(size.x, 0.0, 0.0),
		anchor + basis * Vector3(size.x, 0.0, size.y),
		anchor + basis * Vector3(0.0, 0.0, size.y),
	]
	for corner in corners:
		if Vector3(corner).distance_to(expected_corner) <= 0.001:
			return true
	return false


func _pillar_max_radius_at_y(pillar: Pillar3DScript, expected_y: float) -> float:
	if pillar.mesh == null or pillar.mesh.get_surface_count() <= 0:
		return 0.0
	var arrays := pillar.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var max_radius := 0.0
	for vertex in vertices:
		if absf(vertex.y - expected_y) > 0.001:
			continue
		max_radius = maxf(max_radius, Vector2(vertex.x, vertex.z).length())
	return max_radius


func _has_horizontal_pillar_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if absf(normal.y) > 0.01:
			continue
		if normal.length_squared() > 0.98:
			return true
	return false


func _has_diagonal_wall_normal(array_mesh: ArrayMesh) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if absf(normal.y) > 0.01:
			continue
		if maxf(absf(normal.dot(Vector3.RIGHT)), absf(normal.dot(Vector3.BACK))) < 0.98:
			return true
	return false


func _has_world_diagonal_wall_normal(wall: Wall3DScript) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		var world_normal := (wall.global_transform.basis * normal).normalized()
		if absf(world_normal.y) > 0.01:
			continue
		if maxf(absf(world_normal.dot(Vector3.RIGHT)), absf(world_normal.dot(Vector3.BACK))) < 0.98:
			return true
	return false


func _wall_has_sloped_up_face(wall: Wall3DScript) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		var world_normal := (wall.global_transform.basis * normal).normalized()
		if world_normal.y <= 0.1 or world_normal.y >= 0.999:
			continue
		if maxf(absf(world_normal.x), absf(world_normal.z)) > 0.1:
			return true
	return false


func _wall_mesh_contains_surface_point(
	wall: Wall3DScript,
	world_point: Vector3,
	tolerance: float = 0.002,
	expected_world_normal: Vector3 = Vector3.ZERO
) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var first_index := indices[triangle_start]
		var a := wall.global_transform * vertices[first_index]
		var b := wall.global_transform * vertices[indices[triangle_start + 1]]
		var c := wall.global_transform * vertices[indices[triangle_start + 2]]
		if expected_world_normal != Vector3.ZERO:
			var world_normal := (
				wall.global_transform.basis * normals[first_index]
			).normalized()
			if world_normal.dot(expected_world_normal.normalized()) < 0.98:
				continue
		var normal := (b - a).cross(c - a)
		var normal_length := normal.length()
		if normal_length <= 0.000001:
			continue
		if absf((world_point - a).dot(normal / normal_length)) > tolerance:
			continue
		var v0 := b - a
		var v1 := c - a
		var v2 := world_point - a
		var dot00 := v0.dot(v0)
		var dot01 := v0.dot(v1)
		var dot11 := v1.dot(v1)
		var dot20 := v2.dot(v0)
		var dot21 := v2.dot(v1)
		var denominator := dot00 * dot11 - dot01 * dot01
		if absf(denominator) <= 0.000001:
			continue
		var weight_b := (dot11 * dot20 - dot01 * dot21) / denominator
		var weight_c := (dot00 * dot21 - dot01 * dot20) / denominator
		var weight_a := 1.0 - weight_b - weight_c
		if (
			weight_a >= -tolerance
			and weight_b >= -tolerance
			and weight_c >= -tolerance
		):
			return true
	return false


func _wall_face_winding_matches_normal(
	wall: Wall3DScript,
	expected_world_normal: Vector3
) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found_face := false
	for triangle_start in range(0, indices.size(), 3):
		var first_index := indices[triangle_start]
		var world_normal := (
			wall.global_transform.basis * normals[first_index]
		).normalized()
		if world_normal.dot(expected_world_normal.normalized()) < 0.98:
			continue
		found_face = true
		var a := wall.global_transform * vertices[first_index]
		var b := wall.global_transform * vertices[indices[triangle_start + 1]]
		var c := wall.global_transform * vertices[indices[triangle_start + 2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(world_normal) > -0.98:
			return false
	return found_face


func _world_nonbase_boundary_edge_count(wall: Wall3DScript) -> int:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return 0
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var edge_counts := {}
	var base_y := wall.global_transform.origin.y
	for triangle_start in range(0, indices.size(), 3):
		var a := wall.global_transform * vertices[indices[triangle_start]]
		var b := wall.global_transform * vertices[indices[triangle_start + 1]]
		var c := wall.global_transform * vertices[indices[triangle_start + 2]]
		_add_nonbase_edge_count(edge_counts, a, b, base_y)
		_add_nonbase_edge_count(edge_counts, b, c, base_y)
		_add_nonbase_edge_count(edge_counts, c, a, base_y)
	var open_count := 0
	for key in edge_counts.keys():
		if int(edge_counts[key]) != 2:
			open_count += 1
	return open_count


func _add_nonbase_edge_count(
	edge_counts: Dictionary,
	a: Vector3,
	b: Vector3,
	base_y: float
) -> void:
	# Wall undersides are intentionally open, so their perimeter is not a
	# miter gap. Vertical and upper edges must still remain watertight.
	if absf(a.y - base_y) <= 0.001 and absf(b.y - base_y) <= 0.001:
		return
	var a_key := _vertex_key(a)
	var b_key := _vertex_key(b)
	var edge_key := "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]
	edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1


func _vertex_key(vertex: Vector3) -> String:
	return "%d,%d,%d" % [
		int(round(vertex.x * 1000.0)),
		int(round(vertex.y * 1000.0)),
		int(round(vertex.z * 1000.0)),
	]


func _validate_collinear_overlap_opening_propagation() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = "CollinearOpeningCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 96.0)
	add_child(coordinator)
	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	# Earlier scene-order wall owns the shared span; later wall is clipped there.
	var owner_wall := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3.ZERO, Vector3(6.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(owner_wall)
	var clipped_wall := BuildingFactoryScript.create_wall_node(coordinator,
		Vector3(3.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(clipped_wall)
	coordinator.refresh_wall_intersection_clips()

	# Placement is allowed on the clipped (later) wall along the collinear overlap.
	if !coordinator.can_place_wall_opening(
		clipped_wall, 0, Vector2(1.5, 1.1), Vector2(0.8, 0.8)
	):
		m_failures.append("Opening placement blocked on the clipped collinear wall overlap")

	# Door authored on the clipped (later) wall, inside the overlap (world x ~ 4.5).
	var door := BuildingOpening3DScript.new() as BuildingOpening3DScript
	door.name = "OverlapDoor"
	door.opening_width = 0.9
	door.opening_height = 2.1
	door.position = Vector3(1.5, 1.05, 0.22 * 0.5 + 0.035)
	door.set_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
	clipped_wall.add_child(door)
	clipped_wall.rebuild_wall_mesh()
	coordinator.refresh_wall_intersection_clips()

	# The owner wall must now carry the propagated opening on its shared segment.
	var owner_local_door_x := 4.5
	var owner_rects := owner_wall.get_render_opening_rects(0)
	var found_propagated := false
	for rect in owner_rects:
		if rect.position.x <= owner_local_door_x and rect.end.x >= owner_local_door_x:
			found_propagated = true
			break
	if !found_propagated:
		m_failures.append("Owner wall did not receive the collinear sibling's door opening")

	# And the owner's rendered mesh must show a cut: a reveal/jamb face (normal
	# along the wall axis) at the door edges within the overlap, not just the
	# segment end caps at x=0 and x=6.
	var door_point := coordinator.to_global(Vector3(4.5, 1.0, 0.0))
	var owner_local := owner_wall.to_local(door_point)
	if !_has_axis_reveal_face(
		owner_wall.mesh as ArrayMesh, owner_local.x, 0.6, 2.0
	):
		m_failures.append("Owner wall mesh was not cut within the propagated door frame")

	# A door authored on the owner wall must also propagate the other way, onto
	# the clipped sibling, so the clipped wall's (unclipped) collision is cut and
	# does not block the doorway. Owner-local x ~ 5.0 -> clipped-local x ~ 2.0.
	var owner_door := BuildingOpening3DScript.new() as BuildingOpening3DScript
	owner_door.name = "OwnerOverlapDoor"
	owner_door.opening_width = 0.9
	owner_door.opening_height = 2.1
	owner_door.position = Vector3(5.0, 1.05, 0.22 * 0.5 + 0.035)
	owner_door.set_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
	owner_wall.add_child(owner_door)
	owner_wall.rebuild_wall_mesh()
	coordinator.refresh_wall_intersection_clips()

	var clipped_local_door_x := 2.0
	var clipped_rects := clipped_wall.get_render_opening_rects(0)
	var found_reverse := false
	for rect in clipped_rects:
		if rect.position.x <= clipped_local_door_x and rect.end.x >= clipped_local_door_x:
			found_reverse = true
			break
	if !found_reverse:
		m_failures.append("Clipped wall did not receive the owner wall's door opening for collision")


## True when the mesh has a near-vertical face whose normal runs along the wall
## X axis (a door/window jamb reveal) located near `target_x` and below the
## given height band, ignoring the wall's end caps far from the door.
func _has_axis_reveal_face(
	array_mesh: ArrayMesh,
	target_x: float,
	min_height: float,
	max_height: float
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if absf(normals[i0].x) < 0.9:
			continue
		var mean_x := (vertices[i0].x + vertices[i1].x + vertices[i2].x) / 3.0
		# The two jambs sit ~half the door width either side of centre; the wall
		# end caps (x=0 and x=6) stay well outside this band.
		if absf(mean_x - target_x) > 0.7:
			continue
		var mean_y := (vertices[i0].y + vertices[i1].y + vertices[i2].y) / 3.0
		if mean_y < min_height or mean_y > max_height:
			continue
		return true
	return false


func _has_horizontal_face_covering_plan_point(
	array_mesh: ArrayMesh,
	point: Vector2,
	expected_height: float
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if normals[i0].dot(Vector3.UP) < 0.9:
			continue
		if absf(vertices[i0].y - expected_height) > 0.01:
			continue
		var a := Vector2(vertices[i0].x, vertices[i0].z)
		var b := Vector2(vertices[i1].x, vertices[i1].z)
		var c := Vector2(vertices[i2].x, vertices[i2].z)
		if _plan_triangle_contains_point(a, b, c, point):
			return true
	return false


func _plan_triangle_contains_point(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool:
	var area := absf((b - a).cross(c - a))
	if area <= 0.000001:
		return false
	var area_a := absf((b - point).cross(c - point))
	var area_b := absf((point - a).cross(c - a))
	var area_c := absf((b - a).cross(point - a))
	return absf(area - area_a - area_b - area_c) <= 0.0005


func _endpoint_count(segments: Array, point: Vector3) -> int:
	var count := 0
	for segment in segments:
		var typed_segment := segment as WallSegmentScript
		if typed_segment == null:
			continue
		if typed_segment.start_point.distance_to(point) <= 0.001:
			count += 1
		if typed_segment.end_point.distance_to(point) <= 0.001:
			count += 1
	return count


func _endpoint_count_for_axis(segments: Array, point: Vector3, axis: Vector2) -> int:
	var count := 0
	var normalized_axis := axis.normalized()
	for segment in segments:
		var typed_segment := segment as WallSegmentScript
		if typed_segment == null:
			continue
		var segment_axis := Vector2(
			typed_segment.end_point.x - typed_segment.start_point.x,
			typed_segment.end_point.z - typed_segment.start_point.z
		).normalized()
		if absf(segment_axis.dot(normalized_axis)) < 0.999:
			continue
		if typed_segment.start_point.distance_to(point) <= 0.001:
			count += 1
		if typed_segment.end_point.distance_to(point) <= 0.001:
			count += 1
	return count
