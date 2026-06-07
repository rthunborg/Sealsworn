extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

func run() -> Dictionary:
	_valid_snapshot_exports_schema_and_domain_data_only()
	_snapshot_to_dictionary_deep_copies_nested_data()
	_parse_rejects_invalid_schema_and_containers()
	_parse_rejects_forbidden_references()
	_parse_rejects_invalid_event_log_and_rng_without_mutating_sources()
	_from_domain_rejects_desynchronized_board()
	_from_domain_round_trips_board_rng_and_event_log()
	_restore_and_continue_is_deterministic_after_snapshot()
	_invalid_command_no_mutation_helper_uses_tactical_snapshots()
	_ash_seer_pending_mark_shape_is_serializable_save_truth()
	return result()


func _valid_snapshot_exports_schema_and_domain_data_only() -> void:
	var snapshot: TacticalSnapshot = _create_domain_snapshot()
	var data: Dictionary = snapshot.to_dictionary()

	assert_equal(data.get("schema_version"), TacticalSnapshot.SCHEMA_VERSION, "TacticalSnapshot should export the current schema version.")
	assert_equal(data.get("content_version"), "mvp-0", "TacticalSnapshot should export the MVP content version.")
	assert_true(data.get("board") is Dictionary, "TacticalSnapshot should include board domain data.")
	assert_true(data.get("turn_state") is Dictionary, "TacticalSnapshot should include turn-state domain data.")
	assert_true(data.get("pending_telegraphs") is Array, "TacticalSnapshot should include pending telegraph data.")
	assert_true(data.get("rng_streams") is Dictionary, "TacticalSnapshot should include named RNG stream snapshots.")
	assert_true(data.get("event_log") is Array, "TacticalSnapshot should include ordered domain event dictionaries.")
	assert_true(_is_json_compatible(data), "TacticalSnapshot output should contain JSON-compatible primitives, arrays, and dictionaries only.")
	assert_false(_contains_forbidden_reference(data), "TacticalSnapshot output must not include scene, UI, audio, animation, or presentation references.")
	assert_true(JSON.parse_string(JSON.stringify(data)) is Dictionary, "TacticalSnapshot output should survive JSON stringify/parse.")


func _snapshot_to_dictionary_deep_copies_nested_data() -> void:
	var snapshot: TacticalSnapshot = _create_domain_snapshot()
	var exported: Dictionary = snapshot.to_dictionary()
	var cells: Array = exported.get("board").get("cells")
	var streams: Dictionary = exported.get("rng_streams").get("streams")
	var pending: Array = exported.get("pending_telegraphs")

	cells[0]["terrain"] = 999
	streams.get("combat")["draw_index"] = 999
	pending[0]["source_id"] = "mutated"

	var fresh_export: Dictionary = snapshot.to_dictionary()
	assert_false(fresh_export.get("board").get("cells")[0].get("terrain") == 999, "Board dictionaries exported from TacticalSnapshot should be deep copies.")
	assert_false(fresh_export.get("rng_streams").get("streams").get("combat").get("draw_index") == 999, "RNG dictionaries exported from TacticalSnapshot should be deep copies.")
	assert_equal(fresh_export.get("pending_telegraphs")[0].get("source_id"), "ash_seer", "Pending telegraphs exported from TacticalSnapshot should be deep copies.")


func _parse_rejects_invalid_schema_and_containers() -> void:
	_assert_invalid_tactical_snapshot(_snapshot_without_field("schema_version"), "Missing schema version should be rejected.")
	_assert_invalid_tactical_snapshot(_snapshot_with_field("schema_version", TacticalSnapshot.SCHEMA_VERSION + 1), "Unsupported schema version should be rejected.")
	_assert_invalid_tactical_snapshot(_snapshot_with_field("content_version", "future-content"), "Unsupported content versions should be rejected.")
	_assert_invalid_tactical_snapshot(_snapshot_with_field("board", []), "Malformed board container should be rejected.")
	_assert_invalid_tactical_snapshot(_snapshot_with_field("turn_state", []), "Malformed turn-state container should be rejected.")
	_assert_invalid_tactical_snapshot(_snapshot_with_field("pending_telegraphs", {}), "Malformed pending telegraph container should be rejected.")
	_assert_invalid_tactical_snapshot(_snapshot_with_field("event_log", {}), "Malformed event-log container should be rejected.")


func _parse_rejects_forbidden_references() -> void:
	var object_data: Dictionary = _valid_snapshot_dictionary()
	object_data["turn_state"]["object_ref"] = RefCounted.new()

	var callable_data: Dictionary = _valid_snapshot_dictionary()
	callable_data["turn_state"]["callback"] = Callable(self, "run")

	var scene_path_data: Dictionary = _valid_snapshot_dictionary()
	scene_path_data["pending_telegraphs"][0]["presentation_scene"] = "res://scenes/ui/bad_panel.tscn"
	var animation_path_data: Dictionary = _valid_snapshot_dictionary()
	animation_path_data["turn_state"]["animation_ref"] = "res://assets/animation/hit.anim"

	_assert_invalid_tactical_snapshot(object_data, "Object references should be rejected from tactical snapshots.")
	_assert_invalid_tactical_snapshot(callable_data, "Callable references should be rejected from tactical snapshots.")
	_assert_invalid_tactical_snapshot(scene_path_data, "Scene and presentation paths should be rejected from tactical snapshots.")
	_assert_invalid_tactical_snapshot(animation_path_data, "Animation and asset resource paths should be rejected from tactical snapshots.")


func _parse_rejects_invalid_event_log_and_rng_without_mutating_sources() -> void:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(2026)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	var board_before: Dictionary = board.to_snapshot()
	var rng_before: Dictionary = streams.to_snapshot()

	var invalid_event_log: Dictionary = _snapshot_dictionary_from_domain(board, streams)
	invalid_event_log["event_log"] = [{
		"event_id": "future_event",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {}
	}]
	_assert_invalid_tactical_snapshot(invalid_event_log, "Malformed event-log entries should reject the whole tactical snapshot.")

	var invalid_rng: Dictionary = _snapshot_dictionary_from_domain(board, streams)
	invalid_rng.get("rng_streams").get("streams").get("combat")["draw_index"] = -1
	_assert_invalid_tactical_snapshot(invalid_rng, "Malformed RNG stream snapshots should reject the whole tactical snapshot.")
	var infinite_turn_state: Dictionary = _snapshot_dictionary_from_domain(board, streams)
	infinite_turn_state["turn_state"]["bad_float"] = INF
	_assert_invalid_tactical_snapshot(infinite_turn_state, "Non-finite floats should be rejected from tactical snapshots.")

	assert_equal(board.to_snapshot(), board_before, "Failed tactical snapshot parsing must not mutate the source board object.")
	assert_equal(streams.to_snapshot(), rng_before, "Failed tactical snapshot parsing must not mutate the source RNG object.")


func _from_domain_rejects_desynchronized_board() -> void:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(9090)
	var rng_before: Dictionary = streams.to_snapshot()

	board.get_cell(Vector2i(0, 0)).occupant_id = &"ghost"
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams)
	var position_desynced_board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var position_desynced_streams: RngStreamSet = RngStreamSet.new(9091)
	position_desynced_board.get_cell(Vector2i(0, 0)).position = Vector2i(1, 0)
	var position_result: ActionResult = TacticalSnapshot.from_domain(position_desynced_board, position_desynced_streams)

	assert_true(result_value.is_error(), "TacticalSnapshot.from_domain should reject desynchronized board occupancy.")
	assert_equal(result_value.error_code, &"invalid_tactical_snapshot", "Desynchronized board exports should fail at the tactical snapshot boundary.")
	assert_false(result_value.metadata.has("snapshot"), "Rejected tactical snapshot exports must not expose a partial snapshot object.")
	assert_equal(streams.to_snapshot(), rng_before, "Rejected tactical snapshot exports must not mutate RNG streams.")
	assert_true(position_result.is_error(), "TacticalSnapshot.from_domain should reject source boards whose cell positions disagree with their storage keys.")
	assert_equal(position_result.metadata.get("source_error_code"), "invalid_board_cell_storage", "Cell storage desynchronization should surface as a board validation error.")


func _from_domain_round_trips_board_rng_and_event_log() -> void:
	var snapshot: TacticalSnapshot = _create_domain_snapshot()
	var data: Dictionary = snapshot.to_dictionary()
	var parse_result: ActionResult = TacticalSnapshot.parse(data)
	var parsed: TacticalSnapshot = parse_result.metadata.get("snapshot") as TacticalSnapshot
	var board_result: ActionResult = BoardState.try_from_snapshot(parsed.board)
	var restored_streams: RngStreamSet = RngStreamSet.new(0)
	var rng_result: ActionResult = restored_streams.try_restore(parsed.rng_streams)

	assert_true(parse_result.succeeded, "TacticalSnapshot should parse its own exported dictionary.")
	assert_true(board_result.succeeded, "Parsed tactical snapshots should contain restorable board snapshots.")
	assert_true(rng_result.succeeded, "Parsed tactical snapshots should contain restorable RNG stream snapshots.")
	assert_equal(parsed.event_log.size(), 2, "TacticalSnapshot should preserve ordered event-log entries.")
	assert_equal(parsed.event_log[0].get("event_id"), "board_created", "TacticalSnapshot should preserve event-log ordering.")
	assert_equal(parsed.event_log[1].get("event_id"), "rng_stream_advanced", "TacticalSnapshot should preserve event-log ordering exactly.")


func _restore_and_continue_is_deterministic_after_snapshot() -> void:
	var original_board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var original_streams: RngStreamSet = RngStreamSet.new(777)
	original_streams.rand_int(RngStreamSet.STREAM_MAP, 1, 20, {"system": "map"})
	original_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	original_streams.rand_float(RngStreamSet.STREAM_REWARDS, {"system": "rewards"})
	var snapshot_data: Dictionary = _snapshot_dictionary_from_domain(original_board, original_streams)

	var parsed_result: ActionResult = TacticalSnapshot.parse(snapshot_data)
	var parsed: TacticalSnapshot = parsed_result.metadata.get("snapshot") as TacticalSnapshot
	var restored_board: BoardState = (BoardState.try_from_snapshot(parsed.board).metadata.get("board") as BoardState)
	var restored_streams: RngStreamSet = RngStreamSet.new(0)
	var rng_result: ActionResult = restored_streams.try_restore(parsed.rng_streams)

	var original_result: ActionResult = CreateBoardCommand.new(9, 9).execute(original_board)
	var restored_result: ActionResult = CreateBoardCommand.new(9, 9).execute(restored_board)
	var original_draw: ActionResult = original_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat", "consumer": "restore_check"})
	var restored_draw: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat", "consumer": "restore_check"})

	assert_true(parsed_result.succeeded, "Valid tactical snapshot should parse before deterministic continuation.")
	assert_true(rng_result.succeeded, "Valid tactical snapshot should restore RNG streams before deterministic continuation.")
	assert_true(original_result.is_error(), "Duplicate CreateBoardCommand should fail on the original board.")
	assert_equal(restored_result.error_code, original_result.error_code, "Restored board should reject the same next command with the same error.")
	assert_equal(_event_dictionaries(restored_result.events), _event_dictionaries(original_result.events), "Restored and original failed commands should expose matching ordered events.")
	assert_equal(restored_result.events.size(), 0, "Failed commands after restore should emit zero past-tense domain events.")
	assert_true(original_draw.succeeded, "Original gameplay RNG draw after snapshot should succeed.")
	assert_true(restored_draw.succeeded, "Restored gameplay RNG draw after snapshot should succeed.")
	assert_equal(_snapshot_dictionary_from_domain(restored_board, restored_streams), _snapshot_dictionary_from_domain(original_board, original_streams), "Original and restored tactical snapshots should match after the same failed command and RNG draw.")
	assert_equal(restored_draw.metadata, original_draw.metadata, "Original and restored gameplay RNG draws should preserve value and audit metadata.")


func _invalid_command_no_mutation_helper_uses_tactical_snapshots() -> void:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(3030)
	var before: Dictionary = _snapshot_dictionary_from_domain(board, streams)
	var sequence_before: int = board.next_sequence_id()
	var rng_before: Dictionary = streams.to_snapshot()

	var result_value: ActionResult = CreateBoardCommand.new(4, 3).execute(board)
	var after: Dictionary = _snapshot_dictionary_from_domain(board, streams)

	assert_true(result_value.is_error(), "Duplicate CreateBoardCommand should fail validation.")
	assert_false(result_value.has_events(), "Failed commands should expose no past-tense domain events.")
	assert_equal(after, before, "Top-level tactical snapshots should prove invalid commands do not mutate domain state.")
	assert_equal(board.next_sequence_id(), sequence_before, "Failed commands should not advance board sequence ids.")
	assert_equal(streams.to_snapshot(), rng_before, "Failed commands should not advance gameplay RNG stream states.")


func _ash_seer_pending_mark_shape_is_serializable_save_truth() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var streams: RngStreamSet = RngStreamSet.new(4040)
	var pending_telegraphs: Array[Dictionary] = [{
		"telegraph_id": "ash_seer_mark:enemy_seer:2",
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"target_entity_id": "hero",
		"marked_cell": {"x": 1, "y": 2},
		"created_turn_number": 1,
		"due_turn_number": 2,
		"damage": 4,
		"damage_type": "physical",
		"status": "pending"
	}]

	var snapshot_result: ActionResult = TacticalSnapshot.from_domain(board, streams, {}, pending_telegraphs, [])
	var snapshot: TacticalSnapshot = snapshot_result.metadata.get("snapshot") as TacticalSnapshot
	var parse_result: ActionResult = TacticalSnapshot.parse(snapshot.to_dictionary())

	assert_true(snapshot_result.succeeded, "Ash Seer pending marks should export through TacticalSnapshot.")
	assert_true(parse_result.succeeded, "Ash Seer pending marks should parse back from TacticalSnapshot.")
	assert_equal(snapshot.pending_telegraphs[0].get("kind"), "ash_seer_mark", "Pending mark should preserve stable kind.")
	assert_equal(snapshot.pending_telegraphs[0].get("marked_cell"), {"x": 1, "y": 2}, "Pending mark should preserve target cell.")
	assert_true(_is_json_compatible(snapshot.to_dictionary()), "Pending mark snapshots should stay JSON-compatible.")
	assert_false(_contains_forbidden_reference(snapshot.to_dictionary()), "Pending marks must not include scene, audio, animation, or presentation references.")


func _create_domain_snapshot() -> TacticalSnapshot:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	board.get_cell(Vector2i(0, 0)).visible = true
	board.get_cell(Vector2i(0, 0)).explored = true
	var streams: RngStreamSet = RngStreamSet.new(1234)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat", "consumer": "fixture"})
	streams.rand_float(RngStreamSet.STREAM_REWARDS, {"system": "rewards", "consumer": "fixture"})
	var turn_state: Dictionary = {"turn_number": 2, "active_actor_id": "hero"}
	var pending_telegraphs: Array[Dictionary] = [{
		"source_id": "ash_seer",
		"target": {"x": 1, "y": 1},
		"turns_remaining": 1
	}]
	var events: Array[DomainEvent] = [
		DomainEvent.board_created(1, board.width, board.height),
		DomainEvent.new(DomainEvent.Type.RNG_STREAM_ADVANCED, 2, &"combat_rng", {"stream_id": "combat"})
	]
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state, pending_telegraphs, events)
	assert_true(result_value.succeeded, "Test helper should create a valid tactical snapshot.")
	return result_value.metadata.get("snapshot") as TacticalSnapshot


func _valid_snapshot_dictionary() -> Dictionary:
	return _create_domain_snapshot().to_dictionary()


func _snapshot_dictionary_from_domain(board: BoardState, streams: RngStreamSet) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(result_value.succeeded, "Test helper should export a tactical snapshot from domain state.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()


func _snapshot_without_field(field_name: String) -> Dictionary:
	var data: Dictionary = _valid_snapshot_dictionary()
	data.erase(field_name)
	return data


func _snapshot_with_field(field_name: String, value: Variant) -> Dictionary:
	var data: Dictionary = _valid_snapshot_dictionary()
	data[field_name] = value
	return data


func _assert_invalid_tactical_snapshot(data: Dictionary, message: String) -> void:
	var result_value: ActionResult = TacticalSnapshot.parse(data)
	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, &"invalid_tactical_snapshot", message)
	assert_false(result_value.metadata.has("snapshot"), "Rejected tactical snapshots must not expose a partial snapshot object.")


func _event_dictionaries(events: Array[DomainEvent]) -> Array[Dictionary]:
	var result_value: Array[Dictionary] = []
	for event: DomainEvent in events:
		result_value.append(event.to_dictionary())
	return result_value


func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _is_json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if typeof(key) != TYPE_STRING:
					return false
				if not _is_json_compatible(value[key]):
					return false
			return true
		_:
			return false


func _contains_forbidden_reference(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING:
			var text: String = value
			return text.begins_with("res://scenes/") or text.ends_with(".tscn") or text.contains("presentation")
		TYPE_ARRAY:
			for item: Variant in value:
				if _contains_forbidden_reference(item):
					return true
			return false
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if _contains_forbidden_reference(value[key]):
					return true
			return false
		_:
			return false
