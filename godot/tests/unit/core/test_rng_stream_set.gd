extends "res://tests/unit/test_case.gd"

const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

func run() -> Dictionary:
	_required_streams_are_stable()
	_all_streams_replay_first_and_second_rolls()
	_unrelated_streams_do_not_advance_combat()
	_successful_int_draws_include_audit_metadata()
	_successful_float_draws_include_audit_metadata()
	_consumer_context_is_deep_copied_for_audit_metadata()
	_snapshot_includes_draw_indexes_for_all_streams()
	_snapshot_restores_stream_state()
	_try_restore_rejects_malformed_snapshots_without_mutation()
	_try_restore_replays_next_roll_for_every_stream()
	_invalid_stream_names_do_not_mutate_known_streams()
	_invalid_int_ranges_do_not_mutate_or_emit_draw_audit()
	_cyclic_consumer_context_does_not_mutate_or_emit_draw_audit()
	_deterministic_gameplay_draw_sequence_replays_from_snapshot()
	_cosmetic_draws_do_not_change_gameplay_draw_replay()
	return result()


func _required_streams_are_stable() -> void:
	var expected_streams: Array[StringName] = [
		RngStreamSet.STREAM_MAP,
		RngStreamSet.STREAM_LEVEL,
		RngStreamSet.STREAM_COMBAT,
		RngStreamSet.STREAM_LOOT,
		RngStreamSet.STREAM_REWARDS,
		RngStreamSet.STREAM_EVENTS,
		RngStreamSet.STREAM_COSMETIC
	]

	assert_equal(RngStreamSet.required_streams(), expected_streams, "Required RNG streams should stay in stable architecture order.")


func _all_streams_replay_first_and_second_rolls() -> void:
	var first: RngStreamSet = RngStreamSet.new(12345)
	var second: RngStreamSet = RngStreamSet.new(12345)

	for stream_name: StringName in RngStreamSet.required_streams():
		assert_true(first.has_stream(stream_name), "Configured RNG set should include %s." % String(stream_name))
		assert_true(second.has_stream(stream_name), "Second configured RNG set should include %s." % String(stream_name))
		assert_equal(_roll_int(first, stream_name, 1, 100), _roll_int(second, stream_name, 1, 100), "Same seed should replay first %s roll." % String(stream_name))
		assert_equal(_roll_int(first, stream_name, 1, 100), _roll_int(second, stream_name, 1, 100), "Same seed should replay second %s roll." % String(stream_name))


func _unrelated_streams_do_not_advance_combat() -> void:
	var unrelated_streams: Array[StringName] = [
		RngStreamSet.STREAM_MAP,
		RngStreamSet.STREAM_LEVEL,
		RngStreamSet.STREAM_LOOT,
		RngStreamSet.STREAM_REWARDS,
		RngStreamSet.STREAM_EVENTS,
		RngStreamSet.STREAM_COSMETIC
	]

	for unrelated_stream: StringName in unrelated_streams:
		var with_unrelated: RngStreamSet = RngStreamSet.new(99)
		var without_unrelated: RngStreamSet = RngStreamSet.new(99)

		var first_combat_roll: int = _roll_int(with_unrelated, RngStreamSet.STREAM_COMBAT, 1, 100)
		_roll_int(with_unrelated, unrelated_stream, 1, 100)
		var second_combat_roll: int = _roll_int(with_unrelated, RngStreamSet.STREAM_COMBAT, 1, 100)

		assert_equal(first_combat_roll, _roll_int(without_unrelated, RngStreamSet.STREAM_COMBAT, 1, 100), "Combat stream first roll should be deterministic when %s is unused." % String(unrelated_stream))
		assert_equal(second_combat_roll, _roll_int(without_unrelated, RngStreamSet.STREAM_COMBAT, 1, 100), "Advancing %s should not advance combat stream." % String(unrelated_stream))


func _successful_int_draws_include_audit_metadata() -> void:
	var streams: RngStreamSet = RngStreamSet.new(222)
	var first_result: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat", "reason": "damage_variance"})
	var second_result: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat", "reason": "follow_up"})

	assert_true(first_result.succeeded, "Known RNG int stream should draw successfully.")
	assert_true(second_result.succeeded, "Known RNG int stream should draw successfully a second time.")
	assert_equal(first_result.metadata.get("stream_name"), "combat", "RNG audit should record the stream name.")
	assert_equal(first_result.metadata.get("draw_index"), 0, "First successful combat draw should use draw index 0.")
	assert_equal(second_result.metadata.get("draw_index"), 1, "Second successful combat draw should use draw index 1.")
	assert_equal(first_result.metadata.get("draw_type"), "int", "Integer RNG audit should record draw type.")
	assert_true(first_result.metadata.has("value"), "Integer RNG audit should preserve value metadata.")
	assert_true(first_result.metadata.has("state_before"), "Integer RNG audit should record state before draw.")
	assert_true(first_result.metadata.has("state_after"), "Integer RNG audit should record state after draw.")
	assert_true(first_result.metadata.get("state_before") is int, "State before should be serializable integer data.")
	assert_true(first_result.metadata.get("state_after") is int, "State after should be serializable integer data.")
	assert_true(first_result.metadata.get("state_before") != first_result.metadata.get("state_after"), "Successful draw should advance stream state.")
	assert_equal(first_result.metadata.get("consumer_context").get("reason"), "damage_variance", "RNG audit should preserve consumer context.")


func _successful_float_draws_include_audit_metadata() -> void:
	var streams: RngStreamSet = RngStreamSet.new(333)
	var result_value: ActionResult = streams.rand_float(RngStreamSet.STREAM_REWARDS, {"system": "rewards"})

	assert_true(result_value.succeeded, "Known RNG float stream should draw successfully.")
	assert_equal(result_value.metadata.get("stream_name"), "rewards", "Float RNG audit should record the stream name.")
	assert_equal(result_value.metadata.get("draw_index"), 0, "First successful rewards draw should use draw index 0.")
	assert_equal(result_value.metadata.get("draw_type"), "float", "Float RNG audit should record draw type.")
	assert_true(result_value.metadata.has("value"), "Float RNG audit should preserve value metadata.")
	assert_true(result_value.metadata.has("state_before"), "Float RNG audit should record state before draw.")
	assert_true(result_value.metadata.has("state_after"), "Float RNG audit should record state after draw.")
	assert_equal(result_value.metadata.get("consumer_context").get("system"), "rewards", "Float RNG audit should preserve consumer context.")


func _consumer_context_is_deep_copied_for_audit_metadata() -> void:
	var streams: RngStreamSet = RngStreamSet.new(444)
	var consumer_context: Dictionary = {
		"system": "loot",
		"tags": ["drop", "rare"],
		"nested": {"source": "fixture"}
	}

	var result_value: ActionResult = streams.rand_int(RngStreamSet.STREAM_LOOT, 1, 20, consumer_context)
	consumer_context["system"] = "mutated"
	consumer_context["tags"][0] = "mutated"
	consumer_context["nested"]["source"] = "mutated"

	var audited_context: Dictionary = result_value.metadata.get("consumer_context")
	assert_equal(audited_context.get("system"), "loot", "RNG audit context should not be rewritten by later caller mutation.")
	assert_equal(audited_context.get("tags")[0], "drop", "RNG audit array context should be deep copied.")
	assert_equal(audited_context.get("nested").get("source"), "fixture", "RNG audit dictionary context should be deep copied.")


func _snapshot_restores_stream_state() -> void:
	var original: RngStreamSet = RngStreamSet.new(7)
	_roll_int(original, RngStreamSet.STREAM_REWARDS, 1, 100)
	var snapshot: Dictionary = original.to_snapshot()

	var expected_next_roll: int = _roll_int(original, RngStreamSet.STREAM_REWARDS, 1, 100)
	var restored: RngStreamSet = RngStreamSet.new(0)
	restored.restore(snapshot)

	assert_equal(_roll_int(restored, RngStreamSet.STREAM_REWARDS, 1, 100), expected_next_roll, "RNG stream snapshot should restore next roll.")


func _snapshot_includes_draw_indexes_for_all_streams() -> void:
	var streams: RngStreamSet = RngStreamSet.new(555)
	_roll_int(streams, RngStreamSet.STREAM_COMBAT, 1, 100)
	var snapshot: Dictionary = streams.to_snapshot()
	var stream_states: Dictionary = snapshot.get("streams")

	assert_equal(snapshot.get("root_seed"), 555, "RNG snapshot should include root seed.")
	for stream_name: StringName in RngStreamSet.required_streams():
		var stream_key: String = String(stream_name)
		assert_true(stream_states.has(stream_key), "RNG snapshot should include %s stream state." % stream_key)
		var stream_state: Dictionary = stream_states.get(stream_key)
		assert_true(stream_state.has("seed"), "RNG snapshot should include %s seed." % stream_key)
		assert_true(stream_state.has("state"), "RNG snapshot should include %s state." % stream_key)
		assert_true(stream_state.has("draw_index"), "RNG snapshot should include %s draw index." % stream_key)
		assert_true(stream_state.get("seed") is int, "RNG snapshot %s seed should be integer data." % stream_key)
		assert_true(stream_state.get("state") is int, "RNG snapshot %s state should be integer data." % stream_key)
		assert_true(stream_state.get("draw_index") is int, "RNG snapshot %s draw index should be integer data." % stream_key)
	assert_equal(stream_states.get("combat").get("draw_index"), 1, "RNG snapshot should count successful combat draws.")
	assert_equal(stream_states.get("loot").get("draw_index"), 0, "RNG snapshot should keep untouched stream draw index at zero.")


func _try_restore_rejects_malformed_snapshots_without_mutation() -> void:
	var streams: RngStreamSet = RngStreamSet.new(888)
	_roll_int(streams, RngStreamSet.STREAM_COMBAT, 1, 100)
	var before: Dictionary = streams.to_snapshot()
	var valid_snapshot: Dictionary = streams.to_snapshot()
	var malformed_snapshots: Array[Dictionary] = [
		{},
		{"root_seed": 888},
		_snapshot_missing_stream(valid_snapshot, RngStreamSet.STREAM_COMBAT),
		_snapshot_with_stream_value(valid_snapshot, RngStreamSet.STREAM_COMBAT, 7),
		_snapshot_with_stream_field(valid_snapshot, RngStreamSet.STREAM_COMBAT, "seed", "bad"),
		_snapshot_with_stream_field(valid_snapshot, RngStreamSet.STREAM_COMBAT, "state", []),
		_snapshot_with_stream_field(valid_snapshot, RngStreamSet.STREAM_COMBAT, "draw_index", -1)
	]

	for malformed_snapshot: Dictionary in malformed_snapshots:
		var result_value: ActionResult = streams.try_restore(malformed_snapshot)
		assert_true(result_value.is_error(), "Malformed RNG snapshot should return a deterministic error.")
		assert_equal(result_value.error_code, &"invalid_rng_snapshot", "Malformed RNG snapshot should use the stable restore error code.")
		assert_equal(streams.to_snapshot(), before, "Malformed RNG snapshot restore should not mutate existing stream state.")


func _try_restore_replays_next_roll_for_every_stream() -> void:
	for stream_name: StringName in RngStreamSet.required_streams():
		var original: RngStreamSet = RngStreamSet.new(777)
		_roll_int(original, stream_name, 1, 100)
		_roll_float(original, stream_name)
		var snapshot: Dictionary = original.to_snapshot()
		var expected_next_roll: int = _roll_int(original, stream_name, 1, 100)

		var restored: RngStreamSet = RngStreamSet.new(0)
		var restore_result: ActionResult = restored.try_restore(snapshot)

		assert_true(restore_result.succeeded, "Valid RNG snapshot should restore %s stream." % String(stream_name))
		assert_equal(_roll_int(restored, stream_name, 1, 100), expected_next_roll, "Restored %s stream should match uninterrupted next roll." % String(stream_name))
		assert_equal(restored.to_snapshot().get("streams").get(String(stream_name)).get("draw_index"), snapshot.get("streams").get(String(stream_name)).get("draw_index") + 1, "Restored %s stream should continue draw indexes." % String(stream_name))


func _invalid_stream_names_do_not_mutate_known_streams() -> void:
	var invalid_streams: Array[StringName] = [
		&"combta",
		&"",
		&"combat "
	]

	for stream_name: StringName in invalid_streams:
		var streams: RngStreamSet = RngStreamSet.new(44)
		var before: Dictionary = streams.to_snapshot()

		var result_value: ActionResult = streams.rand_int(stream_name, 1, 100)
		var after: Dictionary = streams.to_snapshot()

		assert_true(result_value.is_error(), "Invalid RNG stream %s should return an explicit error." % String(stream_name))
		assert_equal(result_value.error_code, &"unknown_rng_stream", "Invalid RNG stream %s should explain the failure." % String(stream_name))
		assert_false(_metadata_has_draw_audit(result_value.metadata), "Invalid RNG stream %s should not emit successful draw audit metadata." % String(stream_name))
		assert_equal(after, before, "Invalid RNG stream %s should not mutate any named stream." % String(stream_name))


func _invalid_int_ranges_do_not_mutate_or_emit_draw_audit() -> void:
	var streams: RngStreamSet = RngStreamSet.new(999)
	var before: Dictionary = streams.to_snapshot()

	var result_value: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 10, 1, {"system": "combat"})
	var after: Dictionary = streams.to_snapshot()

	assert_true(result_value.is_error(), "Invalid RNG integer range should return an explicit error.")
	assert_equal(result_value.error_code, &"invalid_rng_range", "Invalid RNG integer range should use a stable error code.")
	assert_false(_metadata_has_draw_audit(result_value.metadata), "Invalid RNG integer range should not emit successful draw audit metadata.")
	assert_equal(after, before, "Invalid RNG integer range should not mutate any named stream.")

	var valid_single_value: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 4, 4, {"system": "combat"})
	assert_true(valid_single_value.succeeded, "Equal integer range bounds should remain a valid deterministic draw.")
	assert_equal(valid_single_value.metadata.get("value"), 4, "Equal integer range bounds should return the bound value.")


func _cyclic_consumer_context_does_not_mutate_or_emit_draw_audit() -> void:
	var streams: RngStreamSet = RngStreamSet.new(1122)
	var consumer_context: Dictionary = {"system": "combat"}
	consumer_context["self"] = consumer_context
	var before: Dictionary = streams.to_snapshot()

	var result_value: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, consumer_context)
	var after: Dictionary = streams.to_snapshot()

	assert_true(result_value.is_error(), "Cyclic RNG consumer context should return an explicit error.")
	assert_equal(result_value.error_code, &"invalid_rng_consumer_context", "Cyclic RNG consumer context should use a stable error code.")
	assert_false(_metadata_has_draw_audit(result_value.metadata), "Cyclic RNG consumer context should not emit successful draw audit metadata.")
	assert_equal(after, before, "Cyclic RNG consumer context should not mutate any named stream.")


func _deterministic_gameplay_draw_sequence_replays_from_snapshot() -> void:
	var initial_streams: RngStreamSet = RngStreamSet.new(13579)
	var initial_snapshot: Dictionary = initial_streams.to_snapshot()

	var first_run: Dictionary = _run_gameplay_draw_fixture(initial_snapshot, false)
	var second_run: Dictionary = _run_gameplay_draw_fixture(initial_snapshot, false)

	assert_equal(first_run.get("values"), second_run.get("values"), "Gameplay RNG fixture should replay draw values from the same snapshot.")
	assert_equal(first_run.get("metadata"), second_run.get("metadata"), "Gameplay RNG fixture should replay audit metadata from the same snapshot.")
	assert_equal(first_run.get("gameplay_snapshot"), second_run.get("gameplay_snapshot"), "Gameplay RNG fixture should replay gameplay stream snapshots from the same snapshot.")
	assert_equal(first_run.get("events"), second_run.get("events"), "Standalone RNG draws should return stable ordered event arrays.")
	assert_equal(first_run.get("events"), [[], [], [], [], [], []], "Standalone RNG draws should not emit gameplay outcome events.")


func _cosmetic_draws_do_not_change_gameplay_draw_replay() -> void:
	var initial_streams: RngStreamSet = RngStreamSet.new(24680)
	var initial_snapshot: Dictionary = initial_streams.to_snapshot()

	var no_cosmetic: Dictionary = _run_gameplay_draw_fixture(initial_snapshot, false)
	var with_cosmetic: Dictionary = _run_gameplay_draw_fixture(initial_snapshot, true)

	assert_equal(with_cosmetic.get("values"), no_cosmetic.get("values"), "Cosmetic draws should not change gameplay RNG fixture values.")
	assert_equal(with_cosmetic.get("metadata"), no_cosmetic.get("metadata"), "Cosmetic draws should not change gameplay RNG audit metadata.")
	assert_equal(with_cosmetic.get("gameplay_snapshot"), no_cosmetic.get("gameplay_snapshot"), "Cosmetic draws should not change gameplay stream snapshots.")
	assert_equal(with_cosmetic.get("events"), no_cosmetic.get("events"), "Cosmetic draws should not change gameplay RNG event arrays.")


func _roll_int(streams: RngStreamSet, stream_name: StringName, minimum: int, maximum: int) -> int:
	var result_value: ActionResult = streams.rand_int(stream_name, minimum, maximum)
	assert_true(result_value.succeeded, "Known RNG stream should return a value.")
	return int(result_value.metadata.get("value", 0))


func _roll_float(streams: RngStreamSet, stream_name: StringName) -> float:
	var result_value: ActionResult = streams.rand_float(stream_name)
	assert_true(result_value.succeeded, "Known RNG stream should return a float value.")
	return float(result_value.metadata.get("value", 0.0))


func _snapshot_missing_stream(snapshot: Dictionary, stream_name: StringName) -> Dictionary:
	var copy: Dictionary = snapshot.duplicate(true)
	copy.get("streams").erase(String(stream_name))
	return copy


func _snapshot_with_stream_value(snapshot: Dictionary, stream_name: StringName, value: Variant) -> Dictionary:
	var copy: Dictionary = snapshot.duplicate(true)
	copy.get("streams")[String(stream_name)] = value
	return copy


func _snapshot_with_stream_field(snapshot: Dictionary, stream_name: StringName, field_name: String, value: Variant) -> Dictionary:
	var copy: Dictionary = snapshot.duplicate(true)
	copy.get("streams").get(String(stream_name))[field_name] = value
	return copy


func _metadata_has_draw_audit(metadata: Dictionary) -> bool:
	var audit_keys: Array[String] = [
		"value",
		"stream_name",
		"draw_index",
		"state_before",
		"state_after",
		"draw_type",
		"consumer_context"
	]
	for key: String in audit_keys:
		if metadata.has(key):
			return true
	return false


func _run_gameplay_draw_fixture(initial_snapshot: Dictionary, include_cosmetic_draws: bool) -> Dictionary:
	var streams: RngStreamSet = RngStreamSet.new(0)
	var restore_result: ActionResult = streams.try_restore(initial_snapshot)
	assert_true(restore_result.succeeded, "Gameplay RNG fixture should restore initial snapshot.")

	var draw_plan: Array[Dictionary] = [
		{"stream": RngStreamSet.STREAM_MAP, "type": "int", "minimum": 1, "maximum": 20, "context": {"system": "map", "consumer": "fixture_route"}},
		{"stream": RngStreamSet.STREAM_LEVEL, "type": "int", "minimum": 1, "maximum": 50, "context": {"system": "level", "consumer": "fixture_layout"}},
		{"stream": RngStreamSet.STREAM_COMBAT, "type": "int", "minimum": 1, "maximum": 6, "context": {"system": "combat", "consumer": "fixture_proc"}},
		{"stream": RngStreamSet.STREAM_LOOT, "type": "int", "minimum": 1, "maximum": 100, "context": {"system": "loot", "consumer": "fixture_drop"}},
		{"stream": RngStreamSet.STREAM_REWARDS, "type": "float", "context": {"system": "rewards", "consumer": "fixture_offer"}},
		{"stream": RngStreamSet.STREAM_EVENTS, "type": "int", "minimum": 1, "maximum": 12, "context": {"system": "events", "consumer": "fixture_event"}}
	]
	var values: Array = []
	var metadata: Array = []
	var events: Array = []

	for draw_index: int in range(draw_plan.size()):
		if include_cosmetic_draws:
			streams.rand_float(RngStreamSet.STREAM_COSMETIC, {"system": "cosmetic", "consumer": "fixture_between_draws", "index": draw_index})

		var draw: Dictionary = draw_plan[draw_index]
		var result_value: ActionResult
		if draw.get("type") == "int":
			result_value = streams.rand_int(draw.get("stream"), int(draw.get("minimum")), int(draw.get("maximum")), draw.get("context"))
		else:
			result_value = streams.rand_float(draw.get("stream"), draw.get("context"))

		assert_true(result_value.succeeded, "Gameplay RNG fixture draw should succeed.")
		values.append(result_value.metadata.get("value"))
		metadata.append(result_value.metadata.duplicate(true))
		events.append(result_value.events.duplicate())

	return {
		"values": values,
		"metadata": metadata,
		"events": events,
		"gameplay_snapshot": _gameplay_stream_snapshot(streams.to_snapshot())
	}


func _gameplay_stream_snapshot(snapshot: Dictionary) -> Dictionary:
	var gameplay_streams: Dictionary = {}
	var stream_states: Dictionary = snapshot.get("streams")
	for stream_name: StringName in RngStreamSet.required_streams():
		if stream_name == RngStreamSet.STREAM_COSMETIC:
			continue
		var stream_key: String = String(stream_name)
		gameplay_streams[stream_key] = stream_states.get(stream_key).duplicate(true)
	return {
		"root_seed": snapshot.get("root_seed"),
		"streams": gameplay_streams
	}
