@tool
class_name OctagonalPillar3D
extends "res://addons/low_poly_building_editor/pillars/pillar_3d.gd"


func get_pillar_style() -> String:
	return "octagonal"


func _effective_side_count() -> int:
	return 8
