class_name OutpostViewModel
extends RefCounted

# Story 8.6 (AC1-AC4) — the scene-free OUTPOST view-model: the pure-read PROJECTION/ASSEMBLY that AGGREGATES the five
# prior Epic-8 read surfaces into ONE serializable outpost surface a later outpost .tscn (a future HUD/boot-flow story)
# renders. It is the "assemble the outpost surface + start the next run" DATA half of the return loop — a view-model /
# read-projection assembly + a start-run REQUEST seam, NOT new domain truth.
#
# ⭐ THE SINGLE MOST IMPORTANT ARCHITECTURAL FACT — EVERY read surface it aggregates, the profile repository, the class
# roster, the run-start command, and the recovery path ALREADY EXIST (SHIPPED by 8.1-8.5 + 5.2). This view model
# ASSEMBLES + WIRES them; it authors almost NO new domain truth. It mirrors the RunSummary / HeroSelectViewModel /
# RunEndOutcome exact-key + fail-closed + no-live-handle projection discipline VERBATIM. It draws ZERO RNG, submits NO
# command, emits NO event, and mutates NOTHING (not the profile, not the run, not the events, not the beat).
#
# WHAT IT AGGREGATES (AC1):
#   - ProfileSnapshot (8.3/8.4/8.5) — the SOURCE OF TRUTH for the cross-run meta readout: oath_shards (the AWARDED
#     total), echoes, unlock_progress (Seal Fragments + threshold flags), class_mastery, first_death_recorded. Read from
#     the PROFILE, NOT the run summary. ⭐ The AWARDED Oath-Shard total is profile.oath_shards; RunSummary.profile_meta
#     .oath_shards_earned STAYS 0/not-yet-supported (the summary reads NO profile), so the outpost's Oath-Shard display
#     reads the profile.
#   - RunSummary (8.2/8.4) — the (OPTIONAL) just-ended run's derived readout (or the fail-closed empty projection when
#     the outpost opens with no just-ended run — a fresh session). Rendered DIRECTLY: notable_loot is already
#     single-sourced/deduped from item_gained (NO second dedup — the 8.2 review ratification); not_yet_supported is the
#     honest limitation note the outpost surfaces.
#   - HeroSelectViewModel (5.2) — the class-options roster (selectable/locked + unlock hints). DELEGATED to (composed
#     from the same class repository); the roster projection is NOT re-implemented here.
#   - FirstDeathNarrativeBeat (8.5) — the (OPTIONAL) first-death narrative beat. RENDERED as a sub-dict; the DISMISS is a
#     PURE PRESENTATION NO-OP (the flag was set independently by 8.5's RecordFirstDeathCommand; the DTO is read-only). The
#     beat is OFF THE CRITICAL PATH — a null/absent beat never blocks the outpost surface.
#   - FirstVictoryRevealBeat (9.4) — Story 11.5 (AC2, Option A) added the OPPOSITE-phase twin as the SECOND embedded reveal
#     sub-dict (first_victory_beat), symmetric with first_death_beat (the 9.4 AC3 render [Decision] deferred wiring the
#     first-victory reveal onto OutpostViewModel to "a later UI story" = 11.5; this embed resolves it). Same PURE-READ /
#     structural-no-op-dismiss / off-critical-path posture as the first-death beat.
#   - RunEndOutcome (8.1) — the next_destination == outpost flow signal is the DOMAIN fact that "the app should show the
#     outpost now". 8.6 produces the outpost DATA the navigation lands on; it does NOT perform the navigation
#     (UI-scene-last).
#
# THE NAMED-SPACE METADATA (AC2): a small const registry of the four GDD outpost spaces (Memory Archive, Hall of Oaths,
# Seal Table, Gate/Descent Stair — gdd.md line 271) each with a STABLE lower_snake id + a display name + a `deferred`
# status marker + a maps_to note. It is DATA only — drives no domain state, gates no run, holds no truth (AC2 "without
# making UI state authoritative"). The exact outpost LAYOUT + the unlock-tree/menu SHAPE are explicitly deferred
# (gdd.md line 710) — 8.6 supplies stable ids + placeholders, NOT a final layout. The descent_stair is the only space
# with a live affordance in v0 (it maps to the AC3 start-another-descent action); the other three are display/deferred.
#
# THE START-ANOTHER-DESCENT SEAM (AC3): the outpost's "start run" action produces a REQUEST value (start_run_request),
# NOT a live start ([Decision] A). The CALLER (a later boot/HUD layer, or the test today) hands that request to a FRESH
# RunOrchestrator.start(root_seed, is_manual_seed, class_id) / RunStartCommand — the AUTHORITATIVE fail-closed start
# seam (UNCHANGED). This keeps the view model a pure read that owns no run and mutates nothing (AC1 "domain/profile
# snapshots remain source truth"; "do not let UI mutate domain state directly"). The prior completed/failed run is NOT
# reused BY CONSTRUCTION: start(...) builds a FRESH RunState.new_run(...) (resets current_node_id + cleared_node_ids), so
# AC3's "prior completed run state is not reused as active state" is STRUCTURAL (a new seed -> a new route -> a new run).
# The class is pre-gated fail-closed via HeroSelectViewModel.is_class_selectable(class_id); the seed-eligibility
# is_manual_seed flag is carried into the request (a manual-seed start -> meta_progression_eligible == false via the
# existing lockstep — 8.6 does NOT change the FR28 eligibility model). An EMPTY class id is the legacy no-class start
# (startable).
#
# THE RECOVERY / FRESH-PROFILE PATH (AC4): the construction path takes the loaded ProfileSnapshot (or a recovery
# signal) and projects a VALID surface for BOTH a real profile AND a fresh/recovery profile:
#   - A null/absent profile projects the FRESH-PROFILE default (ProfileSnapshot.fresh() — the profile_not_found
#     recovery path): a valid 0-Oath-Shard surface, empty Echoes/unlock progress/class mastery, first-death not
#     recorded, the full class roster. has_profile == false distinguishes it. No crash, no invalid meta state.
#   - An INCOMPATIBLE profile (unsupported_profile_schema from ProfileRepository.read_profile -> ProfileSnapshot.parse)
#     is represented as a STRUCTURED recovery_state (a flag + the structured code), NOT a crash. Build it via
#     for_recovery(code): the view model surfaces the recovery state; a later HUD story renders the recover affordance.
#     8.6 CONSUMES the existing structured result; it does NOT build the migration matrix (8.7).
#   - A failed profile WRITE (profile_save_* structured codes) is likewise a surfaced recovery_state + retry affordance
#     (the summary is never lost — it does not read the profile file, 8.3's structural guarantee).
#
# WHAT IT IS NOT: it owns NO domain truth, submits NO command, draws NO RNG (ZERO randi/randf/RandomNumberGenerator),
# emits NO event, and mutates nothing. It is NOT a scene/Control/.tscn (the outpost screen + the button wiring + the
# next_destination navigation are a later HUD/boot-flow story; UI-scene-last). It is NOT a save snapshot (DERIVED on
# demand, NOT persisted; it adds NO ProfileSnapshot/RunSnapshot key — the profile stays SCHEMA_VERSION 1). It does NOT
# award Oath Shards / merge unlocks / record the first-death flag / build the unlock-spend tree (deferred). It does NOT
# re-project the class roster (delegates to HeroSelectViewModel), re-dedup notable_loot (single-sourced by 8.2), or
# re-evaluate unlock thresholds (the merge command owns the flip; the outpost DISPLAYS the recorded progress).

const FirstDeathNarrativeBeat = preload("res://scripts/run/first_death_narrative_beat.gd")
const FirstVictoryRevealBeat = preload("res://scripts/run/first_victory_reveal_beat.gd")
const HeroSelectViewModel = preload("res://scripts/ui/view_models/hero_select_view_model.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

# The EXACT top-level key set of every projection (the RunSummary.DICTIONARY_KEYS / HeroSelectViewModel exact-key
# discipline — a key never silently appears/vanishes; the set is pinned by test_outpost_view_model.gd). has_profile is
# the AC4 fail-closed gate (false for a fresh/recovery surface); recovery_state carries the AC4 structured recovery. The
# run_summary / first_death_beat sub-dicts carry their OWN has_summary / has_beat gates (fail-closed within).
const DICTIONARY_KEYS: Array[String] = [
	"has_profile",
	"recovery_state",
	"oath_shards",
	"echoes",
	"unlock_progress",
	"class_mastery",
	"first_death_recorded",
	"run_summary",
	"class_options",
	"selectable_class_ids",
	"named_spaces",
	"first_death_beat",
	"first_victory_beat",
	"can_start_run"
]

# The EXACT key set of the recovery_state sub-dict (AC4). has_recovery gates whether a recovery is active (false for a
# healthy real/fresh profile); code is the structured recovery code (e.g. unsupported_profile_schema / a profile_save_*
# code) or "" when none; is_recoverable marks whether a fresh-profile fallback / retry recovers it (always true in v0 —
# every recovery path has a fresh-profile or retry affordance). Pinned by test.
const RECOVERY_STATE_KEYS: Array[String] = [
	"has_recovery",
	"code",
	"is_recoverable"
]

# The EXACT per-entry key set of a named-space metadata entry (AC2). Pinned by test. space_id is a STABLE lower_snake id;
# display_name is the GDD display string; status is `deferred` in v0 (no interactive content); maps_to is a note on what
# the space maps to (Echoes/codex, Oath Shards/mastery, Seal Fragments/unlock progress, start-another-descent).
const NAMED_SPACE_KEYS: Array[String] = [
	"space_id",
	"display_name",
	"status",
	"maps_to"
]

# The v0 named-space status marker (AC2 — the visible-exception-marker discipline from Epic 6/7: an unfinished surface is
# EXPLICITLY marked deferred, never silently omitted). NO named space has interactive content in v0.
const NAMED_SPACE_STATUS_DEFERRED := "deferred"

# The four GDD outpost named spaces (gdd.md line 271 — "Meta spaces: Memory Archive, Hall of Oaths, Seal Table, Gate or
# Descent Stair"), the fixed v0 set with STABLE lower_snake ids. This is DATA only (drives no domain state, gates no run,
# holds no truth — AC2 "without making UI state authoritative"). The exact outpost LAYOUT + the unlock-tree/menu SHAPE
# are explicitly deferred (gdd.md line 710); this supplies stable ids + display strings + deferred markers + maps_to
# notes, NOT a final layout. Do NOT invent additional spaces. The descent_stair maps to the AC3 start-another-descent
# action (the only space with a live affordance in v0); the other three are display/deferred placeholders.
const NAMED_SPACES: Array[Dictionary] = [
	{
		"space_id": "memory_archive",
		"display_name": "Memory Archive",
		"status": "deferred",
		"maps_to": "echoes_and_codex"
	},
	{
		"space_id": "hall_of_oaths",
		"display_name": "Hall of Oaths",
		"status": "deferred",
		"maps_to": "oath_shards_and_class_mastery"
	},
	{
		"space_id": "seal_table",
		"display_name": "Seal Table",
		"status": "deferred",
		"maps_to": "seal_fragments_and_unlock_progress"
	},
	{
		"space_id": "descent_stair",
		"display_name": "Gate or Descent Stair",
		"status": "deferred",
		"maps_to": "start_another_descent"
	}
]

# The EXACT key set of a start_run_request(...) result (AC3). Pinned by test. root_seed is the decimal-string-encoded
# int64 seed (JSON doubles truncate beyond 2^53 — the epic-wide root_seed rule); is_manual_seed is the seed-eligibility
# flag (a manual-seed start -> meta_progression_eligible == false via the existing lockstep); class_id is the selected
# class (lower_snake String; "" is the legacy no-class start); is_startable is the fail-closed pre-gate result — whether
# the request can actually start a run (an empty class id is a STARTABLE no-class request even though it is not
# "selectable" per HeroSelectViewModel; a non-empty class must pass the selectable pre-gate).
const START_REQUEST_KEYS: Array[String] = [
	"root_seed",
	"is_manual_seed",
	"class_id",
	"is_startable"
]

# Whether the outpost was built from a REAL loaded profile (true) or a FRESH/recovery profile (false) — the AC4
# fail-closed gate. A fresh-profile surface (profile_not_found recovery) is still VALID (0 Oath Shards, empty homes); a
# consumer reads has_profile to tell "returning player with saved progress" from "brand-new / recovered player".
var has_profile: bool = false
# The AWARDED cross-run Oath-Shard total (== profile.oath_shards). 0 for a fresh/recovery profile (AC4 — no unintended
# progress). Read from the PROFILE (source truth), NOT the run summary (whose oath_shards_earned stays 0/not-yet-supported).
var oath_shards: int = 0
# The discovered Echo ids (== profile.echoes). Empty for a fresh/recovery profile.
var echoes: Array[String] = []
# The unlock-progress record (== profile.unlock_progress, incl. the Seal-Fragment set + threshold state flags +
# _last_merged_run_seed). Empty for a fresh/recovery profile. DISPLAYED (the merge command owns the threshold flip; the
# outpost does NOT re-evaluate thresholds).
var unlock_progress: Dictionary = {}
# The class-mastery record (== profile.class_mastery). Empty for a fresh/recovery profile.
var class_mastery: Dictionary = {}
# The first-death latch (== profile.first_death_recorded). false for a fresh/recovery profile.
var first_death_recorded: bool = false
# The AC4 structured recovery state {has_recovery, code, is_recoverable}. has_recovery == false for a healthy real/fresh
# profile; a recovery surface (unsupported_profile_schema / a profile_save_* write failure) carries the structured code.
var recovery_state: Dictionary = {}
# The just-ended run's RunSummary (or the fail-closed empty summary when no run just ended). Its OWN has_summary gate
# distinguishes them. Rendered DIRECTLY (notable_loot single-sourced/deduped; not_yet_supported the honest note).
var _run_summary: RunSummary = null
# The (OPTIONAL) first-death narrative beat (or the fail-closed empty beat). Its OWN has_beat gate distinguishes them.
var _first_death_beat: FirstDeathNarrativeBeat = null
# Story 11.5 (AC2 first-victory decision — Option A, the minimal first-death-symmetric embed): the (OPTIONAL) first-
# victory reveal beat (or the fail-closed empty beat). The 9.4 AC3 render [Decision] deferred wiring the first-victory
# reveal onto OutpostViewModel to "a later UI story" = 11.5; this resolves it by embedding the beat alongside
# _first_death_beat (both ride beside run_summary, symmetric). Its OWN has_beat gate distinguishes present/absent. The
# DISMISS is a PURE PRESENTATION NO-OP (the flag was set independently by 9.4's RecordFirstVictoryCommand; the DTO is
# read-only). OFF THE CRITICAL PATH — a null/absent beat never blocks the outpost surface (FR64).
var _first_victory_beat: FirstVictoryRevealBeat = null
# The composed class-options roster projection (5.2). DELEGATED to for the class roster + the fail-closed selectable
# pre-gate (the AC3 start-run gate). The roster is NOT re-projected here.
var _hero_select: HeroSelectViewModel = null

func _init(
	profile: ProfileSnapshot = null,
	run_summary: RunSummary = null,
	first_death_beat: FirstDeathNarrativeBeat = null,
	first_victory_beat: FirstVictoryRevealBeat = null,
	class_repository: ClassRepository = null,
	new_recovery_state: Dictionary = {}
) -> void:
	# AC4: a null/absent profile projects the FRESH-PROFILE default (ProfileSnapshot.fresh() — the profile_not_found
	# recovery path). has_profile distinguishes a real profile from a fresh one. A supplied profile is read verbatim as
	# source truth (never mutated). A supplied recovery_state (from for_recovery(...)) marks the incompatible/write-failure
	# path; otherwise a healthy no-recovery state is projected.
	var resolved_profile: ProfileSnapshot = profile if profile != null else ProfileSnapshot.fresh()
	has_profile = profile != null

	# Read the cross-run meta from the PROFILE (source truth — AC1). Deep-copy the sub-dicts/lists so the view model never
	# leaks a live handle into the profile (a mutation of a returned field never perturbs the profile).
	oath_shards = resolved_profile.oath_shards
	echoes = resolved_profile.echoes.duplicate()
	unlock_progress = resolved_profile.unlock_progress.duplicate(true)
	class_mastery = resolved_profile.class_mastery.duplicate(true)
	first_death_recorded = resolved_profile.first_death_recorded

	# AC4: the structured recovery state. A supplied recovery_state (for_recovery) is normalized to the pinned shape; an
	# empty one is the healthy no-recovery state.
	recovery_state = _normalize_recovery_state(new_recovery_state)

	# AC1: the OPTIONAL just-ended run summary (or the fail-closed empty summary when no run just ended — a fresh session).
	# RunSummary.build(null) yields the empty summary (has_summary == false), so a null arg projects a valid empty surface.
	_run_summary = run_summary if run_summary != null else RunSummary.build(null)

	# AC1 render / the 8.5 hand-off: the OPTIONAL first-death beat (or the fail-closed empty beat when none). The beat is
	# OFF THE CRITICAL PATH (a null/absent beat never blocks the outpost surface).
	_first_death_beat = first_death_beat if first_death_beat != null else FirstDeathNarrativeBeat.for_first_death(&"")

	# Story 11.5 (AC2 render / the 9.4 hand-off): the OPTIONAL first-victory reveal beat (or the fail-closed empty beat
	# when none — for_first_victory(&"") yields has_beat == false). The beat is OFF THE CRITICAL PATH (a null/absent beat
	# never blocks the outpost surface — FR64), symmetric with _first_death_beat.
	_first_victory_beat = first_victory_beat if first_victory_beat != null else FirstVictoryRevealBeat.for_first_victory(&"")

	# AC1: the class-options roster is DELEGATED to a composed HeroSelectViewModel (the same class repository the caller's
	# start seam uses; baseline default — the HeroSelectViewModel / RunStartCommand injection posture). The roster is NOT
	# re-projected here.
	_hero_select = HeroSelectViewModel.new(class_repository)


# AC4: build an outpost surface in a STRUCTURED RECOVERY state. This correctly represents BOTH recovery failure modes:
#   - PROFILE-LOAD failure (profile_not_found / unsupported_profile_schema): there is NO valid loaded profile, so
#     loaded_profile stays null and the surface falls back to ProfileSnapshot.fresh() (0 Oath Shards, empty homes —
#     has_profile == false). A fresh 0-shard surface is the honest recovery representation (no real totals exist to show).
#   - PROFILE-WRITE failure (profile_save_* codes): the profile was successfully READ and the player accumulated REAL
#     progress THIS session; only the WRITE failed. The caller holds the intact loaded profile and passes it as
#     loaded_profile so the surface shows the player's REAL Oath-Shard / Echoes / unlock totals BEHIND the retry banner
#     (has_profile == true) — NOT a misleading 0-shard surface. recovery_state still carries the structured write-failure
#     code + is_recoverable == true (the retry affordance).
# In BOTH modes recovery_state {has_recovery, code, is_recoverable} is populated, there is NO crash, and NO invalid meta
# state is created. Draws NO RNG, mutates NOTHING (the supplied loaded_profile is read verbatim as source truth).
static func for_recovery(
	recovery_code: StringName,
	loaded_profile: ProfileSnapshot = null,
	run_summary: RunSummary = null,
	first_death_beat: FirstDeathNarrativeBeat = null,
	class_repository: ClassRepository = null,
	is_recoverable: bool = true,
	first_victory_beat: FirstVictoryRevealBeat = null
) -> OutpostViewModel:
	# Story 11.5: first_victory_beat is a TRAILING optional arg so the EXISTING for_recovery(...) call sites (which never
	# passed a victory beat) stay byte-identical; a write-failure recovery after a live VICTORY passes the beat so the
	# reveal still renders behind the retry banner (a load-failure fresh recovery leaves it null -> the empty beat).
	return load("res://scripts/ui/view_models/outpost_view_model.gd").new(
		loaded_profile,
		run_summary,
		first_death_beat,
		first_victory_beat,
		class_repository,
		{
			"has_recovery": true,
			"code": String(recovery_code),
			"is_recoverable": is_recoverable
		}
	)


# AC1: the class-options roster (DELEGATED to HeroSelectViewModel — the 5.2 projection). Per-class
# {class_id, display_name, selectable, unlock_hint} in ClassRepository.class_ids() order.
func class_options() -> Array:
	return _hero_select.classes()


# AC3 pre-gate: is this class id selectable RIGHT NOW (DELEGATED to HeroSelectViewModel — fail-closed: unknown -> false,
# locked -> false, selectable -> true). The AUTHORITATIVE gate is still RunStartCommand's class validation.
func is_class_selectable(query_class_id: StringName) -> bool:
	return _hero_select.is_class_selectable(query_class_id)


# AC3 start-run affordance: the selectable class ids (the playable roster) in class_ids() order, as plain Strings. Both
# this accessor AND the to_dictionary() "selectable_class_ids" key return the SAME element type (Array[String]) — the
# codebase idiom that dictionary projections are JSON-safe plain Strings (HeroSelectViewModel.classes() emits
# String(class_id)). HeroSelectViewModel.selectable_class_ids() returns the in-engine StringName partition; this
# converts at the boundary so a consumer reading either surface gets a String (no StringName/String type trap).
func selectable_class_ids() -> Array[String]:
	var ids: Array[String] = []
	for class_id: StringName in _hero_select.selectable_class_ids():
		ids.append(String(class_id))
	return ids


# AC2: the named-space metadata (the four fixed GDD spaces with stable lower_snake ids + display + deferred markers +
# maps_to notes). A FRESH deep copy each call so a mutation of a returned entry never perturbs the const registry. DATA
# only — drives no domain state, gates no run, holds no truth.
func named_spaces() -> Array[Dictionary]:
	var spaces: Array[Dictionary] = []
	for space: Dictionary in NAMED_SPACES:
		spaces.append(space.duplicate(true))
	return spaces


# The just-ended run summary sub-dict (or the fail-closed empty summary). A FRESH deep copy (RunSummary.to_dictionary()
# already returns a fresh dict with deep-copied sub-dicts/lists).
func run_summary() -> Dictionary:
	return _run_summary.to_dictionary()


# The first-death narrative beat sub-dict (or the fail-closed empty beat). A FRESH dict (FirstDeathNarrativeBeat
# .to_dictionary() already returns a fresh dict).
func first_death_beat() -> Dictionary:
	return _first_death_beat.to_dictionary()


# Story 11.5 (AC2): the first-victory reveal beat sub-dict (or the fail-closed empty beat). A FRESH dict
# (FirstVictoryRevealBeat.to_dictionary() already returns a fresh dict). Symmetric with first_death_beat().
func first_victory_beat() -> Dictionary:
	return _first_victory_beat.to_dictionary()


# AC3 start-run affordance: whether a start is possible RIGHT NOW (there is at least one selectable class OR an empty
# no-class start is always available). In the baseline there is always at least one selectable class, so this is true;
# an empty-repository outpost still permits the legacy no-class start (start_run_request(&"") is startable), so a start
# is ALWAYS possible in v0. Reported as a convenience affordance flag.
func can_start_run() -> bool:
	return true


# AC3: produce a START-ANOTHER-DESCENT request ([Decision] A — a REQUEST value, NOT a live start). Validates the class
# via the fail-closed HeroSelectViewModel.is_class_selectable pre-gate (a locked/unknown class -> a NOT-startable
# request; an EMPTY class id is the legacy no-class start, which IS startable). The CALLER hands the request to a FRESH
# RunOrchestrator.start(root_seed, is_manual_seed, class_id) — the view model does NOT call start(...) (do not let UI
# mutate domain state; the prior run is NOT reused BY CONSTRUCTION via RunState.new_run). The seed-eligibility
# is_manual_seed flag is carried into the request (a manual-seed start -> meta_progression_eligible == false via the
# existing lockstep — 8.6 does NOT change the FR28 eligibility model). Draws NO RNG, mutates NOTHING. root_seed is the
# decimal-string-encoded int64 (JSON doubles truncate beyond 2^53).
func start_run_request(request_root_seed: int, request_is_manual_seed: bool = false, request_class_id: StringName = &"") -> Dictionary:
	# An EMPTY class id is the legacy no-class start (startable — the RunStartCommand back-compat path). A NON-empty class
	# id must pass the fail-closed selectable pre-gate. So the request is startable iff the class is empty OR selectable.
	var class_is_startable: bool = request_class_id.is_empty() or is_class_selectable(request_class_id)
	return {
		# root_seed is a full int64 -> decimal-string encoded (the epic-wide root_seed JSON-doubles rule).
		"root_seed": str(request_root_seed),
		"is_manual_seed": request_is_manual_seed,
		"class_id": String(request_class_id),
		"is_startable": class_is_startable
	}


# Exact-key projection (the RunSummary / HeroSelectViewModel exact-key discipline): plain String/bool/int/Array/Dictionary
# data only (no live ProfileSnapshot / RunSummary / FirstDeathNarrativeBeat / HeroSelectViewModel handle leaks out). A
# FRESH dictionary each call (with deep-copied sub-dicts/lists) so a mutation of the returned dict never perturbs this DTO
# or the profile/summary/beat it aggregates. PURE read. oath_shards is a small bounded count (plain numeric); the profile
# meta / run summary / named spaces / class roster / first-death beat ride as sub-structures.
func to_dictionary() -> Dictionary:
	return {
		"has_profile": has_profile,
		"recovery_state": recovery_state.duplicate(true),
		"oath_shards": oath_shards,
		"echoes": echoes.duplicate(),
		"unlock_progress": unlock_progress.duplicate(true),
		"class_mastery": class_mastery.duplicate(true),
		"first_death_recorded": first_death_recorded,
		"run_summary": _run_summary.to_dictionary(),
		"class_options": _hero_select.classes(),
		"selectable_class_ids": selectable_class_ids(),
		"named_spaces": named_spaces(),
		"first_death_beat": _first_death_beat.to_dictionary(),
		"first_victory_beat": _first_victory_beat.to_dictionary(),
		"can_start_run": can_start_run()
	}


# Normalize a supplied recovery_state to the pinned RECOVERY_STATE_KEYS shape (a lenient decode — a missing/invalid field
# defaults cleanly). An empty dict -> the healthy no-recovery state (has_recovery == false, code "", is_recoverable
# false — nothing to recover). Deep-copied so the view model never shares the caller's dict by reference. for_recovery
# supplies the has_recovery/code/is_recoverable fields explicitly for the incompatible/write-failure path.
func _normalize_recovery_state(raw: Dictionary) -> Dictionary:
	return {
		"has_recovery": bool(raw.get("has_recovery", false)),
		"code": String(raw.get("code", "")),
		"is_recoverable": bool(raw.get("is_recoverable", false))
	}
