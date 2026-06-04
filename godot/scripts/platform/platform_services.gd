class_name PlatformServices
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")

func record_telemetry(_event_name: StringName, _payload: Dictionary = {}) -> void:
	pass


func unlock_achievement(_achievement_id: StringName) -> void:
	pass


func sync_save(_snapshot: RunSnapshot) -> ActionResult:
	return ActionResult.ok()
