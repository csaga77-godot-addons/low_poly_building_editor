@tool
class_name DoubleDoor3D
extends "res://addons/low_poly_building_editor/openings/leafed_door_3d.gd"


func _init() -> void:
	super()
	opening_width = 1.6


func _build_opening_content() -> void:
	_build_solid_door_leaves(2)
