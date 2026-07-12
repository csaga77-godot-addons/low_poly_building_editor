@tool
extends "res://addons/low_poly_building_editor/roofs/pavilion_hip_geometry_3d.gd"

## Pyramid hip: four faces rising from the full rectangular footprint corners to a
## centered apex. Unlike the inscribed pavilion hips, its base ring reaches the
## render bounds corners so it covers the whole rectangle.


func _side_count() -> int:
	return 4


func _angle_offset() -> float:
	return PI * 0.25


func _projected_offset(
	cos_angle: float,
	sin_angle: float,
	radius_x: float,
	radius_z: float
) -> Vector2:
	return Vector2(signf(cos_angle) * radius_x, signf(sin_angle) * radius_z)
