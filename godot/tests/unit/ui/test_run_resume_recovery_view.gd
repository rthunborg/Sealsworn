extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 4 (AC3) — RunResumeRecoveryView: the testable seam that maps a resume ActionResult error code
# to a clear ON-SCREEN recovery message + a retry/fresh-start affordance (the appendix §13.3 recovery states).
# It reads the structured ActionResult code as truth (NOT stderr) and NEVER perturbs the restored run (it renders
# a message + offers a choice; the domain does the restore — the NFR13 resume invariant). This test pins that each
# of the seven structured recovery codes maps to a distinct message + the correct affordances, a SUCCESS resume
# projects the no-recovery success surface, and an unknown code fails closed to a generic recoverable message.

const RunResumeRecoveryView = preload("res://scripts/ui/view_models/run_resume_recovery_view.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

# The seven structured recovery codes (appendix §13.3; the same codes RunResumeService surfaces).
const RECOVERY_CODES: Array[String] = [
	"save_not_found",
	"save_open_failed",
	"save_parse_failed",
	"unsupported_save_schema",
	"invalid_tactical_snapshot",
	"missing_tactical_snapshot",
	"invalid_rng_snapshot"
]

const EXPECTED_KEYS: Array[String] = [
	"can_retry",
	"can_start_fresh",
	"code",
	"has_recovery",
	"is_recoverable",
	"message"
]

func run() -> Dictionary:
	_success_result_projects_no_recovery()
	_each_recovery_code_maps_to_a_distinct_message()
	_every_recovery_offers_a_fresh_start_affordance()
	_retryable_vs_fresh_only_codes()
	_unknown_code_fails_closed_to_a_generic_recoverable_message()
	_exact_key_set_pinned()
	_from_error_code_matches_from_result()
	return result()


# A SUCCESS resume projects the no-recovery success surface (has_recovery == false).
func _success_result_projects_no_recovery() -> void:
	var view: RunResumeRecoveryView = RunResumeRecoveryView.from_result(ActionResult.ok([], {"board": "restored"}))
	var data: Dictionary = view.to_dictionary()
	assert_equal(data.get("has_recovery"), false, "A successful resume must project has_recovery == false.")
	assert_equal(data.get("code"), "", "A successful resume carries no recovery code.")


# Each of the seven codes maps to a distinct, non-empty, human message + is marked recoverable.
func _each_recovery_code_maps_to_a_distinct_message() -> void:
	var seen_messages: Dictionary = {}
	for code: String in RECOVERY_CODES:
		var view: RunResumeRecoveryView = RunResumeRecoveryView.from_result(ActionResult.error(StringName(code), {}))
		var data: Dictionary = view.to_dictionary()
		assert_equal(data.get("has_recovery"), true, "%s must project has_recovery == true." % code)
		assert_equal(data.get("code"), code, "%s must carry its structured code verbatim." % code)
		assert_equal(data.get("is_recoverable"), true, "%s must be recoverable (a retry/fresh-start affordance exists)." % code)
		var message: String = String(data.get("message", ""))
		assert_false(message.strip_edges().is_empty(), "%s must project a NON-EMPTY on-screen message." % code)
		assert_false(seen_messages.has(message), "%s must project a DISTINCT message (no two codes share one)." % code)
		seen_messages[message] = true


# Every recovery path offers a fresh-start affordance (the "no partial corrupt state -> start fresh" guarantee).
func _every_recovery_offers_a_fresh_start_affordance() -> void:
	for code: String in RECOVERY_CODES:
		var data: Dictionary = RunResumeRecoveryView.from_result(ActionResult.error(StringName(code), {})).to_dictionary()
		assert_equal(data.get("can_start_fresh"), true, "%s must offer a start-fresh affordance." % code)


# save_not_found is fresh-start-only (nothing to retry); a transient/corrupt code offers a retry too.
func _retryable_vs_fresh_only_codes() -> void:
	var not_found: Dictionary = RunResumeRecoveryView.from_result(ActionResult.error(&"save_not_found", {})).to_dictionary()
	assert_equal(not_found.get("can_retry"), false, "save_not_found offers no retry (there is nothing to re-read).")
	assert_equal(not_found.get("can_start_fresh"), true, "save_not_found offers a fresh start.")
	# A transient open failure is retryable.
	var open_failed: Dictionary = RunResumeRecoveryView.from_result(ActionResult.error(&"save_open_failed", {})).to_dictionary()
	assert_equal(open_failed.get("can_retry"), true, "save_open_failed offers a retry (a transient open failure).")


# An unknown code fails closed to a generic recoverable message (never a crash, never a blank surface).
func _unknown_code_fails_closed_to_a_generic_recoverable_message() -> void:
	var data: Dictionary = RunResumeRecoveryView.from_result(ActionResult.error(&"some_unmapped_code", {})).to_dictionary()
	assert_equal(data.get("has_recovery"), true, "An unknown error still projects a recovery surface.")
	assert_equal(data.get("is_recoverable"), true, "An unknown error fails closed to recoverable (a fresh start always exists).")
	assert_false(String(data.get("message", "")).strip_edges().is_empty(), "An unknown error still projects a message.")
	assert_equal(data.get("can_start_fresh"), true, "An unknown error offers a fresh start.")


func _exact_key_set_pinned() -> void:
	var keys: Array = RunResumeRecoveryView.from_result(ActionResult.error(&"save_not_found", {})).to_dictionary().keys()
	keys.sort()
	assert_equal(keys, EXPECTED_KEYS, "The recovery view must expose EXACTLY the pinned key set.")
	var ok_keys: Array = RunResumeRecoveryView.from_result(ActionResult.ok()).to_dictionary().keys()
	ok_keys.sort()
	assert_equal(ok_keys, EXPECTED_KEYS, "The success surface must expose the SAME pinned key set.")


# from_error_code and from_result agree (the presenter may pass either a whole result or just the code).
func _from_error_code_matches_from_result() -> void:
	var via_code: Dictionary = RunResumeRecoveryView.from_error_code(&"invalid_rng_snapshot").to_dictionary()
	var via_result: Dictionary = RunResumeRecoveryView.from_result(ActionResult.error(&"invalid_rng_snapshot", {})).to_dictionary()
	assert_equal(via_code, via_result, "from_error_code must match from_result for the same code.")
