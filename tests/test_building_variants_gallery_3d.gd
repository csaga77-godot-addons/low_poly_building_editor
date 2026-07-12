extends Node3D

const BuildingSpecScript = preload(
	"res://addons/low_poly_building_editor/building_spec.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)

const DEFAULT_SEED_START := 18432
const CELL_SIZE := Vector2(10.5, 9.0)
const PAD_COLOR_A := Color(0.46, 0.54, 0.48, 1.0)
const PAD_COLOR_B := Color(0.50, 0.58, 0.52, 1.0)

@export_file("*.json") var spec_path := (
	"res://addons/low_poly_building_editor/examples/seeded_villa.json"
)
@export_range(1, 24, 1) var variant_count := 12
@export_range(1, 8, 1) var columns := 4
@export var seed_start := DEFAULT_SEED_START

@onready var m_examples: Node3D = $Examples
@onready var m_ground: MeshInstance3D = $Ground
@onready var m_camera: Camera3D = $Camera3D
@onready var m_status_label: Label = $Interface/MarginContainer/Layout/Status


func _ready() -> void:
	rebuild_gallery()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo:
		match event.keycode:
			KEY_N:
				seed_start += variant_count
				rebuild_gallery()
				get_viewport().set_input_as_handled()
			KEY_P:
				seed_start = maxi(0, seed_start - variant_count)
				rebuild_gallery()
				get_viewport().set_input_as_handled()
			KEY_R:
				seed_start = DEFAULT_SEED_START
				rebuild_gallery()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			m_camera.size = maxf(12.0, m_camera.size - 2.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			m_camera.size = minf(90.0, m_camera.size + 2.0)
			get_viewport().set_input_as_handled()


func rebuild_gallery() -> void:
	for child in m_examples.get_children():
		child.free()

	var load_result := BuildingSpecCompilerScript.load_json_spec(spec_path)
	var load_errors: Array = load_result.get("errors", [])
	var base_spec := load_result.get("spec") as BuildingSpecScript
	if base_spec == null or !load_errors.is_empty():
		var message := "Could not load gallery spec: %s" % load_errors
		m_status_label.text = message
		push_error(message)
		return

	var resolved_columns := mini(maxi(columns, 1), variant_count)
	var rows := ceili(float(variant_count) / float(resolved_columns))
	var generated_count := 0
	var failures: Array[String] = []
	for index in range(variant_count):
		var variant_spec := base_spec.duplicate(true) as BuildingSpecScript
		variant_spec.generation_seed = seed_start + index
		variant_spec.building_name = "GalleryVilla%02d" % (index + 1)
		var result := BuildingSpecCompilerScript.compile(variant_spec)
		var resolved: Dictionary = result.get("resolved", {})
		var column := index % resolved_columns
		var row := index / resolved_columns
		var center := _cell_center(column, row, resolved_columns, rows)
		_add_pad(center, index)

		var building := result.get("building") as Node3D
		var errors: Array = result.get("errors", [])
		if building == null or !errors.is_empty():
			failures.append("seed %d: %s" % [variant_spec.generation_seed, errors])
			_add_label(center, "Seed %d\nGeneration failed" % variant_spec.generation_seed, true)
			continue

		var footprint: Array = resolved.get("footprint_size", [0.0, 0.0])
		building.position = center - Vector3(
			float(footprint[0]) * 0.5,
			0.0,
			float(footprint[1]) * 0.5
		)
		building.set_meta("generation_resolved", resolved.duplicate(true))
		m_examples.add_child(building)
		_add_label(center, _variant_label(index, resolved))
		generated_count += 1

	_frame_gallery(resolved_columns, rows)
	m_status_label.text = (
		"Seeds %d–%d  ·  %d/%d generated"
		% [
			seed_start,
			seed_start + variant_count - 1,
			generated_count,
			variant_count,
		]
	)
	if failures.is_empty():
		print(
			"PASS: Building variant gallery generated %d examples "
			% generated_count
			+ "(seeds %d-%d)" % [seed_start, seed_start + variant_count - 1]
		)
	else:
		for failure in failures:
			push_error("Building variant gallery: %s" % failure)


func _cell_center(
	column: int,
	row: int,
	resolved_columns: int,
	rows: int
) -> Vector3:
	return Vector3(
		(float(column) - float(resolved_columns - 1) * 0.5) * CELL_SIZE.x,
		0.0,
		(float(row) - float(rows - 1) * 0.5) * CELL_SIZE.y
	)


func _add_pad(center: Vector3, index: int) -> void:
	var pad := MeshInstance3D.new()
	pad.name = "ExamplePad%02d" % (index + 1)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE.x - 0.6, 0.12, CELL_SIZE.y - 0.6)
	pad.mesh = mesh
	pad.position = center + Vector3(0.0, -0.08, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = PAD_COLOR_A if index % 2 == 0 else PAD_COLOR_B
	material.roughness = 1.0
	pad.material_override = material
	m_examples.add_child(pad)


func _add_label(center: Vector3, text: String, is_error := false) -> void:
	var label := Label3D.new()
	label.name = "ExampleLabel"
	label.text = text
	label.position = center + Vector3(0.0, 6.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 42
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color(1.0, 0.48, 0.42) if is_error else Color.WHITE
	label.outline_modulate = Color(0.08, 0.11, 0.12, 0.92)
	m_examples.add_child(label)


func _variant_label(index: int, resolved: Dictionary) -> String:
	return "#%02d · Seed %d\n%s · %s" % [
		index + 1,
		int(resolved.get("seed", 0)),
		_display_style(String(resolved.get("roof_style", "unknown"))),
		_display_style(String(resolved.get("window_style", "unknown"))),
	]


func _display_style(style: String) -> String:
	return style.replace("_", " ").capitalize()


func _frame_gallery(resolved_columns: int, rows: int) -> void:
	var gallery_width := float(resolved_columns) * CELL_SIZE.x
	var gallery_depth := float(rows) * CELL_SIZE.y
	var ground_mesh := m_ground.mesh as PlaneMesh
	if ground_mesh != null:
		ground_mesh.size = Vector2(gallery_width + 7.0, gallery_depth + 7.0)
	m_camera.position = Vector3(
		gallery_width * 0.68,
		maxf(gallery_width, gallery_depth) * 0.86,
		gallery_depth * 1.15
	)
	m_camera.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)
	m_camera.size = maxf(gallery_depth * 1.48, gallery_width * 0.82)
