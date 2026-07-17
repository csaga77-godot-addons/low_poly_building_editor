@tool
class_name StreetSegmentData
extends Resource

enum CurveMode {
	STRAIGHT,
	CUBIC_BEZIER,
	POLYLINE,
}

enum VerticalMode {
	FOLLOW_TERRAIN,
	GRADED,
	MANUAL,
}

@export var stable_id := "":
	set(value):
		var normalized := value.strip_edges()
		if stable_id == normalized:
			return
		stable_id = normalized
		emit_changed()
@export var start_junction_id := "":
	set(value):
		var normalized := value.strip_edges()
		if start_junction_id == normalized:
			return
		start_junction_id = normalized
		emit_changed()
@export var end_junction_id := "":
	set(value):
		var normalized := value.strip_edges()
		if end_junction_id == normalized:
			return
		end_junction_id = normalized
		emit_changed()

@export_group("Horizontal Curve")
@export_enum("Straight", "Cubic Bezier", "Polyline") var curve_mode: int = CurveMode.STRAIGHT:
	set(value):
		var normalized := clampi(value, CurveMode.STRAIGHT, CurveMode.POLYLINE)
		if curve_mode == normalized:
			return
		curve_mode = normalized
		emit_changed()
## Parent-local offsets from the start/end junction positions.
@export var start_handle := Vector3.ZERO:
	set(value):
		if start_handle.is_equal_approx(value):
			return
		start_handle = value
		emit_changed()
@export var end_handle := Vector3.ZERO:
	set(value):
		if end_handle.is_equal_approx(value):
			return
		end_handle = value
		emit_changed()
## Used by imported/mask paths and by topology-preserving segment splits.
@export var polyline_points := PackedVector3Array():
	set(value):
		if polyline_points == value:
			return
		polyline_points = value
		emit_changed()

@export_group("Vertical Profile")
@export_enum("Follow Terrain", "Graded", "Manual") var vertical_mode: int = VerticalMode.GRADED:
	set(value):
		var normalized := clampi(value, VerticalMode.FOLLOW_TERRAIN, VerticalMode.MANUAL)
		if vertical_mode == normalized:
			return
		vertical_mode = normalized
		emit_changed()
## Dense sampled profile. Follow Terrain rewrites automatic values; Manual keeps
## these values authoritative. Empty means derive height from the junctions.
@export var terrain_profile := PackedVector3Array():
	set(value):
		if terrain_profile == value:
			return
		terrain_profile = value
		emit_changed()

@export_group("Section")
@export var section_profile: StreetSectionProfile = StreetSectionProfile.new():
	set(value):
		if section_profile == value:
			return
		if section_profile != null and section_profile.changed.is_connected(_on_section_changed):
			section_profile.changed.disconnect(_on_section_changed)
		section_profile = value if value != null else StreetSectionProfile.new()
		if !section_profile.changed.is_connected(_on_section_changed):
			section_profile.changed.connect(_on_section_changed)
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


func _init() -> void:
	if section_profile != null and !section_profile.changed.is_connected(_on_section_changed):
		section_profile.changed.connect(_on_section_changed)


func _on_section_changed() -> void:
	emit_changed()
