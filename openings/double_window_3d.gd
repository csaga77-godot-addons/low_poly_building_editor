@tool
class_name DoubleWindow3D
extends "res://addons/low_poly_building_editor/openings/window_pane_3d.gd"


func _init() -> void:
	opening_width = 1.8


func _build_opening_content() -> void:
	_build_window_panes(2)
