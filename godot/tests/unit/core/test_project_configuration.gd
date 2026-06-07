extends "res://tests/unit/test_case.gd"

func run() -> Dictionary:
	var config := ConfigFile.new()
	var load_error: Error = config.load("res://project.godot")

	assert_equal(load_error, OK, "Project config should load in headless tests.")
	_project_is_standard_gdscript(config)
	_project_uses_mobile_boot_baseline(config)
	_project_has_no_prototype_dependency()

	return result()


func _project_is_standard_gdscript(config: ConfigFile) -> void:
	var features: PackedStringArray = config.get_value("application", "config/features", PackedStringArray())
	var project_text: String = _read_project_text()

	assert_true(features.has("4.6"), "Project should target the Godot 4.6 feature set.")
	assert_false(project_text.contains("dotnet"), "Project config must not enable Godot .NET.")
	assert_false(project_text.contains("mono"), "Project config must not enable Mono/C# settings.")
	assert_false(project_text.contains(".csproj"), "Project config must not reference C# project files.")


func _project_uses_mobile_boot_baseline(config: ConfigFile) -> void:
	var main_scene: String = str(config.get_value("application", "run/main_scene", ""))
	var renderer: String = str(config.get_value("rendering", "renderer/rendering_method", ""))
	var mobile_renderer: String = str(config.get_value("rendering", "renderer/rendering_method.mobile", ""))
	var viewport_width: int = int(config.get_value("display", "window/size/viewport_width", 0))
	var viewport_height: int = int(config.get_value("display", "window/size/viewport_height", 0))

	assert_equal(main_scene, "res://scenes/app/boot.tscn", "Project should boot through the minimal app scene.")
	assert_true(ResourceLoader.exists(main_scene), "Configured main scene should exist.")
	assert_equal(renderer, "mobile", "Default renderer should be Mobile.")
	assert_equal(mobile_renderer, "mobile", "Mobile renderer override should stay Mobile.")
	assert_equal(viewport_width, 1080, "Viewport width should use the mobile-first baseline.")
	assert_equal(viewport_height, 1920, "Viewport height should use the mobile-first baseline.")


func _project_has_no_prototype_dependency() -> void:
	var project_text: String = _read_project_text()

	assert_false(project_text.contains("prototype/"), "Project config must not depend on the React/Vite prototype.")
	assert_false(project_text.contains("prototype\\"), "Project config must not depend on the React/Vite prototype.")
	assert_false(project_text.contains("res://prototype"), "Project config must not depend on a Godot prototype path.")


func _read_project_text() -> String:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
