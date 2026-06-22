class_name NodeResolvePlaceholderCommand
extends "res://scripts/core/commands/game_command.gd"

# The placeholder node RESOLUTION command (Story 4.5) — the run-domain command that safely resolves the
# five non-combat MVP node types (shop/reforge/gambling/event/secret) AND the boss placeholder so a
# generated route is fully traversable start-to-end with NO soft-lock and NO broken gameplay. It is the
# SIBLING of NodeEnterCommand (the combat-only level entry): NodeEnterCommand handles combat/elite_combat;
# this command handles EVERYTHING ELSE (the complement set, plus boss). The two partition the 8
# RouteNode.supported_types() with no gap and no overlap, so every node type has exactly one resolution
# path and no node type can ever be a dead end (the AC1 "no broken gameplay" guarantee).
#
# TWO RESOLUTION PATHS, cleanly separated by node type:
#   - NON-BOSS placeholder (shop/reforge/gambling/event/secret): there is NO tactical level and NO
#     GenerationRequest in v0. Transition ACTIVE_ROUTE -> NODE_RESOLUTION, emit ONE node_placeholder_
#     resolved event (the "placeholder completion in domain/debug terms" record carrying a stable
#     placeholder_completed marker + a metadata flag), and STOP there so the EXISTING NodeExitCommand
#     exits it exactly like a combat node (it clears + returns to ACTIVE_ROUTE). NO cleared-set mutation
#     here — the exit clears it (keep the clear in ONE place, mirroring the 4.4 cleared-set discipline;
#     a double-clear would trip RouteState.validate()'s duplicate_cleared_node).
#   - BOSS (AC3): there is NO real boss level in v0 — it is a placeholder run-END. Mark the boss node
#     REVEAL_CLEARED + append it to cleared_node_ids (idempotently), transition ACTIVE_ROUTE ->
#     NODE_RESOLUTION THEN NODE_RESOLUTION -> COMPLETED, and emit node_placeholder_resolved (the boss IS a
#     placeholder node too) + run_completed (the run-end boundary carrying a boss_placeholder outcome + the
#     boss node id + the cleared-node count). The boss does NOT use NodeExitCommand (there is no
#     return-to-route from a terminal boss). Epic 9 replaces the boss's PRE-completion behavior (run a real
#     boss level + a real victory) through the SAME node + the SAME run_completed boundary — WITHOUT
#     changing the route model, the boss node type, or the run-completed boundary.
#
# WHAT THIS IS NOT (scope boundaries — the single biggest risk for this story):
#   - It does NOT generate routes / assign node types (RouteGenerator already assigns all 8 types + one
#     terminal boss, Story 4.2). It CONSUMES the generated route + its assigned types.
#   - It does NOT build a level GenerationRequest and does NOT run LevelGenerator (placeholder nodes have
#     no board; the boss runs no real level in v0). It draws ZERO RNG.
#   - It is NOT a real shop / reforge / gambling / event / secret / reward / boss SYSTEM. "placeholder
#     completion" is a deterministic event + metadata flag. Concrete loot is Epic 6; the risk economy +
#     affinities are Epic 7; the Larval Avatar boss + victory is Epic 9.
#   - It does NOT emit run_started, does NOT measure pacing, and does NOT save/resume route position
#     (Story 4.6 — which CONSUMES the run_completed boundary this command ships, rather than re-creating it).
#
# DESIGN DECISIONS (per the story AC-interpretation notes):
#   - CONTEXT SHAPE: validate(state)/execute(state) accept the RunState DIRECTLY (mirroring 4.3/4.4).
#   - SEQUENCE IDS: a non-boss placeholder emits ONE event (node_placeholder_resolved) at the caller-
#     supplied sequence_id. The BOSS emits TWO (node_placeholder_resolved at sequence_id, run_completed at
#     sequence_id + 1 via _run_completed_sequence_id). validate() gates BOTH ids > 0 BEFORE reading/
#     mutating state (the exact 4.3/4.4 invalid_event_sequence_id guard) so a success path can never emit
#     an event its own validator would reject.
#   - BOSS EMITS TWO EVENTS (not one): the boss IS a placeholder node (consistent node_placeholder_resolved
#     for EVERY placeholder type incl. boss) AND it ends the run (run_completed). See Completion Notes.
#   - PLACEHOLDER_NODE_TYPES is derived as the COMPLEMENT of NodeEnterCommand.NODE_TYPE_RECIPE (the combat
#     set) over RouteNode.supported_types(), so the two commands stay in lockstep and partition all 8 types.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
# (NodeEnterCommand is intentionally NOT preloaded: PLACEHOLDER_NODE_TYPES is the explicit complement of
# its NODE_TYPE_RECIPE, and the complement-coverage test cross-checks the two sets directly — keeping the
# combat command out of this command's preload graph.)
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The stable placeholder-resolution marker carried by node_placeholder_resolved for EVERY placeholder node
# (the five non-combat types AND the boss). Lower_snake; the command sets it and tests assert the exact
# value. Equal to DomainEvent.RESOLUTION_PLACEHOLDER (the event validator pins the same value) — referenced
# from the event const so the command and validator stay in lockstep on the marker vocabulary.
const RESOLUTION_PLACEHOLDER := DomainEvent.RESOLUTION_PLACEHOLDER

# The stable boss run-completion outcome carried by run_completed when the boss placeholder resolves.
# Lower_snake; equal to DomainEvent.RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER (the event validator pins it).
const BOSS_OUTCOME := DomainEvent.RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER

# The node types this command ACCEPTS: the COMPLEMENT of NodeEnterCommand's combat set (combat/elite_
# combat) over RouteNode.supported_types(), i.e. shop/reforge/gambling/event/secret AND boss. This is a
# true compile-time constant (a function-initialized const cannot be referenced cross-script), so the
# complement is written explicitly here; the complement-coverage test (test_node_resolve_placeholder_
# command.gd::_placeholder_and_combat_sets_partition_all_node_types) PROVES it stays the exact complement
# of NodeEnterCommand.NODE_TYPE_RECIPE over RouteNode.supported_types() — no gap, no overlap, all 8 types —
# so the two commands stay in lockstep and no node type can ever be a dead end. A combat/elite node passed
# here is rejected with node_not_placeholder (it uses NodeEnterCommand).
const PLACEHOLDER_NODE_TYPES := {
	RouteNode.TYPE_SHOP: true,
	RouteNode.TYPE_REFORGE: true,
	RouteNode.TYPE_GAMBLING: true,
	RouteNode.TYPE_EVENT: true,
	RouteNode.TYPE_SECRET: true,
	RouteNode.TYPE_BOSS: true
}

var sequence_id: int = 1

func _init(new_sequence_id: int = 1) -> void:
	command_id = &"node_resolve_placeholder"
	sequence_id = new_sequence_id


# Pure read: validate BOTH possible event sequence ids, context, phase, parked-on-a-node, and
# placeholder-node-type. No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (mirror NodeExitCommand): execute() may build node_placeholder_resolved
	# (sequence_id) AND — for the boss — run_completed (sequence_id + 1); DomainEvent.try_from_dictionary
	# requires sequence_id > 0. Gate BOTH ids BEFORE any state is read or mutated so the success path can
	# never emit a non-round-trippable event. (sequence_id + 1 is non-positive only if sequence_id <= -1,
	# already caught by the first check — but assert the second-event id explicitly for clarity / future
	# offset changes.)
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if _run_completed_sequence_id() <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": _run_completed_sequence_id()
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	if run.route == null:
		return _invalid_context()
	# The run/route must be structurally sound before we reason about resolution.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# Placeholder resolution happens IN PHASE_ACTIVE_ROUTE (it transitions ACTIVE_ROUTE -> NODE_RESOLUTION,
	# and for the boss further to COMPLETED). Reject any other phase with the stable wrong_run_phase code +
	# the actual/expected phase in metadata.
	if run.phase != RunState.PHASE_ACTIVE_ROUTE:
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_ACTIVE_ROUTE)
		})

	var route: RouteState = run.route
	# The run must be parked on a node to resolve one.
	if route.current_node_id.is_empty():
		return ActionResult.error(&"no_current_node", {
			"command": String(command_id)
		})

	# The current node must be a PLACEHOLDER type for this command (the non-combat set + boss). A
	# combat/elite node is genuinely not this command's concern — it uses NodeEnterCommand (the combat
	# level entry). Reject it with a stable code carrying the offending type in metadata (hyphenated node
	# ids / types go in metadata, never in the code).
	var current: RouteNode = route.node_by_id(route.current_node_id)
	if not PLACEHOLDER_NODE_TYPES.has(current.type):
		return ActionResult.error(&"node_not_placeholder", {
			"command": String(command_id),
			"node_id": current.id,
			"node_type": String(current.type)
		})

	return ActionResult.ok()


# Validate-then-mutate. Dispatches by node type: the BOSS path runs the boss-placeholder run-END (clear +
# two transitions + node_placeholder_resolved + run_completed); every other placeholder type runs the
# no-op placeholder resolve (one transition + node_placeholder_resolved). Draws ZERO RNG; builds NO
# GenerationRequest; runs no sub-command.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var route: RouteState = run.route
	var node: RouteNode = route.node_by_id(route.current_node_id)

	if node.type == RouteNode.TYPE_BOSS:
		return _resolve_boss(run, route, node)
	return _resolve_non_boss_placeholder(run, node)


# NON-boss placeholder resolve (AC2): transition ACTIVE_ROUTE -> NODE_RESOLUTION, emit ONE
# node_placeholder_resolved event, and surface a metadata flag. NO cleared-set mutation (NodeExitCommand
# clears it on exit, exactly as it clears a combat node — keep the clear in ONE place). Builds NO
# GenerationRequest. Draws ZERO RNG.
func _resolve_non_boss_placeholder(run: RunState, node: RouteNode) -> ActionResult:
	# Transition ACTIVE_ROUTE -> NODE_RESOLUTION (a legal edge; transition_to validates it). The phase
	# guard in validate() already ensured ACTIVE_ROUTE, so this cannot fail — but check defensively and
	# surface a structured error WITHOUT having emitted any event if it ever did.
	var transition: ActionResult = run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	if transition.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_ACTIVE_ROUTE),
			"inner_error_code": String(transition.error_code)
		})

	# Build the single node_placeholder_resolved event (AFTER the transition succeeded).
	var event: DomainEvent = DomainEvent.node_placeholder_resolved(sequence_id, {
		"node_id": node.id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"resolution": String(RESOLUTION_PLACEHOLDER)
	})

	return ActionResult.ok([event], {
		"placeholder_resolved": true,
		"node_id": node.id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"resolution": String(RESOLUTION_PLACEHOLDER)
	})


# BOSS placeholder resolve (AC3): mark the boss cleared (idempotent), transition ACTIVE_ROUTE ->
# NODE_RESOLUTION THEN NODE_RESOLUTION -> COMPLETED, and emit node_placeholder_resolved + run_completed.
# Builds NO GenerationRequest and runs no real boss combat. Draws ZERO RNG.
func _resolve_boss(run: RunState, route: RouteState, node: RouteNode) -> ActionResult:
	var boss_id: String = node.id

	# (1) ORDERING — mutate-before-infallible-transition (the 4.4 [Review][Patch] Low applied here). The
	# boss path performs TWO mutations the non-boss path does not: it clears the boss AND runs two
	# transition_to calls. validate() already pinned ACTIVE_ROUTE and BOTH edges are always-legal from
	# their respective states, so neither transition can actually fail at runtime — but for robustness/
	# symmetry, run BOTH transitions and check each result, returning a structured wrong_run_phase error
	# WITHOUT having emitted any event if EITHER ever failed. Build the events ONLY AFTER both transitions
	# succeed (never emit run_completed and THEN transition). The boss-clear precedes the transitions,
	# mirroring how NodeExitCommand clears a resolved node before its transition; if a transition somehow
	# failed, validate() pins this as unreachable, so the boss-clear-then-failed-transition half-state
	# cannot occur in practice.
	#
	# Mark the boss REVEAL_CLEARED + append it to cleared_node_ids (idempotent guard) so the cleared-node
	# count in run_completed is correct and run.validate() stays green. The boss is cleared HERE (not by
	# NodeExitCommand) because no exit follows a terminal boss.
	node.reveal_state = RouteNode.REVEAL_CLEARED
	if not route.cleared_node_ids.has(boss_id):
		var cleared: Array[String] = route.cleared_node_ids.duplicate()
		cleared.append(boss_id)
		route.cleared_node_ids = cleared

	# (2) Transition ACTIVE_ROUTE -> NODE_RESOLUTION.
	var to_resolution: ActionResult = run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	if to_resolution.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_ACTIVE_ROUTE),
			"inner_error_code": String(to_resolution.error_code)
		})

	# (3) Transition NODE_RESOLUTION -> COMPLETED (the terminal boss run-end edge).
	var to_completed: ActionResult = run.transition_to(RunState.PHASE_COMPLETED)
	if to_completed.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_NODE_RESOLUTION),
			"inner_error_code": String(to_completed.error_code)
		})

	# (4) Build BOTH events AFTER the run is actually in COMPLETED. The boss is a placeholder node too
	# (node_placeholder_resolved for consistency with every placeholder type) AND it ends the run
	# (run_completed). The run_completed cleared_node_count reflects the FULL path INCLUDING the boss.
	var cleared_count: int = route.cleared_node_ids.size()
	var placeholder_event: DomainEvent = DomainEvent.node_placeholder_resolved(sequence_id, {
		"node_id": boss_id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"resolution": String(RESOLUTION_PLACEHOLDER)
	})
	var run_completed_event: DomainEvent = DomainEvent.run_completed(_run_completed_sequence_id(), {
		"outcome": String(BOSS_OUTCOME),
		"boss_node_id": boss_id,
		"cleared_node_count": cleared_count
	})

	return ActionResult.ok([placeholder_event, run_completed_event], {
		"placeholder_resolved": true,
		"run_completed": true,
		"node_id": boss_id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"resolution": String(RESOLUTION_PLACEHOLDER),
		"outcome": String(BOSS_OUTCOME),
		"cleared_node_count": cleared_count
	})


# The run_completed event's sequence id (the second of the two BOSS events). Distinct from node_
# placeholder_resolved's id so the two events have unique sequence ids. Centralized so the offset is
# defined in one place (mirroring NodeExitCommand._route_sealed_sequence_id).
func _run_completed_sequence_id() -> int:
	return sequence_id + 1


# A single stable top-level code (invalid_context) holds the not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring
# NodeEnterCommand / NodeExitCommand / RouteAdvanceCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
