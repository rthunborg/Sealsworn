extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")

func run() -> Dictionary:
	_all_baseline_definitions_validate()
	_selectable_definition_exposes_full_identity_contract()
	_locked_definition_exposes_identity_contract_and_hint()
	_is_selectable_helper_reflects_lock_state()
	_validate_rejects_non_lower_snake_class_id()
	_validate_rejects_blank_display_name()
	_validate_rejects_unknown_lock_state()
	_validate_rejects_selectable_blank_starting_weapon_id()
	_validate_rejects_selectable_non_lower_snake_starting_weapon_id()
	_validate_rejects_selectable_non_lower_snake_starting_support_id()
	_validate_rejects_selectable_non_positive_baseline_hp()
	_validate_rejects_selectable_non_lower_snake_class_passive_id()
	_validate_rejects_selectable_non_lower_snake_equipment_synergy_passive_id()
	_validate_rejects_locked_blank_unlock_hint()
	return result()


func _selectable_warrior() -> ClassDefinition:
	return ClassDefinition.new(
		&"warrior",
		"Warrior",
		ClassDefinition.LOCK_STATE_SELECTABLE,
		"",
		&"sword",
		&"shield",
		18,
		&"warrior_unbreakable_guard",
		&"warrior_blade_and_board"
	)


func _locked_necromancer() -> ClassDefinition:
	return ClassDefinition.new(
		&"necromancer",
		"Necromancer",
		ClassDefinition.LOCK_STATE_LOCKED,
		"Unlocks after completing a run with each starting class."
	)


func _validates(definition: ClassDefinition, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.succeeded, "%s Validation error: %s" % [message, validation.metadata])


func _rejects_field(definition: ClassDefinition, expected_field: StringName, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), message)
	assert_equal(validation.error_code, &"invalid_class_definition", "%s should use the stable definition error code." % message)
	assert_equal(validation.metadata.get("reason"), "invalid_field", "%s should report an invalid field." % message)
	assert_equal(validation.metadata.get("field"), String(expected_field), "%s should name the offending field." % message)


func _all_baseline_definitions_validate() -> void:
	for definition: ClassDefinition in ClassRepository._baseline_definitions():
		_validates(definition, "Baseline class %s should validate." % String(definition.class_id))


func _selectable_definition_exposes_full_identity_contract() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	_validates(definition, "Baseline warrior should validate.")
	assert_equal(definition.class_id, &"warrior", "Class should expose its stable id.")
	assert_equal(definition.display_name, "Warrior", "Class should expose its human-facing display name.")
	assert_equal(definition.lock_state, ClassDefinition.LOCK_STATE_SELECTABLE, "Class should expose its lock state.")
	assert_equal(definition.starting_weapon_id, &"sword", "Class should expose its starting weapon id.")
	assert_equal(definition.starting_support_id, &"shield", "Class should expose its starting support id.")
	assert_equal(definition.baseline_hp, 18, "Class should expose its baseline HP.")
	assert_equal(definition.class_passive_id, &"warrior_unbreakable_guard", "Class should expose its class passive id.")
	assert_equal(definition.equipment_synergy_passive_id, &"warrior_blade_and_board", "Class should expose its equipment-synergy passive id.")
	assert_true(definition.is_selectable(), "A selectable class should report itself as selectable.")


func _locked_definition_exposes_identity_contract_and_hint() -> void:
	var definition: ClassDefinition = _locked_necromancer()
	_validates(definition, "Baseline necromancer should validate as a locked class.")
	assert_equal(definition.class_id, &"necromancer", "Locked class should expose its stable id.")
	assert_equal(definition.display_name, "Necromancer", "Locked class should expose its display name.")
	assert_equal(definition.lock_state, ClassDefinition.LOCK_STATE_LOCKED, "Locked class should expose the locked lock state.")
	assert_false(definition.unlock_hint.strip_edges().is_empty(), "Locked class should expose a non-empty unlock hint.")
	assert_false(definition.is_selectable(), "A locked class should not report itself as selectable.")


func _is_selectable_helper_reflects_lock_state() -> void:
	assert_true(_selectable_warrior().is_selectable(), "Selectable warrior should be selectable.")
	assert_false(_locked_necromancer().is_selectable(), "Locked necromancer should not be selectable.")


func _validate_rejects_non_lower_snake_class_id() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.class_id = &"Warrior"
	_rejects_field(definition, &"class_id", "Class with a non-lower-snake id should be rejected.")


func _validate_rejects_blank_display_name() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.display_name = "   "
	_rejects_field(definition, &"display_name", "Class with a blank display name should be rejected.")


func _validate_rejects_unknown_lock_state() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.lock_state = &"hidden"
	_rejects_field(definition, &"lock_state", "Class with an unknown lock state should be rejected.")


func _validate_rejects_selectable_blank_starting_weapon_id() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.starting_weapon_id = &""
	_rejects_field(definition, &"starting_weapon_id", "Selectable class with a blank starting weapon id should be rejected.")


func _validate_rejects_selectable_non_lower_snake_starting_weapon_id() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.starting_weapon_id = &"Long Sword"
	_rejects_field(definition, &"starting_weapon_id", "Selectable class with a non-lower-snake starting weapon id should be rejected.")


func _validate_rejects_selectable_non_lower_snake_starting_support_id() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.starting_support_id = &"Kite Shield"
	_rejects_field(definition, &"starting_support_id", "Selectable class with a non-lower-snake starting support id should be rejected.")


func _validate_rejects_selectable_non_positive_baseline_hp() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.baseline_hp = 0
	_rejects_field(definition, &"baseline_hp", "Selectable class with non-positive baseline HP should be rejected.")


func _validate_rejects_selectable_non_lower_snake_class_passive_id() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.class_passive_id = &""
	_rejects_field(definition, &"class_passive_id", "Selectable class with a blank class passive id should be rejected.")


func _validate_rejects_selectable_non_lower_snake_equipment_synergy_passive_id() -> void:
	var definition: ClassDefinition = _selectable_warrior()
	definition.equipment_synergy_passive_id = &"Blade And Board"
	_rejects_field(definition, &"equipment_synergy_passive_id", "Selectable class with a non-lower-snake equipment-synergy passive id should be rejected.")


func _validate_rejects_locked_blank_unlock_hint() -> void:
	var definition: ClassDefinition = _locked_necromancer()
	definition.unlock_hint = "   "
	_rejects_field(definition, &"unlock_hint", "Locked class with a blank unlock hint should be rejected.")
