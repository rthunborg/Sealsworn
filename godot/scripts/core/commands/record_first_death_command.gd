class_name RecordFirstDeathCommand
extends "res://scripts/core/commands/game_command.gd"

# Story 8.5 (AC1, FR61) — the FIRST-DEATH RECORD command: the run-domain command that flips the cross-run profile's
# first_death_recorded LATCH the FIRST time a run DIES, behind the run-end seam, so the first-death narrative LINE
# ("Good. You remembered how to die.") can be shown ONCE and NEVER repeated as a first-death event. It is the "narrative
# flavor without blocking play" half of Epic 8 — a sibling of the 8.3 award (AwardMetaProgressCommand) + the 8.4 merge
# (MergeRunDiscoveriesCommand), the THREE run-domain commands that may mutate the profile at run end.
#
# ⭐ THE 4.3 RUN-COMMAND IDIOM VERBATIM (mirroring AwardMetaProgressCommand / MergeRunDiscoveriesCommand): validate(state)/
# execute(state) take the live TERMINAL RunState DIRECTLY as `state` (no wrapper); the PROFILE + the run-level sequence_id
# are supplied via the constructor; validate() rejects sequence_id <= 0 FIRST (invalid_event_sequence_id) so a success
# path can never emit an event its own validator would reject; validate-then-mutate with ZERO events + a byte-identical
# no-mutation run AND profile on ANY reject; the event is built ONLY AFTER the flag is set. It draws ZERO RNG (a first-death
# record is a deterministic flag set + event, not a roll).
#
# ⭐ DEATH-ONLY GATE (AC1 — the discriminator vs the Epic-9 first-VICTORY reveal): the flag is set ONLY when the terminal
# run is a DEATH (run.phase == RunState.PHASE_FAILED). A COMPLETED run (a victory) is NOT a first death — validate() rejects
# it with the stable run_not_failed code + ZERO mutation. Read the terminal phase off the RunState (mirroring how
# RunSummary._derive_outcome_or_cause branches on the terminal phase). The Epic-9 first-VICTORY reveal ("It did not die. It
# learned the way back." — FR62) keys off the OPPOSITE terminal phase; 8.5 owns the first-DEATH line only.
#
# ⭐ ONCE-ONLY IDEMPOTENCY (AC1 "the line is tracked so it is not repeated as a first-death event"): the first_death_recorded
# bool IS its own idempotency marker — a MONOTONIC PER-PROFILE-LIFETIME LATCH (set once on the FIRST death across ALL runs,
# then never again). On a first death (profile.first_death_recorded == false) SET it true + emit the event. On EVERY
# subsequent death (profile.first_death_recorded == true) validate() rejects with the stable first_death_already_recorded
# code + ZERO mutation + ZERO event — so a second, third, Nth death NEVER re-emits the first-death event and NEVER re-shows
# the line. This is a THIRD INDEPENDENT run-end idempotency mechanism alongside the award's last_awarded_run_seed and the
# merge's unlock_progress["_last_merged_run_seed"] (the 8.4 two-marker invariant). 8.5 does NOT read or write EITHER seed
# marker — the first-death latch is per-PROFILE-lifetime (it fires on the FIRST death across ALL runs), NOT per-run (the
# award/merge fire once PER eligible run). All three mechanisms are INDEPENDENT and safe in ANY caller order.
#
# ⭐ ELIGIBILITY DECISION ([Decision] — Option A, RECOMMENDED, recorded in the story Completion Notes): the first-death flag
# is DELIBERATELY NOT gated on meta_progression_eligible. UNLIKE the award (8.3) + the merge (8.4), which DENY a manual-seed
# run at their FR28 eligibility gate (a manual-seed run grants NO meta progression), the first-death flag fires on the first
# real death WHETHER OR NOT the run was manual-seed. Rationale: the line is PURE NARRATIVE FLAVOR (FR61/FR64 — "story
# discovery optional; the game must be fun for players who ignore all lore"), and setting a boolean narrative LATCH is NOT
# "granting meta progression" in the FR28 sense — it grants ZERO Oath Shards, ZERO unlocks, ZERO class mastery. This keeps
# the narrative beat available even in a manual-seed practice death (a player practicing their first-ever death still
# "remembers how to die"). FR64 ("story discovery optional") cuts toward availability: the line is flavor, not a reward. The
# latch is therefore eligibility-INDEPENDENT by design — it does NOT violate FR28 because it is a narrative marker, not
# progression currency/unlocks. 8.6/8.7 must treat the first-death latch as eligibility-independent when they wire the
# outpost + the save-load matrix.
#
# WHAT THIS IS NOT (scope boundaries): it sets ONLY the first_death_recorded bool + emits first_death_recorded — it awards
# NO Oath Shards, merges NO discoveries, and touches NEITHER the award's oath_shards/last_awarded_run_seed NOR the merge's
# echoes/class_mastery/unlock_progress/_last_merged_run_seed. It does NOT build the narrative BEAT DTO (FirstDeathNarrative
# Beat is a SEPARATE pure-read surface — the line DELIVERY is decoupled from the flag MUTATION so a skip cannot mutate the
# flag), does NOT build the outpost MENU scene (Story 8.6; UI-scene-last), and does NOT author a narrative CONTENT roster
# (v0 has EXACTLY ONE line — a single const on the DTO + the flag + the event is the whole surface). It does NOT bump
# ProfileSnapshot.SCHEMA_VERSION or add a migration (it SETS the EXISTING reserved first_death_recorded home at
# SCHEMA_VERSION == 1 — the 8.4 merge-without-migration discipline). It does NOT persist the profile itself — the caller
# calls ProfileRepository.write_profile with the mutated profile (the repository is UNCHANGED; the set flag rides
# to_dictionary() automatically). It is NOT auto-wired into run_to_completion (no live combat death source in v0; caller-
# driven behind the run-end seam, exactly like the 8.3 award + the 8.4 merge).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The stable lower_snake narrative-line id the first-death event carries (LINE-AS-ID — the line is referenced BY id, NOT
# the raw prose). Referenced from the event const so the command + the validator stay in lockstep on the line vocabulary.
const FIRST_DEATH_LINE_ID := DomainEvent.FIRST_DEATH_LINE_ID

# The first-death narrative beat is ALWAYS skippable in v0 (FR65 — a control-loss/narrative moment must be skippable).
const IS_SKIPPABLE := true

# The profile the first-death flag lands on (supplied via the constructor). MUTATED on success (first_death_recorded).
var profile: ProfileSnapshot = null
var sequence_id: int = 1

func _init(new_profile: ProfileSnapshot = null, new_sequence_id: int = 1) -> void:
	command_id = &"record_first_death"
	profile = new_profile
	sequence_id = new_sequence_id


# Pure read: validate the event sequence id, the context (a terminal RunState + a profile), the DEATH-ONLY gate (the run
# is FAILED), and the ONCE-ONLY idempotency (the flag is not already set). No mutation, no event, no RNG. Mirrors
# AwardMetaProgressCommand's gate ORDER (sequence-id -> context -> terminal -> death-only -> idempotency). NOTE (Option A):
# there is DELIBERATELY NO eligibility gate — a manual-seed first death STILL records the flag (the line is narrative
# flavor, not meta progression; see the class doc).
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the 4.3 idiom): execute() builds first_death_recorded(sequence_id), and
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

	# The run must have ENDED (behind the 8.1 run-end seam — a non-terminal run has no first-death record). ZERO mutation.
	if not run.is_terminal():
		return ActionResult.error(&"run_not_terminal", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# DEATH-ONLY GATE (AC1): the flag is set ONLY on a DEATH (PHASE_FAILED). A completed/victory run is NOT a first death —
	# reject with a stable code + ZERO mutation. This is the discriminator vs the Epic-9 first-VICTORY reveal (opposite phase).
	if run.phase != RunState.PHASE_FAILED:
		return ActionResult.error(&"run_not_failed", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# ONCE-ONLY IDEMPOTENCY (AC1 "not repeated as a first-death event"): the first_death_recorded bool IS the marker (a
	# monotonic per-profile-lifetime latch). On a subsequent death (flag already true) reject with a stable code + ZERO
	# mutation + ZERO event — so the first-death event/line NEVER re-fires. Independent of the award/merge seed markers.
	if profile.first_death_recorded:
		return ActionResult.error(&"first_death_already_recorded", {
			"command": String(command_id),
			"profile_id": profile.profile_id
		})

	return ActionResult.ok()


# Validate-then-mutate: SET the profile's first_death_recorded latch, build the first_death_recorded event (the line marker
# + the skippable flag), and return ok([event], {first-death fields}). On ANY reject: ZERO events, ZERO mutation (run +
# profile byte-identical). Draws ZERO RNG; builds the event ONLY after the flag is set.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	# Set the monotonic per-profile-lifetime latch (records the first-death FACT for the once-only guard, INDEPENDENT of
	# whether the narrative beat is ever shown or skipped — the line delivery is the SEPARATE FirstDeathNarrativeBeat DTO).
	profile.first_death_recorded = true

	# Build the first-death event ONLY after the flag is set. It carries the line BY id (LINE-AS-ID) + the skippable flag +
	# the profile the flag landed on. Deterministic (ZERO RNG — no roll/draw_index).
	var event: DomainEvent = DomainEvent.first_death_recorded(sequence_id, {
		"line_id": String(FIRST_DEATH_LINE_ID),
		"is_skippable": IS_SKIPPABLE,
		"profile_id": profile.profile_id
	})

	# Return the first-death fact + the beat data in the result metadata so a caller has it without re-reading the profile
	# (the 8.3/8.4 result-metadata precedent). The caller persists the mutated profile via ProfileRepository.write_profile.
	return ActionResult.ok([event], {
		"first_death_recorded": true,
		"line_id": String(FIRST_DEATH_LINE_ID),
		"is_skippable": IS_SKIPPABLE,
		"profile_id": profile.profile_id
	})


# A single stable top-level code (invalid_context) holds the null-profile / not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring AwardMetaProgressCommand /
# MergeRunDiscoveriesCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
