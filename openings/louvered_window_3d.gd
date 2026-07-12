@tool
class_name LouveredWindow3D
extends "res://addons/low_poly_building_editor/openings/window_3d.gd"

@export_range(1, 16, 1) var louver_count := 6:
	set(value):
		var clamped_value := clampi(value, 1, 16)
		if louver_count == clamped_value:
			return
		louver_count = clamped_value
		_request_rebuild()

@export_range(0.01, 0.5, 0.01) var louver_depth := 0.03:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(louver_depth, clamped_value):
			return
		louver_depth = clamped_value
		_request_rebuild()


func _build_opening_content() -> void:
	var rect := Rect2(
		-opening_width * 0.5,
		-opening_height * 0.5,
		opening_width,
		opening_height
	)
	var slat_gap := rect.size.y / float(louver_count)
	var slat_height := slat_gap * 0.92
	var slat_depth := maxf(louver_depth * 2.0, frame_depth)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(28.0))
	var center_x := rect.position.x + rect.size.x * 0.5
	for index in range(louver_count):
		var y := rect.position.y + slat_gap * (float(index) + 0.5)
		_add_oriented_box(
			"WindowPaneSlat%d" % index,
			Vector3(rect.size.x, slat_height, slat_depth),
			Vector3(center_x, y, 0.0),
			frame_color,
			tilt
		)
