class_name RecordFirstVictoryCommand
extends "res://scripts/core/commands/game_command.gd"

# Story 9.4 (AC2, FR62) — the FIRST-VICTORY RECORD command: the run-domain command that flips the cross-run profile's
# first_victory_recorded LATCH the FIRST time a run is WON (the Larval Avatar reaches 0 HP and the run resolves to
# PHASE_COMPLETED), behind the run-end seam, so the first-victory REVEAL LINE ("It did not die. It learned the way back.")
# can be shown ONCE and NEVER repeated as a first-victory event. It is the OPPOSITE-terminal-phase TWIN of the 8.5
# RecordFirstDeathCommand — a sibling of the 8.3 award (AwardMetaProgressCommand) + the 8.4 merge (MergeRunDiscoveries
# Command) + the 8.5 first-death latch, the run-domain commands that may mutate the profile at run end.
#
# ⭐ MIRRORS RecordFirstDeathCommand VERBATIM at the OPPOSITE phase — the ONLY differences: the gate is VICTORY-only
# (run.phase == RunState.PHASE_COMPLETED, reject a FAILED run with run_not_completed) instead of DEATH-only, and the latch
# is first_victory_recorded instead of first_death_recorded. EVERYTHING else is identical: the 4.3 run-command idiom, the
# once-only idempotency, the ZERO-RNG deterministic shell, and Option A eligibility-independence.
#
# ⭐ THE 4.3 RUN-COMMAND IDIOM VERBATIM (mirroring RecordFirstDeathCommand / AwardMetaProgressCommand): validate(state)/
# execute(state) take the live TERMINAL RunState DIRECTLY as `state` (no wrapper); the PROFILE + the run-level sequence_id
# are supplied via the constructor; validate() rejects sequence_id <= 0 FIRST (invalid_event_sequence_id) so a success
# path can never emit an event its own validator would reject; validate-then-mutate with ZERO events + a byte-identical
# no-mutation run AND profile on ANY reject; the event is built ONLY AFTER the flag is set. It draws ZERO RNG (a
# first-victory record is a deterministic flag set + event, not a roll).
#
# ⭐ VICTORY-ONLY GATE (AC2 — the discriminator vs 8.5's first-DEATH reveal): the flag is set ONLY when the terminal run is
# a VICTORY (run.phase == RunState.PHASE_COMPLETED — the run-victory the boss defeat resolves via CompleteRunCommand with
# the `victory` outcome). A FAILED run (a death) is NOT a first victory — validate() rejects it with the stable
# run_not_completed code + ZERO mutation. This is the exact mirror of 8.5's run_not_failed reject at the OPPOSITE phase.
#
# ⭐ ONCE-ONLY IDEMPOTENCY (AC2 "the reveal is tracked so first-victory state is persisted"): the first_victory_recorded
# bool IS its own idempotency marker — a MONOTONIC PER-PROFILE-LIFETIME LATCH (set once on the FIRST victory across ALL
# runs, then never again). On a first victory (profile.first_victory_recorded == false) SET it true + emit the event. On
# EVERY subsequent victory (profile.first_victory_recorded == true) validate() rejects with the stable
# first_victory_already_recorded code + ZERO mutation + ZERO event — so a second, third, Nth victory NEVER re-emits the
# first-victory event and NEVER re-shows the reveal line. This is the FOURTH INDEPENDENT run-end idempotency mechanism
# alongside the award's last_awarded_run_seed, the merge's unlock_progress["_last_merged_run_seed"], and 8.5's
# first_death_recorded latch. 9.4 does NOT read or write ANY of those three markers — the first-victory latch is
# per-PROFILE-lifetime (it fires on the FIRST victory across ALL runs). All four mechanisms are INDEPENDENT and safe in
# ANY caller order.
#
# ⭐ ELIGIBILITY DECISION ([Decision] — Option A, mirroring the ratified 8.5 first-death Option A, recorded in the story
# Completion Notes): the first-victory flag is DELIBERATELY NOT gated on meta_progression_eligible. UNLIKE the award (8.3)
# + the merge (8.4), which DENY a manual-seed run at their FR28 eligibility gate (a manual-seed run grants NO meta
# progression), the first-victory flag fires on the first real victory WHETHER OR NOT the run was manual-seed. Rationale:
# the reveal line is PURE NARRATIVE FLAVOR (FR61/FR64 — "story discovery optional; the game must be fun for players who
# ignore all lore"), and setting a boolean narrative LATCH is NOT "granting meta progression" in the FR28 sense — it grants
# ZERO Oath Shards, ZERO unlocks, ZERO class mastery. This keeps the first-victory beat available even in a manual-seed
# practice victory. This diverges from the award/merge (which DENY a manual-seed run) but MATCHES 8.5's ratified first-death
# Option A — the FR28 narrative-vs-meta boundary precedent. 9.5/later must treat the first-victory latch as
# eligibility-independent.
#
# WHAT THIS IS NOT (scope boundaries): it sets ONLY the first_victory_recorded bool + emits first_victory_recorded — it
# awards NO Oath Shards, merges NO discoveries, drives NO run-victory resolution (CompleteRunCommand with `victory` owns
# the run-END transition + run_completed; this command runs BEHIND that seam on the already-terminal COMPLETED run), and
# touches NONE of the award/merge/first-death markers. It does NOT build the reveal BEAT DTO (FirstVictoryRevealBeat is a
# SEPARATE pure-read surface — the line DELIVERY is decoupled from the flag MUTATION so a skip cannot mutate the flag), does
# NOT build the outpost MENU scene (UI-scene-last), and does NOT author a narrative CONTENT roster (v0 has EXACTLY ONE
# line). It does NOT bump ProfileSnapshot.SCHEMA_VERSION or add a migration (it SETS the NEW additive first_victory_recorded
# home at SCHEMA_VERSION == 1). It does NOT persist the profile itself — the caller calls ProfileRepository.write_profile
# with the mutated profile (the repository is UNCHANGED; the set flag rides to_dictionary() automatically). It is NOT
# auto-wired into run_to_completion (the boss VICTORY resolution is caller-driven behind the run-end seam, exactly like the
# 8.3 award + the 8.4 merge + the 8.5 first-death record).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The stable lower_snake narrative-line id the first-victory event carries (LINE-AS-ID — the line is referenced BY id, NOT
# the raw prose). Referenced from the event const so the command + the validator stay in lockstep on the line vocabulary.
const FIRST_VICTORY_LINE_ID := DomainEvent.FIRST_VICTORY_LINE_ID

# The first-victory reveal is ALWAYS skippable in v0 (FR65 — a control-loss/narrative moment must be skippable).
const IS_SKIPPABLE := true

# The profile the first-victory flag lands on (supplied via the constructor). MUTATED on success (first_victory_recorded).
var profile: ProfileSnapshot = null
var sequence_id: int = 1

func _init(new_profile: ProfileSnapshot = null, new_sequence_id: int = 1) -> void:
	command_id = &"record_first_victory"
	profile = new_profile
	sequence_id = new_sequence_id


# Pure read: validate the event sequence id, the context (a terminal RunState + a profile), the VICTORY-ONLY gate (the run
# is COMPLETED), and the ONCE-ONLY idempotency (the flag is not already set). No mutation, no event, no RNG. Mirrors
# RecordFirstDeathCommand's gate ORDER (sequence-id -> context -> terminal -> victory-only -> idempotency). NOTE (Option A):
# there is DELIBERATELY NO eligibility gate — a manual-seed first victory STILL records the flag (the line is narrative
# flavor, not meta progression; see the class doc).
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the 4.3 idiom): execute() builds first_victory_recorded(sequence_id), and
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
	# The run must be structurally sound before we reason about the flag.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# The run must have ENDED (behind the 8.1 run-end seam — a non-terminal run has no first-victory record). ZERO mutation.
	if not run.is_terminal():
		return ActionResult.error(&"run_not_terminal", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# VICTORY-ONLY GATE (AC2): the flag is set ONLY on a VICTORY (PHASE_COMPLETED). A FAILED run (a death) is NOT a first
	# victory — reject with a stable code + ZERO mutation. This is the discriminator vs 8.5's first-DEATH reveal (which keys
	# off PHASE_FAILED with the run_not_failed reject; 9.4 mirrors it at the OPPOSITE phase with run_not_completed).
	if run.phase != RunState.PHASE_COMPLETED:
		return ActionResult.error(&"run_not_completed", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# ONCE-ONLY IDEMPOTENCY (AC2 "first-victory state is persisted / not repeated"): the first_victory_recorded bool IS the
	# marker (a monotonic per-profile-lifetime latch). On a subsequent victory (flag already true) reject with a stable code
	# + ZERO mutation + ZERO event — so the first-victory event/line NEVER re-fires. Independent of the award/merge/first-
	# death markers.
	if profile.first_victory_recorded:
		return ActionResult.error(&"first_victory_already_recorded", {
			"command": String(command_id),
			"profile_id": profile.profile_id
		})

	return ActionResult.ok()


# Validate-then-mutate: SET the profile's first_victory_recorded latch, build the first_victory_recorded event (the line
# marker + the skippable flag), and return ok([event], {first-victory fields}). On ANY reject: ZERO events, ZERO mutation
# (run + profile byte-identical). Draws ZERO RNG; builds the event ONLY after the flag is set.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	# Set the monotonic per-profile-lifetime latch (records the first-victory FACT for the once-only guard, INDEPENDENT of
	# whether the reveal beat is ever shown or skipped — the line delivery is the SEPARATE FirstVictoryRevealBeat DTO).
	profile.first_victory_recorded = true

	# Build the first-victory event ONLY after the flag is set. It carries the line BY id (LINE-AS-ID) + the skippable flag
	# + the profile the flag landed on. Deterministic (ZERO RNG — no roll/draw_index).
	var event: DomainEvent = DomainEvent.first_victory_recorded(sequence_id, {
		"line_id": String(FIRST_VICTORY_LINE_ID),
		"is_skippable": IS_SKIPPABLE,
		"profile_id": profile.profile_id
	})

	# Return the first-victory fact + the beat data in the result metadata so a caller has it without re-reading the profile
	# (the 8.3/8.4/8.5 result-metadata precedent). The caller persists the mutated profile via ProfileRepository.write_profile.
	return ActionResult.ok([event], {
		"first_victory_recorded": true,
		"line_id": String(FIRST_VICTORY_LINE_ID),
		"is_skippable": IS_SKIPPABLE,
		"profile_id": profile.profile_id
	})


# A single stable top-level code (invalid_context) holds the null-profile / not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring RecordFirstDeathCommand /
# AwardMetaProgressCommand / MergeRunDiscoveriesCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
