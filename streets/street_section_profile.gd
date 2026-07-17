@tool
class_name StreetSectionProfile
extends Resource

## Reusable cross-section shared by one or more StreetSegmentData resources.
## Left/right widths are explicit so unequal approaches and island footpaths do
## not have to be represented as overlapping Street3D nodes.

@export_group("Road")
@export_range(0.1, 20.0, 0.05, "or_greater") var road_width := 3.2:
	set(value):
		var normalized := maxf(value, 0.1)
		if is_equal_approx(road_width, normalized):
			return
		road_width = normalized
		emit_changed()
@export_range(0.01, 2.0, 0.01, "or_greater") var road_thickness := 0.18:
	set(value):
		var normalized := maxf(value, 0.01)
		if is_equal_approx(road_thickness, normalized):
			return
		road_thickness = normalized
		emit_changed()
@export var road_color := Color(0.38, 0.37, 0.34, 1.0):
	set(value):
		if road_color.is_equal_approx(value):
			return
		road_color = value
		emit_changed()

@export_group("Left Side")
@export_range(0.0, 2.0, 0.01, "or_greater") var left_kerb_width := 0.18:
	set(value):
		var normalized := maxf(value, 0.0)
		if is_equal_approx(left_kerb_width, normalized):
			return
		left_kerb_width = normalized
		emit_changed()
@export_range(0.0, 10.0, 0.05, "or_greater") var left_footpath_width := 1.1:
	set(value):
		var normalized := maxf(value, 0.0)
		if is_equal_approx(left_footpath_width, normalized):
			return
		left_footpath_width = normalized
		emit_changed()

@export_group("Right Side")
@export_range(0.0, 2.0, 0.01, "or_greater") var right_kerb_width := 0.18:
	set(value):
		var normalized := maxf(value, 0.0)
		if is_equal_approx(right_kerb_width, normalized):
			return
		right_kerb_width = normalized
		emit_changed()
@export_range(0.0, 10.0, 0.05, "or_greater") var right_footpath_width := 1.1:
	set(value):
		var normalized := maxf(value, 0.0)
		if is_equal_approx(right_footpath_width, normalized):
			return
		right_footpath_width = normalized
		emit_changed()

@export_group("Kerb And Footpath")
@export_range(0.0, 1.0, 0.01, "or_greater") var kerb_height := 0.14:
	set(value):
		var normalized := maxf(value, 0.0)
		if is_equal_approx(kerb_height, normalized):
			return
		kerb_height = normalized
		emit_changed()
@export var kerb_color := Color(0.66, 0.64, 0.59, 1.0):
	set(value):
		if kerb_color.is_equal_approx(value):
			return
		kerb_color = value
		emit_changed()
@export_range(0.01, 2.0, 0.01, "or_greater") var footpath_thickness := 0.16:
	set(value):
		var normalized := maxf(value, 0.01)
		if is_equal_approx(footpath_thickness, normalized):
			return
		footpath_thickness = normalized
		emit_changed()
@export var footpath_color := Color(0.72, 0.67, 0.57, 1.0):
	set(value):
		if footpath_color.is_equal_approx(value):
			return
		footpath_color = value
		emit_changed()

@export_group("Automatic Footpath Stairs")
@export_range(0.0, 89.0, 0.1) var stair_threshold_degrees := 25.0:
	set(value):
		var normalized := clampf(value, 0.0, 89.0)
		if is_equal_approx(stair_threshold_degrees, normalized):
			return
		stair_threshold_degrees = normalized
		stair_exit_threshold_degrees = minf(stair_exit_threshold_degrees, normalized)
		emit_changed()
@export_range(0.0, 89.0, 0.1) var stair_exit_threshold_degrees := 22.0:
	set(value):
		var normalized := clampf(value, 0.0, stair_threshold_degrees)
		if is_equal_approx(stair_exit_threshold_degrees, normalized):
			return
		stair_exit_threshold_degrees = normalized
		emit_changed()
@export_range(0.1, 20.0, 0.1, "or_greater") var minimum_stair_run_length := 1.0:
	set(value):
		var normalized := maxf(value, 0.1)
		if is_equal_approx(minimum_stair_run_length, normalized):
			return
		minimum_stair_run_length = normalized
		emit_changed()
@export_range(0.01, 10.0, 0.01, "or_greater") var minimum_stair_run_rise := 0.16:
	set(value):
		var normalized := maxf(value, 0.01)
		if is_equal_approx(minimum_stair_run_rise, normalized):
			return
		minimum_stair_run_rise = normalized
		emit_changed()
@export_range(0.02, 1.0, 0.01, "or_greater") var target_riser_height := 0.16:
	set(value):
		var normalized := maxf(value, 0.02)
		if is_equal_approx(target_riser_height, normalized):
			return
		target_riser_height = normalized
		max_riser_height = maxf(max_riser_height, normalized)
		emit_changed()
@export_range(0.02, 1.0, 0.01, "or_greater") var max_riser_height := 0.18:
	set(value):
		var normalized := maxf(value, target_riser_height)
		if is_equal_approx(max_riser_height, normalized):
			return
		max_riser_height = normalized
		emit_changed()
@export_range(0.05, 2.0, 0.01, "or_greater") var min_tread_depth := 0.24:
	set(value):
		var normalized := maxf(value, 0.05)
		if is_equal_approx(min_tread_depth, normalized):
			return
		min_tread_depth = normalized
		emit_changed()

@export_group("Terrain")
@export_range(-1.0, 2.0, 0.005) var terrain_clearance := 0.025:
	set(value):
		if is_equal_approx(terrain_clearance, value):
			return
		terrain_clearance = value
		emit_changed()


func left_half_width() -> float:
	return road_width * 0.5 + left_kerb_width + left_footpath_width


func right_half_width() -> float:
	return road_width * 0.5 + right_kerb_width + right_footpath_width


func maximum_half_width() -> float:
	return maxf(left_half_width(), right_half_width())


func duplicate_profile() -> StreetSectionProfile:
	return duplicate(true) as StreetSectionProfile
