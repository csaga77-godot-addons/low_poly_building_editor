@tool
extends "res://addons/low_poly_building_editor/pillars/pillar_3d.gd"

@export_range(3, 24, 1) var side_count := 8:
	set(value):
		var clamped_value := clampi(value, 3, 24)
		if side_count == clamped_value:
			return
		side_count = clamped_value
		_request_rebuild()


func _effective_side_count() -> int:
	return side_count
