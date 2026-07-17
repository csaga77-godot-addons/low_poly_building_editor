@tool
class_name StreetJunctionData
extends Resource

enum ElevationMode {
	FOLLOW_TERRAIN,
	MANUAL,
}

@export var stable_id := "":
	set(value):
		var normalized := value.strip_edges()
		if stable_id == normalized:
			return
		stable_id = normalized
		emit_changed()
@export var position := Vector3.ZERO:
	set(value):
		if position.is_equal_approx(value):
			return
		position = value
		emit_changed()
@export_enum("Follow Terrain", "Manual") var elevation_mode: int = ElevationMode.MANUAL:
	set(value):
		var normalized := clampi(value, ElevationMode.FOLLOW_TERRAIN, ElevationMode.MANUAL)
		if elevation_mode == normalized:
			return
		elevation_mode = normalized
		emit_changed()
@export var provenance: StringName = &"authored":
	set(value):
		if provenance == value:
			return
		provenance = value
		emit_changed()
@export var locked := false:
	set(value):
		if locked == value:
			return
		locked = value
		emit_changed()
