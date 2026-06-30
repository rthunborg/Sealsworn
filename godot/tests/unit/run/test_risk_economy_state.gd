extends "res://tests/unit/test_case.gd"

# Story 7.1 Task 1 — RiskEconomyState (the run-domain risk-economy value object). Pins:
#   - AC1 defaults (gold/healing/curse/corruption 0; oath_shard_eligible derived; risk_flags empty);
#   - the exact DICTIONARY_KEYS to_dictionary() key set (a key never silently appears/vanishes — the StartingKit /
#     InventoryState precedent) + a real JSON round-trip;
#   - the lenient try_from_dictionary (a partial / pre-7.1 / surplus-key dict defaults cleanly + clamps negatives);
#   - copy() is a DEEP copy (mutating the copy's risk_flags must not perturb the source);
#   - the Oath-Shard eligibility INVARIANT (a manual-seed run is NEVER eligible — lockstep with the run's
#     meta_progression_eligible);
#   - the AC2 gold/healing apply + the FLOOR guard (a spend below 0 is rejected, no mutation), drawing ZERO RNG;
#   - the Story 7.2/7.3 STRUCTURAL setters (curse/corruption count + risk-flag add — container only, no rules).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")

func run() -> Dictionary:
	_defaults_are_zero_and_eligible()
	_for_run_derives_eligibility_from_manual_seed()
	_to_dictionary_emits_exactly_the_pinned_keys()
	_round_trips_through_real_json()
	_try_from_dictionary_is_lenient_on_partial_and_empty()
	_try_from_dictionary_clamps_negatives_and_drops_bad_flags()
	_copy_is_a_deep_copy()
	_returned_dictionary_mutation_does_not_perturb_a_fresh_projection()
	_eligibility_invariant_holds_for_both_seed_modes()
	_apply_gold_delta_credits_and_spends()
	_apply_gold_delta_floor_rejects_below_zero_with_no_mutation()
	_apply_healing_delta_credits_and_spends_with_floor()
	_structural_curse_and_corruption_setters_clamp()
	_structural_risk_flag_add_is_idempotent_and_lower_snake_only()
	return result()


# ---- AC1 defaults --------------------------------------------------------------------------------

func _defaults_are_zero_and_eligible() -> void:
	var state: RiskEconomyState = RiskEconomyState.new()
	assert_equal(state.gold, 0, "AC1: gold defaults to 0.")
	assert_equal(state.healing_charges, 0, "AC1: healing_charges defaults to 0.")
	assert_equal(state.curse_count, 0, "AC1: curse_count defaults to 0.")
	assert_equal(state.corruption, 0, "AC1: corruption defaults to 0.")
	assert_true(state.oath_shard_eligible, "AC1: oath_shard_eligible defaults true (a non-manual run is eligible).")
	assert_equal(state.risk_flags, [], "AC1: risk_flags defaults empty (v0 — 7.3 populates it).")


func _for_run_derives_eligibility_from_manual_seed() -> void:
	var manual: RiskEconomyState = RiskEconomyState.for_run(true)
	assert_false(manual.oath_shard_eligible, "AC1: a manual-seed run economy is NEVER Oath-Shard eligible.")
	var seeded: RiskEconomyState = RiskEconomyState.for_run(false)
	assert_true(seeded.oath_shard_eligible, "AC1: a non-manual run economy IS Oath-Shard eligible.")


# ---- exact-key contract --------------------------------------------------------------------------

func _to_dictionary_emits_exactly_the_pinned_keys() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(12, 2, 1, 3, true, ["salt_marked"])
	var data: Dictionary = state.to_dictionary()
	# Exactly the pinned key set (no surprise key, no missing key).
	assert_equal(data.keys().size(), RiskEconomyState.DICTIONARY_KEYS.size(), "to_dictionary() must emit exactly the pinned key count.")
	for key: String in RiskEconomyState.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must carry the pinned key '%s'." % key)
	for key: Variant in data.keys():
		assert_true(RiskEconomyState.DICTIONARY_KEYS.has(key), "to_dictionary() must not introduce a surprise key (%s)." % str(key))
	# Values project verbatim.
	assert_equal(data.get("gold"), 12, "gold projects verbatim.")
	assert_equal(data.get("healing_charges"), 2, "healing_charges projects verbatim.")
	assert_equal(data.get("curse_count"), 1, "curse_count projects verbatim.")
	assert_equal(data.get("corruption"), 3, "corruption projects verbatim.")
	assert_equal(data.get("oath_shard_eligible"), true, "oath_shard_eligible projects verbatim.")
	assert_equal(data.get("risk_flags"), ["salt_marked"], "risk_flags projects verbatim.")


func _round_trips_through_real_json() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(99, 5, 2, 4, false, ["salt_marked", "blood_debt"])
	var round_trip: Variant = JSON.parse_string(JSON.stringify(state.to_dictionary()))
	assert_true(round_trip is Dictionary, "The economy state must survive a JSON round-trip.")
	var restored: RiskEconomyState = RiskEconomyState.try_from_dictionary(round_trip)
	assert_equal(restored.gold, 99, "gold survives a JSON round-trip.")
	assert_equal(restored.healing_charges, 5, "healing_charges survives a JSON round-trip.")
	assert_equal(restored.curse_count, 2, "curse_count survives a JSON round-trip.")
	assert_equal(restored.corruption, 4, "corruption survives a JSON round-trip.")
	assert_false(restored.oath_shard_eligible, "oath_shard_eligible survives a JSON round-trip.")
	assert_equal(restored.risk_flags, ["salt_marked", "blood_debt"], "risk_flags survives a JSON round-trip.")


# ---- lenient decode ------------------------------------------------------------------------------

func _try_from_dictionary_is_lenient_on_partial_and_empty() -> void:
	# An EMPTY dict (a pre-7.1 run with no economy) decodes to the all-zero defaults.
	var empty: RiskEconomyState = RiskEconomyState.try_from_dictionary({})
	assert_equal(empty.gold, 0, "A pre-7.1/empty dict decodes gold to 0.")
	assert_equal(empty.healing_charges, 0, "A pre-7.1/empty dict decodes healing to 0.")
	assert_true(empty.oath_shard_eligible, "A pre-7.1/empty dict decodes eligibility to the default true.")
	assert_equal(empty.risk_flags, [], "A pre-7.1/empty dict decodes risk_flags to empty.")
	# A PARTIAL dict (only gold) decodes gold + defaults the rest.
	var partial: RiskEconomyState = RiskEconomyState.try_from_dictionary({"gold": 7})
	assert_equal(partial.gold, 7, "A partial dict decodes the present gold.")
	assert_equal(partial.corruption, 0, "A partial dict defaults an absent corruption to 0.")
	# An integral-float / decimal-string gold (JSON forms) decodes.
	var float_gold: RiskEconomyState = RiskEconomyState.try_from_dictionary({"gold": 8.0, "healing_charges": "3"})
	assert_equal(float_gold.gold, 8, "An integral-float gold decodes.")
	assert_equal(float_gold.healing_charges, 3, "A decimal-string healing decodes.")


func _try_from_dictionary_clamps_negatives_and_drops_bad_flags() -> void:
	# Negative counts clamp to 0 (a wallet/curse count is never negative); bad/non-lower_snake flags are dropped;
	# a non-bool eligibility defaults true.
	var state: RiskEconomyState = RiskEconomyState.try_from_dictionary({
		"gold": -5,
		"healing_charges": -1,
		"curse_count": -2,
		"corruption": -3,
		"oath_shard_eligible": "yes",
		"risk_flags": ["salt_marked", "Bad-Flag", 42, "", "blood_debt"]
	})
	assert_equal(state.gold, 0, "A negative gold clamps to 0.")
	assert_equal(state.healing_charges, 0, "A negative healing clamps to 0.")
	assert_equal(state.curse_count, 0, "A negative curse_count clamps to 0.")
	assert_equal(state.corruption, 0, "A negative corruption clamps to 0.")
	assert_true(state.oath_shard_eligible, "A non-bool eligibility defaults to true.")
	assert_equal(state.risk_flags, ["salt_marked", "blood_debt"], "Bad/non-lower_snake/blank/non-string flags are dropped; the rest survive (deduped, ordered).")


# ---- deep copy -----------------------------------------------------------------------------------

func _copy_is_a_deep_copy() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(10, 1, 0, 0, true, ["salt_marked"])
	var copied: RiskEconomyState = state.copy()
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(state.to_dictionary()), "copy() must preserve the economy byte-for-byte.")
	assert_true(copied != state, "copy() must produce a distinct instance.")
	# Mutating the copy's risk_flags must NOT perturb the source (a deep copy of the list).
	copied.add_risk_flag(&"blood_debt")
	assert_equal(state.risk_flags, ["salt_marked"], "Mutating the copy's risk_flags must not perturb the source (deep copy).")
	# Mutating the copy's gold must not perturb the source either.
	copied.apply_gold_delta(5)
	assert_equal(state.gold, 10, "Mutating the copy's gold must not perturb the source.")


func _returned_dictionary_mutation_does_not_perturb_a_fresh_projection() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(10, 0, 0, 0, true, ["salt_marked"])
	var data: Dictionary = state.to_dictionary()
	(data.get("risk_flags") as Array).append("injected")
	data["gold"] = 999
	# A FRESH projection is unaffected by a mutation of a prior returned dict.
	var fresh: Dictionary = state.to_dictionary()
	assert_equal(fresh.get("risk_flags"), ["salt_marked"], "Mutating a returned dict's risk_flags must not perturb a fresh projection.")
	assert_equal(fresh.get("gold"), 10, "Mutating a returned dict's gold must not perturb a fresh projection.")


# ---- AC1 eligibility invariant -------------------------------------------------------------------

func _eligibility_invariant_holds_for_both_seed_modes() -> void:
	# A non-manual run: eligible == true validates; eligible == false violates.
	var seeded: RiskEconomyState = RiskEconomyState.for_run(false)
	assert_true(seeded.validate(false).succeeded, "A non-manual eligible economy must validate against a non-manual run.")
	seeded.oath_shard_eligible = false
	var bad: ActionResult = seeded.validate(false)
	assert_true(bad.is_error(), "A non-manual run with oath_shard_eligible == false must violate the invariant.")
	assert_equal(bad.error_code, &"invalid_oath_shard_eligibility", "The eligibility violation must use the stable code.")
	# A manual run: eligible == false validates; eligible == true violates.
	var manual: RiskEconomyState = RiskEconomyState.for_run(true)
	assert_true(manual.validate(true).succeeded, "A manual ineligible economy must validate against a manual run.")
	manual.oath_shard_eligible = true
	assert_true(manual.validate(true).is_error(), "A manual run that claims eligibility must violate the invariant.")


# ---- AC2 gold / healing apply + floor ------------------------------------------------------------

func _apply_gold_delta_credits_and_spends() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(10)
	assert_equal(state.apply_gold_delta(5), 15, "A positive gold delta credits the wallet.")
	assert_equal(state.gold, 15, "The credited gold is recorded.")
	assert_equal(state.apply_gold_delta(-7), 8, "A negative gold delta spends from the wallet.")
	assert_equal(state.gold, 8, "The spent gold is recorded.")


func _apply_gold_delta_floor_rejects_below_zero_with_no_mutation() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(3)
	assert_false(state.can_apply_gold_delta(-4), "Spending more gold than held is not applicable (floor).")
	assert_equal(state.apply_gold_delta(-4), -1, "An over-spend returns -1 (the floor sentinel).")
	assert_equal(state.gold, 3, "An over-spend leaves gold unchanged (no mutation below 0).")
	assert_true(state.can_apply_gold_delta(-3), "Spending exactly the held gold IS applicable (lands at 0).")


func _apply_healing_delta_credits_and_spends_with_floor() -> void:
	var state: RiskEconomyState = RiskEconomyState.new(0, 2)
	assert_equal(state.apply_healing_delta(1), 3, "A positive healing delta adds availability.")
	assert_false(state.can_apply_healing_delta(-4), "Spending more healing than available is not applicable (floor).")
	assert_equal(state.apply_healing_delta(-4), -1, "An over-spend of healing returns -1.")
	assert_equal(state.healing_charges, 3, "An over-spend of healing leaves availability unchanged.")


# ---- Story 7.2/7.3 structural setters ------------------------------------------------------------

func _structural_curse_and_corruption_setters_clamp() -> void:
	var state: RiskEconomyState = RiskEconomyState.new()
	state.set_curse_count(2)
	assert_equal(state.curse_count, 2, "set_curse_count records a non-negative value.")
	state.set_curse_count(-1)
	assert_equal(state.curse_count, 0, "set_curse_count clamps a negative to 0.")
	state.set_corruption(5)
	assert_equal(state.corruption, 5, "set_corruption records a non-negative value.")
	state.set_corruption(-3)
	assert_equal(state.corruption, 0, "set_corruption clamps a negative to 0.")


func _structural_risk_flag_add_is_idempotent_and_lower_snake_only() -> void:
	var state: RiskEconomyState = RiskEconomyState.new()
	state.add_risk_flag(&"salt_marked")
	state.add_risk_flag(&"salt_marked")  # idempotent
	assert_equal(state.risk_flags, ["salt_marked"], "add_risk_flag is idempotent (a duplicate is not re-added).")
	assert_true(state.has_risk_flag(&"salt_marked"), "has_risk_flag finds a present flag.")
	state.add_risk_flag(&"Not-Snake")  # non-lower_snake ignored
	state.add_risk_flag(&"")  # blank ignored
	assert_equal(state.risk_flags, ["salt_marked"], "A non-lower_snake / blank flag is ignored.")
	state.add_risk_flag(&"blood_debt")
	assert_equal(state.risk_flags, ["salt_marked", "blood_debt"], "A second valid flag appends in order.")
