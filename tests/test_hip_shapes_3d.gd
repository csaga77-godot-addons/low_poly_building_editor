extends Node3D

const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const HipRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/hip_roof_3d.gd"
)
const RoofStyleGeometryFactory := preload(
	"res://addons/low_poly_building_editor/roofs/roof_style_geometry_factory_3d.gd"
)

var m_failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	# Pavilion apex shapes on a square footprint publish one top face per side;
	# the standard hip degenerates to a four-face centered apex on a square.
	var cases := [
		{"shape": HipRoof3DScript.HipShape.STANDARD, "faces": 4},
		{"shape": HipRoof3DScript.HipShape.PYRAMID, "faces": 4},
		{"shape": HipRoof3DScript.HipShape.HEXAGONAL, "faces": 6},
		{"shape": HipRoof3DScript.HipShape.OCTAGON, "faces": 8},
	]
	for hip_case in cases:
		_validate_shape_geometry(hip_case)
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: Hip shape substyles smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_shape_geometry(hip_case: Dictionary) -> void:
	var shape := int(hip_case["shape"])
	var roof := BuildingFactoryScript.create_roof_node(
		self,
		Vector3.ZERO,
		Vector3(6.0, 0.0, 6.0),
		"hip",
		45.0,
		0.12,
		0.0,
		Color(0.56, 0.16, 0.24, 1.0),
		0.0,
		0.0,
		shape
	) as HipRoof3DScript
	add_child(roof)
	if roof.get_hip_shape() != shape:
		m_failures.append("Hip roof did not apply shape %d" % shape)
	if roof.mesh == null:
		m_failures.append("Hip shape %d did not generate a mesh" % shape)
		return
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var parameters := {"angle_degrees": roof.get_roof_angle_degrees(), "hip_shape": shape}
	var expected_height := RoofStyleGeometryFactory.roof_generated_height_for_style(
		"hip", roof.get_roof_size(), roof.roof_overhang, parameters
	)
	if expected_height <= 0.0:
		m_failures.append("Hip shape %d did not derive a height from the angle" % shape)
	var center := roof.get_roof_size() * 0.5
	if absf(roof.get_roof_height_at_local_render_point(center) - expected_height) > 0.001:
		m_failures.append("Hip shape %d center sample does not match its apex" % shape)
	if !_has_vertex_near(vertices, Vector3(center.x, expected_height, center.y)):
		m_failures.append("Hip shape %d mesh is missing its centered apex" % shape)
	if !_has_sloped_upward_normal(normals):
		m_failures.append("Hip shape %d is missing upward sloped normals" % shape)
	if RoofStyleGeometryFactory.roof_top_faces_for_style(
		"hip", roof.get_roof_size(), roof.roof_overhang, parameters
	).size() != int(hip_case["faces"]):
		m_failures.append("Hip shape %d published the wrong top-face count" % shape)
	if roof.get_node_or_null("RoofCollision") == null:
		m_failures.append("Hip shape %d did not generate collision" % shape)


static func _has_vertex_near(vertices: PackedVector3Array, expected: Vector3) -> bool:
	for vertex in vertices:
		if vertex.distance_to(expected) <= 0.001:
			return true
	return false


static func _has_sloped_upward_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if normal.y > 0.2 and normal.y < 0.99:
			return true
	return false
