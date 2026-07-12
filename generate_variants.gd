extends SceneTree

const BuildingGenerationSpecScript = preload(
	"res://addons/low_poly_building_editor/building_generation_spec.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const BuildingThumbnailRendererScript = preload(
	"res://addons/low_poly_building_editor/building_thumbnail_renderer.gd"
)
const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)

const MANIFEST_SCHEMA_VERSION := 1
const DEFAULT_COUNT := 12
const MAX_COUNT := 64
const DEFAULT_IMAGE_SIZE := Vector2i(512, 384)


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	var exit_code: int = await _run(OS.get_cmdline_user_args())
	quit(exit_code)


func _run(arguments: PackedStringArray) -> int:
	var options := _parse_options(arguments)
	var argument_errors := _string_array(options.get("errors", []))
	if bool(options.get("help", false)):
		_print_usage()
		return 0
	var spec_path := String(options.get("spec", ""))
	var output_directory := String(options.get("output_dir", "")).trim_suffix("/")
	if spec_path.is_empty():
		argument_errors.append("Missing required --spec path.")
	if output_directory.is_empty():
		argument_errors.append("Missing required --output-dir path.")
	if !argument_errors.is_empty():
		_print_failure(argument_errors)
		return 2

	var count := int(options.get("count", DEFAULT_COUNT))
	var image_size := Vector2i(
		int(options.get("width", DEFAULT_IMAGE_SIZE.x)),
		int(options.get("height", DEFAULT_IMAGE_SIZE.y))
	)
	if count < 1 or count > MAX_COUNT:
		argument_errors.append("--count must be between 1 and %d." % MAX_COUNT)
	if image_size.x < 64 or image_size.y < 64:
		argument_errors.append("--width and --height must be at least 64.")
	if !argument_errors.is_empty():
		_print_failure(argument_errors)
		return 2
	if DisplayServer.get_name() == "headless":
		_print_failure([
			"Variant thumbnails require a graphical rendering driver. "
				+ "Run generate_variants.gd without --headless; "
				+ "the window can be positioned off-screen for automation.",
		])
		return 2

	var load_result := BuildingSpecCompilerScript.load_json_spec(spec_path)
	var load_errors := _string_array(load_result.get("errors", []))
	if !load_errors.is_empty():
		_print_failure(load_errors)
		return 2
	var base_spec := load_result.get("spec") as BuildingGenerationSpecScript
	if base_spec == null:
		_print_failure(["Building spec could not be loaded."])
		return 2
	var seed_start := (
		int(options["seed_start"])
		if options.has("seed_start") and options["seed_start"] != null
		else base_spec.generation_seed
	)
	var file_stem := _safe_file_stem(base_spec.building_name)
	var manifest_path := String(options.get("manifest", ""))
	if manifest_path.is_empty():
		manifest_path = output_directory.path_join("manifest.json")
	var contact_sheet_path := String(options.get("contact_sheet", ""))
	if contact_sheet_path.is_empty():
		contact_sheet_path = output_directory.path_join("contact_sheet.png")

	var variants: Array[Dictionary] = []
	var thumbnail_paths := PackedStringArray()
	var batch_errors: Array[String] = []
	var renderer := BuildingThumbnailRendererScript.new() as BuildingThumbnailRendererScript
	for index in range(count):
		var variant_seed := seed_start + index
		var variant_number := index + 1
		var variant_name := "%s_%03d" % [file_stem, variant_number]
		var scene_path := output_directory.path_join(variant_name + ".tscn")
		var thumbnail_path := output_directory.path_join(variant_name + ".png")
		var variant_spec := base_spec.duplicate(true) as BuildingGenerationSpecScript
		variant_spec.generation_seed = variant_seed
		variant_spec.building_name = variant_name.to_pascal_case()
		var compile_result := BuildingSpecCompilerScript.compile(variant_spec)
		var variant_errors := _string_array(compile_result.get("errors", []))
		var variant_warnings := _string_array(compile_result.get("warnings", []))
		var resolved: Dictionary = compile_result.get("resolved", {})
		var building := compile_result.get("building") as Building3DScript
		var entry := {
			"index": variant_number,
			"seed": variant_seed,
			"ok": false,
			"scene": scene_path,
			"thumbnail": thumbnail_path,
			"resolved": resolved,
			"errors": variant_errors,
			"warnings": variant_warnings,
		}
		if building == null or !variant_errors.is_empty():
			batch_errors.append(
				"Variant %03d failed compilation." % variant_number
			)
			variants.append(entry)
			continue

		var save_error := BuildingSpecCompilerScript.save_building(
			building,
			scene_path
		)
		if save_error != OK:
			variant_errors.append(
				"Could not save scene (error %d)." % save_error
			)
			entry["errors"] = variant_errors
			batch_errors.append("Variant %03d could not be saved." % variant_number)
			building.free()
			variants.append(entry)
			continue

		var render_result: Dictionary = await renderer.render_building(
			building,
			resolved,
			thumbnail_path,
			image_size
		)
		building.free()
		if !bool(render_result.get("ok", false)):
			variant_errors.append(String(render_result.get("error", "Render failed.")))
			entry["errors"] = variant_errors
			batch_errors.append(
				"Variant %03d could not be rendered." % variant_number
			)
			variants.append(entry)
			continue

		entry["ok"] = true
		variants.append(entry)
		thumbnail_paths.append(thumbnail_path)

	renderer.dispose()
	var contact_sheet_error := OK
	if !thumbnail_paths.is_empty():
		contact_sheet_error = BuildingThumbnailRendererScript.create_contact_sheet(
			thumbnail_paths,
			contact_sheet_path,
			int(options.get("columns", 0))
		)
		if contact_sheet_error != OK:
			batch_errors.append(
				"Could not create contact sheet (error %d)." % contact_sheet_error
			)

	var manifest := {
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"ok": batch_errors.is_empty() and variants.size() == count,
		"source_spec": spec_path,
		"output_directory": output_directory,
		"requested_count": count,
		"generated_count": thumbnail_paths.size(),
		"seed_start": seed_start,
		"image_size": [image_size.x, image_size.y],
		"contact_sheet": (
			contact_sheet_path
			if contact_sheet_error == OK and !thumbnail_paths.is_empty()
			else ""
		),
		"variants": variants,
		"errors": batch_errors,
	}
	var manifest_error := _write_json(manifest_path, manifest)
	if manifest_error != OK:
		batch_errors.append(
			"Could not write manifest '%s' (error %d)."
			% [manifest_path, manifest_error]
		)
		manifest["ok"] = false
		manifest["errors"] = batch_errors
	print(JSON.stringify(manifest, "\t"))
	for error in batch_errors:
		push_error(error)
	return 0 if bool(manifest["ok"]) and manifest_error == OK else 1


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options := {
		"spec": "",
		"output_dir": "",
		"manifest": "",
		"contact_sheet": "",
		"count": DEFAULT_COUNT,
		"seed_start": null,
		"width": DEFAULT_IMAGE_SIZE.x,
		"height": DEFAULT_IMAGE_SIZE.y,
		"columns": 0,
		"help": false,
		"errors": [] as Array[String],
	}
	var value_options := [
		"--spec",
		"--output-dir",
		"--manifest",
		"--contact-sheet",
		"--count",
		"--seed-start",
		"--width",
		"--height",
		"--columns",
	]
	var integer_options := [
		"--count",
		"--seed-start",
		"--width",
		"--height",
		"--columns",
	]
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument == "--help" or argument == "-h":
			options["help"] = true
			index += 1
			continue
		if argument in value_options:
			if index + 1 >= arguments.size():
				(options["errors"] as Array[String]).append(
					"Missing value after %s." % argument
				)
				index += 1
				continue
			var value: Variant = arguments[index + 1]
			if argument in integer_options:
				if !String(value).is_valid_int():
					(options["errors"] as Array[String]).append(
						"%s requires an integer value." % argument
					)
					index += 2
					continue
				value = int(value)
			options[argument.trim_prefix("--").replace("-", "_")] = value
			index += 2
			continue
		(options["errors"] as Array[String]).append(
			"Unknown argument: %s" % argument
		)
		index += 1
	return options


func _write_json(path: String, value: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t") + "\n")
	return OK


func _safe_file_stem(source: String) -> String:
	var stem := source.strip_edges().to_snake_case()
	for forbidden in ["/", "\\", ":", "@", "\"", "%"]:
		stem = stem.replace(forbidden, "_")
	return stem if !stem.is_empty() else "generated_building"


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result


func _print_failure(errors: Array[String]) -> void:
	var report := {"ok": false, "errors": errors}
	print(JSON.stringify(report, "\t"))
	for error in errors:
		push_error(error)


func _print_usage() -> void:
	print(
		"Usage: godot --headless --path . --script "
		+ "addons/low_poly_building_editor/generate_variants.gd -- "
		+ "--spec <spec.json> --output-dir <directory> "
		+ "[--count 12] [--seed-start N] [--width 512] [--height 384] "
		+ "[--columns N] [--manifest <manifest.json>] "
		+ "[--contact-sheet <sheet.png>]"
	)
