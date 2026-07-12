@tool
class_name GridWindow3D
extends "res://addons/low_poly_building_editor/openings/window_pane_3d.gd"

@export_range(0, 8, 1) var pane_grid_rows := 2:
	set(value):
		var clamped_value := clampi(value, 0, 8)
		if pane_grid_rows == clamped_value:
			return
		pane_grid_rows = clamped_value
		_request_rebuild()

@export_range(0, 8, 1) var pane_grid_cols := 1:
	set(value):
		var clamped_value := clampi(value, 0, 8)
		if pane_grid_cols == clamped_value:
			return
		pane_grid_cols = clamped_value
		_request_rebuild()

@export_range(0.005, 0.3, 0.005) var muntin_thickness := 0.03:
	set(value):
		var clamped_value := clampf(value, 0.005, 0.3)
		if is_equal_approx(muntin_thickness, clamped_value):
			return
		muntin_thickness = clamped_value
		_request_rebuild()


func _build_opening_content() -> void:
	var spans := _leaf_spans(1)
	var rect := spans[0]
	_add_window_pane("WindowPane", rect)
	var bar_depth := maxf(window_pane_depth + 0.01, frame_depth * 0.6)
	var center_x := rect.position.x + rect.size.x * 0.5
	var center_y := rect.position.y + rect.size.y * 0.5
	for row in range(pane_grid_rows):
		var y := rect.position.y + rect.size.y * float(row + 1) / float(pane_grid_rows + 1)
		_add_box(
			"WindowPaneMuntinH%d" % row,
			Vector3(rect.size.x, muntin_thickness, bar_depth),
			Vector3(center_x, y, 0.0),
			frame_color,
			false
		)
	for col in range(pane_grid_cols):
		var x := rect.position.x + rect.size.x * float(col + 1) / float(pane_grid_cols + 1)
		_add_box(
			"WindowPaneMuntinV%d" % col,
			Vector3(muntin_thickness, rect.size.y, bar_depth),
			Vector3(x, center_y, 0.0),
			frame_color,
			false
		)
