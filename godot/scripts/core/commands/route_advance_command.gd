class_name RouteAdvanceCommand
extends "res://scripts/core/commands/game_command.gd"

# The route CHOICE / forward-commitment command (Story 4.3) — the FIRST run-domain command. It
# validates a chosen next node against the reveal-gated, cleared-excluded eligibility filter
# (RouteState.eligible_choice_ids, the filter 4.1 deferred here) and the run phase, then COMMITS the
# advance as a single coherent mutation: move current_node_id forward, append the LEFT node to
# cleared_node_ids + mark it REVEAL_CLEARED, REVEAL the arrived node's direct forward neighbors
# (HIDDEN -> REVEALED) so the next tier becomes selectable (the reveal-on-arrival mechanic that
# prevents soft-lock — the 4.2 generator reveals only depths 0-1), and emit ONE route_advanced
# DomainEvent. On any rejection it returns a structured ActionResult.error with ZERO events and
# mutates NOTHING (the RunState/RouteState is byte-identical). It draws ZERO RNG.
#
# WHAT THIS IS NOT (scope boundaries):
#   - NOT route GENERATION (Story 4.2 — draws the `map` stream; this command touches no stream).
#   - NOT node ENTRY/EXIT, level-request creation, or the door_sealed/route_sealed presentation cue
#     (Story 4.4). It records the route-state TRUTH of "the path sealed behind you" and emits
#     route_advanced; it does NOT emit a door-sealed cue and does NOT create a level GenerationRequest.
#   - NOT per-node-type RESOLUTION behavior (Story 4.5) — it advances the pointer regardless of type.
#   - NOT the run-START command / run_started emission (Story 4.6).
#
# DESIGN DECISIONS (per the story AC-interpretation notes):
#   - CONTEXT SHAPE: validate(state)/execute(state) accept the RunState DIRECTLY (a single-field
#     context; a RunActionContext wrapper would add no value for one field — kept simple + typed).
#   - PHASE TRANSITION: AC-interpretation option (A) — this command advances ONLY the route pointer
#     and leaves the run in PHASE_ACTIVE_ROUTE. It does NOT transition ACTIVE_ROUTE -> NODE_RESOLUTION;
#     that transition belongs with node ENTRY (Story 4.4). The command REQUIRES PHASE_ACTIVE_ROUTE and
#     rejects any other phase with a stable wrong_run_phase code.
#   - SEQUENCE ID: the run domain has no event sequencer yet (BoardState owns the tactical one; a
#     run-level log/orchestrator is a later story). The caller supplies the run-level sequence id via
#     the constructor (default 1, kept > 0 so the event is valid). The command itself stays
#     deterministic given (run, target, sequence id).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var target_node_id: String = ""
var sequence_id: int = 1

func _init(new_target_node_id: String = "", new_sequence_id: int = 1) -> void:
	command_id = &"route_advance"
	target_node_id = new_target_node_id
	sequence_id = new_sequence_id


# Pure read: validate the context, phase, and chosen-node eligibility. No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	if run.route == null:
		return _invalid_context()
	# The run/route must be structurally sound before we reason about a choice.
	if run.validate().is_error():
		return _invalid_context()

	# The route choice/commit happens IN PHASE_ACTIVE_ROUTE. Reject any other phase (AC3).
	if run.phase != RunState.PHASE_ACTIVE_ROUTE:
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_ACTIVE_ROUTE)
		})

	var route: RouteState = run.route
	# The run must be parked on a node to have any choice.
	if route.current_node_id.is_empty():
		return ActionResult.error(&"no_current_node", {
			"command": String(command_id)
		})

	# The chosen node must be in the reveal-gated, cleared-excluded eligible set (AC1). A single
	# stable top-level code (ineligible_route_choice) holds AC3's "stable error"; the precise reason
	# is carried in metadata for diagnostics (node ids carry hyphens -> metadata, NEVER the code).
	if not route.is_eligible_choice(target_node_id):
		return ActionResult.error(&"ineligible_route_choice", {
			"command": String(command_id),
			"target_node_id": target_node_id,
			"current_node_id": route.current_node_id,
			"reason": _ineligibility_reason(route, target_node_id)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: clear-the-left-node + advance the pointer + reveal-on-arrival +
# emit ONE route_advanced event. Draws ZERO RNG; runs no sub-command.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var route: RouteState = run.route
	var from_node_id: String = route.current_node_id

	# (1) Seal the path behind the hero: the LEFT node moves to cleared_node_ids + REVEAL_CLEARED.
	var left_node: RouteNode = route.node_by_id(from_node_id)
	left_node.reveal_state = RouteNode.REVEAL_CLEARED
	var cleared: Array[String] = route.cleared_node_ids.duplicate()
	cleared.append(from_node_id)
	route.cleared_node_ids = cleared

	# (2) Advance the pointer to the chosen node.
	route.current_node_id = target_node_id
	var arrived: RouteNode = route.node_by_id(target_node_id)

	# (3) Reveal-on-arrival: flip the arrived node's direct forward neighbors HIDDEN -> REVEALED so
	# the next tier is selectable (prevents soft-lock). Reveal is MONOTONIC: only HIDDEN flips; an
	# already-REVEALED/CLEARED neighbor is left untouched. Collect the newly-revealed ids (in the
	# arrived node's link order) for the event payload.
	var revealed_ids: Array[String] = []
	for link_id: String in arrived.outgoing_link_ids:
		var neighbor: RouteNode = route.node_by_id(link_id)
		if neighbor == null:
			continue
		if neighbor.reveal_state == RouteNode.REVEAL_HIDDEN:
			neighbor.reveal_state = RouteNode.REVEAL_REVEALED
			revealed_ids.append(link_id)

	# (4) Build the single route_advanced system event.
	var event: DomainEvent = DomainEvent.route_advanced(sequence_id, {
		"from_node_id": from_node_id,
		"to_node_id": target_node_id,
		"to_node_type": String(arrived.type),
		"to_node_depth": arrived.depth,
		"cleared_node_id": from_node_id,
		"revealed_node_ids": revealed_ids
	})

	# (5) Return ok with the event + diagnostics metadata.
	return ActionResult.ok([event], {
		"advances_route": true,
		"from_node_id": from_node_id,
		"to_node_id": target_node_id,
		"cleared_node_id": from_node_id,
		"revealed_node_ids": revealed_ids
	})


func _invalid_context() -> ActionResult:
	return ActionResult.error(&"invalid_context", {"command": String(command_id)})


# Derive a precise diagnostic reason for an ineligible chosen node (metadata only — the top-level
# error code stays the stable ineligible_route_choice). Order mirrors AC3's enumeration.
func _ineligibility_reason(route: RouteState, node_id: String) -> String:
	if node_id == route.current_node_id:
		return "is_current_node"
	if not route.has_node(node_id):
		return "unknown_node"
	if route.cleared_node_ids.has(node_id):
		return "cleared_node"
	var current: RouteNode = route.node_by_id(route.current_node_id)
	if current == null or not current.outgoing_link_ids.has(node_id):
		return "not_linked"
	var target: RouteNode = route.node_by_id(node_id)
	if target != null and target.reveal_state != RouteNode.REVEAL_REVEALED:
		return "hidden_node"
	return "ineligible"
