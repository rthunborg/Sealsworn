extends "res://tests/unit/test_case.gd"

# Story 5.4 — RuleTrigger (the fixed trigger-window vocabulary, AC1/AC2).
#
# Pins the ten fixed trigger windows from the architecture's rules-kernel design and is_valid_window's
# allowlist behavior. A change here is an intentional vocabulary change (a later epic wires hook sites against
# these exact ids) — do NOT renumber/rename to make a drifting test pass.

const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")

# The fixed ten windows in the architecture's declaration order.
const EXPECTED_WINDOWS: Array[StringName] = [
	&"run_started",
	&"level_entered",
	&"turn_started",
	&"before_move",
	&"after_move",
	&"before_attack",
	&"damage_calculated",
	&"enemy_killed",
	&"reward_offered",
	&"level_completed"
]

func run() -> Dictionary:
	_windows_constant_is_the_fixed_ten_in_order()
	_named_consts_match_the_window_ids()
	_is_valid_window_accepts_every_fixed_window()
	_is_valid_window_rejects_unknown_windows()
	return result()


func _windows_constant_is_the_fixed_ten_in_order() -> void:
	assert_equal(RuleTrigger.WINDOWS, EXPECTED_WINDOWS, "RuleTrigger.WINDOWS must be the fixed ten trigger windows in the architecture's order.")
	assert_equal(RuleTrigger.WINDOWS.size(), 10, "There must be exactly ten fixed trigger windows.")


func _named_consts_match_the_window_ids() -> void:
	assert_equal(RuleTrigger.RUN_STARTED, &"run_started", "RUN_STARTED const must hold the run_started id.")
	assert_equal(RuleTrigger.LEVEL_ENTERED, &"level_entered", "LEVEL_ENTERED const must hold the level_entered id.")
	assert_equal(RuleTrigger.TURN_STARTED, &"turn_started", "TURN_STARTED const must hold the turn_started id.")
	assert_equal(RuleTrigger.BEFORE_MOVE, &"before_move", "BEFORE_MOVE const must hold the before_move id.")
	assert_equal(RuleTrigger.AFTER_MOVE, &"after_move", "AFTER_MOVE const must hold the after_move id.")
	assert_equal(RuleTrigger.BEFORE_ATTACK, &"before_attack", "BEFORE_ATTACK const must hold the before_attack id.")
	assert_equal(RuleTrigger.DAMAGE_CALCULATED, &"damage_calculated", "DAMAGE_CALCULATED const must hold the damage_calculated id.")
	assert_equal(RuleTrigger.ENEMY_KILLED, &"enemy_killed", "ENEMY_KILLED const must hold the enemy_killed id.")
	assert_equal(RuleTrigger.REWARD_OFFERED, &"reward_offered", "REWARD_OFFERED const must hold the reward_offered id.")
	assert_equal(RuleTrigger.LEVEL_COMPLETED, &"level_completed", "LEVEL_COMPLETED const must hold the level_completed id.")


func _is_valid_window_accepts_every_fixed_window() -> void:
	for window_id: StringName in EXPECTED_WINDOWS:
		assert_true(RuleTrigger.is_valid_window(window_id), "is_valid_window must accept the fixed window %s." % String(window_id))


func _is_valid_window_rejects_unknown_windows() -> void:
	assert_false(RuleTrigger.is_valid_window(&"not_a_real_window"), "is_valid_window must reject an unknown window id.")
	assert_false(RuleTrigger.is_valid_window(&""), "is_valid_window must reject an empty window id.")
	assert_false(RuleTrigger.is_valid_window(&"Run_Started"), "is_valid_window must reject a non-lower-snake variant.")
