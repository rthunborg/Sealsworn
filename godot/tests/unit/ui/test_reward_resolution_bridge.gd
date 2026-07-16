extends "res://tests/unit/test_case.gd"

# Story 13.2 — RewardResolutionBridge (the caller-driven run-command seam that resolves a pending reward offer from
# a click, AC1/AC2/AC3). It mirrors RunEndProfileBridge's construct+execute+sequence_id idiom (a run command
# executed against RunState with the monotonic orchestrator.next_sequence_id()) — NOT a TacticalCommandBridge intent.
#
# This test pins:
#   - resolve_generic executes ResolveRewardCommand: a NON-passive offer resolves (offer -> resolved), emitting the
#     reward_resolved record, drawing ZERO new RNG (the offer was rolled at GENERATE);
#   - commit_passive + consume executes ConsumePassiveCommand: the passive is ADOPTED into the run's RulesResolver,
#     the offer flips resolved, and ONLY a passive_consumed event is emitted (no double-record with reward_resolved);
#   - commit_passive + destroy executes DestroyPassiveCommand: the offer flips resolved, a passive_destroyed event
#     is emitted, and the roll ADVANCES the run-level STREAM_REWARDS (ONE draw through the run streams — never a
#     fresh RandomNumberGenerator; deterministic for the same seed);
#   - a NON-committed intent (committed == false) runs NO command -> the RunState + the run streams are byte-identical
#     (AC2 no-mutation back-out);
#   - EXACTLY ONE command resolves an offer: a second resolve against a now-resolved offer fails closed
#     (reward_offer_already_resolved) — no double-apply;
#   - the bridge's own fail-closed paths (a null context / an unsupported action / an unsupported passive choice).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RewardResolutionBridge = preload("res://scripts/ui/flow/reward_resolution_bridge.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")

const SEED: int = 4242

func run() -> Dictionary:
	_resolve_generic_executes_resolve_reward_command()
	_consume_executes_consume_passive_command_and_adopts_into_the_resolver()
	_destroy_executes_destroy_passive_command_and_advances_the_rewards_stream()
	_destroy_is_deterministic_through_the_run_streams()
	_non_committed_intent_runs_no_command_and_mutates_nothing()
	_exactly_one_command_resolves_an_offer_no_double_apply()
	_fails_closed_on_bad_context_action_and_choice()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _started(seed_value: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Seed %d: start should succeed." % seed_value)
	return orchestrator


func _generic_resolution(offer: RewardOffer) -> Dictionary:
	var entry: Dictionary = offer.offered_entries[0]
	return {
		"action": "resolve_generic",
		"category": String(entry.get("category")),
		"content_id": String(entry.get("content_id"))
	}


func _passive_resolution(offer: RewardOffer, choice: String) -> Dictionary:
	var entry: Dictionary = offer.offered_entries[0]
	return {
		"action": "commit_passive",
		"committed": true,
		"choice": choice,
		"passive_content_id": String(entry.get("content_id")),
		"table_id": String(offer.table_id)
	}


# ---- AC1: generic resolve ------------------------------------------------------------------------

func _resolve_generic_executes_resolve_reward_command() -> void:
	var orchestrator: RunOrchestrator = _started(SEED)
	assert_true(orchestrator.generate_reward_offer(&"standard_combat_reward").succeeded, "Setup: a generic offer should generate.")
	var offer: RewardOffer = orchestrator.run.pending_reward_offer
	var pre_streams: Dictionary = orchestrator.streams.to_snapshot()

	var resolved: ActionResult = RewardResolutionBridge.new().resolve(orchestrator.run, orchestrator, _generic_resolution(offer))
	assert_true(resolved.succeeded, "The generic resolve should succeed: %s" % resolved.metadata)
	assert_true(orchestrator.run.pending_reward_offer.is_resolved(), "The offer must flip to resolved.")
	# RESOLVE draws ZERO new RNG (the offer was rolled at GENERATE).
	assert_equal(orchestrator.streams.to_snapshot(), pre_streams, "A generic resolve must draw ZERO new RNG (streams byte-identical).")
	# A reward_resolved event is emitted.
	var saw_resolved: bool = false
	for event: DomainEvent in resolved.events:
		if event.event_type == DomainEvent.Type.REWARD_RESOLVED:
			saw_resolved = true
	assert_true(saw_resolved, "The generic resolve emits a reward_resolved event.")


# ---- AC2: passive Consume ------------------------------------------------------------------------

func _consume_executes_consume_passive_command_and_adopts_into_the_resolver() -> void:
	var orchestrator: RunOrchestrator = _started(SEED)
	assert_true(orchestrator.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup: a passive offer should generate.")
	var offer: RewardOffer = orchestrator.run.pending_reward_offer
	var pre_streams: Dictionary = orchestrator.streams.to_snapshot()

	var consumed: ActionResult = RewardResolutionBridge.new().resolve(orchestrator.run, orchestrator, _passive_resolution(offer, "consume"))
	assert_true(consumed.succeeded, "The consume should succeed: %s" % consumed.metadata)
	assert_true(orchestrator.run.pending_reward_offer.is_resolved(), "Consume must flip the offer resolved.")
	# Consume draws ZERO RNG + adopts the passive into the run's resolver.
	assert_equal(orchestrator.streams.to_snapshot(), pre_streams, "Consume must draw ZERO RNG (streams byte-identical).")
	assert_true(orchestrator.run.rules_resolver != null, "Consume adopts the passive into a live RulesResolver.")
	assert_true(orchestrator.run.rules_resolver.registered_passive_count() >= 1, "The consumed passive must be registered.")
	# ONLY a passive_consumed event (no double-record with reward_resolved).
	var consumed_events: int = 0
	var resolved_events: int = 0
	for event: DomainEvent in consumed.events:
		if event.event_type == DomainEvent.Type.PASSIVE_CONSUMED:
			consumed_events += 1
		if event.event_type == DomainEvent.Type.REWARD_RESOLVED:
			resolved_events += 1
	assert_equal(consumed_events, 1, "Consume emits exactly one passive_consumed event.")
	assert_equal(resolved_events, 0, "Consume must NOT also emit reward_resolved (no double-record).")


# ---- AC2: passive Destroy ------------------------------------------------------------------------

func _destroy_executes_destroy_passive_command_and_advances_the_rewards_stream() -> void:
	var orchestrator: RunOrchestrator = _started(SEED)
	assert_true(orchestrator.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup: a passive offer should generate.")
	var offer: RewardOffer = orchestrator.run.pending_reward_offer
	var pre_snapshot: Dictionary = orchestrator.streams.to_snapshot()
	var pre_rewards: Dictionary = (pre_snapshot.get("streams") as Dictionary).get("rewards")
	var pre_draw_index: int = int(pre_rewards.get("draw_index"))

	var destroyed: ActionResult = RewardResolutionBridge.new().resolve(orchestrator.run, orchestrator, _passive_resolution(offer, "destroy"))
	assert_true(destroyed.succeeded, "The destroy should succeed: %s" % destroyed.metadata)
	assert_true(orchestrator.run.pending_reward_offer.is_resolved(), "Destroy must flip the offer resolved.")
	# Destroy rolls ONE draw through the run-level rewards stream (the stream ADVANCED).
	var post_rewards: Dictionary = (orchestrator.streams.to_snapshot().get("streams") as Dictionary).get("rewards")
	assert_equal(int(post_rewards.get("draw_index")), pre_draw_index + 1, "Destroy advances the run-level rewards stream by exactly ONE draw.")
	# Destroy does NOT adopt the passive (rules_resolver untouched by Destroy).
	var saw_destroyed: bool = false
	for event: DomainEvent in destroyed.events:
		if event.event_type == DomainEvent.Type.PASSIVE_DESTROYED:
			saw_destroyed = true
	assert_true(saw_destroyed, "Destroy emits a passive_destroyed event.")


func _destroy_is_deterministic_through_the_run_streams() -> void:
	# The same seed + same pre-draw state -> the same rolled Destroy outcome (proving the run-level streams are used,
	# not a fresh RandomNumberGenerator).
	var a: RunOrchestrator = _started(SEED)
	var b: RunOrchestrator = _started(SEED)
	assert_true(a.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup A: passive offer.")
	assert_true(b.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup B: passive offer.")
	var res_a: ActionResult = RewardResolutionBridge.new().resolve(a.run, a, _passive_resolution(a.run.pending_reward_offer, "destroy"))
	var res_b: ActionResult = RewardResolutionBridge.new().resolve(b.run, b, _passive_resolution(b.run.pending_reward_offer, "destroy"))
	assert_true(res_a.succeeded and res_b.succeeded, "Both destroys should succeed.")
	assert_equal(
		String(res_a.metadata.get("outcome_id")),
		String(res_b.metadata.get("outcome_id")),
		"The same seed must roll the SAME Destroy outcome (deterministic through the run-level streams)."
	)


# ---- AC2: no-mutation back-out -------------------------------------------------------------------

func _non_committed_intent_runs_no_command_and_mutates_nothing() -> void:
	var orchestrator: RunOrchestrator = _started(SEED)
	assert_true(orchestrator.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup: a passive offer should generate.")
	var pre_run: String = JSON.stringify(orchestrator.run.to_dictionary())
	var pre_streams: Dictionary = orchestrator.streams.to_snapshot()

	var back_out: ActionResult = RewardResolutionBridge.new().resolve(orchestrator.run, orchestrator, {
		"action": "commit_passive",
		"committed": false,
		"choice": "consume",
		"passive_content_id": "warrior_unbreakable_guard",
		"table_id": "passive_reward_choice"
	})
	assert_true(back_out.succeeded, "A non-committed intent is a benign no-op ok.")
	assert_false(back_out.has_events(), "A non-committed intent emits no event.")
	assert_true(orchestrator.run.pending_reward_offer.is_pending(), "The offer stays pending after a back-out.")
	# AC2 — the RunState is byte-identical + the streams are byte-identical (no command ran).
	assert_equal(JSON.stringify(orchestrator.run.to_dictionary()), pre_run, "A back-out leaves the RunState byte-identical.")
	assert_equal(orchestrator.streams.to_snapshot(), pre_streams, "A back-out draws ZERO RNG.")


# ---- AC3: exactly one command per offer ----------------------------------------------------------

func _exactly_one_command_resolves_an_offer_no_double_apply() -> void:
	var orchestrator: RunOrchestrator = _started(SEED)
	assert_true(orchestrator.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup: a passive offer should generate.")
	var offer: RewardOffer = orchestrator.run.pending_reward_offer
	var bridge: RewardResolutionBridge = RewardResolutionBridge.new()
	assert_true(bridge.resolve(orchestrator.run, orchestrator, _passive_resolution(offer, "consume")).succeeded, "The first consume resolves the offer.")
	# A SECOND resolution against the now-resolved offer fails closed (no double-apply / double-record).
	var second: ActionResult = bridge.resolve(orchestrator.run, orchestrator, _passive_resolution(offer, "consume"))
	assert_true(second.is_error(), "A second resolve against a resolved offer must fail closed.")
	assert_equal(second.error_code, &"reward_offer_already_resolved", "The second resolve uses the stable already-resolved code.")


# ---- fail-closed bridge paths --------------------------------------------------------------------

func _fails_closed_on_bad_context_action_and_choice() -> void:
	var orchestrator: RunOrchestrator = _started(SEED)
	var bridge: RewardResolutionBridge = RewardResolutionBridge.new()
	# A null run is a structured error (never a crash).
	var null_run: ActionResult = bridge.resolve(null, orchestrator, {"action": "resolve_generic"})
	assert_true(null_run.is_error(), "A null run fails closed.")
	assert_equal(null_run.error_code, &"invalid_reward_resolution_context", "A null context uses the stable context code.")
	# An unsupported action fails closed.
	var bad_action: ActionResult = bridge.resolve(orchestrator.run, orchestrator, {"action": "not_a_reward_action"})
	assert_true(bad_action.is_error(), "An unsupported action fails closed.")
	assert_equal(bad_action.error_code, &"unsupported_reward_resolution", "An unsupported action uses the stable code.")
	# An unsupported passive choice fails closed.
	assert_true(orchestrator.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Setup: a passive offer for the bad-choice probe.")
	var bad_choice: ActionResult = bridge.resolve(orchestrator.run, orchestrator, {
		"action": "commit_passive",
		"committed": true,
		"choice": "obliterate",
		"passive_content_id": "warrior_unbreakable_guard",
		"table_id": "passive_reward_choice"
	})
	assert_true(bad_choice.is_error(), "An unsupported passive choice fails closed.")
	assert_equal(bad_choice.error_code, &"unsupported_passive_choice", "An unsupported choice uses the stable code.")
