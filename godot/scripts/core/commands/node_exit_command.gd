class_name NodeExitCommand
extends "res://scripts/core/commands/game_command.gd"

# The node EXIT command (Story 4.4) — the run-domain command that returns LEVEL flow to ROUTE flow.
# When the run is in PHASE_NODE_RESOLUTION parked on the resolved node, exiting it:
#   (1) marks the CURRENT node cleared (reveal_state -> REVEAL_CLEARED, id appended to cleared_node_ids
#       idempotently), and
#   (2) transitions NODE_RESOLUTION -> ACTIVE_ROUTE (route choice becomes active again), and
#   (3) emits TWO system events: node_exited + route_sealed (the deterministic door-sealed containment
#       cue carrying the stable cue id door_sealed_placeholder),
# returning autosave_requested: true + the route-side RunState.to_run_snapshot_fields() payload in the
# result metadata so the CALLER can compose + write a between-level autosave when it has the tactical
# board (Story 4.6 / the playable shell). On any rejection it returns a structured ActionResult.error
# with ZERO events and mutates NOTHING. It draws ZERO RNG and writes NO save.
#
# WHAT THIS IS NOT (scope boundaries):
#   - It does NOT write a save. RunSnapshot.from_between_level REQUIRES a live BoardState + RngStreamSet
#     and embeds a strict TacticalSnapshot — this story has NO board (it does not run the level). So exit
#     only ADVERTISES the autosave seam (autosave_requested + the route-side snapshot fields); the actual
#     board-bearing file write through SaveRepository is the caller's / Story 4.6's job.
#   - It does NOT advance the route pointer (RouteAdvanceCommand, Story 4.3, moves OFF the cleared node on
#     the NEXT advance). The pointer STAYS on the just-cleared node after exit.
#   - It does NOT build a reward system. "rewards placeholder" is a metadata flag on the exit boundary
#     (true for combat/elite nodes) so a later reward story can hook here; concrete loot is Epic 6.
#
# DESIGN DECISIONS (per the story AC-interpretation notes):
#   - CONTEXT SHAPE: validate(state)/execute(state) accept the RunState DIRECTLY (mirroring 4.3).
#   - SEQUENCE IDS: exit emits TWO events. node_exited uses the caller-supplied sequence_id; route_sealed
#     uses sequence_id + 1 (distinct, deterministic). validate() gates BOTH > 0 before reading/mutating
#     state, so the success path can never emit an event its own validator would reject.
#   - DOOR CUE: the stable cue id is the named constant DOOR_SEALED_CUE = "door_sealed_placeholder".
#   - CLEARED-SET IDEMPOTENCY: the append to cleared_node_ids is guarded (skip if already present) so the
#     exit is defensive against a node already cleared. Paired with the Story 4.3 idempotency guard, the
#     advance -> enter -> exit -> advance sequence keeps cleared_node_ids duplicate-free (RouteState
#     .validate() rejects duplicate_cleared_node).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The stable door-sealed presentation cue id (GDD line 210 containment-law feedback). Lower_snake; the
# route_sealed payload carries it in cue_id and tests assert the exact value.
const DOOR_SEALED_CUE := &"door_sealed_placeholder"

# Node types whose exit records a rewards placeholder (combat/elite earn a reward at the boundary). v0
# scopes node ENTRY to these two types, so an exit reached via NodeEnterCommand is always one of them;
# the flag is computed defensively from the node type so a future per-type exit can extend it.
const REWARDS_PLACEHOLDER_TYPES := {
	RouteNode.TYPE_COMBAT: true,
	RouteNode.TYPE_ELITE_COMBAT: true
}

var sequence_id: int = 1

func _init(new_sequence_id: int = 1) -> void:
	command_id = &"node_exit"
	sequence_id = new_sequence_id


# Pure read: validate BOTH event sequence ids, context, phase, and parked-on-a-node. No mutation, no
# event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (mirror RouteAdvanceCommand): execute() builds node_exited (sequence_id) AND
	# route_sealed (sequence_id + 1); DomainEvent.try_from_dictionary requires sequence_id > 0. Gate BOTH
	# ids BEFORE any state is read or mutated so the success path can never emit a non-round-trippable
	# event. (sequence_id + 1 is non-positive only if sequence_id <= -1, already caught by the first
	# check — but assert the second-event id explicitly for clarity / future offset changes.)
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if _route_sealed_sequence_id() <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": _route_sealed_sequence_id()
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	if run.route == null:
		return _invalid_context()
	# The run/route must be structurally sound before we reason about exit.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# Node exit happens IN PHASE_NODE_RESOLUTION (it transitions NODE_RESOLUTION -> ACTIVE_ROUTE). Reject
	# any other phase (AC4) with the stable wrong_run_phase code + actual/expected phase in metadata.
	if run.phase != RunState.PHASE_NODE_RESOLUTION:
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_NODE_RESOLUTION)
		})

	var route: RouteState = run.route
	# The run must be parked on a node to exit one.
	if route.current_node_id.is_empty():
		return ActionResult.error(&"no_current_node", {
			"command": String(command_id)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: mark the current node cleared (idempotent), transition the phase,
# emit node_exited + route_sealed, and surface the autosave seam. Draws ZERO RNG; writes NO save.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var route: RouteState = run.route
	var node: RouteNode = route.node_by_id(route.current_node_id)
	var node_id: String = node.id
	var rewards_placeholder: bool = REWARDS_PLACEHOLDER_TYPES.has(node.type)

	# (1) Seal the path behind the hero: mark the resolved node REVEAL_CLEARED and add it to
	# cleared_node_ids. The append is IDEMPOTENT (skip if already present) so re-exiting an already-
	# cleared node cannot create a duplicate (RouteState.validate() rejects duplicate_cleared_node).
	node.reveal_state = RouteNode.REVEAL_CLEARED
	if not route.cleared_node_ids.has(node_id):
		var cleared: Array[String] = route.cleared_node_ids.duplicate()
		cleared.append(node_id)
		route.cleared_node_ids = cleared

	# (2) Transition NODE_RESOLUTION -> ACTIVE_ROUTE (a legal edge; transition_to validates it). The
	# phase guard in validate() already ensured NODE_RESOLUTION, so this cannot fail — but check
	# defensively and surface a structured error if it ever did. (No event has been emitted yet.)
	var transition: ActionResult = run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	if transition.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_NODE_RESOLUTION),
			"inner_error_code": String(transition.error_code)
		})

	# (3) Build the two system events: node_exited, then route_sealed (the door-sealed containment cue).
	var exited_event: DomainEvent = DomainEvent.node_exited(sequence_id, {
		"node_id": node_id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"rewards_placeholder": rewards_placeholder
	})
	var sealed_event: DomainEvent = DomainEvent.route_sealed(_route_sealed_sequence_id(), {
		"node_id": node_id,
		"cue_id": String(DOOR_SEALED_CUE)
	})

	# (4) Surface the between-level autosave seam: advertise autosave_requested + the route-side snapshot
	# fields (the existing 4.1 bridge) so the caller can compose + write the autosave WHEN it has the
	# board. This command writes NO save and fabricates NO board.
	var metadata: Dictionary = {
		"exits_node": true,
		"node_id": node_id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"rewards_placeholder": rewards_placeholder,
		"autosave_requested": true,
		"run_snapshot_fields": run.to_run_snapshot_fields()
	}
	return ActionResult.ok([exited_event, sealed_event], metadata)


# The route_sealed event's sequence id (the second of the two exit events). Distinct from node_exited's
# id so the two events have unique sequence ids. Centralized so the offset is defined in one place.
func _route_sealed_sequence_id() -> int:
	return sequence_id + 1


# A single stable top-level code (invalid_context) holds the not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring
# RouteAdvanceCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
