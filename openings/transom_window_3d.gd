@tool
class_name TransomWindow3D
extends "res://addons/low_poly_building_editor/openings/window_pane_3d.gd"

@export_range(0.0, 0.9, 0.01) var transom_ratio := 0.28:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.9)
		if is_equal_approx(transom_ratio, clamped_value):
			return
		transom_ratio = clamped_value
		_request_rebuild()

@export_range(0.005, 0.3, 0.005) var transom_rail_thickness := 0.03:
	set(value):
		var clamped_value := clampf(value, 0.005, 0.3)
		if is_equal_approx(transom_rail_thickness, clamped_value):
			return
		transom_rail_thickness = clamped_value
		_request_rebuild()


func _build_opening_content() -> void:
	var spans := _leaf_spans(1)
	var rect := spans[0]
	_add_window_pane("WindowPane", rect)
	if transom_ratio <= 0.0:
		return
	var split_y := rect.end.y - rect.size.y * transom_ratio
	var bar_depth := maxf(window_pane_depth + 0.01, frame_depth * 0.6)
	_add_box(
		"WindowPaneTransomRail",
		Vector3(rect.size.x, transom_rail_thickness, bar_depth),
		Vector3(rect.position.x + rect.size.x * 0.5, split_y, 0.0),
		frame_color,
		false
	)
