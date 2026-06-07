class_name TacticalActionAvailability
extends RefCounted

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = new_data.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_preview(preview: Dictionary) -> TacticalActionAvailability:
	var preview_kind: String = String(preview.get("kind", ""))
	var preview_available: bool = bool(preview.get("available", false))
	var preview_reason: String = String(preview.get("reason", "none"))
	var data: Dictionary = {
		"move": _entry(preview_kind == "move" and preview_available, preview_reason if preview_kind == "move" else "no_move_preview"),
		"attack": _entry(preview_kind == "attack" and preview_available, preview_reason if preview_kind == "attack" else "no_attack_preview"),
		"inspect": _entry(true, "available"),
		"confirm": _entry(false, "not_in_commit_flow"),
		"cancel": _entry(false, "not_in_commit_flow")
	}
	return load("res://scripts/ui/view_models/tactical_action_availability.gd").new(data)


static func _entry(enabled: bool, reason: String) -> Dictionary:
	return {
		"enabled": enabled,
		"reason": reason
	}
