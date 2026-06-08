class_name TacticalAttackPreview
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = TacticalPreviewView.safe_dictionary_copy(new_data)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_query(
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon: WeaponDefinition
) -> TacticalAttackPreview:
	var validation: ActionResult = AttackPreviewQuery.new().preview_target_cell(board, actor_id, target_cell, weapon)
	var source_metadata: Dictionary = validation.metadata if validation.metadata is Dictionary else {}
	var reason: String = String(source_metadata.get("reason", "valid" if validation.succeeded else validation.error_code))
	var available: bool = validation.succeeded
	var weapon_id: String = String(source_metadata.get("weapon_id", String(weapon.weapon_id) if weapon != null else ""))
	var weapon_reach: int = int(source_metadata.get("range", weapon.attack_range if weapon != null else 0))
	var targeting_shape: String = String(source_metadata.get("targeting_shape", String(weapon.targeting_shape) if weapon != null else ""))
	var expected_base_damage: int = int(source_metadata.get("expected_base_damage", -1))
	var blocker_ignored: bool = bool(source_metadata.get("blocker_ignored", false))
	var warnings: Array = TacticalPreviewView.safe_array_copy(source_metadata.get("warnings", []))
	var effects: Array = TacticalPreviewView.safe_array_copy(source_metadata.get("effects", []))
	var blocker_cells: Array = TacticalPreviewView.safe_array_copy(source_metadata.get("blocker_cells", []))

	var metadata: Dictionary = {
		"weapon_id": weapon_id,
		"weapon_reach": weapon_reach,
		"targeting_shape": targeting_shape,
		"distance": int(source_metadata.get("distance", -1)),
		"line_cells": TacticalPreviewView.safe_array_copy(source_metadata.get("line_cells", [])),
		"blocker_cells": blocker_cells,
		"blocker_state": _blocker_state(available, blocker_cells, blocker_ignored),
		"blocker_ignored": blocker_ignored,
		"expected_damage": expected_base_damage,
		"expected_base_damage": expected_base_damage,
		"effects": effects,
		"warnings": warnings,
		"explanation": String(source_metadata.get("explanation", ""))
	}

	var data: Dictionary = {
		"kind": "attack",
		"available": available,
		"reason": reason,
		"actor_id": String(actor_id),
		"target_cell": TacticalPreviewView.cell_metadata(target_cell),
		"target_entity_id": String(source_metadata.get("target_entity_id", "")),
		"target_valid": available,
		"commit_available": available,
		"commit_reason": reason,
		"cue_ids": _cue_ids(available, reason, blocker_ignored, warnings, effects),
		"metadata": metadata
	}
	return load("res://scripts/ui/view_models/tactical_attack_preview.gd").new(data)


static func _blocker_state(available: bool, blocker_cells: Array, blocker_ignored: bool) -> String:
	if not blocker_cells.is_empty():
		return "ignored" if blocker_ignored else "blocked"
	if available:
		return "clear"
	return "unknown"


static func _cue_ids(
	available: bool,
	reason: String,
	blocker_ignored: bool,
	warnings: Array,
	effects: Array
) -> Array[String]:
	var result: Array[String] = []
	result.append("attack_preview_valid" if available else "attack_preview_invalid")
	if reason == "blocked_line":
		result.append("attack_preview_blocked_line")
	if blocker_ignored:
		result.append("attack_preview_blocker_ignored")
	if _has_warning(warnings, "adjacent_ranged_penalty"):
		result.append("attack_preview_adjacent_warning")
	if not effects.is_empty():
		result.append("preview_effect")
	result.append("commit_available" if available else "commit_unavailable")
	return result


static func _has_warning(warnings: Array, warning_id: String) -> bool:
	for warning_value: Variant in warnings:
		if warning_value is Dictionary and String((warning_value as Dictionary).get("id", "")) == warning_id:
			return true
	return false
