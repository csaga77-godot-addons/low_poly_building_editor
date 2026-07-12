@tool
class_name BuildingSpec
extends "res://addons/low_poly_building_editor/building_generation_spec.gd"

const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)

const RANDOM_STYLE := "random"

@export var footprint_cells := Vector2i(16, 12)
@export var footprint_jitter_cells := Vector2i.ZERO
@export_range(1, 8, 1) var storeys := 1

@export_group("Wall")
@export_range(0.1, 6.0, 0.05, "or_greater") var wall_height := 2.8
@export_range(0.03, 1.0, 0.01, "or_greater") var wall_thickness := 0.22
@export var wall_color := Color(0.78, 0.68, 0.54, 1.0)

@export_group("Floor")
@export_range(0.01, 2.0, 0.01, "or_greater") var floor_thickness := 0.15
@export var floor_color := Color(0.46, 0.40, 0.32, 1.0)

@export_group("Facade")
@export var door_style := "single_door"
@export_range(-1, 3, 1) var entrance_segment := 0
@export_range(0.1, 6.0, 0.01, "or_greater") var door_width := 0.9
@export_range(0.1, 6.0, 0.01, "or_greater") var door_height := 2.1
@export var door_color := Color(0.50, 0.34, 0.20, 1.0)
@export var window_style := "single_window"
@export_range(0, 8, 1) var window_count_per_wall := 2
@export_range(0.1, 6.0, 0.01, "or_greater") var window_width := 1.0
@export_range(0.1, 6.0, 0.01, "or_greater") var window_height := 1.0
@export_range(0.0, 6.0, 0.01) var window_sill_height := 0.9
@export var window_pane_color := Color(0.58, 0.82, 0.95, 0.52)
@export var frame_color := Color(0.86, 0.92, 0.94, 1.0)
@export var porch_pillars := false
@export var pillar_style := "square"
@export_range(0.05, 2.0, 0.01, "or_greater") var pillar_radius := 0.18

@export_group("Roof")
@export var roof_style := "gable"
@export_range(0.0, 89.0, 1.0) var roof_angle_degrees := 38.0
@export_range(0.02, 2.0, 0.01, "or_greater") var roof_thickness := 0.14
@export_range(0.0, 4.0, 0.01, "or_greater") var roof_overhang := 0.35
@export var roof_color := Color(0.50, 0.34, 0.25, 1.0)


func validate() -> Array[String]:
	var errors: Array[String] = super.validate()
	if generation_type != "building":
		errors.append("BuildingSpec type must be 'building'.")
	if footprint_cells.x < 6 or footprint_cells.y < 6:
		errors.append("footprint_cells must be at least [6, 6].")
	if footprint_jitter_cells.x < 0 or footprint_jitter_cells.y < 0:
		errors.append("footprint_jitter_cells cannot be negative.")
	if storeys != 1:
		errors.append("Generator version 1 supports exactly one storey.")
	if wall_height <= 0.1:
		errors.append("wall.height must be greater than 0.1.")
	if wall_thickness < 0.03:
		errors.append("wall.thickness must be at least 0.03.")
	if floor_thickness < 0.01:
		errors.append("floor.thickness must be at least 0.01.")
	if !_style_is_random_or_supported_door(door_style):
		errors.append("Unsupported facade.door_style '%s'." % door_style)
	if entrance_segment < -1 or entrance_segment > 3:
		errors.append("facade.entrance_segment must be -1 or a value from 0 to 3.")
	if door_width <= 0.1 or door_height <= 0.1:
		errors.append("Facade door dimensions must be greater than 0.1.")
	if !_style_is_random_or_supported_window(window_style):
		errors.append("Unsupported facade.window_style '%s'." % window_style)
	if window_count_per_wall < 0 or window_count_per_wall > 8:
		errors.append("facade.window_count_per_wall must be between 0 and 8.")
	if window_width <= 0.1 or window_height <= 0.1:
		errors.append("Facade window dimensions must be greater than 0.1.")
	if window_sill_height < 0.0:
		errors.append("facade.window_sill_height cannot be negative.")
	if !BuildingFactoryScript.is_pillar_style_supported(pillar_style):
		errors.append("Unsupported facade.pillar_style '%s'." % pillar_style)
	if pillar_radius < 0.05:
		errors.append("facade.pillar_radius must be at least 0.05.")
	if !_style_is_random_or_supported_roof(roof_style):
		errors.append("Unsupported roof.style '%s'." % roof_style)
	if roof_angle_degrees < 0.0 or roof_angle_degrees >= 89.0:
		errors.append("roof.angle_degrees must be in the range 0..<89.")
	if roof_thickness < 0.02:
		errors.append("roof.thickness must be at least 0.02.")
	if roof_overhang < 0.0:
		errors.append("roof.overhang cannot be negative.")
	if door_height > wall_height:
		errors.append("The door height exceeds the wall height.")
	if window_sill_height + window_height > wall_height:
		errors.append("The window top exceeds the wall height.")
	return errors


func to_dictionary() -> Dictionary:
	var result := common_dictionary()
	result.merge({
		"footprint_cells": [footprint_cells.x, footprint_cells.y],
		"storeys": storeys,
		"variation": {
			"footprint_jitter_cells": [
				footprint_jitter_cells.x,
				footprint_jitter_cells.y,
			],
		},
		"wall": {
			"height": wall_height,
			"thickness": wall_thickness,
			"color": wall_color.to_html(true),
		},
		"floor": {
			"thickness": floor_thickness,
			"color": floor_color.to_html(true),
		},
		"facade": {
			"door_style": door_style,
			"entrance_segment": entrance_segment,
			"door_width": door_width,
			"door_height": door_height,
			"door_color": door_color.to_html(true),
			"window_style": window_style,
			"window_count_per_wall": window_count_per_wall,
			"window_width": window_width,
			"window_height": window_height,
			"window_sill_height": window_sill_height,
			"window_pane_color": window_pane_color.to_html(true),
			"frame_color": frame_color.to_html(true),
			"porch_pillars": porch_pillars,
			"pillar_style": pillar_style,
			"pillar_radius": pillar_radius,
		},
		"roof": {
			"style": roof_style,
			"angle_degrees": roof_angle_degrees,
			"thickness": roof_thickness,
			"overhang": roof_overhang,
			"color": roof_color.to_html(true),
		},
	})
	return result


func apply_dictionary(source: Dictionary) -> Array[String]:
	var spec := self
	var parse_errors: Array[String] = []
	spec.apply_common_dictionary(source, "building")
	spec.footprint_cells = _parse_vector2i(
		source.get("footprint_cells", spec.footprint_cells),
		spec.footprint_cells,
		"footprint_cells",
		parse_errors
	)
	spec.storeys = int(source.get("storeys", spec.storeys))

	var variation := _parse_section(source, "variation", parse_errors)
	spec.footprint_jitter_cells = _parse_vector2i(
		variation.get("footprint_jitter_cells", spec.footprint_jitter_cells),
		spec.footprint_jitter_cells,
		"variation.footprint_jitter_cells",
		parse_errors
	)

	var wall := _parse_section(source, "wall", parse_errors)
	spec.wall_height = float(wall.get("height", spec.wall_height))
	spec.wall_thickness = float(wall.get("thickness", spec.wall_thickness))
	spec.wall_color = _parse_color(
		wall.get("color", spec.wall_color),
		spec.wall_color,
		"wall.color",
		parse_errors
	)

	var floor := _parse_section(source, "floor", parse_errors)
	spec.floor_thickness = float(floor.get("thickness", spec.floor_thickness))
	spec.floor_color = _parse_color(
		floor.get("color", spec.floor_color),
		spec.floor_color,
		"floor.color",
		parse_errors
	)

	var facade := _parse_section(source, "facade", parse_errors)
	spec.door_style = String(facade.get("door_style", spec.door_style))
	spec.entrance_segment = int(
		facade.get("entrance_segment", spec.entrance_segment)
	)
	spec.door_width = float(facade.get("door_width", spec.door_width))
	spec.door_height = float(facade.get("door_height", spec.door_height))
	spec.door_color = _parse_color(
		facade.get("door_color", spec.door_color),
		spec.door_color,
		"facade.door_color",
		parse_errors
	)
	spec.window_style = String(facade.get("window_style", spec.window_style))
	spec.window_count_per_wall = int(
		facade.get("window_count_per_wall", spec.window_count_per_wall)
	)
	spec.window_width = float(facade.get("window_width", spec.window_width))
	spec.window_height = float(facade.get("window_height", spec.window_height))
	spec.window_sill_height = float(
		facade.get("window_sill_height", spec.window_sill_height)
	)
	spec.window_pane_color = _parse_color(
		facade.get("window_pane_color", spec.window_pane_color),
		spec.window_pane_color,
		"facade.window_pane_color",
		parse_errors
	)
	spec.frame_color = _parse_color(
		facade.get("frame_color", spec.frame_color),
		spec.frame_color,
		"facade.frame_color",
		parse_errors
	)
	spec.porch_pillars = bool(facade.get("porch_pillars", spec.porch_pillars))
	spec.pillar_style = String(facade.get("pillar_style", spec.pillar_style))
	spec.pillar_radius = float(
		facade.get("pillar_radius", spec.pillar_radius)
	)

	var roof := _parse_section(source, "roof", parse_errors)
	spec.roof_style = String(roof.get("style", spec.roof_style))
	spec.roof_angle_degrees = float(
		roof.get("angle_degrees", spec.roof_angle_degrees)
	)
	spec.roof_thickness = float(roof.get("thickness", spec.roof_thickness))
	spec.roof_overhang = float(roof.get("overhang", spec.roof_overhang))
	spec.roof_color = _parse_color(
		roof.get("color", spec.roof_color),
		spec.roof_color,
		"roof.color",
		parse_errors
	)

	parse_errors.append_array(spec.validate())
	return parse_errors


static func _style_is_random_or_supported_door(style: String) -> bool:
	var normalized := style.strip_edges().to_lower()
	return (
		normalized == RANDOM_STYLE
		or BuildingFactoryScript.is_door_style_supported(normalized)
	)


static func _style_is_random_or_supported_window(style: String) -> bool:
	var normalized := style.strip_edges().to_lower()
	return (
		normalized == RANDOM_STYLE
		or BuildingFactoryScript.is_window_style_supported(normalized)
	)


static func _style_is_random_or_supported_roof(style: String) -> bool:
	var normalized := style.strip_edges().to_lower()
	return (
		normalized == RANDOM_STYLE
		or BuildingFactoryScript.is_roof_style_supported(normalized)
	)


static func _parse_section(
	source: Dictionary,
	key: String,
	errors: Array[String]
) -> Dictionary:
	if !source.has(key):
		return {}
	var value: Variant = source[key]
	if value is Dictionary:
		return value
	errors.append("%s must be a JSON object." % key)
	return {}


static func _parse_vector2i(
	value: Variant,
	fallback: Vector2i,
	field_name: String,
	errors: Array[String]
) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	errors.append("%s must be a two-element integer array." % field_name)
	return fallback


static func _parse_color(
	value: Variant,
	fallback: Color,
	field_name: String,
	errors: Array[String]
) -> Color:
	if value is Color:
		return value
	if value is String:
		var text := String(value).strip_edges()
		if Color.html_is_valid(text):
			return Color.from_string(text, fallback)
	errors.append("%s must be a valid HTML color string." % field_name)
	return fallback
