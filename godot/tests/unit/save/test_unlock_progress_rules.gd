extends "res://tests/unit/test_case.gd"

# Story 8.4 Task 4/6 (AC3, FR95): the UnlockProgressRules threshold rule — deterministic, capped, idempotent, ZERO-RNG. A
# threshold crossing is DETERMINISTIC (same merged state -> same crossings) + CAPPED (a finite set of flags) + idempotent
# (re-crossing an already-flipped threshold is a no-op); a crossing reports the unlock state change; the rule does NOT
# mutate its input; and it produces NO raw-stat unlock key (AC3 / FR95 — meta power widens variety/options, never a
# repeatable raw combat stat). Mirrors test_meta_award_rules.gd (the pure-calculator template).

const UnlockProgressRules = preload("res://scripts/save/unlock_progress_rules.gd")

func run() -> Dictionary:
	_first_threshold_crosses_at_its_required_count()
	_below_threshold_crosses_nothing()
	_second_threshold_crosses_at_higher_count()
	_recrossing_an_already_flipped_threshold_is_a_no_op()
	_evaluation_is_deterministic()
	_evaluation_does_not_mutate_the_input()
	_no_threshold_produces_a_raw_stat_unlock_key()
	_thresholds_are_capped_and_finite()
	_raw_stat_key_classifier_flags_the_rejected_vocabulary()
	return result()


func _first_threshold_crosses_at_its_required_count() -> void:
	# seal_gate_1 crosses at exactly 1 discovered Seal Fragment and flips its state flag.
	var state: Dictionary = {UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a"]}
	var evaluation: Dictionary = UnlockProgressRules.evaluate(state)

	var crossed: Array = evaluation.get("thresholds_crossed")
	assert_true(crossed.has("seal_gate_1"), "1 Seal Fragment must cross seal_gate_1.")
	assert_true(bool((evaluation.get("state") as Dictionary).get("seal_gate_1_unlocked")), "Crossing seal_gate_1 must flip its state flag.")
	# The higher threshold has NOT crossed yet.
	assert_false(crossed.has("seal_gate_2"), "1 Seal Fragment must NOT cross seal_gate_2 (needs 3).")


func _below_threshold_crosses_nothing() -> void:
	# Zero Seal Fragments crosses no threshold.
	var evaluation: Dictionary = UnlockProgressRules.evaluate({UnlockProgressRules.SEAL_FRAGMENTS_KEY: []})
	assert_true((evaluation.get("thresholds_crossed") as Array).is_empty(), "0 Seal Fragments crosses no threshold.")

	# A missing seal_fragments key is a fail-safe 0 (crosses nothing).
	var missing_evaluation: Dictionary = UnlockProgressRules.evaluate({})
	assert_true((missing_evaluation.get("thresholds_crossed") as Array).is_empty(), "A missing seal_fragments key crosses no threshold (fail-safe 0).")


func _second_threshold_crosses_at_higher_count() -> void:
	# 3 Seal Fragments crosses BOTH seal_gate_1 (>=1) and seal_gate_2 (>=3) in one evaluation (a fresh profile).
	var state: Dictionary = {UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a", "seal_b", "seal_c"]}
	var evaluation: Dictionary = UnlockProgressRules.evaluate(state)
	var crossed: Array = evaluation.get("thresholds_crossed")
	assert_true(crossed.has("seal_gate_1"), "3 Seal Fragments crosses seal_gate_1.")
	assert_true(crossed.has("seal_gate_2"), "3 Seal Fragments crosses seal_gate_2.")
	assert_true(bool((evaluation.get("state") as Dictionary).get("seal_gate_2_unlocked")), "Crossing seal_gate_2 must flip its state flag.")


func _recrossing_an_already_flipped_threshold_is_a_no_op() -> void:
	# AC3 "flips ONCE": evaluating a state whose seal_gate_1 flag is ALREADY set does NOT re-cross it (idempotent).
	var state: Dictionary = {
		UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a", "seal_b"],
		"seal_gate_1_unlocked": true
	}
	var evaluation: Dictionary = UnlockProgressRules.evaluate(state)
	var crossed: Array = evaluation.get("thresholds_crossed")
	assert_false(crossed.has("seal_gate_1"), "An already-flipped threshold must NOT re-cross (idempotent).")
	# The flag stays true (unchanged).
	assert_true(bool((evaluation.get("state") as Dictionary).get("seal_gate_1_unlocked")), "The already-set flag stays set.")

	# A second evaluation of the RESULT crosses nothing at all (fully saturated for that count).
	var second: Dictionary = UnlockProgressRules.evaluate(evaluation.get("state"))
	assert_true((second.get("thresholds_crossed") as Array).is_empty(), "Re-evaluating a saturated state crosses nothing (idempotent).")


func _evaluation_is_deterministic() -> void:
	# Same merged state -> same crossings + same resulting state, every time (ZERO RNG — a deterministic calculation).
	var state: Dictionary = {UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a", "seal_b", "seal_c"]}
	var first: Dictionary = UnlockProgressRules.evaluate(state.duplicate(true))
	var second: Dictionary = UnlockProgressRules.evaluate(state.duplicate(true))
	assert_equal(second.get("thresholds_crossed"), first.get("thresholds_crossed"), "The crossings must be deterministic (twice -> identical).")
	assert_equal(second.get("state"), first.get("state"), "The resulting state must be deterministic (twice -> identical).")


func _evaluation_does_not_mutate_the_input() -> void:
	# The rule returns a fresh state; it does NOT mutate its input (a pure read — the caller applies the result).
	var state: Dictionary = {UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a"]}
	var before: Dictionary = state.duplicate(true)
	UnlockProgressRules.evaluate(state)
	assert_equal(state, before, "evaluate() must NOT mutate its input (a pure read).")


func _no_threshold_produces_a_raw_stat_unlock_key() -> void:
	# AC3 / FR95: no crossing produces a raw-stat unlock key (damage/max-HP/armor/crit/dodge). The resulting state carries
	# only variety/knowledge flags + the seal-fragment set + (possibly) bookkeeping — never a raw combat stat.
	var state: Dictionary = {UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a", "seal_b", "seal_c"]}
	var evaluation: Dictionary = UnlockProgressRules.evaluate(state)
	for key_value: Variant in (evaluation.get("state") as Dictionary).keys():
		assert_false(UnlockProgressRules.is_raw_stat_unlock_key(String(key_value)), "No unlock-progress key may be a raw-stat key (AC3/FR95): %s" % String(key_value))


func _thresholds_are_capped_and_finite() -> void:
	# AC3 "capped": a huge Seal-Fragment count crosses only the FINITE declared threshold set (no unbounded ladder). Even
	# 100 fragments produces at most SEAL_FRAGMENT_THRESHOLDS.size() crossings.
	var many: Array = []
	for index: int in range(100):
		many.append("seal_%d" % index)
	var evaluation: Dictionary = UnlockProgressRules.evaluate({UnlockProgressRules.SEAL_FRAGMENTS_KEY: many})
	assert_equal((evaluation.get("thresholds_crossed") as Array).size(), UnlockProgressRules.SEAL_FRAGMENT_THRESHOLDS.size(), "A huge count crosses only the FINITE declared threshold set (capped, no unbounded ladder).")


func _raw_stat_key_classifier_flags_the_rejected_vocabulary() -> void:
	# The is_raw_stat_unlock_key classifier flags the AC3-rejected raw-stat vocabulary and passes a variety flag.
	assert_true(UnlockProgressRules.is_raw_stat_unlock_key("bonus_damage"), "A damage key is a raw-stat key (rejected).")
	assert_true(UnlockProgressRules.is_raw_stat_unlock_key("max_hp_up"), "A max-HP key is a raw-stat key (rejected).")
	assert_true(UnlockProgressRules.is_raw_stat_unlock_key("armor_tier"), "An armor key is a raw-stat key (rejected).")
	assert_true(UnlockProgressRules.is_raw_stat_unlock_key("crit_chance"), "A crit key is a raw-stat key (rejected).")
	assert_true(UnlockProgressRules.is_raw_stat_unlock_key("dodge_rating"), "A dodge key is a raw-stat key (rejected).")
	assert_false(UnlockProgressRules.is_raw_stat_unlock_key("seal_gate_1_unlocked"), "A variety unlock flag is NOT a raw-stat key.")
	assert_false(UnlockProgressRules.is_raw_stat_unlock_key("variety_pool_tier"), "A variety-pool key is NOT a raw-stat key.")
