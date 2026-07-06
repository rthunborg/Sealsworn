class_name BootController
extends Control

# The boot presenter (Story 2 baseline; Story 11.3 routes it into the run flow). It boots the app, then enters
# the FIRST run-flow stage (hero select) via the SceneManager named-stage surface (AC1: SceneManager drives
# launch -> hero select -> ...). It guards has_node("/root/SceneManager") + logs via Diagnostics (the reference
# presenter pattern every 11.3 presenter follows). It OWNS no run/tactical truth — it only navigates.

# The first run-flow stage the boot chain enters (Story 11.3). The launch stage IS the boot chain; boot advances
# to hero select (the class picker) — the RunFlowRouter STAGES vocabulary's second stage.
const FIRST_FLOW_STAGE := "hero_select"

func _ready() -> void:
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_ready", {"scene": "boot"})
	call_deferred("_enter_first_flow_stage")


func _enter_first_flow_stage() -> void:
	if not has_node("/root/SceneManager"):
		return

	var result: Error = SceneManager.go_to_stage(FIRST_FLOW_STAGE)
	if result != OK and has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_scene_change_failed", {
			"target_stage": FIRST_FLOW_STAGE,
			"error": result
		})
