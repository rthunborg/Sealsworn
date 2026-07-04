class_name CompleteRunCommand
extends "res://scripts/core/commands/game_command.gd"

# The run-END RESOLUTION command (Story 8.1) — the run-domain command that closes the RUN-END boundary: it makes a run
# the hero LOSES (death) resolve to PHASE_FAILED with an emitted run_failed event carrying a CAUSE (AC1), a run that
# COMPLETES/wins resolve to PHASE_COMPLETED with a broadened run_completed event (AC2), makes BOTH carry an explicit
# "next destination = outpost" flow signal (FR32), and makes a SECOND resolution on an already-terminal run idempotent
# / a stable error that does NOT double-grant (AC3). It is the FIRST command to DRIVE PHASE_FAILED (which was reachable
# in the RunState transition table but had no command — combat auto-resolves to success, so today a run can only reach
# COMPLETED via the boss).
#
# ⭐ IT EXTENDS the Epic-4 run machinery; it does NOT reinvent it. It DRIVES the already-existing PHASE_FAILED /
# PHASE_COMPLETED transition edges (RunState._legal_next_phases — NOT adding edges), BROADENS the existing 4.5
# run_completed event's outcome (NOT creating a parallel completed event), adds the NEW run_failed event (appended at
# the DomainEvent.Type enum end), and mirrors NodeResolvePlaceholderCommand._resolve_boss's mutate-then-event two-step
# transition pattern. It does NOT change the boss boundary (Epic 9 reuses NodeResolvePlaceholderCommand's boss
# run_completed unchanged); 8.1's completion path is a SEPARATE generic completion.
#
# ONE OUTCOME-PARAMETERIZED COMMAND ([Decision] A, the story RECOMMENDED): the caller supplies an explicit `outcome`
# string that is EITHER a death CAUSE (in DomainEvent.RUN_FAILED_CAUSES — e.g. hero_death / level_defeat / boss_defeat
# / abandoned) OR a completion MARKER (DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED). The command classifies it:
#   - a death cause  -> transition to PHASE_FAILED   + emit run_failed   (with the cause + the outpost destination).
#   - the completion marker -> transition to PHASE_COMPLETED + emit run_completed (with the broadened `completed`
#     outcome + the outpost destination). From ACTIVE_ROUTE this runs the boss's TWO-STEP (ACTIVE_ROUTE ->
#     NODE_RESOLUTION -> COMPLETED) so NO new transition edge is needed; from NODE_RESOLUTION it is a single step.
#   - anything else -> rejected fail-loud (unknown_run_end_outcome) BEFORE any mutation.
# Unifying both endings behind one validate-then-mutate seam mirrors NodeResolvePlaceholderCommand's boss path.
#
# THE 4.3 RUN-COMMAND IDIOM VERBATIM: validate(state)/execute(state) take the live RunState DIRECTLY (no
# RunActionContext wrapper); the CALLER supplies the run-level sequence_id (default 1) via the constructor; validate()
# rejects sequence_id <= 0 FIRST (invalid_event_sequence_id) so a success path can never emit an event its own
# validator would reject; validate-then-mutate with ZERO events + a byte-identical no-mutation RunState on ANY reject;
# the event is built ONLY AFTER the (legal) transition succeeds.
#
# IT DRAWS ZERO RNG: run-END resolution is a deterministic phase transition + event — NO randi/randf, NO
# RandomNumberGenerator, NO stream advance (the named-RNG rule). Same (run, outcome, sequence_id) -> identical result.
#
# AC3 IDEMPOTENCY / NO-DOUBLE-GRANT: re-resolving an ALREADY-terminal run is rejected with the stable
# run_already_terminal code (mirroring RunOrchestrator.resolve_current_node's guard) — ZERO second event + ZERO
# mutation, so nothing can be granted twice. v0 grants no reward/progression at run-END (awarding is Story 8.3), so
# "not granted twice" is satisfied structurally today; the guard is the SEAM 8.3's Oath-Shard awarding must run BEHIND
# (the award must never re-fire on a re-completion).
#
# WHAT THIS IS NOT (scope boundaries):
#   - It does NOT build the run SUMMARY (Story 8.2), the meta profile / Oath-Shard AWARDING (Story 8.3), the outpost
#     MENU scene (Story 8.6), or the first-death narrative line (Story 8.5). It emits the run-END EVENTS + terminal
#     phase + flow signal those stories CONSUME.
#   - It does NOT detect a live combat death (combat auto-resolves; the live death SOURCE is a deferred HUD/run-flow
#     story) — the failed path is CALLER-DRIVEN with an EXPLICIT cause the caller supplies.
#   - It is NOT auto-wired into RunOrchestrator.run_to_completion's auto-resolve loop (no live death source exists; an
#     OPTIONAL thin orchestrator dispatch hook exists for a caller, mirroring _resolve_boss).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The completion outcome marker this command emits for a generic completion (the broadened run_completed outcome — NOT the
# boss placeholder). Equal to DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED (the validator pins the allowlist) — referenced
# from the event const so the command + validator stay in lockstep on the marker vocabulary.
const COMPLETION_OUTCOME := DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED

# Story 9.4 (AC1): the run-VICTORY completion marker for the REAL Larval-Avatar boss victory. `victory` is a SECOND
# COMPLETION marker (a completion, NOT a death cause — see _is_completion_outcome): it drives the SAME completion path as
# `completed` (both run _resolve_completed -> PHASE_COMPLETED + run_completed) with the `victory` outcome. This UNBLOCKS the
# 8.1-reserved `victory` outcome so the boss defeat resolves the run the SAME way a generic completion does, WITHOUT
# touching the boss_placeholder / completed values. The command emits the ACTUAL requested outcome (victory or completed),
# NOT a hardcoded marker.
const VICTORY_OUTCOME := DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY

# The completion markers this command accepts (both drive the completion path). `completed` (8.1 generic completion) +
# `victory` (9.4 real boss victory). The boss_placeholder outcome is NOT here — that is the 4.5 NodeResolvePlaceholder
# Command's boss branch, unchanged by 9.4.
const COMPLETION_OUTCOMES: Array[StringName] = [
	DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED,
	DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY
]

# The stable "next app flow destination" marker carried on the result metadata + both emitted event payloads (FR32 —
# death/completion returns to the last outpost). Equal to DomainEvent.RUN_END_DESTINATION_OUTPOST.
const NEXT_DESTINATION_OUTPOST := DomainEvent.RUN_END_DESTINATION_OUTPOST

# The requested run-END outcome: EITHER a death cause (in DomainEvent.RUN_FAILED_CAUSES) OR the completion marker
# (COMPLETION_OUTCOME). Supplied by the caller.
var outcome: StringName = &""
var sequence_id: int = 1

func _init(new_outcome: StringName = &"", new_sequence_id: int = 1) -> void:
	command_id = &"complete_run"
	outcome = new_outcome
	sequence_id = new_sequence_id


# Pure read: validate the event sequence id, context, the idempotency (not-already-terminal) guard, the requested
# outcome classification, and that the requested END transition is reachable from the current phase. No mutation, no
# event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the 4.3 idiom): execute() builds run_failed / run_completed (sequence_id), and
	# DomainEvent.try_from_dictionary requires sequence_id > 0. Gate it BEFORE any state is read or mutated so a
	# success path can never emit a non-round-trippable event.
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
	# The run/route must be structurally sound before we reason about resolution.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# AC3 idempotency / no-double-grant: an ALREADY-terminal run cannot be re-resolved (the run already ended). Reject
	# with the stable run_already_terminal code (mirroring RunOrchestrator.resolve_current_node) — the no-second-event
	# + no-mutation guard so nothing can be granted twice (Story 8.3's awarding sits BEHIND this seam). Checked BEFORE
	# the outcome classification so a re-completion is rejected for being terminal, not for the outcome.
	if run.is_terminal():
		return ActionResult.error(&"run_already_terminal", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# Classify the requested outcome: a death cause (-> FAILED) or the completion marker (-> COMPLETED). Anything else
	# is rejected fail-loud BEFORE any mutation (the offending value rides metadata, never the lower_snake code).
	if _is_death_cause(outcome):
		# Death path: PHASE_FAILED must be a legal edge from the current phase (ACTIVE_ROUTE / NODE_RESOLUTION). From
		# NEW_RUN it is not reachable — reject with the stable wrong_run_phase code + the actual phase in metadata.
		if not run.can_transition_to(RunState.PHASE_FAILED):
			return ActionResult.error(&"wrong_run_phase", {
				"command": String(command_id),
				"phase": String(run.phase),
				"requested_phase": String(RunState.PHASE_FAILED)
			})
		return ActionResult.ok()
	if _is_completion_outcome(outcome):
		# Completion path (`completed` or the 9.4 `victory`): PHASE_COMPLETED is legal only from NODE_RESOLUTION; from
		# ACTIVE_ROUTE the command runs the boss's TWO-STEP (ACTIVE_ROUTE -> NODE_RESOLUTION -> COMPLETED), so a completion
		# is reachable from BOTH ACTIVE_ROUTE and NODE_RESOLUTION (no new transition edge). From NEW_RUN neither is
		# reachable — reject.
		if run.phase != RunState.PHASE_ACTIVE_ROUTE and run.phase != RunState.PHASE_NODE_RESOLUTION:
			return ActionResult.error(&"wrong_run_phase", {
				"command": String(command_id),
				"phase": String(run.phase),
				"requested_phase": String(RunState.PHASE_COMPLETED)
			})
		return ActionResult.ok()
	# Neither a known death cause nor a completion marker.
	return ActionResult.error(&"unknown_run_end_outcome", {
		"command": String(command_id),
		"outcome": String(outcome)
	})


# Validate-then-mutate. Dispatches by the requested outcome: a death cause runs the FAILED resolution (transition +
# run_failed); the completion marker runs the COMPLETED resolution (transition(s) + run_completed). Draws ZERO RNG;
# builds the event ONLY after the (legal) transition succeeds.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	if _is_death_cause(outcome):
		return _resolve_failed(run)
	return _resolve_completed(run)


# DEATH resolution (AC1): transition ACTIVE_ROUTE/NODE_RESOLUTION -> PHASE_FAILED, then emit run_failed carrying the
# CAUSE + the cleared-node count + the outpost destination. validate() already pinned the legal edge, so transition_to
# cannot fail here — but check defensively and surface a structured error WITHOUT having emitted any event if it ever
# did (never emit run_failed and THEN fail to transition). Draws ZERO RNG.
func _resolve_failed(run: RunState) -> ActionResult:
	var transition: ActionResult = run.transition_to(RunState.PHASE_FAILED)
	if transition.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"requested_phase": String(RunState.PHASE_FAILED),
			"inner_error_code": String(transition.error_code)
		})

	var cleared_count: int = run.route.cleared_node_ids.size()
	# The run died at the CURRENTLY-parked node (if any). A run abandoned at a route CHOICE has no current node — the
	# node_id is then empty (the run_failed validator tolerates an empty node_id). NOT cleared here — death is a
	# terminal resolution, not a node clear (the cleared set is the nodes cleared BEFORE the death).
	var node_id: String = String(run.route.current_node_id)

	var event: DomainEvent = DomainEvent.run_failed(sequence_id, {
		"cause": String(outcome),
		"node_id": node_id,
		"cleared_node_count": cleared_count,
		"next_destination": String(NEXT_DESTINATION_OUTPOST)
	})

	return ActionResult.ok([event], {
		"run_failed": true,
		"cause": String(outcome),
		"node_id": node_id,
		"cleared_node_count": cleared_count,
		"next_destination": String(NEXT_DESTINATION_OUTPOST)
	})


# COMPLETION resolution (AC2 / Story 9.4 AC1): transition to PHASE_COMPLETED (from NODE_RESOLUTION directly, or from
# ACTIVE_ROUTE via the boss's TWO-STEP ACTIVE_ROUTE -> NODE_RESOLUTION -> COMPLETED so NO new edge is needed), then emit
# run_completed with the ACTUAL requested completion outcome (`completed` OR the 9.4 `victory`) + the cleared-node count +
# the outpost destination. validate() already pinned the phase, so the transitions cannot fail here — but check each
# defensively and surface a structured error WITHOUT having emitted any event if either ever did (build the event ONLY after
# the run is actually in COMPLETED). Draws ZERO RNG.
#
# TWO-STEP ATOMICITY (Story 9.4 Task 8 — the 8.1 review Round-1 Low #1, RE-CARRIED to 9.4, now FIXED): the ACTIVE_ROUTE ->
# NODE_RESOLUTION -> COMPLETED two-step could leave the run MUTATED in NODE_RESOLUTION (non-terminal) if step 1 succeeded
# but step 2 then failed — violating the command's "byte-identical no-mutation RunState on ANY reject" promise. It is
# currently UNREACHABLE (given RunState._legal_next_phases both edges are always legal from the checked phases), so this is
# a DEFENSIVE-CORRECTNESS fix, not a live bug. FIX: capture the phase BEFORE step 1 and RESTORE it (run.phase = phase_before
# — the command already reads run.phase directly; no new RunState surface) on a step-2 failure, so a step-2 failure leaves
# the run byte-identical (as if the two-step never ran) rather than parked in NODE_RESOLUTION. 9.4 drives this exact path for
# the boss VICTORY (from ACTIVE_ROUTE, the two-step runs), so the owning story hardens it.
func _resolve_completed(run: RunState) -> ActionResult:
	# Capture the phase BEFORE any transition so a step-2 failure can restore the run to byte-identical (the atomicity fix).
	var phase_before: StringName = run.phase

	# Step 1 (only from ACTIVE_ROUTE): ACTIVE_ROUTE -> NODE_RESOLUTION (the boss two-step's first hop). From
	# NODE_RESOLUTION this is skipped (already there).
	if run.phase == RunState.PHASE_ACTIVE_ROUTE:
		var to_resolution: ActionResult = run.transition_to(RunState.PHASE_NODE_RESOLUTION)
		if to_resolution.is_error():
			# Step 1 failed BEFORE any mutation (transition_to rejects without mutating) — the run is still at phase_before.
			return ActionResult.error(&"wrong_run_phase", {
				"command": String(command_id),
				"phase": String(run.phase),
				"requested_phase": String(RunState.PHASE_NODE_RESOLUTION),
				"inner_error_code": String(to_resolution.error_code)
			})

	# Step 2: NODE_RESOLUTION -> COMPLETED (the terminal completion edge).
	var to_completed: ActionResult = run.transition_to(RunState.PHASE_COMPLETED)
	if to_completed.is_error():
		# ATOMICITY (the 8.1 Low #1 fix): step 1 may have advanced the run to NODE_RESOLUTION; RESTORE the pre-step-1 phase
		# so a step-2 failure leaves the run BYTE-IDENTICAL (no mutation on ANY reject). Unreachable today (both edges are
		# always legal), so this restore is defensive; it never fires in the live flow.
		run.phase = phase_before
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"requested_phase": String(RunState.PHASE_COMPLETED),
			"inner_error_code": String(to_completed.error_code)
		})

	var cleared_count: int = run.route.cleared_node_ids.size()
	# A non-boss generic completion AND the 9.4 victory have NO boss node — boss_node_id is omitted (the broadened
	# run_completed validator tolerates its absence for the `completed`/`victory` outcomes; it is required only for the
	# boss_placeholder outcome). Emit the ACTUAL requested outcome (victory or completed), NOT a hardcoded marker.
	var event: DomainEvent = DomainEvent.run_completed(sequence_id, {
		"outcome": String(outcome),
		"cleared_node_count": cleared_count,
		"next_destination": String(NEXT_DESTINATION_OUTPOST)
	})

	return ActionResult.ok([event], {
		"run_completed": true,
		"outcome": String(outcome),
		"cleared_node_count": cleared_count,
		"next_destination": String(NEXT_DESTINATION_OUTPOST)
	})


# Whether the requested outcome is a death CAUSE (in the run_failed cause allowlist) -> the FAILED resolution path.
func _is_death_cause(value: StringName) -> bool:
	return DomainEvent.RUN_FAILED_CAUSES.has(value)


# Whether the requested outcome is a COMPLETION marker (`completed` or the 9.4 `victory`) -> the COMPLETED resolution path.
# Story 9.4 extends the classifier to accept `victory` alongside `completed` (both run _resolve_completed).
func _is_completion_outcome(value: StringName) -> bool:
	return COMPLETION_OUTCOMES.has(value)


# A single stable top-level code (invalid_context) holds the not-a-RunState / null-route / structurally-invalid-run
# cases, surfacing the inner validate() error for diagnosis (mirroring NodeResolvePlaceholderCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
