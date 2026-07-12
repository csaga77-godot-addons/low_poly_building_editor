@tool
class_name BuildingGenerationSpec
extends Resource

const CURRENT_SCHEMA_VERSION := 1
const CURRENT_GENERATOR_VERSION := 1

@export var generation_type := "building"
@export var schema_version := CURRENT_SCHEMA_VERSION
@export var generator_version := CURRENT_GENERATOR_VERSION
@export var building_name := "GeneratedBuilding"
## Serialized as JSON `seed`; avoids shadowing GDScript's global seed().
@export var generation_seed := 1
@export_range(0.05, 8.0, 0.05) var grid_step := 0.5


func validate() -> Array[String]:
	var errors: Array[String] = []
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("Unsupported schema_version %d; expected %d." % [schema_version, CURRENT_SCHEMA_VERSION])
	if generator_version != CURRENT_GENERATOR_VERSION:
		errors.append("Unsupported generator_version %d; expected %d." % [generator_version, CURRENT_GENERATOR_VERSION])
	if building_name.strip_edges().is_empty():
		errors.append("name must not be empty.")
	if grid_step < 0.05:
		errors.append("grid_step must be at least 0.05.")
	return errors


func apply_common_dictionary(source: Dictionary, fallback_type: String) -> void:
	generation_type = String(source.get("type", fallback_type)).strip_edges().to_lower()
	schema_version = int(source.get("schema_version", CURRENT_SCHEMA_VERSION))
	generator_version = int(source.get("generator_version", CURRENT_GENERATOR_VERSION))
	building_name = String(source.get("name", building_name))
	generation_seed = int(source.get("seed", generation_seed))
	grid_step = float(source.get("grid_step", grid_step))


func common_dictionary() -> Dictionary:
	return {
		"type": generation_type,
		"schema_version": schema_version,
		"generator_version": generator_version,
		"name": building_name,
		"seed": generation_seed,
		"grid_step": grid_step,
	}
