extends "res://tests/unit/test_case.gd"

# Story 7.2 Task 1 — CursedRewardDefinition (the typed, validated cursed-reward content definition, AC1). Covers the
# AC1 tradeoff contract: a valid baseline passes validate(); each per-field reject (a bad id, blank display_name/
# upside_text/downside_text/consequences_text, negative benefit/penalty/cost ints, the NO-TRADEOFF reject); and the
# honest hidden/delayed-consequence both-states (a KNOWN downside + an honestly-unknown downside, BOTH valid with a
# non-blank consequences_text). Mirrors test_gold_reward_definition.gd / test_passive_definition.gd (the typed-Resource
# validate() per-field shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")

func run() -> Dictionary:
	_baseline_definitions_validate()
	_a_valid_cursed_reward_validates()
	_rejects_a_non_lower_snake_id()
	_rejects_a_blank_display_name()
	_rejects_a_blank_upside_text()
	_rejects_a_blank_downside_text()
	_rejects_a_blank_consequences_text()
	_rejects_a_negative_benefit_or_penalty_or_cost()
	_rejects_a_no_benefit_pure_penalty()
	_rejects_a_no_penalty_free_reward()
	_known_and_honestly_unknown_consequences_are_both_valid()
	_applies_curse_reflects_the_penalty()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A genuine-tradeoff cursed reward (a gold benefit + a curse increment + a known consequence line). Mutate one field
# per reject test.
func _valid_definition() -> CursedRewardDefinition:
	return CursedRewardDefinition.new(
		&"test_cursed_reward",
		"Test Cursed Reward",
		"Gain a clear upside worth a measure of gold.",
		"Pay a clear downside: a curse settles on you.",
		20,  # gold_benefit
		0,   # healing_benefit
		1,   # curse_increment
		0,   # corruption_increment
		0,   # gold_cost
		0,   # healing_cost
		false,
		"No hidden cost beyond the curse: the trade is exactly as stated."
	)


# ---- the baseline + a valid definition -----------------------------------------------------------

func _baseline_definitions_validate() -> void:
	# Every baseline cursed reward must validate (the repository build proves this, but assert it directly here too).
	var repo: CursedRewardRepository = CursedRewardRepository.create_baseline_repository()
	assert_true(repo != null, "The baseline cursed-reward repository must build (every baseline validates).")
	for cursed_reward_id: StringName in CursedRewardRepository.BASELINE_CURSED_REWARD_IDS:
		var definition: CursedRewardDefinition = repo.get_cursed_reward(cursed_reward_id)
		assert_true(definition != null, "Baseline cursed reward %s must resolve." % String(cursed_reward_id))
		assert_true(definition.validate().succeeded, "Baseline cursed reward %s must validate." % String(cursed_reward_id))


func _a_valid_cursed_reward_validates() -> void:
	assert_true(_valid_definition().validate().succeeded, "A genuine-tradeoff cursed reward must validate.")


# ---- per-field rejects ---------------------------------------------------------------------------

func _assert_invalid_field(definition: CursedRewardDefinition, expected_field: String, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), "%s (must reject)." % message)
	assert_equal(validation.error_code, &"invalid_cursed_reward_definition", "%s (stable code)." % message)
	assert_equal(String(validation.metadata.get("field")), expected_field, "%s (field in metadata)." % message)


func _rejects_a_non_lower_snake_id() -> void:
	var definition: CursedRewardDefinition = _valid_definition()
	definition.cursed_reward_id = &"Bad-Id"
	_assert_invalid_field(definition, "cursed_reward_id", "A non-lower_snake cursed_reward_id")


func _rejects_a_blank_display_name() -> void:
	var definition: CursedRewardDefinition = _valid_definition()
	definition.display_name = "   "
	_assert_invalid_field(definition, "display_name", "A blank display_name")


func _rejects_a_blank_upside_text() -> void:
	var definition: CursedRewardDefinition = _valid_definition()
	definition.upside_text = ""
	_assert_invalid_field(definition, "upside_text", "A blank upside_text")


func _rejects_a_blank_downside_text() -> void:
	var definition: CursedRewardDefinition = _valid_definition()
	definition.downside_text = ""
	_assert_invalid_field(definition, "downside_text", "A blank downside_text")


func _rejects_a_blank_consequences_text() -> void:
	# The honest-unknown contract: a blank consequences_text is INVALID regardless of has_delayed_consequences ("we
	# forgot to say"). This is the load-bearing AC1 honest-labeling reject.
	var definition: CursedRewardDefinition = _valid_definition()
	definition.consequences_text = "   "
	_assert_invalid_field(definition, "consequences_text", "A blank consequences_text")


func _rejects_a_negative_benefit_or_penalty_or_cost() -> void:
	var negative_gold_benefit: CursedRewardDefinition = _valid_definition()
	negative_gold_benefit.gold_benefit = -1
	_assert_invalid_field(negative_gold_benefit, "gold_benefit", "A negative gold_benefit")

	var negative_healing_benefit: CursedRewardDefinition = _valid_definition()
	negative_healing_benefit.healing_benefit = -1
	_assert_invalid_field(negative_healing_benefit, "healing_benefit", "A negative healing_benefit")

	var negative_curse: CursedRewardDefinition = _valid_definition()
	negative_curse.curse_increment = -1
	_assert_invalid_field(negative_curse, "curse_increment", "A negative curse_increment")

	var negative_corruption: CursedRewardDefinition = _valid_definition()
	negative_corruption.corruption_increment = -1
	_assert_invalid_field(negative_corruption, "corruption_increment", "A negative corruption_increment")

	var negative_gold_cost: CursedRewardDefinition = _valid_definition()
	negative_gold_cost.gold_cost = -1
	_assert_invalid_field(negative_gold_cost, "gold_cost", "A negative gold_cost")

	var negative_healing_cost: CursedRewardDefinition = _valid_definition()
	negative_healing_cost.healing_cost = -1
	_assert_invalid_field(negative_healing_cost, "healing_cost", "A negative healing_cost")


func _rejects_a_no_benefit_pure_penalty() -> void:
	# A cursed reward with a penalty but NO benefit is a pure penalty, not a tradeoff — rejected (the no-tradeoff rule).
	var definition: CursedRewardDefinition = _valid_definition()
	definition.gold_benefit = 0
	definition.healing_benefit = 0
	# curse_increment stays 1 (a penalty exists), so the missing side is the benefit.
	_assert_invalid_field(definition, "gold_benefit", "A no-benefit (pure penalty) cursed reward")


func _rejects_a_no_penalty_free_reward() -> void:
	# A cursed reward with a benefit but NO penalty is a free reward, not a tradeoff — rejected (the no-tradeoff rule).
	var definition: CursedRewardDefinition = _valid_definition()
	definition.curse_increment = 0
	definition.corruption_increment = 0
	definition.gold_cost = 0
	definition.healing_cost = 0
	# gold_benefit stays 20 (a benefit exists), so the missing side is the penalty.
	_assert_invalid_field(definition, "curse_increment", "A no-penalty (free reward) cursed reward")


# ---- the honest hidden/delayed-consequence both-states -------------------------------------------

func _known_and_honestly_unknown_consequences_are_both_valid() -> void:
	# A KNOWN-downside cursed reward (has_delayed_consequences == false + a concrete line) is valid.
	var known: CursedRewardDefinition = _valid_definition()
	known.has_delayed_consequences = false
	known.consequences_text = "The corruption is the whole cost; nothing else is hidden."
	assert_true(known.validate().succeeded, "A KNOWN-downside cursed reward with a non-blank consequences_text is valid.")

	# An honestly-UNKNOWN cursed reward (has_delayed_consequences == true + an honest unknown line) is ALSO valid — the
	# difference between hiding a consequence (invalid) and honestly labeling it (valid).
	var honest: CursedRewardDefinition = _valid_definition()
	honest.has_delayed_consequences = true
	honest.consequences_text = "Honestly unknown: a future penalty awaits, but its exact form cannot be read before you accept."
	assert_true(honest.validate().succeeded, "An honestly-unknown cursed reward with a non-blank consequences_text is valid + surfaced.")


# ---- applies_curse() -----------------------------------------------------------------------------

func _applies_curse_reflects_the_penalty() -> void:
	# applies_curse() is true when there is a curse/corruption increment (the AC3 seating gate).
	var with_curse: CursedRewardDefinition = _valid_definition()
	assert_true(with_curse.applies_curse(), "A cursed reward with a curse_increment applies a curse.")

	var corruption_only: CursedRewardDefinition = _valid_definition()
	corruption_only.curse_increment = 0
	corruption_only.corruption_increment = 1
	assert_true(corruption_only.applies_curse(), "A cursed reward with a corruption_increment applies a curse.")

	# A reward whose penalty is ONLY a resource cost (no curse/corruption) does NOT apply a curse (but is still a valid
	# tradeoff — a benefit + a gold_cost).
	var cost_only: CursedRewardDefinition = _valid_definition()
	cost_only.curse_increment = 0
	cost_only.corruption_increment = 0
	cost_only.gold_cost = 5
	assert_true(cost_only.validate().succeeded, "A benefit + a resource-cost-only cursed reward is a valid tradeoff.")
	assert_false(cost_only.applies_curse(), "A resource-cost-only cursed reward does NOT apply a curse.")
