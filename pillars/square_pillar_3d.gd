@tool
class_name SquarePillar3D
extends "res://addons/low_poly_building_editor/pillars/pillar_3d.gd"


func get_pillar_style() -> String:
	return "square"


func _effective_side_count() -> int:
	return 4


func _effective_angle_offset(_sides: int) -> float:
	return PI * 0.25
