@tool
extends RefCounted

## Abstract base for per-tool editor controllers — stage 3+ of the plugin
## split (see `../docs/plugin_split_plan.md`). A concrete controller owns its
## tool's dock settings, preview, hover highlight, and drag state, and
## receives viewport input while its mode is active. Controllers are
## plugin-lifetime objects created in `_enter_tree`, so undo/redo actions may
## bind controller or context methods. Internal and path-extended; not an
## editor-creatable type.

const BuildingToolContextScript = preload("res://addons/low_poly_building_editor/editor/building_tool_context.gd")

## Screen-space distance (pixels) a draw gesture must travel before releasing
## the mouse commits the preview.
const DRAG_COMMIT_DISTANCE := 6.0

## Rectangle-footprint edit-mask bits shared by the floor/stairs/roof pick
## helpers.
const FLOOR_EDIT_MOVE := 0
const FLOOR_EDIT_MIN_X := 1
const FLOOR_EDIT_MAX_X := 2
const FLOOR_EDIT_MIN_Z := 4
const FLOOR_EDIT_MAX_Z := 8
const FLOOR_EDIT_POLYGON_VERTEX := 16
const FLOOR_EDIT_POLYGON_EDGE := 32

## Footprint creation styles shared by the floor and roof tools.
const FLOOR_STYLE_RECTANGLE := "rectangle"
const FLOOR_STYLE_POLYGON := "polygon"

var m_context: BuildingToolContextScript


func _init(context: BuildingToolContextScript) -> void:
	m_context = context


## Viewport input while this controller's mode is active (both the direct
## `_forward_3d_gui_input` path and the viewport-overlay path). Returns an
## `EditorPlugin.AFTER_GUI_INPUT_*` value.
func handle_input(_camera: Camera3D, _event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## New tool defaults pushed from the dock's `<tool>_settings_changed` signal.
func apply_settings(_settings: Dictionary) -> void:
	pass


## Cancels any in-progress draw preview, hover highlight, and drag, restoring
## authored state. Called on Escape/right-click, on tool-mode changes, and on
## plugin exit; must be safe to call at any time.
func cancel_preview() -> void:
	pass


## Shared angle helpers.
static func normalize_degrees(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


static func angles_match(first: float, second: float) -> bool:
	return absf(angle_difference(deg_to_rad(first), deg_to_rad(second))) <= deg_to_rad(0.5)
