class_name CombatOutcomeState
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

const STATE_ACTIVE := &"active"
const STATE_VICTORY := &"victory"
const STATE_DEFEAT := &"defeat"

var state_id: StringName = STATE_ACTIVE
var metadata: Dictionary = {}

func _init(new_state_id: StringName = STATE_ACTIVE, new_metadata: Dictionary = {}) -> void:
	state_id = new_state_id
	metadata = new_metadata.duplicate(true)


func is_active() -> bool:
	return state_id == STATE_ACTIVE


func is_terminal() -> bool:
	return state_id == STATE_VICTORY or state_id == STATE_DEFEAT


func validate() -> ActionResult:
	if not _is_supported_state(state_id):
		return _invalid(&"invalid_outcome_state", {
			"state_id": String(state_id)
		})
	return ActionResult.ok()


func apply_outcome_event(event: DomainEvent) -> ActionResult:
	if event == null:
		return _invalid(&"invalid_event")
	match event.event_type:
		DomainEvent.Type.LEVEL_VICTORY_REACHED:
			state_id = STATE_VICTORY
		DomainEvent.Type.LEVEL_DEFEAT_REACHED:
			state_id = STATE_DEFEAT
		_:
			return _invalid(&"unsupported_event", {
				"event_id": String(DomainEvent.id_for_type(event.event_type))
			})
	metadata = event.payload.duplicate(true)
	metadata["outcome_event_sequence_id"] = event.sequence_id
	return ActionResult.ok()


func to_dictionary() -> Dictionary:
	return {
		"state_id": String(state_id),
		"metadata": metadata.duplicate(true)
	}


func copy() -> CombatOutcomeState:
	return load("res://scripts/tactical/outcomes/combat_outcome_state.gd").new(state_id, metadata)


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not _has_string_like_field(data, &"state_id"):
		return _invalid(&"invalid_outcome_state", {"field": "state_id"})
	var parsed_state_id: StringName = StringName(str(_field(data, &"state_id")))
	var parsed_metadata: Dictionary = {}
	if _has_field(data, &"metadata"):
		var metadata_value: Variant = _field(data, &"metadata")
		if not metadata_value is Dictionary:
			return _invalid(&"invalid_outcome_state", {"field": "metadata"})
		parsed_metadata = (metadata_value as Dictionary).duplicate(true)

	var outcome_state: CombatOutcomeState = load("res://scripts/tactical/outcomes/combat_outcome_state.gd").new(parsed_state_id, parsed_metadata)
	var validation: ActionResult = outcome_state.validate()
	if validation.is_error():
		return validation
	return ActionResult.ok([], {
		"outcome_state": outcome_state
	})


static func from_dictionary(data: Dictionary) -> CombatOutcomeState:
	var result: ActionResult = try_from_dictionary(data)
	if result.is_error():
		push_error("CombatOutcomeState parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("outcome_state") as CombatOutcomeState


static func _is_supported_state(value: StringName) -> bool:
	return value == STATE_ACTIVE or value == STATE_VICTORY or value == STATE_DEFEAT


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	if not _has_field(data, field_name):
		return false
	var value: Variant = _field(data, field_name)
	return value is String or value is StringName


static func _invalid(reason: StringName, new_metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in new_metadata.keys():
		result_metadata[key] = new_metadata[key]
	return ActionResult.error(&"invalid_outcome_state", result_metadata)
