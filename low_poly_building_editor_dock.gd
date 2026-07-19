@tool
extends VBoxContainer

signal tool_mode_changed(mode: String)
signal wall_settings_changed(settings: Dictionary)
signal floor_settings_changed(settings: Dictionary)
signal street_settings_changed(settings: Dictionary)
signal street_resample_requested()
signal stair_settings_changed(settings: Dictionary)
signal rail_settings_changed(settings: Dictionary)
signal pillar_settings_changed(settings: Dictionary)
signal roof_settings_changed(settings: Dictionary)
signal prop_settings_changed(settings: Dictionary)
signal window_settings_changed(settings: Dictionary)
signal door_settings_changed(settings: Dictionary)
signal display_settings_changed(settings: Dictionary)
signal transform_snap_changed(step: float)
signal create_coordinator_requested()

const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_FLOOR := "floor"
const MODE_STREET := "street"
const MODE_STAIRS := "stairs"
const MODE_RAIL := "rail"
const MODE_PILLAR := "pillar"
const MODE_ROOF := "roof"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MODE_DOOR := "door"
const MAX_PALETTE_ITEMS := 120
const DEFAULT_PROP_PALETTE_ROOT := "res://assets"
const PROP_SCENE_EXTENSIONS := [".tscn", ".scn", ".gltf", ".glb"]
const PROJECT_METADATA_SECTION := "low_poly_building_editor"
const PROJECT_METADATA_KEY := "dock_state"
const DEFAULT_ROOF_ANGLE_DEGREES := 40.0
const LEGACY_ROOF_VALUE_MAX := 8.0
const WALL_TYPE_WALL := "wall"
const WALL_TYPE_ROOM := "room"
const FLOOR_TYPE_SOLID := "solid"
const FLOOR_TYPE_HOLE := "hole"
const FLOOR_STYLE_RECTANGLE := "rectangle"
const FLOOR_STYLE_POLYGON := "polygon"
const STREET_CROSS_SECTION_ROAD_ONLY := 0
const STREET_CROSS_SECTION_FOOTPATH_ONLY := 1
const STREET_CROSS_SECTION_ROAD_AND_FOOTPATH := 2
const NEWEL_PLACEMENT_TREAD := 0
const TREAD_STYLE_CLOSED := 0
const TREAD_STYLE_OPEN := 1
const TREAD_STYLE_NOSING := 2
const RAIL_STYLE_VERTICAL := 0
const RAIL_STYLE_HORIZONTAL := 1
const BuildingFactoryScript := preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const RAIL_STYLE_GLASS_PANEL := 2
const COLOR_SWATCH_ICON_SIZE := 16
const COLOR_SWATCH_MIN_WIDTH := 34.0
const SHORTCUTS_SELECT_TEXT := "Shortcuts\nSelect: normal Godot editor selection and transform tools are active."
const SHORTCUTS_WALL_TEXT := "Shortcuts\nUse Wall Type to choose a single wall or enclosed room.\nRoom Sides sets its connected span count (minimum 3).\nDrag empty space to draw a wall span or room bounds.\nClick once, then click the endpoint or opposite room bound.\nDrag a four-side room wall to resize in one direction.\nOption/Alt-drag a four-side room to move it.\nDrag other wall bodies to move them.\nDrag endpoint or joint to edit.\nShift-click wall body to add joint.\nOption/Alt-drag shared joint to disconnect.\nEsc or right-click cancels."
const SHORTCUTS_FLOOR_TEXT := "Shortcuts\nRectangle and Polygon only change how a floor is created.\nRectangle: drag, or click two opposite corners.\nPolygon: click each vertex; click the first vertex or press Enter to close.\nFor either style, drag any vertex to reshape.\nDrag any edge to move its two vertices.\nShift-click an edge to add a vertex.\nOption/Alt-click a vertex to remove it.\nDrag the floor body to move it.\nEsc or right-click cancels."
const SHORTCUTS_STREET_TEXT := "Shortcuts\nClick successive points to draw a connected street-network path.\nDouble-click or press Enter to finish; Backspace removes the last point.\nDrag a junction to move its connected approaches.\nShift-click a segment to split it; Option/Alt-click a junction to remove it.\nCommand/Ctrl-click near a junction starts a new path instead of moving it.\nUse Resample Terrain on a selected StreetNetwork3D or legacy Street3D after terrain changes.\nEsc or right-click cancels."
const SHORTCUTS_STAIRS_TEXT := "Shortcuts\nDrag empty space to draw a stair rectangle.\nClick one corner, then click the opposite corner to place.\nR rotates the preview or hovered stairs by 90 degrees.\nShift+R rotates the opposite direction.\nDrag stairs body to move it.\nDrag stairs edge or corner to resize.\nEsc or right-click cancels."
const SHORTCUTS_RAIL_TEXT := "Shortcuts\nDrag empty space to draw a standard rail.\nClick once, then click the endpoint to place.\nDrag a rail endpoint to resize it.\nDrag the rail body to move it.\nEsc or right-click cancels."
const SHORTCUTS_PILLAR_TEXT := "Shortcuts\nClick empty space to place a pillar.\nDrag pillar body to move it.\nDrag pillar edge to resize its radius.\nEsc or right-click cancels."
const SHORTCUTS_ROOF_TEXT := "Shortcuts\nFlat roofs can be created as Rectangle or Polygon footprints.\nRectangle: drag, or click two opposite corners.\nPolygon: click each vertex; click the first vertex or press Enter to close.\nFor either Flat footprint, drag any vertex or edge to reshape.\nShift-click an edge to add a vertex.\nOption/Alt-click a vertex to remove it.\nDrag the roof body to move it.\nR rotates rectangular or pitched roofs by 90 degrees.\nEsc or right-click cancels."
const SHORTCUTS_PROP_TEXT := "Shortcuts\nSelect a palette item, then click to place.\nR rotates the preview by 90 degrees.\nEsc or right-click cancels."
const SHORTCUTS_WINDOW_TEXT := "Shortcuts\nClick a wall to place a window.\nDrag window center to move.\nDrag window edge to resize.\nEsc or right-click cancels."
const SHORTCUTS_DOOR_TEXT := "Shortcuts\nSelect a door style, then click a wall to place.\nDrag door center to move.\nDrag door edge to resize.\nEsc or right-click cancels."

var m_editor_interface: EditorInterface
var m_mode_option: OptionButton
var m_status_label: Label
var m_debug_wireframe_check: CheckBox
var m_debug_wireframe_xray_check: CheckBox
var m_debug_wireframe_color_picker: ColorPickerButton
var m_transform_snap_spin: SpinBox
var m_wall_section: VBoxContainer
var m_floor_section: VBoxContainer
var m_street_section: VBoxContainer
var m_stair_section: VBoxContainer
var m_rail_section: VBoxContainer
var m_pillar_section: VBoxContainer
var m_roof_section: VBoxContainer
var m_prop_section: VBoxContainer
var m_window_section: VBoxContainer
var m_door_section: VBoxContainer
var m_wall_type_option: OptionButton
var m_grid_spin: SpinBox
var m_room_sides_spin: SpinBox
var m_room_sides_row: HBoxContainer
var m_wall_base_height_spin: SpinBox
var m_wall_height_spin: SpinBox
var m_wall_thickness_spin: SpinBox
var m_wall_color_picker: ColorPickerButton
var m_lock_8_way_check: CheckBox
var m_floor_type_option: OptionButton
var m_floor_style_option: OptionButton
var m_floor_grid_spin: SpinBox
var m_floor_base_height_spin: SpinBox
var m_floor_thickness_spin: SpinBox
var m_floor_color_picker: ColorPickerButton
var m_street_grid_spin: SpinBox
var m_street_base_height_spin: SpinBox
var m_street_cross_section_option: OptionButton
var m_street_road_width_spin: SpinBox
var m_street_road_thickness_spin: SpinBox
var m_street_road_color_picker: ColorPickerButton
var m_street_kerb_width_spin: SpinBox
var m_street_kerb_height_spin: SpinBox
var m_street_kerb_color_picker: ColorPickerButton
var m_street_footpath_width_spin: SpinBox
var m_street_footpath_thickness_spin: SpinBox
var m_street_footpath_color_picker: ColorPickerButton
var m_street_stair_threshold_spin: SpinBox
var m_street_target_riser_spin: SpinBox
var m_street_max_riser_spin: SpinBox
var m_street_min_tread_spin: SpinBox
var m_street_sample_spacing_spin: SpinBox
var m_street_clearance_spin: SpinBox
var m_stair_layout_option: OptionButton
var m_stair_turn_option: OptionButton
var m_stair_winder_turn_option: OptionButton
var m_stair_spiral_turn_spin: SpinBox
var m_stair_flight_width_spin: SpinBox
var m_stair_grid_spin: SpinBox
var m_stair_base_height_spin: SpinBox
var m_stair_height_spin: SpinBox
var m_stair_step_count_spin: SpinBox
var m_stair_thickness_spin: SpinBox
var m_stair_tread_style_option: OptionButton
var m_stair_nosing_spin: SpinBox
var m_stair_rotation_spin: SpinBox
var m_stair_color_picker: ColorPickerButton
var m_stair_left_rail_check: CheckBox
var m_stair_right_rail_check: CheckBox
var m_stair_rail_style_option: OptionButton
var m_stair_lower_newel_check: CheckBox
var m_stair_lower_newel_position_option: OptionButton
var m_stair_upper_newel_check: CheckBox
var m_stair_upper_newel_position_option: OptionButton
var m_stair_middle_newel_count_spin: SpinBox
var m_stair_infill_count_spin: SpinBox
var m_stair_newel_size_spin: SpinBox
var m_stair_rail_margin_spin: SpinBox
var m_rail_grid_spin: SpinBox
var m_rail_base_height_spin: SpinBox
var m_rail_height_spin: SpinBox
var m_rail_post_spacing_spin: SpinBox
var m_rail_post_thickness_spin: SpinBox
var m_rail_bar_thickness_spin: SpinBox
var m_rail_style_option: OptionButton
var m_rail_newel_count_spin: SpinBox
var m_rail_infill_count_spin: SpinBox
var m_rail_newel_size_spin: SpinBox
var m_rail_lower_height_spin: SpinBox
var m_rail_color_picker: ColorPickerButton
var m_pillar_grid_spin: SpinBox
var m_pillar_style_option: OptionButton
var m_pillar_base_height_spin: SpinBox
var m_pillar_radius_spin: SpinBox
var m_pillar_upper_radius_spin: SpinBox
var m_pillar_height_spin: SpinBox
var m_pillar_sides_spin: SpinBox
var m_pillar_lower_rim_height_spin: SpinBox
var m_pillar_lower_rim_outset_spin: SpinBox
var m_pillar_upper_rim_height_spin: SpinBox
var m_pillar_upper_rim_outset_spin: SpinBox
var m_pillar_color_picker: ColorPickerButton
var m_pillar_style_header: Label
var m_pillar_sides_row: HBoxContainer
var m_roof_grid_spin: SpinBox
var m_roof_style_option: OptionButton
var m_roof_footprint_option: OptionButton
var m_roof_footprint_row: HBoxContainer
var m_roof_base_height_spin: SpinBox
var m_roof_height_spin: SpinBox
var m_roof_thickness_spin: SpinBox
var m_roof_overhang_spin: SpinBox
var m_roof_hip_gable_height_spin: SpinBox
var m_roof_rotation_spin: SpinBox
var m_roof_color_picker: ColorPickerButton
var m_roof_style_header: Label
var m_roof_angle_row: HBoxContainer
var m_roof_hip_shape_option: OptionButton
var m_roof_hip_shape_row: HBoxContainer
var m_roof_hip_gable_height_row: HBoxContainer
var m_palette_root_edit: LineEdit
var m_prop_path_edit: LineEdit
var m_prop_clearance_spin: SpinBox
var m_palette_list: ItemList
var m_palette_root_dialog: EditorFileDialog
var m_scene_dialog: EditorFileDialog
var m_window_style_option: OptionButton
var m_window_width_spin: SpinBox
var m_window_height_spin: SpinBox
var m_window_frame_spin: SpinBox
var m_window_frame_protrusion_spin: SpinBox
var m_window_frame_color_picker: ColorPickerButton
var m_window_sill_spin: SpinBox
var m_window_frame_sides_option: OptionButton
var m_window_style_header: Label
var m_window_style_rows: Dictionary = {}
var m_window_pane_depth_spin: SpinBox
var m_window_pane_color_picker: ColorPickerButton
var m_window_grid_rows_spin: SpinBox
var m_window_grid_cols_spin: SpinBox
var m_window_muntin_thickness_spin: SpinBox
var m_window_louver_count_spin: SpinBox
var m_window_louver_depth_spin: SpinBox
var m_window_transom_ratio_spin: SpinBox
var m_window_transom_rail_spin: SpinBox
var m_window_arch_steps_spin: SpinBox
var m_door_style_option: OptionButton
var m_door_width_spin: SpinBox
var m_door_height_spin: SpinBox
var m_door_frame_spin: SpinBox
var m_door_frame_protrusion_spin: SpinBox
var m_door_frame_color_picker: ColorPickerButton
var m_door_frame_sides_option: OptionButton
var m_door_style_header: Label
var m_door_style_rows: Dictionary = {}
var m_door_panel_depth_spin: SpinBox
var m_door_panel_color_picker: ColorPickerButton
var m_door_glazing_ratio_spin: SpinBox
var m_door_glass_depth_spin: SpinBox
var m_door_glass_color_picker: ColorPickerButton
var m_door_grid_rows_spin: SpinBox
var m_door_grid_cols_spin: SpinBox
var m_door_muntin_thickness_spin: SpinBox
var m_door_inset_rows_spin: SpinBox
var m_door_inset_cols_spin: SpinBox
var m_palette_paths: PackedStringArray = PackedStringArray()


func setup(editor_interface: EditorInterface) -> void:
	m_editor_interface = editor_interface


func _ready() -> void:
	if get_child_count() > 0:
		return
	_build_ui()
	_load_persisted_settings()
	_scan_palette()
	_emit_all_settings()


func _exit_tree() -> void:
	_save_persisted_settings()


func set_status(text: String) -> void:
	if m_status_label != null:
		m_status_label.text = text


func set_active_coordinator_path(_path_text: String) -> void:
	pass


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	m_status_label = Label.new()
	m_status_label.text = "Select a tool."
	m_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(m_status_label)

	content.add_child(HSeparator.new())

	var mode_row := HBoxContainer.new()
	var mode_label := Label.new()
	mode_label.text = "Tool:"
	mode_row.add_child(mode_label)

	m_mode_option = OptionButton.new()
	m_mode_option.tooltip_text = _shortcut_text_for_mode(MODE_SELECT)
	m_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_mode_option.add_item("Select", 0)
	m_mode_option.set_item_metadata(0, MODE_SELECT)
	m_mode_option.add_item("Wall", 1)
	m_mode_option.set_item_metadata(1, MODE_WALL)
	m_mode_option.add_item("Floor", 2)
	m_mode_option.set_item_metadata(2, MODE_FLOOR)
	m_mode_option.add_item("Street", 3)
	m_mode_option.set_item_metadata(3, MODE_STREET)
	m_mode_option.add_item("Stairs", 4)
	m_mode_option.set_item_metadata(4, MODE_STAIRS)
	m_mode_option.add_item("Rail", 5)
	m_mode_option.set_item_metadata(5, MODE_RAIL)
	m_mode_option.add_item("Pillar", 6)
	m_mode_option.set_item_metadata(6, MODE_PILLAR)
	m_mode_option.add_item("Roof", 7)
	m_mode_option.set_item_metadata(7, MODE_ROOF)
	m_mode_option.add_item("Prop", 8)
	m_mode_option.set_item_metadata(8, MODE_PROP)
	m_mode_option.add_item("Door", 9)
	m_mode_option.set_item_metadata(9, MODE_DOOR)
	m_mode_option.add_item("Window", 10)
	m_mode_option.set_item_metadata(10, MODE_WINDOW)
	m_mode_option.item_selected.connect(_on_mode_selected)
	mode_row.add_child(m_mode_option)
	content.add_child(mode_row)

	var coordinator_button := Button.new()
	coordinator_button.text = "Add Building"
	coordinator_button.tooltip_text = "Add and select a new Building3D root."
	coordinator_button.pressed.connect(_on_create_coordinator)
	content.add_child(coordinator_button)

	_build_display_controls(content)

	m_wall_section = _make_tool_section(content)
	_build_wall_controls(m_wall_section)
	m_floor_section = _make_tool_section(content)
	_build_floor_controls(m_floor_section)
	m_street_section = _make_tool_section(content)
	_build_street_controls(m_street_section)
	m_stair_section = _make_tool_section(content)
	_build_stair_controls(m_stair_section)
	m_rail_section = _make_tool_section(content)
	_build_rail_controls(m_rail_section)
	m_pillar_section = _make_tool_section(content)
	_build_pillar_controls(m_pillar_section)
	m_roof_section = _make_tool_section(content)
	_build_roof_controls(m_roof_section)
	m_prop_section = _make_tool_section(content)
	_build_prop_controls(m_prop_section)
	m_door_section = _make_tool_section(content)
	_build_door_controls(m_door_section)
	m_window_section = _make_tool_section(content)
	_build_window_controls(m_window_section)
	_update_visible_tool_section(MODE_SELECT)

	m_scene_dialog = EditorFileDialog.new()
	m_scene_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	m_scene_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	m_scene_dialog.title = "Select 3D prop scene"
	m_scene_dialog.add_filter("*.tscn,*.scn,*.gltf,*.glb ; 3D scene assets")
	m_scene_dialog.file_selected.connect(_on_scene_selected)
	add_child(m_scene_dialog)

	m_palette_root_dialog = EditorFileDialog.new()
	m_palette_root_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	m_palette_root_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	m_palette_root_dialog.title = "Select prop palette folder"
	m_palette_root_dialog.dir_selected.connect(_on_palette_root_selected)
	add_child(m_palette_root_dialog)


func _make_tool_section(parent: VBoxContainer) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(HSeparator.new())
	parent.add_child(section)
	return section


func _build_display_controls(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	var header := Label.new()
	header.text = "Debug Display"
	parent.add_child(header)
	m_debug_wireframe_check = CheckBox.new()
	m_debug_wireframe_check.text = "Wireframe"
	m_debug_wireframe_check.tooltip_text = (
		"Show deduplicated triangle edges for generated building blocks and previews."
	)
	m_debug_wireframe_check.toggled.connect(_on_debug_wireframe_changed)
	parent.add_child(m_debug_wireframe_check)
	m_debug_wireframe_xray_check = CheckBox.new()
	m_debug_wireframe_xray_check.text = "X-ray wireframe"
	m_debug_wireframe_xray_check.tooltip_text = (
		"Draw hidden wireframe edges through geometry. Disabled is lighter and less cluttered."
	)
	m_debug_wireframe_xray_check.toggled.connect(_on_debug_wireframe_changed)
	parent.add_child(m_debug_wireframe_xray_check)
	m_debug_wireframe_color_picker = _make_color_picker(
		Color(0.05, 0.95, 1.0, 1.0)
	)
	m_debug_wireframe_color_picker.color_changed.connect(
		_on_debug_wireframe_color_changed
	)
	_add_labeled_control(
		parent,
		"Wire Color:",
		m_debug_wireframe_color_picker
	)
	m_transform_snap_spin = _make_spin(0.0, 8.0, 0.05, 0.5)
	m_transform_snap_spin.allow_greater = true
	m_transform_snap_spin.tooltip_text = (
		"Grid step applied when a building block is edited with the native Move/Rotate/Scale "
		+ "gizmos. Positions and baked sizes snap to this step; 0 disables snapping."
	)
	_add_labeled_control(parent, "Transform Snap:", m_transform_snap_spin)
	m_transform_snap_spin.value_changed.connect(_on_transform_snap_changed)
	_update_debug_wireframe_controls()


func _on_transform_snap_changed(_value: float) -> void:
	transform_snap_changed.emit(float(m_transform_snap_spin.value))


func _build_wall_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Wall Defaults"
	parent.add_child(header)

	m_wall_type_option = OptionButton.new()
	m_wall_type_option.add_item("Wall", 0)
	m_wall_type_option.set_item_metadata(0, WALL_TYPE_WALL)
	m_wall_type_option.add_item("Room", 1)
	m_wall_type_option.set_item_metadata(1, WALL_TYPE_ROOM)
	m_wall_type_option.item_selected.connect(_on_wall_type_selected)
	_add_labeled_control(
		parent,
		"Type:",
		m_wall_type_option,
		"Draw one wall span or connected walls enclosing a room."
	)

	m_room_sides_spin = _make_spin(3.0, 64.0, 1.0, 4.0)
	m_room_sides_spin.allow_greater = true
	m_room_sides_row = _add_labeled_control(
		parent,
		"Sides:",
		m_room_sides_spin,
		"Number of connected wall spans in a new room. Minimum 3."
	)
	m_room_sides_spin.value_changed.connect(_on_wall_setting_changed)

	m_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_grid_spin, "Snap size for drawing and editing wall endpoints.")
	m_grid_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_wall_base_height_spin.tooltip_text = "Parent-local Y height for new wall bases."
	_add_labeled_control(parent, "Base Y:", m_wall_base_height_spin)
	m_wall_base_height_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_height_spin = _make_spin(0.1, 6.0, 0.05, 2.4)
	_add_labeled_control(parent, "Height:", m_wall_height_spin, "Vertical height of newly drawn walls.")
	m_wall_height_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_thickness_spin = _make_spin(0.03, 1.0, 0.01, 0.22)
	_add_labeled_control(parent, "Thickness:", m_wall_thickness_spin, "Depth of the wall measured across its center line.")
	m_wall_thickness_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_color_picker = _make_color_picker(Color(0.78, 0.68, 0.54, 1.0))
	m_wall_color_picker.color_changed.connect(_on_wall_color_changed)
	_add_labeled_control(parent, "Color:", m_wall_color_picker, "Vertex color applied to newly drawn walls.")

	m_lock_8_way_check = CheckBox.new()
	m_lock_8_way_check.text = "8-way lock"
	m_lock_8_way_check.tooltip_text = "Constrain new wall spans to horizontal, vertical, and diagonal directions."
	m_lock_8_way_check.button_pressed = true
	m_lock_8_way_check.toggled.connect(_on_wall_lock_changed)
	parent.add_child(m_lock_8_way_check)


func _build_floor_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Floor Defaults"
	parent.add_child(header)

	m_floor_type_option = OptionButton.new()
	m_floor_type_option.tooltip_text = "Choose whether the selected Rectangle/Polygon outline creates a slab or cuts a matching hole."
	m_floor_type_option.add_item("Solid", 0)
	m_floor_type_option.set_item_metadata(0, FLOOR_TYPE_SOLID)
	m_floor_type_option.add_item("Hole", 1)
	m_floor_type_option.set_item_metadata(1, FLOOR_TYPE_HOLE)
	m_floor_type_option.select(0)
	m_floor_type_option.item_selected.connect(_on_floor_type_selected)
	_add_labeled_control(parent, "Type:", m_floor_type_option)

	m_floor_style_option = OptionButton.new()
	m_floor_style_option.tooltip_text = "Choose a two-corner rectangle or a multi-vertex polygon footprint."
	m_floor_style_option.add_item("Rectangle", 0)
	m_floor_style_option.set_item_metadata(0, FLOOR_STYLE_RECTANGLE)
	m_floor_style_option.add_item("Polygon", 1)
	m_floor_style_option.set_item_metadata(1, FLOOR_STYLE_POLYGON)
	m_floor_style_option.select(0)
	m_floor_style_option.item_selected.connect(_on_floor_style_selected)
	_add_labeled_control(parent, "Style:", m_floor_style_option)

	m_floor_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_floor_grid_spin, "Snap size for drawing and editing floor footprints.")
	m_floor_grid_spin.value_changed.connect(_on_floor_setting_changed)

	m_floor_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_floor_base_height_spin.tooltip_text = "Parent-local Y height for new floor top surfaces."
	_add_labeled_control(parent, "Base Y:", m_floor_base_height_spin)
	m_floor_base_height_spin.value_changed.connect(_on_floor_setting_changed)

	m_floor_thickness_spin = _make_spin(0.01, 2.0, 0.01, 0.12)
	_add_labeled_control(parent, "Thickness:", m_floor_thickness_spin, "Thickness extending downward from the floor top surface.")
	m_floor_thickness_spin.value_changed.connect(_on_floor_setting_changed)

	m_floor_color_picker = _make_color_picker(Color(0.46, 0.40, 0.32, 1.0))
	m_floor_color_picker.color_changed.connect(_on_floor_color_changed)
	_add_labeled_control(parent, "Color:", m_floor_color_picker, "Vertex color applied to newly drawn floors.")


func _build_street_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Street Defaults"
	parent.add_child(header)
	m_street_cross_section_option = OptionButton.new()
	m_street_cross_section_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Array in [
		["Road Only", STREET_CROSS_SECTION_ROAD_ONLY],
		["Footpath Only", STREET_CROSS_SECTION_FOOTPATH_ONLY],
		["Road + Footpath", STREET_CROSS_SECTION_ROAD_AND_FOOTPATH],
	]:
		var index := m_street_cross_section_option.get_item_count()
		m_street_cross_section_option.add_item(String(entry[0]), int(entry[1]))
		m_street_cross_section_option.set_item_metadata(index, int(entry[1]))
	m_street_cross_section_option.select(STREET_CROSS_SECTION_ROAD_AND_FOOTPATH)
	m_street_cross_section_option.item_selected.connect(_on_street_cross_section_selected)
	_add_labeled_control(
		parent, "Surface:", m_street_cross_section_option,
		"Road Only uses the centre road surface; Footpath Only uses one pedestrian centre strip; Road + Footpath adds kerbs and side paths."
	)
	m_street_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	m_street_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_street_road_width_spin = _make_spin(0.1, 20.0, 0.05, 3.2)
	m_street_road_thickness_spin = _make_spin(0.01, 2.0, 0.01, 0.18)
	m_street_road_color_picker = _make_color_picker(Color(0.38, 0.37, 0.34, 1.0))
	m_street_kerb_width_spin = _make_spin(0.01, 2.0, 0.01, 0.18)
	m_street_kerb_height_spin = _make_spin(0.01, 1.0, 0.01, 0.14)
	m_street_kerb_color_picker = _make_color_picker(Color(0.66, 0.64, 0.59, 1.0))
	m_street_footpath_width_spin = _make_spin(0.05, 10.0, 0.05, 1.1)
	m_street_footpath_thickness_spin = _make_spin(0.01, 2.0, 0.01, 0.16)
	m_street_footpath_color_picker = _make_color_picker(Color(0.72, 0.67, 0.57, 1.0))
	m_street_stair_threshold_spin = _make_spin(0.0, 89.0, 0.1, 25.0)
	m_street_target_riser_spin = _make_spin(0.02, 1.0, 0.01, 0.16)
	m_street_max_riser_spin = _make_spin(0.02, 1.0, 0.01, 0.18)
	m_street_min_tread_spin = _make_spin(0.05, 2.0, 0.01, 0.24)
	m_street_sample_spacing_spin = _make_spin(0.1, 10.0, 0.1, 0.5)
	m_street_clearance_spin = _make_spin(-1.0, 2.0, 0.005, 0.025)
	var controls: Array[Array] = [
		["Grid:", m_street_grid_spin],
		["Base Y:", m_street_base_height_spin],
		["Center Width:", m_street_road_width_spin],
		["Road Depth:", m_street_road_thickness_spin],
		["Kerb Width:", m_street_kerb_width_spin],
		["Kerb Height:", m_street_kerb_height_spin],
		["Footpath Width:", m_street_footpath_width_spin],
		["Footpath Depth:", m_street_footpath_thickness_spin],
		["Stair Threshold:", m_street_stair_threshold_spin],
		["Target Riser:", m_street_target_riser_spin],
		["Max Riser:", m_street_max_riser_spin],
		["Min Tread:", m_street_min_tread_spin],
		["Sample Spacing:", m_street_sample_spacing_spin],
		["Terrain Lift:", m_street_clearance_spin],
	]
	for entry: Array in controls:
		_add_labeled_control(parent, String(entry[0]), entry[1] as Control)
		(entry[1] as SpinBox).value_changed.connect(_on_street_setting_changed)
	for color_entry: Array in [
		["Road Color:", m_street_road_color_picker],
		["Kerb Color:", m_street_kerb_color_picker],
		["Footpath Color:", m_street_footpath_color_picker],
	]:
		_add_labeled_control(parent, String(color_entry[0]), color_entry[1] as Control)
		(color_entry[1] as ColorPickerButton).color_changed.connect(_on_street_color_changed)
	var resample_button := Button.new()
	resample_button.text = "Resample Selected Street"
	resample_button.tooltip_text = "Rebuild automatic profile heights from the first scene node exposing get_world_surface_height(); Manual Height profile points are preserved."
	resample_button.pressed.connect(_on_street_resample_pressed)
	parent.add_child(resample_button)
	_update_street_cross_section_controls()


func _build_stair_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Stairs Defaults"
	parent.add_child(header)

	m_stair_layout_option = _make_stair_layout_option()
	m_stair_layout_option.item_selected.connect(_on_stair_layout_selected)
	_add_labeled_control(
		parent,
		"Layout:",
		m_stair_layout_option,
		"Stair layout drawn inside the stair rectangle: one straight run, turning flights joined by landings or winders, or radial spiral treads around a central column."
	)

	m_stair_turn_option = _make_stair_turn_option()
	m_stair_turn_option.item_selected.connect(_on_stair_layout_selected)
	_add_labeled_control(
		parent,
		"Turn:",
		m_stair_turn_option,
		"Turn direction for L, double L, U, winder, and spiral layouts, relative to the climb direction."
	)

	m_stair_winder_turn_option = _make_stair_winder_turn_option()
	m_stair_winder_turn_option.item_selected.connect(_on_stair_layout_selected)
	_add_labeled_control(
		parent,
		"Winder:",
		m_stair_winder_turn_option,
		"Total winder turn angle: 90 degrees fans one corner, 180 degrees fans a full half turn."
	)

	m_stair_spiral_turn_spin = _make_spin(45.0, 1080.0, 15.0, 360.0)
	_add_labeled_control(
		parent,
		"Spiral Turn:",
		m_stair_spiral_turn_spin,
		"Total turn angle of the Spiral layout in degrees; 360 is one full revolution."
	)
	m_stair_spiral_turn_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_flight_width_spin = _make_spin(0.2, 8.0, 0.01, 1.2)
	_add_labeled_control(
		parent,
		"Flight Width:",
		m_stair_flight_width_spin,
		"Width of each flight and its landings for turning layouts, and the radial tread depth outside the central column for the Spiral layout; clamped to fit the drawn stair rectangle."
	)
	m_stair_flight_width_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_stair_grid_spin, "Snap size for drawing and editing stair footprints.")
	m_stair_grid_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_stair_base_height_spin.tooltip_text = "Parent-local Y height for the lower stair entry."
	_add_labeled_control(parent, "Base Y:", m_stair_base_height_spin)
	m_stair_base_height_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_height_spin = _make_spin(0.05, 20.0, 0.01, 1.2)
	_add_labeled_control(parent, "Height:", m_stair_height_spin, "Total climb height from the lower entry to the top tread.")
	m_stair_height_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_step_count_spin = _make_spin(1.0, 64.0, 1.0, 6.0)
	_add_labeled_control(
		parent,
		"Steps:",
		m_stair_step_count_spin,
		"Requested riser/tread count. Spiral layouts add steps when needed to keep each radial tread at or below 45 degrees."
	)
	m_stair_step_count_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_thickness_spin = _make_spin(0.0, 2.0, 0.01, 0.12)
	_add_labeled_control(parent, "Thickness:", m_stair_thickness_spin, "Solid underside thickness extending below the lower stair entry; also the slab thickness of Open treads and nosing lips.")
	m_stair_thickness_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_tread_style_option = _make_stair_tread_style_option()
	m_stair_tread_style_option.item_selected.connect(_on_stair_tread_style_selected)
	_add_labeled_control(
		parent,
		"Treads:",
		m_stair_tread_style_option,
		"Closed builds the solid stepped mass. Open floats individual tread slabs with no risers or underside. Nosing keeps the closed mass and overhangs each tread past the riser below. Winder fans and spiral treads treat Nosing as Closed."
	)

	m_stair_nosing_spin = _make_spin(0.0, 1.0, 0.01, 0.08)
	_add_labeled_control(
		parent,
		"Nosing:",
		m_stair_nosing_spin,
		"Tread overhang past the riser below for the Nosing style, clamped to a fraction of the tread depth."
	)
	m_stair_nosing_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_rotation_spin = _make_spin(-180.0, 180.0, 1.0, 0.0)
	m_stair_rotation_spin.tooltip_text = "Starting Y rotation for new stairs, in degrees."
	_add_labeled_control(parent, "Rotation:", m_stair_rotation_spin)
	m_stair_rotation_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_color_picker = _make_color_picker(Color(0.52, 0.46, 0.38, 1.0))
	m_stair_color_picker.color_changed.connect(_on_stair_color_changed)
	_add_labeled_control(parent, "Color:", m_stair_color_picker, "Vertex color applied to newly drawn stairs.")

	m_stair_left_rail_check = CheckBox.new()
	m_stair_left_rail_check.text = "Left Rail"
	m_stair_left_rail_check.tooltip_text = "Add an optional handrail along the left side of newly drawn stairs. Newels sit at tread centers; infills sit on the base rail and spread evenly between newels."
	m_stair_left_rail_check.toggled.connect(_on_stair_setting_toggled)
	parent.add_child(m_stair_left_rail_check)

	m_stair_right_rail_check = CheckBox.new()
	m_stair_right_rail_check.text = "Right Rail"
	m_stair_right_rail_check.tooltip_text = "Add an optional handrail along the right side of newly drawn stairs. Newels sit at tread centers; infills sit on the base rail and spread evenly between newels."
	m_stair_right_rail_check.toggled.connect(_on_stair_setting_toggled)
	parent.add_child(m_stair_right_rail_check)

	m_stair_rail_style_option = _make_rail_style_option()
	m_stair_rail_style_option.item_selected.connect(_on_stair_rail_style_selected)
	_add_labeled_control(
		parent,
		"Infill Style:",
		m_stair_rail_style_option,
		"Vertical infill rails, evenly spaced horizontal infill rails, or a translucent glass panel."
	)

	m_stair_lower_newel_check = CheckBox.new()
	m_stair_lower_newel_check.text = "Lower Newel"
	m_stair_lower_newel_check.tooltip_text = "Add a thicker newel post at the lower end of each enabled stair rail."
	m_stair_lower_newel_check.toggled.connect(_on_stair_setting_toggled)
	parent.add_child(m_stair_lower_newel_check)

	m_stair_lower_newel_position_option = _make_newel_position_option()
	m_stair_lower_newel_position_option.item_selected.connect(_on_stair_newel_position_selected)
	_add_labeled_control(
		parent,
		"Lower At:",
		m_stair_lower_newel_position_option,
		"Place the lower newel on the first tread or one regular post interval beyond it on the lower floor."
	)

	m_stair_upper_newel_check = CheckBox.new()
	m_stair_upper_newel_check.text = "Upper Newel"
	m_stair_upper_newel_check.tooltip_text = "Add a thicker newel post at the upper end of each enabled stair rail."
	m_stair_upper_newel_check.toggled.connect(_on_stair_setting_toggled)
	parent.add_child(m_stair_upper_newel_check)

	m_stair_upper_newel_position_option = _make_newel_position_option()
	m_stair_upper_newel_position_option.item_selected.connect(_on_stair_newel_position_selected)
	_add_labeled_control(
		parent,
		"Upper At:",
		m_stair_upper_newel_position_option,
		"Place the upper newel on the last tread or one regular post interval beyond it on the upper floor."
	)

	m_stair_middle_newel_count_spin = _make_spin(0.0, 64.0, 1.0, 0.0)
	m_stair_middle_newel_count_spin.value_changed.connect(_on_stair_setting_changed)
	_add_labeled_control(
		parent,
		"Newels (Total):",
		m_stair_middle_newel_count_spin,
		"Total newels including enabled lower/upper terminals. Remaining posts are distributed between the first and last newel anchors."
	)

	m_stair_infill_count_spin = _make_spin(0.0, 64.0, 1.0, 1.0)
	m_stair_infill_count_spin.value_changed.connect(_on_stair_setting_changed)
	_add_labeled_control(
		parent,
		"Infills / Span:",
		m_stair_infill_count_spin,
		"Exact infill count per style: vertical infills in every clear opening between adjacent newel posts, or stacked horizontal infill rails across the run."
	)

	m_stair_newel_size_spin = _make_spin(0.02, 1.0, 0.01, 0.1)
	m_stair_newel_size_spin.value_changed.connect(_on_stair_setting_changed)
	_add_labeled_control(
		parent,
		"Newel Size:",
		m_stair_newel_size_spin,
		"Square newel width/depth. Geometry clamps it to the handrail width so the welded top stays covered."
	)

	m_stair_rail_margin_spin = _make_spin(0.0, 2.0, 0.01, 0.15)
	_add_labeled_control(
		parent,
		"Rail Margin:",
		m_stair_rail_margin_spin,
		"Inset of each enabled rail from the stairs' left/right footprint edge, clamped so opposing margins cannot cross."
	)
	m_stair_rail_margin_spin.value_changed.connect(_on_stair_setting_changed)
	_update_stair_newel_controls()
	_update_stair_layout_controls()
	_update_stair_tread_controls()


func _build_rail_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Standard Rail Defaults"
	parent.add_child(header)

	m_rail_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_rail_grid_spin, "Snap size for drawing and editing rail endpoints.")
	m_rail_grid_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	_add_labeled_control(parent, "Base Y:", m_rail_base_height_spin, "Parent-local Y height for new rail bases.")
	m_rail_base_height_spin.value_changed.connect(_on_rail_setting_changed)

	# Shared rail controls follow the same order as the stair rail controls:
	# infill style, newel count, infill count, newel size, height, infill
	# rail thickness, rail size, lower rail, color.
	m_rail_style_option = _make_rail_style_option()
	m_rail_style_option.item_selected.connect(_on_rail_style_selected)
	_add_labeled_control(
		parent,
		"Infill Style:",
		m_rail_style_option,
		"Vertical infill rails, evenly spaced horizontal infill rails, or a translucent glass panel."
	)

	m_rail_newel_count_spin = _make_spin(2.0, 64.0, 1.0, 2.0)
	_add_labeled_control(
		parent,
		"Newels (Total):",
		m_rail_newel_count_spin,
		"Total evenly distributed newel posts, including both rail endpoints."
	)
	m_rail_newel_count_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_infill_count_spin = _make_spin(0.0, 64.0, 1.0, 1.0)
	_add_labeled_control(
		parent,
		"Infills / Span:",
		m_rail_infill_count_spin,
		"Exact infill count per style: vertical infills between every adjacent newel pair, or stacked horizontal infill rails across the span."
	)
	m_rail_infill_count_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_newel_size_spin = _make_spin(0.02, 1.0, 0.01, 0.1)
	_add_labeled_control(
		parent,
		"Newel Size:",
		m_rail_newel_size_spin,
		"Square newel width/depth, clamped to the handrail width."
	)
	m_rail_newel_size_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_height_spin = _make_spin(0.2, 4.0, 0.01, 1.0)
	_add_labeled_control(parent, "Height:", m_rail_height_spin, "Height from the base to the top of the handrail.")
	m_rail_height_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_post_spacing_spin = _make_spin(0.1, 8.0, 0.05, 1.0)

	m_rail_post_thickness_spin = _make_spin(0.02, 1.0, 0.01, 0.08)
	_add_labeled_control(parent, "Infill Rail Thickness:", m_rail_post_thickness_spin, "Square thickness of each vertical or horizontal infill rail between newels, clamped to the handrail width.")
	m_rail_post_thickness_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_bar_thickness_spin = _make_spin(0.02, 1.0, 0.01, 0.1)
	_add_labeled_control(parent, "Rail Size:", m_rail_bar_thickness_spin, "Square width and height of the top and lower rails.")
	m_rail_bar_thickness_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_lower_height_spin = _make_spin(0.0, 4.0, 0.01, 0.18)
	_add_labeled_control(parent, "Lower Rail Y:", m_rail_lower_height_spin, "Center height of the lower horizontal rail. Set to 0 to disable it.")
	m_rail_lower_height_spin.value_changed.connect(_on_rail_setting_changed)

	m_rail_color_picker = _make_color_picker(Color(0.33, 0.28, 0.22, 1.0))
	m_rail_color_picker.color_changed.connect(_on_rail_color_changed)
	_add_labeled_control(parent, "Color:", m_rail_color_picker, "Vertex color applied to newly drawn rails.")


func _build_pillar_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Pillar Defaults"
	parent.add_child(header)

	m_pillar_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_pillar_grid_spin, "Snap size for placing and moving pillars.")
	m_pillar_grid_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_style_option = OptionButton.new()
	m_pillar_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for style: Dictionary in BuildingFactoryScript.PILLAR_STYLES:
		m_pillar_style_option.add_item(String(style["label"]))
		m_pillar_style_option.set_item_metadata(
			m_pillar_style_option.item_count - 1, style["key"]
		)
	m_pillar_style_option.item_selected.connect(_on_pillar_style_selected)
	_add_labeled_control(parent, "Style:", m_pillar_style_option, "Pillar body shape used for newly placed pillars.")

	m_pillar_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_pillar_base_height_spin.tooltip_text = "Parent-local Y height for new pillar bases."
	_add_labeled_control(parent, "Base Y:", m_pillar_base_height_spin)
	m_pillar_base_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_radius_spin = _make_spin(0.05, 4.0, 0.01, 0.25)
	m_pillar_radius_spin.tooltip_text = "Lower body radius."
	_add_labeled_control(parent, "Lower Radius:", m_pillar_radius_spin)
	m_pillar_radius_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_upper_radius_spin = _make_spin(0.0, 4.0, 0.01, 0.0)
	m_pillar_upper_radius_spin.tooltip_text = "Upper body radius. Set to 0 to use the selected style's default top radius."
	_add_labeled_control(parent, "Upper Radius:", m_pillar_upper_radius_spin)
	m_pillar_upper_radius_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_height_spin = _make_spin(0.1, 12.0, 0.05, 2.4)
	_add_labeled_control(parent, "Height:", m_pillar_height_spin, "Vertical height of newly placed pillars.")
	m_pillar_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_lower_rim_height_spin = _make_spin(0.0, 2.0, 0.01, 0.12)
	m_pillar_lower_rim_height_spin.tooltip_text = "Lower rim band height. Set height or outset to 0 to disable it."
	_add_labeled_control(parent, "Lower Rim H:", m_pillar_lower_rim_height_spin)
	m_pillar_lower_rim_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_lower_rim_outset_spin = _make_spin(0.0, 2.0, 0.01, 0.05)
	m_pillar_lower_rim_outset_spin.tooltip_text = "Lower rim radius added beyond the pillar body."
	_add_labeled_control(parent, "Lower Rim Out:", m_pillar_lower_rim_outset_spin)
	m_pillar_lower_rim_outset_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_upper_rim_height_spin = _make_spin(0.0, 2.0, 0.01, 0.12)
	m_pillar_upper_rim_height_spin.tooltip_text = "Upper rim band height. Set height or outset to 0 to disable it."
	_add_labeled_control(parent, "Upper Rim H:", m_pillar_upper_rim_height_spin)
	m_pillar_upper_rim_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_upper_rim_outset_spin = _make_spin(0.0, 2.0, 0.01, 0.05)
	m_pillar_upper_rim_outset_spin.tooltip_text = "Upper rim radius added beyond the pillar body."
	_add_labeled_control(parent, "Upper Rim Out:", m_pillar_upper_rim_outset_spin)
	m_pillar_upper_rim_outset_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_color_picker = _make_color_picker(Color(0.70, 0.64, 0.52, 1.0))
	m_pillar_color_picker.color_changed.connect(_on_pillar_color_changed)
	_add_labeled_control(parent, "Color:", m_pillar_color_picker, "Vertex color applied to newly placed pillars.")

	m_pillar_style_header = _add_style_properties_header(parent)
	m_pillar_sides_spin = _make_spin(3.0, 24.0, 1.0, 8.0)
	m_pillar_sides_row = _add_labeled_control(
		parent,
		"Sides:",
		m_pillar_sides_spin,
		"Number of sides used by round and tapered pillar styles."
	)
	m_pillar_sides_spin.value_changed.connect(_on_pillar_setting_changed)
	_update_pillar_style_controls()


func _build_roof_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Roof Defaults"
	parent.add_child(header)

	m_roof_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_roof_grid_spin, "Snap size for drawing and editing roof footprints.")
	m_roof_grid_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_style_option = OptionButton.new()
	m_roof_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for style: Dictionary in BuildingFactoryScript.ROOF_STYLES:
		m_roof_style_option.add_item(String(style["label"]))
		var style_index := m_roof_style_option.item_count - 1
		m_roof_style_option.set_item_metadata(style_index, style["key"])
		if String(style["key"]) == "gable":
			m_roof_style_option.select(style_index)
	m_roof_style_option.item_selected.connect(_on_roof_style_selected)
	_add_labeled_control(parent, "Style:", m_roof_style_option, "Roof shape used for newly drawn roof footprints.")

	m_roof_footprint_option = OptionButton.new()
	m_roof_footprint_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_roof_footprint_option.add_item("Rectangle", 0)
	m_roof_footprint_option.set_item_metadata(0, FLOOR_STYLE_RECTANGLE)
	m_roof_footprint_option.add_item("Polygon", 1)
	m_roof_footprint_option.set_item_metadata(1, FLOOR_STYLE_POLYGON)
	m_roof_footprint_option.select(0)
	m_roof_footprint_option.item_selected.connect(_on_roof_footprint_selected)
	m_roof_footprint_row = _add_labeled_control(
		parent,
		"Footprint:",
		m_roof_footprint_option,
		"Rectangle and Polygon only change how a Flat roof is created."
	)

	m_roof_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 2.4)
	m_roof_base_height_spin.tooltip_text = "Parent-local Y height for new roof eaves."
	_add_labeled_control(parent, "Base Y:", m_roof_base_height_spin)
	m_roof_base_height_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_thickness_spin = _make_spin(0.02, 2.0, 0.01, 0.12)
	_add_labeled_control(parent, "Thickness:", m_roof_thickness_spin, "Thickness extending downward from the generated roof surface.")
	m_roof_thickness_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_overhang_spin = _make_spin(0.0, 4.0, 0.01, 0.2)
	_add_labeled_control(parent, "Overhang:", m_roof_overhang_spin, "Distance the roof eaves extend beyond the drawn footprint.")
	m_roof_overhang_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_rotation_spin = _make_spin(-180.0, 180.0, 1.0, 0.0)
	m_roof_rotation_spin.tooltip_text = "Starting Y rotation for new roofs, in degrees."
	_add_labeled_control(parent, "Rotation:", m_roof_rotation_spin)
	m_roof_rotation_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_color_picker = _make_color_picker(Color(0.50, 0.34, 0.25, 1.0))
	m_roof_color_picker.color_changed.connect(_on_roof_color_changed)
	_add_labeled_control(parent, "Color:", m_roof_color_picker, "Vertex color applied to newly drawn roofs.")

	m_roof_style_header = _add_style_properties_header(parent)
	m_roof_height_spin = _make_spin(0.0, 89.0, 1.0, DEFAULT_ROOF_ANGLE_DEGREES)
	m_roof_height_spin.tooltip_text = "Roof face angle in degrees for shed, gable, hip, and dome roofs. A 45-degree dome is hemispherical on a square footprint."
	m_roof_angle_row = _add_labeled_control(parent, "Angle:", m_roof_height_spin)
	m_roof_height_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_hip_shape_option = OptionButton.new()
	m_roof_hip_shape_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for hip_shape: Dictionary in [
		{"label": "Standard", "value": 0},
		{"label": "Pyramid", "value": 1},
		{"label": "Hexagonal", "value": 2},
		{"label": "Octagon", "value": 3},
	]:
		m_roof_hip_shape_option.add_item(String(hip_shape["label"]))
		m_roof_hip_shape_option.set_item_metadata(
			m_roof_hip_shape_option.item_count - 1, int(hip_shape["value"])
		)
	m_roof_hip_shape_option.select(0)
	m_roof_hip_shape_option.item_selected.connect(_on_roof_hip_shape_selected)
	m_roof_hip_shape_row = _add_labeled_control(
		parent,
		"Hip Shape:",
		m_roof_hip_shape_option,
		"Standard raises a ridge; Pyramid, Hexagonal, and Octagon raise the footprint to a centered apex."
	)

	m_roof_hip_gable_height_spin = _make_spin(0.0, 20.0, 0.01, 0.0)
	m_roof_hip_gable_height_row = _add_labeled_control(
		parent,
		"Gable Drop:",
		m_roof_hip_gable_height_spin,
		"Vertical drop from a hip roof peak to the clipped gable base. Positive values extend the ridge while keeping roof faces at the selected angle."
	)
	m_roof_hip_gable_height_spin.value_changed.connect(_on_roof_setting_changed)
	_update_roof_style_controls()


func _build_prop_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Prop Palette"
	parent.add_child(header)

	var palette_root_row := HBoxContainer.new()
	var palette_root_label := Label.new()
	palette_root_label.text = "Folder:"
	palette_root_label.custom_minimum_size = Vector2(84.0, 0.0)
	palette_root_label.tooltip_text = "Resource folder scanned for prop palette scene files."
	palette_root_row.add_child(palette_root_label)

	m_palette_root_edit = LineEdit.new()
	m_palette_root_edit.text = DEFAULT_PROP_PALETTE_ROOT
	m_palette_root_edit.placeholder_text = DEFAULT_PROP_PALETTE_ROOT
	m_palette_root_edit.tooltip_text = "Resource folder scanned by the prop palette."
	m_palette_root_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_palette_root_edit.text_submitted.connect(_on_palette_root_submitted)
	m_palette_root_edit.focus_exited.connect(_on_palette_root_focus_exited)
	palette_root_row.add_child(m_palette_root_edit)

	var palette_root_browse := Button.new()
	palette_root_browse.text = "Browse"
	palette_root_browse.tooltip_text = "Choose the folder scanned by the prop palette."
	palette_root_browse.pressed.connect(_on_browse_palette_root)
	palette_root_row.add_child(palette_root_browse)
	parent.add_child(palette_root_row)

	var scene_row := HBoxContainer.new()
	m_prop_path_edit = LineEdit.new()
	m_prop_path_edit.placeholder_text = DEFAULT_PROP_PALETTE_ROOT.path_join("...")
	m_prop_path_edit.tooltip_text = "Scene file placed by the Prop tool."
	m_prop_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_prop_path_edit.text_changed.connect(_on_prop_setting_changed)
	scene_row.add_child(m_prop_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.tooltip_text = "Choose a prop scene file to place."
	browse_button.pressed.connect(_on_browse_scene)
	scene_row.add_child(browse_button)
	parent.add_child(scene_row)

	var scan_button := Button.new()
	scan_button.text = "Rescan Palette"
	scan_button.tooltip_text = "Refresh the prop palette list from the configured folder."
	scan_button.pressed.connect(_scan_palette)
	parent.add_child(scan_button)

	m_palette_list = ItemList.new()
	m_palette_list.custom_minimum_size = Vector2(0, 180)
	m_palette_list.tooltip_text = "Prop scene files found in the configured palette folder."
	m_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_palette_list.item_selected.connect(_on_palette_item_selected)
	parent.add_child(m_palette_list)

	m_prop_clearance_spin = _make_spin(0.0, 5.0, 0.05, 0.25)
	_add_labeled_control(parent, "Clearance:", m_prop_clearance_spin, "Forward offset from the wall face when placing props on walls.")
	m_prop_clearance_spin.value_changed.connect(_on_prop_clearance_changed)


func _build_window_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Window Defaults"
	parent.add_child(header)

	m_window_style_option = OptionButton.new()
	m_window_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_window_style_option.add_item("Single Window", 0)
	m_window_style_option.set_item_metadata(0, "single_window")
	m_window_style_option.add_item("Double Window", 1)
	m_window_style_option.set_item_metadata(1, "double_window")
	m_window_style_option.add_item("Grid Window", 2)
	m_window_style_option.set_item_metadata(2, "grid_window")
	m_window_style_option.add_item("Louvered Window", 3)
	m_window_style_option.set_item_metadata(3, "louvered_window")
	m_window_style_option.add_item("Transom Window", 4)
	m_window_style_option.set_item_metadata(4, "transom_window")
	m_window_style_option.add_item("Arched Window", 5)
	m_window_style_option.set_item_metadata(5, "arched_window")
	m_window_style_option.add_item("Window Frame", 6)
	m_window_style_option.set_item_metadata(6, "frame")
	m_window_style_option.item_selected.connect(_on_window_style_selected)
	_add_labeled_control(parent, "Style:", m_window_style_option, "Window opening or frame style to place on a wall.")

	m_window_width_spin = _make_spin(0.1, 8.0, 0.01, _window_default_width("single_window"))
	_add_labeled_control(parent, "Width:", m_window_width_spin, "Opening width measured along the wall.")
	m_window_width_spin.value_changed.connect(_on_window_setting_changed)

	m_window_height_spin = _make_spin(0.1, 8.0, 0.01, 1.0)
	_add_labeled_control(parent, "Height:", m_window_height_spin, "Opening height measured upward from the sill.")
	m_window_height_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_spin = _make_spin(0.01, 1.0, 0.01, 0.08)
	_add_labeled_control(parent, "Frame:", m_window_frame_spin, "Visible frame thickness around the opening.")
	m_window_frame_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_protrusion_spin = _make_spin(0.0, 0.5, 0.005, 0.02)
	_add_labeled_control(
		parent,
		"Frame Outset:",
		m_window_frame_protrusion_spin,
		"Distance the frame casing projects beyond the wall face."
	)
	m_window_frame_protrusion_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_color_picker = _make_color_picker(Color(0.86, 0.92, 0.94, 1.0))
	_add_labeled_control(parent, "Frame Color:", m_window_frame_color_picker, "Color of the window frame casing.")
	m_window_frame_color_picker.color_changed.connect(_on_window_style_color_changed)

	m_window_sill_spin = _make_spin(0.0, 10.0, 0.01, 0.9)
	m_window_sill_spin.tooltip_text = "Height of the opening's bottom edge above the wall base."
	_add_labeled_control(parent, "Sill:", m_window_sill_spin)
	m_window_sill_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_sides_option = _make_frame_sides_option()
	_add_labeled_control(parent, "Frame Sides:", m_window_frame_sides_option, "Show the frame casing on just the placed wall face, or on both faces.")
	m_window_frame_sides_option.item_selected.connect(_on_window_frame_sides_selected)

	m_window_style_header = _add_style_properties_header(parent)

	m_window_pane_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.03)
	m_window_style_rows["pane_depth"] = _add_labeled_control(
		parent, "Pane Depth:", m_window_pane_depth_spin, "Depth of generated window glass."
	)
	m_window_pane_depth_spin.value_changed.connect(_on_window_setting_changed)

	m_window_pane_color_picker = _make_color_picker(Color(0.58, 0.82, 0.95, 0.52))
	m_window_style_rows["pane_color"] = _add_labeled_control(
		parent, "Pane Color:", m_window_pane_color_picker, "Color and opacity of generated window glass."
	)
	m_window_pane_color_picker.color_changed.connect(_on_window_style_color_changed)

	m_window_grid_rows_spin = _make_spin(0.0, 8.0, 1.0, 2.0)
	m_window_style_rows["grid_rows"] = _add_labeled_control(
		parent, "Grid Rows:", m_window_grid_rows_spin, "Horizontal muntin rows inside a grid window."
	)
	m_window_grid_rows_spin.value_changed.connect(_on_window_setting_changed)

	m_window_grid_cols_spin = _make_spin(0.0, 8.0, 1.0, 1.0)
	m_window_style_rows["grid_cols"] = _add_labeled_control(
		parent, "Grid Cols:", m_window_grid_cols_spin, "Vertical muntin columns inside a grid window."
	)
	m_window_grid_cols_spin.value_changed.connect(_on_window_setting_changed)

	m_window_muntin_thickness_spin = _make_spin(0.005, 0.3, 0.005, 0.03)
	m_window_style_rows["muntin"] = _add_labeled_control(
		parent, "Muntin:", m_window_muntin_thickness_spin, "Thickness of grid-window muntin bars."
	)
	m_window_muntin_thickness_spin.value_changed.connect(_on_window_setting_changed)

	m_window_louver_count_spin = _make_spin(1.0, 16.0, 1.0, 6.0)
	m_window_style_rows["louver_count"] = _add_labeled_control(
		parent, "Louvers:", m_window_louver_count_spin, "Number of horizontal louver slats."
	)
	m_window_louver_count_spin.value_changed.connect(_on_window_setting_changed)

	m_window_louver_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.03)
	m_window_style_rows["louver_depth"] = _add_labeled_control(
		parent, "Louver Depth:", m_window_louver_depth_spin, "Depth of generated louver slats."
	)
	m_window_louver_depth_spin.value_changed.connect(_on_window_setting_changed)

	m_window_transom_ratio_spin = _make_spin(0.0, 0.9, 0.01, 0.28)
	m_window_style_rows["transom_ratio"] = _add_labeled_control(
		parent, "Transom Ratio:", m_window_transom_ratio_spin, "Fraction of the pane height above the transom rail."
	)
	m_window_transom_ratio_spin.value_changed.connect(_on_window_setting_changed)

	m_window_transom_rail_spin = _make_spin(0.005, 0.3, 0.005, 0.03)
	m_window_style_rows["transom_rail"] = _add_labeled_control(
		parent, "Transom Rail:", m_window_transom_rail_spin, "Thickness of the transom rail."
	)
	m_window_transom_rail_spin.value_changed.connect(_on_window_setting_changed)

	m_window_arch_steps_spin = _make_spin(1.0, 6.0, 1.0, 3.0)
	m_window_style_rows["arch_steps"] = _add_labeled_control(
		parent, "Arch Steps:", m_window_arch_steps_spin, "Number of stepped bands forming the window arch."
	)
	m_window_arch_steps_spin.value_changed.connect(_on_window_setting_changed)
	_update_window_style_controls()


func _build_door_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Door Defaults"
	parent.add_child(header)

	m_door_style_option = OptionButton.new()
	m_door_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_door_style_option.add_item("Single Door", 0)
	m_door_style_option.set_item_metadata(0, "single_door")
	m_door_style_option.add_item("Double Door", 1)
	m_door_style_option.set_item_metadata(1, "double_door")
	m_door_style_option.add_item("Glazed Door", 2)
	m_door_style_option.set_item_metadata(2, "glazed_door")
	m_door_style_option.add_item("Cross Glazed Door", 3)
	m_door_style_option.set_item_metadata(3, "glazed_grid_door")
	m_door_style_option.add_item("Panel Door", 4)
	m_door_style_option.set_item_metadata(4, "panel_door")
	m_door_style_option.add_item("Dutch Door", 5)
	m_door_style_option.set_item_metadata(5, "dutch_door")
	m_door_style_option.add_item("Single Door Frame", 6)
	m_door_style_option.set_item_metadata(6, "single_frame")
	m_door_style_option.add_item("Double Door Frame", 7)
	m_door_style_option.set_item_metadata(7, "double_frame")
	m_door_style_option.item_selected.connect(_on_door_style_selected)
	_add_labeled_control(parent, "Style:", m_door_style_option, "Door opening or frame style to place on a wall.")

	m_door_width_spin = _make_spin(0.3, 8.0, 0.01, _door_default_width("single_door"))
	_add_labeled_control(parent, "Width:", m_door_width_spin, "Door opening width measured along the wall.")
	m_door_width_spin.value_changed.connect(_on_door_setting_changed)

	m_door_height_spin = _make_spin(0.3, 8.0, 0.01, 2.1)
	_add_labeled_control(parent, "Height:", m_door_height_spin, "Door opening height measured from the wall base.")
	m_door_height_spin.value_changed.connect(_on_door_setting_changed)

	m_door_frame_spin = _make_spin(0.01, 1.0, 0.01, 0.08)
	_add_labeled_control(parent, "Frame:", m_door_frame_spin, "Visible frame thickness around the door opening.")
	m_door_frame_spin.value_changed.connect(_on_door_setting_changed)

	m_door_frame_protrusion_spin = _make_spin(0.0, 0.5, 0.005, 0.02)
	_add_labeled_control(
		parent,
		"Frame Outset:",
		m_door_frame_protrusion_spin,
		"Distance the frame casing projects beyond the wall face."
	)
	m_door_frame_protrusion_spin.value_changed.connect(_on_door_setting_changed)

	m_door_frame_color_picker = _make_color_picker(Color(0.86, 0.92, 0.94, 1.0))
	_add_labeled_control(parent, "Frame Color:", m_door_frame_color_picker, "Color of the door frame casing.")
	m_door_frame_color_picker.color_changed.connect(_on_door_style_color_changed)

	m_door_frame_sides_option = _make_frame_sides_option()
	_add_labeled_control(parent, "Frame Sides:", m_door_frame_sides_option, "Show the frame casing on just the placed wall face, or on both faces.")
	m_door_frame_sides_option.item_selected.connect(_on_door_frame_sides_selected)

	m_door_style_header = _add_style_properties_header(parent)

	m_door_panel_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.05)
	m_door_style_rows["panel_depth"] = _add_labeled_control(
		parent, "Panel Depth:", m_door_panel_depth_spin, "Depth of generated solid door leaves."
	)
	m_door_panel_depth_spin.value_changed.connect(_on_door_setting_changed)

	m_door_panel_color_picker = _make_color_picker(Color(0.50, 0.34, 0.20, 1.0))
	m_door_style_rows["panel_color"] = _add_labeled_control(
		parent, "Panel Color:", m_door_panel_color_picker, "Color of generated door leaves."
	)
	m_door_panel_color_picker.color_changed.connect(_on_door_style_color_changed)

	m_door_glazing_ratio_spin = _make_spin(0.0, 0.95, 0.01, 0.55)
	m_door_style_rows["glazing_ratio"] = _add_labeled_control(
		parent, "Glazing Ratio:", m_door_glazing_ratio_spin, "Fraction of each glazed door leaf occupied by glass."
	)
	m_door_glazing_ratio_spin.value_changed.connect(_on_door_setting_changed)

	m_door_glass_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.03)
	m_door_style_rows["glass_depth"] = _add_labeled_control(
		parent, "Glass Depth:", m_door_glass_depth_spin, "Depth of generated door glass."
	)
	m_door_glass_depth_spin.value_changed.connect(_on_door_setting_changed)

	m_door_glass_color_picker = _make_color_picker(Color(0.58, 0.82, 0.95, 0.52))
	m_door_style_rows["glass_color"] = _add_labeled_control(
		parent, "Glass Color:", m_door_glass_color_picker, "Color and opacity of generated door glass."
	)
	m_door_glass_color_picker.color_changed.connect(_on_door_style_color_changed)

	m_door_grid_rows_spin = _make_spin(0.0, 8.0, 1.0, 2.0)
	m_door_style_rows["grid_rows"] = _add_labeled_control(
		parent, "Grid Rows:", m_door_grid_rows_spin, "Horizontal muntin rows inside a cross-glazed door."
	)
	m_door_grid_rows_spin.value_changed.connect(_on_door_setting_changed)

	m_door_grid_cols_spin = _make_spin(0.0, 8.0, 1.0, 1.0)
	m_door_style_rows["grid_cols"] = _add_labeled_control(
		parent, "Grid Cols:", m_door_grid_cols_spin, "Vertical muntin columns inside a cross-glazed door."
	)
	m_door_grid_cols_spin.value_changed.connect(_on_door_setting_changed)

	m_door_muntin_thickness_spin = _make_spin(0.005, 0.3, 0.005, 0.03)
	m_door_style_rows["muntin"] = _add_labeled_control(
		parent, "Muntin:", m_door_muntin_thickness_spin, "Thickness of cross-glazed muntin bars."
	)
	m_door_muntin_thickness_spin.value_changed.connect(_on_door_setting_changed)

	m_door_inset_rows_spin = _make_spin(0.0, 4.0, 1.0, 3.0)
	m_door_style_rows["inset_rows"] = _add_labeled_control(
		parent, "Inset Rows:", m_door_inset_rows_spin, "Rows of raised inset details on a panel door."
	)
	m_door_inset_rows_spin.value_changed.connect(_on_door_setting_changed)

	m_door_inset_cols_spin = _make_spin(0.0, 3.0, 1.0, 2.0)
	m_door_style_rows["inset_cols"] = _add_labeled_control(
		parent, "Inset Cols:", m_door_inset_cols_spin, "Columns of raised inset details on a panel door."
	)
	m_door_inset_cols_spin.value_changed.connect(_on_door_setting_changed)
	_update_door_style_controls()


func _make_spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _make_color_picker(initial_color: Color) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.color = initial_color
	picker.text = " "
	picker.tooltip_text = "Choose color"
	picker.custom_minimum_size = Vector2(COLOR_SWATCH_MIN_WIDTH, 0.0)
	picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	picker.size_flags_vertical = Control.SIZE_FILL
	picker.resized.connect(_on_color_picker_resized.bind(picker))
	_update_color_picker_icon(picker)
	return picker


func _on_color_picker_resized(picker: ColorPickerButton) -> void:
	_sync_color_picker_minimum_width(picker)


func _update_color_picker_icon(picker: ColorPickerButton) -> void:
	if picker == null:
		return
	picker.icon = _make_color_swatch_texture(picker.color)
	_sync_color_picker_minimum_width(picker)


func _sync_color_picker_minimum_width(picker: ColorPickerButton) -> void:
	if picker == null:
		return
	var required_width := maxf(
		COLOR_SWATCH_MIN_WIDTH,
		ceilf(maxf(picker.get_combined_minimum_size().y, picker.size.y))
	)
	if is_equal_approx(picker.custom_minimum_size.x, required_width) and is_zero_approx(picker.custom_minimum_size.y):
		return
	picker.custom_minimum_size = Vector2(required_width, 0.0)


func _refresh_color_picker_icons() -> void:
	_update_color_picker_icon(m_debug_wireframe_color_picker)
	_update_color_picker_icon(m_wall_color_picker)
	_update_color_picker_icon(m_floor_color_picker)
	_update_color_picker_icon(m_street_road_color_picker)
	_update_color_picker_icon(m_street_kerb_color_picker)
	_update_color_picker_icon(m_street_footpath_color_picker)
	_update_color_picker_icon(m_stair_color_picker)
	_update_color_picker_icon(m_rail_color_picker)
	_update_color_picker_icon(m_pillar_color_picker)
	_update_color_picker_icon(m_roof_color_picker)
	_update_color_picker_icon(m_window_frame_color_picker)
	_update_color_picker_icon(m_window_pane_color_picker)
	_update_color_picker_icon(m_door_frame_color_picker)
	_update_color_picker_icon(m_door_panel_color_picker)
	_update_color_picker_icon(m_door_glass_color_picker)


func _make_color_swatch_texture(color: Color) -> Texture2D:
	var size := COLOR_SWATCH_ICON_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var opaque_color := Color(color.r, color.g, color.b, 1.0)
	for y in range(size):
		for x in range(size):
			var checker_dark := (int(x / 4) + int(y / 4)) % 2 == 0
			var checker_color := Color(0.64, 0.64, 0.64, 1.0) if checker_dark else Color(0.86, 0.86, 0.86, 1.0)
			image.set_pixel(x, y, checker_color.lerp(opaque_color, color.a))
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var border_color := Color(0.0, 0.0, 0.0, 0.85) if luminance > 0.58 else Color(1.0, 1.0, 1.0, 0.85)
	for index in range(size):
		image.set_pixel(index, 0, border_color)
		image.set_pixel(index, size - 1, border_color)
		image.set_pixel(0, index, border_color)
		image.set_pixel(size - 1, index, border_color)
	return ImageTexture.create_from_image(image)


func _add_labeled_control(
	parent: VBoxContainer,
	label_text: String,
	control: Control,
	description: String = ""
) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(84.0, 0.0)
	var tooltip := description.strip_edges()
	if tooltip.is_empty():
		tooltip = control.tooltip_text.strip_edges()
	if !tooltip.is_empty():
		row.tooltip_text = tooltip
		label.tooltip_text = tooltip
		control.tooltip_text = tooltip
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
	return row


func _add_style_properties_header(parent: VBoxContainer) -> Label:
	var header := Label.new()
	header.text = "Style Properties"
	parent.add_child(header)
	return header


func _on_mode_selected(index: int) -> void:
	var mode := String(m_mode_option.get_item_metadata(index))
	_update_tool_tooltip_for_mode(mode)
	_update_visible_tool_section(mode)
	tool_mode_changed.emit(mode)


func select_tool_mode(mode: String) -> void:
	# Programmatic entry point (used by the 3D viewport toolbar) that mirrors a
	# user choosing a tool in the dock's option button.
	var index := _index_for_tool_mode(mode)
	if index < 0:
		return
	if m_mode_option != null:
		m_mode_option.select(index)
	_update_tool_tooltip_for_mode(mode)
	_update_visible_tool_section(mode)
	tool_mode_changed.emit(mode)


func _index_for_tool_mode(mode: String) -> int:
	if m_mode_option == null:
		return -1
	for i in range(m_mode_option.item_count):
		if String(m_mode_option.get_item_metadata(i)) == mode:
			return i
	return -1


func _update_tool_tooltip_for_mode(mode: String) -> void:
	if m_mode_option == null:
		return
	m_mode_option.tooltip_text = _shortcut_text_for_mode(mode)


func _shortcut_text_for_mode(mode: String) -> String:
	match mode:
		MODE_WALL:
			return SHORTCUTS_WALL_TEXT
		MODE_FLOOR:
			return SHORTCUTS_FLOOR_TEXT
		MODE_STREET:
			return SHORTCUTS_STREET_TEXT
		MODE_STAIRS:
			return SHORTCUTS_STAIRS_TEXT
		MODE_RAIL:
			return SHORTCUTS_RAIL_TEXT
		MODE_PILLAR:
			return SHORTCUTS_PILLAR_TEXT
		MODE_ROOF:
			return SHORTCUTS_ROOF_TEXT
		MODE_PROP:
			return SHORTCUTS_PROP_TEXT
		MODE_WINDOW:
			return SHORTCUTS_WINDOW_TEXT
		MODE_DOOR:
			return SHORTCUTS_DOOR_TEXT
		_:
			return SHORTCUTS_SELECT_TEXT


func _update_visible_tool_section(mode: String) -> void:
	if m_wall_section != null:
		m_wall_section.visible = mode == MODE_WALL
	if m_floor_section != null:
		m_floor_section.visible = mode == MODE_FLOOR
	if m_street_section != null:
		m_street_section.visible = mode == MODE_STREET
	if m_stair_section != null:
		m_stair_section.visible = mode == MODE_STAIRS
	if m_rail_section != null:
		m_rail_section.visible = mode == MODE_RAIL
	if m_pillar_section != null:
		m_pillar_section.visible = mode == MODE_PILLAR
	if m_roof_section != null:
		m_roof_section.visible = mode == MODE_ROOF
	if m_prop_section != null:
		m_prop_section.visible = mode == MODE_PROP
	if m_window_section != null:
		m_window_section.visible = mode == MODE_WINDOW
	if m_door_section != null:
		m_door_section.visible = mode == MODE_DOOR


func _on_create_coordinator() -> void:
	create_coordinator_requested.emit()


func _on_browse_scene() -> void:
	m_scene_dialog.current_dir = _get_resolved_palette_root()["path"]
	m_scene_dialog.popup_centered(Vector2i(720, 520))


func _on_browse_palette_root() -> void:
	m_palette_root_dialog.current_dir = _get_resolved_palette_root()["path"]
	m_palette_root_dialog.popup_centered(Vector2i(720, 520))


func _on_palette_root_selected(dir: String) -> void:
	m_palette_root_edit.text = dir
	_save_persisted_settings()
	_scan_palette()


func _on_palette_root_submitted(_text: String) -> void:
	_save_persisted_settings()
	_scan_palette()


func _on_palette_root_focus_exited() -> void:
	_save_persisted_settings()


func _on_scene_selected(path: String) -> void:
	m_prop_path_edit.text = path
	_on_prop_setting_changed(path)


func _on_palette_item_selected(index: int) -> void:
	if index < 0 or index >= m_palette_paths.size():
		return
	var path := m_palette_paths[index]
	m_prop_path_edit.text = path
	_on_prop_setting_changed(path)


func _on_wall_setting_changed(_value: float) -> void:
	_emit_wall_settings()


func _on_wall_type_selected(_index: int) -> void:
	_update_wall_type_controls()
	_emit_wall_settings()


func _on_wall_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_wall_color_picker)
	_emit_wall_settings()


func _on_wall_lock_changed(_pressed: bool) -> void:
	_emit_wall_settings()


func _on_floor_type_selected(_index: int) -> void:
	_update_floor_type_controls()
	_emit_floor_settings()


func _on_floor_style_selected(_index: int) -> void:
	_emit_floor_settings()


func _on_floor_setting_changed(_value: float) -> void:
	_emit_floor_settings()


func _on_floor_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_floor_color_picker)
	_emit_floor_settings()


func _on_street_setting_changed(_value: float) -> void:
	_emit_street_settings()


func _on_street_cross_section_selected(_index: int) -> void:
	_update_street_cross_section_controls()
	_emit_street_settings()


func _update_street_cross_section_controls() -> void:
	var mode := _selected_option_metadata(
		m_street_cross_section_option, STREET_CROSS_SECTION_ROAD_AND_FOOTPATH
	)
	var has_road := mode != STREET_CROSS_SECTION_FOOTPATH_ONLY
	var has_side_footpaths := mode == STREET_CROSS_SECTION_ROAD_AND_FOOTPATH
	var has_footpath := mode != STREET_CROSS_SECTION_ROAD_ONLY
	if m_street_road_thickness_spin != null:
		m_street_road_thickness_spin.editable = has_road
	if m_street_road_color_picker != null:
		m_street_road_color_picker.disabled = !has_road
	for spin: SpinBox in [
		m_street_kerb_width_spin,
		m_street_kerb_height_spin,
		m_street_footpath_width_spin,
	]:
		if spin != null:
			spin.editable = has_side_footpaths
	if m_street_kerb_color_picker != null:
		m_street_kerb_color_picker.disabled = !has_side_footpaths
	if m_street_footpath_thickness_spin != null:
		m_street_footpath_thickness_spin.editable = has_footpath
	if m_street_footpath_color_picker != null:
		m_street_footpath_color_picker.disabled = !has_footpath
	for stair_spin: SpinBox in [
		m_street_stair_threshold_spin,
		m_street_target_riser_spin,
		m_street_max_riser_spin,
		m_street_min_tread_spin,
	]:
		if stair_spin != null:
			stair_spin.editable = has_footpath


func _on_street_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_street_road_color_picker)
	_update_color_picker_icon(m_street_kerb_color_picker)
	_update_color_picker_icon(m_street_footpath_color_picker)
	_emit_street_settings()


func _on_street_resample_pressed() -> void:
	street_resample_requested.emit()


func _on_stair_setting_changed(_value: float) -> void:
	_update_stair_newel_controls()
	_emit_stair_settings()


func _on_stair_setting_toggled(_pressed: bool) -> void:
	_update_stair_newel_controls()
	_emit_stair_settings()


func _on_stair_newel_position_selected(_index: int) -> void:
	_update_stair_newel_controls()
	_emit_stair_settings()


func _on_stair_rail_style_selected(_index: int) -> void:
	_update_stair_newel_controls()
	_emit_stair_settings()


func _on_stair_layout_selected(_index: int) -> void:
	_update_stair_layout_controls()
	_emit_stair_settings()


func _on_stair_tread_style_selected(_index: int) -> void:
	_update_stair_tread_controls()
	_emit_stair_settings()


func _on_stair_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_stair_color_picker)
	_emit_stair_settings()


func _on_rail_setting_changed(_value: float) -> void:
	_emit_rail_settings()
	_emit_stair_settings()


func _on_rail_style_selected(_index: int) -> void:
	_emit_rail_settings()


func _on_rail_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_rail_color_picker)
	_emit_rail_settings()
	_emit_stair_settings()


func _on_pillar_setting_changed(_value: float) -> void:
	_emit_pillar_settings()


func _on_pillar_style_selected(_index: int) -> void:
	_update_pillar_style_controls()
	_emit_pillar_settings()


func _on_pillar_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_pillar_color_picker)
	_emit_pillar_settings()


func _on_roof_setting_changed(_value: float) -> void:
	_emit_roof_settings()


func _on_roof_style_selected(_index: int) -> void:
	_update_roof_style_controls()
	_emit_roof_settings()


func _on_roof_hip_shape_selected(_index: int) -> void:
	_update_roof_style_controls()
	_emit_roof_settings()


func _on_roof_footprint_selected(_index: int) -> void:
	_emit_roof_settings()


func _on_roof_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_roof_color_picker)
	_emit_roof_settings()


func _on_debug_wireframe_changed(_pressed: bool) -> void:
	_update_debug_wireframe_controls()
	_emit_display_settings()


func _on_debug_wireframe_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_debug_wireframe_color_picker)
	_emit_display_settings()


func _update_debug_wireframe_controls() -> void:
	if m_debug_wireframe_xray_check != null:
		m_debug_wireframe_xray_check.disabled = (
			m_debug_wireframe_check == null
			or !m_debug_wireframe_check.button_pressed
		)
	if m_debug_wireframe_color_picker != null:
		m_debug_wireframe_color_picker.disabled = (
			m_debug_wireframe_check == null
			or !m_debug_wireframe_check.button_pressed
		)


func _on_prop_setting_changed(_value: String) -> void:
	_emit_prop_settings()


func _on_prop_clearance_changed(_value: float) -> void:
	_emit_prop_settings()


func _on_window_setting_changed(_value: float) -> void:
	_emit_window_settings()


func _on_window_style_selected(_index: int) -> void:
	var style := _selected_window_style()
	if m_window_width_spin != null:
		m_window_width_spin.value = _window_default_width(style)
	_update_window_style_controls()
	_emit_window_settings()


func _on_door_style_selected(_index: int) -> void:
	var style := _selected_door_style()
	if m_door_width_spin != null:
		m_door_width_spin.value = _door_default_width(style)
	_update_door_style_controls()
	_emit_door_settings()


func _on_door_setting_changed(_value: float) -> void:
	_emit_door_settings()


func _on_window_style_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_window_frame_color_picker)
	_update_color_picker_icon(m_window_pane_color_picker)
	_emit_window_settings()


func _on_door_style_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_door_frame_color_picker)
	_update_color_picker_icon(m_door_panel_color_picker)
	_update_color_picker_icon(m_door_glass_color_picker)
	_emit_door_settings()


func _on_window_frame_sides_selected(_index: int) -> void:
	_emit_window_settings()


func _on_door_frame_sides_selected(_index: int) -> void:
	_emit_door_settings()


func _make_frame_sides_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("Placed Side", 0)
	option.set_item_metadata(0, 0)
	option.add_item("Both Sides", 1)
	option.set_item_metadata(1, 1)
	return option


func _make_newel_position_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("Tread", 0)
	option.set_item_metadata(0, 0)
	option.add_item("Floor", 1)
	option.set_item_metadata(1, 1)
	return option


func _make_stair_layout_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for layout: Dictionary in BuildingFactoryScript.STAIR_LAYOUTS:
		option.add_item(String(layout["label"]))
		option.set_item_metadata(option.item_count - 1, layout["script"])
	return option


func _make_stair_tread_style_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var labels := PackedStringArray(["Closed", "Open", "Nosing"])
	for index in range(labels.size()):
		option.add_item(labels[index], index)
		option.set_item_metadata(index, index)
	return option


func _make_stair_turn_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("Left", 0)
	option.set_item_metadata(0, 0)
	option.add_item("Right", 1)
	option.set_item_metadata(1, 1)
	option.select(1)
	return option


func _make_stair_winder_turn_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("90 Degrees", 0)
	option.set_item_metadata(0, 0)
	option.add_item("180 Degrees", 1)
	option.set_item_metadata(1, 1)
	return option


func _selected_option_metadata(option: OptionButton, fallback: int) -> int:
	if option == null or option.selected < 0:
		return fallback
	return int(option.get_item_metadata(option.selected))


func _stair_layout_script_from_value(value: Variant) -> Script:
	var selected_script: Script
	if value is Script:
		selected_script = value as Script
	if (
		selected_script != null
		and !BuildingFactoryScript.get_stair_layout(selected_script).is_empty()
	):
		return selected_script
	var selection := String(value)
	for layout: Dictionary in BuildingFactoryScript.STAIR_LAYOUTS:
		var candidate := layout["script"] as Script
		if String(layout["key"]) == selection or candidate.resource_path == selection:
			return candidate
	return BuildingFactoryScript.StraightStairs3DScript


func _selected_stair_layout_script() -> Script:
	if m_stair_layout_option == null or m_stair_layout_option.selected < 0:
		return BuildingFactoryScript.StraightStairs3DScript
	return _stair_layout_script_from_value(
		m_stair_layout_option.get_item_metadata(m_stair_layout_option.selected)
	)


func _select_stair_layout_script(value: Variant) -> void:
	var selected_script := _stair_layout_script_from_value(value)
	for index in range(m_stair_layout_option.get_item_count()):
		if m_stair_layout_option.get_item_metadata(index) != selected_script:
			continue
		m_stair_layout_option.select(index)
		return
	m_stair_layout_option.select(0)


func _update_stair_layout_controls() -> void:
	var layout_script := _selected_stair_layout_script()
	var layout := BuildingFactoryScript.get_stair_layout(layout_script)
	var layout_key := String(layout.get("key", "straight"))
	var is_straight := layout_key == "straight"
	var is_winder := layout_key == "winder"
	var is_spiral := layout_key == "spiral"
	if m_stair_turn_option != null:
		m_stair_turn_option.disabled = is_straight
	if m_stair_winder_turn_option != null:
		m_stair_winder_turn_option.disabled = !is_winder
	if m_stair_spiral_turn_spin != null:
		m_stair_spiral_turn_spin.editable = is_spiral
	if m_stair_flight_width_spin != null:
		m_stair_flight_width_spin.editable = !is_straight
	if m_stair_tread_style_option != null:
		m_stair_tread_style_option.set_item_disabled(TREAD_STYLE_NOSING, is_spiral)
		if (
			is_spiral
			and _selected_option_metadata(
				m_stair_tread_style_option, TREAD_STYLE_CLOSED
			) == TREAD_STYLE_NOSING
		):
			m_stair_tread_style_option.select(TREAD_STYLE_CLOSED)
	_update_stair_tread_controls()


func _update_stair_tread_controls() -> void:
	if m_stair_nosing_spin != null:
		m_stair_nosing_spin.editable = (
			_selected_option_metadata(m_stair_tread_style_option, TREAD_STYLE_CLOSED)
			== TREAD_STYLE_NOSING
		)


func _make_rail_style_option() -> OptionButton:
	var option := OptionButton.new()
	option.add_item("Vertical Rail", RAIL_STYLE_VERTICAL)
	option.set_item_metadata(0, RAIL_STYLE_VERTICAL)
	option.add_item("Horizontal Rail", RAIL_STYLE_HORIZONTAL)
	option.set_item_metadata(1, RAIL_STYLE_HORIZONTAL)
	option.add_item("Glass Panel", RAIL_STYLE_GLASS_PANEL)
	option.set_item_metadata(2, RAIL_STYLE_GLASS_PANEL)
	return option


func _selected_rail_style(option: OptionButton) -> int:
	if option == null or option.selected < 0:
		return RAIL_STYLE_VERTICAL
	return int(option.get_item_metadata(option.selected))


func _select_rail_style(option: OptionButton, value: int) -> void:
	if option == null:
		return
	for index in range(option.get_item_count()):
		if int(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _selected_newel_placement(option: OptionButton) -> int:
	if option == null or option.selected < 0:
		return 0
	return int(option.get_item_metadata(option.selected))


func _select_newel_placement(option: OptionButton, value: int) -> void:
	if option == null:
		return
	for index in range(option.get_item_count()):
		if int(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _update_stair_newel_controls() -> void:
	var lower_enabled := (
		m_stair_lower_newel_check != null
		and m_stair_lower_newel_check.button_pressed
	)
	var upper_enabled := (
		m_stair_upper_newel_check != null
		and m_stair_upper_newel_check.button_pressed
	)
	if m_stair_lower_newel_position_option != null:
		m_stair_lower_newel_position_option.disabled = !lower_enabled
	if m_stair_upper_newel_position_option != null:
		m_stair_upper_newel_position_option.disabled = !upper_enabled
	if m_stair_middle_newel_count_spin != null and m_stair_step_count_spin != null:
		var explicit_terminal_count := (
			(1 if lower_enabled else 0)
			+ (1 if upper_enabled else 0)
		)
		var maximum_newel_count := int(roundf(m_stair_step_count_spin.value))
		if (
			lower_enabled
			and _selected_newel_placement(
				m_stair_lower_newel_position_option
			) != NEWEL_PLACEMENT_TREAD
		):
			maximum_newel_count += 1
		if (
			upper_enabled
			and _selected_newel_placement(
				m_stair_upper_newel_position_option
			) != NEWEL_PLACEMENT_TREAD
		):
			maximum_newel_count += 1
		m_stair_middle_newel_count_spin.max_value = maximum_newel_count
		m_stair_middle_newel_count_spin.min_value = explicit_terminal_count
	if m_stair_newel_size_spin != null:
		var middle_count := (
			int(roundf(m_stair_middle_newel_count_spin.value))
			if m_stair_middle_newel_count_spin != null
			else 0
		)
		m_stair_newel_size_spin.editable = lower_enabled or upper_enabled or middle_count > 0


func _selected_frame_sides(option: OptionButton) -> int:
	if option == null or option.selected < 0:
		return 0
	return int(option.get_item_metadata(option.selected))


func _select_frame_sides(option: OptionButton, value: int) -> void:
	if option == null:
		return
	for index in range(option.get_item_count()):
		if int(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _emit_all_settings() -> void:
	_emit_display_settings()
	_emit_wall_settings()
	_emit_floor_settings()
	_emit_street_settings()
	_emit_stair_settings()
	_emit_rail_settings()
	_emit_pillar_settings()
	_emit_roof_settings()
	_emit_prop_settings()
	_emit_window_settings()
	_emit_door_settings()


func _emit_display_settings() -> void:
	display_settings_changed.emit({
		"wireframe": (
			m_debug_wireframe_check != null
			and m_debug_wireframe_check.button_pressed
		),
		"wireframe_xray": (
			m_debug_wireframe_xray_check != null
			and m_debug_wireframe_xray_check.button_pressed
		),
		"wireframe_color": (
			m_debug_wireframe_color_picker.color
			if m_debug_wireframe_color_picker != null
			else Color(0.05, 0.95, 1.0, 1.0)
		),
	})


func _emit_wall_settings() -> void:
	wall_settings_changed.emit({
		"grid_step": float(m_grid_spin.value),
		"type": _selected_wall_type(),
		"room_sides": maxi(int(roundf(m_room_sides_spin.value)), 3),
		"base_height": float(m_wall_base_height_spin.value),
		"height": float(m_wall_height_spin.value),
		"thickness": float(m_wall_thickness_spin.value),
		"color": m_wall_color_picker.color,
		"lock_8_way": m_lock_8_way_check.button_pressed,
	})


func _emit_floor_settings() -> void:
	floor_settings_changed.emit({
		"grid_step": float(m_floor_grid_spin.value),
		"type": _selected_floor_type(),
		"style": _selected_floor_style(),
		"base_height": float(m_floor_base_height_spin.value),
		"thickness": float(m_floor_thickness_spin.value),
		"color": m_floor_color_picker.color,
	})


func _emit_street_settings() -> void:
	street_settings_changed.emit({
		"grid_step": float(m_street_grid_spin.value),
		"base_height": float(m_street_base_height_spin.value),
		"cross_section_mode": _selected_option_metadata(
			m_street_cross_section_option, STREET_CROSS_SECTION_ROAD_AND_FOOTPATH
		),
		"road_width": float(m_street_road_width_spin.value),
		"road_thickness": float(m_street_road_thickness_spin.value),
		"road_color": m_street_road_color_picker.color,
		"kerb_width": float(m_street_kerb_width_spin.value),
		"kerb_height": float(m_street_kerb_height_spin.value),
		"kerb_color": m_street_kerb_color_picker.color,
		"footpath_width": float(m_street_footpath_width_spin.value),
		"footpath_thickness": float(m_street_footpath_thickness_spin.value),
		"footpath_color": m_street_footpath_color_picker.color,
		"stair_threshold_degrees": float(m_street_stair_threshold_spin.value),
		"target_riser_height": float(m_street_target_riser_spin.value),
		"max_riser_height": float(m_street_max_riser_spin.value),
		"min_tread_depth": float(m_street_min_tread_spin.value),
		"terrain_sample_spacing": float(m_street_sample_spacing_spin.value),
		"terrain_clearance": float(m_street_clearance_spin.value),
	})


func _emit_stair_settings() -> void:
	stair_settings_changed.emit({
		"grid_step": float(m_stair_grid_spin.value),
		"base_height": float(m_stair_base_height_spin.value),
		"height": float(m_stair_height_spin.value),
		"step_count": int(roundf(m_stair_step_count_spin.value)),
		"thickness": float(m_stair_thickness_spin.value),
		"tread_style": _selected_option_metadata(
			m_stair_tread_style_option, TREAD_STYLE_CLOSED
		),
		"nosing_depth": (
			float(m_stair_nosing_spin.value)
			if m_stair_nosing_spin != null
			else 0.08
		),
		"rotation_degrees": float(m_stair_rotation_spin.value),
		"color": m_stair_color_picker.color,
		"layout_script": _selected_stair_layout_script(),
		"turn_direction": _selected_option_metadata(m_stair_turn_option, 1),
		"winder_turn": _selected_option_metadata(m_stair_winder_turn_option, 0),
		"spiral_turn_degrees": (
			float(m_stair_spiral_turn_spin.value)
			if m_stair_spiral_turn_spin != null
			else 360.0
		),
		"flight_width": (
			float(m_stair_flight_width_spin.value)
			if m_stair_flight_width_spin != null
			else 1.2
		),
		"left_rail_enabled": (
			m_stair_left_rail_check.button_pressed if m_stair_left_rail_check != null else false
		),
		"right_rail_enabled": (
			m_stair_right_rail_check.button_pressed if m_stair_right_rail_check != null else false
		),
		"infill_style": _selected_rail_style(m_stair_rail_style_option),
		"lower_newel_enabled": (
			m_stair_lower_newel_check.button_pressed
			if m_stair_lower_newel_check != null
			else false
		),
		"lower_newel_placement": _selected_newel_placement(
			m_stair_lower_newel_position_option
		),
		"upper_newel_enabled": (
			m_stair_upper_newel_check.button_pressed
			if m_stair_upper_newel_check != null
			else false
		),
		"upper_newel_placement": _selected_newel_placement(
			m_stair_upper_newel_position_option
		),
		"middle_newel_post_count": (
			int(roundf(m_stair_middle_newel_count_spin.value))
			if m_stair_middle_newel_count_spin != null
			else 0
		),
		"infill_count_between_newels": (
			int(roundf(m_stair_infill_count_spin.value))
			if m_stair_infill_count_spin != null
			else 1
		),
		"rail_newel_post_thickness": (
			float(m_stair_newel_size_spin.value)
			if m_stair_newel_size_spin != null
			else 0.1
		),
		"rail_edge_margin": (
			float(m_stair_rail_margin_spin.value) if m_stair_rail_margin_spin != null else 0.15
		),
		"rail_height": float(m_rail_height_spin.value) if m_rail_height_spin != null else 1.0,
		"infill_rail_thickness": (
			float(m_rail_post_thickness_spin.value) if m_rail_post_thickness_spin != null else 0.08
		),
		"rail_thickness": (
			float(m_rail_bar_thickness_spin.value) if m_rail_bar_thickness_spin != null else 0.1
		),
		"rail_lower_height": (
			float(m_rail_lower_height_spin.value) if m_rail_lower_height_spin != null else 0.18
		),
		"rail_color": (
			m_rail_color_picker.color if m_rail_color_picker != null
			else Color(0.33, 0.28, 0.22, 1.0)
		),
	})


func _emit_rail_settings() -> void:
	rail_settings_changed.emit({
		"grid_step": float(m_rail_grid_spin.value),
		"base_height": float(m_rail_base_height_spin.value),
		"height": float(m_rail_height_spin.value),
		"post_spacing": float(m_rail_post_spacing_spin.value),
		"infill_rail_thickness": float(m_rail_post_thickness_spin.value),
		"rail_thickness": float(m_rail_bar_thickness_spin.value),
		"infill_style": _selected_rail_style(m_rail_style_option),
		"newel_post_count": int(roundf(m_rail_newel_count_spin.value)),
		"infill_count_between_newels": int(roundf(m_rail_infill_count_spin.value)),
		"newel_post_thickness": float(m_rail_newel_size_spin.value),
		"lower_rail_height": float(m_rail_lower_height_spin.value),
		"color": m_rail_color_picker.color,
	})


func _emit_pillar_settings() -> void:
	pillar_settings_changed.emit({
		"grid_step": float(m_pillar_grid_spin.value),
		"style": _selected_pillar_style(),
		"base_height": float(m_pillar_base_height_spin.value),
		"radius": float(m_pillar_radius_spin.value),
		"upper_radius": float(m_pillar_upper_radius_spin.value),
		"height": float(m_pillar_height_spin.value),
		"sides": int(roundf(m_pillar_sides_spin.value)),
		"lower_rim_height": float(m_pillar_lower_rim_height_spin.value),
		"lower_rim_outset": float(m_pillar_lower_rim_outset_spin.value),
		"upper_rim_height": float(m_pillar_upper_rim_height_spin.value),
		"upper_rim_outset": float(m_pillar_upper_rim_outset_spin.value),
		"color": m_pillar_color_picker.color,
	})


func _emit_roof_settings() -> void:
	roof_settings_changed.emit({
		"grid_step": float(m_roof_grid_spin.value),
		"style": _selected_roof_style(),
		"footprint_style": _selected_roof_footprint_style(),
		"base_height": float(m_roof_base_height_spin.value),
		"height": float(m_roof_height_spin.value),
		"thickness": float(m_roof_thickness_spin.value),
		"overhang": float(m_roof_overhang_spin.value),
		"hip_gable_height": float(m_roof_hip_gable_height_spin.value),
		"hip_shape": _selected_roof_hip_shape(),
		"rotation_degrees": float(m_roof_rotation_spin.value),
		"color": m_roof_color_picker.color,
	})


func _selected_wall_type() -> String:
	if m_wall_type_option == null or m_wall_type_option.selected < 0:
		return WALL_TYPE_WALL
	return String(m_wall_type_option.get_item_metadata(m_wall_type_option.selected))


func _select_wall_type(wall_type: String) -> void:
	if m_wall_type_option == null:
		return
	for index in range(m_wall_type_option.get_item_count()):
		if String(m_wall_type_option.get_item_metadata(index)) == wall_type:
			m_wall_type_option.select(index)
			_update_wall_type_controls()
			return
	m_wall_type_option.select(0)
	_update_wall_type_controls()


func _update_wall_type_controls() -> void:
	var is_room := _selected_wall_type() == WALL_TYPE_ROOM
	if m_lock_8_way_check != null:
		m_lock_8_way_check.disabled = is_room
	if m_room_sides_row != null:
		m_room_sides_row.visible = is_room


func _selected_floor_type() -> String:
	if m_floor_type_option == null or m_floor_type_option.selected < 0:
		return FLOOR_TYPE_SOLID
	return String(m_floor_type_option.get_item_metadata(m_floor_type_option.selected))


func _select_floor_type(floor_type: String) -> void:
	if m_floor_type_option == null:
		return
	for index in range(m_floor_type_option.get_item_count()):
		if String(m_floor_type_option.get_item_metadata(index)) == floor_type:
			m_floor_type_option.select(index)
			_update_floor_type_controls()
			return
	m_floor_type_option.select(0)
	_update_floor_type_controls()


func _selected_floor_style() -> String:
	if m_floor_style_option == null or m_floor_style_option.selected < 0:
		return FLOOR_STYLE_RECTANGLE
	return String(m_floor_style_option.get_item_metadata(m_floor_style_option.selected))


func _select_floor_style(floor_style: String) -> void:
	if m_floor_style_option == null:
		return
	for index in range(m_floor_style_option.get_item_count()):
		if String(m_floor_style_option.get_item_metadata(index)) == floor_style:
			m_floor_style_option.select(index)
			return
	m_floor_style_option.select(0)


func _update_floor_type_controls() -> void:
	if m_floor_style_option != null:
		m_floor_style_option.disabled = false


func _selected_pillar_style() -> String:
	if m_pillar_style_option == null or m_pillar_style_option.selected < 0:
		return "round"
	return String(m_pillar_style_option.get_item_metadata(m_pillar_style_option.selected))


func _select_pillar_style(style: String) -> void:
	if m_pillar_style_option == null:
		return
	for index in range(m_pillar_style_option.get_item_count()):
		if String(m_pillar_style_option.get_item_metadata(index)) == style:
			m_pillar_style_option.select(index)
			_update_pillar_style_controls()
			return
	m_pillar_style_option.select(0)
	_update_pillar_style_controls()


func _update_pillar_style_controls() -> void:
	var has_side_count := _selected_pillar_style() in ["round", "tapered"]
	if m_pillar_style_header != null:
		m_pillar_style_header.visible = has_side_count
	if m_pillar_sides_row != null:
		m_pillar_sides_row.visible = has_side_count


func _selected_roof_style() -> String:
	if m_roof_style_option == null or m_roof_style_option.selected < 0:
		return "gable"
	return String(m_roof_style_option.get_item_metadata(m_roof_style_option.selected))


func _selected_roof_footprint_style() -> String:
	if m_roof_footprint_option == null or m_roof_footprint_option.selected < 0:
		return FLOOR_STYLE_RECTANGLE
	return String(m_roof_footprint_option.get_item_metadata(m_roof_footprint_option.selected))


func _select_roof_footprint_style(style: String) -> void:
	if m_roof_footprint_option == null:
		return
	for index in range(m_roof_footprint_option.get_item_count()):
		if String(m_roof_footprint_option.get_item_metadata(index)) == style:
			m_roof_footprint_option.select(index)
			return
	m_roof_footprint_option.select(0)


func _select_roof_style(style: String) -> void:
	if m_roof_style_option == null:
		return
	for index in range(m_roof_style_option.get_item_count()):
		if String(m_roof_style_option.get_item_metadata(index)) == style:
			m_roof_style_option.select(index)
			_update_roof_style_controls()
			return
	for index in range(m_roof_style_option.get_item_count()):
		if String(m_roof_style_option.get_item_metadata(index)) == "gable":
			m_roof_style_option.select(index)
			break
	_update_roof_style_controls()


func _update_roof_style_controls() -> void:
	var style := _selected_roof_style()
	var has_angle := style != "flat"
	var is_hip := style == "hip"
	# Only the standard hip shape carries a ridge and its gable drop.
	var has_gable_drop := is_hip and _selected_roof_hip_shape() == 0
	if m_roof_footprint_row != null:
		m_roof_footprint_row.visible = style == "flat"
	if m_roof_style_header != null:
		m_roof_style_header.visible = has_angle or is_hip
	if m_roof_angle_row != null:
		m_roof_angle_row.visible = has_angle
	if m_roof_hip_shape_row != null:
		m_roof_hip_shape_row.visible = is_hip
	if m_roof_hip_gable_height_row != null:
		m_roof_hip_gable_height_row.visible = has_gable_drop


func _selected_roof_hip_shape() -> int:
	if m_roof_hip_shape_option == null or m_roof_hip_shape_option.selected < 0:
		return 0
	return int(m_roof_hip_shape_option.get_item_metadata(m_roof_hip_shape_option.selected))


func _select_roof_hip_shape(hip_shape: int) -> void:
	if m_roof_hip_shape_option == null:
		return
	for index in range(m_roof_hip_shape_option.get_item_count()):
		if int(m_roof_hip_shape_option.get_item_metadata(index)) == hip_shape:
			m_roof_hip_shape_option.select(index)
			_update_roof_style_controls()
			return
	m_roof_hip_shape_option.select(0)
	_update_roof_style_controls()


func _emit_prop_settings() -> void:
	prop_settings_changed.emit({
		"scene_path": m_prop_path_edit.text.strip_edges(),
		"clearance": float(m_prop_clearance_spin.value),
	})


func _emit_window_settings() -> void:
	window_settings_changed.emit({
		"style": _selected_window_style(),
		"width": float(m_window_width_spin.value),
		"height": float(m_window_height_spin.value),
		"frame_thickness": float(m_window_frame_spin.value),
		"frame_protrusion": float(m_window_frame_protrusion_spin.value),
		"frame_color": m_window_frame_color_picker.color,
		"sill_height": float(m_window_sill_spin.value),
		"frame_sides": _selected_frame_sides(m_window_frame_sides_option),
		"window_pane_depth": float(m_window_pane_depth_spin.value),
		"window_pane_color": m_window_pane_color_picker.color,
		"pane_grid_rows": int(roundf(m_window_grid_rows_spin.value)),
		"pane_grid_cols": int(roundf(m_window_grid_cols_spin.value)),
		"muntin_thickness": float(m_window_muntin_thickness_spin.value),
		"louver_count": int(roundf(m_window_louver_count_spin.value)),
		"louver_depth": float(m_window_louver_depth_spin.value),
		"transom_ratio": float(m_window_transom_ratio_spin.value),
		"transom_rail_thickness": float(m_window_transom_rail_spin.value),
		"arch_steps": int(roundf(m_window_arch_steps_spin.value)),
	})


func _selected_window_style() -> String:
	if m_window_style_option == null or m_window_style_option.selected < 0:
		return "single_window"
	return String(m_window_style_option.get_item_metadata(m_window_style_option.selected))


func _select_window_style(style: String) -> void:
	if m_window_style_option == null:
		return
	for index in range(m_window_style_option.get_item_count()):
		if String(m_window_style_option.get_item_metadata(index)) == style:
			m_window_style_option.select(index)
			_update_window_style_controls()
			return
	m_window_style_option.select(0)
	_update_window_style_controls()


func _update_window_style_controls() -> void:
	var style := _selected_window_style()
	var visible_keys: Array[String] = []
	if style in ["single_window", "double_window", "grid_window", "transom_window", "arched_window"]:
		visible_keys.append_array(["pane_depth", "pane_color"])
	match style:
		"grid_window":
			visible_keys.append_array(["grid_rows", "grid_cols", "muntin"])
		"louvered_window":
			visible_keys.append_array(["louver_count", "louver_depth"])
		"transom_window":
			visible_keys.append_array(["transom_ratio", "transom_rail"])
		"arched_window":
			visible_keys.append("arch_steps")
	_set_style_rows_visible(m_window_style_rows, visible_keys)
	if m_window_style_header != null:
		m_window_style_header.visible = !visible_keys.is_empty()


func _window_default_width(style: String) -> float:
	return 1.8 if style == "double_window" else 1.0


func _emit_door_settings() -> void:
	door_settings_changed.emit({
		"style": _selected_door_style(),
		"width": float(m_door_width_spin.value),
		"height": float(m_door_height_spin.value),
		"frame_thickness": float(m_door_frame_spin.value),
		"frame_protrusion": float(m_door_frame_protrusion_spin.value),
		"frame_color": m_door_frame_color_picker.color,
		"frame_sides": _selected_frame_sides(m_door_frame_sides_option),
		"door_panel_depth": float(m_door_panel_depth_spin.value),
		"door_panel_color": m_door_panel_color_picker.color,
		"door_glazing_ratio": float(m_door_glazing_ratio_spin.value),
		"door_glass_depth": float(m_door_glass_depth_spin.value),
		"door_glass_color": m_door_glass_color_picker.color,
		"pane_grid_rows": int(roundf(m_door_grid_rows_spin.value)),
		"pane_grid_cols": int(roundf(m_door_grid_cols_spin.value)),
		"muntin_thickness": float(m_door_muntin_thickness_spin.value),
		"door_inset_rows": int(roundf(m_door_inset_rows_spin.value)),
		"door_inset_cols": int(roundf(m_door_inset_cols_spin.value)),
	})


func _selected_door_style() -> String:
	if m_door_style_option == null or m_door_style_option.selected < 0:
		return "single_door"
	return String(m_door_style_option.get_item_metadata(m_door_style_option.selected))


func _select_door_style(style: String) -> void:
	if m_door_style_option == null:
		return
	for index in range(m_door_style_option.get_item_count()):
		if String(m_door_style_option.get_item_metadata(index)) == style:
			m_door_style_option.select(index)
			_update_door_style_controls()
			return
	m_door_style_option.select(0)
	_update_door_style_controls()


func _update_door_style_controls() -> void:
	var style := _selected_door_style()
	var visible_keys: Array[String] = []
	if style not in ["single_frame", "double_frame"]:
		visible_keys.append_array(["panel_depth", "panel_color"])
	if style in ["glazed_door", "glazed_grid_door"]:
		visible_keys.append_array(["glazing_ratio", "glass_depth", "glass_color"])
	if style == "glazed_grid_door":
		visible_keys.append_array(["grid_rows", "grid_cols", "muntin"])
	if style == "panel_door":
		visible_keys.append_array(["inset_rows", "inset_cols"])
	_set_style_rows_visible(m_door_style_rows, visible_keys)
	if m_door_style_header != null:
		m_door_style_header.visible = !visible_keys.is_empty()


func _set_style_rows_visible(rows: Dictionary, visible_keys: Array[String]) -> void:
	for key_variant in rows:
		var key := String(key_variant)
		var row := rows[key_variant] as Control
		if row != null:
			row.visible = visible_keys.has(key)


func _door_default_width(style: String) -> float:
	return 1.6 if style.begins_with("double") else 0.9


func _scan_palette() -> void:
	m_palette_paths.clear()
	var root_state := _get_resolved_palette_root()
	var palette_root := String(root_state["path"])
	_collect_scene_paths(palette_root, m_palette_paths)
	m_palette_paths.sort()
	if m_palette_list == null:
		return
	m_palette_list.clear()
	var scene_icon := get_theme_icon(&"PackedScene", &"EditorIcons")
	for path in m_palette_paths:
		var label := path.get_file().get_basename()
		m_palette_list.add_item(label, scene_icon)
		m_palette_list.set_item_tooltip(m_palette_list.get_item_count() - 1, path)


func _collect_scene_paths(path: String, results: PackedStringArray) -> void:
	if results.size() >= MAX_PALETTE_ITEMS:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while !file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path := path.path_join(file_name)
		if dir.current_is_dir():
			if !["addons", "3rdparty", "godot_common", "godot_tilemap", "agent_tools"].has(file_name):
				_collect_scene_paths(child_path, results)
		elif _is_prop_scene_file(file_name):
			results.append(child_path)
		if results.size() >= MAX_PALETTE_ITEMS:
			break
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_prop_scene_file(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	for extension in PROP_SCENE_EXTENSIONS:
		if lower_name.ends_with(extension):
			return true
	return false


func _get_configured_palette_root() -> String:
	if m_palette_root_edit == null:
		return DEFAULT_PROP_PALETTE_ROOT
	var configured := m_palette_root_edit.text.strip_edges()
	if configured.is_empty():
		return DEFAULT_PROP_PALETTE_ROOT
	return configured


func _get_resolved_palette_root() -> Dictionary:
	var configured := _get_configured_palette_root()
	if DirAccess.dir_exists_absolute(configured):
		return {
			"path": configured,
			"warning": "",
		}
	if configured != DEFAULT_PROP_PALETTE_ROOT and !configured.is_empty():
		var fallback := DEFAULT_PROP_PALETTE_ROOT if DirAccess.dir_exists_absolute(DEFAULT_PROP_PALETTE_ROOT) else "res://"
		return {
			"path": fallback,
			"warning": "Palette folder not found: %s." % configured,
		}
	return {
		"path": "res://",
		"warning": "",
	}


func _get_editor_settings() -> EditorSettings:
	if m_editor_interface != null:
		return m_editor_interface.get_editor_settings()
	return EditorInterface.get_editor_settings()


func _load_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	var state_variant: Variant = editor_settings.get_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {})
	if typeof(state_variant) != TYPE_DICTIONARY:
		return

	var state: Dictionary = state_variant
	m_palette_root_edit.text = str(state.get("prop_palette_root", m_palette_root_edit.text))
	m_debug_wireframe_check.button_pressed = bool(
		state.get(
			"debug_wireframe",
			state.get("roof_debug_wireframe", m_debug_wireframe_check.button_pressed)
		)
	)
	m_debug_wireframe_xray_check.button_pressed = bool(
		state.get(
			"debug_wireframe_xray",
			m_debug_wireframe_xray_check.button_pressed
		)
	)
	var wireframe_color_variant: Variant = state.get(
		"debug_wireframe_color",
		m_debug_wireframe_color_picker.color
	)
	if wireframe_color_variant is Color:
		m_debug_wireframe_color_picker.color = wireframe_color_variant
	_update_debug_wireframe_controls()
	_select_wall_type(str(state.get("wall_type", _selected_wall_type())))
	m_room_sides_spin.value = maxf(
		float(state.get("wall_room_sides", m_room_sides_spin.value)),
		3.0
	)
	m_wall_base_height_spin.value = float(state.get("wall_base_height", m_wall_base_height_spin.value))
	_select_floor_type(str(state.get("floor_type", _selected_floor_type())))
	_select_floor_style(str(state.get("floor_style", _selected_floor_style())))
	m_floor_grid_spin.value = float(state.get("floor_grid_step", m_floor_grid_spin.value))
	m_floor_base_height_spin.value = float(state.get("floor_base_height", m_floor_base_height_spin.value))
	m_floor_thickness_spin.value = float(state.get("floor_thickness", m_floor_thickness_spin.value))
	var floor_color_variant: Variant = state.get("floor_color", m_floor_color_picker.color)
	if floor_color_variant is Color:
		m_floor_color_picker.color = floor_color_variant
	m_street_grid_spin.value = float(state.get("street_grid_step", m_street_grid_spin.value))
	m_street_base_height_spin.value = float(state.get("street_base_height", m_street_base_height_spin.value))
	_select_frame_sides(
		m_street_cross_section_option,
		int(state.get("street_cross_section_mode", STREET_CROSS_SECTION_ROAD_AND_FOOTPATH))
	)
	_update_street_cross_section_controls()
	m_street_road_width_spin.value = float(state.get("street_road_width", m_street_road_width_spin.value))
	m_street_road_thickness_spin.value = float(state.get("street_road_thickness", m_street_road_thickness_spin.value))
	m_street_kerb_width_spin.value = float(state.get("street_kerb_width", m_street_kerb_width_spin.value))
	m_street_kerb_height_spin.value = float(state.get("street_kerb_height", m_street_kerb_height_spin.value))
	m_street_footpath_width_spin.value = float(state.get("street_footpath_width", m_street_footpath_width_spin.value))
	m_street_footpath_thickness_spin.value = float(state.get("street_footpath_thickness", m_street_footpath_thickness_spin.value))
	m_street_stair_threshold_spin.value = float(state.get("street_stair_threshold", m_street_stair_threshold_spin.value))
	m_street_target_riser_spin.value = float(state.get("street_target_riser", m_street_target_riser_spin.value))
	m_street_max_riser_spin.value = float(state.get("street_max_riser", m_street_max_riser_spin.value))
	m_street_min_tread_spin.value = float(state.get("street_min_tread", m_street_min_tread_spin.value))
	m_street_sample_spacing_spin.value = float(state.get("street_sample_spacing", m_street_sample_spacing_spin.value))
	m_street_clearance_spin.value = float(state.get("street_terrain_clearance", m_street_clearance_spin.value))
	for color_state: Array in [
		["street_road_color", m_street_road_color_picker],
		["street_kerb_color", m_street_kerb_color_picker],
		["street_footpath_color", m_street_footpath_color_picker],
	]:
		var stored_color: Variant = state.get(String(color_state[0]), (color_state[1] as ColorPickerButton).color)
		if stored_color is Color:
			(color_state[1] as ColorPickerButton).color = stored_color
	m_stair_grid_spin.value = float(state.get("stair_grid_step", m_stair_grid_spin.value))
	m_stair_base_height_spin.value = float(state.get("stair_base_height", m_stair_base_height_spin.value))
	m_stair_height_spin.value = float(state.get("stair_height", m_stair_height_spin.value))
	m_stair_step_count_spin.value = float(state.get("stair_step_count", m_stair_step_count_spin.value))
	m_stair_thickness_spin.value = float(state.get("stair_thickness", m_stair_thickness_spin.value))
	m_stair_tread_style_option.select(clampi(
		int(state.get(
			"stair_tread_style",
			_selected_option_metadata(m_stair_tread_style_option, TREAD_STYLE_CLOSED)
		)),
		0,
		m_stair_tread_style_option.get_item_count() - 1
	))
	m_stair_nosing_spin.value = float(
		state.get("stair_nosing_depth", m_stair_nosing_spin.value)
	)
	_update_stair_tread_controls()
	m_stair_rotation_spin.value = float(state.get("stair_rotation_degrees", m_stair_rotation_spin.value))
	var stair_color_variant: Variant = state.get("stair_color", m_stair_color_picker.color)
	if stair_color_variant is Color:
		m_stair_color_picker.color = stair_color_variant
	_select_stair_layout_script(
		state.get(
			"stair_layout_script",
			_selected_stair_layout_script()
		)
	)
	m_stair_turn_option.select(clampi(
		int(state.get("stair_turn_direction", _selected_option_metadata(m_stair_turn_option, 1))),
		0,
		m_stair_turn_option.get_item_count() - 1
	))
	m_stair_winder_turn_option.select(clampi(
		int(state.get(
			"stair_winder_turn",
			_selected_option_metadata(m_stair_winder_turn_option, 0)
		)),
		0,
		m_stair_winder_turn_option.get_item_count() - 1
	))
	m_stair_spiral_turn_spin.value = float(
		state.get("stair_spiral_turn_degrees", m_stair_spiral_turn_spin.value)
	)
	m_stair_flight_width_spin.value = float(
		state.get("stair_flight_width", m_stair_flight_width_spin.value)
	)
	_update_stair_layout_controls()
	m_stair_left_rail_check.button_pressed = bool(
		state.get("stair_left_rail_enabled", m_stair_left_rail_check.button_pressed)
	)
	m_stair_right_rail_check.button_pressed = bool(
		state.get("stair_right_rail_enabled", m_stair_right_rail_check.button_pressed)
	)
	_select_rail_style(
		m_stair_rail_style_option,
		int(state.get(
			"stair_infill_style",
			state.get(
				"stair_rail_style",
				_selected_rail_style(m_stair_rail_style_option)
			)
		))
	)
	m_stair_lower_newel_check.button_pressed = bool(
		state.get("stair_lower_newel_enabled", m_stair_lower_newel_check.button_pressed)
	)
	_select_newel_placement(
		m_stair_lower_newel_position_option,
		int(state.get(
			"stair_lower_newel_placement",
			_selected_newel_placement(m_stair_lower_newel_position_option)
		))
	)
	m_stair_upper_newel_check.button_pressed = bool(
		state.get("stair_upper_newel_enabled", m_stair_upper_newel_check.button_pressed)
	)
	_select_newel_placement(
		m_stair_upper_newel_position_option,
		int(state.get(
			"stair_upper_newel_placement",
			_selected_newel_placement(m_stair_upper_newel_position_option)
		))
	)
	m_stair_middle_newel_count_spin.value = float(
		state.get(
			"stair_middle_newel_post_count",
			m_stair_middle_newel_count_spin.value
		)
	)
	m_stair_infill_count_spin.value = float(
		state.get(
			"stair_infill_count_between_newels",
			state.get(
				"stair_baluster_count_between_newels",
				m_stair_infill_count_spin.value
			)
		)
	)
	m_stair_newel_size_spin.value = float(
		state.get("stair_rail_newel_post_thickness", m_stair_newel_size_spin.value)
	)
	_update_stair_newel_controls()
	m_stair_rail_margin_spin.value = float(
		state.get("stair_rail_edge_margin", m_stair_rail_margin_spin.value)
	)
	m_rail_grid_spin.value = float(state.get("rail_grid_step", m_rail_grid_spin.value))
	m_rail_base_height_spin.value = float(state.get("rail_base_height", m_rail_base_height_spin.value))
	m_rail_height_spin.value = float(state.get("rail_height", m_rail_height_spin.value))
	m_rail_post_spacing_spin.value = float(state.get("rail_post_spacing", m_rail_post_spacing_spin.value))
	m_rail_post_thickness_spin.value = float(
		state.get(
			"infill_rail_thickness",
			state.get("rail_post_thickness", m_rail_post_thickness_spin.value)
		)
	)
	m_rail_bar_thickness_spin.value = float(state.get("rail_thickness", m_rail_bar_thickness_spin.value))
	_select_rail_style(
		m_rail_style_option,
		int(state.get(
			"infill_style",
			state.get("rail_style", _selected_rail_style(m_rail_style_option))
		))
	)
	m_rail_newel_count_spin.value = float(
		state.get("rail_newel_post_count", m_rail_newel_count_spin.value)
	)
	m_rail_infill_count_spin.value = float(
		state.get(
			"rail_infill_count_between_newels",
			state.get(
				"rail_baluster_count_between_newels",
				m_rail_infill_count_spin.value
			)
		)
	)
	m_rail_newel_size_spin.value = float(
		state.get("rail_newel_post_thickness", m_rail_newel_size_spin.value)
	)
	m_rail_lower_height_spin.value = float(state.get("rail_lower_height", m_rail_lower_height_spin.value))
	var rail_color_variant: Variant = state.get("rail_color", m_rail_color_picker.color)
	if rail_color_variant is Color:
		m_rail_color_picker.color = rail_color_variant
	m_pillar_grid_spin.value = float(state.get("pillar_grid_step", m_pillar_grid_spin.value))
	_select_pillar_style(str(state.get("pillar_style", _selected_pillar_style())))
	m_pillar_base_height_spin.value = float(state.get("pillar_base_height", m_pillar_base_height_spin.value))
	m_pillar_radius_spin.value = float(state.get("pillar_radius", m_pillar_radius_spin.value))
	m_pillar_upper_radius_spin.value = float(state.get("pillar_upper_radius", m_pillar_upper_radius_spin.value))
	m_pillar_height_spin.value = float(state.get("pillar_height", m_pillar_height_spin.value))
	m_pillar_sides_spin.value = float(state.get("pillar_sides", m_pillar_sides_spin.value))
	m_pillar_lower_rim_height_spin.value = float(state.get("pillar_lower_rim_height", m_pillar_lower_rim_height_spin.value))
	m_pillar_lower_rim_outset_spin.value = float(state.get("pillar_lower_rim_outset", m_pillar_lower_rim_outset_spin.value))
	m_pillar_upper_rim_height_spin.value = float(state.get("pillar_upper_rim_height", m_pillar_upper_rim_height_spin.value))
	m_pillar_upper_rim_outset_spin.value = float(state.get("pillar_upper_rim_outset", m_pillar_upper_rim_outset_spin.value))
	var pillar_color_variant: Variant = state.get("pillar_color", m_pillar_color_picker.color)
	if pillar_color_variant is Color:
		m_pillar_color_picker.color = pillar_color_variant
	m_roof_grid_spin.value = float(state.get("roof_grid_step", m_roof_grid_spin.value))
	_select_roof_style(str(state.get("roof_style", _selected_roof_style())))
	_select_roof_footprint_style(
		str(state.get("roof_footprint_style", _selected_roof_footprint_style()))
	)
	m_roof_base_height_spin.value = float(state.get("roof_base_height", m_roof_base_height_spin.value))
	m_roof_height_spin.value = _stored_roof_angle_degrees(state)
	m_roof_thickness_spin.value = float(state.get("roof_thickness", m_roof_thickness_spin.value))
	m_roof_overhang_spin.value = float(state.get("roof_overhang", m_roof_overhang_spin.value))
	m_roof_hip_gable_height_spin.value = float(
		state.get("roof_hip_gable_height", m_roof_hip_gable_height_spin.value)
	)
	_select_roof_hip_shape(int(state.get("roof_hip_shape", _selected_roof_hip_shape())))
	m_roof_rotation_spin.value = float(state.get("roof_rotation_degrees", m_roof_rotation_spin.value))
	if m_transform_snap_spin != null:
		m_transform_snap_spin.value = float(
			state.get("transform_snap_step", m_transform_snap_spin.value)
		)
	var roof_color_variant: Variant = state.get("roof_color", m_roof_color_picker.color)
	if roof_color_variant is Color:
		m_roof_color_picker.color = roof_color_variant
	var window_style := str(state.get("window_style", _selected_window_style()))
	_select_window_style(window_style)
	m_window_width_spin.value = float(state.get("window_width", _window_default_width(window_style)))
	m_window_height_spin.value = float(state.get("window_height", m_window_height_spin.value))
	m_window_frame_spin.value = float(state.get("window_frame_thickness", m_window_frame_spin.value))
	m_window_frame_protrusion_spin.value = float(
		state.get("window_frame_protrusion", m_window_frame_protrusion_spin.value)
	)
	var window_frame_color_variant: Variant = state.get("window_frame_color", m_window_frame_color_picker.color)
	if window_frame_color_variant is Color:
		m_window_frame_color_picker.color = window_frame_color_variant
	m_window_sill_spin.value = float(state.get("window_sill_height", m_window_sill_spin.value))
	_select_frame_sides(m_window_frame_sides_option, int(state.get("window_frame_sides", _selected_frame_sides(m_window_frame_sides_option))))
	m_window_pane_depth_spin.value = float(state.get("window_pane_depth", m_window_pane_depth_spin.value))
	var window_pane_color_variant: Variant = state.get("window_pane_color", m_window_pane_color_picker.color)
	if window_pane_color_variant is Color:
		m_window_pane_color_picker.color = window_pane_color_variant
	m_window_grid_rows_spin.value = float(state.get("window_pane_grid_rows", m_window_grid_rows_spin.value))
	m_window_grid_cols_spin.value = float(state.get("window_pane_grid_cols", m_window_grid_cols_spin.value))
	m_window_muntin_thickness_spin.value = float(
		state.get("window_muntin_thickness", m_window_muntin_thickness_spin.value)
	)
	m_window_louver_count_spin.value = float(state.get("window_louver_count", m_window_louver_count_spin.value))
	m_window_louver_depth_spin.value = float(state.get("window_louver_depth", m_window_louver_depth_spin.value))
	m_window_transom_ratio_spin.value = float(state.get("window_transom_ratio", m_window_transom_ratio_spin.value))
	m_window_transom_rail_spin.value = float(state.get("window_transom_rail", m_window_transom_rail_spin.value))
	m_window_arch_steps_spin.value = float(state.get("window_arch_steps", m_window_arch_steps_spin.value))
	var door_style := str(state.get("door_style", _selected_door_style()))
	_select_door_style(door_style)
	m_door_width_spin.value = float(state.get("door_width", _door_default_width(door_style)))
	m_door_height_spin.value = float(state.get("door_height", m_door_height_spin.value))
	m_door_frame_spin.value = float(state.get("door_frame_thickness", m_door_frame_spin.value))
	m_door_frame_protrusion_spin.value = float(
		state.get("door_frame_protrusion", m_door_frame_protrusion_spin.value)
	)
	var door_frame_color_variant: Variant = state.get("door_frame_color", m_door_frame_color_picker.color)
	if door_frame_color_variant is Color:
		m_door_frame_color_picker.color = door_frame_color_variant
	_select_frame_sides(m_door_frame_sides_option, int(state.get("door_frame_sides", _selected_frame_sides(m_door_frame_sides_option))))
	m_door_panel_depth_spin.value = float(state.get("door_panel_depth", m_door_panel_depth_spin.value))
	var door_panel_color_variant: Variant = state.get("door_panel_color", m_door_panel_color_picker.color)
	if door_panel_color_variant is Color:
		m_door_panel_color_picker.color = door_panel_color_variant
	m_door_glazing_ratio_spin.value = float(state.get("door_glazing_ratio", m_door_glazing_ratio_spin.value))
	m_door_glass_depth_spin.value = float(state.get("door_glass_depth", m_door_glass_depth_spin.value))
	var door_glass_color_variant: Variant = state.get("door_glass_color", m_door_glass_color_picker.color)
	if door_glass_color_variant is Color:
		m_door_glass_color_picker.color = door_glass_color_variant
	m_door_grid_rows_spin.value = float(state.get("door_pane_grid_rows", m_door_grid_rows_spin.value))
	m_door_grid_cols_spin.value = float(state.get("door_pane_grid_cols", m_door_grid_cols_spin.value))
	m_door_muntin_thickness_spin.value = float(
		state.get("door_muntin_thickness", m_door_muntin_thickness_spin.value)
	)
	m_door_inset_rows_spin.value = float(state.get("door_inset_rows", m_door_inset_rows_spin.value))
	m_door_inset_cols_spin.value = float(state.get("door_inset_cols", m_door_inset_cols_spin.value))
	_update_window_style_controls()
	_update_door_style_controls()
	_refresh_color_picker_icons()


func _stored_roof_angle_degrees(state: Dictionary) -> float:
	if state.has("roof_angle_degrees"):
		return float(state["roof_angle_degrees"])
	var legacy_value := float(state.get("roof_height", m_roof_height_spin.value))
	if legacy_value > 0.0 and legacy_value <= LEGACY_ROOF_VALUE_MAX:
		return rad_to_deg(atan(legacy_value))
	return legacy_value


func _save_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	editor_settings.set_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {
		"prop_palette_root": _get_configured_palette_root(),
		"debug_wireframe": (
			m_debug_wireframe_check.button_pressed
			if m_debug_wireframe_check != null
			else false
		),
		"debug_wireframe_xray": (
			m_debug_wireframe_xray_check.button_pressed
			if m_debug_wireframe_xray_check != null
			else false
		),
		"debug_wireframe_color": (
			m_debug_wireframe_color_picker.color
			if m_debug_wireframe_color_picker != null
			else Color(0.05, 0.95, 1.0, 1.0)
		),
		"wall_type": _selected_wall_type(),
		"wall_room_sides": (
			maxi(int(roundf(m_room_sides_spin.value)), 3)
			if m_room_sides_spin != null
			else 4
		),
		"wall_base_height": float(m_wall_base_height_spin.value) if m_wall_base_height_spin != null else 0.0,
		"floor_type": _selected_floor_type(),
		"floor_style": _selected_floor_style(),
		"floor_grid_step": float(m_floor_grid_spin.value) if m_floor_grid_spin != null else 0.5,
		"floor_base_height": float(m_floor_base_height_spin.value) if m_floor_base_height_spin != null else 0.0,
		"floor_thickness": float(m_floor_thickness_spin.value) if m_floor_thickness_spin != null else 0.12,
		"floor_color": m_floor_color_picker.color if m_floor_color_picker != null else Color(0.46, 0.40, 0.32, 1.0),
		"street_grid_step": float(m_street_grid_spin.value) if m_street_grid_spin != null else 0.5,
		"street_base_height": float(m_street_base_height_spin.value) if m_street_base_height_spin != null else 0.0,
		"street_cross_section_mode": _selected_option_metadata(
			m_street_cross_section_option, STREET_CROSS_SECTION_ROAD_AND_FOOTPATH
		),
		"street_road_width": float(m_street_road_width_spin.value) if m_street_road_width_spin != null else 3.2,
		"street_road_thickness": float(m_street_road_thickness_spin.value) if m_street_road_thickness_spin != null else 0.18,
		"street_road_color": m_street_road_color_picker.color if m_street_road_color_picker != null else Color(0.38, 0.37, 0.34, 1.0),
		"street_kerb_width": float(m_street_kerb_width_spin.value) if m_street_kerb_width_spin != null else 0.18,
		"street_kerb_height": float(m_street_kerb_height_spin.value) if m_street_kerb_height_spin != null else 0.14,
		"street_kerb_color": m_street_kerb_color_picker.color if m_street_kerb_color_picker != null else Color(0.66, 0.64, 0.59, 1.0),
		"street_footpath_width": float(m_street_footpath_width_spin.value) if m_street_footpath_width_spin != null else 1.1,
		"street_footpath_thickness": float(m_street_footpath_thickness_spin.value) if m_street_footpath_thickness_spin != null else 0.16,
		"street_footpath_color": m_street_footpath_color_picker.color if m_street_footpath_color_picker != null else Color(0.72, 0.67, 0.57, 1.0),
		"street_stair_threshold": float(m_street_stair_threshold_spin.value) if m_street_stair_threshold_spin != null else 25.0,
		"street_target_riser": float(m_street_target_riser_spin.value) if m_street_target_riser_spin != null else 0.16,
		"street_max_riser": float(m_street_max_riser_spin.value) if m_street_max_riser_spin != null else 0.18,
		"street_min_tread": float(m_street_min_tread_spin.value) if m_street_min_tread_spin != null else 0.24,
		"street_sample_spacing": float(m_street_sample_spacing_spin.value) if m_street_sample_spacing_spin != null else 0.5,
		"street_terrain_clearance": float(m_street_clearance_spin.value) if m_street_clearance_spin != null else 0.025,
		"stair_grid_step": float(m_stair_grid_spin.value) if m_stair_grid_spin != null else 0.5,
		"stair_base_height": float(m_stair_base_height_spin.value) if m_stair_base_height_spin != null else 0.0,
		"stair_height": float(m_stair_height_spin.value) if m_stair_height_spin != null else 1.2,
		"stair_step_count": int(roundf(m_stair_step_count_spin.value)) if m_stair_step_count_spin != null else 6,
		"stair_thickness": float(m_stair_thickness_spin.value) if m_stair_thickness_spin != null else 0.12,
		"stair_tread_style": _selected_option_metadata(
			m_stair_tread_style_option, TREAD_STYLE_CLOSED
		),
		"stair_nosing_depth": (
			float(m_stair_nosing_spin.value)
			if m_stair_nosing_spin != null
			else 0.08
		),
		"stair_rotation_degrees": float(m_stair_rotation_spin.value) if m_stair_rotation_spin != null else 0.0,
		"stair_color": m_stair_color_picker.color if m_stair_color_picker != null else Color(0.52, 0.46, 0.38, 1.0),
		"stair_layout_script": _selected_stair_layout_script().resource_path,
		"stair_turn_direction": _selected_option_metadata(m_stair_turn_option, 1),
		"stair_winder_turn": _selected_option_metadata(m_stair_winder_turn_option, 0),
		"stair_spiral_turn_degrees": (
			float(m_stair_spiral_turn_spin.value)
			if m_stair_spiral_turn_spin != null
			else 360.0
		),
		"stair_flight_width": (
			float(m_stair_flight_width_spin.value)
			if m_stair_flight_width_spin != null
			else 1.2
		),
		"stair_left_rail_enabled": (
			m_stair_left_rail_check.button_pressed if m_stair_left_rail_check != null else false
		),
		"stair_right_rail_enabled": (
			m_stair_right_rail_check.button_pressed if m_stair_right_rail_check != null else false
		),
		"stair_infill_style": _selected_rail_style(m_stair_rail_style_option),
		"stair_lower_newel_enabled": (
			m_stair_lower_newel_check.button_pressed
			if m_stair_lower_newel_check != null
			else false
		),
		"stair_lower_newel_placement": _selected_newel_placement(
			m_stair_lower_newel_position_option
		),
		"stair_upper_newel_enabled": (
			m_stair_upper_newel_check.button_pressed
			if m_stair_upper_newel_check != null
			else false
		),
		"stair_upper_newel_placement": _selected_newel_placement(
			m_stair_upper_newel_position_option
		),
		"stair_middle_newel_post_count": (
			int(roundf(m_stair_middle_newel_count_spin.value))
			if m_stair_middle_newel_count_spin != null
			else 0
		),
		"stair_infill_count_between_newels": (
			int(roundf(m_stair_infill_count_spin.value))
			if m_stair_infill_count_spin != null
			else 1
		),
		"stair_rail_newel_post_thickness": (
			float(m_stair_newel_size_spin.value)
			if m_stair_newel_size_spin != null
			else 0.1
		),
		"stair_rail_edge_margin": (
			float(m_stair_rail_margin_spin.value) if m_stair_rail_margin_spin != null else 0.15
		),
		"rail_grid_step": float(m_rail_grid_spin.value) if m_rail_grid_spin != null else 0.5,
		"rail_base_height": float(m_rail_base_height_spin.value) if m_rail_base_height_spin != null else 0.0,
		"rail_height": float(m_rail_height_spin.value) if m_rail_height_spin != null else 1.0,
		"rail_post_spacing": float(m_rail_post_spacing_spin.value) if m_rail_post_spacing_spin != null else 1.0,
		"infill_rail_thickness": float(m_rail_post_thickness_spin.value) if m_rail_post_thickness_spin != null else 0.08,
		"rail_thickness": float(m_rail_bar_thickness_spin.value) if m_rail_bar_thickness_spin != null else 0.1,
		"infill_style": _selected_rail_style(m_rail_style_option),
		"rail_newel_post_count": int(roundf(m_rail_newel_count_spin.value)) if m_rail_newel_count_spin != null else 2,
		"rail_infill_count_between_newels": int(roundf(m_rail_infill_count_spin.value)) if m_rail_infill_count_spin != null else 1,
		"rail_newel_post_thickness": float(m_rail_newel_size_spin.value) if m_rail_newel_size_spin != null else 0.1,
		"rail_lower_height": float(m_rail_lower_height_spin.value) if m_rail_lower_height_spin != null else 0.18,
		"rail_color": m_rail_color_picker.color if m_rail_color_picker != null else Color(0.33, 0.28, 0.22, 1.0),
		"pillar_grid_step": float(m_pillar_grid_spin.value) if m_pillar_grid_spin != null else 0.5,
		"pillar_style": _selected_pillar_style(),
		"pillar_base_height": float(m_pillar_base_height_spin.value) if m_pillar_base_height_spin != null else 0.0,
		"pillar_radius": float(m_pillar_radius_spin.value) if m_pillar_radius_spin != null else 0.25,
		"pillar_upper_radius": float(m_pillar_upper_radius_spin.value) if m_pillar_upper_radius_spin != null else 0.0,
		"pillar_height": float(m_pillar_height_spin.value) if m_pillar_height_spin != null else 2.4,
		"pillar_sides": int(roundf(m_pillar_sides_spin.value)) if m_pillar_sides_spin != null else 8,
		"pillar_lower_rim_height": float(m_pillar_lower_rim_height_spin.value) if m_pillar_lower_rim_height_spin != null else 0.12,
		"pillar_lower_rim_outset": float(m_pillar_lower_rim_outset_spin.value) if m_pillar_lower_rim_outset_spin != null else 0.05,
		"pillar_upper_rim_height": float(m_pillar_upper_rim_height_spin.value) if m_pillar_upper_rim_height_spin != null else 0.12,
		"pillar_upper_rim_outset": float(m_pillar_upper_rim_outset_spin.value) if m_pillar_upper_rim_outset_spin != null else 0.05,
		"pillar_color": m_pillar_color_picker.color if m_pillar_color_picker != null else Color(0.70, 0.64, 0.52, 1.0),
		"roof_grid_step": float(m_roof_grid_spin.value) if m_roof_grid_spin != null else 0.5,
		"roof_style": _selected_roof_style(),
		"roof_footprint_style": _selected_roof_footprint_style(),
		"roof_base_height": float(m_roof_base_height_spin.value) if m_roof_base_height_spin != null else 2.4,
		"roof_angle_degrees": float(m_roof_height_spin.value) if m_roof_height_spin != null else DEFAULT_ROOF_ANGLE_DEGREES,
		"roof_height": float(m_roof_height_spin.value) if m_roof_height_spin != null else DEFAULT_ROOF_ANGLE_DEGREES,
		"roof_thickness": float(m_roof_thickness_spin.value) if m_roof_thickness_spin != null else 0.12,
		"roof_overhang": float(m_roof_overhang_spin.value) if m_roof_overhang_spin != null else 0.2,
		"roof_hip_gable_height": float(m_roof_hip_gable_height_spin.value) if m_roof_hip_gable_height_spin != null else 0.0,
		"roof_hip_shape": _selected_roof_hip_shape() if m_roof_hip_shape_option != null else 0,
		"roof_rotation_degrees": float(m_roof_rotation_spin.value) if m_roof_rotation_spin != null else 0.0,
		"transform_snap_step": float(m_transform_snap_spin.value) if m_transform_snap_spin != null else 0.5,
		"roof_color": m_roof_color_picker.color if m_roof_color_picker != null else Color(0.50, 0.34, 0.25, 1.0),
		"window_style": _selected_window_style(),
		"window_width": float(m_window_width_spin.value) if m_window_width_spin != null else 1.0,
		"window_height": float(m_window_height_spin.value) if m_window_height_spin != null else 1.0,
		"window_frame_thickness": float(m_window_frame_spin.value) if m_window_frame_spin != null else 0.08,
		"window_frame_protrusion": float(m_window_frame_protrusion_spin.value) if m_window_frame_protrusion_spin != null else 0.02,
		"window_frame_color": m_window_frame_color_picker.color if m_window_frame_color_picker != null else Color(0.86, 0.92, 0.94, 1.0),
		"window_sill_height": float(m_window_sill_spin.value) if m_window_sill_spin != null else 0.9,
		"window_frame_sides": _selected_frame_sides(m_window_frame_sides_option),
		"window_pane_depth": float(m_window_pane_depth_spin.value) if m_window_pane_depth_spin != null else 0.03,
		"window_pane_color": m_window_pane_color_picker.color if m_window_pane_color_picker != null else Color(0.58, 0.82, 0.95, 0.52),
		"window_pane_grid_rows": int(roundf(m_window_grid_rows_spin.value)) if m_window_grid_rows_spin != null else 2,
		"window_pane_grid_cols": int(roundf(m_window_grid_cols_spin.value)) if m_window_grid_cols_spin != null else 1,
		"window_muntin_thickness": float(m_window_muntin_thickness_spin.value) if m_window_muntin_thickness_spin != null else 0.03,
		"window_louver_count": int(roundf(m_window_louver_count_spin.value)) if m_window_louver_count_spin != null else 6,
		"window_louver_depth": float(m_window_louver_depth_spin.value) if m_window_louver_depth_spin != null else 0.03,
		"window_transom_ratio": float(m_window_transom_ratio_spin.value) if m_window_transom_ratio_spin != null else 0.28,
		"window_transom_rail": float(m_window_transom_rail_spin.value) if m_window_transom_rail_spin != null else 0.03,
		"window_arch_steps": int(roundf(m_window_arch_steps_spin.value)) if m_window_arch_steps_spin != null else 3,
		"door_style": _selected_door_style(),
		"door_width": float(m_door_width_spin.value) if m_door_width_spin != null else 0.9,
		"door_height": float(m_door_height_spin.value) if m_door_height_spin != null else 2.1,
		"door_frame_thickness": float(m_door_frame_spin.value) if m_door_frame_spin != null else 0.08,
		"door_frame_protrusion": float(m_door_frame_protrusion_spin.value) if m_door_frame_protrusion_spin != null else 0.02,
		"door_frame_color": m_door_frame_color_picker.color if m_door_frame_color_picker != null else Color(0.86, 0.92, 0.94, 1.0),
		"door_frame_sides": _selected_frame_sides(m_door_frame_sides_option),
		"door_panel_depth": float(m_door_panel_depth_spin.value) if m_door_panel_depth_spin != null else 0.05,
		"door_panel_color": m_door_panel_color_picker.color if m_door_panel_color_picker != null else Color(0.50, 0.34, 0.20, 1.0),
		"door_glazing_ratio": float(m_door_glazing_ratio_spin.value) if m_door_glazing_ratio_spin != null else 0.55,
		"door_glass_depth": float(m_door_glass_depth_spin.value) if m_door_glass_depth_spin != null else 0.03,
		"door_glass_color": m_door_glass_color_picker.color if m_door_glass_color_picker != null else Color(0.58, 0.82, 0.95, 0.52),
		"door_pane_grid_rows": int(roundf(m_door_grid_rows_spin.value)) if m_door_grid_rows_spin != null else 2,
		"door_pane_grid_cols": int(roundf(m_door_grid_cols_spin.value)) if m_door_grid_cols_spin != null else 1,
		"door_muntin_thickness": float(m_door_muntin_thickness_spin.value) if m_door_muntin_thickness_spin != null else 0.03,
		"door_inset_rows": int(roundf(m_door_inset_rows_spin.value)) if m_door_inset_rows_spin != null else 3,
		"door_inset_cols": int(roundf(m_door_inset_cols_spin.value)) if m_door_inset_cols_spin != null else 2,
	})
