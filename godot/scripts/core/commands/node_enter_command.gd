class_name NodeEnterCommand
extends "res://scripts/core/commands/game_command.gd"

# The node ENTRY command (Story 4.4) — the run-domain command that bridges ROUTE flow into LEVEL flow.
# When the run is parked on a chosen COMBAT/ELITE_COMBAT node in PHASE_ACTIVE_ROUTE, entering it:
#   (1) builds + validates a deterministic level GenerationRequest from (run root_seed, the node), and
#   (2) transitions ACTIVE_ROUTE -> NODE_RESOLUTION, and
#   (3) emits ONE node_entered DomainEvent,
# returning the live GenerationRequest in the result metadata (level_request) so the CALLER runs
# LevelGenerator.generate(...) and plays the tactical level. On any rejection it returns a structured
# ActionResult.error with ZERO events and mutates NOTHING (the RunState/RouteState is byte-identical).
# It draws ZERO RNG (building a request is pure; the `level` stream is drawn by generation LATER).
#
# WHAT THIS IS NOT (scope boundaries):
#   - It does NOT run LevelGenerator.generate(...) and does NOT depend on the content repositories
#     (EnemyRepository / LevelRecipeRepository). It produces the REQUEST + the phase transition; running
#     generation (which draws the `level` stream) and playing the board belong to the caller / Story 4.6.
#   - It does NOT advance the route pointer or clear nodes (that is RouteAdvanceCommand, Story 4.3) and
#     does NOT mark anything cleared on enter (exit clears the resolved node, NodeExitCommand).
#   - It does NOT implement per-node-type RESOLUTION (Story 4.5) — it scopes ENTRY to combat/elite_combat
#     and rejects other node types with a stable unsupported_node_entry code.
#
# DESIGN DECISIONS (per the story AC-interpretation notes):
#   - CONTEXT SHAPE: validate(state)/execute(state) accept the RunState DIRECTLY (mirroring 4.3; a
#     RunActionContext wrapper would add no value for one field).
#   - SEQUENCE ID: the run domain has no event sequencer yet; the caller supplies the run-level sequence
#     id via the constructor (default 1, gated > 0 so the emitted event is always round-trippable).
#   - NODE-TYPE -> (recipe_id, size_class) MAP: combat -> small_combat_basic / SIZE_SMALL;
#     elite_combat -> medium_combat_basic / SIZE_MEDIUM (the two v0 level recipes). Documented in the
#     NODE_TYPE_RECIPE / NODE_TYPE_SIZE_CLASS tables below + the story Completion Notes.
#   - HYPHEN TRAP: route node ids are hyphenated (node-1-0) but GenerationRequest.node_id is validated
#     lower_snake. The request node id is DERIVED by replacing hyphens with underscores (node-1-0 ->
#     node_1_0); the ORIGINAL hyphenated id is carried separately in the event payload + result metadata.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Deterministic node-type -> level-recipe map (v0 scopes combat entry to the two v0 recipes).
const NODE_TYPE_RECIPE := {
	RouteNode.TYPE_COMBAT: &"small_combat_basic",
	RouteNode.TYPE_ELITE_COMBAT: &"medium_combat_basic"
}

# Deterministic node-type -> size-class map (mirrors the recipe size: small recipe = Small board, etc.).
const NODE_TYPE_SIZE_CLASS := {
	RouteNode.TYPE_COMBAT: GenerationRequest.SIZE_SMALL,
	RouteNode.TYPE_ELITE_COMBAT: GenerationRequest.SIZE_MEDIUM
}

var sequence_id: int = 1

func _init(new_sequence_id: int = 1) -> void:
	command_id = &"node_enter"
	sequence_id = new_sequence_id


# Pure read: validate the sequence id, context, phase, parked-on-a-node, and supported-node-type. No
# mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (mirror RouteAdvanceCommand): execute() builds a node_entered event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id
	# would make the success path emit a non-round-trippable event. Reject it BEFORE any state is read or
	# mutated so a command's success path can never emit an event its own validator rejects.
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
	# The run/route must be structurally sound before we reason about entry.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# Node entry happens IN PHASE_ACTIVE_ROUTE (it transitions ACTIVE_ROUTE -> NODE_RESOLUTION). Reject
	# any other phase (AC4) with the stable wrong_run_phase code + the actual/expected phase in metadata.
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

	# The current node must be a COMBAT/ELITE_COMBAT type for this story's scope. Non-combat-node entry
	# / resolution is Story 4.5 — reject it with a stable code carrying the offending type in metadata
	# (hyphenated node ids / types go in metadata, never in the code).
	var current: RouteNode = route.node_by_id(route.current_node_id)
	if not NODE_TYPE_RECIPE.has(current.type):
		return ActionResult.error(&"unsupported_node_entry", {
			"command": String(command_id),
			"node_id": current.id,
			"node_type": String(current.type)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: build + validate the level GenerationRequest, transition the phase,
# emit ONE node_entered event, and return the live request in metadata. Draws ZERO RNG; runs no
# sub-command; does NOT call LevelGenerator.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var route: RouteState = run.route
	var node: RouteNode = route.node_by_id(route.current_node_id)

	# Derive the lower_snake request node id from the hyphenated route id (node-1-0 -> node_1_0). The
	# ORIGINAL hyphenated id is carried separately (event payload + result metadata).
	var request_node_id: String = _to_lower_snake_node_id(node.id)
	var recipe_id: StringName = NODE_TYPE_RECIPE.get(node.type)
	var size_class: StringName = NODE_TYPE_SIZE_CLASS.get(node.type)

	# Build the level request. root_seed is the run root_seed (full int64, never mangled). node_type is
	# already lower_snake (RouteNode.TYPE_* values pass directly). difficulty_band / affinity default.
	var request: GenerationRequest = GenerationRequest.new(
		run.root_seed,
		StringName(request_node_id),
		node.type,
		recipe_id,
		size_class
	)
	# VALIDATE the built request BEFORE any mutation: a request that fails to validate is a structured
	# entry error (invalid_level_request) with the offending field, ZERO events, and NO mutation.
	var request_validation: ActionResult = request.validate()
	if request_validation.is_error():
		return ActionResult.error(&"invalid_level_request", {
			"command": String(command_id),
			"node_id": node.id,
			"level_request_node_id": request_node_id,
			"inner_error_code": String(request_validation.error_code),
			"inner_metadata": request_validation.metadata.duplicate(true)
		})

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

	# Build the single node_entered system event.
	var event: DomainEvent = DomainEvent.node_entered(sequence_id, {
		"node_id": node.id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"level_request_node_id": request_node_id,
		"recipe_id": String(recipe_id),
		"size_class": String(size_class)
	})

	# Return ok with the event + the live GenerationRequest (the caller runs LevelGenerator.generate)
	# and the diagnostics metadata. The original hyphenated node id is preserved separately.
	return ActionResult.ok([event], {
		"enters_node": true,
		"node_id": node.id,
		"node_type": String(node.type),
		"node_depth": node.depth,
		"level_request": request,
		"level_request_node_id": request_node_id,
		"recipe_id": String(recipe_id),
		"size_class": String(size_class)
	})


# A single stable top-level code (invalid_context) holds the not-a-RunState / null-route /
# structurally-invalid-run cases. When caused by a structurally-invalid run, surface the inner
# RouteState/RunState validate() error code + metadata for diagnosis (mirroring RouteAdvanceCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)


# Derive a lower_snake GenerationRequest node id from a hyphenated route node id (node-1-0 -> node_1_0).
# Route ids are non-empty, whitespace-free, lower-case with hyphens/digits (RouteGenerator mints them);
# replacing hyphens with underscores yields a valid lower_snake id for GenerationRequest.node_id.
static func _to_lower_snake_node_id(route_node_id: String) -> String:
	return route_node_id.replace("-", "_")
