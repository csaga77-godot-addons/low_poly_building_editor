@tool
extends Node3D

const StreetNetwork3DScript = preload(
	"res://addons/low_poly_building_editor/streets/street_network_3d.gd"
)

var m_failures: Array[String] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run_checks")


func _run_checks() -> void:
	_validate_five_arm_junction_and_asymmetric_profile()
	_validate_three_arm_junction_surface_connection()
	_validate_adaptive_cubic_sampling()
	_validate_same_level_crossing_topology()
	_validate_vertical_crossing_independence()
	_validate_coherent_stair_runs()
	_validate_legacy_migration_preserves_geometry()
	_validate_split_merge_and_state_restore()
	_validate_local_dirty_rebuild()
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: StreetNetwork3D geometry and topology test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_five_arm_junction_and_asymmetric_profile() -> void:
	var network := _make_network()
	var profile := StreetSectionProfile.new()
	profile.left_kerb_width = 0.12
	profile.right_kerb_width = 0.32
	profile.left_footpath_width = 0.7
	profile.right_footpath_width = 1.6
	var paths: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3.ZERO, Vector3(8.0, 0.0, 0.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(-8.0, 0.0, 0.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 8.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, -8.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(6.0, 0.0, 6.0)]),
	]
	network.add_paths(paths, profile, &"test", false)
	network.rebuild_network()
	if network.network_data.junctions.size() != 6:
		m_failures.append("Five-arm network did not consolidate its shared endpoint into one junction")
	if network.network_data.segments.size() != 5:
		m_failures.append("Five-arm network did not retain five explicit segments")
	var central := network.find_nearest_junction(Vector3.ZERO, 0.01)
	if central.is_empty():
		m_failures.append("Five-arm network omitted its central junction")
	else:
		var central_id := String(central["junction_id"])
		if network.network_data.incident_segments(central_id).size() != 5:
			m_failures.append("Central street junction does not report degree five")
		var junction_mesh := _junction_child(network, central_id)
		if junction_mesh == null or junction_mesh.mesh == null:
			m_failures.append("Five-arm junction did not generate its dedicated centre mesh")
	var first_child := _segment_child(network, network.network_data.segments[0].stable_id)
	if first_child == null:
		m_failures.append("Network did not generate a Street3D segment cache")
	elif (
		!is_equal_approx(first_child.get_side_kerb_width(true), 0.12)
		or !is_equal_approx(first_child.get_side_footpath_width(false), 1.6)
	):
		m_failures.append("Network segment lost its asymmetric section widths")
	network.queue_free()


func _validate_three_arm_junction_surface_connection() -> void:
	var network := _make_network()
	var profile := StreetSectionProfile.new()
	var paths: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3.ZERO, Vector3(8.0, 0.0, 0.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(-8.0, 0.0, 0.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 8.0)]),
	]
	network.add_paths(paths, profile, &"test", false)
	network.rebuild_network()
	var central := network.find_nearest_junction(Vector3.ZERO, 0.01)
	if central.is_empty():
		m_failures.append("Three-arm network omitted its central junction")
		network.queue_free()
		return
	var central_id := String(central["junction_id"])
	if network.network_data.incident_segments(central_id).size() != 3:
		m_failures.append("Three-arm network central junction does not report degree three")
	var junction_mesh := _junction_child(network, central_id)
	if junction_mesh == null or junction_mesh.mesh == null:
		m_failures.append("Three-arm network did not generate its dedicated centre mesh")
	elif !_mesh_covers_parent_plan_point(
		junction_mesh,
		Vector3(0.0, 0.0, -profile.road_width * 0.25),
		profile.road_color
	):
		m_failures.append("Three-arm network centre mesh left its outer road wedge open")
	var checked_corner_count := 0
	for segment: StreetSegmentData in network.network_data.incident_segments(central_id):
		var street := _segment_child(network, segment.stable_id)
		if street == null:
			m_failures.append("Three-arm network omitted an incident segment mesh")
			continue
		var key := "start" if segment.start_junction_id == central_id else "end"
		var joins: Dictionary = street.get_end_joins().get(key, {})
		for field: String in [
			"left_road", "right_road",
			"left_kerb", "right_kerb",
			"left_foot", "right_foot",
		]:
			if !joins.has(field):
				continue
			checked_corner_count += 1
			var target_color := street.road_color
			if field.ends_with("kerb"):
				target_color = street.kerb_color
			elif field.ends_with("foot"):
				target_color = street.footpath_color
			if !_mesh_reaches_parent_point(street, joins[field], target_color):
				m_failures.append(
					"Three-arm network segment did not reach its shared %s corner" % field
				)
	if checked_corner_count != 12:
		m_failures.append(
			"Three-arm network supplied %d shared ring corners, expected 12"
			% checked_corner_count
		)
	network.queue_free()


func _validate_adaptive_cubic_sampling() -> void:
	var network := _make_network()
	var ids := network.add_path(
		PackedVector3Array([Vector3.ZERO, Vector3(10.0, 2.0, 0.0)]),
		null, &"test", false
	)
	var segment := network.network_data.find_segment(ids[0])
	segment.curve_mode = StreetSegmentData.CurveMode.CUBIC_BEZIER
	segment.start_handle = Vector3(2.0, 0.0, 6.0)
	segment.end_handle = Vector3(-2.0, 0.0, 6.0)
	network.maximum_chord_error = 0.03
	network.rebuild_network()
	var child := _segment_child(network, segment.stable_id)
	if child == null or child.path_points.size() <= 4:
		m_failures.append("Cubic street was not adaptively subdivided")
	elif (
		!is_equal_approx(child.path_points[0].y, 0.0)
		or !is_equal_approx(child.path_points[child.path_points.size() - 1].y, 2.0)
	):
		m_failures.append("Graded cubic street did not preserve endpoint elevations")
	network.queue_free()


func _validate_same_level_crossing_topology() -> void:
	var network := _make_network()
	network.add_path(
		PackedVector3Array([Vector3(-6.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0)]),
		null, &"test", true
	)
	network.add_path(
		PackedVector3Array([Vector3(0.0, 0.0, -6.0), Vector3(0.0, 0.0, 6.0)]),
		null, &"test", true
	)
	network.rebuild_network()
	var crossing := network.find_nearest_junction(Vector3.ZERO, 0.01)
	if crossing.is_empty():
		m_failures.append("Same-level crossing did not create a topology junction")
	elif network.network_data.incident_segments(String(crossing["junction_id"])).size() != 4:
		m_failures.append("Same-level crossing did not split into four incident segments")
	if network.network_data.segments.size() != 4:
		m_failures.append("Same-level crossing produced an unexpected segment count")
	network.queue_free()


func _validate_vertical_crossing_independence() -> void:
	var network := _make_network()
	network.add_path(
		PackedVector3Array([Vector3(-6.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0)]),
		null, &"test", true
	)
	network.add_path(
		PackedVector3Array([Vector3(0.0, 2.0, -6.0), Vector3(0.0, 2.0, 6.0)]),
		null, &"test", true
	)
	if network.network_data.segments.size() != 2 or network.network_data.junctions.size() != 4:
		m_failures.append("Vertically separated crossing was incorrectly connected")
	network.queue_free()


func _validate_coherent_stair_runs() -> void:
	var network := _make_network()
	var ids := network.add_path(
		PackedVector3Array([Vector3.ZERO, Vector3(1.5, 0.9, 0.0)]),
		null, &"test", false, StreetSegmentData.VerticalMode.MANUAL
	)
	var segment := network.network_data.find_segment(ids[0])
	segment.terrain_profile = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.5, 0.3, 0.0),
		Vector3(1.0, 0.6, 0.0),
		Vector3(1.5, 0.9, 0.0),
	])
	network.rebuild_network()
	var child := _segment_child(network, segment.stable_id)
	if child == null or int(child.get_last_build_stats().get("stair_segment_count", 0)) != 1:
		m_failures.append("Adjacent steep samples did not collapse into one coherent stair run")
	segment.terrain_profile = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.4, 0.3, 0.0),
		Vector3(1.5, 0.3, 0.0),
	])
	network.rebuild_network()
	if int(child.get_last_build_stats().get("stair_segment_count", -1)) != 0:
		m_failures.append("Sub-minimum terrain ripple incorrectly generated a short stair run")
	network.queue_free()


func _validate_legacy_migration_preserves_geometry() -> void:
	var legacy := Street3D.new()
	legacy.build_on_ready = false
	legacy.path_points = PackedVector3Array([
		Vector3(2.0, 1.0, 3.0),
		Vector3(5.0, 1.5, 7.0),
		Vector3(9.0, 2.0, 8.0),
	])
	legacy.road_width = 4.2
	add_child(legacy)
	var network := _make_network()
	var changed := network.add_legacy_street(legacy, false)
	network.rebuild_network()
	if changed.is_empty() or network.network_data.segments.size() != 1:
		m_failures.append("Legacy Street3D migration did not create one graph segment")
	else:
		var segment := network.network_data.find_segment(changed[0])
		var start := network.network_data.find_junction(segment.start_junction_id)
		var end := network.network_data.find_junction(segment.end_junction_id)
		if (
			start == null or end == null
			or !start.position.is_equal_approx(legacy.path_points[0])
			or !end.position.is_equal_approx(legacy.path_points[legacy.path_points.size() - 1])
		):
			m_failures.append("Legacy migration changed authored endpoint positions")
		if segment.section_profile == null or !is_equal_approx(segment.section_profile.road_width, 4.2):
			m_failures.append("Legacy migration changed the street cross-section")
	legacy.queue_free()
	network.queue_free()


func _validate_split_merge_and_state_restore() -> void:
	var network := _make_network()
	var ids := network.add_path(
		PackedVector3Array([Vector3.ZERO, Vector3(8.0, 0.0, 0.0)]),
		null, &"test", false
	)
	var initial := network.capture_network_state()
	var junction_id := network.split_segment(ids[0], Vector3(4.0, 0.0, 0.0))
	if junction_id.is_empty() or network.network_data.segments.size() != 2:
		m_failures.append("Segment split did not create two topology edges")
	else:
		var incident := network.network_data.incident_segments(junction_id)
		if incident.size() != 2:
			m_failures.append("Split junction did not retain its two incident segments")
	network.restore_network_state(initial)
	if network.network_data.segments.size() != 1 or network.network_data.junctions.size() != 2:
		m_failures.append("Network state restore did not exactly undo a split")
	network.queue_free()


func _validate_local_dirty_rebuild() -> void:
	var network := _make_network()
	var first_ids := network.add_path(
		PackedVector3Array([Vector3.ZERO, Vector3(6.0, 0.0, 0.0)]),
		null, &"test", false
	)
	var second_ids := network.add_path(
		PackedVector3Array([Vector3(20.0, 0.0, 0.0), Vector3(26.0, 0.0, 0.0)]),
		null, &"test", false
	)
	network.rebuild_network()
	var first_child := _segment_child(network, first_ids[0])
	var second_child := _segment_child(network, second_ids[0])
	var first_before := first_child.get_mesh_rebuild_count()
	var second_before := second_child.get_mesh_rebuild_count()
	var first_segment := network.network_data.find_segment(first_ids[0])
	var first_junction := network.network_data.find_junction(first_segment.start_junction_id)
	network.move_junction(first_junction.stable_id, first_junction.position + Vector3(0.0, 0.0, 1.0))
	network.rebuild_network()
	if first_child.get_mesh_rebuild_count() <= first_before:
		m_failures.append("Dirty segment did not rebuild after moving its junction")
	if second_child.get_mesh_rebuild_count() != second_before:
		m_failures.append("Unrelated segment rebuilt during a local junction edit")
	network.queue_free()


func _make_network() -> StreetNetwork3DScript:
	var network := StreetNetwork3DScript.new() as StreetNetwork3DScript
	network.build_on_ready = false
	add_child(network)
	return network


func _segment_child(network: StreetNetwork3DScript, segment_id: String) -> Street3D:
	for child in network.get_children():
		if child is Street3D and String(child.get_meta(network.SEGMENT_ID_META, "")) == segment_id:
			return child
	return null


func _junction_child(network: StreetNetwork3DScript, junction_id: String) -> StreetJunction3D:
	for child in network.get_children():
		if (
			child is StreetJunction3D
			and String(child.get_meta(network.JUNCTION_ID_META, "")) == junction_id
		):
			return child
	return null


func _mesh_reaches_parent_point(street: Street3D, parent_point: Vector3, color: Color) -> bool:
	if street.mesh == null or street.mesh.get_surface_count() <= 0:
		return false
	var local_point := street.to_local(street.get_parent_node_3d().to_global(parent_point))
	var arrays: Array = street.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for vertex_index in range(vertices.size()):
		if !_colors_near(colors[vertex_index], color):
			continue
		if Vector2(
			vertices[vertex_index].x - local_point.x,
			vertices[vertex_index].z - local_point.z
		).length() <= 0.01:
			return true
	return false


func _mesh_covers_parent_plan_point(
	mesh_instance: MeshInstance3D, parent_point: Vector3, color: Color
) -> bool:
	var local_point_3d := mesh_instance.to_local(
		mesh_instance.get_parent_node_3d().to_global(parent_point)
	)
	var local_point := Vector2(local_point_3d.x, local_point_3d.z)
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_index in range(0, indices.size(), 3):
		var a_index := indices[triangle_index]
		var b_index := indices[triangle_index + 1]
		var c_index := indices[triangle_index + 2]
		if normals[a_index].y < 0.9:
			continue
		if (
			!_colors_near(colors[a_index], color)
			or !_colors_near(colors[b_index], color)
			or !_colors_near(colors[c_index], color)
		):
			continue
		if _point_in_triangle(
			local_point,
			Vector2(vertices[a_index].x, vertices[a_index].z),
			Vector2(vertices[b_index].x, vertices[b_index].z),
			Vector2(vertices[c_index].x, vertices[c_index].z)
		):
			return true
	return false


func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var ab := (b - a).cross(point - a)
	var bc := (c - b).cross(point - b)
	var ca := (a - c).cross(point - c)
	var has_negative := ab < -0.0001 or bc < -0.0001 or ca < -0.0001
	var has_positive := ab > 0.0001 or bc > 0.0001 or ca > 0.0001
	return !(has_negative and has_positive)


func _colors_near(first: Color, second: Color, tolerance := 0.01) -> bool:
	return (
		absf(first.r - second.r) <= tolerance
		and absf(first.g - second.g) <= tolerance
		and absf(first.b - second.b) <= tolerance
		and absf(first.a - second.a) <= tolerance
	)
