class_name ClassDefinition
extends Resource

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"class"

# Lock states (FR42/FR43). Warrior/Pyromancer/Ranger are SELECTABLE; Necromancer/Shadeblade are
# LOCKED future classes shown grayed-out with a clear unlock hint.
const LOCK_STATE_SELECTABLE := &"selectable"
const LOCK_STATE_LOCKED := &"locked"

@export var class_id: StringName = &""
@export var display_name: String = ""
@export var lock_state: StringName = &""
@export var unlock_hint: String = ""
# Starting equipment (AC1): one weapon id + one support id (may be `none`) + baseline HP.
# Equipment ids are validated for lower_snake SHAPE only; Story 5.3 resolves them through
# WeaponRepository/SupportRepository at run-start and fails closed on a missing item.
@export var starting_weapon_id: StringName = &""
@export var starting_support_id: StringName = &""
@export var baseline_hp: int = 0
# Passive ids (FR44) are lower_snake STRING-shape forward references. There is no passive
# definition / passive repository / rules kernel yet (Epic 6 authors the passive pool; Story 5.4
# wires class passives into the rules kernel through explicit trigger windows). validate() checks
# SHAPE ONLY and MUST NOT resolve these against a passive repository.
@export var class_passive_id: StringName = &""
@export var equipment_synergy_passive_id: StringName = &""

func _init(
	new_class_id: StringName = &"",
	new_display_name: String = "",
	new_lock_state: StringName = &"",
	new_unlock_hint: String = "",
	new_starting_weapon_id: StringName = &"",
	new_starting_support_id: StringName = &"",
	new_baseline_hp: int = 0,
	new_class_passive_id: StringName = &"",
	new_equipment_synergy_passive_id: StringName = &""
) -> void:
	class_id = new_class_id
	display_name = new_display_name
	lock_state = new_lock_state
	unlock_hint = new_unlock_hint
	starting_weapon_id = new_starting_weapon_id
	starting_support_id = new_starting_support_id
	baseline_hp = new_baseline_hp
	class_passive_id = new_class_passive_id
	equipment_synergy_passive_id = new_equipment_synergy_passive_id


func validate() -> ActionResult:
	if not _is_lower_snake_id(class_id):
		return _invalid(&"class_id")
	if display_name.strip_edges().is_empty():
		return _invalid(&"display_name")
	if not _is_valid_lock_state(lock_state):
		return _invalid(&"lock_state")

	match lock_state:
		LOCK_STATE_SELECTABLE:
			if not _is_lower_snake_id(starting_weapon_id):
				return _invalid(&"starting_weapon_id")
			if not _is_lower_snake_id(starting_support_id):
				return _invalid(&"starting_support_id")
			if baseline_hp <= 0:
				return _invalid(&"baseline_hp")
			if not _is_lower_snake_id(class_passive_id):
				return _invalid(&"class_passive_id")
			if not _is_lower_snake_id(equipment_synergy_passive_id):
				return _invalid(&"equipment_synergy_passive_id")
		LOCK_STATE_LOCKED:
			if unlock_hint.strip_edges().is_empty():
				return _invalid(&"unlock_hint")
	return ActionResult.ok()


func is_selectable() -> bool:
	return lock_state == LOCK_STATE_SELECTABLE


static func _is_valid_lock_state(value: StringName) -> bool:
	return value == LOCK_STATE_SELECTABLE or value == LOCK_STATE_LOCKED


static func _is_lower_snake_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text != text.to_lower():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


static func _invalid(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_class_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
