class_name RunEndOutcome
extends RefCounted

# Story 8.1 (AC1/AC2) — the scene-free RUN-END read surface / flow signal. It is the small, pure-read DOMAIN DTO
# that surfaces "the run ended; here is how, and where the app should go next" as serializable DATA a later
# boot/app-flow + outpost-scene layer (Story 8.6) reads to perform the actual navigation. It is the DOMAIN counterpart
# of the run_failed / run_completed event payloads: where the events RECORD the run-end on the event log, this read DTO
# PROJECTS the same run-end fact off a terminal RunState (phase + outcome/cause + the outpost destination + the
# meta-progression eligibility) for a consumer that holds the live run rather than the event stream.
#
# WHAT IT IS:
#   - RunEndOutcome.for_failed(run, cause) / RunEndOutcome.for_completed(run, outcome): build a run-end fact from a
#     TERMINAL run + the resolved cause/outcome (the CompleteRunCommand result). to_dictionary() projects the EXACT
#     pinned DICTIONARY_KEYS set: phase, outcome_or_cause, next_destination (= outpost), meta_progression_eligible.
#   - It READS run.meta_progression_eligible (already lockstep with is_manual_seed) for the eligibility field — it does
#     NOT compute, grant, or deny an Oath-Shard award (FR28 enforcement + the awarding are Story 8.3). A manual-seed
#     run's outcome reports meta_progression_eligible == false but 8.1 takes NO award action.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws NO RNG, and mutates nothing — it is a PURE read of a terminal
#     run (repeated reads are identical; the AffinityViewModel / HeroSelectViewModel exact-key, no-live-handle, fail-
#     closed discipline). It is NOT a scene transition, NOT a SceneManager call, NOT an outpost .tscn (8.6 / UI-scene-
#     last). The destination is a DATA fact; presentation consumes it later.
#   - It does NOT build the run SUMMARY (cause/nodes-cleared/loot/Oath-Shards/Echoes/unlock progress — Story 8.2). It
#     surfaces only the run-end boundary fact (phase + outcome/cause + destination + eligibility). The run_failed.cause
#     / run_completed.outcome are the INPUTS the 8.2 summary reads.
#
# next_destination is ALWAYS the outpost marker (FR32 — death/completion returns to the last outpost). A non-terminal
# run projects a fail-closed empty fact (has_ended == false, empty outcome/cause, empty destination) so a consumer can
# branch on has_ended without inspecting the empty fields — NEVER a crash, NEVER a half-fact.

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The EXACT top-level key set of every projection (the AffinityViewModel.MODAL_KEYS exact-key discipline — a key never
# silently appears/vanishes; the set is pinned by test_run_end_outcome.gd). has_ended gates whether the other fields are
# meaningful. outcome_or_cause unifies the two endings: a completed run carries its run_completed outcome (e.g.
# `completed` / `boss_placeholder`), a failed run carries its run_failed cause (e.g. `hero_death`).
const DICTIONARY_KEYS: Array[String] = [
	"has_ended",
	"phase",
	"outcome_or_cause",
	"next_destination",
	"meta_progression_eligible"
]

# Whether the run actually ended (a terminal phase). A non-terminal source run projects has_ended == false + empty
# fields (fail-closed).
var has_ended: bool = false
# The run's terminal phase (RunState.PHASE_COMPLETED / PHASE_FAILED), or "" for a non-terminal source run.
var phase: StringName = &""
# The unified run-end marker: the run_completed outcome (a completion) OR the run_failed cause (a death). "" for a
# non-terminal source run.
var outcome_or_cause: StringName = &""
# The next app-flow destination (ALWAYS the outpost marker for a terminal run; "" for a non-terminal source run).
var next_destination: StringName = &""
# The run's Oath-Shard / meta-progression eligibility (READ from run.meta_progression_eligible — lockstep with
# is_manual_seed). REPORTED only; 8.1 grants/denies NOTHING (Story 8.3 owns the awarding behind the AC3 guard).
var meta_progression_eligible: bool = false

func _init(
	new_has_ended: bool = false,
	new_phase: StringName = &"",
	new_outcome_or_cause: StringName = &"",
	new_next_destination: StringName = &"",
	new_meta_progression_eligible: bool = false
) -> void:
	has_ended = new_has_ended
	phase = new_phase
	outcome_or_cause = new_outcome_or_cause
	next_destination = new_next_destination
	meta_progression_eligible = new_meta_progression_eligible


# Build the run-end fact for a FAILED run (AC1): the run is in PHASE_FAILED, carries its death `cause`, routes to the
# outpost, and reports its meta eligibility. A null / non-terminal / non-FAILED run projects the fail-closed empty fact
# (has_ended == false) so a consumer never mistakes a still-active run for an ended one.
static func for_failed(run: RunState, cause: StringName) -> RunEndOutcome:
	if run == null or run.phase != RunState.PHASE_FAILED:
		return _empty()
	return load("res://scripts/run/run_end_outcome.gd").new(
		true,
		RunState.PHASE_FAILED,
		cause,
		DomainEvent.RUN_END_DESTINATION_OUTPOST,
		run.meta_progression_eligible
	)


# Build the run-end fact for a COMPLETED run (AC2): the run is in PHASE_COMPLETED, carries its completion `outcome`,
# routes to the outpost, and reports its meta eligibility. A null / non-terminal / non-COMPLETED run projects the fail-
# closed empty fact (has_ended == false).
static func for_completed(run: RunState, outcome: StringName) -> RunEndOutcome:
	if run == null or run.phase != RunState.PHASE_COMPLETED:
		return _empty()
	return load("res://scripts/run/run_end_outcome.gd").new(
		true,
		RunState.PHASE_COMPLETED,
		outcome,
		DomainEvent.RUN_END_DESTINATION_OUTPOST,
		run.meta_progression_eligible
	)


# Exact-key projection (the AffinityViewModel exact-key discipline): plain String/bool data only (no live RunState
# handle leaks out). A FRESH dictionary each call so a mutation of the returned dict never perturbs this DTO. PURE read.
func to_dictionary() -> Dictionary:
	return {
		"has_ended": has_ended,
		"phase": String(phase),
		"outcome_or_cause": String(outcome_or_cause),
		"next_destination": String(next_destination),
		"meta_progression_eligible": meta_progression_eligible
	}


# The fail-closed empty fact (a null / non-terminal / wrong-phase source run): has_ended == false + empty fields, so a
# consumer branches on has_ended without inspecting the empty fields (the AffinityViewModel._identity_absent_modal
# discipline). meta_progression_eligible defaults false (no eligibility claim for a non-ended run).
static func _empty() -> RunEndOutcome:
	return load("res://scripts/run/run_end_outcome.gd").new(false, &"", &"", &"", false)
