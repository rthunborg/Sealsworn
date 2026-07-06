class_name RunResumeRecoveryView
extends RefCounted

# Story 11.3 (AC3, appendix §13.3) — the scene-free RESUME-RECOVERY view. It MAPS a resume ActionResult (from
# SaveManager.resume_run / resume_route_position -> RunResumeService) to a CLEAR on-screen recovery message + a
# retry / start-fresh affordance, for EACH of the seven structured recovery codes. It reads the STRUCTURED
# ActionResult CODE as truth (NOT stderr — a parse failure emits one expected `ERROR: Parse JSON failed` line and
# STILL returns a structured error; this view reads the code, never the stderr).
#
# ⭐ IT NEVER PERTURBS THE RESTORED RUN (the NFR13 resume invariant the scene MUST respect): it renders a MESSAGE
# + offers a CHOICE; the DOMAIN does the restore (consuming NO RNG, running NO command, advancing NO turn). This
# view is a PURE read of the result — it draws NO RNG, mutates NOTHING, mints no event. A recovery screen may
# present a message + a retry/fresh-start choice, but it must not itself run a command or advance a turn — this
# view holds only the message + the affordance flags; the presenter wires the retry (a fresh resume call) / the
# fresh start (a new run) to the EXISTING seams.
#
# ⭐ NO PARTIAL CORRUPT STATE: on any recovery the run is NOT restored (the RunResumeService "no partial state on
# failure" guarantee), so EVERY recovery path offers a fresh start (is_recoverable == true). A transient failure
# (save_open_failed) additionally offers a retry; a save_not_found offers only a fresh start (nothing to re-read);
# a corrupt-payload code offers both (a re-read may hit a transient, else start fresh). An unknown code fails
# closed to a generic recoverable message (never a crash, never a blank surface).
#
# ⭐ SPLIT (§13.1): 11.3 handles the RUN save/resume recovery on the run-flow side; the PROFILE-recovery surface at
# the outpost is 11.5's (the OutpostViewModel.recovery_state). This view is the RUN-side recovery.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

# The EXACT key set (pinned by test). has_recovery gates whether a recovery is active (false for a successful
# resume); code is the structured recovery code (or "" on success); is_recoverable marks whether a fresh-start /
# retry recovers it (always true — every failure has a fresh-start path); message is the on-screen text; can_retry
# / can_start_fresh are the affordance flags the presenter renders.
const DICTIONARY_KEYS: Array[String] = [
	"has_recovery",
	"code",
	"is_recoverable",
	"message",
	"can_retry",
	"can_start_fresh"
]

# The seven structured recovery codes (appendix §13.3; the codes RunResumeService surfaces). Each maps to a
# distinct on-screen message + the correct affordance (retry when a re-read may recover; fresh-start always). A
# code marked can_retry offers "try again" (a transient / a re-read that may hit a good file); every code offers
# "start fresh" (no partial corrupt state ever became active).
const _RECOVERY_CATALOG: Dictionary = {
	"save_not_found": {
		"message": "No saved run was found. Start a fresh descent.",
		"can_retry": false
	},
	"save_open_failed": {
		"message": "The save file could not be opened (it may be temporarily locked). Try again, or start fresh.",
		"can_retry": true
	},
	"save_parse_failed": {
		"message": "The save file is unreadable (corrupted data). Try again, or start a fresh descent.",
		"can_retry": true
	},
	"unsupported_save_schema": {
		"message": "This save is from an incompatible version and cannot be resumed. Start a fresh descent.",
		"can_retry": false
	},
	"invalid_tactical_snapshot": {
		"message": "The saved battle state is corrupted and cannot be restored. Try again, or start fresh.",
		"can_retry": true
	},
	"missing_tactical_snapshot": {
		"message": "The saved battle state is missing and cannot be restored. Start a fresh descent.",
		"can_retry": false
	},
	"invalid_rng_snapshot": {
		"message": "The saved run's determinism data is corrupted and cannot be restored. Try again, or start fresh.",
		"can_retry": true
	}
}

# The generic fail-closed recovery message for an UNMAPPED error code (never a crash / blank surface).
const _GENERIC_RECOVERY_MESSAGE := "The saved run could not be resumed. Try again, or start a fresh descent."

var has_recovery: bool = false
var code: String = ""
var is_recoverable: bool = true
var message: String = ""
var can_retry: bool = false
var can_start_fresh: bool = false

# Build the recovery view from a resume ActionResult. A SUCCESS result projects the no-recovery success surface; an
# ERROR result maps its code to the recovery message + affordances.
static func from_result(resume_result: ActionResult) -> RunResumeRecoveryView:
	if resume_result != null and resume_result.succeeded:
		return _success()
	var error_code: StringName = resume_result.error_code if resume_result != null else &"unknown_resume_error"
	return from_error_code(error_code)


# Build the recovery view from a raw error code (the presenter may pass either the whole result or just the code).
static func from_error_code(error_code: StringName) -> RunResumeRecoveryView:
	var view: RunResumeRecoveryView = load("res://scripts/ui/view_models/run_resume_recovery_view.gd").new()
	view.has_recovery = true
	view.code = String(error_code)
	view.is_recoverable = true
	# EVERY failure offers a fresh start (no partial corrupt state ever became active).
	view.can_start_fresh = true

	if _RECOVERY_CATALOG.has(view.code):
		var entry: Dictionary = _RECOVERY_CATALOG[view.code]
		view.message = String(entry.get("message", _GENERIC_RECOVERY_MESSAGE))
		view.can_retry = bool(entry.get("can_retry", false))
	else:
		# Fail closed: an unmapped code still projects a generic recoverable surface (retry allowed — a re-read
		# may recover a transient; the fresh start always exists).
		view.message = _GENERIC_RECOVERY_MESSAGE
		view.can_retry = true
	return view


# The no-recovery SUCCESS surface (has_recovery == false — the resume restored the run; nothing to recover).
static func _success() -> RunResumeRecoveryView:
	var view: RunResumeRecoveryView = load("res://scripts/ui/view_models/run_resume_recovery_view.gd").new()
	view.has_recovery = false
	view.code = ""
	view.is_recoverable = true
	view.message = ""
	view.can_retry = false
	view.can_start_fresh = false
	return view


# Exact-key projection: plain String/bool data only (no live ActionResult handle leaks out). A FRESH dictionary
# each call.
func to_dictionary() -> Dictionary:
	return {
		"has_recovery": has_recovery,
		"code": code,
		"is_recoverable": is_recoverable,
		"message": message,
		"can_retry": can_retry,
		"can_start_fresh": can_start_fresh
	}
