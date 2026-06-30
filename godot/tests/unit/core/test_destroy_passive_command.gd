extends "res://tests/unit/test_case.gd"

# Story 6.6 Task 5 — DestroyPassiveCommand (the DESTROY-passive command, the second half of the FR82
# Consume/Destroy split). Covers AC1 (a valid Destroy validates the pending passive offer, ROLLS a deterministic
# 70/20/10 outcome through the run-level RngStreamSet `rewards` stream, flips the offer to `resolved` + records the
# selected entry, leaves run.rules_resolver UNTOUCHED — Destroy does NOT adopt, and emits EXACTLY ONE
# passive_destroyed event carrying the rolled outcome + draw provenance), AC2 (DETERMINISM same-seed -> same-outcome
# + named-stream-only: only the `rewards` stream advances; the production file draws NO randi/randf), and AC4 (the
# load-bearing no-double-destroy + the fail-closed/no-mutation rejections + Consume/Destroy mutual exclusion).
#
# Mirrors test_consume_passive_command.gd (the run-command valid/invalid/no-mutation shape). DestroyPassive is a
# DISTINCT command from ConsumePassive: it ROLLS RNG (Consume draws zero), it does NOT register the passive (Consume
# adopts), and it emits passive_destroyed (NOT passive_consumed / reward_resolved — no double-record).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumePassiveCommand = preload("res://scripts/core/commands/consume_passive_command.gd")
const DestroyOutcomeTableDefinition = preload("res://scripts/content/definitions/destroy_outcome_table_definition.gd")
const DestroyPassiveCommand = preload("res://scripts/core/commands/destroy_passive_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_destroys_a_passive_rolls_an_outcome_flips_the_offer_and_emits_one_event()
	_destroy_does_not_register_the_passive_into_the_resolver()
	_destroy_is_deterministic_per_seed_and_advances_only_the_rewards_stream()
	_pick_outcome_maps_each_roll_value_to_its_cumulative_weight_boundary()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_a_missing_or_incomplete_rng_stream_set()
	_rejects_invalid_context()
	_rejects_when_no_pending_offer()
	_rejects_a_non_offered_passive_selection()
	_rejects_an_offered_passive_that_does_not_resolve_unknown_passive()
	_rejects_an_invalid_outcome_table()
	_duplicate_destroy_against_a_resolved_offer_rejects_no_double_destroy()
	_consume_then_destroy_is_mutually_exclusive_on_one_offer()
	_destroy_draws_no_rng_on_reject()
	# Story 7.2 Task 6 — the CLEANSE hook (curse reduction off the cleanse outcome).
	_cleanse_outcome_reduces_curse_and_emits_a_negative_delta_event()
	_cleanse_reduces_corruption_when_no_curse_remains()
	_cleanse_floors_at_zero_when_nothing_to_cleanse()
	_a_non_cleanse_outcome_leaves_curse_and_corruption_unchanged()
	_cleanse_draws_no_additional_rng()
	return result()


# ---- Story 7.2 Task 6: the CLEANSE hook helpers --------------------------------------------------

# A single-entry outcome table that ALWAYS rolls the cleanse outcome (minor_restoration). It uses the sanctioned
# mvp_distribution_exception marker (WITH a reason) so an off-70/20/10 single-entry test table is VALID — this makes
# the cleanse deterministic without depending on which seed lands the 70% band.
func _always_cleanse_table() -> DestroyOutcomeTableDefinition:
	return DestroyOutcomeTableDefinition.new(
		&"always_cleanse_test_table",
		[
			{
				"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT,
				"outcome_id": DestroyPassiveCommand.CLEANSE_OUTCOME_ID,
				"weight": 1,
				"effect": "destroy_outcome_small_immediate_benefit",
				"explanation": "Destroying the passive releases its bound energy as a cleansed wound."
			}
		],
		true,
		"Test-only single-entry table to deterministically exercise the cleanse outcome."
	)


# A single-entry outcome table that NEVER rolls the cleanse outcome (a non-cleanse small_immediate_benefit id).
func _never_cleanse_table() -> DestroyOutcomeTableDefinition:
	return DestroyOutcomeTableDefinition.new(
		&"never_cleanse_test_table",
		[
			{
				"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT,
				"outcome_id": &"some_other_benefit",
				"weight": 1,
				"effect": "destroy_outcome_small_immediate_benefit",
				"explanation": "Destroying the passive yields a small benefit that is not a cleanse."
			}
		],
		true,
		"Test-only single-entry non-cleanse table."
	)


func _cleanse_outcome_reduces_curse_and_emits_a_negative_delta_event() -> void:
	# A run carrying a curse; a Destroy that lands the cleanse outcome REDUCES curse_count by 1 + emits a curse_applied
	# event with a NEGATIVE delta (the signed-delta path), curse_source = the cleanse marker.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	run.risk_economy.set_curse_count(2)
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, _always_cleanse_table()).execute(run)
	assert_true(destroyed.succeeded, "A cleanse-outcome destroy should succeed: %s" % destroyed.metadata)

	assert_equal(run.risk_economy.curse_count, 1, "The cleanse REDUCES curse_count by 1 (2 -> 1).")
	# Two events: passive_destroyed (the existing) + curse_applied (the cleanse record).
	assert_equal(destroyed.events.size(), 2, "A cleanse emits the passive_destroyed event PLUS a curse_applied cleanse event.")
	assert_equal(destroyed.events[0].event_type, DomainEvent.Type.PASSIVE_DESTROYED, "The first event stays passive_destroyed.")
	var cleanse_event: DomainEvent = destroyed.events[1]
	assert_equal(cleanse_event.event_type, DomainEvent.Type.CURSE_APPLIED, "The second event is the curse_applied cleanse record.")
	assert_equal(String(cleanse_event.payload.get("curse_source")), "passive_destroyed_cleanse", "The cleanse event identifies the cleanse source.")
	assert_equal(int(cleanse_event.payload.get("curse_before")), 2, "The cleanse event records curse_before.")
	assert_equal(int(cleanse_event.payload.get("curse_after")), 1, "The cleanse event records curse_after.")
	assert_equal(int(cleanse_event.payload.get("curse_delta")), -1, "The cleanse event records a NEGATIVE curse_delta (the signed-delta path).")
	# Distinct sequence ids (passive_destroyed at 1, the cleanse at 2) so the round-trip never collides.
	assert_equal(cleanse_event.sequence_id, 2, "The cleanse event uses sequence_id + 1 (unique).")
	# The cleanse event passes a real JSON round-trip.
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(cleanse_event.to_dictionary())))
	assert_true(parsed.succeeded, "The cleanse curse_applied event should pass payload validation: %s" % parsed.metadata)
	assert_true(bool(destroyed.metadata.get("cleansed")), "The metadata flags a cleanse.")


func _cleanse_reduces_corruption_when_no_curse_remains() -> void:
	# A run with NO curse but some corruption: the cleanse reduces corruption instead (cleanse the deeper taint).
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	run.risk_economy.set_curse_count(0)
	run.risk_economy.set_corruption(3)
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, _always_cleanse_table()).execute(run)
	assert_true(destroyed.succeeded, "A cleanse-outcome destroy should succeed: %s" % destroyed.metadata)
	assert_equal(run.risk_economy.curse_count, 0, "Curse stays 0 (none to reduce).")
	assert_equal(run.risk_economy.corruption, 2, "The cleanse reduces corruption by 1 when no curse remains (3 -> 2).")
	var cleanse_event: DomainEvent = destroyed.events[1]
	assert_equal(int(cleanse_event.payload.get("corruption_delta")), -1, "The cleanse event records a negative corruption_delta.")
	assert_equal(int(cleanse_event.payload.get("curse_delta")), 0, "The cleanse event records a zero curse_delta when only corruption was reduced.")


func _cleanse_floors_at_zero_when_nothing_to_cleanse() -> void:
	# A run with NO curse and NO corruption: the cleanse outcome reduces nothing (floored at 0) and emits NO curse_applied
	# event (nothing was cleansed — only the passive_destroyed event).
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	assert_equal(run.risk_economy.curse_count, 0, "Setup: no curse.")
	assert_equal(run.risk_economy.corruption, 0, "Setup: no corruption.")
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, _always_cleanse_table()).execute(run)
	assert_true(destroyed.succeeded, "A cleanse-outcome destroy with nothing to cleanse should still succeed: %s" % destroyed.metadata)
	assert_equal(run.risk_economy.curse_count, 0, "Cleansing below 0 stays 0 (curse).")
	assert_equal(run.risk_economy.corruption, 0, "Cleansing below 0 stays 0 (corruption).")
	assert_equal(destroyed.events.size(), 1, "Cleansing nothing emits NO curse_applied event (only passive_destroyed).")
	assert_false(bool(destroyed.metadata.get("cleansed")), "The metadata reflects no cleanse occurred.")


func _a_non_cleanse_outcome_leaves_curse_and_corruption_unchanged() -> void:
	# A Destroy whose rolled outcome is NOT the cleanse outcome reduces NO curse/corruption (the existing behavior is
	# unchanged for non-cleanse outcomes) and emits ONLY the passive_destroyed event.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	run.risk_economy.set_curse_count(2)
	run.risk_economy.set_corruption(2)
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, _never_cleanse_table()).execute(run)
	assert_true(destroyed.succeeded, "A non-cleanse destroy should succeed: %s" % destroyed.metadata)
	assert_equal(run.risk_economy.curse_count, 2, "A non-cleanse outcome leaves curse_count unchanged.")
	assert_equal(run.risk_economy.corruption, 2, "A non-cleanse outcome leaves corruption unchanged.")
	assert_equal(destroyed.events.size(), 1, "A non-cleanse outcome emits ONLY the passive_destroyed event.")
	assert_false(bool(destroyed.metadata.get("cleansed")), "A non-cleanse outcome does not flag a cleanse.")


func _cleanse_draws_no_additional_rng() -> void:
	# The cleanse rides the EXISTING single 70/20/10 roll — it adds NO second RNG draw. The rewards stream advances
	# exactly once (draw_index 0 -> 1), the same as a non-cleanse destroy.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	run.risk_economy.set_curse_count(2)
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, _always_cleanse_table()).execute(run)
	assert_true(destroyed.succeeded, "The cleanse destroy should succeed: %s" % destroyed.metadata)
	var snapshot: Dictionary = streams.to_snapshot()
	var stream_states: Dictionary = snapshot.get("streams")
	assert_equal(int((stream_states.get("rewards") as Dictionary).get("draw_index")), 1, "The cleanse adds NO second draw: the rewards stream advances exactly once (0 -> 1).")
	for other_stream: String in ["map", "level", "combat", "loot", "events", "cosmetic"]:
		assert_equal(int((stream_states.get(other_stream) as Dictionary).get("draw_index")), 0, "The cleanse touches no other stream (%s stays at 0)." % other_stream)


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice WITH a pending passive offer carrying the given entries.
func _run_with_passive_offer(table_id: StringName, offered_entries: Array) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	run.pending_reward_offer = RewardOffer.new(table_id, RewardOffer.STATUS_PENDING, offered_entries, {}, "rewards", 1, 0, 42)
	assert_true(run.validate().succeeded, "Setup: the run with a passive offer should validate.")
	return run


func _baseline_offered_entries() -> Array:
	return [
		{"category": "passive", "content_id": "warrior_unbreakable_guard"},
		{"category": "passive", "content_id": "ranger_steady_aim"}
	]


# ---- AC1: successful destroy ---------------------------------------------------------------------

func _destroys_a_passive_rolls_an_outcome_flips_the_offer_and_emits_one_event() -> void:
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()

	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	assert_true(destroyed.succeeded, "Destroying a passive should succeed: %s" % destroyed.metadata)

	# The offer flipped to resolved + recorded the selected entry (the ResolveReward offer-flip posture).
	assert_true(run.pending_reward_offer.is_resolved(), "The offer must flip to resolved after a successful destroy.")
	assert_equal(String(run.pending_reward_offer.selected_entry.get("content_id")), "warrior_unbreakable_guard", "The offer must record the selected passive entry.")
	assert_equal(String(run.pending_reward_offer.selected_entry.get("category")), "passive", "The selected entry must be the passive category.")

	# EXACTLY ONE passive_destroyed event (no reward_resolved, no passive_consumed — do NOT double-record).
	assert_equal(destroyed.events.size(), 1, "A destroy should emit EXACTLY ONE event.")
	var event: DomainEvent = destroyed.events[0]
	assert_equal(event.event_type, DomainEvent.Type.PASSIVE_DESTROYED, "A destroy should emit a passive_destroyed event.")
	for emitted: DomainEvent in destroyed.events:
		assert_false(emitted.event_type == DomainEvent.Type.REWARD_RESOLVED, "A destroy must NOT emit a reward_resolved event (no double-record).")
		assert_false(emitted.event_type == DomainEvent.Type.PASSIVE_CONSUMED, "A destroy must NOT emit a passive_consumed event (Destroy is not Consume).")

	# The payload carries the passive id + table id + a VALID rolled outcome + the draw provenance.
	assert_equal(event.payload.get("passive_id"), "warrior_unbreakable_guard", "passive_destroyed should carry the destroyed passive id.")
	assert_equal(event.payload.get("table_id"), "passive_reward_choice", "passive_destroyed should carry the offer's table id.")
	assert_true(DestroyOutcomeTableDefinition.DESTROY_OUTCOME_CATEGORIES.has(StringName(String(event.payload.get("outcome_category")))), "The rolled outcome_category must be one of the three FR50 categories.")
	assert_false(String(event.payload.get("outcome_id")).is_empty(), "passive_destroyed should carry a non-empty outcome_id.")
	assert_false(String(event.payload.get("outcome_effect")).is_empty(), "passive_destroyed should carry a non-empty outcome_effect.")
	assert_false(String(event.payload.get("explanation")).is_empty(), "passive_destroyed should carry a non-empty explanation.")
	assert_equal(int(event.payload.get("draw_index")), 0, "The first rewards draw should report draw_index 0.")
	assert_true(int(event.payload.get("roll")) >= 0, "The roll provenance should be non-negative.")

	# The emitted event passes a real JSON round-trip (payload validation).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted passive_destroyed event should pass payload validation: %s" % parsed.metadata)

	# Result metadata surfaces the destroy diagnostics.
	assert_true(bool(destroyed.metadata.get("destroys_passive")), "The metadata should flag a destroy.")
	assert_equal(String(destroyed.metadata.get("passive_id")), "warrior_unbreakable_guard", "The metadata should carry the passive id.")
	assert_true(DestroyOutcomeTableDefinition.DESTROY_OUTCOME_CATEGORIES.has(StringName(String(destroyed.metadata.get("outcome_category")))), "The metadata should carry a valid outcome_category.")
	assert_true(run.validate().succeeded, "A committed destroy should leave the run structurally valid.")

	# The rewards stream ADVANCED exactly once (draw_index 0 -> 1); the held stream set is no longer at the start.
	var streams_after: Dictionary = streams.to_snapshot()
	assert_false(streams_after == streams_before, "A successful destroy must advance the held stream set (it rolled once).")
	var rewards_after: Dictionary = (streams_after.get("streams") as Dictionary).get("rewards")
	assert_equal(int(rewards_after.get("draw_index")), 1, "The rewards stream draw_index should advance 0 -> 1 after one roll.")


# ---- AC1: Destroy does NOT adopt (the opposite of Consume) ---------------------------------------

func _destroy_does_not_register_the_passive_into_the_resolver() -> void:
	# Destroy is the OPPOSITE of adopting the passive: run.rules_resolver is UNTOUCHED (no create/seat/register).
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	assert_true(run.rules_resolver == null, "Setup: a new_run has no resolver.")
	var streams: RngStreamSet = RngStreamSet.new(2468)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	assert_true(destroyed.succeeded, "Destroying should succeed: %s" % destroyed.metadata)
	assert_true(run.rules_resolver == null, "Destroy must NOT create/seat a resolver (it does not adopt the passive — the opposite of Consume).")


# ---- AC2: determinism + named-stream isolation ---------------------------------------------------

func _destroy_is_deterministic_per_seed_and_advances_only_the_rewards_stream() -> void:
	# The SAME run-level stream-set seed + the SAME outcome table -> the SAME rolled outcome across two fresh runs
	# (byte-identical event payload modulo sequence). Run the same seed twice.
	var first_event: DomainEvent = _destroy_once_with_seed(11111)
	var second_event: DomainEvent = _destroy_once_with_seed(11111)
	assert_equal(first_event.payload.get("outcome_category"), second_event.payload.get("outcome_category"), "The SAME seed must roll the SAME outcome_category (determinism).")
	assert_equal(first_event.payload.get("outcome_id"), second_event.payload.get("outcome_id"), "The SAME seed must roll the SAME outcome_id (determinism).")
	assert_equal(int(first_event.payload.get("roll")), int(second_event.payload.get("roll")), "The SAME seed must produce the SAME roll value (determinism).")

	# A DIVERGENT seed is each individually reproducible (we do NOT assert the two seeds differ — only that each seed
	# is consistent with itself, the determinism contract).
	var other_a: DomainEvent = _destroy_once_with_seed(99999)
	var other_b: DomainEvent = _destroy_once_with_seed(99999)
	assert_equal(other_a.payload.get("outcome_id"), other_b.payload.get("outcome_id"), "A second distinct seed must also be reproducible per-seed.")

	# Named-stream isolation: the roll advances ONLY the `rewards` stream; every other stream stays at draw_index 0.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	var streams: RngStreamSet = RngStreamSet.new(31415)
	DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	var snapshot: Dictionary = streams.to_snapshot()
	var stream_states: Dictionary = snapshot.get("streams")
	assert_equal(int((stream_states.get("rewards") as Dictionary).get("draw_index")), 1, "The rewards stream must advance to draw_index 1.")
	for other_stream: String in ["map", "level", "combat", "loot", "events", "cosmetic"]:
		assert_equal(int((stream_states.get(other_stream) as Dictionary).get("draw_index")), 0, "The %s stream must stay at draw_index 0 (named-stream isolation)." % other_stream)


# Run a single fresh destroy with the given run-level stream-set seed and return the emitted passive_destroyed event.
func _destroy_once_with_seed(seed_value: int) -> DomainEvent:
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	var streams: RngStreamSet = RngStreamSet.new(seed_value)
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	assert_true(destroyed.succeeded, "Destroying with seed %d should succeed: %s" % [seed_value, destroyed.metadata])
	return destroyed.events[0]


# ---- AC2/AC3: weighted-pick cumulative-boundary coverage -----------------------------------------

# Pin the cumulative-weight boundaries of the 70/20/10 pick. The baseline table's stable entry order is
# small_immediate_benefit (weight 7) -> progress_unlock_hidden_flag (weight 2) -> no_obvious_reward_avoids_danger
# (weight 1), so the cumulative thresholds are 7, 9, 10. The command draws rand_int(STREAM_REWARDS, 0,
# total_weight - 1) = [0, 9] (randi_range is inclusive both ends), and _pick_outcome walks the cumulative weights:
# roll < 7 -> small, 7 <= roll < 9 -> progress, 9 <= roll < 10 -> no_obvious. This exercises the
# rolled_value < cumulative walk at and around every 7/2/1 boundary (incl. the non-dominant 20%/10% bands the
# seed-based determinism test only hits indirectly), feeding the roll value directly into _pick_outcome.
func _pick_outcome_maps_each_roll_value_to_its_cumulative_weight_boundary() -> void:
	var table: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.create_baseline_table()
	assert_true(table.validate().succeeded, "Setup: the baseline table must validate.")
	assert_equal(table.total_weight(), 10, "Setup: the baseline table total weight should be 10 (7+2+1).")
	# A command instance carrying the baseline table; _pick_outcome is a pure function of the rolled value (no RNG,
	# no state read), so we exercise it directly across the full reachable roll range [0, total_weight - 1].
	var command: DestroyPassiveCommand = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, RngStreamSet.new(0), table)

	# The exhaustive roll-value -> category map across and around each cumulative threshold (7, 9, 10).
	var expected_by_roll: Dictionary = {
		0: DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT,
		1: DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT,
		5: DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT,
		6: DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT,  # last value in the 70% band
		7: DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG,  # first value in the 20% band
		8: DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG,  # last value in the 20% band
		9: DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER  # the single value in the 10% band
	}
	for roll_value: int in expected_by_roll:
		var outcome: Dictionary = command._pick_outcome(roll_value)
		assert_equal(
			StringName(String(outcome.get("outcome_category"))),
			expected_by_roll[roll_value],
			"Roll %d should map to the %s cumulative band." % [roll_value, String(expected_by_roll[roll_value])]
		)
		# The picked entry is a real, non-empty outcome entry (never the defensive empty-dict fail-safe).
		assert_false(String(outcome.get("outcome_id")).is_empty(), "Roll %d should pick a real entry with a non-empty outcome_id." % roll_value)

	# Each cumulative band picks the entry's own stable outcome_id (the baseline 7/2/1 entry ids).
	assert_equal(String(command._pick_outcome(6).get("outcome_id")), "minor_restoration", "The 70% band should pick the small_immediate_benefit entry id.")
	assert_equal(String(command._pick_outcome(7).get("outcome_id")), "quiet_progress", "The 20% band should pick the progress_unlock_hidden_flag entry id.")
	assert_equal(String(command._pick_outcome(9).get("outcome_id")), "sealed_danger", "The 10% band should pick the no_obvious_reward_avoids_danger entry id.")


# ---- AC4: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
		var streams: RngStreamSet = RngStreamSet.new(13579)
		var streams_before: Dictionary = streams.to_snapshot()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", bad_sequence_id, streams).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)
		assert_equal(streams.to_snapshot(), streams_before, "A sequence-id rejection must draw NO RNG (%d)." % bad_sequence_id)
		assert_true(run.rules_resolver == null, "A sequence-id rejection must touch nothing (resolver stays null) (%d)." % bad_sequence_id)


func _rejects_a_missing_or_incomplete_rng_stream_set() -> void:
	# A Destroy with NO stream set cannot roll — fail closed missing_rng_streams, byte-identical run.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", _baseline_offered_entries())
	var before: Dictionary = run.to_dictionary()
	var no_streams: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, null).execute(run)
	assert_true(no_streams.is_error(), "A destroy with no stream set must be rejected.")
	assert_equal(no_streams.error_code, &"missing_rng_streams", "A null stream set should use the stable missing_rng_streams code.")
	assert_false(no_streams.has_events(), "A missing-stream rejection should emit zero events.")
	assert_equal(run.to_dictionary(), before, "A missing-stream rejection must leave the run byte-identical.")
	assert_true(run.pending_reward_offer.is_pending(), "A missing-stream rejection must leave the offer pending.")


func _rejects_invalid_context() -> void:
	var streams: RngStreamSet = RngStreamSet.new(13579)
	# A non-RunState context is rejected with invalid_context.
	var not_a_run: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is also rejected as invalid_context, with the inner error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	run.pending_reward_offer = RewardOffer.new(&"passive_reward_choice", RewardOffer.STATUS_PENDING, [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var before: Dictionary = run.to_dictionary()
	var streams_before: Dictionary = streams.to_snapshot()
	var invalid_run: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code for diagnosis.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")
	assert_equal(streams.to_snapshot(), streams_before, "An invalid-context rejection must draw NO RNG.")


func _rejects_when_no_pending_offer() -> void:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var run: RunState = RunState.new_run(7, false, RouteState.new([start, boss], "", []))
	assert_true(run.pending_reward_offer == null, "Setup: the run has no pending offer.")
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A destroy with no pending offer must be rejected.")
	assert_equal(rejected.error_code, &"no_pending_reward_offer", "No pending offer should use the stable code.")
	assert_false(rejected.has_events(), "A no-offer rejection should emit zero events.")
	assert_equal(after, before, "A no-offer rejection must leave the run byte-identical.")
	assert_equal(streams.to_snapshot(), streams_before, "A no-offer rejection must draw NO RNG.")


func _rejects_a_non_offered_passive_selection() -> void:
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()
	var before: Dictionary = run.to_dictionary()
	# A passive id not on the offer.
	var wrong_id: ActionResult = DestroyPassiveCommand.new(&"ranger_steady_aim", &"passive_reward_choice", 1, streams).execute(run)
	assert_true(wrong_id.is_error(), "A non-offered passive id must be rejected.")
	assert_equal(wrong_id.error_code, &"invalid_reward_selection", "A non-offered passive should use the stable code.")
	assert_false(wrong_id.has_events(), "A non-offered-selection rejection should emit zero events.")
	assert_equal(String(wrong_id.metadata.get("content_id")), "ranger_steady_aim", "The reject metadata should carry the rejected content id.")
	assert_equal(run.to_dictionary(), before, "A non-offered-selection rejection must leave the run byte-identical.")
	assert_true(run.pending_reward_offer.is_pending(), "A rejected selection must leave the offer pending.")
	assert_equal(streams.to_snapshot(), streams_before, "A non-offered-selection rejection must draw NO RNG.")


func _rejects_an_offered_passive_that_does_not_resolve_unknown_passive() -> void:
	# An offered passive id that does NOT resolve through the injected PassiveRepository rejects unknown_passive.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var partial_repo: PassiveRepository = PassiveRepository.create_repository_from_definitions([
		PassiveDefinition.new(
			&"ranger_steady_aim", "Steady Aim", PassiveDefinition.KIND_CLASS, [RuleTrigger.BEFORE_ATTACK],
			"Steady Aim settles the shot.", PassiveDefinition.ICON_PLACEHOLDER, "A held breath.",
			"Before an attack resolves, settles the aim.", "Consume to keep the aim.", "Destroy to loose it.",
			false, "No hidden cost.", [PassiveDefinition.PILLAR_TACTICAL_CLARITY]
		)
	])
	assert_true(partial_repo != null, "Setup: the partial repository should build.")
	assert_true(partial_repo.get_passive(&"warrior_unbreakable_guard") == null, "Setup: the partial repo must not resolve the offered id.")
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, null, partial_repo).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "An offered passive that does not resolve must be rejected.")
	assert_equal(rejected.error_code, &"unknown_passive", "An unresolvable passive should use the stable unknown_passive code.")
	assert_false(rejected.has_events(), "An unknown-passive rejection should emit zero events.")
	assert_equal(String(rejected.metadata.get("passive_id")), "warrior_unbreakable_guard", "The unknown-passive error should carry the passive id.")
	assert_equal(after, before, "An unknown-passive rejection must leave the run byte-identical.")
	assert_true(run.pending_reward_offer.is_pending(), "An unknown-passive rejection must leave the offer pending.")
	assert_equal(streams.to_snapshot(), streams_before, "An unknown-passive rejection must draw NO RNG.")


func _rejects_an_invalid_outcome_table() -> void:
	# A null/invalid outcome table rejects invalid_destroy_outcome_table with zero mutation + zero RNG. An empty table
	# is invalid (validate() rejects it), so inject one.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()
	var before: Dictionary = run.to_dictionary()
	var bad_table: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"empty_outcome_table", [])
	assert_true(bad_table.validate().is_error(), "Setup: the injected table must be invalid (empty).")
	var rejected: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams, bad_table).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "An invalid outcome table must be rejected.")
	assert_equal(rejected.error_code, &"invalid_destroy_outcome_table", "An invalid table should use the stable invalid_destroy_outcome_table code.")
	assert_false(rejected.has_events(), "An invalid-table rejection should emit zero events.")
	assert_equal(after, before, "An invalid-table rejection must leave the run byte-identical.")
	assert_true(run.pending_reward_offer.is_pending(), "An invalid-table rejection must leave the offer pending.")
	assert_equal(streams.to_snapshot(), streams_before, "An invalid-table rejection must draw NO RNG (validate must not roll).")


# The single most load-bearing correctness property: a SECOND destroy against an already-resolved offer fails closed
# with ZERO events, ZERO RNG, byte-identical run + held stream set (no second roll).
func _duplicate_destroy_against_a_resolved_offer_rejects_no_double_destroy() -> void:
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var streams: RngStreamSet = RngStreamSet.new(13579)
	# First destroy succeeds + rolls + flips.
	var first: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, streams).execute(run)
	assert_true(first.succeeded, "The first destroy should succeed.")
	assert_true(run.pending_reward_offer.is_resolved(), "The offer is resolved after the first destroy.")

	# Snapshot the post-first-destroy run + the SAME held stream set (already advanced to draw_index 1); the SECOND
	# destroy must change NOTHING (no second roll).
	var before: Dictionary = run.to_dictionary()
	var streams_before: Dictionary = streams.to_snapshot()

	var second: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 2, streams).execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(second.is_error(), "A second destroy against a resolved offer must be rejected.")
	assert_equal(second.error_code, &"reward_offer_already_resolved", "A duplicate destroy should use the stable reward_offer_already_resolved code.")
	assert_equal(String(second.metadata.get("table_id")), "passive_reward_choice", "The duplicate-destroy error should carry the table id.")
	assert_false(second.has_events(), "A duplicate destroy must emit ZERO events (no second passive_destroyed).")
	assert_equal(after, before, "A duplicate destroy must leave the run byte-identical (no double-destroy).")
	# No second roll: the held stream set is byte-identical (draw_index unchanged).
	assert_equal(streams.to_snapshot(), streams_before, "A duplicate destroy must draw NO RNG (held stream set unchanged — no second roll).")


# AC4: a Destroy and a Consume are mutually exclusive on one offer — the offer is resolved by exactly one command.
func _consume_then_destroy_is_mutually_exclusive_on_one_offer() -> void:
	# Consume first, then a Destroy against the now-resolved offer rejects reward_offer_already_resolved.
	var consume_run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var consumed: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(consume_run)
	assert_true(consumed.succeeded, "Setup: the consume should succeed.")
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()
	var destroy_after_consume: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 2, streams).execute(consume_run)
	assert_true(destroy_after_consume.is_error(), "A destroy after a consume (resolved offer) must be rejected.")
	assert_equal(destroy_after_consume.error_code, &"reward_offer_already_resolved", "A destroy on a consumed offer should reject reward_offer_already_resolved.")
	assert_equal(streams.to_snapshot(), streams_before, "A destroy on a consumed offer must draw NO RNG.")

	# Destroy first, then a Consume against the now-resolved offer rejects reward_offer_already_resolved.
	var destroy_run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var destroyed: ActionResult = DestroyPassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, RngStreamSet.new(2468)).execute(destroy_run)
	assert_true(destroyed.succeeded, "Setup: the destroy should succeed.")
	var consume_after_destroy: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(destroy_run)
	assert_true(consume_after_destroy.is_error(), "A consume after a destroy (resolved offer) must be rejected.")
	assert_equal(consume_after_destroy.error_code, &"reward_offer_already_resolved", "A consume on a destroyed offer should reject reward_offer_already_resolved.")


# ---- AC4: zero RNG on reject ---------------------------------------------------------------------

func _destroy_draws_no_rng_on_reject() -> void:
	# A standalone sentinel: a rejected destroy (off-offer selection) draws no RNG. The held stream set is the run's
	# OWN injected set, so this is a real behavioral check (the command takes the stream set and must not roll on a
	# reject — validate is a pure read).
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()
	DestroyPassiveCommand.new(&"ranger_steady_aim", &"passive_reward_choice", 1, streams).execute(run)
	assert_equal(streams.to_snapshot(), before, "A rejected destroy must draw no RNG (stream set unchanged).")
