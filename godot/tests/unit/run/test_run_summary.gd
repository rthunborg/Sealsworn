extends "res://tests/unit/test_case.gd"

# Story 8.2 — RunSummary (the scene-free RUN-SUMMARY read aggregator). Covers the AC1-AC5 field set: a summary
# AGGREGATES every FR60 field from the terminal run STATE + the supplied domain EVENT list (AC1); source truth is
# domain state + event records, NOT presentation logs, and manual-seed eligibility is included (AC2); the output keeps
# EXPLICIT run-scoped / profile-meta / content-unlock boundaries and replay/debug grants nothing (AC3); fixture runs
# ending in death, shell completion, and a manual-seed-ineligible path report the expected field values (AC4); every
# not-yet-supported field is a TRACKED placeholder (0/empty AND named in not_yet_supported) that grants no progress
# (AC5). PLUS: an EXACT pinned key set (top-level + sub-dicts); a JSON round-trip preserves it (seed survives via
# decimal-string encoding); the read is PURE (twice -> identical; mutating a returned dict does not perturb the DTO); a
# non-terminal / null run projects the fail-closed empty fact; ZERO RNG is drawn (a pure aggregation).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

func run() -> Dictionary:
	_failed_run_reports_death_cause_and_phase()
	_completed_run_reports_completion_outcome_and_phase()
	_manual_seed_run_reports_ineligible_same_award_shape()
	_seed_round_trips_losslessly_through_json()
	_nodes_and_boss_and_elite_progress_derive_from_route()
	_no_cleared_nodes_reports_zero_and_no_crash()
	_passives_and_loot_aggregate_from_events()
	_empty_event_list_yields_empty_lists()
	_unrelated_events_do_not_pollute_lists()
	_reward_resolved_is_excluded_from_notable_loot()
	_backpack_reward_is_counted_once_not_doubled()
	_not_yet_supported_fields_are_placeholder_and_flagged()
	_state_boundaries_are_separable()
	_non_terminal_or_null_run_projects_empty_fact()
	_outcome_or_cause_takes_the_first_matching_terminal_event()
	_projection_keys_are_exact()
	_read_is_pure()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A run forced into a terminal phase (FAILED or COMPLETED), with the given manual-seed flag, over a route with one
# combat start node + one elite node + one boss node, all cleared. Built directly so the read DTO can be exercised
# without driving a full command sequence (the test_run_end_outcome.gd _terminal_run precedent).
func _terminal_run(phase: StringName, is_manual_seed: bool) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var elite: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_CLEARED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_CLEARED, [])
	var route: RouteState = RouteState.new([start, elite, boss], "node-2-0", ["node-0-0", "node-1-0", "node-2-0"])
	var run: RunState = RunState.new(phase, 4242, is_manual_seed, not is_manual_seed, route)
	assert_true(run.validate().succeeded, "Setup: the terminal %s run should validate." % String(phase))
	return run


# A run forced terminal with a specific seed + a specific economy (gold/curse/corruption), over a minimal cleared route.
func _terminal_run_with_seed_and_economy(phase: StringName, seed_value: int, gold: int, curse: int, corruption: int) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_CLEARED, [])
	var route: RouteState = RouteState.new([start, boss], "node-1-0", ["node-0-0", "node-1-0"])
	var economy: RiskEconomyState = RiskEconomyState.new(gold, 0, curse, corruption, true, [])
	var run: RunState = RunState.new(phase, seed_value, false, true, route, &"", null, null, null, null, economy)
	assert_true(run.validate().succeeded, "Setup: the terminal run with economy should validate.")
	return run


# ---- AC1/AC4: a failed fixture run reports the failed phase + the death cause ---------------------

func _failed_run_reports_death_cause_and_phase() -> void:
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, false)
	var events: Array = [DomainEvent.run_failed(1, {"cause": "hero_death", "node_id": "node-1-0", "cleared_node_count": 2})]
	var summary: RunSummary = RunSummary.build(run, events)
	var data: Dictionary = summary.to_dictionary()

	assert_true(bool(data.get("has_summary")), "A failed run's summary should report has_summary == true.")
	assert_equal(data.get("phase"), "failed", "A failed run's summary should report the failed phase.")
	assert_equal(data.get("outcome_or_cause"), "hero_death", "A failed run's summary should carry the death cause (from the run_failed event).")
	assert_true(bool(data.get("meta_progression_eligible")), "A non-manual failed run is meta-eligible (mirrors the run).")


# ---- AC1/AC4: a completed (shell completion) fixture run reports the completed phase + the outcome -

func _completed_run_reports_completion_outcome_and_phase() -> void:
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var events: Array = [DomainEvent.run_completed(1, {"outcome": "completed", "cleared_node_count": 3})]
	var summary: RunSummary = RunSummary.build(run, events)
	var data: Dictionary = summary.to_dictionary()

	assert_true(bool(data.get("has_summary")), "A completed run's summary should report has_summary == true.")
	assert_equal(data.get("phase"), "completed", "A completed run's summary should report the completed phase.")
	assert_equal(data.get("outcome_or_cause"), "completed", "A completed run's summary should carry the completion outcome (from the run_completed event).")
	# The boss_placeholder outcome (a boss-cleared run) is also read verbatim.
	var boss_events: Array = [DomainEvent.run_completed(1, {"outcome": "boss_placeholder", "boss_node_id": "node-2-0", "cleared_node_count": 3})]
	var boss_summary: Dictionary = RunSummary.build(_terminal_run(RunState.PHASE_COMPLETED, false), boss_events).to_dictionary()
	assert_equal(boss_summary.get("outcome_or_cause"), "boss_placeholder", "A boss-cleared run's summary carries the boss_placeholder outcome.")


# ---- AC2/AC3/AC4: a manual-seed run reports ineligible + the SAME 0/empty award shape (no grant) --

func _manual_seed_run_reports_ineligible_same_award_shape() -> void:
	# A manual-seed (replay/practice) run is NEVER meta-eligible (lockstep with is_manual_seed). The summary REPORTS
	# this READ-ONLY; building it grants NOTHING — a manual-seed run's award/unlock fields are the SAME 0/empty shape as
	# an eligible run (AC3 "replay/debug cannot grant progress" is structural).
	var manual_run: RunState = _terminal_run(RunState.PHASE_FAILED, true)
	assert_false(manual_run.meta_progression_eligible, "Setup: a manual-seed run is not meta-eligible.")
	var manual_data: Dictionary = RunSummary.build(manual_run, [DomainEvent.run_failed(1, {"cause": "abandoned"})]).to_dictionary()

	assert_false(bool(manual_data.get("meta_progression_eligible")), "A manual-seed run's summary reports meta_progression_eligible == false.")
	assert_true(bool(manual_data.get("is_manual_seed")), "A manual-seed run's summary reports is_manual_seed == true.")
	var manual_profile: Dictionary = manual_data.get("profile_meta")
	assert_equal(int(manual_profile.get("oath_shards_earned")), 0, "A manual-seed run's summary reports 0 Oath Shards earned (no award).")

	# An ELIGIBLE run has the IDENTICAL award/unlock shape (eligibility does not grant).
	var eligible_data: Dictionary = RunSummary.build(_terminal_run(RunState.PHASE_COMPLETED, false), [DomainEvent.run_completed(1, {"outcome": "completed"})]).to_dictionary()
	var eligible_profile: Dictionary = eligible_data.get("profile_meta")
	assert_equal(int(eligible_profile.get("oath_shards_earned")), 0, "An eligible run's summary ALSO reports 0 Oath Shards earned (v0 awards none).")
	assert_equal(manual_data.get("profile_meta"), eligible_data.get("profile_meta"), "A manual-seed run's profile_meta equals an eligible run's (eligibility does not grant).")
	assert_equal(manual_data.get("content_unlock"), eligible_data.get("content_unlock"), "A manual-seed run's content_unlock equals an eligible run's (eligibility does not grant).")


# ---- AC1/AC2: the seed round-trips losslessly through JSON (decimal-string encoding) --------------

func _seed_round_trips_losslessly_through_json() -> void:
	# A large int64 seed (beyond 2^53) must survive JSON.stringify -> parse_string via decimal-string encoding.
	var big_seed: int = 9223372036854775000
	var run: RunState = _terminal_run_with_seed_and_economy(RunState.PHASE_COMPLETED, big_seed, 0, 0, 0)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var serialized: String = JSON.stringify(summary.to_dictionary())
	var parsed: Variant = JSON.parse_string(serialized)
	assert_true(parsed is Dictionary, "The summary must survive a JSON round-trip as a Dictionary.")
	var parsed_dict: Dictionary = parsed
	assert_equal(String(parsed_dict.get("seed")), str(big_seed), "The full int64 seed must not lose precision through a JSON round-trip (decimal-string encoded).")
	# Sanity: the seed field is a decimal string, not a truncated double.
	assert_true(parsed_dict.get("seed") is String, "The seed field must be a decimal string (int64-safe), not a JSON number.")


# ---- AC1: nodes cleared + boss/elite progress derive from the route ------------------------------

func _nodes_and_boss_and_elite_progress_derive_from_route() -> void:
	# The _terminal_run fixture clears node-0-0 (combat), node-1-0 (elite), node-2-0 (boss) -> 3 cleared, boss cleared,
	# 1 elite cleared.
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var summary: Dictionary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "boss_placeholder", "boss_node_id": "node-2-0"})]).to_dictionary()
	var run_scoped: Dictionary = summary.get("run_scoped")
	assert_equal(int(run_scoped.get("nodes_cleared")), 3, "nodes_cleared should equal the cleared-node-set size.")
	assert_true(bool(run_scoped.get("boss_cleared")), "A run that cleared the boss node reports boss_cleared == true.")
	assert_equal(int(run_scoped.get("elite_nodes_cleared")), 1, "elite_nodes_cleared should count the cleared elite_combat nodes.")


# ---- AC1: a run with no cleared nodes reports 0/false (no crash) ----------------------------------

func _no_cleared_nodes_reports_zero_and_no_crash() -> void:
	# A run can be FAILED with nothing cleared (abandoned at the first choice). The route has nodes but the cleared set
	# is empty.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "node-0-0", [])
	var run: RunState = RunState.new(RunState.PHASE_FAILED, 7, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the no-cleared-nodes failed run should validate.")

	var run_scoped: Dictionary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "abandoned"})]).to_dictionary().get("run_scoped")
	assert_equal(int(run_scoped.get("nodes_cleared")), 0, "A run with no cleared nodes reports nodes_cleared == 0.")
	assert_false(bool(run_scoped.get("boss_cleared")), "A run with no cleared nodes reports boss_cleared == false.")
	assert_equal(int(run_scoped.get("elite_nodes_cleared")), 0, "A run with no cleared nodes reports elite_nodes_cleared == 0.")


# ---- AC1/AC2: passives-consumed + passives-destroyed + notable-loot aggregate from EVENTS ---------

func _passives_and_loot_aggregate_from_events() -> void:
	# A supplied list with 2 passive_consumed + 1 passive_destroyed + 3 item_gained events yields the correct three
	# lists. These have NO persisted home in v0 — the events ARE the source truth (AC2).
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var events: Array = [
		DomainEvent.passive_consumed(1, {"passive_id": "warrior_resolve", "table_id": "passive_reward_basic"}),
		DomainEvent.item_gained(2, {"item_id": "iron_sword", "category": "weapon", "backpack_size_after": 1, "slot_index": 0}),
		DomainEvent.passive_consumed(3, {"passive_id": "ember_focus", "table_id": "passive_reward_basic"}),
		DomainEvent.item_gained(4, {"item_id": "leather_vest", "category": "armor", "backpack_size_after": 2, "slot_index": 1}),
		DomainEvent.passive_destroyed(5, {"passive_id": "cursed_pact", "table_id": "passive_reward_basic", "outcome_category": "small_immediate_benefit", "outcome_id": "minor_gold", "outcome_effect": "gain_gold", "explanation": "x", "roll": 3, "draw_index": 1}),
		DomainEvent.item_gained(6, {"item_id": "healing_draught", "category": "consumable", "backpack_size_after": 3, "slot_index": 2}),
		DomainEvent.run_completed(7, {"outcome": "completed"})
	]
	var run_scoped: Dictionary = RunSummary.build(run, events).to_dictionary().get("run_scoped")

	var consumed: Array = run_scoped.get("passives_consumed")
	assert_equal(consumed.size(), 2, "Two passive_consumed events yield two consumed passives.")
	assert_true(consumed.has("warrior_resolve"), "The consumed list carries warrior_resolve.")
	assert_true(consumed.has("ember_focus"), "The consumed list carries ember_focus.")

	var destroyed: Array = run_scoped.get("passives_destroyed")
	assert_equal(destroyed.size(), 1, "One passive_destroyed event yields one destroyed passive.")
	assert_true(destroyed.has("cursed_pact"), "The destroyed list carries cursed_pact.")

	var loot: Array = run_scoped.get("notable_loot")
	assert_equal(loot.size(), 3, "Three item_gained events yield three notable-loot entries.")
	var loot_ids: Array[String] = []
	for entry: Variant in loot:
		loot_ids.append(String((entry as Dictionary).get("item_id")))
	assert_true(loot_ids.has("iron_sword") and loot_ids.has("leather_vest") and loot_ids.has("healing_draught"), "The notable-loot list carries the three gained item ids.")


# ---- AC1/AC2: an empty event list yields three empty lists ----------------------------------------

func _empty_event_list_yields_empty_lists() -> void:
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	# A terminal run with NO events still builds (the phase carries the terminal fact; the marker is simply unknown).
	var run_scoped: Dictionary = RunSummary.build(run, []).to_dictionary().get("run_scoped")
	assert_true((run_scoped.get("passives_consumed") as Array).is_empty(), "An empty event list yields an empty passives_consumed list.")
	assert_true((run_scoped.get("passives_destroyed") as Array).is_empty(), "An empty event list yields an empty passives_destroyed list.")
	assert_true((run_scoped.get("notable_loot") as Array).is_empty(), "An empty event list yields an empty notable_loot list.")


# ---- AC2: an event list with unrelated events does not pollute the summary lists ------------------

func _unrelated_events_do_not_pollute_lists() -> void:
	# entity_moved / damage_applied / run_started are unrelated to the aggregated lists — they must be ignored. A
	# non-DomainEvent entry (a stray dict) is also tolerated and ignored (the tolerant-element-type contract).
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var events: Array = [
		DomainEvent.run_started(1, {"root_seed": "4242", "is_manual_seed": false, "node_count": 3}),
		DomainEvent.new(DomainEvent.Type.ENTITY_MOVED, 2, &"hero", {"from": "0,0", "to": "1,0"}),
		DomainEvent.new(DomainEvent.Type.DAMAGE_APPLIED, 3, &"hero", {"amount": 5}),
		{"not": "a domain event"},
		DomainEvent.item_gained(4, {"item_id": "iron_sword", "category": "weapon", "backpack_size_after": 1, "slot_index": 0}),
		DomainEvent.run_completed(5, {"outcome": "completed"})
	]
	var run_scoped: Dictionary = RunSummary.build(run, events).to_dictionary().get("run_scoped")
	assert_true((run_scoped.get("passives_consumed") as Array).is_empty(), "Unrelated events do not pollute passives_consumed.")
	assert_true((run_scoped.get("passives_destroyed") as Array).is_empty(), "Unrelated events do not pollute passives_destroyed.")
	assert_equal((run_scoped.get("notable_loot") as Array).size(), 1, "Only the item_gained event contributes to notable_loot (unrelated events ignored).")


# ---- AC1: reward_resolved is fully excluded from notable loot (item_gained is the sole source) -----

func _reward_resolved_is_excluded_from_notable_loot() -> void:
	# [Decision, round 1 review] reward_resolved is EXCLUDED from notable_loot ENTIRELY (all REWARD_CATEGORIES): gold is
	# an economy readout, passive is tracked via the consume/destroy lists, and a BACKPACK-category reward already emits a
	# paired item_gained (ResolveRewardCommand composes PickupItemCommand) — so counting the reward_resolved too would
	# DOUBLE-COUNT the same physical item. item_gained is the SOLE notable-loot source; each gained item is counted once.
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var events: Array = [
		DomainEvent.reward_resolved(1, {"table_id": "reward_basic", "category": "gold", "content_id": "gold_small"}),
		DomainEvent.reward_resolved(2, {"table_id": "reward_basic", "category": "passive", "content_id": "warrior_resolve"}),
		DomainEvent.reward_resolved(3, {"table_id": "reward_basic", "category": "armor", "content_id": "leather_vest"}),
		DomainEvent.run_completed(4, {"outcome": "completed"})
	]
	var loot: Array = RunSummary.build(run, events).to_dictionary().get("run_scoped").get("notable_loot")
	assert_equal(loot.size(), 0, "reward_resolved (gold/passive/backpack) is fully excluded from notable_loot — item_gained is the sole source.")


# ---- AC1: a backpack reward (reward_resolved + its paired item_gained) is counted EXACTLY once ------

func _backpack_reward_is_counted_once_not_doubled() -> void:
	# The MAIN Epic-6 loot path: ResolveRewardCommand for a backpack reward emits BOTH a reward_resolved (sequence_id)
	# AND a paired item_gained (sequence_id + 1, via the composed PickupItemCommand) for the SAME physical item. The
	# summary must count that item EXACTLY ONCE (from the item_gained), NOT twice (the round-1 review double-count fix).
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var events: Array = [
		DomainEvent.reward_resolved(1, {"table_id": "reward_basic", "category": "armor", "content_id": "leather_vest"}),
		DomainEvent.item_gained(2, {"item_id": "leather_vest", "category": "armor", "backpack_size_after": 1, "slot_index": 0}),
		DomainEvent.run_completed(3, {"outcome": "completed"})
	]
	var loot: Array = RunSummary.build(run, events).to_dictionary().get("run_scoped").get("notable_loot")
	assert_equal(loot.size(), 1, "A backpack reward (reward_resolved + paired item_gained for the same item) is counted EXACTLY once, not doubled.")
	assert_equal(String((loot[0] as Dictionary).get("item_id")), "leather_vest", "The single notable-loot entry is the gained item.")
	assert_equal(String((loot[0] as Dictionary).get("source")), "item_gained", "The single entry is sourced from item_gained (reward_resolved is excluded).")


# ---- AC1/AC5: not-yet-supported fields are placeholder (0/empty) AND flagged ----------------------

func _not_yet_supported_fields_are_placeholder_and_flagged() -> void:
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var data: Dictionary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})]).to_dictionary()

	# The placeholder VALUES are safe (0 / []) — structurally impossible to mistake for a real award/unlock.
	assert_equal(int((data.get("profile_meta") as Dictionary).get("oath_shards_earned")), 0, "oath_shards_earned is the 0 placeholder (awarding is Story 8.3).")
	assert_true(((data.get("content_unlock") as Dictionary).get("echoes_discovered") as Array).is_empty(), "echoes_discovered is the empty placeholder (Story 8.4).")
	assert_true(((data.get("content_unlock") as Dictionary).get("unlock_progress") as Array).is_empty(), "unlock_progress is the empty placeholder (Story 8.4).")

	# The not_yet_supported signal NAMES the deferred fields so the Epic-10 readiness pass (Story 10.7) can enumerate them.
	var flagged: Array = data.get("not_yet_supported")
	assert_true(flagged.has("oath_shards_earned"), "not_yet_supported names oath_shards_earned.")
	assert_true(flagged.has("echoes_discovered"), "not_yet_supported names echoes_discovered.")
	assert_true(flagged.has("unlock_progress"), "not_yet_supported names unlock_progress.")
	assert_equal(flagged.size(), 3, "not_yet_supported names exactly the three tracked placeholder fields.")


# ---- AC3: the run-scoped / profile-meta / content-unlock boundaries are separable ----------------

func _state_boundaries_are_separable() -> void:
	# The output keeps the three state kinds in DISTINCT sub-dicts so a reader can tell run-scoped facts from the
	# 0/empty profile/unlock readouts (AC3). The run-scoped economy readouts are the REAL v0 fields.
	var run: RunState = _terminal_run_with_seed_and_economy(RunState.PHASE_COMPLETED, 4242, 25, 2, 1)
	var data: Dictionary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})]).to_dictionary()

	assert_true(data.get("run_scoped") is Dictionary, "run_scoped is a distinct sub-dict.")
	assert_true(data.get("profile_meta") is Dictionary, "profile_meta is a distinct sub-dict.")
	assert_true(data.get("content_unlock") is Dictionary, "content_unlock is a distinct sub-dict.")

	var run_scoped: Dictionary = data.get("run_scoped")
	assert_equal(int(run_scoped.get("gold")), 25, "run_scoped carries the run's gold readout.")
	assert_equal(int(run_scoped.get("curse_count")), 2, "run_scoped carries the run's curse_count readout.")
	assert_equal(int(run_scoped.get("corruption")), 1, "run_scoped carries the run's corruption readout.")


# ---- fail-closed: a non-terminal / null run projects the empty fact -------------------------------

func _non_terminal_or_null_run_projects_empty_fact() -> void:
	# A non-terminal run projects has_summary == false + empty/zero fields, so a consumer branches on has_summary
	# without inspecting the empty fields (the RunEndOutcome._empty() discipline).
	var active: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([active], "node-0-0", [])
	var active_run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 5, false, true, route)

	var active_data: Dictionary = RunSummary.build(active_run, [DomainEvent.run_completed(1, {"outcome": "completed"})]).to_dictionary()
	assert_false(bool(active_data.get("has_summary")), "A non-terminal (active) run projects has_summary == false.")
	assert_equal(active_data.get("phase"), "", "An empty fact has an empty phase.")
	assert_equal(active_data.get("outcome_or_cause"), "", "An empty fact has an empty outcome_or_cause.")
	assert_equal(String(active_data.get("seed")), "0", "An empty fact has a 0 seed.")
	assert_false(bool(active_data.get("meta_progression_eligible")), "An empty fact defaults meta_progression_eligible to false (no claim).")
	# The empty fact still has the pinned sub-dict shape (empty defaults).
	assert_equal(int((active_data.get("run_scoped") as Dictionary).get("nodes_cleared")), 0, "An empty fact's run_scoped.nodes_cleared is 0.")
	assert_equal(int((active_data.get("profile_meta") as Dictionary).get("oath_shards_earned")), 0, "An empty fact's profile_meta.oath_shards_earned is 0.")

	# A NEW_RUN run (also non-terminal) -> empty.
	var new_run: RunState = RunState.new(RunState.PHASE_NEW_RUN, 5, false, true, route)
	assert_false(bool(RunSummary.build(new_run, []).to_dictionary().get("has_summary")), "A new_run run projects has_summary == false.")

	# null run -> empty.
	assert_false(bool(RunSummary.build(null, []).to_dictionary().get("has_summary")), "build(null) projects the empty fact.")
	# A default (no events arg) build of null also projects empty.
	assert_false(bool(RunSummary.build(null).to_dictionary().get("has_summary")), "build(null) with no events arg projects the empty fact.")


# ---- AC1: outcome_or_cause takes the FIRST matching terminal run-end event ------------------------

func _outcome_or_cause_takes_the_first_matching_terminal_event() -> void:
	# [Decision, round 1 review] The derivation breaks on the FIRST matching terminal run-end event (a run ends exactly
	# once). On a malformed list carrying multiple run_failed events, the FIRST cause wins (self-consistent with the
	# run-ended-once reality — not a silent last-wins overwrite).
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, false)
	var events: Array = [
		DomainEvent.run_failed(1, {"cause": "hero_death"}),
		DomainEvent.run_failed(2, {"cause": "abandoned"})
	]
	var data: Dictionary = RunSummary.build(run, events).to_dictionary()
	assert_equal(data.get("outcome_or_cause"), "hero_death", "The FIRST matching run_failed cause wins (first-match, not last-wins).")

	# The same first-match rule holds for a completed run with multiple run_completed events.
	var completed_run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var completed_events: Array = [
		DomainEvent.run_completed(1, {"outcome": "completed"}),
		DomainEvent.run_completed(2, {"outcome": "boss_placeholder", "boss_node_id": "node-2-0"})
	]
	var completed_data: Dictionary = RunSummary.build(completed_run, completed_events).to_dictionary()
	assert_equal(completed_data.get("outcome_or_cause"), "completed", "The FIRST matching run_completed outcome wins (first-match, not last-wins).")


# ---- the projection has an EXACT pinned key set (top-level + sub-dicts) ---------------------------

func _projection_keys_are_exact() -> void:
	# The to_dictionary() key set is EXACTLY DICTIONARY_KEYS (no key silently appears/vanishes — the exact-key
	# discipline). Checked for a terminal AND an empty projection (both share the shape), plus each sub-dict's pinned
	# key set.
	var terminal: Dictionary = RunSummary.build(_terminal_run(RunState.PHASE_COMPLETED, false), [DomainEvent.run_completed(1, {"outcome": "completed"})]).to_dictionary()
	var empty: Dictionary = RunSummary.build(null, []).to_dictionary()

	for projected: Dictionary in [terminal, empty]:
		_assert_exact_keys(projected, RunSummary.DICTIONARY_KEYS, "top-level")
		_assert_exact_keys(projected.get("run_scoped"), RunSummary.RUN_SCOPED_KEYS, "run_scoped")
		_assert_exact_keys(projected.get("profile_meta"), RunSummary.PROFILE_META_KEYS, "profile_meta")
		_assert_exact_keys(projected.get("content_unlock"), RunSummary.CONTENT_UNLOCK_KEYS, "content_unlock")


func _assert_exact_keys(projected: Dictionary, pinned_keys: Array, label: String) -> void:
	assert_equal(projected.size(), pinned_keys.size(), "The %s projection must have exactly the pinned key count." % label)
	for key: String in pinned_keys:
		assert_true(projected.has(key), "The %s projection must carry the pinned key `%s`." % [label, key])
	for key_value: Variant in projected.keys():
		assert_true(pinned_keys.has(String(key_value)), "The %s projection must NOT carry an un-pinned key `%s`." % [label, String(key_value)])


# ---- the read is pure (twice -> identical; a returned-dict mutation does not perturb the DTO) -----

func _read_is_pure() -> void:
	# Repeated reads of the same summary are byte-identical (no mutation, no RNG, no events — a pure read DTO). Building
	# twice from the same inputs is also identical (a pure function of (terminal RunState, events)).
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, false)
	var events: Array = [
		DomainEvent.passive_consumed(1, {"passive_id": "warrior_resolve", "table_id": "t"}),
		DomainEvent.run_failed(2, {"cause": "level_defeat"})
	]
	var summary: RunSummary = RunSummary.build(run, events)
	var first: Dictionary = summary.to_dictionary()
	var second: Dictionary = summary.to_dictionary()
	assert_equal(second, first, "Repeated reads of a RunSummary must be identical (pure read).")

	# Building twice from the same inputs yields identical projections (deterministic pure aggregation).
	var rebuilt: Dictionary = RunSummary.build(_terminal_run(RunState.PHASE_FAILED, false), [
		DomainEvent.passive_consumed(1, {"passive_id": "warrior_resolve", "table_id": "t"}),
		DomainEvent.run_failed(2, {"cause": "level_defeat"})
	]).to_dictionary()
	assert_equal(rebuilt, first, "Building twice from the same inputs yields identical summaries (pure function).")

	# Mutating the returned dict (top-level AND a nested sub-dict/list) must not perturb the DTO (a fresh deep copy each
	# call).
	first["has_summary"] = false
	(first.get("run_scoped") as Dictionary)["nodes_cleared"] = 999
	(first.get("run_scoped").get("passives_consumed") as Array).append("injected")
	var reread: Dictionary = summary.to_dictionary()
	assert_true(bool(reread.get("has_summary")), "Mutating a returned dict must not perturb the DTO (top-level).")
	# The _terminal_run fixture clears node-0-0 / node-1-0 / node-2-0 -> nodes_cleared == 3 (the real, un-mutated value).
	assert_equal((reread.get("run_scoped") as Dictionary).get("nodes_cleared"), 3, "Mutating a returned nested dict must not perturb the DTO.")
	assert_equal((reread.get("run_scoped").get("passives_consumed") as Array).size(), 1, "Mutating a returned nested list must not perturb the DTO.")
