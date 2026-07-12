@tool
class_name HipRoof3D
extends "res://addons/low_poly_building_editor/roofs/sloped_roof_3d.gd"

## Concrete hip roof. A single serialized style with an authored hip shape:
## Standard raises a ridge along the longer axis (and owns the hip gable drop),
## while the Pyramid, Hexagonal, and Octagon pavilion shapes raise a base ring to
## a centered apex. Pavilion shapes ignore the gable drop.
enum HipShape { STANDARD, PYRAMID, HEXAGONAL, OCTAGON }

const StandardGeometry := preload("res://addons/low_poly_building_editor/roofs/hip_roof_geometry_3d.gd")
const PyramidGeometry := preload("res://addons/low_poly_building_editor/roofs/pyramid_hip_geometry_3d.gd")
const HexagonalGeometry := preload("res://addons/low_poly_building_editor/roofs/hexagonal_hip_geometry_3d.gd")
const OctagonGeometry := preload("res://addons/low_poly_building_editor/roofs/octagon_hip_geometry_3d.gd")

@export_enum("Standard", "Pyramid", "Hexagonal", "Octagon") var hip_shape: int = HipShape.STANDARD:
	set(value):
		var clamped_value := clampi(value, 0, HipShape.OCTAGON)
		if hip_shape == clamped_value:
			return
		hip_shape = clamped_value
		_request_rebuild()
		source_geometry_changed.emit()

@export_range(0.0, 20.0, 0.01, "or_greater") var hip_gable_height := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(hip_gable_height, clamped_value):
			return
		hip_gable_height = clamped_value
		_request_rebuild()
		source_geometry_changed.emit()


func get_roof_style() -> String:
	return "hip"


func get_hip_shape() -> int:
	return hip_shape


func set_hip_shape(shape: int) -> void:
	hip_shape = clampi(shape, 0, HipShape.OCTAGON)


func get_hip_gable_height() -> float:
	return hip_gable_height


func set_hip_gable_height(height: float) -> void:
	hip_gable_height = height


func _style_geometry_parameters() -> Dictionary:
	var parameters := super()
	parameters["gable_height_from_peak"] = hip_gable_height
	parameters["hip_shape"] = int(hip_shape)
	return parameters


func _apply_style_geometry_parameters(parameters: Dictionary) -> void:
	super(parameters)
	hip_gable_height = float(parameters.get(
		"gable_height_from_peak", hip_gable_height
	))
	set_hip_shape(int(parameters.get("hip_shape", hip_shape)))


func _get_style_geometry() -> RefCounted:
	match hip_shape:
		HipShape.PYRAMID:
			return PyramidGeometry.new()
		HipShape.HEXAGONAL:
			return HexagonalGeometry.new()
		HipShape.OCTAGON:
			return OctagonGeometry.new()
	return StandardGeometry.new()
