class_name TacticalCommandBridge
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const CommandBridgeResult = preload("res://scripts/ui/command_bridge/command_bridge_result.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")
const WaitCommand = preload("res://scripts/core/commands/wait_command.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

func build_command(context: Variant, intent_value: Variant) -> CommandBridgeResult:
	if not intent_value is Dictionary:
		return CommandBridgeResult.disabled_result(&"", &"invalid_ui_intent", "malformed_intent")

	var intent: Dictionary = intent_value
	var intent_id: StringName = _intent_id_from(intent)
	if intent_id == &"":
		return CommandBridgeResult.disabled_result(&"", &"invalid_ui_intent", "missing_intent")

	match intent_id:
		&"move":
			return _build_move_command(context, intent_id, intent)
		&"attack":
			return _build_attack_command(context, intent_id, intent)
		&"wait":
			return _build_wait_command(context, intent_id, intent)
		&"inspect":
			return _build_inspect_result(context, intent_id, intent)
		_:
			return CommandBridgeResult.disabled_result(intent_id, &"unsupported_intent", "unsupported_intent", {
				"intent_id": String(intent_id)
			})


func execute_intent(context: Variant, intent: Variant) -> ActionResult:
	var conversion: CommandBridgeResult = build_command(context, intent)
	if not conversion.succeeded or conversion.command == null:
		if conversion.succeeded and conversion.command == null:
			return ActionResult.ok([], {
				"reason": conversion.reason,
				"intent_id": String(conversion.intent_id),
				"metadata": _metadata_copy(conversion.metadata)
			})
		var error_code: StringName = conversion.error_code
		if error_code == &"":
			error_code = &"invalid_ui_intent"
		return ActionResult.error(error_code, {
			"reason": conversion.reason,
			"intent_id": String(conversion.intent_id),
			"metadata": _metadata_copy(conversion.metadata)
		})
	return conversion.command.execute(context)


func _build_move_command(context: Variant, intent_id: StringName, intent: Dictionary) -> CommandBridgeResult:
	var context_result: Dictionary = _context_or_error(context, intent_id)
	if not bool(context_result.get("ok", false)):
		return context_result.get("result") as CommandBridgeResult

	var actor_result: Dictionary = _actor_id_or_error(intent, intent_id)
	if not bool(actor_result.get("ok", false)):
		return actor_result.get("result") as CommandBridgeResult

	var cell_result: Dictionary = _target_cell_or_error(intent, intent_id)
	if not bool(cell_result.get("ok", false)):
		return cell_result.get("result") as CommandBridgeResult

	var budget_result: Dictionary = _movement_budget_or_error(intent, intent_id)
	if not bool(budget_result.get("ok", false)):
		return budget_result.get("result") as CommandBridgeResult

	var command: MoveCommand = MoveCommand.new(
		actor_result.get("actor_id"),
		cell_result.get("cell"),
		int(budget_result.get("movement_budget"))
	)
	var validation: ActionResult = command.validate(context as TacticalActionContext)
	if validation.is_error():
		return _action_unavailable(intent_id, validation)

	return CommandBridgeResult.command_ready(
		intent_id,
		&"move",
		command,
		_command_metadata(&"move", validation.metadata),
		String(validation.metadata.get("reason", "valid"))
	)


# Story 14.1 — build the WAIT / pass-turn command from a UI intent, keeping the Wait tap seam SYMMETRIC with move /
# attack (all committed player actions go through the ONE command-bridge submission seam). A wait carries no target
# cell / weapon / support to marshal — only the actor and an optional lower_snake `reason` (default `voluntary`). The
# command's own validate (context / live actor / PLAYER_PLANNING / active actor) decides availability; a validate
# reject surfaces as `action_unavailable`, exactly like a rejected move.
func _build_wait_command(context: Variant, intent_id: StringName, intent: Dictionary) -> CommandBridgeResult:
	var context_result: Dictionary = _context_or_error(context, intent_id)
	if not bool(context_result.get("ok", false)):
		return context_result.get("result") as CommandBridgeResult

	var actor_result: Dictionary = _actor_id_or_error(intent, intent_id)
	if not bool(actor_result.get("ok", false)):
		return actor_result.get("result") as CommandBridgeResult

	var reason: StringName = _wait_reason_from(intent)
	var command: WaitCommand = WaitCommand.new(actor_result.get("actor_id"), reason)
	var validation: ActionResult = command.validate(context as TacticalActionContext)
	if validation.is_error():
		return _action_unavailable(intent_id, validation)

	return CommandBridgeResult.command_ready(
		intent_id,
		&"wait",
		command,
		{"reason": String(reason)},
		String(reason)
	)


func _build_attack_command(context: Variant, intent_id: StringName, intent: Dictionary) -> CommandBridgeResult:
	var context_result: Dictionary = _context_or_error(context, intent_id)
	if not bool(context_result.get("ok", false)):
		return context_result.get("result") as CommandBridgeResult

	var actor_result: Dictionary = _actor_id_or_error(intent, intent_id)
	if not bool(actor_result.get("ok", false)):
		return actor_result.get("result") as CommandBridgeResult

	var cell_result: Dictionary = _target_cell_or_error(intent, intent_id)
	if not bool(cell_result.get("ok", false)):
		return cell_result.get("result") as CommandBridgeResult

	var support_result: Dictionary = _supports_or_error(intent, intent_id)
	if not bool(support_result.get("ok", false)):
		return support_result.get("result") as CommandBridgeResult

	var weapon_result: Dictionary = _weapon_or_error(intent, intent_id)
	if not bool(weapon_result.get("ok", false)):
		return weapon_result.get("result") as CommandBridgeResult

	var command: AttackCommand = AttackCommand.new(
		actor_result.get("actor_id"),
		cell_result.get("cell"),
		weapon_result.get("weapon") as WeaponDefinition,
		support_result.get("attacker_support") as SupportDefinition,
		support_result.get("defender_support") as SupportDefinition
	)
	var validation: ActionResult = command.validate(context as TacticalActionContext)
	if validation.is_error():
		return _action_unavailable(intent_id, validation)

	return CommandBridgeResult.command_ready(
		intent_id,
		&"attack",
		command,
		_command_metadata(&"attack", validation.metadata),
		String(validation.metadata.get("reason", "valid"))
	)


func _build_inspect_result(context: Variant, intent_id: StringName, intent: Dictionary) -> CommandBridgeResult:
	var context_result: Dictionary = _context_or_error(context, intent_id)
	if not bool(context_result.get("ok", false)):
		return context_result.get("result") as CommandBridgeResult

	var cell_result: Dictionary = _target_cell_or_error(intent, intent_id)
	if not bool(cell_result.get("ok", false)):
		return cell_result.get("result") as CommandBridgeResult

	var action_context: TacticalActionContext = context as TacticalActionContext
	var target_cell: Vector2i = cell_result.get("cell")
	var fact_result: ActionResult = TacticalVisibilityQuery.new().visible_facts_for_cell(action_context.board, target_cell)
	if fact_result.is_error():
		return _action_unavailable(intent_id, fact_result)

	var fact: Dictionary = fact_result.metadata.get("fact", {}).duplicate(true)
	var selection: Dictionary = {
		"selected_cell": _cell_metadata(target_cell),
		"selected_entity_id": String(fact.get("occupant_id", ""))
	}
	return CommandBridgeResult.metadata_only(intent_id, {
		"target_cell": _cell_metadata(target_cell),
		"cell": fact,
		"selection": selection
	}, "inspect")


func _context_or_error(context: Variant, intent_id: StringName) -> Dictionary:
	if not context is TacticalActionContext:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_command_context", "invalid_context")
		}
	var action_context: TacticalActionContext = context as TacticalActionContext
	if action_context.board == null:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_command_context", "invalid_context")
		}
	if not action_context.has_required_state():
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_command_context", "invalid_context")
		}
	return {"ok": true}


func _actor_id_or_error(intent: Dictionary, intent_id: StringName) -> Dictionary:
	if not _has_field(intent, &"actor_id") or String(_field(intent, &"actor_id")).is_empty():
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_ui_intent", "missing_actor")
		}
	return {
		"ok": true,
		"actor_id": StringName(str(_field(intent, &"actor_id")))
	}


func _target_cell_or_error(intent: Dictionary, intent_id: StringName) -> Dictionary:
	if not _has_field(intent, &"target_cell"):
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_ui_intent", "missing_target_cell")
		}

	var value: Variant = _field(intent, &"target_cell")
	if value is Vector2i:
		return {
			"ok": true,
			"cell": value
		}
	if not value is Dictionary:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_ui_intent", "malformed_target_cell")
		}

	var data: Dictionary = value
	if not _has_integral_field(data, &"x") or not _has_integral_field(data, &"y"):
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_ui_intent", "malformed_target_cell")
		}
	return {
		"ok": true,
		"cell": Vector2i(int(_field(data, &"x")), int(_field(data, &"y")))
	}


func _movement_budget_or_error(intent: Dictionary, intent_id: StringName) -> Dictionary:
	if not _has_field(intent, &"movement_budget"):
		return {
			"ok": true,
			"movement_budget": MoveCommand.BASELINE_MOVEMENT_BUDGET
		}
	if not _is_integral_number(_field(intent, &"movement_budget")):
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_ui_intent", "invalid_movement_budget")
		}
	var movement_budget: int = int(_field(intent, &"movement_budget"))
	if movement_budget <= 0:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"invalid_ui_intent", "invalid_movement_budget")
		}
	return {
		"ok": true,
		"movement_budget": movement_budget
	}


func _supports_or_error(intent: Dictionary, intent_id: StringName) -> Dictionary:
	var attacker_support: Variant = _field(intent, &"attacker_support") if _has_field(intent, &"attacker_support") else null
	var defender_support: Variant = _field(intent, &"defender_support") if _has_field(intent, &"defender_support") else null
	if attacker_support != null and not attacker_support is SupportDefinition:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"action_unavailable", "invalid_support", {
				"field": "attacker_support"
			})
		}
	if defender_support != null and not defender_support is SupportDefinition:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"action_unavailable", "invalid_support", {
				"field": "defender_support"
			})
		}
	return {
		"ok": true,
		"attacker_support": attacker_support,
		"defender_support": defender_support
	}


func _weapon_or_error(intent: Dictionary, intent_id: StringName) -> Dictionary:
	if not _has_field(intent, &"weapon"):
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"action_unavailable", "invalid_weapon")
		}
	var weapon: Variant = _field(intent, &"weapon")
	if not weapon is WeaponDefinition:
		return {
			"ok": false,
			"result": CommandBridgeResult.disabled_result(intent_id, &"action_unavailable", "invalid_weapon")
		}
	return {
		"ok": true,
		"weapon": weapon
	}


func _action_unavailable(intent_id: StringName, validation: ActionResult) -> CommandBridgeResult:
	var source_metadata: Dictionary = validation.metadata.duplicate(true)
	var reason: String = String(source_metadata.get("reason", validation.error_code))
	return CommandBridgeResult.disabled_result(intent_id, &"action_unavailable", reason, {
		"source_error_code": String(validation.error_code)
	})


func _intent_id_from(intent: Dictionary) -> StringName:
	if not _has_field(intent, &"intent_id"):
		return &""
	return StringName(str(_field(intent, &"intent_id")))


# The optional wait reason (default `voluntary`). The command's board-apply payload validator enforces lower_snake; the
# bridge just passes a non-empty value through (an empty/absent reason falls back to the voluntary default).
func _wait_reason_from(intent: Dictionary) -> StringName:
	if not _has_field(intent, &"reason"):
		return WaitCommand.REASON_VOLUNTARY
	var value: String = String(_field(intent, &"reason")).strip_edges()
	if value.is_empty():
		return WaitCommand.REASON_VOLUNTARY
	return StringName(value)


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _has_integral_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_integral_number(_field(data, field_name))


func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


func _command_metadata(command_id: StringName, source: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"reason": String(source.get("reason", "valid"))
	}
	match command_id:
		&"move":
			if source.has("movement_cost"):
				result["movement_cost"] = int(source.get("movement_cost", 0))
			if source.has("movement_budget"):
				result["movement_budget"] = int(source.get("movement_budget", 0))
		&"attack":
			for key: StringName in [
				&"legal",
				&"actor_id",
				&"target_cell",
				&"target_entity_id",
				&"weapon_id",
				&"targeting_shape",
				&"range",
				&"distance",
				&"blocker_ignored",
				&"expected_base_damage",
				&"warnings",
				&"effects",
				&"explanation"
			]:
				if source.has(String(key)):
					result[String(key)] = _safe_value(source.get(String(key)))
	return result


func _metadata_copy(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		if key is String or key is StringName:
			result[String(key)] = _safe_value(source[key])
	return result


func _safe_array_copy(source: Array) -> Array:
	var result: Array = []
	for item: Variant in source:
		result.append(_safe_value(item))
	return result


func _safe_dictionary_copy(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		if key is String or key is StringName:
			result[String(key)] = _safe_value(source[key])
	return result


func _safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return null
			return numeric_value
		TYPE_STRING:
			return String(value)
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2I:
			var cell: Vector2i = value
			return _cell_metadata(cell)
		TYPE_ARRAY:
			return _safe_array_copy(value)
		TYPE_DICTIONARY:
			return _safe_dictionary_copy(value)
		_:
			return null
	return null


func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false
