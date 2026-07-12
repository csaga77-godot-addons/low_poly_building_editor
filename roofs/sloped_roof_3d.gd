@tool
extends "res://addons/low_poly_building_editor/roofs/roof_3d.gd"

const MAX_ROOF_ANGLE_DEGREES := 89.0

@export_range(0.0, 89.0, 1.0) var roof_height := 40.0:
	set(value):
		var clamped_value := clampf(value, 0.0, MAX_ROOF_ANGLE_DEGREES)
		if is_equal_approx(roof_height, clamped_value):
			return
		roof_height = clamped_value
		_request_rebuild()
		source_geometry_changed.emit()


func get_roof_angle_degrees() -> float:
	return roof_height


func set_roof_angle_degrees(angle_degrees: float) -> void:
	roof_height = angle_degrees


func _style_geometry_parameters() -> Dictionary:
	return {"angle_degrees": roof_height}


func _apply_style_geometry_parameters(parameters: Dictionary) -> void:
	roof_height = float(parameters.get("angle_degrees", roof_height))


static func _clamped_roof_angle_degrees(angle_degrees: float) -> float:
	return clampf(angle_degrees, 0.0, MAX_ROOF_ANGLE_DEGREES)
