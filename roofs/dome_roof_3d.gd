@tool
class_name DomeRoof3D
extends "res://addons/low_poly_building_editor/roofs/sloped_roof_3d.gd"

const StyleGeometry := preload(
	"res://addons/low_poly_building_editor/roofs/dome_roof_geometry_3d.gd"
)


func get_roof_style() -> String:
	return "dome"


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()
