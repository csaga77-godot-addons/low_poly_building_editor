@tool
class_name DutchDoor3D
extends "res://addons/low_poly_building_editor/openings/leafed_door_3d.gd"


func _build_opening_content() -> void:
	var spans := _leaf_spans(1)
	var rect := spans[0]
	var gap := frame_thickness
	var leaf_height := maxf((rect.size.y - gap) * 0.5, 0.01)
	var lower := Rect2(rect.position.x, rect.position.y, rect.size.x, leaf_height)
	var upper := Rect2(rect.position.x, rect.position.y + leaf_height + gap, rect.size.x, leaf_height)
	_add_solid_door_panel("DoorPanelLower", lower)
	_add_solid_door_panel("DoorPanelUpper", upper)
	_add_box(
		"DoorPanelMidRail",
		Vector3(rect.size.x, gap, door_panel_depth),
		Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + leaf_height + gap * 0.5, 0.0),
		frame_color,
		false
	)
