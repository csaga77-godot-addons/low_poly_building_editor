@tool
extends "res://addons/low_poly_building_editor/roofs/pavilion_hip_geometry_3d.gd"

## Hexagonal hip: six faces rising from a regular hexagon inscribed in the render
## bounds to a centered apex.


func _side_count() -> int:
	return 6
