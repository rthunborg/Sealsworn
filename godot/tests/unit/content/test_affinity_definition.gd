extends "res://tests/unit/test_case.gd"

# Story 7.4 Task 1 — AffinityDefinition (the typed, validated affinity content definition, AC1/AC3). Covers the AC1
# surface (id, display name, tactical rules, visual tags, explanation text) + invalid content FAILING validation: each
# of the 4 MVP baselines + the neutral pass validate(); each per-field reject (a bad affinity_id, a blank display_name/
# explanation, a malformed tactical_rules entry, a non-lower_snake visual_tag); the neutral affinity has an EMPTY
# tactical_rules set + is_neutral() (AC3); a real affinity carries >= 1 rule marker + is NOT neutral. Mirrors
# test_cursed_reward_definition.gd / test_gold_reward_definition.gd (the typed-Resource validate() per-field shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")

func run() -> Dictionary:
	_baseline_definitions_validate()
	_a_valid_affinity_validates()
	_rejects_a_non_lower_snake_id()
	_rejects_a_blank_display_name()
	_rejects_a_blank_explanation()
	_rejects_a_malformed_tactical_rule_entry()
	_rejects_a_non_lower_snake_visual_tag()
	_the_neutral_affinity_has_an_empty_rule_set_and_is_neutral()
	_a_real_affinity_carries_a_rule_marker_and_is_not_neutral()
	_tactical_rules_copy_is_a_deep_read()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A genuine MVP-shaped affinity (a real id + display name + one rule marker + one visual tag + an explanation). Mutate
# one field per reject test.
func _valid_definition() -> AffinityDefinition:
	return AffinityDefinition.new(
		&"test_affinity",
		"Test Affinity",
		[
			{
				"rule_id": "test_pressure",
				"description": "A test affinity applies a readable tactical pressure."
			}
		],
		[&"test_affinity"] as Array[StringName],
		"A test affinity: a readable tactical identity surfaced honestly."
	)


# ---- the baseline + a valid definition -----------------------------------------------------------

func _baseline_definitions_validate() -> void:
	# Every baseline affinity (the 4 MVP + the neutral none) must validate (the repository build proves this, but
	# assert it directly here too).
	var repo: AffinityRepository = AffinityRepository.create_baseline_repository()
	assert_true(repo != null, "The baseline affinity repository must build (every baseline validates).")
	for affinity_id: StringName in AffinityRepository.BASELINE_AFFINITY_IDS:
		var definition: AffinityDefinition = repo.get_affinity(affinity_id)
		assert_true(definition != null, "Baseline affinity %s must resolve." % String(affinity_id))
		assert_true(definition.validate().succeeded, "Baseline affinity %s must validate." % String(affinity_id))
		assert_false(definition.display_name.strip_edges().is_empty(), "Baseline affinity %s must carry a non-empty display name." % String(affinity_id))
		assert_false(definition.explanation.strip_edges().is_empty(), "Baseline affinity %s must carry a non-empty explanation." % String(affinity_id))


func _a_valid_affinity_validates() -> void:
	assert_true(_valid_definition().validate().succeeded, "A genuine MVP-shaped affinity must validate.")


# ---- per-field rejects ---------------------------------------------------------------------------

func _assert_invalid_field(definition: AffinityDefinition, expected_field: String, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), "%s (must reject)." % message)
	assert_equal(validation.error_code, &"invalid_affinity_definition", "%s (stable code)." % message)
	assert_equal(String(validation.metadata.get("field")), expected_field, "%s (field in metadata)." % message)


func _rejects_a_non_lower_snake_id() -> void:
	var definition: AffinityDefinition = _valid_definition()
	definition.affinity_id = &"Bad-Id"
	_assert_invalid_field(definition, "affinity_id", "A non-lower_snake affinity_id")


func _rejects_a_blank_display_name() -> void:
	var definition: AffinityDefinition = _valid_definition()
	definition.display_name = "   "
	_assert_invalid_field(definition, "display_name", "A blank display_name")


func _rejects_a_blank_explanation() -> void:
	var definition: AffinityDefinition = _valid_definition()
	definition.explanation = ""
	_assert_invalid_field(definition, "explanation", "A blank explanation")


func _rejects_a_malformed_tactical_rule_entry() -> void:
	# A non-Dictionary entry is invalid.
	var non_dict: AffinityDefinition = _valid_definition()
	non_dict.tactical_rules = ["not_a_dictionary"]
	_assert_invalid_field(non_dict, "tactical_rules", "A non-Dictionary tactical_rules entry")

	# A non-lower_snake rule_id is invalid.
	var bad_rule_id: AffinityDefinition = _valid_definition()
	bad_rule_id.tactical_rules = [{"rule_id": "Bad-Rule", "description": "A description."}]
	_assert_invalid_field(bad_rule_id, "tactical_rules", "A non-lower_snake tactical_rules rule_id")

	# A blank description is invalid (the RECORD-ONLY data must carry a readable description).
	var blank_description: AffinityDefinition = _valid_definition()
	blank_description.tactical_rules = [{"rule_id": "valid_rule", "description": "   "}]
	_assert_invalid_field(blank_description, "tactical_rules", "A blank tactical_rules description")

	# A missing rule_id key (empty default) is invalid.
	var missing_rule_id: AffinityDefinition = _valid_definition()
	missing_rule_id.tactical_rules = [{"description": "A description with no rule id."}]
	_assert_invalid_field(missing_rule_id, "tactical_rules", "A missing tactical_rules rule_id")


func _rejects_a_non_lower_snake_visual_tag() -> void:
	var definition: AffinityDefinition = _valid_definition()
	definition.visual_tags = [&"Bad-Tag"] as Array[StringName]
	_assert_invalid_field(definition, "visual_tags", "A non-lower_snake visual_tag")


# ---- the neutral / no-affinity contract (AC3) ----------------------------------------------------

func _the_neutral_affinity_has_an_empty_rule_set_and_is_neutral() -> void:
	var neutral: AffinityDefinition = AffinityDefinition.neutral()
	assert_true(neutral.validate().succeeded, "The neutral affinity must validate (a neutral explanation, no rules, no tags).")
	assert_equal(neutral.affinity_id, AffinityDefinition.AFFINITY_NONE, "The neutral affinity reuses the AFFINITY_NONE id (&\"none\").")
	assert_true(neutral.tactical_rules.is_empty(), "AC3: the neutral affinity has an EMPTY tactical_rules set (no affinity side effects).")
	assert_true(neutral.visual_tags.is_empty(), "The neutral affinity has no visual tags.")
	assert_true(neutral.is_neutral(), "AC3: the neutral affinity reports is_neutral() == true.")
	assert_false(neutral.explanation.strip_edges().is_empty(), "The neutral affinity carries a non-empty neutral explanation (never blank).")
	# The baseline-registered none must also be the neutral definition.
	var repo: AffinityRepository = AffinityRepository.create_baseline_repository()
	var registered_none: AffinityDefinition = repo.get_affinity(AffinityDefinition.AFFINITY_NONE)
	assert_true(registered_none != null, "The baseline must register the neutral none affinity.")
	assert_true(registered_none.is_neutral(), "The baseline-registered none affinity must be neutral.")


func _a_real_affinity_carries_a_rule_marker_and_is_not_neutral() -> void:
	var repo: AffinityRepository = AffinityRepository.create_baseline_repository()
	for affinity_id: StringName in [&"scorched", &"flooded_conductive", &"cursed", &"darkness"]:
		var definition: AffinityDefinition = repo.get_affinity(affinity_id)
		assert_true(definition != null, "Real affinity %s must resolve." % String(affinity_id))
		assert_true(definition.tactical_rules.size() >= 1, "Real affinity %s must carry >= 1 rule marker (not an empty shell)." % String(affinity_id))
		assert_false(definition.is_neutral(), "Real affinity %s must NOT be neutral." % String(affinity_id))
		assert_true(definition.visual_tags.size() >= 1, "Real affinity %s must carry >= 1 visual tag (the art/cue hook)." % String(affinity_id))


func _tactical_rules_copy_is_a_deep_read() -> void:
	# tactical_rules_copy() returns a fresh deep copy — mutating it must not perturb the definition's stored rules.
	var definition: AffinityDefinition = _valid_definition()
	var copy_a: Array = definition.tactical_rules_copy()
	copy_a.append({"rule_id": "intruder", "description": "Should not leak back."})
	(copy_a[0] as Dictionary)["description"] = "Mutated."
	var copy_b: Array = definition.tactical_rules_copy()
	assert_equal(copy_b.size(), 1, "Mutating a returned tactical_rules copy must not change the stored rule count.")
	assert_equal(String((copy_b[0] as Dictionary).get("description")), "A test affinity applies a readable tactical pressure.", "Mutating a returned tactical_rules copy must not change the stored rule data.")
