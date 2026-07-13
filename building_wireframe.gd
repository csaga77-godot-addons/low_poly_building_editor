# Scripts with static variables are never freed unless annotated; without this
# the script (and its cached shaders) leaks at exit ("resources still in use").
@static_unload
@tool
class_name BuildingWireframe
extends RefCounted

const NODE_NAME := "BuildingDebugWireframe"
const GENERATED_META := &"building_debug_wireframe"
const LEGACY_NODE_NAMES := [&"RoofTriangleWireframe"]
const DEPTH_TESTED_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, wireframe, cull_back, shadows_disabled, depth_draw_never;

uniform vec4 wire_color : source_color = vec4(0.05, 0.95, 1.0, 1.0);

void fragment() {
	ALBEDO = wire_color.rgb;
	EMISSION = wire_color.rgb;
	ALPHA = wire_color.a;
}
"""
const XRAY_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, wireframe, cull_back, shadows_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 wire_color : source_color = vec4(0.05, 0.95, 1.0, 1.0);

void fragment() {
	ALBEDO = wire_color.rgb;
	EMISSION = wire_color.rgb;
	ALPHA = wire_color.a;
}
"""

static var s_depth_tested_shader: Shader
static var s_xray_shader: Shader
static var s_overlay_states := {}


static func sync(
	root: Node3D,
	mesh_instances: Array[MeshInstance3D],
	enabled: bool,
	color: Color,
	xray: bool
) -> void:
	clear(root)
	if !enabled or root == null:
		return
	var entries: Array[Dictionary] = []
	for source in mesh_instances:
		if (
			source == null
			or !is_instance_valid(source)
			or source.has_meta(GENERATED_META)
			or source.mesh == null
		):
			continue
		var debug_material := _build_material(color, xray)
		debug_material.next_pass = source.material_overlay
		RenderingServer.instance_geometry_set_material_overlay(
			source.get_instance(),
			debug_material.get_rid()
		)
		entries.append({
			"source": weakref(source),
			"debug_material": debug_material,
		})
	if entries.is_empty():
		return
	s_overlay_states[root.get_instance_id()] = {
		"root": weakref(root),
		"entries": entries,
		"xray": xray,
	}


static func sync_recursive(
	root: Node3D,
	enabled: bool,
	color: Color,
	xray: bool
) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)
	sync(root, meshes, enabled, color, xray)


static func update_style(root: Node3D, color: Color, xray: bool) -> bool:
	var state := _state_for_root(root)
	if state.is_empty():
		return false
	var entries: Array[Dictionary] = state["entries"]
	for entry in entries:
		var source := _source_from_entry(entry)
		if source == null:
			continue
		var debug_material := _build_material(color, xray)
		debug_material.next_pass = source.material_overlay
		RenderingServer.instance_geometry_set_material_overlay(
			source.get_instance(),
			debug_material.get_rid()
		)
		entry["debug_material"] = debug_material
	state["xray"] = xray
	s_overlay_states[root.get_instance_id()] = state
	return true


static func clear(root: Node3D) -> void:
	if root == null:
		return
	# Remove overlays created by older plugin versions before material-overlay
	# rendering replaced scene-tree debug children.
	for child in root.get_children():
		if (
			!child.has_meta(GENERATED_META)
			and StringName(child.name) not in LEGACY_NODE_NAMES
		):
			continue
		root.remove_child(child)
		child.free()

	var state := _state_for_root(root)
	if state.is_empty():
		return
	var entries: Array[Dictionary] = state["entries"]
	for entry in entries:
		var source := _source_from_entry(entry)
		if source == null:
			continue
		var restored_overlay := source.material_overlay
		RenderingServer.instance_geometry_set_material_overlay(
			source.get_instance(),
			restored_overlay.get_rid() if restored_overlay != null else RID()
		)
	s_overlay_states.erase(root.get_instance_id())


static func is_active(root: Node3D) -> bool:
	return !_state_for_root(root).is_empty()


static func get_overlay_sources(root: Node3D) -> Array[MeshInstance3D]:
	var sources: Array[MeshInstance3D] = []
	var state := _state_for_root(root)
	if state.is_empty():
		return sources
	var entries: Array[Dictionary] = state["entries"]
	for entry in entries:
		var source := _source_from_entry(entry)
		if source != null:
			sources.append(source)
	return sources


static func get_debug_material(
	root: Node3D,
	source: MeshInstance3D
) -> ShaderMaterial:
	var state := _state_for_root(root)
	if state.is_empty() or source == null:
		return null
	var entries: Array[Dictionary] = state["entries"]
	for entry in entries:
		if _source_from_entry(entry) == source:
			return entry.get("debug_material") as ShaderMaterial
	return null


static func is_xray(root: Node3D) -> bool:
	var state := _state_for_root(root)
	return !state.is_empty() and bool(state.get("xray", false))


static func _state_for_root(root: Node3D) -> Dictionary:
	if root == null:
		return {}
	var state_variant: Variant = s_overlay_states.get(root.get_instance_id(), {})
	if !(state_variant is Dictionary):
		return {}
	var state := state_variant as Dictionary
	var root_reference := state.get("root") as WeakRef
	if root_reference == null or root_reference.get_ref() != root:
		s_overlay_states.erase(root.get_instance_id())
		return {}
	return state


static func _source_from_entry(entry: Dictionary) -> MeshInstance3D:
	var source_reference := entry.get("source") as WeakRef
	if source_reference == null:
		return null
	var source := source_reference.get_ref() as MeshInstance3D
	if source == null or !is_instance_valid(source):
		return null
	return source


static func _collect_mesh_instances(
	node: Node,
	meshes: Array[MeshInstance3D]
) -> void:
	if node.has_meta(GENERATED_META):
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, meshes)


static func _build_material(color: Color, xray: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = _wireframe_shader(xray)
	material.set_shader_parameter(&"wire_color", color)
	material.render_priority = 1
	return material


static func _wireframe_shader(xray: bool) -> Shader:
	if xray:
		if s_xray_shader == null:
			s_xray_shader = Shader.new()
			s_xray_shader.code = XRAY_SHADER_CODE
		return s_xray_shader
	if s_depth_tested_shader == null:
		s_depth_tested_shader = Shader.new()
		s_depth_tested_shader.code = DEPTH_TESTED_SHADER_CODE
	return s_depth_tested_shader
