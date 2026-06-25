extends "res://tests/unit/test_case.gd"

# Story 5.4 — PassiveDefinition (the typed passive content resource, AC1/AC2/AC3).
#
# Pins: construct stores every field; validate() accepts a good def + the six baselines; rejects a
# non-lower_snake passive_id, an empty display_name, a passive_kind outside the allowlist, empty
# trigger_windows, an invalid trigger window id, and an empty explanation (each on the right `field`); the
# fires_in_window helper; AND (AC3) that PassiveDefinition exposes NO active-skill field/method — it is a
# PASSIVE rule-bender, never an active class skill.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")

func run() -> Dictionary:
	_construct_stores_every_field()
	_validate_accepts_a_good_definition()
	_all_baseline_definitions_validate()
	_validate_rejects_non_lower_snake_passive_id()
	_validate_rejects_blank_display_name()
	_validate_rejects_unknown_passive_kind()
	_validate_rejects_empty_trigger_windows()
	_validate_rejects_an_invalid_trigger_window()
	_validate_rejects_blank_explanation()
	_fires_in_window_reflects_declared_windows()
	_passive_definition_has_no_active_skill_field()
	return result()


func _good_passive() -> PassiveDefinition:
	return PassiveDefinition.new(
		&"warrior_unbreakable_guard",
		"Unbreakable Guard",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK],
		"Unbreakable Guard steels the hero before an incoming attack."
	)


func _validates(definition: PassiveDefinition, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.succeeded, "%s Validation error: %s" % [message, validation.metadata])


func _rejects_field(definition: PassiveDefinition, expected_field: StringName, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), message)
	assert_equal(validation.error_code, &"invalid_passive_definition", "%s should use the stable definition error code." % message)
	assert_equal(validation.metadata.get("reason"), "invalid_field", "%s should report an invalid field." % message)
	assert_equal(validation.metadata.get("field"), String(expected_field), "%s should name the offending field." % message)


func _construct_stores_every_field() -> void:
	var definition: PassiveDefinition = _good_passive()
	assert_equal(definition.passive_id, &"warrior_unbreakable_guard", "Passive should expose its stable id.")
	assert_equal(definition.display_name, "Unbreakable Guard", "Passive should expose its display name.")
	assert_equal(definition.passive_kind, PassiveDefinition.KIND_CLASS, "Passive should expose its kind.")
	assert_equal(definition.trigger_windows, [RuleTrigger.BEFORE_ATTACK] as Array[StringName], "Passive should expose its trigger windows.")
	assert_equal(definition.explanation, "Unbreakable Guard steels the hero before an incoming attack.", "Passive should expose its explanation.")
	assert_equal(PassiveDefinition.DEFINITION_TYPE, &"passive", "The definition type should be the stable lower_snake 'passive'.")


func _validate_accepts_a_good_definition() -> void:
	_validates(_good_passive(), "A well-formed passive should validate.")
	# An equipment-synergy passive with a run_started window also validates.
	var synergy: PassiveDefinition = PassiveDefinition.new(
		&"warrior_blade_and_board",
		"Blade and Board",
		PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
		[RuleTrigger.RUN_STARTED],
		"Blade and Board pairs sword and shield as the run begins."
	)
	_validates(synergy, "A well-formed equipment-synergy passive should validate.")
	# A passive declaring MULTIPLE valid windows validates.
	var multi: PassiveDefinition = PassiveDefinition.new(
		&"multi_window_passive",
		"Multi Window",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK, RuleTrigger.DAMAGE_CALCULATED],
		"Fires across two windows."
	)
	_validates(multi, "A passive declaring multiple valid windows should validate.")


func _all_baseline_definitions_validate() -> void:
	for definition: PassiveDefinition in PassiveRepository._baseline_definitions():
		_validates(definition, "Baseline passive %s should validate." % String(definition.passive_id))


func _validate_rejects_non_lower_snake_passive_id() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.passive_id = &"Unbreakable_Guard"
	_rejects_field(definition, &"passive_id", "A non-lower-snake passive id should be rejected.")


func _validate_rejects_blank_display_name() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.display_name = "   "
	_rejects_field(definition, &"display_name", "A blank display name should be rejected.")


func _validate_rejects_unknown_passive_kind() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.passive_kind = &"active"
	_rejects_field(definition, &"passive_kind", "A passive kind outside the allowlist should be rejected.")


func _validate_rejects_empty_trigger_windows() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.trigger_windows = [] as Array[StringName]
	_rejects_field(definition, &"trigger_windows", "An empty trigger-window list should be rejected (a passive must declare at least one).")


func _validate_rejects_an_invalid_trigger_window() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.trigger_windows = [&"not_a_real_window"] as Array[StringName]
	_rejects_field(definition, &"trigger_windows", "A trigger window outside the fixed vocabulary should be rejected.")
	# A mix of one valid + one invalid window is still rejected (every window is checked).
	var mixed: PassiveDefinition = _good_passive()
	mixed.trigger_windows = [RuleTrigger.BEFORE_ATTACK, &"made_up_window"] as Array[StringName]
	_rejects_field(mixed, &"trigger_windows", "A trigger-window list with any invalid window should be rejected.")


func _validate_rejects_blank_explanation() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.explanation = "   "
	_rejects_field(definition, &"explanation", "A blank explanation should be rejected.")


func _fires_in_window_reflects_declared_windows() -> void:
	var definition: PassiveDefinition = _good_passive()
	assert_true(definition.fires_in_window(RuleTrigger.BEFORE_ATTACK), "A passive should fire in its declared window.")
	assert_false(definition.fires_in_window(RuleTrigger.RUN_STARTED), "A passive should NOT fire in a window it did not declare.")
	assert_false(definition.fires_in_window(&"not_a_real_window"), "A passive should NOT fire in an unknown window.")


# AC3: PassiveDefinition is PASSIVE-only — there is NO active-skill field/method. Assert the EXACT property
# set (so a future active-skill field is caught), and that representative active-skill accessor names are
# absent.
func _passive_definition_has_no_active_skill_field() -> void:
	var definition: PassiveDefinition = _good_passive()
	var property_names: Array[String] = []
	for property_info: Dictionary in definition.get_property_list():
		var usage: int = int(property_info.get("usage", 0))
		# Only script-declared storage/editor properties (the @export fields), not engine/script internals.
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			property_names.append(String(property_info.get("name", "")))

	# The EXACT lean v0 schema (Task 2.1) — a new field appearing here is an intentional schema change that
	# must update this assertion (and, for an active-skill field, would violate AC3).
	var expected_fields: Array[String] = [
		"passive_id",
		"display_name",
		"passive_kind",
		"trigger_windows",
		"explanation"
	]
	assert_equal(property_names, expected_fields, "PassiveDefinition must expose EXACTLY the lean v0 schema (no active-skill field).")

	# Representative active-skill concepts must be entirely absent (field OR method).
	for forbidden: String in ["active_skill", "skill_id", "level_1_skill", "activate", "cooldown", "is_active_skill"]:
		assert_false(forbidden in property_names, "PassiveDefinition must not declare an active-skill field '%s' (AC3)." % forbidden)
		assert_false(definition.has_method(forbidden), "PassiveDefinition must not expose an active-skill method '%s' (AC3)." % forbidden)
