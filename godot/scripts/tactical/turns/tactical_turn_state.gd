class_name TacticalTurnState
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

enum Phase {
	PLAYER_PLANNING,
	PLAYER_RESOLVING,
	ENEMY_PLANNING,
	ENEMY_RESOLVING,
	ENVIRONMENT_RESOLVING
}

const PHASE_PLAYER_PLANNING := &"player_planning"
const PHASE_PLAYER_RESOLVING := &"player_resolving"
const PHASE_ENEMY_PLANNING := &"enemy_planning"
const PHASE_ENEMY_RESOLVING := &"enemy_resolving"
const PHASE_ENVIRONMENT_RESOLVING := &"environment_resolving"
const PHASE_UNKNOWN := &"unknown"

var turn_number: int = 1
var phase: int = Phase.PLAYER_PLANNING
var active_actor_id: StringName = &""

func _init(
	new_turn_number: int = 1,
	new_phase: int = Phase.PLAYER_PLANNING,
	new_active_actor_id: StringName = &""
) -> void:
	turn_number = new_turn_number
	phase = new_phase
	active_actor_id = new_active_actor_id


func to_dictionary() -> Dictionary:
	return {
		"turn_number": turn_number,
		"phase": String(id_for_phase(phase)),
		"active_actor_id": String(active_actor_id)
	}


func copy() -> TacticalTurnState:
	return load("res://scripts/tactical/turns/tactical_turn_state.gd").new(
		turn_number,
		phase,
		active_actor_id
	)


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not _has_integral_field(data, &"turn_number"):
		return _invalid_turn_state(&"turn_number")
	if not _has_field(data, &"phase"):
		return _invalid_turn_state(&"phase")
	if not _has_string_like_field(data, &"active_actor_id"):
		return _invalid_turn_state(&"active_actor_id")

	var parsed_turn_number: int = int(_field(data, &"turn_number"))
	if parsed_turn_number <= 0:
		return _invalid_turn_state(&"turn_number")

	var parsed_phase: int = phase_from_variant(_field(data, &"phase"))
	if not is_supported_phase(parsed_phase):
		return _invalid_turn_state(&"phase")

	var turn_state: TacticalTurnState = load("res://scripts/tactical/turns/tactical_turn_state.gd").new(
		parsed_turn_number,
		parsed_phase,
		StringName(str(_field(data, &"active_actor_id")))
	)
	return ActionResult.ok([], {"turn_state": turn_state})


static func id_for_phase(phase_value: int) -> StringName:
	match phase_value:
		Phase.PLAYER_PLANNING:
			return PHASE_PLAYER_PLANNING
		Phase.PLAYER_RESOLVING:
			return PHASE_PLAYER_RESOLVING
		Phase.ENEMY_PLANNING:
			return PHASE_ENEMY_PLANNING
		Phase.ENEMY_RESOLVING:
			return PHASE_ENEMY_RESOLVING
		Phase.ENVIRONMENT_RESOLVING:
			return PHASE_ENVIRONMENT_RESOLVING
		_:
			return PHASE_UNKNOWN


static func phase_for_id(phase_id: StringName) -> int:
	match phase_id:
		PHASE_PLAYER_PLANNING:
			return Phase.PLAYER_PLANNING
		PHASE_PLAYER_RESOLVING:
			return Phase.PLAYER_RESOLVING
		PHASE_ENEMY_PLANNING:
			return Phase.ENEMY_PLANNING
		PHASE_ENEMY_RESOLVING:
			return Phase.ENEMY_RESOLVING
		PHASE_ENVIRONMENT_RESOLVING:
			return Phase.ENVIRONMENT_RESOLVING
		_:
			return -1


static func phase_from_variant(value: Variant) -> int:
	if _is_integral_number(value):
		return int(value)
	if not _is_string_like(value):
		return -1
	return phase_for_id(StringName(str(value)))


static func is_supported_phase(phase_value: int) -> bool:
	return phase_value >= Phase.PLAYER_PLANNING and phase_value <= Phase.ENVIRONMENT_RESOLVING


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_string_like(_field(data, field_name))


static func _has_integral_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_integral_number(_field(data, field_name))


static func _is_string_like(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _invalid_turn_state(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_turn_state", {
		"field": String(field_name)
	})
