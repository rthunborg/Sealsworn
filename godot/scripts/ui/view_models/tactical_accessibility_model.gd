class_name TacticalAccessibilityModel
extends RefCounted

## Scene-free accessibility / tactical-readability contract for the tactical HUD.
##
## Story 2.6: this helper formalizes the semantic cue-id vocabulary already emitted by Epic 2
## (movement preview, attack preview, inspect, commit flow, layout) into an auditable
## accessibility contract that guarantees every critical tactical meaning is communicated
## without relying on color alone (AC1). It adds the net-new preview-vs-committed distinction
## (feedback_preview / feedback_committed) with non-color visual channels and parallel optional
## audio cue ids that always carry a visual/textual equivalent so the distinction survives with
## audio muted or unavailable (AC3). It hosts the scalable-text bounds contract via
## TacticalTextScale (AC2).
##
## This is a presentation contract only. It is NOT save truth, NOT domain state, NOT tactical
## legality, and NOT a settings store. It never executes commands, never consumes gameplay RNG,
## never reaches into the command bridge, and never mutates tactical truth. Audio is represented
## as stable string cue ids only; no AudioStreamPlayer / AudioManager wiring is added here.
##
## Value sanitization is routed through TacticalPreviewView.safe_* (the shared helper) so this
## model does NOT add a fourth duplicate sanitizer.

const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

const KIND := "accessibility"

# Stable non-color channel ids. AC1 requires at least one of these per critical meaning.
const CHANNEL_SHAPE := "shape"
const CHANNEL_ICON := "icon"
const CHANNEL_LABEL := "label"
const CHANNEL_PATTERN := "pattern"
const CHANNEL_TEXT := "text"

# Stable severity ids. A presenter MAY map a severity to a color, but it is additive: it is
# never the sole signal because every critical cue also carries a non-color channel above.
const SEVERITY_INFO := "info"
const SEVERITY_WARNING := "warning"
const SEVERITY_BLOCKED := "blocked"
const SEVERITY_DANGER := "danger"

# Net-new preview-vs-committed feedback cue ids (AC3).
const CUE_FEEDBACK_PREVIEW := "feedback_preview"
const CUE_FEEDBACK_COMMITTED := "feedback_committed"
const AUDIO_FEEDBACK_PREVIEW := "audio_feedback_preview"
const AUDIO_FEEDBACK_COMMITTED := "audio_feedback_committed"

const REASON_VALID := "valid"

## Authoritative cue catalog. The keys are the EXACT cue-id strings already emitted by
## TacticalMovementPreview, TacticalAttackPreview, TacticalInspectView, and
## TacticalAttackCommitFlow (do not rename them), plus the two net-new feedback cues.
## Each entry declares the required redundant non-color channels and a severity. The two
## feedback cues additionally declare a parallel optional audio cue id; both still carry a
## non-color channel so the meaning survives with audio absent.
const _CUE_CATALOG: Dictionary = {
	# Movement validity.
	"move_preview_valid": {"channels": [CHANNEL_SHAPE, CHANNEL_LABEL], "severity": SEVERITY_INFO},
	"move_preview_invalid": {"channels": [CHANNEL_SHAPE, CHANNEL_LABEL], "severity": SEVERITY_BLOCKED},
	# Attack legality / range.
	"attack_preview_valid": {"channels": [CHANNEL_ICON, CHANNEL_LABEL], "severity": SEVERITY_INFO},
	"attack_preview_invalid": {"channels": [CHANNEL_ICON, CHANNEL_LABEL], "severity": SEVERITY_BLOCKED},
	# Blocked line.
	"attack_preview_blocked_line": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_BLOCKED},
	# Blocker ignored / override.
	"attack_preview_blocker_ignored": {"channels": [CHANNEL_ICON, CHANNEL_TEXT], "severity": SEVERITY_INFO},
	# Adjacency warning.
	"attack_preview_adjacent_warning": {"channels": [CHANNEL_ICON, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_WARNING},
	# Telegraphed danger.
	"telegraph_pending": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL], "severity": SEVERITY_WARNING},
	"telegraph_due": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_DANGER},
	"danger_damage": {"channels": [CHANNEL_ICON, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_DANGER},
	# Story 7.5 — affinity tactical-effect danger cues (FR57). Each carries a non-color channel so the affinity's
	# critical danger information is NOT color-only (AC2 + the Epic-2 color-independence contract). The Scorched
	# hazard + Flooded pathing cues are FINAL ids; the conductive-danger cue is a TRACKED MVP PLACEHOLDER (AC4) — its
	# id carries the `_placeholder` marker (distinct-from-final) and a shape channel so the placeholder danger still
	# reads with color stripped. (Authored as a board-effect cue vocabulary, not a difficulty knob.)
	"affinity_scorched_hazard": {"channels": [CHANNEL_ICON, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_DANGER},
	"affinity_conductive_danger_placeholder": {"channels": [CHANNEL_SHAPE, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_DANGER},
	"affinity_pathing_pressure": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL], "severity": SEVERITY_WARNING},
	# Story 7.6 — Darkness affinity visibility/memory-pressure cues (FR58). Darkness's reduced-visibility + uncertain-
	# memory state is CRITICAL tactical information, so each cue carries a NON-COLOR channel (AC2 + NFR9 + the Epic-2 +
	# 7.5 color-independence contract). These are FINAL ids (Darkness is fully realized — NOT a tracked placeholder).
	# reduced_visibility uses icon+label+text (the shrunk sight radius is shown as an icon/label, not a colour); the
	# memory-uncertainty cue uses a dashed/stale pattern + label + text so a stale-memory cell reads with colour stripped.
	"affinity_darkness_reduced_visibility": {"channels": [CHANNEL_ICON, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_WARNING},
	"affinity_darkness_memory_uncertain": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_WARNING},
	# Inspect visibility tiers.
	"inspect_visible": {"channels": [CHANNEL_LABEL], "severity": SEVERITY_INFO},
	"inspect_memory": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL], "severity": SEVERITY_INFO},
	"inspect_hidden_unexplored": {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL], "severity": SEVERITY_INFO},
	# Commit availability.
	"commit_available": {"channels": [CHANNEL_LABEL], "severity": SEVERITY_INFO},
	"commit_unavailable": {"channels": [CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_BLOCKED},
	# Net-new preview-vs-committed distinction. The channel sets intentionally differ so a
	# player can tell a previewed action from a committed one with color stripped: preview uses
	# a dashed/outline shape + label, committed adds a solid pattern + confirming text.
	CUE_FEEDBACK_PREVIEW: {"channels": [CHANNEL_SHAPE, CHANNEL_LABEL], "severity": SEVERITY_INFO, "audio_cue_id": AUDIO_FEEDBACK_PREVIEW},
	CUE_FEEDBACK_COMMITTED: {"channels": [CHANNEL_PATTERN, CHANNEL_LABEL, CHANNEL_TEXT], "severity": SEVERITY_INFO, "audio_cue_id": AUDIO_FEEDBACK_COMMITTED}
}

var _available: bool = true
var _reason: String = REASON_VALID
var _cues: Dictionary = {}
var _feedback: Dictionary = {}
var _text_scale: Dictionary = {}
var _cue_ids: Array[String] = []

func to_dictionary() -> Dictionary:
	return {
		"kind": KIND,
		"color_independent": true,
		"available": _available,
		"reason": _reason,
		"cues": _cues.duplicate(true),
		"feedback": _feedback.duplicate(true),
		"text_scale": _text_scale.duplicate(true),
		"cue_ids": _cue_ids.duplicate()
	}


## Build the accessibility envelope from optional presentation inputs. All inputs are read-only:
## - text_scale: a requested numeric text scale (clamped via TacticalTextScale).
## - audio_available: bool, defaults true; when false the feedback slot marks audio unavailable
##   but keeps its visual/textual channels so the distinction still holds.
## - preview / commit_flow / commit_result: read-only sources used to derive feedback state.
static func from_state(options: Dictionary = {}) -> TacticalAccessibilityModel:
	var model: TacticalAccessibilityModel = load("res://scripts/ui/view_models/tactical_accessibility_model.gd").new()
	model._cues = _build_cue_catalog()
	model._text_scale = TacticalTextScale.from_value(TacticalPreviewView.field(options, &"text_scale", TacticalTextScale.DEFAULT_TEXT_SCALE)).to_dictionary()

	var audio_available: bool = _audio_available_from_options(options)
	var preview_active: bool = _preview_active_from_options(options)
	var committed_active: bool = _committed_active_from_options(options)
	model._feedback = _build_feedback(preview_active, committed_active, audio_available)
	model._cue_ids = _build_cue_ids(preview_active, committed_active)
	model._available = true
	model._reason = REASON_VALID
	return model


## Static audit helper: the registered non-color channels for a cue id, or [] if unmapped.
static func channels_for_cue(cue_id: String) -> Array[String]:
	if not _CUE_CATALOG.has(cue_id):
		return []
	var result: Array[String] = []
	for channel_value: Variant in (_CUE_CATALOG[cue_id] as Dictionary).get("channels", []):
		result.append(String(channel_value))
	return result


## Static audit helper: true if the cue id is registered with at least one non-color channel.
static func has_non_color_channel(cue_id: String) -> bool:
	return not channels_for_cue(cue_id).is_empty()


static func _build_cue_catalog() -> Dictionary:
	# Deep value-only copy so callers can never mutate the shared const catalog.
	var result: Dictionary = {}
	for cue_id: Variant in _CUE_CATALOG.keys():
		var entry: Dictionary = _CUE_CATALOG[cue_id]
		var copied: Dictionary = {
			"channels": _string_array(entry.get("channels", [])),
			"severity": String(entry.get("severity", SEVERITY_INFO))
		}
		if entry.has("audio_cue_id"):
			copied["audio_cue_id"] = String(entry.get("audio_cue_id", ""))
		result[String(cue_id)] = copied
	return result


static func _build_feedback(preview_active: bool, committed_active: bool, audio_available: bool) -> Dictionary:
	return {
		"audio_available": audio_available,
		"preview": _feedback_entry(CUE_FEEDBACK_PREVIEW, AUDIO_FEEDBACK_PREVIEW, preview_active, audio_available),
		"committed": _feedback_entry(CUE_FEEDBACK_COMMITTED, AUDIO_FEEDBACK_COMMITTED, committed_active, audio_available)
	}


static func _feedback_entry(cue_id: String, audio_cue_id: String, active: bool, audio_available: bool) -> Dictionary:
	var channels: Array[String] = channels_for_cue(cue_id)
	return {
		"cue_id": cue_id,
		"audio_cue_id": audio_cue_id,
		"channels": channels,
		# The visual/textual channel is always available; this is the guarantee that the
		# preview-vs-committed distinction survives with audio muted or absent (AC3).
		"visual_available": not channels.is_empty(),
		"audio_available": audio_available,
		"active": active
	}


static func _build_cue_ids(preview_active: bool, committed_active: bool) -> Array[String]:
	var result: Array[String] = []
	if preview_active:
		result.append(CUE_FEEDBACK_PREVIEW)
	if committed_active:
		result.append(CUE_FEEDBACK_COMMITTED)
	return result


static func _audio_available_from_options(options: Dictionary) -> bool:
	var value: Variant = TacticalPreviewView.field(options, &"audio_available", true)
	if typeof(value) == TYPE_BOOL:
		return value
	return true


## feedback_preview is active when an attack preview is currently pending: either an explicit
## active preview dictionary, or a commit flow in attack_preview mode.
static func _preview_active_from_options(options: Dictionary) -> bool:
	var commit_flow_value: Variant = TacticalPreviewView.field(options, &"commit_flow", {})
	if commit_flow_value is Dictionary:
		if String((commit_flow_value as Dictionary).get("mode", "none")) == "attack_preview":
			return true
	var preview_value: Variant = TacticalPreviewView.field(options, &"preview", {})
	if preview_value is Dictionary:
		var preview: Dictionary = preview_value
		if not preview.is_empty() and String(preview.get("kind", "")) == "attack" and bool(preview.get("commit_available", false)):
			return true
	return false


## feedback_committed is active when a successful committed attack result is supplied. The
## source is a TacticalAttackCommitFlowResult dictionary (submitted == true and the command
## summary succeeded). This reads a result; it never executes a command.
static func _committed_active_from_options(options: Dictionary) -> bool:
	var result_value: Variant = TacticalPreviewView.field(options, &"commit_result", {})
	if not result_value is Dictionary:
		return false
	var commit_result: Dictionary = result_value
	if not bool(commit_result.get("submitted", false)):
		return false
	var summary_value: Variant = commit_result.get("command_result_summary", {})
	if summary_value is Dictionary:
		return bool((summary_value as Dictionary).get("succeeded", false))
	return false


static func _string_array(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if not source is Array:
		return result
	for item: Variant in source:
		result.append(String(item))
	return result
