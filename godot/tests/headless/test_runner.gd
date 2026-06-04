extends Node

const TEST_ROOTS: Array[String] = [
	"res://tests/unit",
	"res://tests/integration"
]

func _ready() -> void:
	var total_failures: int = 0

	for script_path: String in _discover_tests():
		var script: Variant = load(script_path)
		if script == null:
			total_failures += 1
			push_error("Missing test script: %s" % script_path)
			continue

		var test_instance: Variant = script.new()
		var result: Dictionary = test_instance.run()
		var failures: Array = result.get("failures", [])
		if failures.is_empty():
			print("PASS ", script_path)
		else:
			total_failures += failures.size()
			print("FAIL ", script_path)
			for failure: Variant in failures:
				print("  - ", failure)

	if OS.get_cmdline_user_args().has("--force-test-failure"):
		total_failures += 1
		print("FAIL forced test-runner exit-code check")

	if total_failures == 0:
		print("Headless tests passed.")
	else:
		push_error("Headless tests failed: %s failure(s)." % total_failures)

	get_tree().quit(total_failures)


func _discover_tests() -> Array[String]:
	var script_paths: Array[String] = []
	for root_path: String in TEST_ROOTS:
		_collect_tests(root_path, script_paths)
	script_paths.sort()
	return script_paths


func _collect_tests(directory_path: String, script_paths: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while entry_name != "":
		var entry_path: String = "%s/%s" % [directory_path, entry_name]
		if directory.current_is_dir():
			if not entry_name.begins_with("."):
				_collect_tests(entry_path, script_paths)
		elif _is_test_script(entry_name):
			script_paths.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _is_test_script(file_name: String) -> bool:
	return file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd"
