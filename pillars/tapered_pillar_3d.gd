@tool
class_name TaperedPillar3D
extends "res://addons/low_poly_building_editor/pillars/variable_sided_pillar_3d.gd"


func get_pillar_style() -> String:
	return "tapered"


func _effective_top_radius() -> float:
	if upper_radius > 0.0001:
		return upper_radius
	return pillar_radius * 0.72
