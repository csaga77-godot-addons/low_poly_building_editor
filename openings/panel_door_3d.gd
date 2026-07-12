@tool
class_name PanelDoor3D
extends "res://addons/low_poly_building_editor/openings/leafed_door_3d.gd"

@export_range(0, 4, 1) var door_inset_rows := 3:
	set(value):
		var clamped_value := clampi(value, 0, 4)
		if door_inset_rows == clamped_value:
			return
		door_inset_rows = clamped_value
		_request_rebuild()

@export_range(0, 3, 1) var door_inset_cols := 2:
	set(value):
		var clamped_value := clampi(value, 0, 3)
		if door_inset_cols == clamped_value:
			return
		door_inset_cols = clamped_value
		_request_rebuild()


func _build_opening_content() -> void:
	var spans := _leaf_spans(1)
	_build_panel_door_face("DoorPanel", spans[0])


func _build_panel_door_face(part_name: String, rect: Rect2) -> void:
	_add_solid_door_panel(part_name, rect)
	if door_inset_rows <= 0 or door_inset_cols <= 0:
		return
	var margin := minf(minf(rect.size.x, rect.size.y) * 0.18, 0.12)
	var cell_width := (
		(rect.size.x - margin * float(door_inset_cols + 1))
		/ float(door_inset_cols)
	)
	var cell_height := (
		(rect.size.y - margin * float(door_inset_rows + 1))
		/ float(door_inset_rows)
	)
	if cell_width <= 0.02 or cell_height <= 0.02:
		return
	var raise := door_panel_depth * 0.6
	for row in range(door_inset_rows):
		for col in range(door_inset_cols):
			var x := rect.position.x + margin * float(col + 1) + cell_width * (float(col) + 0.5)
			var y := rect.position.y + margin * float(row + 1) + cell_height * (float(row) + 0.5)
			_add_box(
				"%sInset%d_%d" % [part_name, row, col],
				Vector3(cell_width, cell_height, door_panel_depth + raise),
				Vector3(x, y, 0.0),
				door_panel_color,
				false
			)
