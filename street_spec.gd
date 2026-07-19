@tool
class_name StreetSpec
extends "res://addons/low_poly_building_editor/building_generation_spec.gd"

enum CrossSectionMode {
	ROAD_ONLY,
	FOOTPATH_ONLY,
	ROAD_AND_FOOTPATH,
}

@export var path_points := PackedVector3Array([
	Vector3.ZERO,
	Vector3(0.0, 0.0, 8.0),
])

@export_group("Cross Section")
@export_enum("Road Only", "Footpath Only", "Road + Footpath") var cross_section_mode: int = CrossSectionMode.ROAD_AND_FOOTPATH

@export_group("Road")
@export_range(0.1, 20.0, 0.05, "or_greater") var road_width := 3.2
@export_range(0.01, 2.0, 0.01, "or_greater") var road_thickness := 0.18
@export var road_color := Color(0.38, 0.37, 0.34, 1.0)

@export_group("Kerb")
@export_range(0.01, 2.0, 0.01, "or_greater") var kerb_width := 0.18
@export_range(0.01, 1.0, 0.01, "or_greater") var kerb_height := 0.14
@export var kerb_color := Color(0.66, 0.64, 0.59, 1.0)

@export_group("Footpath")
@export_range(0.05, 10.0, 0.05, "or_greater") var footpath_width := 1.1
@export_range(0.01, 2.0, 0.01, "or_greater") var footpath_thickness := 0.16
@export var footpath_color := Color(0.72, 0.67, 0.57, 1.0)

@export_group("Automatic Footpath Stairs")
@export_range(0.0, 89.0, 0.1) var stair_threshold_degrees := 25.0
@export_range(0.02, 1.0, 0.01, "or_greater") var target_riser_height := 0.16
@export_range(0.02, 1.0, 0.01, "or_greater") var max_riser_height := 0.18
@export_range(0.05, 2.0, 0.01, "or_greater") var min_tread_depth := 0.24


func _init() -> void:
	generation_type = "street"
	building_name = "GeneratedStreet"


func validate() -> Array[String]:
	var errors: Array[String] = super.validate()
	if generation_type != "street":
		errors.append("StreetSpec type must be 'street'.")
	if path_points.size() < 2:
		errors.append("path must contain at least two [x, y, z] points.")
	if cross_section_mode < CrossSectionMode.ROAD_ONLY or cross_section_mode > CrossSectionMode.ROAD_AND_FOOTPATH:
		errors.append("cross_section_mode must be road_only, footpath_only, or road_and_footpath.")
	if road_width < 0.1:
		errors.append("road.width is below its supported minimum.")
	if cross_section_mode != CrossSectionMode.FOOTPATH_ONLY and road_thickness < 0.01:
		errors.append("road.thickness is below its supported minimum.")
	if (
		cross_section_mode == CrossSectionMode.ROAD_AND_FOOTPATH
		and (kerb_width < 0.01 or kerb_height < 0.01)
	):
		errors.append("Kerb width/height are below their supported minimums.")
	if cross_section_mode == CrossSectionMode.ROAD_AND_FOOTPATH and footpath_width < 0.05:
		errors.append("footpath.width is below its supported minimum.")
	if cross_section_mode != CrossSectionMode.ROAD_ONLY and footpath_thickness < 0.01:
		errors.append("footpath.thickness is below its supported minimum.")
	if (
		cross_section_mode != CrossSectionMode.ROAD_ONLY
		and max_riser_height < target_riser_height
	):
		errors.append("stairs.max_riser_height must be at least target_riser_height.")
	for index in range(path_points.size() - 1):
		var a := path_points[index]
		var b := path_points[index + 1]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if run <= 0.00001:
			errors.append("path segment %d has zero horizontal length." % index)
			continue
		var rise := absf(b.y - a.y)
		if cross_section_mode == CrossSectionMode.ROAD_ONLY:
			continue
		if rad_to_deg(atan2(rise, run)) <= stair_threshold_degrees + 0.0001:
			continue
		if ceili(rise / max_riser_height) > floori(run / min_tread_depth):
			errors.append("path segment %d cannot fit valid footpath stairs." % index)
	return errors


func apply_dictionary(source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	apply_common_dictionary(source, "street")
	path_points = _parse_path(source.get("path", path_points), errors)
	cross_section_mode = _parse_cross_section_mode(
		source.get("cross_section_mode", cross_section_mode_key()), errors
	)
	var road := _section(source, "road", errors)
	road_width = float(road.get("width", road_width))
	road_thickness = float(road.get("thickness", road_thickness))
	road_color = _color(road.get("color", road_color), road_color, "road.color", errors)
	var kerb := _section(source, "kerb", errors)
	kerb_width = float(kerb.get("width", kerb_width))
	kerb_height = float(kerb.get("height", kerb_height))
	kerb_color = _color(kerb.get("color", kerb_color), kerb_color, "kerb.color", errors)
	var footpath := _section(source, "footpath", errors)
	footpath_width = float(footpath.get("width", footpath_width))
	footpath_thickness = float(footpath.get("thickness", footpath_thickness))
	footpath_color = _color(footpath.get("color", footpath_color), footpath_color, "footpath.color", errors)
	var stairs := _section(source, "stairs", errors)
	stair_threshold_degrees = float(stairs.get("threshold_degrees", stair_threshold_degrees))
	target_riser_height = float(stairs.get("target_riser_height", target_riser_height))
	max_riser_height = float(stairs.get("max_riser_height", max_riser_height))
	min_tread_depth = float(stairs.get("min_tread_depth", min_tread_depth))
	errors.append_array(validate())
	return errors


func to_dictionary() -> Dictionary:
	var result := common_dictionary()
	var serialized_path: Array[Array] = []
	for point in path_points:
		serialized_path.append([point.x, point.y, point.z])
	result.merge({
		"path": serialized_path,
		"cross_section_mode": cross_section_mode_key(),
		"road": {"width": road_width, "thickness": road_thickness, "color": road_color.to_html(true)},
		"kerb": {"width": kerb_width, "height": kerb_height, "color": kerb_color.to_html(true)},
		"footpath": {"width": footpath_width, "thickness": footpath_thickness, "color": footpath_color.to_html(true)},
		"stairs": {
			"threshold_degrees": stair_threshold_degrees,
			"target_riser_height": target_riser_height,
			"max_riser_height": max_riser_height,
			"min_tread_depth": min_tread_depth,
		},
	})
	return result


func cross_section_mode_key() -> String:
	match cross_section_mode:
		CrossSectionMode.ROAD_ONLY:
			return "road_only"
		CrossSectionMode.FOOTPATH_ONLY:
			return "footpath_only"
		_:
			return "road_and_footpath"


static func _parse_cross_section_mode(value: Variant, errors: Array[String]) -> int:
	if value is int or value is float:
		var numeric := int(value)
		if numeric >= CrossSectionMode.ROAD_ONLY and numeric <= CrossSectionMode.ROAD_AND_FOOTPATH:
			return numeric
	var key := String(value).strip_edges().to_lower()
	match key:
		"road_only", "road":
			return CrossSectionMode.ROAD_ONLY
		"footpath_only", "footpath":
			return CrossSectionMode.FOOTPATH_ONLY
		"road_and_footpath", "both":
			return CrossSectionMode.ROAD_AND_FOOTPATH
	errors.append("cross_section_mode must be road_only, footpath_only, or road_and_footpath.")
	return CrossSectionMode.ROAD_AND_FOOTPATH


static func _parse_path(value: Variant, errors: Array[String]) -> PackedVector3Array:
	var result := PackedVector3Array()
	if !(value is Array or value is PackedVector3Array):
		errors.append("path must be an array of [x, y, z] points.")
		return result
	for index in range(value.size()):
		var entry: Variant = value[index]
		if entry is Vector3:
			result.append(entry)
		elif entry is Array and entry.size() == 3:
			result.append(Vector3(float(entry[0]), float(entry[1]), float(entry[2])))
		else:
			errors.append("path[%d] must be a three-element number array." % index)
	return result


static func _section(source: Dictionary, key: String, errors: Array[String]) -> Dictionary:
	if !source.has(key):
		return {}
	if source[key] is Dictionary:
		return source[key]
	errors.append("%s must be a JSON object." % key)
	return {}


static func _color(value: Variant, fallback: Color, field: String, errors: Array[String]) -> Color:
	if value is Color:
		return value
	if value is String and Color.html_is_valid(String(value)):
		return Color.from_string(String(value), fallback)
	errors.append("%s must be a valid HTML color string." % field)
	return fallback
