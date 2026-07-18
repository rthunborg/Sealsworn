class_name OutpostRenderView
extends RefCounted

# Story 11.5 (AC1/AC2/AC3/AC4) — the scene-free OUTPOST RENDER-DECISION seam: the pure-read RefCounted projection the
# outpost_presenter reads to decide WHAT to render, so the RENDER LOGIC (the recovery-mode branch, the manual-seed
# warning, the reveal-beat presence, the deferred-space markers, the meta readout, the summary gate) is UNIT-TESTABLE by
# the scene-free harness (which has NO SceneTree — the retro G1/G2 posture: steer ALL testable logic into a fail-closed
# RefCounted view-model/projection seam; the .tscn/Control is verified BY CONSTRUCTION via the scene-load compile
# guardrail + the read-only-projection discipline). The presenter MAPS these decisions to Control nodes; it invents no
# render vocabulary + owns no truth.
#
# ⭐ IT IS A PURE READ over the OutpostViewModel.to_dictionary() projection (the pinned DICTIONARY_KEYS). It draws ZERO
# RNG, submits NO command, emits NO event, and mutates NOTHING (the resume-invariant discipline, mirrored on the profile
# side — the recovery render consumes no RNG, runs no command, mutates nothing). It leaks no live handle (it reads the
# already-serialized dict). Every meaning it surfaces carries a NON-COLOR channel (text/icon/label — the appendix §14
# color-independence rule): the recovery mode reads differently by text+icon ("profile not found" vs "save failed —
# retry"), the manual-seed warning is a labeled banner (text+icon), the deferred spaces carry an explicit "deferred"
# marker (never silently omitted — the visible-exception discipline).
#
# ⭐ THE RECOVERY-MODE BRANCH (AC3): recovery_state.has_recovery gates whether a recovery surface renders. It distinguishes
# the TWO modes by the (code, has_profile) pair the bridge threads:
#   - LOAD failure  (recovery + has_profile == false): the fresh-fallback 0-shard surface + a recovery note (the profile
#     could not be read — a fresh 0-shard outpost; no real totals exist to show).
#   - WRITE failure (recovery + has_profile == true): the REAL totals (oath_shards/echoes/unlock) BEHIND a retry banner
#     (the profile was read fine + the player earned real progress this session; only the write failed — NOT a misleading
#     0-shard surface). The retry affordance re-attempts the write.
#
# ⭐ THE MANUAL-SEED WARNING (AC4, FR28): a READOUT of the EXISTING flags (no new field). The just-ended run's summary
# reports is_manual_seed / meta_progression_eligible (lockstep); when is_manual_seed is true the render surfaces a "manual
# seed — no meta progression earned" banner. A normal-seed run shows none.
#
# ⭐ THE REVEAL BEATS (AC2): each beat renders iff its has_beat gate is true (an absent beat is NOT rendered, nothing
# blocked). The Skip/Dismiss is STRUCTURALLY a no-op (this seam surfaces the beat DATA only; there is NO skip command —
# the latch was set by the record command independently). OFF THE CRITICAL PATH (FR64): the outpost surface + the start-
# descent affordance are COMPLETE without either beat.

const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
# Story 14.5 (AC2): the deterministic Oath-Shard award CALCULATOR (the earned-this-run count is a separate render-side
# read via its public consts, NOT a summary-key change — see run_oath_shards_earned()) + the RunState phase ids (the
# outcome label keys off the summary's terminal phase — D6). Read-only references; no domain/save file is touched.
const MetaAwardRules = preload("res://scripts/save/meta_award_rules.gd")
const RunState = preload("res://scripts/run/run_state.gd")

const RECOVERY_MODE_NONE := "none"
const RECOVERY_MODE_LOAD_FAILURE := "load_failure"
const RECOVERY_MODE_WRITE_FAILURE := "write_failure"

# The manual-seed no-progression warning line (FR28 — a labeled banner, text+icon; the icon is the presenter's, the text
# is here so the warning wording is centralized + testable).
const MANUAL_SEED_WARNING_LINE := "Manual seed — no meta progression earned."

# The recovery notes (text explanation per mode — the appendix §13.5 non-color channel so "profile not found" reads
# differently from "save failed — retry"). Keyed by mode. The presenter pairs each with a distinct icon.
const RECOVERY_NOTE_LOAD_FAILURE := "Your saved progress could not be loaded. Starting a fresh outpost."
const RECOVERY_NOTE_WRITE_FAILURE := "Your progress could not be saved this session. Your totals are shown; retry the save."

# Story 11.6 (AC1, FR59 — the shallow meta menu render decisions, centralized + testable per the retro G1/G2 posture).
# The spend can-afford/insufficient/applied states + the cost carry text+icon (a non-color channel — appendix §14): the
# affordable/insufficient state reads differently by label (not color), the applied state by an "Unlocked" marker, the
# cost by a number+label. The presenter maps these to Control tiles; it invents no spend render vocabulary.
const SPEND_STATE_APPLIED := "applied"          # already unlocked (the spend was made — the variety gate is open).
const SPEND_STATE_AFFORDABLE := "affordable"    # not yet unlocked, and the profile can afford the cost.
const SPEND_STATE_INSUFFICIENT := "insufficient"  # not yet unlocked, and the profile CANNOT afford the cost.

# The insufficient-shards message (a fail-loud non-color channel — never a silent no-op; appendix §14). The presenter
# pairs it with a distinct icon; the shortfall wording is centralized here so it is testable without a SceneTree.
const INSUFFICIENT_SHARDS_NOTE := "Not enough Oath Shards to unlock this yet."

# Story 14.5 (AC2, D6/F-2): the run-summary OUTCOME LABELS, keyed off the summary's terminal `phase` (NOT the live-blank
# outcome_or_cause). Reuses run_end_presenter.gd:58's Victory/Fallen vocabulary so the two run-end surfaces read
# consistently. Centralized + testable without a SceneTree; the presenter pairs each with a distinct non-color glyph.
const SUMMARY_OUTCOME_VICTORY := "Victory"
const SUMMARY_OUTCOME_DEATH := "Fallen"

# The projection this render view reads (OutpostViewModel.to_dictionary() — the pinned DICTIONARY_KEYS). A deep copy is
# stored so a mutation of a caller's dict never perturbs this seam's reads.
var _projection: Dictionary = {}

func _init(outpost_projection: Dictionary = {}) -> void:
	_projection = outpost_projection.duplicate(true)


# Build a render view directly from an OutpostViewModel (the convenience seam the presenter uses — it reads the model's
# projection once). A null model yields the fail-closed empty projection (every gate false).
static func from_view_model(view_model: RefCounted) -> OutpostRenderView:
	if view_model == null:
		return load("res://scripts/ui/view_models/outpost_render_view.gd").new({})
	return load("res://scripts/ui/view_models/outpost_render_view.gd").new(view_model.to_dictionary())


# AC3: the recovery mode (none / load_failure / write_failure). Fail-closed: no recovery -> none. A recovery WITH a loaded
# profile (has_profile == true) is the WRITE-failure real-totals-behind-retry mode; a recovery WITHOUT (has_profile ==
# false) is the LOAD-failure fresh-fallback mode. This is the branch the AC3 scene-level test asserts.
func recovery_mode() -> String:
	var recovery_state: Dictionary = _projection.get("recovery_state", {})
	if not bool(recovery_state.get("has_recovery", false)):
		return RECOVERY_MODE_NONE
	if bool(_projection.get("has_profile", false)):
		return RECOVERY_MODE_WRITE_FAILURE
	return RECOVERY_MODE_LOAD_FAILURE


# AC3: whether a recovery surface renders at all (a healthy real/fresh profile -> false).
func is_recovery() -> bool:
	return recovery_mode() != RECOVERY_MODE_NONE


# AC3: the structured recovery code (the diagnostic code behind the banner — e.g. profile_save_replace_failed /
# unsupported_profile_schema), or "" when no recovery.
func recovery_code() -> String:
	return String((_projection.get("recovery_state", {}) as Dictionary).get("code", ""))


# AC3: the text explanation for the active recovery mode (a non-color channel so the two modes read differently), or ""
# when no recovery.
func recovery_note() -> String:
	match recovery_mode():
		RECOVERY_MODE_LOAD_FAILURE:
			return RECOVERY_NOTE_LOAD_FAILURE
		RECOVERY_MODE_WRITE_FAILURE:
			return RECOVERY_NOTE_WRITE_FAILURE
		_:
			return ""


# AC3: whether the active recovery mode offers a RETRY affordance (the WRITE-failure real-totals mode retries the write; a
# LOAD-failure fresh fallback has no write to retry — the recovery is the fresh start itself). Only the write-failure mode
# retries; a load failure surfaces the note but the recover action IS the fresh outpost.
func has_retry_affordance() -> bool:
	if recovery_mode() != RECOVERY_MODE_WRITE_FAILURE:
		return false
	return bool((_projection.get("recovery_state", {}) as Dictionary).get("is_recoverable", false))


# AC4: whether the manual-seed no-progression warning renders (a READOUT of the just-ended run summary's is_manual_seed
# flag — no new field). True only when the summary is present AND the run used a manual seed (meta_progression_eligible is
# false in lockstep). A fresh session with no just-ended run (has_summary == false) shows none.
func shows_manual_seed_warning() -> bool:
	var summary: Dictionary = _projection.get("run_summary", {})
	if not bool(summary.get("has_summary", false)):
		return false
	return bool(summary.get("is_manual_seed", false))


# AC4: the manual-seed warning line (a labeled banner), or "" when no warning.
func manual_seed_warning_line() -> String:
	return MANUAL_SEED_WARNING_LINE if shows_manual_seed_warning() else ""


# AC4 (the G3 coupling — Option A, the honest as-is): the AWARDED Oath-Shard total is the PROFILE's (surfaced via
# OutpostViewModel.oath_shards). RunSummary.profile_meta.oath_shards_earned STAYS 0/not_yet_supported (the summary reads
# no profile). The presenter shows THIS at the outpost level as the awarded total.
func awarded_oath_shards() -> int:
	return int(_projection.get("oath_shards", 0))


# AC4 (the G3 coupling — Option A): the summary's oath_shards_earned field (STAYS 0 — the not_yet_supported placeholder).
# The presenter renders an honest "not yet tallied" note against this rather than a misleading number. Reads the summary
# sub-dict's profile_meta.oath_shards_earned verbatim (it is always 0 in v0; if the summary is absent -> 0).
func summary_oath_shards_earned() -> int:
	var summary: Dictionary = _projection.get("run_summary", {})
	var profile_meta: Dictionary = summary.get("profile_meta", {})
	return int(profile_meta.get("oath_shards_earned", 0))


# AC4 (the G3 coupling — Option A): whether the run summary's Oath-Shard-earned field is a NOT-YET-SUPPORTED placeholder
# (so the presenter shows the honest "not yet tallied" note instead of a real number). True when the summary names
# oath_shards_earned in its not_yet_supported list. A fresh session with no summary -> false (nothing to note).
func summary_oath_shards_not_yet_tallied() -> bool:
	var summary: Dictionary = _projection.get("run_summary", {})
	if not bool(summary.get("has_summary", false)):
		return false
	var not_yet_supported: Array = summary.get("not_yet_supported", [])
	return not_yet_supported.has("oath_shards_earned")


# AC1: whether a just-ended run summary renders (its own has_summary gate — a fresh session with no just-ended run shows
# "no just-ended run", not a zeroed sheet).
func shows_run_summary() -> bool:
	return bool((_projection.get("run_summary", {}) as Dictionary).get("has_summary", false))


# Story 14.5 (AC2, D6/F-2): the victory/death OUTCOME LABEL keyed off the summary's terminal `phase`. A COMPLETED run
# reads the victory label; a FAILED run reads the death label; an absent / non-terminal / unknown-phase summary reads ""
# (fail-closed — the presenter renders "No just-ended run." on the has_summary gate before it reaches here). It does NOT
# read outcome_or_cause (which is "" in the live flow — RunEndProfileBridge builds RunSummary.build(run, []) with an empty
# events list, so the terminal-event-derived marker never populates; `phase` is always the honest terminal fact).
func summary_outcome_label() -> String:
	var phase: String = _summary_phase()
	if phase == String(RunState.PHASE_COMPLETED):
		return SUMMARY_OUTCOME_VICTORY
	if phase == String(RunState.PHASE_FAILED):
		return SUMMARY_OUTCOME_DEATH
	return ""


# Story 14.5 (AC2): the nodes-cleared run signal (run_summary.run_scoped.nodes_cleared — a bounded route count, NOT a
# difficulty knob). 0 when absent (fail-closed).
func summary_nodes_cleared() -> int:
	var run_scoped: Dictionary = (_projection.get("run_summary", {}) as Dictionary).get("run_scoped", {})
	return int(run_scoped.get("nodes_cleared", 0))


# Story 14.5 (AC2): the run seed (run_summary.seed — already the decimal-string int64 the epic-wide root_seed rule uses;
# useful for FR27 replay/sharing). "" when the summary is absent (fail-closed). The has_summary gate is deliberate: the
# fail-closed EMPTY summary carries seed "0" (root_seed defaults to 0), which is ambiguous with a real seed-0 run — so an
# absent summary reads "" ("no just-ended run"), while a present summary reads its real seed (even "0").
func summary_seed() -> String:
	var summary: Dictionary = _projection.get("run_summary", {})
	if not bool(summary.get("has_summary", false)):
		return ""
	return String(summary.get("seed", ""))


# Story 14.5 (AC2): the honest OATH-SHARDS-EARNED-THIS-RUN count — a SEPARATE deterministic render-side read (NOT a
# summary-key change; RunSummary.profile_meta.oath_shards_earned STAYS 0/not_yet_supported). It is 0 unless the run
# COMPLETED (phase) AND is meta-eligible (a manual-seed run earns no meta — FR28); otherwise it is the SAME capped, sparse
# amount MetaAwardRules.oath_shard_award_for(run) would grant: clampi(BASE_AWARD + PER_NODE_AWARD * nodes_cleared, 0,
# MAX_AWARD). The MetaAwardRules consts are referenced so the NUMBERS are single-sourced (not hardcoded 1/1/5). A death or
# manual-seed run honestly earns 0. Pure read; draws ZERO RNG; touches NO domain/save file.
func run_oath_shards_earned() -> int:
	var summary: Dictionary = _projection.get("run_summary", {})
	var is_completed: bool = _summary_phase() == String(RunState.PHASE_COMPLETED)
	var is_eligible: bool = bool(summary.get("meta_progression_eligible", false))
	if not (is_completed and is_eligible):
		return 0
	var raw_award: int = MetaAwardRules.BASE_AWARD + MetaAwardRules.PER_NODE_AWARD * summary_nodes_cleared()
	return clampi(raw_award, 0, MetaAwardRules.MAX_AWARD)


# Story 14.5: the summary's terminal phase String (the projected run_summary.phase — "completed" / "failed", or "" for an
# absent / non-terminal summary). A private helper the outcome label + the earned-count gate read.
func _summary_phase() -> String:
	return String((_projection.get("run_summary", {}) as Dictionary).get("phase", ""))


# AC2: whether the first-death reveal beat renders (its own has_beat gate — an absent beat is not rendered, nothing
# blocked).
func shows_first_death_beat() -> bool:
	return bool((_projection.get("first_death_beat", {}) as Dictionary).get("has_beat", false))


# AC2: the resolved first-death reveal line (the FR61 prose — inherently non-color text), or "" when absent.
func first_death_line() -> String:
	return String((_projection.get("first_death_beat", {}) as Dictionary).get("line", ""))


# AC2: whether the first-victory reveal beat renders (its own has_beat gate).
func shows_first_victory_beat() -> bool:
	return bool((_projection.get("first_victory_beat", {}) as Dictionary).get("has_beat", false))


# AC2: the resolved first-victory reveal line (the FR62 prose), or "" when absent.
func first_victory_line() -> String:
	return String((_projection.get("first_victory_beat", {}) as Dictionary).get("line", ""))


# AC1/AC2 (the off-critical-path FR64 assertion): whether the START-ANOTHER-DESCENT affordance is available. It is
# ALWAYS available in v0 (can_start_run is true even on a fresh/recovery surface) — a null/absent/dismissed reveal beat
# NEVER blocks it, and a recovery surface can still start a fresh run. This is the seam the FR64 test reads to prove the
# outpost is COMPLETE without either beat.
func can_start_descent() -> bool:
	return bool(_projection.get("can_start_run", false))


# AC1: the four deferred named-space markers (each display_name + an EXPLICIT "deferred" marker — the visible-exception
# discipline, never silently omitted). A pure pass-through of the projection's named_spaces (already deep-copied). The
# presenter renders each as an icon/label tile with the deferred marker.
func named_space_markers() -> Array:
	var markers: Array = []
	for space_value: Variant in _projection.get("named_spaces", []):
		var space: Dictionary = space_value
		markers.append({
			"space_id": String(space.get("space_id", "")),
			"display_name": String(space.get("display_name", "")),
			"status": String(space.get("status", "")),
			"maps_to": String(space.get("maps_to", "")),
			# The deferred marker is EXPLICIT (a boolean the presenter maps to a "coming soon" icon/label — not color-only).
			"is_deferred": String(space.get("status", "")) == "deferred"
		})
	return markers


# AC1 (FR59 — the shallow meta menu): the spendable class-unlock options each as a render dict the presenter maps to a
# spend tile. PURE read over the projection's oath_shards (affordability) + unlock_progress (applied state) + the
# MetaSpendRules cost/flag config. Each entry: {unlock_id, class_id, display_name, cost, state (applied/affordable/
# insufficient), is_applied, can_afford, shortfall}. The state + cost carry text+icon (non-color — appendix §14). The
# presenter renders a spend button (>=44x44) per entry, disabled when applied or unaffordable, labeled with the cost +
# the state. Ordered by the MetaSpendRules declaration order (necromancer, shadeblade). A class_repository is composed
# for the display name (baseline default — the OutpostViewModel / HeroSelectViewModel injection posture).
func class_unlock_options() -> Array:
	var available: int = awarded_oath_shards()
	var unlock_progress: Dictionary = _projection.get("unlock_progress", {})
	var repository: ClassRepository = ClassRepository.create_baseline_repository()
	var options: Array = []
	for unlock_id: String in MetaSpendRules.CLASS_UNLOCKS.keys():
		var class_id: String = MetaSpendRules.class_id_for_unlock(unlock_id)
		var cost: int = MetaSpendRules.class_unlock_cost(unlock_id)
		var flag_key: String = MetaSpendRules.class_unlock_flag_key(unlock_id)
		var is_applied: bool = bool(unlock_progress.get(flag_key, false))
		var can_afford: bool = available >= cost
		var state: String = SPEND_STATE_APPLIED if is_applied else (SPEND_STATE_AFFORDABLE if can_afford else SPEND_STATE_INSUFFICIENT)
		var definition: ClassDefinition = repository.get_class_definition(StringName(class_id))
		var display_name: String = definition.display_name if definition != null else class_id
		options.append({
			"unlock_id": unlock_id,
			"class_id": class_id,
			"display_name": display_name,
			"cost": cost,
			"state": state,
			"is_applied": is_applied,
			"can_afford": can_afford,
			"shortfall": maxi(0, cost - available)
		})
	return options


# AC1 (FR59): the spend affordance for a specific unlock (the presenter reads it when wiring a spend button — whether the
# button submits a spend or is disabled). Fail-closed: an unknown/applied/unaffordable unlock returns false. A spend is
# submittable iff the unlock is a declared class unlock, NOT already applied, AND affordable.
func can_spend_unlock(unlock_id: String) -> bool:
	if not MetaSpendRules.is_class_unlock(unlock_id):
		return false
	var unlock_progress: Dictionary = _projection.get("unlock_progress", {})
	if bool(unlock_progress.get(MetaSpendRules.class_unlock_flag_key(unlock_id), false)):
		return false
	return awarded_oath_shards() >= MetaSpendRules.class_unlock_cost(unlock_id)


# AC1 (FR59): whether ANY spendable class unlock is affordable-and-unapplied right now (the presenter reads it to decide
# whether the spend menu shows a live affordance or only "coming soon"/applied tiles). A convenience roll-up.
func has_affordable_unlock() -> bool:
	for option: Variant in class_unlock_options():
		if String((option as Dictionary).get("state", "")) == SPEND_STATE_AFFORDABLE:
			return true
	return false
