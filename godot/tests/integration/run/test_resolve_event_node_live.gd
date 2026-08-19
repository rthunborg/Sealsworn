extends "res://tests/unit/test_case.gd"

# Story 15.5 (Review Med patch — the one genuinely-uncovered new domain seam) — RunOrchestrator.resolve_event_node_live:
# the ON-SCREEN event-node resolution seam the route map drives (via EventNodeOverlay) AFTER generate_event_offer +
# EventViewModel present + the human's pick. It applies the pick through ChooseEventOptionCommand, then transitions
# ACTIVE_ROUTE -> NODE_RESOLUTION -> NodeExitCommand (clear the node), and returns the before/after outcome metadata the
# AC3 EventOutcomeViewModel reads. Before this test the seam had NO direct coverage (grep -rn resolve_event_node_live
# tests/ returned nothing) — the AC3 unit test exercised ChooseEventOptionCommand + the projection, but NOT the
# orchestrator method that CLEARS the node. This integration test drives a REAL run parked on a REAL generated event
# node (seed 1 -> node-1-0, smugglers_cache) through generate_event_offer -> resolve_event_node_live and pins:
#   (a) a valid pick CLEARS the node + the phase returns to ACTIVE_ROUTE;
#   (b) the outcome metadata MATCHES the applied ChooseEventOptionCommand (the real economy deltas + event_resolved);
#   (c) an off-offer/invalid choice_id FAILS CLOSED with the node still UN-cleared + the offer still pending (re-pickable);
#   (d) the node_not_event guard rejects a non-event node; the already-cleared guard is a stable no-op (no double-clear).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Seed 1 parks on an EVENT node (node-1-0, smugglers_cache) after a single advance (probe-verified). The generator
# guarantees the depth-0 opener is a COMBAT node, so start(1) also gives a clean non-event node for the guard test.
const EVENT_SEED: int = 1

func run() -> Dictionary:
	_valid_pick_clears_the_node_returns_to_active_route_and_surfaces_the_outcome()
	_invalid_choice_fails_closed_with_the_node_uncleared_and_repickable()
	_node_not_event_guard_rejects_a_non_event_node()
	_already_cleared_guard_is_a_stable_noop()
	_no_active_run_guard_fails_closed()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Drive a real run to a position PARKED on an unresolved EVENT node in ACTIVE_ROUTE (resolve-current then advance,
# preferring an event successor when one is eligible — mirroring _orchestrator_parked_after_clearing). Fails loud if the
# seed does not reach an event node within the bound.
func _parked_on_event_node(seed_value: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Setup: start seed %d should succeed." % seed_value)
	var steps: int = 0
	while not orchestrator.run.is_terminal() and steps < 14:
		var current: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
		if current != null and current.type == RouteNode.TYPE_EVENT:
			assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "Setup: the parked event node is at an ACTIVE_ROUTE choice.")
			assert_false(orchestrator.run.route.cleared_node_ids.has(current.id), "Setup: the parked event node is NOT yet cleared.")
			return orchestrator
		if current == null or current.type == RouteNode.TYPE_BOSS:
			break
		assert_true(orchestrator.resolve_current_node().succeeded, "Setup: resolve step %d should succeed." % steps)
		var eligible: Array = orchestrator.run.route.eligible_choice_ids()
		assert_false(eligible.is_empty(), "Setup: an eligible choice must exist at step %d (no soft-lock)." % steps)
		var next_id: String = String(eligible[0])
		for cid: Variant in eligible:
			var node: RouteNode = orchestrator.run.route.node_by_id(String(cid))
			if node != null and node.type == RouteNode.TYPE_EVENT:
				next_id = String(cid)
				break
		assert_true(orchestrator.advance_to(next_id).succeeded, "Setup: advance to %s should succeed." % next_id)
		steps += 1
	assert_true(false, "Setup: seed %d must park on an event node within the bound." % seed_value)
	return orchestrator


# ---- (a) + (b): a valid pick clears the node, returns to ACTIVE_ROUTE, surfaces the applied outcome --------------

func _valid_pick_clears_the_node_returns_to_active_route_and_surfaces_the_outcome() -> void:
	var orchestrator: RunOrchestrator = _parked_on_event_node(EVENT_SEED)
	var node_id: String = orchestrator.run.route.current_node_id
	assert_equal(String(orchestrator.run.route.node_by_id(node_id).type), String(RouteNode.TYPE_EVENT), "Setup: parked on an event node.")

	# Generate the LIVE offer (the events-stream roll) — the only production caller before resolve.
	var generate: ActionResult = orchestrator.generate_event_offer()
	assert_true(generate.succeeded, "Setup: generate the event offer: %s" % generate.metadata)
	var choice_ids: Array = orchestrator.run.pending_event_offer.offered_choice_ids
	assert_true(choice_ids.size() >= 1, "Setup: the offer carries choice ids.")
	var event_id: StringName = orchestrator.run.pending_event_offer.event_id
	var choice_id: StringName = StringName(String(choice_ids[0]))
	# Snapshot the pre-choice economy so the outcome deltas can be checked against the REAL applied resolution.
	var gold_before: int = orchestrator.run.risk_economy.gold
	var curse_before: int = orchestrator.run.risk_economy.curse_count
	var corruption_before: int = orchestrator.run.risk_economy.corruption

	var resolved: ActionResult = orchestrator.resolve_event_node_live(choice_id)
	assert_true(resolved.succeeded, "A valid pick resolves: %s" % resolved.metadata)

	# (a) the node is CLEARED + the phase returns to ACTIVE_ROUTE (not stranded mid-transition).
	assert_true(orchestrator.run.route.cleared_node_ids.has(node_id), "(a) resolve_event_node_live CLEARS the event node.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "(a) the phase returns to ACTIVE_ROUTE after the exit.")
	assert_true(orchestrator.run.pending_event_offer == null or not orchestrator.run.pending_event_offer.is_pending(), "(a) the offer is no longer pending (it was resolved, not left dangling).")

	# (b) the outcome metadata MATCHES the applied ChooseEventOptionCommand (real economy, not invented data).
	assert_equal(String(resolved.metadata.get("resolution")), "event_resolved", "(b) the resolution is event_resolved (NOT a placeholder counter bump).")
	assert_equal(String(resolved.metadata.get("event_id")), String(event_id), "(b) the outcome carries the resolved event id.")
	assert_equal(String(resolved.metadata.get("choice_id")), String(choice_id), "(b) the outcome carries the chosen id.")
	assert_equal(int(resolved.metadata.get("gold_before")), gold_before, "(b) gold_before matches the pre-choice economy.")
	assert_equal(int(resolved.metadata.get("gold_after")), orchestrator.run.risk_economy.gold, "(b) gold_after matches the REAL applied economy (the choice's gold side was actually applied).")
	assert_equal(int(resolved.metadata.get("curse_before")), curse_before, "(b) curse_before matches the pre-choice economy.")
	assert_equal(int(resolved.metadata.get("curse_after")), orchestrator.run.risk_economy.curse_count, "(b) curse_after matches the REAL applied economy.")
	assert_equal(int(resolved.metadata.get("corruption_after")), orchestrator.run.risk_economy.corruption, "(b) corruption_after matches the REAL applied economy.")
	assert_true(resolved.metadata.has("risk_flags"), "(b) the outcome surfaces the raised risk flags key.")
	# The applied resolution emitted an event_resolved domain event (the AC3 source, not a placeholder marker).
	assert_true(_has_event_of_type(resolved.events, DomainEvent.Type.EVENT_RESOLVED), "(b) resolve_event_node_live surfaces the event_resolved domain event.")


# ---- (c): an off-offer choice fails closed BEFORE any clear, offer stays pending (re-pickable) -------------------

func _invalid_choice_fails_closed_with_the_node_uncleared_and_repickable() -> void:
	var orchestrator: RunOrchestrator = _parked_on_event_node(EVENT_SEED)
	var node_id: String = orchestrator.run.route.current_node_id
	assert_true(orchestrator.generate_event_offer().succeeded, "Setup: generate the offer.")
	var gold_before: int = orchestrator.run.risk_economy.gold

	var rejected: ActionResult = orchestrator.resolve_event_node_live(&"not_a_real_choice_id")
	assert_true(rejected.is_error(), "(c) an off-offer choice_id fails closed.")
	assert_equal(rejected.error_code, &"invalid_event_choice", "(c) the off-offer pick surfaces the ChooseEventOptionCommand error VERBATIM (invalid_event_choice).")
	# Fail-closed BEFORE any node clear: the node is still un-cleared, the run stays in ACTIVE_ROUTE, ZERO economy mutation.
	assert_false(orchestrator.run.route.cleared_node_ids.has(node_id), "(c) the event node stays UN-cleared on a rejected pick (never a silent clear).")
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "(c) the run stays in ACTIVE_ROUTE (no half-transition into NODE_RESOLUTION).")
	assert_equal(orchestrator.run.risk_economy.gold, gold_before, "(c) a rejected pick mutates NO economy.")
	# The offer stays pending -> the player can re-pick (a decline is always affordable — no soft-lock, the 14.6 posture).
	assert_true(orchestrator.run.pending_event_offer != null and orchestrator.run.pending_event_offer.is_pending(), "(c) the offer stays pending (re-pickable — no stall).")

	# A subsequent VALID pick still resolves (the re-pick path clears the node — an event node ALWAYS resolves).
	var choice_id: StringName = StringName(String(orchestrator.run.pending_event_offer.offered_choice_ids[0]))
	var re_pick: ActionResult = orchestrator.resolve_event_node_live(choice_id)
	assert_true(re_pick.succeeded, "(c) a valid re-pick after the reject resolves (no stall): %s" % re_pick.metadata)
	assert_true(orchestrator.run.route.cleared_node_ids.has(node_id), "(c) the valid re-pick CLEARS the node.")


# ---- (d): the node_not_event guard + the already-cleared no-op guard ---------------------------------------------

func _node_not_event_guard_rejects_a_non_event_node() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(EVENT_SEED, false).succeeded, "Setup: start.")
	# The depth-0 opener is a COMBAT node (the generator guarantees it), so the parked node is NOT an event node.
	var current: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
	assert_false(String(current.type) == String(RouteNode.TYPE_EVENT), "Setup: the parked depth-0 node is NOT an event node (it is %s)." % current.type)

	var rejected: ActionResult = orchestrator.resolve_event_node_live(&"take_the_gold")
	assert_true(rejected.is_error(), "(d) resolve_event_node_live rejects a NON-event node.")
	assert_equal(rejected.error_code, &"node_not_event", "(d) a non-event node uses the stable node_not_event code.")
	assert_false(orchestrator.run.route.cleared_node_ids.has(current.id), "(d) the non-event node is NOT cleared by the rejected call.")


func _already_cleared_guard_is_a_stable_noop() -> void:
	var orchestrator: RunOrchestrator = _parked_on_event_node(EVENT_SEED)
	var node_id: String = orchestrator.run.route.current_node_id
	assert_true(orchestrator.generate_event_offer().succeeded, "Setup: generate the offer.")
	var choice_id: StringName = StringName(String(orchestrator.run.pending_event_offer.offered_choice_ids[0]))
	assert_true(orchestrator.resolve_event_node_live(choice_id).succeeded, "Setup: resolve the event once.")
	assert_true(orchestrator.run.route.cleared_node_ids.has(node_id), "Setup: the node is now cleared.")
	var cleared_count_before: int = orchestrator.run.route.cleared_node_ids.size()

	# A second resolve on the STILL-CURRENT already-cleared node is a stable no-op (not a double-clear, not an error).
	var again: ActionResult = orchestrator.resolve_event_node_live(choice_id)
	assert_true(again.succeeded, "(d) a second resolve on the cleared node is a NO-OP, not an error.")
	assert_equal(String(again.metadata.get("resolution")), "already_cleared_noop", "(d) the already-cleared guard returns already_cleared_noop.")
	assert_equal(orchestrator.run.route.cleared_node_ids.size(), cleared_count_before, "(d) the no-op does NOT double-clear the node.")


func _no_active_run_guard_fails_closed() -> void:
	# A fail-closed guard on an unstarted orchestrator (no seated run) — never a crash.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var rejected: ActionResult = orchestrator.resolve_event_node_live(&"take_the_gold")
	assert_true(rejected.is_error(), "resolve_event_node_live on an unstarted run fails closed.")
	assert_equal(rejected.error_code, &"no_active_run", "An unstarted run uses the stable no_active_run code.")


# ---- helpers -------------------------------------------------------------------------------------

func _has_event_of_type(events: Array, event_type: int) -> bool:
	for event_value: Variant in events:
		if event_value is DomainEvent and (event_value as DomainEvent).event_type == event_type:
			return true
	return false
