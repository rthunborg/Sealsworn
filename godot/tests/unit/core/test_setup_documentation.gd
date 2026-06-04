extends "res://tests/unit/test_case.gd"

func run() -> Dictionary:
	var readme_text: String = _read_file_text("res://README.md")

	assert_true(readme_text.contains("godot --version"), "README should record the local Godot version check.")
	assert_true(
		readme_text.contains("godot --headless --path C:\\Sealsworn\\godot --scene res://tests/headless/test_runner.tscn --quit-after 10"),
		"README should record the Windows-friendly headless test command."
	)
	assert_true(readme_text.contains("godot --path C:\\Sealsworn\\godot"), "README should record the Windows dev-run command.")
	assert_true(
		readme_text.contains("godot --path C:\\Sealsworn\\godot --scene res://scenes/app/boot.tscn"),
		"README should record the explicit boot scene dev-run command."
	)

	return result()


func _read_file_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
