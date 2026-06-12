class_name TacticalActionAvailability
extends RefCounted

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = new_data.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_preview(preview: Dictionary, commit_flow: Dictionary = {}) -> TacticalActionAvailability:
	var preview_kind: String = String(preview.get("kind", ""))
	var preview_available: bool = bool(preview.get("available", false))
	var preview_reason: String = String(preview.get("reason", "none"))
	var commit_available: bool = bool(preview.get("commit_available", preview_available))
	var commit_reason: String = String(preview.get("commit_reason", preview_reason))
	var active_attack_flow: bool = String(commit_flow.get("mode", "none")) == "attack_preview"
	var flow_matches_preview: bool = active_attack_flow and _flow_matches_preview(preview, commit_flow)
	var flow_confirm_available: bool = flow_matches_preview and bool(commit_flow.get("confirm_available", false))
	var flow_cancel_available: bool = flow_matches_preview and bool(commit_flow.get("cancel_available", false))
	var confirm_enabled: bool = (
		(preview_kind == "move" and commit_available)
		or (preview_kind == "attack" and commit_available and flow_confirm_available)
	)
	var confirm_reason: String = _confirm_reason(preview_kind, active_attack_flow, flow_matches_preview, commit_reason)
	var cancel_reason: String = "available" if flow_cancel_available else ("stale_commit_flow" if active_attack_flow and not flow_matches_preview else "not_in_commit_flow")
	var data: Dictionary = {
		"move": _entry(preview_kind == "move" and commit_available, commit_reason if preview_kind == "move" else "no_move_preview"),
		"attack": _entry(preview_kind == "attack" and commit_available, commit_reason if preview_kind == "attack" else "no_attack_preview"),
		"inspect": _entry(true, "available"),
		"confirm": _entry(confirm_enabled, confirm_reason),
		"cancel": _entry(flow_cancel_available, cancel_reason)
	}
	return load("res://scripts/ui/view_models/tactical_action_availability.gd").new(data)


static func _entry(enabled: bool, reason: String) -> Dictionary:
	return {
		"enabled": enabled,
		"reason": reason
	}


static func _confirm_reason(
	preview_kind: String,
	active_attack_flow: bool,
	flow_matches_preview: bool,
	commit_reason: String
) -> String:
	if preview_kind != "attack":
		return commit_reason
	if not active_attack_flow:
		return "not_in_commit_flow"
	if not flow_matches_preview:
		return "stale_commit_flow"
	return commit_reason


static func _flow_matches_preview(preview: Dictionary, commit_flow: Dictionary) -> bool:
	if String(preview.get("kind", "")) != "attack":
		return false
	if String(preview.get("actor_id", "")) != String(commit_flow.get("actor_id", "")):
		return false
	if _cell_from_value(preview.get("target_cell", {})) != _cell_from_value(commit_flow.get("target_cell", {})):
		return false
	if String(preview.get("target_entity_id", "")) != String(commit_flow.get("target_entity_id", "")):
		return false
	return _weapon_id_from_preview(preview) == String(commit_flow.get("weapon_id", ""))


static func _weapon_id_from_preview(preview: Dictionary) -> String:
	var metadata_value: Variant = preview.get("metadata", {})
	if not metadata_value is Dictionary:
		return ""
	return String((metadata_value as Dictionary).get("weapon_id", ""))


static func _cell_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var data: Dictionary = value
		return Vector2i(int(_field(data, &"x", 0)), int(_field(data, &"y", 0)))
	return Vector2i.ZERO


static func _field(data: Dictionary, field_name: StringName, fallback: Variant = null) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	if data.has(field_name):
		return data[field_name]
	return fallback
