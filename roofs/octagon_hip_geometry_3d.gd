@tool
extends "res://addons/low_poly_building_editor/roofs/pavilion_hip_geometry_3d.gd"

## Octagonal hip: eight faces rising from a regular octagon inscribed in the
## render bounds to a centered apex. The angular offset aligns flat edges with the
## footprint sides.


func _side_count() -> int:
	return 8


func _angle_offset() -> float:
	return PI / 8.0
