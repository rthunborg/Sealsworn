class_name AwardMetaProgressCommand
extends "res://scripts/core/commands/game_command.gd"

# The META-AWARD APPLICATION command (Story 8.3, AC1/AC2/AC4) — the run-domain command that AWARDS the cross-run
# Oath-Shard currency to the profile when an ELIGIBLE run ENDS, behind TWO GATES so a re-completion never re-awards and
# a manual-seed run never awards. It is the "receive eligible progress" seam of Epic 8 + the FIRST command to MUTATE
# persistent cross-run state (the profile). It reads the TERMINAL RunState (the run that ended) + the run's RunSummary
# (Story 8.2 — the bounded award signal) + the current ProfileSnapshot, computes the capped/sparse award (MetaAwardRules,
# AC3), UPDATES the profile's cross-run oath_shards total, and RECORDS the change via the deterministic
# oath_shards_awarded event (AC2).
#
# ⭐ THE 4.3 RUN-COMMAND IDIOM VERBATIM (mirroring CompleteRunCommand): validate(state)/execute(state) take the live
# TERMINAL RunState DIRECTLY as `state` (no wrapper); the PROFILE + the SUMMARY + the run-level sequence_id are supplied
# via the constructor; validate() rejects sequence_id <= 0 FIRST (invalid_event_sequence_id) so a success path can never
# emit an event its own validator would reject; validate-then-mutate with ZERO events + a byte-identical no-mutation run
# AND profile on ANY reject; the event is built ONLY AFTER the award is applied. It draws ZERO RNG (the award is a
# deterministic calculation, not a roll).
#
# ⭐ GATE 1 — IDEMPOTENCY (the 8.1 seam; AC1 "not granted twice"): the award must run BEHIND the 8.1
# run_already_terminal guard so a re-completion (which CompleteRunCommand rejects) never re-awards. This command ADDS a
# SECOND idempotency layer for the case where the award is invoked INDEPENDENTLY of resolve_run_end ([Decision] — a
# marker on the profile, NOT relying solely on the caller): the profile records last_awarded_run_seed (the run identity;
# v0's RunState has no run_id, so the root_seed IS the deterministic run identity). validate() REJECTS a run whose
# root_seed already equals profile.last_awarded_run_seed with the stable run_already_awarded code (ZERO second event,
# ZERO double-mutation). So a re-invocation for the SAME already-awarded run is a stable no-op — no double-award,
# structurally guaranteed regardless of how many times the caller invokes.
#
# ⭐ GATE 2 — ELIGIBILITY (FR28/AC4): validate() REJECTS a manual-seed run (run.meta_progression_eligible == false) with
# the stable run_not_meta_eligible code ([Decision] — reject, so a manual-seed run VISIBLY grants nothing: ZERO Oath
# Shards, ZERO class mastery, ZERO unlock progress, ZERO event, the profile UNCHANGED). The eligibility is ALREADY
# computed + validated in the domain (RunState.validate() asserts meta_progression_eligible == not is_manual_seed, in
# lockstep with RiskEconomyState.oath_shard_eligible) — the award READS it; it does not re-derive it.
#
# WHAT THIS IS NOT (scope boundaries): it AWARDS only Oath Shards (the currency) — Echoes / Seal-Fragments / class-
# mastery / unlock-progress are Story 8.4 (the profile has empty/0 HOMES for them, untouched here). It does NOT SPEND
# the currency, does NOT apply any stat/passive/class from it, and does NOT build the unlock tree (AC3 — a capped/sparse
# currency award, not a raw-stat ladder). It does NOT persist the profile itself — the caller calls
# ProfileRepository.write_profile with the mutated profile (AC5's structured save-failure recovery is the repository's).
# It is NOT auto-wired into run_to_completion (no live death source in v0; caller-driven behind resolve_run_end).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MetaAwardRules = preload("res://scripts/save/meta_award_rules.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

# The reason marker recorded on the award event (in DomainEvent.OATH_SHARDS_AWARDED_REASONS — the validator pins the
# allowlist). Referenced from the event const so the command + validator stay in lockstep.
const AWARD_REASON := &"run_completed_eligible"

# The profile the award lands on (supplied via the constructor). MUTATED on success (oath_shards + last_awarded_run_seed).
var profile: ProfileSnapshot = null
# The run's summary (Story 8.2 — the bounded award signal). Read-only.
var summary: RunSummary = null
var sequence_id: int = 1

func _init(new_profile: ProfileSnapshot = null, new_summary: RunSummary = null, new_sequence_id: int = 1) -> void:
	command_id = &"award_meta_progress"
	profile = new_profile
	summary = new_summary
	sequence_id = new_sequence_id


# Pure read: validate the event sequence id, the context (a terminal RunState + a profile), Gate 1 (idempotency — not
# already awarded), and Gate 2 (eligibility — not a manual-seed run). No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the 4.3 idiom): execute() builds oath_shards_awarded (sequence_id), and
	# DomainEvent.try_from_dictionary requires sequence_id > 0. Gate it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if profile == null:
		return _invalid_context()
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	if run.route == null:
		return _invalid_context()
	# The run must be structurally sound before we reason about the award (this also asserts the manual-seed/eligibility
	# lockstep invariant, so Gate 2 reads a validated flag).
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# The run must have ENDED (behind the 8.1 idempotency seam — a non-terminal run has no award). A non-terminal run
	# rejects with a stable code + ZERO mutation.
	if not run.is_terminal():
		return ActionResult.error(&"run_not_terminal", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# Gate 2 — ELIGIBILITY (FR28/AC4): a manual-seed run awards NOTHING (reject visibly; ZERO mutation, ZERO event).
	if not run.meta_progression_eligible:
		return ActionResult.error(&"run_not_meta_eligible", {
			"command": String(command_id),
			"is_manual_seed": run.is_manual_seed
		})

	# Gate 1 — IDEMPOTENCY (AC1 + the 8.1 seam): a run whose identity already matches the profile's last-awarded marker
	# is a no-op (no double-award). The root_seed IS the v0 run identity (RunState has no run_id).
	if profile.last_awarded_run_seed == str(run.root_seed):
		return ActionResult.error(&"run_already_awarded", {
			"command": String(command_id),
			"run_seed": str(run.root_seed)
		})

	return ActionResult.ok()


# Validate-then-mutate: compute the capped award (Task 3), UPDATE the profile (cross-run oath_shards + the idempotency
# marker), build the oath_shards_awarded event (Task 5), and return ok([event], {award fields}). On ANY reject: ZERO
# events, ZERO mutation (run + profile byte-identical). Draws ZERO RNG; builds the event ONLY after the award is applied.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var amount: int = MetaAwardRules.oath_shard_award_for(run, summary)
	var before: int = profile.oath_shards
	var after: int = before + amount

	# Apply the award to the profile (the cross-run total rises; record the run identity so a re-award is a no-op).
	profile.oath_shards = after
	profile.last_awarded_run_seed = str(run.root_seed)

	var event: DomainEvent = DomainEvent.oath_shards_awarded(sequence_id, {
		"amount": amount,
		"oath_shards_before": before,
		"oath_shards_after": after,
		"reason": String(AWARD_REASON),
		"profile_id": profile.profile_id
	})

	return ActionResult.ok([event], {
		"oath_shards_awarded": true,
		"amount": amount,
		"oath_shards_before": before,
		"oath_shards_after": after,
		"reason": String(AWARD_REASON),
		"profile_id": profile.profile_id
	})


# A single stable top-level code (invalid_context) holds the null-profile / not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring CompleteRunCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
