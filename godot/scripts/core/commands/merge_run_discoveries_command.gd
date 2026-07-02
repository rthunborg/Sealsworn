class_name MergeRunDiscoveriesCommand
extends "res://scripts/core/commands/game_command.gd"

# Story 8.4 (AC1/AC2/AC3) — the DISCOVERY-MERGE APPLICATION command: the run-domain command that MERGES an ELIGIBLE run's
# discovered Echoes / Seal Fragments / class-mastery points / unlock flags into the cross-run PROFILE when the run ENDS,
# behind the SAME TWO GATES the award (AwardMetaProgressCommand) sits behind so a re-merge never double-grants and a
# manual-seed run never merges. It is the "unlock or advance something" half of Epic 8 (the award is the "receive
# currency" half). It reads the TERMINAL RunState + the run's ordered content_discovered EVENT list (the DISCOVERY SOURCE
# DECISION — v0 has NO persisted in-run discovery home, so discoveries are DERIVED from the events the run emitted,
# mirroring 8.2's RunSummary.build(run, events) pattern for passives_consumed/notable_loot) + the current ProfileSnapshot,
# MERGES the discoveries into the profile's echoes / class_mastery / unlock_progress homes, computes deterministic unlock
# THRESHOLD crossings (UnlockProgressRules, AC3), and RECORDS the change via the deterministic profile_progress_merged
# event.
#
# ⭐ THE 4.3 RUN-COMMAND IDIOM VERBATIM (mirroring AwardMetaProgressCommand): validate(state)/execute(state) take the live
# TERMINAL RunState DIRECTLY as `state` (no wrapper); the PROFILE + the DISCOVERY EVENT list + the run-level sequence_id
# are supplied via the constructor; validate() rejects sequence_id <= 0 FIRST (invalid_event_sequence_id) so a success
# path can never emit an event its own validator would reject; validate-then-mutate with ZERO events + a byte-identical
# no-mutation run AND profile on ANY reject; the event is built ONLY AFTER the merge is applied. It draws ZERO RNG (the
# merge + the threshold calc are deterministic calculations, not rolls).
#
# ⭐ GATE 1 — IDEMPOTENCY (AC1 "duplicate discoveries do not grant duplicate unique unlocks" + the 8.1 seam). TWO layers:
#   (a) PER-INVOCATION ([Decision] — the IDEMPOTENCY DECISION): the merge records a DEDICATED run-identity marker
#       `unlock_progress[LAST_MERGED_RUN_SEED_KEY]` (the decimal-string root_seed — RunState has no run_id). validate()
#       REJECTS a run whose root_seed already equals this with the stable run_already_merged code (ZERO second event, ZERO
#       double-mutation). It is a DEDICATED merge marker stored INSIDE the existing unlock_progress Dictionary home (NOT a
#       new top-level ProfileSnapshot key — so 8.4 merges WITHOUT a migration, honoring the reserved-homes decision) so
#       the merge is FULLY INDEPENDENT of the award's last_awarded_run_seed: the caller may run award-then-merge OR
#       merge-then-award (either order works, each is separately idempotent) — the alternative (a SHARED
#       last_awarded_run_seed both set + check) would make whichever command runs FIRST block the SECOND in BOTH orders.
#       The threshold rule reads ONLY seal_fragments, so this bookkeeping key never perturbs a crossing; the summary
#       derives from events (not the profile), so it never leaks the marker.
#   (b) PER-ITEM (SET semantics): echoes is a SET of unique ids (an id already present is not appended twice);
#       unlock_progress[seal_fragments] is a SET of unique ids (a Seal Fragment already unlocked is not re-unlocked); an
#       unlock_flag already true is not re-set. So even a FIRST merge with DUPLICATE ids in the discovery list grants each
#       unique unlock EXACTLY once (AC1's "duplicate discoveries" clause is about the CONTENT, not just re-invocation).
#       class-mastery is the exception — a mastery point may legitimately ACCUMULATE (a count that rises per discovery),
#       but the per-RUN merge is still idempotent via the per-invocation marker (a) so a re-merge never re-accumulates.
#
# ⭐ GATE 2 — ELIGIBILITY (FR28/AC2): validate() REJECTS a manual-seed run (run.meta_progression_eligible == false) with
# the stable run_not_meta_eligible code (the EXACT gate code + shape AwardMetaProgressCommand uses) — a manual-seed run
# merges NOTHING (ZERO Echoes, ZERO Seal Fragments, ZERO mastery, ZERO unlock progress, ZERO event, the profile
# byte-identical). AC2: a manual-seed run's discoveries MAY appear in the RUN SUMMARY as "discovered during replay" (the
# summary derives them from the SAME events) but grant NO permanent meta progress (the merge denies the grant here).
#
# WHAT THIS IS NOT (scope boundaries): it authors NO Echo/Seal-Fragment/mastery CONTENT roster or repository (it tracks
# discoveries BY id — the codex/seal content is a later content story). It does NOT SPEND Oath Shards, apply any
# stat/passive/class/starting-option from an unlock, or build an unlock-SPEND tree (AC3 — it RECORDS the unlock STATE
# flip; the effect-application is a later meta-spend story, 8.6+/Epic 9). It does NOT bump ProfileSnapshot.SCHEMA_VERSION
# or add a migration (it merges into the EXISTING reserved homes at SCHEMA_VERSION == 1). It does NOT persist the profile
# itself — the caller calls ProfileRepository.write_profile with the mutated profile. It is NOT auto-wired into
# run_to_completion (no live discovery source in v0; caller-driven behind the run-end seam, like the 8.3 award).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const UnlockProgressRules = preload("res://scripts/save/unlock_progress_rules.gd")

# The dedicated per-invocation idempotency marker key, stored INSIDE the existing unlock_progress Dictionary home (NOT a
# new top-level ProfileSnapshot key — so 8.4 merges without a migration). Holds the decimal-string root_seed of the LAST
# run whose discoveries were merged. Namespaced under a leading underscore so it can never collide with a lower_snake
# unlock-track/flag key (which never begins with "_"), and so the threshold rule / summary derive ignore it.
const LAST_MERGED_RUN_SEED_KEY := "_last_merged_run_seed"

# The profile the merge lands on (supplied via the constructor). MUTATED on success (echoes / class_mastery /
# unlock_progress + the idempotency marker).
var profile: ProfileSnapshot = null
# The run's ordered discovery event list (the caller collected these across the run — the DISCOVERY SOURCE). The command
# scans it for content_discovered events. Received untyped; type-checked per element (the 8.2 RunSummary.build precedent).
var discovery_events: Array = []
var sequence_id: int = 1

func _init(new_profile: ProfileSnapshot = null, new_discovery_events: Array = [], new_sequence_id: int = 1) -> void:
	command_id = &"merge_run_discoveries"
	profile = new_profile
	discovery_events = new_discovery_events
	sequence_id = new_sequence_id


# Pure read: validate the event sequence id, the context (a terminal RunState + a profile), Gate 2 (eligibility — not a
# manual-seed run), and Gate 1 (idempotency — not already merged). No mutation, no event, no RNG. Mirrors
# AwardMetaProgressCommand's gate ORDER (sequence-id -> context -> terminal -> eligibility -> idempotency).
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the 4.3 idiom): execute() builds profile_progress_merged(sequence_id), and
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
	# The run must be structurally sound before we reason about the merge (this also asserts the manual-seed/eligibility
	# lockstep invariant, so Gate 2 reads a validated flag).
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# The run must have ENDED (behind the 8.1 idempotency seam — a non-terminal run has no merge). ZERO mutation.
	if not run.is_terminal():
		return ActionResult.error(&"run_not_terminal", {
			"command": String(command_id),
			"phase": String(run.phase)
		})

	# Gate 2 — ELIGIBILITY (FR28/AC2): a manual-seed run merges NOTHING (reject visibly; ZERO mutation, ZERO event). The
	# EXACT code + shape AwardMetaProgressCommand uses, so the award path + the merge path deny a manual-seed run identically.
	if not run.meta_progression_eligible:
		return ActionResult.error(&"run_not_meta_eligible", {
			"command": String(command_id),
			"is_manual_seed": run.is_manual_seed
		})

	# Gate 1(a) — PER-INVOCATION IDEMPOTENCY (AC1 + the 8.1 seam): a run whose identity already matches the profile's
	# dedicated merge marker is a no-op (no double-grant). The root_seed IS the v0 run identity (RunState has no run_id).
	if _last_merged_run_seed() == str(run.root_seed):
		return ActionResult.error(&"run_already_merged", {
			"command": String(command_id),
			"run_seed": str(run.root_seed)
		})

	return ActionResult.ok()


# Validate-then-mutate: derive the discoveries from the event list, MERGE them into the profile (set-based per item),
# compute deterministic unlock-threshold crossings, record the idempotency marker, build the profile_progress_merged
# event, and return ok([event], {merge summary}). On ANY reject: ZERO events, ZERO mutation (run + profile
# byte-identical). Draws ZERO RNG; builds the event ONLY after the merge is applied.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState

	# ---- derive the discoveries from the event list (the DISCOVERY SOURCE). Scan ONCE, bucketing by content_kind. A
	# non-DomainEvent / non-content_discovered entry is ignored (the tolerant-element-type contract).
	var echo_ids: Array[String] = []
	var seal_fragment_ids: Array[String] = []
	var mastery_ids: Array[String] = []  # class ids, ordered, WITH duplicates (mastery accumulates per discovery).
	var unlock_flag_ids: Array[String] = []
	for event_value: Variant in discovery_events:
		if not (event_value is DomainEvent):
			continue
		var event: DomainEvent = event_value
		if event.event_type != DomainEvent.Type.CONTENT_DISCOVERED:
			continue
		var content_kind: String = String(event.payload.get("content_kind", ""))
		var content_id: String = String(event.payload.get("content_id", ""))
		if content_id.is_empty():
			continue
		match content_kind:
			"echo":
				echo_ids.append(content_id)
			"seal_fragment":
				seal_fragment_ids.append(content_id)
			"class_mastery":
				mastery_ids.append(content_id)
			"unlock_flag":
				unlock_flag_ids.append(content_id)
			_:
				# An unknown kind (an out-of-allowlist content_discovered would have been rejected at event build, but be
				# defensive) is ignored.
				pass

	# ---- MERGE per item (SET semantics for echoes / seal_fragments / unlock_flags; ACCUMULATE for mastery). Track the
	# NEWLY-added deltas (what the event records) — a duplicate id already present is NOT a new delta.
	# echoes: a unique-id SET on the profile.
	var added_echo_ids: Array[String] = []
	for echo_id: String in echo_ids:
		if not profile.echoes.has(echo_id) and not added_echo_ids.has(echo_id):
			profile.echoes.append(echo_id)
			added_echo_ids.append(echo_id)

	# unlock_progress[seal_fragments]: a unique-id SET inside unlock_progress (the SEAL FRAGMENTS HOME DECISION).
	var seal_set: Array = _seal_fragment_set()
	var added_seal_fragment_ids: Array[String] = []
	for seal_id: String in seal_fragment_ids:
		if not seal_set.has(seal_id) and not added_seal_fragment_ids.has(seal_id):
			seal_set.append(seal_id)
			added_seal_fragment_ids.append(seal_id)
	profile.unlock_progress[UnlockProgressRules.SEAL_FRAGMENTS_KEY] = seal_set

	# class_mastery: a per-class ACCUMULATING count (each discovery adds one point). The delta is the count of discoveries
	# for that class in THIS merge (idempotency at the RUN level is the per-invocation marker, not set semantics here).
	var mastery_deltas: Array = []
	var mastery_delta_by_class: Dictionary = {}
	for class_id: String in mastery_ids:
		mastery_delta_by_class[class_id] = int(mastery_delta_by_class.get(class_id, 0)) + 1
	# Apply in first-seen order (deterministic; mastery_ids preserves discovery order).
	var mastery_applied: Dictionary = {}
	for class_id: String in mastery_ids:
		if mastery_applied.has(class_id):
			continue
		mastery_applied[class_id] = true
		var delta: int = int(mastery_delta_by_class.get(class_id, 0))
		profile.class_mastery[class_id] = int(profile.class_mastery.get(class_id, 0)) + delta
		mastery_deltas.append({"class_id": class_id, "delta": delta})

	# unlock_flag: a bool STATE flag in unlock_progress (idempotent — a flag already true is not re-set).
	var added_unlock_flag_ids: Array[String] = []
	for flag_id: String in unlock_flag_ids:
		if not bool(profile.unlock_progress.get(flag_id, false)) and not added_unlock_flag_ids.has(flag_id):
			profile.unlock_progress[flag_id] = true
			added_unlock_flag_ids.append(flag_id)

	# ---- deterministic unlock-THRESHOLD crossings (AC3): evaluate the merged unlock_progress, apply the new state, and
	# record the crossed threshold ids. Draws ZERO RNG (a pure calculation).
	var evaluation: Dictionary = UnlockProgressRules.evaluate(profile.unlock_progress)
	profile.unlock_progress = evaluation.get("state")
	var thresholds_crossed: Array = evaluation.get("thresholds_crossed")

	# ---- record the per-invocation idempotency marker (so a re-merge for THIS run is a no-op).
	profile.unlock_progress[LAST_MERGED_RUN_SEED_KEY] = str(run.root_seed)

	# ---- build the merge event ONLY after the merge is applied.
	var event: DomainEvent = DomainEvent.profile_progress_merged(sequence_id, {
		"added_echo_ids": added_echo_ids,
		"added_seal_fragment_ids": added_seal_fragment_ids,
		"added_unlock_flag_ids": added_unlock_flag_ids,
		"thresholds_crossed": thresholds_crossed,
		"class_mastery_deltas": mastery_deltas,
		"echoes_added": added_echo_ids.size(),
		"seal_fragments_added": added_seal_fragment_ids.size(),
		"unlock_flags_added": added_unlock_flag_ids.size(),
		"thresholds_crossed_count": thresholds_crossed.size(),
		"profile_id": profile.profile_id
	})

	return ActionResult.ok([event], {
		"profile_progress_merged": true,
		"added_echo_ids": added_echo_ids,
		"added_seal_fragment_ids": added_seal_fragment_ids,
		"added_unlock_flag_ids": added_unlock_flag_ids,
		"class_mastery_deltas": mastery_deltas,
		"thresholds_crossed": thresholds_crossed,
		"profile_id": profile.profile_id
	})


# The profile's dedicated per-invocation merge marker (the decimal-string root_seed of the last merged run), or "" if
# never merged / malformed. Read-only.
func _last_merged_run_seed() -> String:
	if profile == null:
		return ""
	var value: Variant = profile.unlock_progress.get(LAST_MERGED_RUN_SEED_KEY, "")
	return String(value)


# The profile's Seal-Fragment id set (a fresh Array to mutate + write back). A missing/malformed entry starts a fresh
# empty set (fail-safe — never coerce a foreign shape).
func _seal_fragment_set() -> Array:
	var value: Variant = profile.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY, [])
	if value is Array:
		return (value as Array).duplicate()
	return []


# A single stable top-level code (invalid_context) holds the null-profile / not-a-RunState / null-route /
# structurally-invalid-run cases, surfacing the inner validate() error for diagnosis (mirroring AwardMetaProgressCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
