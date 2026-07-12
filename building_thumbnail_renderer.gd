@tool
class_name BuildingThumbnailRenderer
extends RefCounted

const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)

const DEFAULT_SIZE := Vector2i(512, 384)
const BACKGROUND_COLOR := Color(0.73, 0.80, 0.82, 1.0)
const GROUND_COLOR := Color(0.50, 0.58, 0.52, 1.0)
const CONTACT_SHEET_PADDING := 12

var m_viewport: SubViewport
var m_preview_root: Node3D
var m_camera: Camera3D
var m_ground: MeshInstance3D


func render_building(
	building: Building3DScript,
	resolved: Dictionary,
	output_path: String,
	image_size: Vector2i = DEFAULT_SIZE
) -> Dictionary:
	if building == null or building.get_parent() != null:
		return _result(false, "Building must be a detached Building3D.", null)
	if image_size.x < 64 or image_size.y < 64:
		return _result(false, "Thumbnail dimensions must be at least 64 x 64.", null)
	if DisplayServer.get_name() == "headless":
		return _result(
			false,
			"Thumbnail rendering requires a graphical rendering driver; "
				+ "run generate_variants.gd without --headless.",
			null
		)
	if !_ensure_viewport(image_size):
		return _result(false, "Could not initialize the thumbnail viewport.", null)

	m_preview_root.add_child(building)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		m_preview_root.remove_child(building)
		return _result(false, "Thumbnail rendering requires a SceneTree.", null)
	await tree.process_frame

	var bounds_result := _global_aabb(building)
	if !bool(bounds_result.get("found", false)):
		m_preview_root.remove_child(building)
		return _result(false, "Generated building has no visible geometry.", null)
	var bounds := AABB(bounds_result["aabb"]).abs()
	_configure_ground(bounds)
	_frame_camera(bounds, int(resolved.get("entrance_segment", 0)))

	m_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	RenderingServer.force_draw(false)
	await tree.process_frame
	RenderingServer.force_draw(false)
	await tree.process_frame
	RenderingServer.force_draw(false)
	var image := m_viewport.get_texture().get_image()
	m_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	m_preview_root.remove_child(building)
	_clear_ground()

	if image == null or image.is_empty():
		return _result(false, "Renderer returned an empty thumbnail.", null)
	if !_image_has_visual_content(image):
		return _result(false, "Renderer returned a background-only thumbnail.", null)
	var directory_error := _ensure_output_directory(output_path)
	if directory_error != OK:
		return _result(
			false,
			"Could not create thumbnail directory (error %d)." % directory_error,
			null
		)
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _result(
			false,
			"Could not save thumbnail (error %d)." % save_error,
			null
		)
	return _result(true, "", image)


func dispose() -> void:
	if is_instance_valid(m_viewport):
		m_viewport.queue_free()
	m_viewport = null
	m_preview_root = null
	m_camera = null
	m_ground = null


static func create_contact_sheet(
	image_paths: PackedStringArray,
	output_path: String,
	columns: int = 0
) -> Error:
	if image_paths.is_empty():
		return ERR_INVALID_PARAMETER
	var images: Array[Image] = []
	var cell_size := Vector2i.ZERO
	for path in image_paths:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			return ERR_FILE_CORRUPT
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		if cell_size == Vector2i.ZERO:
			cell_size = image.get_size()
		elif image.get_size() != cell_size:
			image.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		images.append(image)
	var resolved_columns := columns
	if resolved_columns <= 0:
		resolved_columns = ceili(sqrt(float(images.size())))
	resolved_columns = clampi(resolved_columns, 1, images.size())
	var rows := ceili(float(images.size()) / float(resolved_columns))
	var sheet_size := Vector2i(
		resolved_columns * cell_size.x
			+ (resolved_columns + 1) * CONTACT_SHEET_PADDING,
		rows * cell_size.y + (rows + 1) * CONTACT_SHEET_PADDING
	)
	var sheet := Image.create(
		sheet_size.x,
		sheet_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(BACKGROUND_COLOR.darkened(0.18))
	for index in range(images.size()):
		var column := index % resolved_columns
		var row := index / resolved_columns
		var destination := Vector2i(
			CONTACT_SHEET_PADDING
				+ column * (cell_size.x + CONTACT_SHEET_PADDING),
			CONTACT_SHEET_PADDING
				+ row * (cell_size.y + CONTACT_SHEET_PADDING)
		)
		sheet.blit_rect(
			images[index],
			Rect2i(Vector2i.ZERO, cell_size),
			destination
		)
	var directory_error := _ensure_output_directory(output_path)
	if directory_error != OK:
		return directory_error
	return sheet.save_png(ProjectSettings.globalize_path(output_path))


func _ensure_viewport(image_size: Vector2i) -> bool:
	if is_instance_valid(m_viewport):
		m_viewport.size = image_size
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	m_viewport = SubViewport.new()
	m_viewport.name = "BuildingThumbnailViewport"
	m_viewport.size = image_size
	m_viewport.transparent_bg = false
	m_viewport.disable_3d = false
	m_viewport.own_world_3d = true
	m_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	m_viewport.msaa_3d = Viewport.MSAA_2X

	m_preview_root = Node3D.new()
	m_preview_root.name = "PreviewRoot"
	m_viewport.add_child(m_preview_root)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.88, 0.92, 0.94, 1.0)
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	m_viewport.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.78, 1.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	m_viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
	fill.light_color = Color(0.68, 0.78, 0.95, 1.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	m_viewport.add_child(fill)

	m_camera = Camera3D.new()
	m_camera.name = "Camera3D"
	m_camera.current = true
	m_camera.fov = 38.0
	m_preview_root.add_child(m_camera)

	tree.root.add_child(m_viewport)
	return true


func _configure_ground(bounds: AABB) -> void:
	_clear_ground()
	m_ground = MeshInstance3D.new()
	m_ground.name = "PreviewGround"
	var plane := PlaneMesh.new()
	var diameter := maxf(bounds.size.x, bounds.size.z) * 2.8
	plane.size = Vector2(maxf(diameter, 4.0), maxf(diameter, 4.0))
	m_ground.mesh = plane
	m_ground.position = Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y - 0.025,
		bounds.position.z + bounds.size.z * 0.5
	)
	var material := StandardMaterial3D.new()
	material.albedo_color = GROUND_COLOR
	material.roughness = 1.0
	m_ground.material_override = material
	m_preview_root.add_child(m_ground)


func _clear_ground() -> void:
	if !is_instance_valid(m_ground):
		m_ground = null
		return
	if m_ground.get_parent() != null:
		m_ground.get_parent().remove_child(m_ground)
	m_ground.free()
	m_ground = null


func _frame_camera(bounds: AABB, entrance_segment: int) -> void:
	var center := bounds.position + bounds.size * 0.5
	var radius := maxf(bounds.size.length() * 0.5, 0.5)
	var direction := _camera_direction_for_entrance(entrance_segment)
	var distance := radius / tan(deg_to_rad(m_camera.fov * 0.5)) * 1.28
	m_camera.global_position = center + direction.normalized() * distance
	m_camera.look_at(center + Vector3(0.0, bounds.size.y * 0.05, 0.0), Vector3.UP)
	m_camera.near = maxf(radius / 100.0, 0.02)
	m_camera.far = maxf(distance + radius * 5.0, 100.0)


func _camera_direction_for_entrance(segment_index: int) -> Vector3:
	match posmod(segment_index, 4):
		0:
			return Vector3(0.85, 0.72, -1.0)
		1:
			return Vector3(1.0, 0.72, 0.85)
		2:
			return Vector3(-0.85, 0.72, 1.0)
		_:
			return Vector3(-1.0, 0.72, -0.85)


func _global_aabb(node: Node) -> Dictionary:
	var found := false
	var bounds := AABB()
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var local_bounds := mesh_node.mesh.get_aabb()
			for corner in _aabb_corners(local_bounds):
				var world_corner := mesh_node.global_transform * corner
				if !found:
					bounds = AABB(world_corner, Vector3.ZERO)
					found = true
				else:
					bounds = bounds.expand(world_corner)
	for child in node.get_children():
		var child_result := _global_aabb(child)
		if !bool(child_result.get("found", false)):
			continue
		var child_bounds := AABB(child_result["aabb"])
		if !found:
			bounds = child_bounds
			found = true
		else:
			bounds = bounds.merge(child_bounds)
	return {"found": found, "aabb": bounds}


func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	return [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
		bounds.position + Vector3(0.0, bounds.size.y, 0.0),
		bounds.position + Vector3(0.0, 0.0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, bounds.size.y, 0.0),
		bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
		bounds.position + Vector3(0.0, bounds.size.y, bounds.size.z),
		bounds.end,
	]


func _image_has_visual_content(image: Image) -> bool:
	var reference := image.get_pixel(0, 0)
	var step_x := maxi(image.get_width() / 24, 1)
	var step_y := maxi(image.get_height() / 18, 1)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var sample := image.get_pixel(x, y)
			var difference := maxf(
				absf(sample.r - reference.r),
				maxf(
					absf(sample.g - reference.g),
					absf(sample.b - reference.b)
				)
			)
			if difference > 0.025:
				return true
	return false


static func _ensure_output_directory(path: String) -> Error:
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	return OK if error == ERR_ALREADY_EXISTS else error


static func _result(ok: bool, error: String, image: Image) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"image": image,
	}
