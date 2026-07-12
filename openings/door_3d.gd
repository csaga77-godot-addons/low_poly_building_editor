@tool
extends "res://addons/low_poly_building_editor/openings/building_opening_3d.gd"


func _init() -> void:
	opening_width = 0.9
	opening_height = 2.1
	show_bottom_frame = false


# Concrete door styles own their generated leaves and detailing. Door3D only
# establishes geometry and frame behavior shared by every door opening.
func _build_opening_content() -> void:
	pass
