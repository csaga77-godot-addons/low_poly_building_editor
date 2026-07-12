extends SceneTree

const BuildingGenerationSpecScript = preload(
	"res://addons/low_poly_building_editor/building_generation_spec.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)


func _init() -> void:
	var exit_code := _run(OS.get_cmdline_user_args())
	quit(exit_code)


func _run(arguments: PackedStringArray) -> int:
	var options := _parse_options(arguments)
	var argument_errors := _string_array(options.get("errors", []))
	if bool(options.get("help", false)):
		_print_usage()
		return 0
	if !argument_errors.is_empty():
		return _finish_report({}, argument_errors, [], options, 2)

	var spec_path := String(options.get("spec", ""))
	var output_path := String(options.get("output", ""))
	if spec_path.is_empty():
		argument_errors.append("Missing required --spec path.")
	if output_path.is_empty():
		argument_errors.append("Missing required --output path.")
	if !argument_errors.is_empty():
		return _finish_report({}, argument_errors, [], options, 2)

	var load_result := _load_spec(spec_path)
	var load_errors := _string_array(load_result.get("errors", []))
	if !load_errors.is_empty():
		return _finish_report({}, load_errors, [], options, 2)
	var spec := load_result.get("spec") as BuildingGenerationSpecScript
	var compile_result := BuildingSpecCompilerScript.compile(spec)
	var errors := _string_array(compile_result.get("errors", []))
	var warnings := _string_array(compile_result.get("warnings", []))
	var resolved: Dictionary = compile_result.get("resolved", {})
	var building := compile_result.get("building") as Building3DScript
	if !errors.is_empty() or building == null:
		return _finish_report(resolved, errors, warnings, options, 1)

	var save_error := BuildingSpecCompilerScript.save_building(
		building,
		output_path
	)
	building.free()
	if save_error != OK:
		errors.append(
			"Could not save '%s' (error %d)." % [output_path, save_error]
		)
		return _finish_report(resolved, errors, warnings, options, 1)
	return _finish_report(resolved, errors, warnings, options, 0)


func _load_spec(path: String) -> Dictionary:
	return BuildingSpecCompilerScript.load_json_spec(path)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options := {
		"spec": "",
		"output": "",
		"report": "",
		"help": false,
		"errors": [] as Array[String],
	}
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument == "--help" or argument == "-h":
			options["help"] = true
			index += 1
			continue
		if argument in ["--spec", "--output", "--report"]:
			if index + 1 >= arguments.size():
				(options["errors"] as Array[String]).append(
					"Missing value after %s." % argument
				)
				index += 1
				continue
			options[argument.trim_prefix("--")] = arguments[index + 1]
			index += 2
			continue
		(options["errors"] as Array[String]).append(
			"Unknown argument: %s" % argument
		)
		index += 1
	return options


func _finish_report(
	resolved: Dictionary,
	errors: Array[String],
	warnings: Array[String],
	options: Dictionary,
	exit_code: int
) -> int:
	var report := {
		"ok": exit_code == 0,
		"output": String(options.get("output", "")),
		"resolved": resolved,
		"errors": errors,
		"warnings": warnings,
	}
	var report_text := JSON.stringify(report, "\t")
	print(report_text)
	var report_path := String(options.get("report", ""))
	if !report_path.is_empty():
		var report_error := _write_report(report_path, report_text)
		if report_error != OK:
			push_error(
				"Could not write report '%s' (error %d)."
				% [report_path, report_error]
			)
			return 1
	if exit_code != 0:
		for error in errors:
			push_error(error)
	return exit_code


func _write_report(path: String, report_text: String) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(report_text + "\n")
	return OK


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result


func _print_usage() -> void:
	print(
		"Usage: godot --headless --path . --script "
		+ "addons/low_poly_building_editor/generate_building.gd -- "
		+ "--spec <spec.json> --output <building.tscn> [--report <report.json>]"
	)
