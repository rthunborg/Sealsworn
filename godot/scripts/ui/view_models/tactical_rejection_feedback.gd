class_name TacticalRejectionFeedback
extends RefCounted

# Story 14.2 (AC2/AC3 — the F3 fix) — the PURE, SCENE-FREE rejection-cue projection seam. Given the result of a live
# tap (a move/wait ActionResult, or an attack TacticalAttackCommitFlowResult) plus the tapped cell, it decides
# whether the command was REJECTED and, if so, projects a NON-COLOR cue the presenter surfaces so a rejected action
# is NEVER silent (the F3 defect: every rejected command produced no shake, no toast, nothing).
#
# THE DECISION THAT LIVES HERE (AC2): a genuine rejection (show a cue) vs. a benign non-commit (no cue). A first
# tap that ARMS an attack preview (reason "preview_ready"), a user CANCEL (reason "cancelled"), and a committed
# action (submitted && command_result.succeeded) are NOT rejections; a rejected move/wait (ActionResult error) and a
# cleared attack flow carrying an error reason ARE. Every reject reason maps to a short, color-independent,
# audio-absent-equivalent message via a stable table with a FAIL-SAFE default (no reason is ever un-messaged).
#
# It reads ONLY the result the existing commands already return (no new command, no new domain query), mutates
# NOTHING, and draws ZERO RNG. NFR9: the `message` line is the required accessible channel; the `shake` flag is an
# ADDITIVE hint for an optional cell nudge, never the sole cue.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const TacticalAttackCommitFlowResult = preload("res://scripts/ui/view_models/tactical_attack_commit_flow_result.gd")

# The EXACT key set of every cue (the exact-key discipline — a test pins it, fail-loud if a key appears/vanishes).
const CUE_KEYS: Array[String] = [
	"has_cue",
	"message",
	"reason_id",
	"source_error_code",
	"cell",
	"shake"
]

# Flow-result reasons that are NOT rejections: a first-tap ARM, a user CANCEL, and the success reasons a committed
# attack can carry (defense-in-depth alongside the submitted && succeeded gate).
const BENIGN_FLOW_REASONS: Array[String] = [
	"preview_ready",
	"cancelled",
	"committed",
	"attack"
]

const MODE_ATTACK_PREVIEW := "attack_preview"
const DEFAULT_MESSAGE_PREFIX := "Action not allowed"

# The stable reason -> player-facing, color-independent message table. Covers the reason vocabulary the live tap
# seams emit (move validation, attack targeting, bridge/session). A reason NOT in the table falls back to a
# fail-safe default (message_for) — never an empty message. `missing_target` is the exact F3 "attacking a
# damage-killed corpse is silent" case (14.1 corpse-clear makes a corpse read as missing_target, not dead_target).
const MESSAGES: Dictionary = {
	# Move / shared movement-validation reasons (move_command.gd + tactical_movement_query.gd).
	"blocked": "Blocked by a wall",
	"occupied": "That cell is occupied",
	"out_of_bounds": "Off the board",
	"beyond_budget": "Too far to move",
	"unreachable": "No path to that cell",
	"same_cell": "That's your own cell",
	"not_visible": "Can't see that cell",
	"invalid_budget": "Can't move there",
	"invalid_board": "Can't act right now",
	"invalid_context": "Can't act right now",
	"invalid_actor": "That unit can't act",
	"dead_actor": "Your hero is down",
	"wrong_phase": "Not your turn",
	# Attack targeting reasons (attack_preview_query.gd).
	"missing_target": "No target there",
	"dead_target": "That target is already dead",
	"friendly_target": "Can't attack an ally",
	"not_aligned": "Not in line",
	"out_of_range": "Out of range",
	"blocked_line": "Line of fire is blocked",
	"invalid_weapon": "No weapon ready",
	# Attack commit-flow edge reasons (tactical_attack_commit_flow.gd).
	"no_pending_attack": "No attack armed",
	"weapon_changed": "Weapon changed — re-aim",
	"target_changed": "Target moved — re-aim",
	# Bridge / session reasons (tactical_command_bridge.gd + interactive_combat_session.gd).
	"action_unavailable": "Action not allowed",
	"invalid_ui_intent": "Invalid action",
	"invalid_command_context": "Can't act right now",
	"unsupported_intent": "Action not supported",
	"session_not_begun": "The fight hasn't started",
	"session_terminal": "The fight is over"
}


# Map a move/wait ActionResult into a cue. A null or successful result is a benign non-cue; a rejected result carries
# its reason at metadata.reason (falling back to error_code) — the bridge wraps a validation reject as error_code
# `action_unavailable` with the concrete reason (e.g. "blocked") at metadata.reason.
static func from_action_result(result: ActionResult, cell: Variant = null) -> Dictionary:
	if result == null:
		return _no_cue()
	if result.succeeded:
		return _no_cue()
	var metadata: Dictionary = result.metadata if result.metadata is Dictionary else {}
	var source_error_code: String = String(result.error_code)
	var reason_id: String = String(metadata.get("reason", ""))
	if reason_id.is_empty():
		reason_id = source_error_code
	return _cue(reason_id, source_error_code, cell)


# Map an attack TacticalAttackCommitFlowResult into a cue. A committed-and-succeeded attack, a first-tap ARM
# (preview_ready), and a user CANCEL are benign non-cues; a cleared flow carrying an error reason (out_of_range,
# missing_target, blocked_line, ...) is a rejection.
static func from_flow_result(flow_result: TacticalAttackCommitFlowResult, cell: Variant = null) -> Dictionary:
	if flow_result == null:
		return _no_cue()
	# A committed-and-succeeded attack is not a rejection.
	var command_result: ActionResult = flow_result.command_result
	if flow_result.submitted and command_result != null and command_result.succeeded:
		return _no_cue()
	var reason_id: String = String(flow_result.reason)
	# Benign non-commits (arm / cancel / success reasons) never show a cue.
	if BENIGN_FLOW_REASONS.has(reason_id):
		return _no_cue()
	# A still-armed preview (defensive; the reason would be preview_ready) is benign.
	if _flow_mode(flow_result) == MODE_ATTACK_PREVIEW:
		return _no_cue()
	# Otherwise a cleared flow with an error reason IS a rejection.
	var source_error_code: String = String(command_result.error_code) if command_result != null else reason_id
	return _cue(reason_id, source_error_code, cell)


# The stable reason -> message lookup, with a fail-safe default so no reason is ever un-messaged.
static func message_for(reason_id: String) -> String:
	if MESSAGES.has(reason_id):
		return String(MESSAGES[reason_id])
	if reason_id.is_empty():
		return DEFAULT_MESSAGE_PREFIX
	return "%s (%s)" % [DEFAULT_MESSAGE_PREFIX, reason_id]


static func _cue(reason_id: String, source_error_code: String, cell: Variant) -> Dictionary:
	return {
		"has_cue": true,
		"message": message_for(reason_id),
		"reason_id": reason_id,
		"source_error_code": source_error_code,
		"cell": _cell_or_null(cell),
		"shake": true
	}


static func _no_cue() -> Dictionary:
	return {
		"has_cue": false,
		"message": "",
		"reason_id": "",
		"source_error_code": "",
		"cell": null,
		"shake": false
	}


static func _flow_mode(flow_result: TacticalAttackCommitFlowResult) -> String:
	var data: Dictionary = flow_result.to_dictionary()
	var flow_value: Variant = data.get("flow", {})
	var flow: Dictionary = flow_value if flow_value is Dictionary else {}
	return String(flow.get("mode", ""))


static func _cell_or_null(value: Variant) -> Variant:
	if value is Vector2i:
		var vector: Vector2i = value
		return {"x": vector.x, "y": vector.y}
	if value is Dictionary:
		var data: Dictionary = value
		if (data.has("x") or data.has(&"x")) and (data.has("y") or data.has(&"y")):
			return {"x": int(_num(data, "x")), "y": int(_num(data, "y"))}
	return null


static func _num(data: Dictionary, key: String) -> int:
	if data.has(key):
		return int(data[key])
	if data.has(StringName(key)):
		return int(data[StringName(key)])
	return 0
