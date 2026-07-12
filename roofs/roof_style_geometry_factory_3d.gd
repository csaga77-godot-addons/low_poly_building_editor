@tool
extends RefCounted

const STYLE_FLAT := "flat"
const STYLE_SHED := "shed"
const STYLE_GABLE := "gable"
const STYLE_HIP := "hip"
const STYLE_PYRAMID_HIP := "pyramid_hip"
const STYLE_HEXAGONAL_HIP := "hexagonal_hip"
const STYLE_OCTAGON_HIP := "octagon_hip"
const STYLE_DOME := "dome"

## Hip shape identifiers. These mirror HipRoof3D.HipShape and select the internal
## geometry strategy for the single public "hip" roof style.
const HIP_SHAPE_STANDARD := 0
const HIP_SHAPE_PYRAMID := 1
const HIP_SHAPE_HEXAGONAL := 2
const HIP_SHAPE_OCTAGON := 3

const FlatGeometry := preload("res://addons/low_poly_building_editor/roofs/roof_style_geometry_3d.gd")
const ShedGeometry := preload("res://addons/low_poly_building_editor/roofs/shed_roof_geometry_3d.gd")
const GableGeometry := preload("res://addons/low_poly_building_editor/roofs/gable_roof_geometry_3d.gd")
const HipGeometry := preload("res://addons/low_poly_building_editor/roofs/hip_roof_geometry_3d.gd")
const PyramidHipGeometry := preload("res://addons/low_poly_building_editor/roofs/pyramid_hip_geometry_3d.gd")
const HexagonalHipGeometry := preload("res://addons/low_poly_building_editor/roofs/hexagonal_hip_geometry_3d.gd")
const OctagonHipGeometry := preload("res://addons/low_poly_building_editor/roofs/octagon_hip_geometry_3d.gd")
const DomeGeometry := preload("res://addons/low_poly_building_editor/roofs/dome_roof_geometry_3d.gd")


static func create(style: String) -> RefCounted:
	match style.strip_edges().to_lower():
		STYLE_FLAT:
			return FlatGeometry.new()
		STYLE_SHED:
			return ShedGeometry.new()
		STYLE_GABLE:
			return GableGeometry.new()
		STYLE_HIP:
			return HipGeometry.new()
		STYLE_PYRAMID_HIP:
			return PyramidHipGeometry.new()
		STYLE_HEXAGONAL_HIP:
			return HexagonalHipGeometry.new()
		STYLE_OCTAGON_HIP:
			return OctagonHipGeometry.new()
		STYLE_DOME:
			return DomeGeometry.new()
	push_error("Unsupported roof geometry style: %s" % style)
	return null


## Maps a hip shape identifier to its internal geometry style key.
static func hip_geometry_style_for_shape(hip_shape: int) -> String:
	match hip_shape:
		HIP_SHAPE_PYRAMID:
			return STYLE_PYRAMID_HIP
		HIP_SHAPE_HEXAGONAL:
			return STYLE_HEXAGONAL_HIP
		HIP_SHAPE_OCTAGON:
			return STYLE_OCTAGON_HIP
	return STYLE_HIP


## Resolves the geometry style for a public roof style, expanding the hip style
## into its authored pavilion shape when requested through parameters.
static func _effective_geometry_style(style: String, parameters: Dictionary) -> String:
	if style.strip_edges().to_lower() == STYLE_HIP:
		return hip_geometry_style_for_shape(
			int(parameters.get("hip_shape", HIP_SHAPE_STANDARD))
		)
	return style


static func roof_height_for_angle_degrees(run: float, angle_degrees: float) -> float:
	return FlatGeometry.roof_height_for_angle(run, angle_degrees)


static func sloped_parameters(angle_degrees: float) -> Dictionary:
	return {"angle_degrees": angle_degrees}


static func hip_parameters(
	angle_degrees: float,
	gable_height_from_peak: float
) -> Dictionary:
	return {
		"angle_degrees": angle_degrees,
		"gable_height_from_peak": gable_height_from_peak,
	}


static func shed_height_for_angle_degrees(
	depth: float,
	overhang: float,
	angle_degrees: float
) -> float:
	return ShedGeometry.new().generated_height(
		Vector2(0.0, depth), overhang, sloped_parameters(angle_degrees)
	)


static func shed_roof_run_for_depth(depth: float, overhang: float) -> float:
	return ShedGeometry.new().roof_run(Vector2(0.0, depth), overhang)


static func gable_height_for_angle_degrees(
	depth: float,
	overhang: float,
	angle_degrees: float
) -> float:
	return GableGeometry.new().generated_height(
		Vector2(0.0, depth), overhang, sloped_parameters(angle_degrees)
	)


static func gable_roof_run_for_depth(depth: float, overhang: float) -> float:
	return GableGeometry.new().roof_run(Vector2(0.0, depth), overhang)


static func hip_height_for_angle_degrees(
	size: Vector2,
	overhang: float,
	angle_degrees: float
) -> float:
	return HipGeometry.new().generated_height(
		size, overhang, sloped_parameters(angle_degrees)
	)


static func hip_roof_run_for_size(size: Vector2, overhang: float) -> float:
	return HipGeometry.new().roof_run(size, overhang)


static func dome_height_for_angle_degrees(
	size: Vector2,
	overhang: float,
	angle_degrees: float
) -> float:
	return DomeGeometry.new().generated_height(
		size, overhang, sloped_parameters(angle_degrees)
	)


static func dome_roof_run_for_size(size: Vector2, overhang: float) -> float:
	return DomeGeometry.new().roof_run(size, overhang)


static func hip_roof_ridge_points_for_size(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> PackedVector3Array:
	return HipGeometry.new().ridge_points(
		size, overhang, angle_degrees, gable_height_from_peak
	)


static func roof_generated_height_for_style(
	style: String,
	size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> float:
	var geometry := create(_effective_geometry_style(style, parameters))
	return (
		geometry.generated_height(size, overhang, parameters)
		if geometry != null
		else 0.0
	)


static func roof_surface_height_for_style(
	style: String,
	size: Vector2,
	overhang: float,
	local_render_point: Vector2,
	parameters: Dictionary = {}
) -> float:
	var geometry := create(_effective_geometry_style(style, parameters))
	if geometry == null:
		return 0.0
	return geometry.surface_height(
		size,
		overhang,
		local_render_point,
		parameters
	)


static func roof_top_triangles_for_style(
	style: String,
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[PackedVector3Array]:
	var geometry := create(_effective_geometry_style(style, parameters))
	if geometry == null:
		return []
	return geometry.top_triangles(
		full_size,
		overhang,
		parameters
	)


static func roof_top_faces_for_style(
	style: String,
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[Dictionary]:
	var geometry := create(_effective_geometry_style(style, parameters))
	if geometry == null:
		return []
	return geometry.top_faces(
		full_size,
		overhang,
		parameters
	)
