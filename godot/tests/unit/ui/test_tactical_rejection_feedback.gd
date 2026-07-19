extends "res://tests/unit/test_case.gd"

# Story 14.2 (Task 3 — the F3 rejection cue) — TacticalRejectionFeedback coverage. Proves the scene-free seam
# distinguishes a genuine rejection (show a non-color cue) from a benign non-commit (no cue), and maps every reject
# reason to a non-empty, color-independent message:
#   - the EXACT CUE_KEYS set for BOTH a reject cue and a no-cue result;
#   - a rejected move (action_unavailable + metadata.reason "blocked") -> has_cue: true, "Blocked by a wall", + cell;
#   - a session error with no metadata.reason (session_terminal) -> reason falls back to error_code;
#   - a successful move / wait -> has_cue: false (even carrying a success reason like "voluntary");
#   - a first-tap ARM (preview_ready) and a user CANCEL -> has_cue: false;
#   - a committed attack (submitted && command_result.succeeded) -> has_cue: false;
#   - a cleared flow carrying a pruned success-reason string ("committed"/"attack") -> has_cue: true (fail-loud);
#   - a cleared attack flow with an error reason (out_of_range) -> has_cue: true, "Out of range";
#   - the corpse missing_target case -> a clear "No target there" message (the exact F3 defect), + dead_target;
#   - an UNMAPPED reason -> the fail-safe default (never empty), naming the reason;
#   - a null result / null flow result -> benign no-cue (no crash);
#   - zero mutation of the input result metadata.
# str() (never eager String(nullable)) is used in assert messages (the 14.1 retro test-honesty note).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const TacticalAttackCommitFlowResult = preload("res://scripts/ui/view_models/tactical_attack_commit_flow_result.gd")
const TacticalRejectionFeedback = preload("res://scripts/ui/view_models/tactical_rejection_feedback.gd")

func run() -> Dictionary:
	_cue_keys_are_exact()
	_rejected_move_shows_a_cue_with_reason_and_cell()
	_session_error_reason_falls_back_to_error_code()
	_successful_move_and_wait_show_no_cue()
	_arm_and_cancel_flow_show_no_cue()
	_committed_attack_shows_no_cue()
	_pruned_success_reason_strings_are_now_fail_loud()
	_cleared_error_attack_flow_shows_a_cue()
	_corpse_and_dead_target_map_to_clear_messages()
	_unmapped_reason_uses_the_fail_safe_default()
	_null_results_are_benign_no_cue()
	_message_for_maps_and_defaults()
	_projection_does_not_mutate_the_input()
	return result()


# ---- exact-key discipline ------------------------------------------------------------------------

func _cue_keys_are_exact() -> void:
	var reject: Dictionary = TacticalRejectionFeedback.from_action_result(_move_reject("blocked"), Vector2i(1, 1))
	_assert_exact_keys(reject, TacticalRejectionFeedback.CUE_KEYS, "A reject cue must carry EXACTLY the CUE_KEYS set.")
	var none: Dictionary = TacticalRejectionFeedback.from_action_result(ActionResult.ok(), null)
	_assert_exact_keys(none, TacticalRejectionFeedback.CUE_KEYS, "A no-cue result must carry the SAME CUE_KEYS set.")


# ---- move / wait (ActionResult) ------------------------------------------------------------------

func _rejected_move_shows_a_cue_with_reason_and_cell() -> void:
	var cue: Dictionary = TacticalRejectionFeedback.from_action_result(_move_reject("blocked"), Vector2i(1, 1))
	assert_equal(cue.get("has_cue"), true, "A rejected move is never silent.")
	assert_equal(cue.get("reason_id"), "blocked", "The cue reads the concrete reason from metadata.reason. Got %s." % str(cue.get("reason_id")))
	assert_equal(cue.get("message"), "Blocked by a wall", "The reason maps to a color-independent message. Got %s." % str(cue.get("message")))
	assert_equal(cue.get("cell"), {"x": 1, "y": 1}, "The cue carries the rejected cell. Got %s." % str(cue.get("cell")))
	assert_equal(cue.get("source_error_code"), "action_unavailable", "The cue records the bridge error code. Got %s." % str(cue.get("source_error_code")))
	assert_equal(cue.get("shake"), true, "A reject cue flags an optional additive shake.")
	# A few more concrete move reasons map to distinct non-empty messages.
	assert_equal(TacticalRejectionFeedback.from_action_result(_move_reject("occupied"), Vector2i(0, 0)).get("message"), "That cell is occupied", "occupied maps to a clear message.")
	assert_equal(TacticalRejectionFeedback.from_action_result(_move_reject("out_of_bounds"), Vector2i(0, 0)).get("message"), "Off the board", "out_of_bounds maps to a clear message.")
	assert_equal(TacticalRejectionFeedback.from_action_result(_move_reject("beyond_budget"), Vector2i(0, 0)).get("message"), "Too far to move", "beyond_budget maps to a clear message.")


func _session_error_reason_falls_back_to_error_code() -> void:
	# The session's own _error path carries NO metadata.reason (only a command tag) — the reason falls back to the
	# error_code so session_terminal / session_not_begun still surface a message.
	var terminal: ActionResult = ActionResult.error(&"session_terminal", {"command": "interactive_combat_session"})
	var cue: Dictionary = TacticalRejectionFeedback.from_action_result(terminal, null)
	assert_equal(cue.get("has_cue"), true, "A session_terminal reject is never silent.")
	assert_equal(cue.get("reason_id"), "session_terminal", "With no metadata.reason, the reason falls back to error_code. Got %s." % str(cue.get("reason_id")))
	assert_equal(cue.get("message"), "The fight is over", "session_terminal maps to a clear message. Got %s." % str(cue.get("message")))
	assert_equal(cue.get("cell"), null, "A cell-less reject (e.g. wait) carries a null cell.")


func _successful_move_and_wait_show_no_cue() -> void:
	# A successful result short-circuits BEFORE reading any reason — a committed wait carries reason "voluntary" but
	# must never produce a cue.
	var ok_move: ActionResult = ActionResult.ok([], {"advances_turn": true})
	assert_equal(TacticalRejectionFeedback.from_action_result(ok_move, Vector2i(2, 2)).get("has_cue"), false, "A successful move shows no cue.")
	var ok_wait: ActionResult = ActionResult.ok([], {"advances_turn": true, "reason": "voluntary"})
	assert_equal(TacticalRejectionFeedback.from_action_result(ok_wait, null).get("has_cue"), false, "A committed wait shows no cue even with a success reason.")


# ---- attack (TacticalAttackCommitFlowResult) -----------------------------------------------------

func _arm_and_cancel_flow_show_no_cue() -> void:
	var arm: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "preview_ready", null, {"mode": "attack_preview"})
	assert_equal(TacticalRejectionFeedback.from_flow_result(arm, Vector2i(3, 2)).get("has_cue"), false, "A first-tap ARM is benign (the armed panel shows instead).")
	var cancel: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "cancelled", null, {"mode": "none"})
	assert_equal(TacticalRejectionFeedback.from_flow_result(cancel, null).get("has_cue"), false, "A user CANCEL is benign — no cue.")


func _committed_attack_shows_no_cue() -> void:
	# submitted && command_result.succeeded is a commit, not a rejection — regardless of the reason string.
	var committed: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(true, "attack", "attack", ActionResult.ok([], {}), {"mode": "none"})
	assert_equal(TacticalRejectionFeedback.from_flow_result(committed, Vector2i(2, 1)).get("has_cue"), false, "A committed attack shows no cue.")


func _pruned_success_reason_strings_are_now_fail_loud() -> void:
	# Round-1 [Review][Decision]: "committed" and "attack" were PRUNED from BENIGN_FLOW_REASONS. They are the success
	# reason / command_id a committed attack carries, already short-circuited by the submitted && succeeded gate. A
	# CLEARED flow (not submitted, mode "none") that carries one of these as a FAILURE reason must now surface a cue
	# (fail-loud default), never be silently swallowed as benign — guards against re-adding the dead entries.
	var committed_fail: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "committed", null, {"mode": "none"})
	assert_equal(TacticalRejectionFeedback.from_flow_result(committed_fail, Vector2i(4, 4)).get("has_cue"), true, "A cleared flow carrying 'committed' as a failure reason is fail-loud, not benign.")
	var attack_fail: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "attack", null, {"mode": "none"})
	assert_equal(TacticalRejectionFeedback.from_flow_result(attack_fail, Vector2i(4, 4)).get("has_cue"), true, "A cleared flow carrying 'attack' as a failure reason is fail-loud, not benign.")


func _cleared_error_attack_flow_shows_a_cue() -> void:
	var oor: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "out_of_range", null, {"mode": "none"})
	var cue: Dictionary = TacticalRejectionFeedback.from_flow_result(oor, Vector2i(5, 5))
	assert_equal(cue.get("has_cue"), true, "A cleared attack flow with an error reason is a rejection.")
	assert_equal(cue.get("message"), "Out of range", "out_of_range maps to a clear message. Got %s." % str(cue.get("message")))
	assert_equal(cue.get("cell"), {"x": 5, "y": 5}, "The attack cue carries the tapped cell. Got %s." % str(cue.get("cell")))
	# not_aligned + blocked_line also surface.
	assert_equal(TacticalRejectionFeedback.from_flow_result(TacticalAttackCommitFlowResult.from_flow(false, "", "not_aligned", null, {"mode": "none"}), null).get("message"), "Not in line", "not_aligned maps to a clear message.")
	assert_equal(TacticalRejectionFeedback.from_flow_result(TacticalAttackCommitFlowResult.from_flow(false, "", "blocked_line", null, {"mode": "none"}), null).get("message"), "Line of fire is blocked", "blocked_line maps to a clear message.")


func _corpse_and_dead_target_map_to_clear_messages() -> void:
	# The exact F3 defect: attacking a damage-killed corpse returns missing_target (14.1 corpse-clear). It must NOT be
	# silent — it maps to a clear "no target" message.
	var corpse: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "missing_target", null, {"mode": "none"})
	var corpse_cue: Dictionary = TacticalRejectionFeedback.from_flow_result(corpse, Vector2i(2, 1))
	assert_equal(corpse_cue.get("has_cue"), true, "Attacking a corpse (missing_target) is never silent (F3).")
	assert_equal(corpse_cue.get("reason_id"), "missing_target", "The corpse reject reads missing_target. Got %s." % str(corpse_cue.get("reason_id")))
	assert_equal(corpse_cue.get("message"), "No target there", "missing_target maps to a clear 'no target' message. Got %s." % str(corpse_cue.get("message")))
	# A setup-PLACED dead entity still returns dead_target — cover both.
	var dead: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "dead_target", null, {"mode": "none"})
	assert_equal(TacticalRejectionFeedback.from_flow_result(dead, null).get("message"), "That target is already dead", "dead_target maps to a clear message.")


func _unmapped_reason_uses_the_fail_safe_default() -> void:
	var weird: TacticalAttackCommitFlowResult = TacticalAttackCommitFlowResult.from_flow(false, "", "totally_unknown_reason", null, {"mode": "none"})
	var cue: Dictionary = TacticalRejectionFeedback.from_flow_result(weird, null)
	assert_equal(cue.get("has_cue"), true, "An unmapped reason still surfaces a cue (never silent).")
	assert_false(String(cue.get("message", "")).is_empty(), "An unmapped reason gets a non-empty fail-safe message. Got %s." % str(cue.get("message")))
	assert_true(String(cue.get("message", "")).contains("totally_unknown_reason"), "The fail-safe default names the raw reason. Got %s." % str(cue.get("message")))


func _null_results_are_benign_no_cue() -> void:
	assert_equal(TacticalRejectionFeedback.from_action_result(null, null).get("has_cue"), false, "A null ActionResult is a benign no-cue.")
	assert_equal(TacticalRejectionFeedback.from_flow_result(null, null).get("has_cue"), false, "A null flow result is a benign no-cue.")


func _message_for_maps_and_defaults() -> void:
	assert_equal(TacticalRejectionFeedback.message_for("blocked"), "Blocked by a wall", "message_for maps a known reason.")
	assert_equal(TacticalRejectionFeedback.message_for("missing_target"), "No target there", "message_for maps missing_target.")
	assert_false(TacticalRejectionFeedback.message_for("nonexistent_reason").is_empty(), "message_for never returns an empty message.")


# ---- purity --------------------------------------------------------------------------------------

func _projection_does_not_mutate_the_input() -> void:
	var result_value: ActionResult = _move_reject("blocked")
	var before: Dictionary = result_value.metadata.duplicate(true)
	TacticalRejectionFeedback.from_action_result(result_value, Vector2i(1, 1))
	assert_equal(result_value.metadata, before, "from_action_result must not mutate the result metadata.")


# ---- fixtures / helpers --------------------------------------------------------------------------

# The shape the command bridge produces for a rejected move: error_code action_unavailable, the concrete movement
# reason at metadata.reason, and the source error code nested under metadata.metadata.
func _move_reject(reason: String) -> ActionResult:
	return ActionResult.error(&"action_unavailable", {
		"reason": reason,
		"intent_id": "move",
		"metadata": {"source_error_code": "invalid_movement"}
	})


func _assert_exact_keys(actual: Dictionary, expected: Array, message: String) -> void:
	var keys: Array = actual.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	assert_equal(keys, want, message)
