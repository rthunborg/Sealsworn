extends "res://tests/unit/test_case.gd"

const REQUIRED_DOMAIN_ROOTS: Array[String] = [
	"res://scripts/core",
	"res://scripts/tactical",
	"res://scripts/rules",
	"res://scripts/generation",
	"res://scripts/ai",
	"res://scripts/content",
	"res://scripts/save",
	"res://scripts/ui",
	"res://scripts/platform",
	"res://scripts/diagnostics",
	"res://scripts/utils"
]

const REQUIRED_PROJECT_ROOTS: Array[String] = [
	"res://scenes/game",
	"res://scenes/ui",
	"res://assets",
	"res://data/source",
	"res://data/resources",
	"res://tests",
	"res://tests/unit",
	"res://tests/integration"
]

func run() -> Dictionary:
	_required_roots_exist()
	_headless_runner_scans_unit_and_integration_roots()
	return result()


func _required_roots_exist() -> void:
	for root_path: String in REQUIRED_DOMAIN_ROOTS:
		assert_true(DirAccess.open(root_path) != null, "%s should exist for domain code." % root_path)

	for root_path: String in REQUIRED_PROJECT_ROOTS:
		assert_true(DirAccess.open(root_path) != null, "%s should exist for project structure." % root_path)


func _headless_runner_scans_unit_and_integration_roots() -> void:
	var runner_text: String = _read_file_text("res://tests/headless/test_runner.gd")

	assert_true(runner_text.contains("\"res://tests/unit\""), "Headless runner should scan unit tests.")
	assert_true(runner_text.contains("\"res://tests/integration\""), "Headless runner should scan integration tests.")
	assert_true(runner_text.contains("get_tree().quit(total_failures)"), "Headless runner should exit with the failure count.")


func _read_file_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
