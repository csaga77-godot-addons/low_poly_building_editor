@tool
class_name SingleDoor3D
extends "res://addons/low_poly_building_editor/openings/leafed_door_3d.gd"


func _build_opening_content() -> void:
	_build_solid_door_leaves(1)
