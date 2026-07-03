class_name BossNodeEnterCommand
extends "res://scripts/core/commands/game_command.gd"

# The boss-ENTRY / finale-SETUP command (Story 9.1) — the run-domain command that replaces the boss node's
# PRE-completion behavior at the SAME node boundary the run-progression model already owns. When the run is
# parked on the terminal TYPE_BOSS node in PHASE_ACTIVE_ROUTE, entering it:
#   (1) builds + validates a deterministic BossEncounterRequest from (run root_seed, the boss node), and
#   (2) builds + validates the deterministic boss ARENA level snapshot (BossArenaBuilder), and
#   (3) transitions ACTIVE_ROUTE -> NODE_RESOLUTION, and
#   (4) emits ONE boss_encounter_started DomainEvent,
# returning the live request + the arena payload in the result metadata so the CALLER (the orchestrator /
# the later live boss loop 9.3/9.4) runs the real fight. It is the boss sibling of NodeEnterCommand (the
# combat-node level entry) — the same build-validate-transition-emit-return shape.
#
# WHAT THIS IS NOT (scope boundaries — the biggest risk for this story):
#   - It does NOT COMPLETE the run. The boss no longer auto-completes on arrival: the run stays in
#     NODE_RESOLUTION awaiting the real boss fight + victory (Story 9.4, which reuses the run_completed
#     boundary UNCHANGED). This command is the SETUP half only.
#   - It does NOT author the Larval Avatar's stats/phases/actions (Story 9.2/9.3). It reserves the boss-entity
#     SLOT / id in the arena (BossEncounterRequest.BOSS_ENTITY_ID); 9.2 attaches the real definition there.
#   - It does NOT clear the boss node (that is 9.4's victory) and does NOT run any live turn loop.
#   - It draws ZERO RNG (building the request + the fixed deterministic arena is pure — the NodeEnterCommand
#     posture).
#
# ATOMICITY (AC3 — the 8.1 two-step-transition-atomicity defer applied here): the WHOLE setup (build +
# validate the request + build + strict-validate the arena snapshot + assemble the payload) runs and is fully
# validated BEFORE the ACTIVE_ROUTE -> NODE_RESOLUTION transition, so the transition is the LAST, infallible
# step. On ANY setup failure the command returns a structured ActionResult.error (carrying the inner
# GenerationResult seed/phase/reason/diagnostics) with ZERO events and a byte-identical no-mutation RunState —
# never a half-transition, never a partial encounter. No snapshot/restore is needed because nothing is mutated
# until the setup fully validates.
#
# DESIGN DECISIONS (per the story AC-interpretation notes):
#   - CONTEXT SHAPE: validate(state)/execute(state) accept the RunState DIRECTLY (the 4.3 idiom; a
#     RunActionContext wrapper would add no value for one field).
#   - SEQUENCE ID: the run domain has no event sequencer; the caller supplies the run-level sequence id via the
#     constructor (default 1, gated > 0 so the emitted event is always round-trippable).
#   - HYPHEN TRAP: the route boss id is hyphenated (node-7-0) but BossEncounterRequest.node_id is validated
#     lower_snake. The request node id is DERIVED by replacing hyphens with underscores (node-7-0 -> node_7_0);
#     the ORIGINAL hyphenated id is carried separately in the event payload + result metadata (never in a code).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const BossArenaBuilder = preload("res://scripts/generation/boss/boss_arena_builder.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var sequence_id: int = 1

func _init(new_sequence_id: int = 1) -> void:
	command_id = &"boss_node_enter"
	sequence_id = new_sequence_id


# Pure read: validate the sequence id, context, phase, parked-on-a-node, and boss-node-type. No mutation, no
# event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (mirror NodeEnterCommand): execute() builds a boss_encounter_started event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — reject a non-positive id BEFORE
	# any state is read or mutated so a success path can never emit an event its own validator rejects.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	if run.route == null:
		return _invalid_context()
	# The run/route must be structurally sound before we reason about the boss encounter.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# Boss entry happens IN PHASE_ACTIVE_ROUTE (it transitions ACTIVE_ROUTE -> NODE_RESOLUTION). Reject any other
	# phase with the stable wrong_run_phase code + the actual/expected phase in metadata.
	if run.phase != RunState.PHASE_ACTIVE_ROUTE:
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_ACTIVE_ROUTE)
		})

	var route: RouteState = run.route
	# The run must be parked on a node to enter one.
	if route.current_node_id.is_empty():
		return ActionResult.error(&"no_current_node", {
			"command": String(command_id)
		})

	# The current node must be the TYPE_BOSS node for this command — it is the boss finale SETUP. A non-boss node
	# is a caller dispatch error (combat -> NodeEnterCommand; the five non-combat placeholders + a non-boss node ->
	# NodeResolvePlaceholderCommand). Reject with a stable code carrying the offending type in metadata (hyphenated
	# node ids / types go in metadata, never in the code).
	var current: RouteNode = route.node_by_id(route.current_node_id)
	if current.type != RouteNode.TYPE_BOSS:
		return ActionResult.error(&"node_not_boss", {
			"command": String(command_id),
			"node_id": current.id,
			"node_type": String(current.type)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: build + validate the boss encounter request AND the arena snapshot FIRST
# (atomicity), THEN transition the phase (the last infallible step), emit ONE boss_encounter_started event, and
# return the live request + arena payload in metadata. Draws ZERO RNG; runs no live turn loop; does NOT
# complete the run.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var route: RouteState = run.route
	var node: RouteNode = route.node_by_id(route.current_node_id)

	# Derive the lower_snake request node id from the hyphenated route boss id (node-7-0 -> node_7_0). The ORIGINAL
	# hyphenated id is carried separately (event payload + result metadata).
	var request_node_id: String = _to_lower_snake_node_id(node.id)

	# Build the boss encounter request. root_seed is the run root_seed (full int64, never mangled).
	var request: BossEncounterRequest = BossEncounterRequest.new(
		run.root_seed,
		StringName(request_node_id),
		node.type,
		BossEncounterRequest.BOSS_ENTITY_ID
	)
	# VALIDATE the built request BEFORE any mutation: a request that fails to validate is a structured setup
	# error (invalid_boss_encounter_request) with the offending field, ZERO events, and NO mutation.
	var request_validation: ActionResult = request.validate()
	if request_validation.is_error():
		return ActionResult.error(&"invalid_boss_encounter_request", {
			"command": String(command_id),
			"node_id": node.id,
			"boss_request_node_id": request_node_id,
			"inner_error_code": String(request_validation.error_code),
			"inner_metadata": request_validation.metadata.duplicate(true)
		})

	# Build + STRICT-validate the deterministic boss ARENA snapshot BEFORE the transition (atomicity — AC3). A
	# failed arena setup returns a structured error carrying the GenerationResult seed + phase + reason + compact
	# diagnostics (NEVER a grid dump) with ZERO events and NO mutation (the run stays byte-identical in
	# ACTIVE_ROUTE — no broken boss state).
	var arena_result: GenerationResult = BossArenaBuilder.new().build(request)
	if arena_result.is_error():
		return ActionResult.error(&"boss_arena_setup_failed", {
			"command": String(command_id),
			"node_id": node.id,
			"inner_failed_phase": String(arena_result.failed_phase),
			"inner_error_code": String(arena_result.error_code),
			"inner_reason": String(arena_result.reason),
			"seed": arena_result.seed,
			"inner_diagnostics": arena_result.diagnostics.duplicate(true)
		})
	var arena_payload: Dictionary = arena_result.payload.duplicate(true)

	# Transition ACTIVE_ROUTE -> NODE_RESOLUTION (a legal edge; transition_to validates it) — the LAST, infallible
	# step (the setup above is fully validated). The phase guard in validate() already ensured ACTIVE_ROUTE, so
	# this cannot fail — but check defensively and surface a structured error WITHOUT having emitted any event or
	# mutated the arena into a partial encounter if it ever did.
	var transition: ActionResult = run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	if transition.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_ACTIVE_ROUTE),
			"inner_error_code": String(transition.error_code)
		})

	# Build the single boss_encounter_started system event (AFTER the transition succeeded). It records the boss
	# node id (hyphenated), the reserved boss-entity slot id, and the arena bounds.
	var boss_slot: Dictionary = arena_payload.get("boss_slot", {})
	var board_snapshot: Dictionary = arena_payload.get("board_snapshot", {})
	var event: DomainEvent = DomainEvent.boss_encounter_started(sequence_id, {
		"boss_node_id": node.id,
		"boss_entity_id": String(boss_slot.get("entity_id", String(request.boss_entity_id))),
		"arena_width": int(board_snapshot.get("width", 0)),
		"arena_height": int(board_snapshot.get("height", 0))
	})

	# Return ok with the event + the live BossEncounterRequest + the arena payload (the caller runs the real boss
	# fight) and diagnostics metadata. The original hyphenated node id is preserved separately.
	return ActionResult.ok([event], {
		"boss_encounter_started": true,
		"node_id": node.id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"boss_encounter_request": request,
		"boss_request_node_id": request_node_id,
		"boss_entity_id": String(boss_slot.get("entity_id", String(request.boss_entity_id))),
		"arena_payload": arena_payload
	})


# A single stable top-level code (invalid_context) holds the not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring NodeEnterCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)


# Derive a lower_snake BossEncounterRequest node id from a hyphenated route node id (node-7-0 -> node_7_0).
# Route ids are non-empty, whitespace-free, lower-case with hyphens/digits (RouteGenerator mints them);
# replacing hyphens with underscores yields a valid lower_snake id for BossEncounterRequest.node_id.
static func _to_lower_snake_node_id(route_node_id: String) -> String:
	return route_node_id.replace("-", "_")
