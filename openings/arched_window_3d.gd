@tool
class_name ArchedWindow3D
extends "res://addons/low_poly_building_editor/openings/window_pane_3d.gd"

@export_range(1, 6, 1) var arch_steps := 3:
	set(value):
		var clamped_value := clampi(value, 1, 6)
		if arch_steps == clamped_value:
			return
		arch_steps = clamped_value
		_request_rebuild()


func _build_opening_content() -> void:
	var spans := _leaf_spans(1)
	var rect := spans[0]
	_add_window_pane("WindowPane", rect)
	var zone := minf(rect.size.x * 0.45, rect.size.y * 0.5)
	if zone <= 0.001:
		return
	var band_height := zone / float(arch_steps)
	var fill_depth := maxf(window_pane_depth + 0.01, frame_depth)
	for index in range(arch_steps):
		var fill := zone * (1.0 - float(index) / float(arch_steps))
		if fill <= 0.001:
			continue
		var y := rect.end.y - band_height * (float(index) + 0.5)
		_add_box(
			"WindowPaneArchL%d" % index,
			Vector3(fill, band_height, fill_depth),
			Vector3(rect.position.x + fill * 0.5, y, 0.0),
			frame_color,
			false
		)
		_add_box(
			"WindowPaneArchR%d" % index,
			Vector3(fill, band_height, fill_depth),
			Vector3(rect.end.x - fill * 0.5, y, 0.0),
			frame_color,
			false
		)
