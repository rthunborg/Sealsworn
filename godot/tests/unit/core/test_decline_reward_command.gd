extends "res://tests/unit/test_case.gd"

# Story 14.7 Task 5 — DeclineRewardCommand (the reward-DECLINE command, the full-backpack escape hatch). Covers AC1
# (a pending generic offer can be DECLINED — the offer flips to `resolved` WITHOUT applying it, so the run can
# advance; the load-bearing full-backpack case breaks the soft-lock while the backpack stays byte-identical, so the
# fail-closed inventory_full guard is un-weakened) and AC2 (validate-before-mutate: sequence_id <= 0 rejects FIRST;
# a non-RunState / structurally-invalid run rejects invalid_context; no pending offer rejects no_pending_reward_offer;
# a SECOND decline against a resolved offer rejects reward_offer_already_resolved with ZERO events, ZERO RNG,
# byte-identical run; the command draws ZERO RNG on both success and reject).
#
# Mirrors test_resolve_reward_command.gd (the run-command valid/invalid/no-mutation/no-RNG shape). The decline drops
# the selection + apply steps entirely — it applies NOTHING (no PickupItemCommand, no gold credit), so it can never
# hit inventory_full.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DeclineRewardCommand = preload("res://scripts/core/commands/decline_reward_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PickupItemCommand = preload("res://scripts/core/commands/pickup_item_command.gd")
const ResolveRewardCommand = preload("res://scripts/core/commands/resolve_reward_command.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_declines_a_pending_generic_offer_records_no_selection_and_one_event()
	_declines_a_full_backpack_offer_breaking_the_soft_lock_without_touching_the_backpack()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_when_no_pending_offer()
	_second_decline_against_a_resolved_offer_rejects_no_double_record()
	_decline_draws_no_rng_on_success_and_reject()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice WITH a pending offer carrying the given entries (mirrors
# test_resolve_reward_command._run_with_offer).
func _run_with_offer(table_id: StringName, offered_entries: Array, gold_amount: int = 0) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	run.pending_reward_offer = RewardOffer.new(table_id, RewardOffer.STATUS_PENDING, offered_entries, {}, "rewards", 1, 0, 42, gold_amount)
	assert_true(run.validate().succeeded, "Setup: the run with an offer should validate.")
	return run


# ---- AC1: successful decline ---------------------------------------------------------------------

func _declines_a_pending_generic_offer_records_no_selection_and_one_event() -> void:
	var run: RunState = _run_with_offer(&"standard_combat_reward", [
		{"category": "weapon", "content_id": "sword"}
	])
	var inventory_before: int = run.inventory.size()
	var gold_before: int = run.risk_economy.gold
	var declined: ActionResult = DeclineRewardCommand.new().execute(run)
	assert_true(declined.succeeded, "Declining a pending generic offer should succeed: %s" % declined.metadata)

	# The offer flipped to resolved with NO recorded selection (declined = nothing selected).
	assert_true(run.pending_reward_offer.is_resolved(), "The offer must flip to resolved after a successful decline.")
	assert_true(run.pending_reward_offer.selected_entry.is_empty(), "A decline records NO selected entry (selected_entry == {}).")

	# Exactly ONE reward_declined event; NO item_gained / economy_changed (nothing applied).
	assert_equal(declined.events.size(), 1, "A decline emits exactly ONE event (reward_declined).")
	var event: DomainEvent = declined.events[0]
	assert_equal(event.event_type, DomainEvent.Type.REWARD_DECLINED, "The emitted event is reward_declined.")
	assert_equal(String(event.actor_id), "", "reward_declined is a system event (empty actor id).")
	assert_equal(event.payload.get("table_id"), "standard_combat_reward", "reward_declined carries the offer table id.")
	assert_equal(event.payload.get("reason"), "player_declined", "reward_declined carries the player_declined reason.")
	# The emitted event passes payload validation (real JSON round-trip).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted reward_declined event should pass payload validation: %s" % parsed.metadata)

	# The backpack + economy are untouched (nothing applied — a declined reward contributes no loot / no gold).
	assert_equal(run.inventory.size(), inventory_before, "A decline records NO backpack slot.")
	assert_equal(run.risk_economy.gold, gold_before, "A decline credits NO gold.")
	assert_true(run.validate().succeeded, "A committed decline should leave the run structurally valid.")


# The single most load-bearing AC1 property: a backpack reward that WOULD inventory_full on resolve (a FULL 6/6
# backpack) is instead DECLINABLE — the offer flips resolved (the run advances, the soft-lock is broken) while the
# backpack stays byte-identical (the fail-closed guard is un-weakened; the decline never touches the backpack).
func _declines_a_full_backpack_offer_breaking_the_soft_lock_without_touching_the_backpack() -> void:
	var fill_ids: Array[StringName] = [&"minor_healing_draught", &"warding_salve", &"ember_flask", &"health_morsel", &"focus_ember", &"padded_vest"]
	var fill_categories: Array[StringName] = [&"consumable", &"consumable", &"consumable", &"pickup", &"pickup", &"armor"]

	# Pre-condition probe (a SEPARATE run so it does not consume the offer we decline below): resolving this
	# backpack reward into a full backpack DOES surface inventory_full and leaves the offer PENDING — the soft-lock.
	var probe: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "armor", "content_id": "chain_hauberk"}])
	for i: int in range(fill_ids.size()):
		assert_true(PickupItemCommand.new(fill_ids[i], fill_categories[i]).execute(probe).succeeded, "Probe: filling slot %d should succeed." % i)
	assert_true(probe.inventory.is_full(), "Probe: the backpack should be full (6/6).")
	var would_reject: ActionResult = ResolveRewardCommand.new(&"armor", &"chain_hauberk").execute(probe)
	assert_true(would_reject.is_error(), "Pre-condition: resolving into a full backpack surfaces an error.")
	assert_equal(would_reject.error_code, &"inventory_full", "Pre-condition: the full-backpack resolve surfaces inventory_full.")
	assert_true(probe.pending_reward_offer.is_pending(), "Pre-condition: the full-backpack resolve leaves the offer PENDING (the soft-lock).")

	# The DECLINE breaks the soft-lock.
	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "armor", "content_id": "chain_hauberk"}])
	for i: int in range(fill_ids.size()):
		assert_true(PickupItemCommand.new(fill_ids[i], fill_categories[i]).execute(run).succeeded, "Filling slot %d should succeed." % i)
	assert_true(run.inventory.is_full(), "Setup: the backpack should be full (6/6).")
	var backpack_before: Array = run.inventory.backpack.duplicate(true)

	var declined: ActionResult = DeclineRewardCommand.new().execute(run)
	assert_true(declined.succeeded, "A full-backpack offer must be DECLINABLE (the soft-lock break): %s" % declined.metadata)
	assert_equal(declined.events.size(), 1, "A full-backpack decline emits exactly ONE reward_declined event.")
	assert_equal(declined.events[0].event_type, DomainEvent.Type.REWARD_DECLINED, "The emitted event is reward_declined.")
	assert_true(run.pending_reward_offer.is_resolved(), "The declined offer flips to resolved (the run can advance).")
	# The backpack is byte-identical (the fail-closed guard is un-weakened — the decline never touches the backpack).
	assert_equal(run.inventory.size(), 6, "A decline into a full backpack adds NO slot (backpack still 6/6).")
	assert_equal(run.inventory.backpack, backpack_before, "A decline leaves the full backpack byte-identical (never touches it).")


# ---- AC2: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = DeclineRewardCommand.new(bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)
		assert_true(run.pending_reward_offer.is_pending(), "A sequence-id rejection must leave the offer pending (%d)." % bad_sequence_id)


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context.
	var not_a_run: ActionResult = DeclineRewardCommand.new().execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is also rejected as invalid_context, with the inner error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	run.pending_reward_offer = RewardOffer.new(&"t", RewardOffer.STATUS_PENDING, [{"category": "weapon", "content_id": "sword"}])
	var before: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = DeclineRewardCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code for diagnosis.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_when_no_pending_offer() -> void:
	# A run with NO pending offer rejects no_pending_reward_offer with zero mutation.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var run: RunState = RunState.new_run(7, false, RouteState.new([start, boss], "", []))
	assert_true(run.pending_reward_offer == null, "Setup: the run has no pending offer.")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = DeclineRewardCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A decline with no pending offer must be rejected.")
	assert_equal(rejected.error_code, &"no_pending_reward_offer", "No pending offer should use the stable code.")
	assert_false(rejected.has_events(), "A no-offer rejection should emit zero events.")
	assert_equal(after, before, "A no-offer rejection must leave the run byte-identical.")


# The no-double-record guarantee: a SECOND decline against an already-resolved offer fails closed with ZERO events,
# ZERO RNG, byte-identical run (exactly-one-command — a decline shares the resolve command's already-resolved code).
func _second_decline_against_a_resolved_offer_rejects_no_double_record() -> void:
	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
	# First decline succeeds + flips the offer.
	var first: ActionResult = DeclineRewardCommand.new().execute(run)
	assert_true(first.succeeded, "The first decline should succeed.")
	assert_true(run.pending_reward_offer.is_resolved(), "The offer is resolved after the first decline.")

	# Snapshot the post-first-decline run + a held RNG stream set; the SECOND decline must change NOTHING.
	var before: Dictionary = run.to_dictionary()
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()

	var second: ActionResult = DeclineRewardCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(second.is_error(), "A second decline against a resolved offer must be rejected.")
	assert_equal(second.error_code, &"reward_offer_already_resolved", "A duplicate decline should use the stable reward_offer_already_resolved code.")
	assert_equal(String(second.metadata.get("table_id")), "standard_combat_reward", "The duplicate-decline error should carry the table id.")
	assert_false(second.has_events(), "A duplicate decline must emit ZERO events (no second reward_declined).")
	assert_equal(after, before, "A duplicate decline must leave the run byte-identical (no double-record).")
	assert_equal(streams.to_snapshot(), streams_before, "A duplicate decline must draw NO RNG (held stream set unchanged).")


# ---- AC2: no RNG ---------------------------------------------------------------------------------

func _decline_draws_no_rng_on_success_and_reject() -> void:
	# The decline is deterministic — the command receives no stream set at all, so it structurally cannot advance one.
	# Hold an external stream set, snapshot it, run a SUCCESSFUL decline and a REJECTED decline, and assert the streams
	# are byte-identical in both cases (mirrors test_resolve_reward_command._resolve_draws_no_rng_on_success_and_reject).
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
	DeclineRewardCommand.new().execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful decline must draw no RNG (stream set unchanged).")

	# A rejected decline (a second decline against the now-resolved offer) also draws no RNG.
	DeclineRewardCommand.new().execute(run)
	assert_equal(streams.to_snapshot(), before, "A rejected decline must draw no RNG (stream set unchanged).")
