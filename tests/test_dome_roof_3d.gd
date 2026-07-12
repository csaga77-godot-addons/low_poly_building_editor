extends Node3D

const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const BuildingSpecScript = preload(
	"res://addons/low_poly_building_editor/building_spec.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const DomeRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/dome_roof_3d.gd"
)
const RoofStyleGeometryFactory := preload(
	"res://addons/low_poly_building_editor/roofs/roof_style_geometry_factory_3d.gd"
)

var m_failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_validate_typed_style()
	_validate_geometry()
	_validate_building_spec()
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: DomeRoof3D smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_typed_style() -> void:
	if !BuildingFactoryScript.is_roof_style_supported("dome"):
		m_failures.append("BuildingFactory does not publish the dome roof style")
		return
	var dome := BuildingFactoryScript.instantiate_roof_style("dome")
	if dome == null or dome.get_script() != DomeRoof3DScript:
		m_failures.append("BuildingFactory did not instantiate DomeRoof3D")
	if dome != null:
		dome.free()


func _validate_geometry() -> void:
	var dome := BuildingFactoryScript.create_roof_node(
		self,
		Vector3.ZERO,
		Vector3(6.0, 0.0, 6.0),
		"dome",
		45.0,
		0.12,
		0.0,
		Color(0.56, 0.16, 0.24, 1.0)
	)
	add_child(dome)
	if dome.mesh == null:
		m_failures.append("DomeRoof3D did not generate a mesh")
		return
	var arrays := dome.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size() != 928:
		m_failures.append("DomeRoof3D generated the wrong faceted vertex count")
	var expected_height := RoofStyleGeometryFactory.dome_height_for_angle_degrees(
		dome.get_roof_size(),
		dome.roof_overhang,
		dome.get_roof_angle_degrees()
	)
	var center := dome.get_roof_size() * 0.5
	if absf(dome.get_roof_height_at_local_render_point(center) - expected_height) > 0.001:
		m_failures.append("DomeRoof3D center sample does not match its peak")
	if absf(dome.get_roof_height_at_local_render_point(Vector2(0.0, center.y))) > 0.001:
		m_failures.append("DomeRoof3D did not return to the eave plane")
	if !_has_vertex_near(vertices, Vector3(center.x, expected_height, center.y)):
		m_failures.append("DomeRoof3D mesh is missing its centered peak")
	if !_has_sloped_upward_normal(normals):
		m_failures.append("DomeRoof3D is missing upward faceted normals")
	if RoofStyleGeometryFactory.roof_top_faces_for_style(
		"dome",
		dome.get_roof_size(),
		dome.roof_overhang,
		{"angle_degrees": dome.get_roof_angle_degrees()}
	).size() != 144:
		m_failures.append("DomeRoof3D did not publish every top face")
	if dome.get_node_or_null("RoofCollision") == null:
		m_failures.append("DomeRoof3D did not generate collision")


func _validate_building_spec() -> void:
	var spec := BuildingSpecScript.new() as BuildingSpecScript
	spec.roof_style = "dome"
	var result := BuildingSpecCompilerScript.compile(spec)
	var building := result.get("building")
	if building == null:
		m_failures.append(
			"BuildingSpecCompiler rejected dome style: %s"
			% [result.get("errors", [])]
		)
		return
	var roofs: Array = building.get_roof_nodes()
	if roofs.size() != 1 or roofs[0].get_roof_style() != "dome":
		m_failures.append("BuildingSpecCompiler did not generate DomeRoof3D")
	building.free()


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
