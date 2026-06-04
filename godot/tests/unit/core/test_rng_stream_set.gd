extends "res://tests/unit/test_case.gd"

const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

func run() -> Dictionary:
	_same_seed_replays_streams()
	_cosmetic_stream_does_not_advance_combat()
	_snapshot_restores_stream_state()
	_unknown_stream_does_not_mutate_known_streams()
	return result()


func _same_seed_replays_streams() -> void:
	var first: RngStreamSet = RngStreamSet.new(12345)
	var second: RngStreamSet = RngStreamSet.new(12345)

	assert_equal(_roll_int(first, RngStreamSet.STREAM_LEVEL, 1, 100), _roll_int(second, RngStreamSet.STREAM_LEVEL, 1, 100), "Same seed should replay level stream.")
	assert_equal(_roll_int(first, RngStreamSet.STREAM_LOOT, 1, 100), _roll_int(second, RngStreamSet.STREAM_LOOT, 1, 100), "Same seed should replay loot stream.")


func _cosmetic_stream_does_not_advance_combat() -> void:
	var with_cosmetic: RngStreamSet = RngStreamSet.new(99)
	var without_cosmetic: RngStreamSet = RngStreamSet.new(99)

	var first_combat_roll: int = _roll_int(with_cosmetic, RngStreamSet.STREAM_COMBAT, 1, 100)
	_roll_int(with_cosmetic, RngStreamSet.STREAM_COSMETIC, 1, 100)
	var second_combat_roll: int = _roll_int(with_cosmetic, RngStreamSet.STREAM_COMBAT, 1, 100)

	assert_equal(first_combat_roll, _roll_int(without_cosmetic, RngStreamSet.STREAM_COMBAT, 1, 100), "Combat stream first roll should be deterministic.")
	assert_equal(second_combat_roll, _roll_int(without_cosmetic, RngStreamSet.STREAM_COMBAT, 1, 100), "Cosmetic stream use should not advance combat stream.")


func _snapshot_restores_stream_state() -> void:
	var original: RngStreamSet = RngStreamSet.new(7)
	_roll_int(original, RngStreamSet.STREAM_REWARDS, 1, 100)
	var snapshot: Dictionary = original.to_snapshot()

	var expected_next_roll: int = _roll_int(original, RngStreamSet.STREAM_REWARDS, 1, 100)
	var restored: RngStreamSet = RngStreamSet.new(0)
	restored.restore(snapshot)

	assert_equal(_roll_int(restored, RngStreamSet.STREAM_REWARDS, 1, 100), expected_next_roll, "RNG stream snapshot should restore next roll.")


func _unknown_stream_does_not_mutate_known_streams() -> void:
	var streams: RngStreamSet = RngStreamSet.new(44)
	var before: Dictionary = streams.to_snapshot()

	var result_value: ActionResult = streams.rand_int(&"combta", 1, 100)
	var after: Dictionary = streams.to_snapshot()

	assert_true(result_value.is_error(), "Unknown RNG stream should return an explicit error.")
	assert_equal(result_value.error_code, &"unknown_rng_stream", "Unknown RNG stream should explain the failure.")
	assert_equal(after, before, "Unknown RNG stream should not mutate any named stream.")


func _roll_int(streams: RngStreamSet, stream_name: StringName, minimum: int, maximum: int) -> int:
	var result_value: ActionResult = streams.rand_int(stream_name, minimum, maximum)
	assert_true(result_value.succeeded, "Known RNG stream should return a value.")
	return int(result_value.metadata.get("value", 0))
