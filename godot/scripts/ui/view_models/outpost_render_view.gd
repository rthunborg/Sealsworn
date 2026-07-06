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
