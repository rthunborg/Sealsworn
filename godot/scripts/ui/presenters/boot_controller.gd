class_name BootController
extends Control

const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"

func _ready() -> void:
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_ready", {"scene": "boot"})
	call_deferred("_enter_main_scene")


func _enter_main_scene() -> void:
	if not has_node("/root/SceneManager"):
		return

	var result: Error = SceneManager.change_scene(MAIN_SCENE_PATH)
	if result != OK and has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_scene_change_failed", {
			"target_scene": MAIN_SCENE_PATH,
			"error": result
		})
