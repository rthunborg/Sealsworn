extends "res://tests/unit/test_case.gd"

func run() -> Dictionary:
	var presets_text: String = _read_file_text("res://export_presets.cfg")
	var readme_text: String = _read_file_text("res://README.md")

	_windows_and_android_presets_are_scaffolded(presets_text)
	_production_exports_exclude_non_runtime_files(presets_text)
	_android_prerequisites_are_documented(readme_text)
	_ios_export_is_deferred_without_secrets(presets_text, readme_text)
	_export_setup_avoids_forbidden_dependencies(presets_text)

	return result()


func _windows_and_android_presets_are_scaffolded(presets_text: String) -> void:
	assert_true(presets_text.contains("name=\"Windows Desktop MVP\""), "Export presets should include Windows desktop scaffold.")
	assert_true(presets_text.contains("platform=\"Windows Desktop\""), "Windows scaffold should target Windows Desktop.")
	assert_true(presets_text.contains("name=\"Android MVP\""), "Export presets should include Android scaffold.")
	assert_true(presets_text.contains("platform=\"Android\""), "Android scaffold should target Android.")
	assert_true(presets_text.contains("package/signed=false"), "Android scaffold should not require signing secrets.")


func _production_exports_exclude_non_runtime_files(presets_text: String) -> void:
	assert_true(presets_text.contains("data/source/**"), "Production export filters should exclude source-only data.")
	assert_true(presets_text.contains("scenes/debug/**"), "Production export filters should exclude debug scenes.")
	assert_true(presets_text.contains("tests/**"), "Production export filters should exclude tests.")
	assert_true(presets_text.contains("tools/**"), "Production export filters should exclude tools.")
	assert_true(presets_text.contains("**/test_*.gd"), "Production export filters should exclude test scripts.")


func _android_prerequisites_are_documented(readme_text: String) -> void:
	assert_true(readme_text.contains("Godot export templates"), "README should document Godot export templates for Android.")
	assert_true(readme_text.contains("Android Studio"), "README should document Android Studio for Android export setup.")
	assert_true(readme_text.contains("OpenJDK 17"), "README should document the pinned OpenJDK requirement.")
	assert_true(readme_text.contains("Android SDK Platform-Tools 35.0.0"), "README should document pinned Android Platform-Tools.")
	assert_true(readme_text.contains("Build-Tools 35.0.1"), "README should document pinned Android Build-Tools.")
	assert_true(readme_text.contains("Platform 35"), "README should document pinned Android Platform.")
	assert_true(readme_text.contains("CMake 3.10.2.4988404"), "README should document pinned Android CMake.")
	assert_true(readme_text.contains("NDK r28b"), "README should document pinned Android NDK.")


func _ios_export_is_deferred_without_secrets(presets_text: String, readme_text: String) -> void:
	assert_true(presets_text.contains("name=\"iOS MVP\""), "Export presets should include iOS scaffold.")
	assert_true(presets_text.contains("platform=\"iOS\""), "iOS scaffold should target iOS.")
	assert_true(presets_text.contains("application/app_store_team_id=\"\""), "iOS scaffold should keep team id blank.")
	assert_true(presets_text.contains("application/code_sign_identity_debug=\"\""), "iOS scaffold should keep debug signing identity blank.")
	assert_true(presets_text.contains("application/code_sign_identity_release=\"\""), "iOS scaffold should keep release signing identity blank.")
	assert_true(readme_text.contains("iOS export is deferred"), "README should record iOS export as deferred.")
	assert_true(readme_text.contains("macOS with Xcode"), "README should document macOS and Xcode as iOS requirements.")
	assert_true(readme_text.contains("iOS signing"), "README should record signing values as blank or placeholder-only.")


func _export_setup_avoids_forbidden_dependencies(presets_text: String) -> void:
	assert_false(presets_text.contains("prototype/"), "Export setup must not depend on prototype files.")
	assert_false(presets_text.contains("telemetry"), "Export setup must not add telemetry services.")
	assert_false(presets_text.contains("multiplayer"), "Export setup must not add multiplayer services.")
	assert_false(presets_text.contains("cloud"), "Export setup must not add cloud service dependencies.")


func _read_file_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
