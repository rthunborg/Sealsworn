extends "res://tests/unit/test_case.gd"

# Story 5.4 — PassiveDefinition (the typed passive content resource, AC1/AC2/AC3).
# Story 6.4 — EXTENDED with the FR47 reward-modal fields + the FR77 served-pillar field (additive).
#
# Pins: construct stores every field; validate() accepts a good def + the six baselines; rejects a
# non-lower_snake passive_id, an empty display_name, a passive_kind outside the allowlist, empty
# trigger_windows, an invalid trigger window id, and an empty explanation (each on the right `field`); the
# fires_in_window helper; AND (AC3) that PassiveDefinition exposes NO active-skill field/method — it is a
# PASSIVE rule-bender, never an active class skill.
#
# Story 6.4 additions: the new @export fields store; validate() accepts a def carrying all new fields +
# >=1 pillar; validate() REJECTS (each on the right `field`) a non-lower_snake non-placeholder icon, a blank
# flavor / exact_mechanical_effects / consume_text / destroy_text, a blank consequences_text when
# has_unknown_consequences is false (AC3 unclear-downside), an EMPTY served_pillars (AC4 — the load-bearing
# mechanically-complete-but-pillarless reject), and a served_pillars carrying an out-of-allowlist pillar (AC4);
# the honest-unknown contract is SURFACED (has_unknown_consequences true + a consequences_text validates).

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
	# Story 6.4 — the FR47 modal fields + the FR77 served-pillar field.
	_construct_stores_the_new_modal_fields()
	_validate_accepts_a_definition_with_an_icon_placeholder()
	_validate_accepts_an_honest_unknown_consequence()
	_validate_rejects_a_non_lower_snake_icon()
	_validate_rejects_blank_flavor()
	_validate_rejects_blank_exact_mechanical_effects()
	_validate_rejects_blank_consume_text()
	_validate_rejects_blank_destroy_text()
	_validate_rejects_blank_consequences_text_when_not_unknown()
	_validate_rejects_empty_served_pillars()
	_validate_rejects_an_out_of_allowlist_pillar()
	_validate_rejects_a_mechanically_complete_but_pillarless_passive()
	return result()


func _good_passive() -> PassiveDefinition:
	return PassiveDefinition.new(
		&"warrior_unbreakable_guard",
		"Unbreakable Guard",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK],
		"Unbreakable Guard steels the hero before an incoming attack.",
		&"warrior_unbreakable_guard",
		"A scarred oath that will not bend.",
		"Reduces the next incoming attack's damage before it lands.",
		"Consume to take the guard into your build as permanent damage reduction.",
		"Destroy to purge the oath and cleanse a point of corruption.",
		false,
		"No hidden downside: the guard is exactly what it claims.",
		[PassiveDefinition.PILLAR_TACTICAL_CLARITY, PassiveDefinition.PILLAR_RISK]
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
	# An equipment-synergy passive with a run_started window also validates (Story 6.4: carrying the modal fields).
	var synergy: PassiveDefinition = PassiveDefinition.new(
		&"warrior_blade_and_board",
		"Blade and Board",
		PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
		[RuleTrigger.RUN_STARTED],
		"Blade and Board pairs sword and shield as the run begins.",
		PassiveDefinition.ICON_PLACEHOLDER,
		"Steel and oak, balanced.",
		"Links the equipped sword and shield as the run begins.",
		"Consume to lock in the pairing.",
		"Destroy to dissolve the pairing for salvage.",
		false,
		"No hidden cost.",
		[PassiveDefinition.PILLAR_BUILD_SYNERGY]
	)
	_validates(synergy, "A well-formed equipment-synergy passive should validate.")
	# A passive declaring MULTIPLE valid windows validates.
	var multi: PassiveDefinition = PassiveDefinition.new(
		&"multi_window_passive",
		"Multi Window",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK, RuleTrigger.DAMAGE_CALCULATED],
		"Fires across two windows.",
		PassiveDefinition.ICON_PLACEHOLDER,
		"It watches two moments at once.",
		"Bends both the attack and the damage calculation.",
		"Consume to keep both bends.",
		"Destroy to release both bends.",
		false,
		"No hidden cost.",
		[PassiveDefinition.PILLAR_MYSTERY]
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

	# The EXACT schema (Story 5.4 lean v0 + the Story 6.4 FR47 modal fields + the FR77 served-pillar field) — a
	# new field appearing here is an intentional schema change that must update this assertion (and, for an
	# active-skill field, would violate AC3). The Story 6.4 additions are reward-modal DATA + a served pillar,
	# NOT an active-skill concept.
	var expected_fields: Array[String] = [
		"passive_id",
		"display_name",
		"passive_kind",
		"trigger_windows",
		"explanation",
		"icon",
		"flavor",
		"exact_mechanical_effects",
		"consume_text",
		"destroy_text",
		"has_unknown_consequences",
		"consequences_text",
		"served_pillars"
	]
	assert_equal(property_names, expected_fields, "PassiveDefinition must expose EXACTLY the v0 schema + the Story 6.4 modal/pillar fields (no active-skill field).")

	# Representative active-skill concepts must be entirely absent (field OR method).
	for forbidden: String in ["active_skill", "skill_id", "level_1_skill", "activate", "cooldown", "is_active_skill"]:
		assert_false(forbidden in property_names, "PassiveDefinition must not declare an active-skill field '%s' (AC3)." % forbidden)
		assert_false(definition.has_method(forbidden), "PassiveDefinition must not expose an active-skill method '%s' (AC3)." % forbidden)


# ---- Story 6.4: the FR47 modal fields + the FR77 served-pillar field --------------------------------

func _construct_stores_the_new_modal_fields() -> void:
	var definition: PassiveDefinition = _good_passive()
	assert_equal(definition.icon, &"warrior_unbreakable_guard", "Passive should expose its icon id.")
	assert_equal(definition.flavor, "A scarred oath that will not bend.", "Passive should expose its flavor line.")
	assert_equal(definition.exact_mechanical_effects, "Reduces the next incoming attack's damage before it lands.", "Passive should expose its exact mechanical effects.")
	assert_equal(definition.consume_text, "Consume to take the guard into your build as permanent damage reduction.", "Passive should expose its Consume text.")
	assert_equal(definition.destroy_text, "Destroy to purge the oath and cleanse a point of corruption.", "Passive should expose its Destroy text.")
	assert_equal(definition.has_unknown_consequences, false, "Passive should expose its honest-unknown flag.")
	assert_equal(definition.consequences_text, "No hidden downside: the guard is exactly what it claims.", "Passive should expose its consequences text.")
	assert_equal(definition.served_pillars, [PassiveDefinition.PILLAR_TACTICAL_CLARITY, PassiveDefinition.PILLAR_RISK] as Array[StringName], "Passive should expose its served pillars.")
	# The pillar allowlist is the fixed four-pillar GDD vocabulary.
	assert_equal(PassiveDefinition.SERVED_PILLARS, [&"tactical_clarity", &"build_synergy", &"risk", &"mystery"] as Array[StringName], "The served-pillar allowlist must be the fixed four GDD pillars.")
	assert_equal(PassiveDefinition.ICON_PLACEHOLDER, &"passive_icon_placeholder", "The icon placeholder sentinel must be stable.")


func _validate_accepts_a_definition_with_an_icon_placeholder() -> void:
	# An art-less passive is VALID with the placeholder sentinel (never a crash, never an empty-icon surprise).
	var definition: PassiveDefinition = _good_passive()
	definition.icon = PassiveDefinition.ICON_PLACEHOLDER
	_validates(definition, "A passive using the icon placeholder sentinel should validate.")


func _validate_accepts_an_honest_unknown_consequence() -> void:
	# AC1: a passive whose downside is HONESTLY UNKNOWN validates (has_unknown_consequences true + an honest line).
	var definition: PassiveDefinition = _good_passive()
	definition.has_unknown_consequences = true
	definition.consequences_text = "Consequences of destroying this memory are unknown."
	_validates(definition, "A passive that honestly labels its consequences unknown should validate.")


func _validate_rejects_a_non_lower_snake_icon() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.icon = &"Unbreakable_Guard_Icon"
	_rejects_field(definition, &"icon", "A non-lower-snake (non-placeholder) icon id should be rejected.")


func _validate_rejects_blank_flavor() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.flavor = "   "
	_rejects_field(definition, &"flavor", "A blank flavor line should be rejected.")


func _validate_rejects_blank_exact_mechanical_effects() -> void:
	# AC1/AC3 — mechanics MUST be explicit even when flavor is mysterious; an empty mechanics string is invalid.
	var definition: PassiveDefinition = _good_passive()
	definition.exact_mechanical_effects = ""
	_rejects_field(definition, &"exact_mechanical_effects", "A blank exact-mechanical-effects string should be rejected (mechanics must be explicit).")


func _validate_rejects_blank_consume_text() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.consume_text = "   "
	_rejects_field(definition, &"consume_text", "A blank Consume text should be rejected.")


func _validate_rejects_blank_destroy_text() -> void:
	var definition: PassiveDefinition = _good_passive()
	definition.destroy_text = ""
	_rejects_field(definition, &"destroy_text", "A blank Destroy text should be rejected.")


func _validate_rejects_blank_consequences_text_when_not_unknown() -> void:
	# AC3 "unclear downside fields" — a passive must EITHER state a known downside OR honestly mark it unknown;
	# a blank consequences_text with has_unknown_consequences == false is the "we forgot to say" invalid case.
	var definition: PassiveDefinition = _good_passive()
	definition.has_unknown_consequences = false
	definition.consequences_text = "   "
	_rejects_field(definition, &"consequences_text", "A blank consequences text with no honest-unknown marker should be rejected.")


func _validate_rejects_empty_served_pillars() -> void:
	# AC4 — at least one served pillar is required.
	var definition: PassiveDefinition = _good_passive()
	definition.served_pillars = [] as Array[StringName]
	_rejects_field(definition, &"served_pillars", "An empty served-pillar list should be rejected (a passive must serve at least one pillar).")


func _validate_rejects_an_out_of_allowlist_pillar() -> void:
	# AC4 — every served pillar must be in the fixed four-pillar allowlist.
	var definition: PassiveDefinition = _good_passive()
	definition.served_pillars = [PassiveDefinition.PILLAR_RISK, &"made_up_pillar"] as Array[StringName]
	_rejects_field(definition, &"served_pillars", "A served-pillar list with any out-of-allowlist pillar should be rejected.")


func _validate_rejects_a_mechanically_complete_but_pillarless_passive() -> void:
	# AC4 LOAD-BEARING: a passive whose FR47 modal fields are all present + valid but that serves NO pillar is
	# INVALID — mechanical completeness does not excuse pillarlessness.
	var definition: PassiveDefinition = _good_passive()
	# Confirm the only thing wrong is the pillar set (everything else is the valid _good_passive content).
	definition.served_pillars = [] as Array[StringName]
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), "A mechanically-complete but pillarless passive must fail validation (AC4).")
	assert_equal(validation.metadata.get("field"), "served_pillars", "The pillarless reject must name served_pillars.")
