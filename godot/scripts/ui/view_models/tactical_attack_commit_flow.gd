class_name TacticalAttackCommitFlow
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const CommandBridgeResult = preload("res://scripts/ui/command_bridge/command_bridge_result.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlowResult = preload("res://scripts/ui/view_models/tactical_attack_commit_flow_result.gd")
const TacticalAttackPreview = preload("res://scripts/ui/view_models/tactical_attack_preview.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

const MODE_NONE := "none"
const MODE_ATTACK_PREVIEW := "attack_preview"

var _state: Dictionary = _empty_state("none")

func to_dictionary() -> Dictionary:
	return _state.duplicate(true)


func tap_attack_target(
	context: TacticalActionContext,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon: WeaponDefinition,
	attacker_support: SupportDefinition = null,
	defender_support: SupportDefinition = null,
	command_bridge: TacticalCommandBridge = null
) -> TacticalAttackCommitFlowResult:
	if _matches_pending_attack(actor_id, target_cell, weapon):
		return confirm_attack(context, weapon, attacker_support, defender_support, command_bridge)
	return _start_attack_preview(context, actor_id, target_cell, weapon)


func confirm_attack(
	context: TacticalActionContext,
	weapon: WeaponDefinition,
	attacker_support: SupportDefinition = null,
	defender_support: SupportDefinition = null,
	command_bridge: TacticalCommandBridge = null
) -> TacticalAttackCommitFlowResult:
	if String(_state.get("mode", MODE_NONE)) != MODE_ATTACK_PREVIEW:
		_clear("no_pending_attack")
		return _result(false, "", "no_pending_attack", null)
	if not _weapon_matches_state(weapon):
		_clear("weapon_changed")
		return _result(false, "", "weapon_changed", null)

	var actor_id: StringName = StringName(String(_state.get("actor_id", "")))
	var target_cell: Vector2i = _cell_from_value(_state.get("target_cell", {}))
	var preview: Dictionary = TacticalAttackPreview.from_query(_context_board(context), actor_id, target_cell, weapon).to_dictionary()
	var preview_reason: String = String(preview.get("reason", "invalid_attack_preview"))
	if not bool(preview.get("commit_available", false)):
		_clear(preview_reason)
		return _result(false, "", preview_reason, null)
	if String(preview.get("target_entity_id", "")) != String(_state.get("target_entity_id", "")):
		_clear("target_changed")
		return _result(false, "", "target_changed", null)

	var bridge: TacticalCommandBridge = command_bridge if command_bridge != null else TacticalCommandBridge.new()
	var intent: Dictionary = _attack_intent(actor_id, target_cell, weapon, attacker_support, defender_support)
	var conversion: CommandBridgeResult = bridge.build_command(context, intent)
	if not conversion.succeeded or conversion.command == null:
		var unavailable_reason: String = _bridge_result_reason(conversion)
		_clear(unavailable_reason)
		return _result(false, "", unavailable_reason, null)

	var execution: ActionResult = conversion.command.execute(context)
	var result_reason: String = _command_result_reason(execution)
	_clear(result_reason)
	return _result(execution != null and execution.succeeded, "attack" if execution != null and execution.succeeded else "", result_reason, execution)


func cancel() -> TacticalAttackCommitFlowResult:
	_clear("cancelled")
	return _result(false, "", "cancelled", null)


func clear_for_non_attack_tile(_target_cell: Vector2i) -> TacticalAttackCommitFlowResult:
	_clear("non_attack_tile")
	return _result(false, "", "non_attack_tile", null)


func clear_for_mode_switch(reason: StringName = &"mode_switch") -> TacticalAttackCommitFlowResult:
	var reason_text: String = String(reason)
	if reason_text.is_empty():
		reason_text = "mode_switch"
	_clear(reason_text)
	return _result(false, "", reason_text, null)


func refresh_or_clear(
	context: TacticalActionContext,
	weapon: WeaponDefinition
) -> TacticalAttackCommitFlowResult:
	if String(_state.get("mode", MODE_NONE)) != MODE_ATTACK_PREVIEW:
		return _result(false, "", "no_pending_attack", null)
	if not _weapon_matches_state(weapon):
		_clear("weapon_changed")
		return _result(false, "", "weapon_changed", null)

	var actor_id: StringName = StringName(String(_state.get("actor_id", "")))
	var target_cell: Vector2i = _cell_from_value(_state.get("target_cell", {}))
	var preview: Dictionary = TacticalAttackPreview.from_query(_context_board(context), actor_id, target_cell, weapon).to_dictionary()
	var reason: String = String(preview.get("reason", "invalid_attack_preview"))
	if not bool(preview.get("commit_available", false)):
		_clear(reason)
		return _result(false, "", reason, null)
	if String(preview.get("target_entity_id", "")) != String(_state.get("target_entity_id", "")):
		_clear("target_changed")
		return _result(false, "", "target_changed", null)

	_state = _state_from_preview(preview, reason)
	return _result(false, "", reason, null)


func _start_attack_preview(
	context: TacticalActionContext,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon: WeaponDefinition
) -> TacticalAttackCommitFlowResult:
	var preview: Dictionary = TacticalAttackPreview.from_query(_context_board(context), actor_id, target_cell, weapon).to_dictionary()
	var reason: String = String(preview.get("reason", "invalid_attack_preview"))
	if not bool(preview.get("commit_available", false)):
		_clear(reason)
		return _result(false, "", reason, null)

	_state = _state_from_preview(preview, "preview_ready")
	return _result(false, "", "preview_ready", null)


func _matches_pending_attack(
	actor_id: StringName,
	target_cell: Vector2i,
	weapon: WeaponDefinition
) -> bool:
	if String(_state.get("mode", MODE_NONE)) != MODE_ATTACK_PREVIEW:
		return false
	if String(_state.get("actor_id", "")) != String(actor_id):
		return false
	if _cell_from_value(_state.get("target_cell", {})) != target_cell:
		return false
	if not _weapon_matches_state(weapon):
		return false
	return not String(_state.get("target_entity_id", "")).is_empty()


func _weapon_matches_state(weapon: WeaponDefinition) -> bool:
	if weapon == null:
		return false
	return String(_state.get("weapon_id", "")) == String(weapon.weapon_id)


func _state_from_preview(preview: Dictionary, reason: String) -> Dictionary:
	var preview_copy: Dictionary = TacticalPreviewView.safe_dictionary_copy(preview)
	var cue_ids: Array = TacticalPreviewView.safe_array_copy(preview_copy.get("cue_ids", []))
	if not cue_ids.has("cancel_available"):
		cue_ids.append("cancel_available")
	return {
		"mode": MODE_ATTACK_PREVIEW,
		"actor_id": String(preview_copy.get("actor_id", "")),
		"target_cell": TacticalPreviewView.safe_value(preview_copy.get("target_cell", {})),
		"target_entity_id": String(preview_copy.get("target_entity_id", "")),
		"weapon_id": String((preview_copy.get("metadata", {}) as Dictionary).get("weapon_id", "")),
		"preview": preview_copy,
		"confirm_available": bool(preview_copy.get("commit_available", false)),
		"cancel_available": true,
		"reason": reason,
		"cue_ids": cue_ids
	}


func _clear(reason: String) -> void:
	_state = _empty_state(reason)


func _result(
	was_submitted: bool,
	command_id: String,
	result_reason: String,
	result_value: ActionResult
) -> TacticalAttackCommitFlowResult:
	return TacticalAttackCommitFlowResult.from_flow(
		was_submitted,
		command_id,
		result_reason,
		result_value,
		_state
	)


func _attack_intent(
	actor_id: StringName,
	target_cell: Vector2i,
	weapon: WeaponDefinition,
	attacker_support: SupportDefinition,
	defender_support: SupportDefinition
) -> Dictionary:
	var intent: Dictionary = {
		"intent_id": "attack",
		"actor_id": String(actor_id),
		"target_cell": target_cell,
		"weapon": weapon
	}
	if attacker_support != null:
		intent["attacker_support"] = attacker_support
	if defender_support != null:
		intent["defender_support"] = defender_support
	return intent


func _context_board(context: TacticalActionContext) -> Variant:
	if context == null:
		return null
	return context.board


func _command_result_reason(result_value: ActionResult) -> String:
	if result_value == null:
		return "missing_command_result"
	if result_value.succeeded:
		return String(result_value.metadata.get("reason", "committed"))
	var metadata_reason: String = String(result_value.metadata.get("reason", ""))
	if not metadata_reason.is_empty():
		return metadata_reason
	var nested_metadata: Variant = result_value.metadata.get("metadata", {})
	if nested_metadata is Dictionary and not String((nested_metadata as Dictionary).get("reason", "")).is_empty():
		return String((nested_metadata as Dictionary).get("reason", ""))
	return String(result_value.error_code)


func _bridge_result_reason(result_value: CommandBridgeResult) -> String:
	if result_value == null:
		return "missing_command_result"
	if not result_value.reason.is_empty():
		return result_value.reason
	if result_value.error_code != &"":
		return String(result_value.error_code)
	return "command_unavailable"


static func _empty_state(reason: String) -> Dictionary:
	return {
		"mode": MODE_NONE,
		"actor_id": "",
		"target_cell": {},
		"target_entity_id": "",
		"weapon_id": "",
		"preview": {},
		"confirm_available": false,
		"cancel_available": false,
		"reason": reason,
		"cue_ids": []
	}


static func _cell_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var data: Dictionary = value
		return Vector2i(int(TacticalPreviewView.field(data, &"x", 0)), int(TacticalPreviewView.field(data, &"y", 0)))
	return Vector2i.ZERO
