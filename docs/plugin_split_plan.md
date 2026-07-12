# Plugin Split Plan: Tool Controllers for `plugin.gd`

Status: all seven stages implemented and post-reviewed; pending final editor
validation. Delete this file (or fold the durable parts into
[`contract.md`](contract.md) and [`feature.md`](feature.md)) once that
validation passes.

## As-Built Summary

- `plugin.gd` is 520 lines / 49 functions / 13 member variables (from
  9,268 / 441 / 173); the largest controller is roof at 1,836 lines. All
  size targets met.
- Tool keys (stairs/roof R-rotation, floor/roof polygon Enter-close, prop R)
  live in their controllers' `handle_input`; the plugin key section keeps
  only Escape, and right-click cancel stays global.
- The shipped controller API is `handle_input`, `apply_settings`, and
  `cancel_preview` (the sketched `enter_tool`/`exit_tool`/
  `handle_overlay_input` were never needed — overlay input funnels through
  `_forward_3d_gui_input`). The placement controller deviates with
  `apply_prop_settings`/`apply_window_settings`/`apply_door_settings`
  because it owns three dock sections under one instance registered for the
  window, door, and prop modes.
- The shared wall-query helpers (`raycast_walls`, `intersect_wall_box`,
  `find_wall_from_collider`, `refresh_wall_intersections`,
  `can_place_wall_opening`) and `m_preview_parent` moved into the context;
  prop/opening snapping follows the wall grid through
  `BuildingToolContext.default_grid_step()`, backed by a grid-step cache on
  the plugin (`m_wall_grid_step`).
- Remaining transitional context callbacks: `_apply_debug_wireframe_to_node`
  (display cluster) and `_refresh_dock_context` (dock wiring). Both are
  documented in the context header.

## Post-Split Review Findings (fixed)

- **Multiline undo-bind bug.** Six `add_do_method`/`add_undo_method` calls in
  the roof and wall controllers were formatted across multiple lines, so the
  extraction's single-line substitution table left them binding retired
  plugin method names on `self` (broken undo for polygon-flat-roof creation,
  roof creation, and two wall commit paths). Fixed and re-verified with a
  multiline-aware sweep across every controller: all binds now resolve on
  their targets. Lesson for any future mechanical extraction: match and
  verify call-site patterns with `re.S`, never line-anchored regexes.
- Dead `OPENING_*_META` alias constants removed from `plugin.gd` (their
  self-referential definitions defeated the naive unused-const counter).

## Why

`plugin.gd` currently owns every editor concern at once: plugin lifecycle, dock
wiring, native-toolbar integration, icon drawing, selection sync, undo helpers,
coordinator resolution, and the complete draw/preview/drag/commit state machine
for all nine tool modes. Every tool change risks unrelated tools, and the file
is too large to review or navigate confidently.

## Measured Inventory

Function clusters by name affinity (approximate body lines, measured):

| Cluster                          | Funcs | Lines | Notes |
| -------------------------------- | ----- | ----- | ----- |
| roof                             | 72    | 1771  | rect + polygon modes, rotation key, covers refresh |
| floor                            | 64    | 1531  | rect + polygon modes, hole editing |
| wall                             | 68    | 1401  | joints, rooms, merge, opening anchors, geometry undo helpers |
| stairs                           | 42    | 743   | rotation key, layout/rail settings |
| lifecycle/dispatch/selection     | 45    | 727   | stays in `plugin.gd` |
| native toolbar + icons           | 49    | 697   | self-contained editor-UI shim |
| pillar                           | 30    | 537   | simplest full tool |
| rail                             | 23    | 490   | |
| window/door/prop placement       | 24    | 555   | one shared placement path |
| shared helpers                   | 15    | 198   | snapping, raycast, preview material, status |
| coordinator resolution           | 9     | 95    | find/create `Building3D` targets |

Existing seams the split can lean on (all verified in the current file):

- `_forward_3d_gui_input()` already dispatches exactly one
  `_handle_<tool>_input(camera, event)` per mode constant.
- Member state is already partitioned per tool: `m_<tool>_settings`,
  `m_<tool>_preview`, `m_drag_<tool>_*`, `m_is_drawing_<tool>`,
  `m_reset_<tool>_drag_state()` families do not cross tools.
- The dock emits one `<tool>_settings_changed` signal per tool; handlers are
  one-per-tool already.
- Cross-tool touch points are few and explicit: `_cancel_active_preview()`
  (fans out to every tool's clear), `_clear_*_preview()`/`_clear_*_hover()`
  fan-outs on mode change, and the shared helpers listed above.

## Target Layout

New `editor/` folder inside the plugin:

```
editor/
  building_tool_context.gd        # RefCounted service facade (stage 1)
  building_tool_controller.gd     # abstract controller base (stage 3)
  wall_tool_controller.gd
  floor_tool_controller.gd
  stairs_tool_controller.gd
  rail_tool_controller.gd
  pillar_tool_controller.gd
  roof_tool_controller.gd
  placement_tool_controller.gd    # window + door + prop
  native_toolbar_integration.gd   # + icon drawing (stage 2)
```

`plugin.gd` keeps: `_enter_tree`/`_exit_tree`, dock creation and signal wiring,
`_handles`/`_forward_3d_gui_input` dispatch, tool-mode state + toolbar sync,
editor-selection sync, viewport overlay/capture ownership, and scene-change
handling. Target size after the split: under 1,000 lines; no controller over
2,000.

### Controller interface (sketch)

```gdscript
# building_tool_controller.gd
class_name-free, path-extended, internal (matches the style-pattern rule
that internal layers are not global types).

var m_context: BuildingToolContext

func enter_tool() -> void            # activate: build preview scaffolding
func exit_tool() -> void             # deactivate: clear previews/hover/drag
func handle_input(camera, event) -> int
func handle_overlay_input(overlay, camera, event) -> int
func apply_settings(settings: Dictionary) -> void
func cancel_preview() -> void
```

`_forward_3d_gui_input` becomes: shared key handling (Escape/right-click
cancel), then `return m_active_controller.handle_input(camera, event)` via a
`{mode: controller}` dictionary. Dock signal handlers become
`m_controllers[MODE_X].apply_settings(settings)`.

### Context interface (sketch)

`BuildingToolContext` (RefCounted, created once in `_enter_tree`, holds a weak
reference to the plugin) exposes what tools currently reach into the plugin
for:

- undo access: `undo_redo()` returning `EditorUndoRedoManager`
- coordinator resolution: `get_or_create_coordinator()`, `find_selected_coordinator()`, `active_coordinator()`
- snapping/raycast: `snap_world_position()`, `raycast_world()`, `intersect_aabb_ray()`, `closest_point_on_plan_segment()`
- preview plumbing: `set_preview_parent()`, `apply_preview_material()`, `build_preview_material()`
- UI feedback: `set_status()`, `handled()`
- node lifecycle used inside undo actions: `do_add_node*()`, `undo_remove_node*()`, `set_owner_recursive()`, `select_node()`

## Shared-State Disposition

- Move with each tool: `m_<tool>_settings`, `m_<tool>_preview`,
  `m_<tool>_start/end_local`, `m_is_drawing_<tool>`, all `m_drag_<tool>_*`,
  hover materials/markers, rotation-degree state.
- Move to placement controller: `m_prop_*`, `m_window_settings`,
  `m_door_settings`, `m_drag_opening_*`, `m_drag_hover_opening`,
  `m_drag_face_sign`, `m_drag_target_segment`.
- Move to native-toolbar module: `m_native_*`, `m_viewport_toolbar`,
  `m_toolbar_buttons`, `m_toolbar_icon_cache`, `m_toolbar_icon_size`,
  `m_handling_native_click` (the module owns the whole toolbar it builds).
- Stay on plugin: `m_tool_mode`, `m_dock`, `m_editor_dock`,
  `m_viewport_overlays`, `m_input_capture`, `m_active_coordinator`,
  custom-type registration caches.
- Shared via context: `m_preview_parent`, `m_display_settings`.

## Stages

Each stage is one reviewable patch. Gate every stage on:
the host project's building smoke scene (in Kulangsu:
`scenes/tests/test_low_poly_building_editor_3d.tscn`) exits 0, plus a manual editor
pass over each tool the stage touched (draw, preview, commit, drag-edit,
undo, redo, Escape-cancel).

1. **Context extraction (no behavior change).** Create
   `building_tool_context.gd` with the shared-helper, coordinator, and
   undo-callable methods. `plugin.gd` methods become one-line delegations
   (kept temporarily so undo history and internal callers are undisturbed).
   Undo caution: `add_do_method(self, ...)` targets move from the plugin to
   the context object — the context must live as long as the plugin, and any
   queued undo actions from a previous session are invalidated on plugin
   reload (already true today for plugin reloads; acceptable).
2. **Native toolbar + icons.** Move the 49-function native-button/icon shim
   into `native_toolbar_integration.gd`. Zero geometry coupling; talks back
   to the plugin only through `select_tool_mode()` and
   `is_building_tool_active()`. This is the safest large chunk and removes
   ~700 lines early.
3. **First tool controller: Pillar.** Smallest complete tool (537 lines): no
   polygon mode, no rotation key, standard preview/drag/commit lifecycle.
   Introduce `building_tool_controller.gd`, the `{mode: controller}` dispatch
   map, and controller-owned settings. Prove Escape-cancel fan-out via
   `cancel_preview()` on the active controller only (matching current
   behavior of `_cancel_active_preview`).
4. **Rail, then Stairs.** Rail is pillar-shaped. Stairs adds the R-rotation
   key path, layout/rail settings application, and the
   `configure_stair_layout` preview flow — the template for roof's rotation
   handling.
5. **Floor, then Roof.** The two largest. Both add polygon draw/edit modes
   (Enter-to-close handling moves into the controller's `handle_input`),
   hover-edit pick chains, and hole editing (floor) / covers refresh + hip
   parameters (roof). Roof's `_set_roof_state_and_refresh` undo helpers move
   to the roof controller; wall-clip refresh calls stay routed through the
   context so the synchronous refresh-chain contract clause is preserved.
6. **Wall + placement.** Wall last among geometry tools: it owns the deepest
   undo helper family (`_do_set_wall_geometry*`, joint add/delete,
   zero-length deletion), joint hover markers, room-side resize, and opening
   anchors consumed by the placement path. Extract
   `placement_tool_controller.gd` (window/door/prop) in the same stage or
   immediately after, since opening drag helpers reference wall segment
   mapping.
7. **Cleanup + docs.** Delete the temporary delegation shims in `plugin.gd`,
   re-measure sizes, and update [`contract.md`](contract.md) (editor
   integration clause), [`feature.md`](feature.md) ownership notes, the
   plugin `README.md`, and the parent `docs/module_map.md` pointer in the
   same patch, per the governance rules.

## Risks

- **Undo/redo callable targets.** Undo actions must bind to objects that
  outlive the action. Controllers and the context are plugin-lifetime
  RefCounted members; never bind undo methods to per-gesture temporaries.
- **Editor reload.** After each stage, disable/re-enable the plugin (or
  restart the editor) to verify `_enter_tree` wiring; stale `Callable`s to
  freed controllers are the most likely regression.
- **Cross-controller calls.** Placement (openings) reads wall segment frames;
  roof commit refreshes wall clips. Route these through `Building3D`/the
  context, never controller-to-controller, to keep the boundaries honest.
- **Dock metadata keys.** Controllers must keep reading/writing the same
  editor-project-metadata keys the dock persists today; no key renames during
  the split.
- **No headless coverage for editor input.** The smoke test covers factories,
  geometry, caches, and collision — not viewport gestures. The manual pass per
  stage is mandatory, and stages are ordered so the riskiest tools land last,
  after the pattern is proven on three smaller ones.

## Acceptance

- [x] `plugin.gd` under 1,000 lines; each controller under 2,000.
- [ ] The host project's building smoke scene (in Kulangsu:
  `scenes/tests/test_low_poly_building_editor_3d.tscn`),
  `tests/test_dome_roof_3d.tscn`, and the variants gallery all pass
  (pending — no Godot run since the split).
- [ ] Manual checklist green for all nine tools (draw, preview, commit,
  drag-edit, rotation keys where applicable, undo/redo, Escape/right-click
  cancel, polygon Enter-close for floor/roof, native-toolbar mutual
  exclusivity). Give extra attention to undo/redo on every commit path —
  the one bug found in review was a broken undo bind.
- [x] Contract, feature, README, and module-map docs updated.

## Follow-On Candidates (out of scope for this plan)

- `low_poly_building_editor_dock.gd` is now the largest file in the plugin
  (2,866 lines / 143 functions). The same extraction pattern applies —
  per-tool settings sections behind a small section base — and is lower risk
  than the plugin split since the dock is plain UI.
- Controller-level headless tests are now feasible: instantiate
  `BuildingToolContext` plus one controller and drive synthetic input events
  (draw → commit → undo per tool). One such test per controller would have
  caught the undo-bind bug mechanically.
- Retire the two remaining transitional context callbacks by moving the
  debug-wireframe cluster into the context (or a display module) and giving
  the dock-context refresh a first-class home.
- `BuildingFactory.create_pillar_node` (12 positional parameters) still
  awaits the settings-dictionary treatment `create_stairs_node` received.
