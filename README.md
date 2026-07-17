# Low-Poly Building Editor

Godot editor plugin for grid-snapped low-poly building authoring — an editor dock plus 3D
viewport tools for walls, floors, terrain-profiled streets, stairs, standard rails, pillars, roofs, openings, and
props, authored as normal scene nodes so the result serializes into `.tscn` files. The Wall tool can draw
either individual spans or enclosed rooms with a configurable side count of at least
three; four sides preserves rectangular-room creation. The Stairs tool draws one
bounding rectangle and can lay it out as a straight run or as L-shaped, double-L,
U-shaped, 90/180-degree winder, or spiral stairs with a configurable flight width
and left/right turn direction. Each layout is represented by a concrete `Stairs3D`
subclass. `Stairs3D` owns only universal stair state, delegating reusable segment mesh
primitives to internal geometry-strategy classes that mirror the roof split;
the internal `TurningStairs3D` layer owns Turn and Flight Width plus shared turning-plan
allocation, mirroring, transition-rail, and collision orchestration; Winder owns its
90/180-degree selector, and Spiral owns its configurable 45–1080-degree
radial run around a low-poly central column. Straight owns its complete single-run
mesh, rail, and side-blocker path, while each concrete non-straight class builds
its own segment and rail plan; landings, winder fans, and spiral
treads subdivide the same rectangle, and optional rails follow the turning path.
The dock passes the selected concrete stair script directly to the factory rather
than serializing a separate layout enum or key.
Stairs offer three tread styles: Closed builds the solid stepped mass, Open
floats individual tread slabs (and landing platforms) with no risers or
underside, and Nosing keeps the closed mass while overhanging each tread past
its riser by a configurable depth; winder fans treat Nosing as Closed. Spiral
supports only Closed and Open: its class normalizes unsupported values, its
inspector hides Nosing and nosing depth, and the dock disables Nosing.
The Floor tool's Rectangle and
Polygon styles choose only how a new footprint is drawn: two opposite corners or a
multi-click outline. Both use the same grid-snapped editing gestures afterward. Any
vertex can be dragged, any edge can move both adjacent vertices, and vertices can be
inserted with Shift-click on an edge or removed with Option/Alt-click. Hole uses the
same Rectangle/Polygon creation choice and the same outline-editing gestures.
Flat roofs follow the same pattern: Rectangle and Polygon change only creation, then
both expose shared vertex, edge, insertion, removal, and body-drag editing. Other roof
styles retain their rectangular footprints. Floor slabs and polygon Flat roofs share
the same polygon-prism topology builder, so generated top, underside, and boundary
faces follow one outline; Flat-roof overhang preserves one render corner per authored
corner, including acute footprints.

## Installation

This repository contains the plugin files at its root. Clone it into
`res://addons/low_poly_building_editor` (or copy the repository contents there), then
enable **Low-Poly Building Editor** under Project → Project Settings → Plugins.

`Building3D` is the scene-owned assembly root and carries no editor-tool configuration;
the editor dock owns temporary tool defaults. `BuildingFactory` creates and names
building blocks, while transient wall and roof geometry resolvers perform intersection,
overlap, opening-propagation, and clipping calculations.

The dock's global **Debug Display** controls draw one shared, transient wireframe across
walls, floors, stairs, rails, pillars, roofs, openings, and placed props. The display assigns
a transient RenderingServer material overlay to each existing mesh instance and relies on Godot's native
wireframe shader mode instead of adding scene children, extracting triangle edges, or
allocating duplicate geometry on the editor thread. Wireframes are depth-tested by default
and back-face culled so invisible surface triangles stay hidden; X-ray mode is the explicit
option for drawing hidden geometry. Display changes replace only those temporary materials,
restore any authored material overlay when disabled, and never rebuild authored mesh or
collision geometry. New mesh blocks inherit this behavior automatically from
the internal `building_mesh_3d.gd` infrastructure base.

A scene can contain multiple independent `Building3D` roots or packed building scene
instances. **Add Building** creates and selects a new root; selecting any building root
or one of its authored descendants makes that building the target for subsequent tool
operations. Geometry merging and clipping never cross between building roots.

Styled blocks use typed hierarchies. Their base classes own only universal state and
low-level generation infrastructure; optional intermediate layers own properties shared
by a genuine subset; and concrete pillar, roof, window, and door styles own their style
identity, style controls, and geometry. Internal bases and intermediate layers are not
registered as editor-creatable custom types; plugin registration is derived from the
factory's canonical stair, pillar, roof, and opening registries. Abstract bases contain
no retired-style compatibility adapters; cross-style roof geometry queries live in the
roof strategy factory, while each concrete roof selects its own strategy directly. See
the normative future-block pattern in
[`docs/contract.md`](docs/contract.md#building-block-style-pattern).

Serialized generated meshes are validated caches. Walls, floors, stairs, rails, pillars, and
roofs share `BuildingMesh3D` cache signatures; windows and doors cache their generated
part meshes. Loading reuses matching geometry while recreating unsaved collision/debug
children, and authored or clipping changes invalidate only the affected cache.

## Seeded Building Generation

The plugin also provides a deterministic JSON-to-scene path for AI agents and batch
authoring. [`building_spec.gd`](building_spec.gd) parses and validates the versioned
input, [`building_spec_compiler.gd`](building_spec_compiler.gd) builds ordinary
`Building3D` nodes through `BuildingFactory`, and
[`generate_building.gd`](generate_building.gd) saves the result as an editable `.tscn`.

Generate the included example:

```sh
godot --headless --path . \
  --script addons/low_poly_building_editor/generate_building.gd -- \
  --spec res://addons/low_poly_building_editor/examples/seeded_villa.json \
  --output res://generated/buildings/seeded_villa.tscn \
  --report res://generated/buildings/seeded_villa.report.json
```

Generator version 1 supports two spec types. The default `building` type supports one rectangular storey, one required entrance, repeated
validated facade windows, optional porch pillars, footprint jitter, and one flat, shed,
gable, hip, or dome roof. The `street` type supports a multi-point 3D path, a continuously sloped road, raised kerbs, two footpaths, and automatic footpath-only stairs where local slope is strictly greater than 25 degrees. A style value of `random` resolves deterministically from `seed`.
The command prints the same machine-readable report it optionally writes to `--report`.
Invalid specs and buildings that cannot fit their entrance do not produce a scene.

Generate the included bent hill-street example:

```sh
godot --headless --path . \
  --script addons/low_poly_building_editor/generate_building.gd -- \
  --spec res://addons/low_poly_building_editor/examples/seeded_street.json \
  --output res://generated/buildings/seeded_street.tscn
```

New Street viewport commits author one `StreetNetwork3D` per `Building3D`. Its serialized
`StreetNetworkData` stores stable junction IDs, segment endpoint references, straight/cubic/
polyline curves, vertical policy, and reusable asymmetric `StreetSectionProfile` resources.
Dragging a junction rebuilds only its incident segments; Shift-click splits a segment and
Option/Alt-click removes a junction through Godot undo/redo. Same-level crossings split into
one explicit junction, while vertically separated crossings remain topologically independent.

`StreetCurveSampler` adaptively subdivides cubic curves by chord error and tangent angle.
Follow-terrain segments use a smoothed sampled profile; graded segments interpolate between
junction elevations; manual segments retain their authored profile. Steep adjacent samples
are grouped with entry/exit hysteresis into one coherent footpath stair run, while short
terrain ripples remain ramps. Segment children sweep road/kerb/footpath geometry and a
dedicated `StreetJunction3D` owns each multi-road centre surface. Cross-sections may use
different left/right kerb and footpath widths.

`LowPolyTerrain3D` discovers either the network's multi-corridor contract or a legacy
`Street3D` source, lowers/feathers its supporting bed, and includes junction polygons in
terrain shaping. Mask generation thins blue STREET cells into branch-aware paths, converts
them into one deterministic network beneath `GeneratedStreets`, samples the untouched base
grid, and rebuilds visible segment/junction caches. Explicit rebuilds replace generated mask
overrides. Existing `Street3D` scenes and version-1 street JSON remain supported; a network's
`add_legacy_street(s)` migration methods preserve their authored positions and sections.

### Visual Variant Batches

[`generate_variants.gd`](generate_variants.gd) expands one base spec across consecutive
seeds, saves every editable scene and isometric thumbnail, and writes a manifest plus a
contact sheet for AI or human ranking:

```sh
godot --path . --audio-driver Dummy \
  --script addons/low_poly_building_editor/generate_variants.gd -- \
  --spec res://addons/low_poly_building_editor/examples/seeded_villa.json \
  --output-dir res://generated/buildings/villa_variants \
  --count 12
```

Thumbnail generation requires a graphical rendering driver, so this command intentionally
does not use `--headless` (Godot's macOS headless display exposes only the dummy renderer).
Automation may launch a tiny off-screen window with Godot's `--resolution` and `--position`
options. Each manifest entry maps a seed and resolved parameters to its `.tscn` and `.png`;
`contact_sheet.png` preserves manifest order.

Run [`tests/test_building_variants_gallery_3d.tscn`](tests/test_building_variants_gallery_3d.tscn)
to inspect the included 12-seed example as a live 4×3 scene. `N` and `P` compile adjacent
seed batches, `R` restores seeds 18432–18443, and the mouse wheel adjusts the orthographic
camera. Each generated root retains its resolved generator values as metadata for runtime
inspection.

This README is the plugin's entry point; the full documentation lives in [`docs/`](docs):

- [`docs/feature.md`](docs/feature.md) — goals, authoring experience, rules, edge cases, ownership, and validation.
- [`docs/contract.md`](docs/contract.md) — stable contract and governance for the plugin's nodes, storage, and editor interaction.
- [`docs/plugin_split_plan.md`](docs/plugin_split_plan.md) — staged plan for the shipped `plugin.gd` split into per-tool editor controllers under `editor/` (delete after editor validation).

The end-to-end building smoke scene lives in the consuming project rather than
this addon, because it probes generated buildings against the host project's
player actor (in Kulangsu: `scenes/tests/test_low_poly_building_editor_3d.tscn`);
this keeps the addon free of parent-repo resource paths. The focused legacy
street smoke scene is [`tests/test_street_3d.tscn`](tests/test_street_3d.tscn), the graph/geometry
suite is [`tests/test_street_network_3d.tscn`](tests/test_street_network_3d.tscn), the focused
dome smoke scene is [`tests/test_dome_roof_3d.tscn`](tests/test_dome_roof_3d.tscn), the
hip shape smoke scene is
[`tests/test_hip_shapes_3d.tscn`](tests/test_hip_shapes_3d.tscn), the native transform
bake smoke scene is
[`tests/test_native_transform_3d.tscn`](tests/test_native_transform_3d.tscn), and the
interactive generator gallery is
[`tests/test_building_variants_gallery_3d.tscn`](tests/test_building_variants_gallery_3d.tscn). The
plugin-owned documentation in [`docs/`](docs) is the canonical reference for its
architecture and contracts.

## Known noise

Headless runs of a consuming project may print `resource still in use at exit`
naming `building_wireframe.gd`. Its static shader cache is annotated with
`@static_unload`, but Godot 4.x releases script references after the exit-time
leak check, so the warning persists as harmless shutdown-ordering noise rather
than a runtime leak. Do not spend time chasing it here.
