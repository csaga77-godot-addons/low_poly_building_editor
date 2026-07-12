@tool
extends "res://addons/low_poly_building_editor/openings/window_3d.gd"

@export_range(0.01, 0.5, 0.01) var window_pane_depth := 0.03:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(window_pane_depth, clamped_value):
			return
		window_pane_depth = clamped_value
		_request_rebuild()

@export var window_pane_color := Color(0.58, 0.82, 0.95, 0.52):
	set(value):
		if window_pane_color == value:
			return
		window_pane_color = value
		_request_rebuild()


func _build_window_panes(count: int) -> void:
	var spans := _leaf_spans(count)
	for index in range(spans.size()):
		var part_name := _leaf_part_name("WindowPane", index, spans.size())
		_add_window_pane(part_name, spans[index])


func _leaf_spans(count: int) -> Array[Rect2]:
	var spans: Array[Rect2] = []
	if count <= 0:
		return spans
	var half_width := opening_width * 0.5
	var half_height := opening_height * 0.5
	if count == 1:
		spans.append(Rect2(-half_width, -half_height, opening_width, opening_height))
		return spans
	var seam_gap := minf(0.035, opening_width * 0.08)
	var panel_width := maxf((opening_width - seam_gap) * 0.5, 0.01)
	var offset_x := panel_width * 0.5 + seam_gap * 0.5
	spans.append(Rect2(-offset_x - panel_width * 0.5, -half_height, panel_width, opening_height))
	spans.append(Rect2(offset_x - panel_width * 0.5, -half_height, panel_width, opening_height))
	return spans


func _leaf_part_name(base: String, index: int, count: int) -> String:
	if count <= 1:
		return base
	return ("Left" if index == 0 else "Right") + base


func _add_window_pane(part_name: String, rect: Rect2) -> void:
	_add_glass(part_name, rect, window_pane_depth, window_pane_color)
