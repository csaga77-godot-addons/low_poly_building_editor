@tool
class_name GlazedDoor3D
extends "res://addons/low_poly_building_editor/openings/leafed_door_3d.gd"

@export_range(0.0, 0.95, 0.01) var door_glazing_ratio := 0.55:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.95)
		if is_equal_approx(door_glazing_ratio, clamped_value):
			return
		door_glazing_ratio = clamped_value
		_request_rebuild()

@export_range(0.01, 0.5, 0.01) var door_glass_depth := 0.03:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(door_glass_depth, clamped_value):
			return
		door_glass_depth = clamped_value
		_request_rebuild()

@export var door_glass_color := Color(0.58, 0.82, 0.95, 0.52):
	set(value):
		if door_glass_color == value:
			return
		door_glass_color = value
		_request_rebuild()


func _build_opening_content() -> void:
	var spans := _leaf_spans(1)
	_build_glazed_door_leaf("DoorPanel", spans[0])


func _build_glazed_door_leaf(part_name: String, rect: Rect2) -> void:
	if door_glazing_ratio <= 0.0:
		_add_solid_door_panel(part_name, rect)
		return
	var rail := frame_thickness
	var glass_height := maxf(rect.size.y * door_glazing_ratio, 0.01)
	var solid_height := maxf(rect.size.y - glass_height - rail, 0.01)
	var solid_rect := Rect2(rect.position.x, rect.position.y, rect.size.x, solid_height)
	var glass_rect := Rect2(
		rect.position.x,
		rect.position.y + solid_height + rail,
		rect.size.x,
		maxf(rect.size.y - solid_height - rail, 0.01)
	)
	_add_solid_door_panel("%sPanel" % part_name, solid_rect)
	_add_box(
		"%sRail" % part_name,
		Vector3(rect.size.x, rail, door_panel_depth),
		Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + solid_height + rail * 0.5, 0.0),
		door_panel_color,
		false
	)
	_add_glazed_door_lite("%sGlass" % part_name, glass_rect)


func _add_glazed_door_lite(part_name: String, rect: Rect2) -> void:
	_add_glass(part_name, rect, door_glass_depth, door_glass_color)
