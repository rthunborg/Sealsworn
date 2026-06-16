class_name GenerationResult
extends RefCounted

# Structured success-or-error result for the procedural generation pipeline. Mirrors the
# ActionResult discipline (lower-snake codes, deep-copied metadata) but carries the extra
# failed_phase + payload slots that the architecture's GenerationResult requires.
#
# Named generation phases, in architecture order. This story only fires the `recipe` phase;
# Stories 3.2-3.6 emit layout..validation. The full vocabulary is fixed from story one so the
# result shape is stable.
const PHASE_ROUTE := &"route"
const PHASE_RECIPE := &"recipe"
const PHASE_LAYOUT := &"layout"
const PHASE_PATHING := &"pathing"
const PHASE_BLOCKERS := &"blockers"
const PHASE_HAZARDS := &"hazards"
const PHASE_ENEMIES := &"enemies"
const PHASE_REWARDS := &"rewards"
const PHASE_AFFINITY := &"affinity"
const PHASE_VALIDATION := &"validation"
const PHASE_FINALIZE := &"finalize"

var succeeded: bool = false
var error_code: StringName = &""
var failed_phase: StringName = &""
var reason: StringName = &""
# The request seed, string-encoded if persisted (full 64-bit seeds truncate as raw JSON numbers).
var seed: String = ""
var diagnostics: Dictionary = {}
# Final immutable level snapshot slot. LEFT EMPTY this story; Story 3.2 fills it with a
# converted/generated level payload.
var payload: Dictionary = {}

static func ok(new_payload: Dictionary = {}, new_diagnostics: Dictionary = {}) -> GenerationResult:
	var result: GenerationResult = load("res://scripts/generation/level/generation_result.gd").new()
	result.succeeded = true
	result.payload = new_payload.duplicate(true)
	result.diagnostics = new_diagnostics.duplicate(true)
	return result


static func error(new_failed_phase: StringName, new_error_code: StringName, new_reason: StringName, new_seed: String, new_diagnostics: Dictionary = {}) -> GenerationResult:
	var result: GenerationResult = load("res://scripts/generation/level/generation_result.gd").new()
	result.succeeded = false
	result.failed_phase = new_failed_phase
	if not is_known_phase(result.failed_phase):
		result.failed_phase = &"invalid_phase"
	result.error_code = new_error_code
	if not _is_valid_code(result.error_code):
		result.error_code = &"invalid_error_code"
	result.reason = new_reason
	if not _is_valid_code(result.reason):
		result.reason = &"invalid_reason"
	result.seed = new_seed
	result.diagnostics = new_diagnostics.duplicate(true)
	return result


func is_error() -> bool:
	return not succeeded


func has_payload() -> bool:
	return succeeded and not payload.is_empty()


static func generation_phases() -> Array[StringName]:
	return [
		PHASE_ROUTE,
		PHASE_RECIPE,
		PHASE_LAYOUT,
		PHASE_PATHING,
		PHASE_BLOCKERS,
		PHASE_HAZARDS,
		PHASE_ENEMIES,
		PHASE_REWARDS,
		PHASE_AFFINITY,
		PHASE_VALIDATION,
		PHASE_FINALIZE
	]


static func is_known_phase(phase: StringName) -> bool:
	return generation_phases().has(phase)


# Same lower-snake code discipline as ActionResult._is_valid_error_code: no whitespace, no
# punctuation that would break stable machine-readable codes.
static func _is_valid_code(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text.strip_edges() != text:
		return false
	if text != text.to_lower():
		return false

	var invalid_fragments: Array[String] = [" ", ".", ":", ";", "-", "/", "\\", "'", "\""]
	for fragment: String in invalid_fragments:
		if text.contains(fragment):
			return false

	return true
