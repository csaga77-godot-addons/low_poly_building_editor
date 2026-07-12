@tool
class_name StreetProfilePoint
extends Resource

@export_range(0.0, 100000.0, 0.01, "or_greater") var path_distance := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(path_distance, clamped_value):
			return
		path_distance = clamped_value
		emit_changed()

## Position is parent-local to the owning Building3D. X/Z come from the
## sampled street path; Y is the baked terrain height or a manual override.
@export var position := Vector3.ZERO:
	set(value):
		if position.is_equal_approx(value):
			return
		position = value
		emit_changed()

@export var manual_height := false:
	set(value):
		if manual_height == value:
			return
		manual_height = value
		emit_changed()
