extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 1/2/3/4 — the scene/presenter CONSTRUCTION guardrail. The scene-free harness cannot run a
# SceneTree, but it CAN verify every 11.3 presenter SCRIPT and every 11.3 .tscn LOADS without a parse/compile
# error (a broken presenter would otherwise silently ship — it is in no other test's preload chain). This is the
# "verified by construction" backstop: it proves the .tscn -> Control presenter wiring compiles + the scenes
# reference real scripts, without instantiating a scene tree. It does NOT _ready() the presenters (that needs a
# SceneTree); it loads the script + scene resources, which forces GDScript to COMPILE each presenter.

func run() -> Dictionary:
	_every_run_flow_presenter_script_compiles()
	_every_run_flow_scene_loads_with_its_script()
	return result()


# Loading a GDScript resource forces it to compile; a parse/type error would make load() return null.
func _every_run_flow_presenter_script_compiles() -> void:
	var presenter_scripts: Array[String] = [
		"res://scripts/ui/presenters/boot_controller.gd",
		"res://scripts/ui/presenters/hero_select_presenter.gd",
		"res://scripts/ui/presenters/route_map_presenter.gd",
		"res://scripts/ui/presenters/tactical_board_presenter.gd",
		"res://scripts/ui/presenters/tactical_board_grid.gd",
		"res://scripts/ui/presenters/gameplay_shell_presenter.gd",
		"res://scripts/ui/presenters/run_end_presenter.gd",
		"res://scripts/ui/presenters/outpost_presenter.gd",
		"res://scripts/ui/presenters/save_recovery_presenter.gd"
	]
	for script_path: String in presenter_scripts:
		var script: Variant = load(script_path)
		assert_true(script != null, "Presenter script must compile + load: %s" % script_path)
		assert_true(script is GDScript, "Presenter must be a GDScript: %s" % script_path)


# Loading a PackedScene forces its ext_resource scripts to resolve; a missing/broken script or a bad node type
# would fail the load.
func _every_run_flow_scene_loads_with_its_script() -> void:
	var scene_paths: Array[String] = [
		"res://scenes/ui/hero_select.tscn",
		"res://scenes/ui/route_map.tscn",
		"res://scenes/ui/run_end.tscn",
		"res://scenes/ui/outpost.tscn",
		"res://scenes/ui/save_recovery.tscn",
		"res://scenes/game/gameplay_shell.tscn",
		"res://scenes/game/tactical_board.tscn",
		"res://scenes/app/boot.tscn",
		"res://scenes/app/main.tscn"
	]
	for scene_path: String in scene_paths:
		var scene: Variant = load(scene_path)
		assert_true(scene != null, "Scene must load with its script resolved: %s" % scene_path)
		assert_true(scene is PackedScene, "Loaded resource must be a PackedScene: %s" % scene_path)
