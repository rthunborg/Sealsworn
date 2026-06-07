extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const Epic1MicroCombatScenario = preload("res://scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd")

func run() -> Dictionary:
	_scripted_win_path_reaches_victory_with_explanations()
	_scripted_loss_path_reaches_defeat_with_cause()
	_scenario_replay_is_deterministic_without_timing()
	_timing_records_are_development_gated_and_event_neutral()
	return result()


func _scripted_win_path_reaches_victory_with_explanations() -> void:
	var result_value: ActionResult = Epic1MicroCombatScenario.new().run_win_path()
	var event_ids: Array[String] = _event_ids(result_value.events)
	var entries: Array = result_value.metadata.get("explanation_entries", [])
	var weapons_used: Array = result_value.metadata.get("weapons_used", [])

	assert_true(result_value.succeeded, "Win path should run headlessly.")
	assert_equal(result_value.metadata.get("outcome"), "victory", "Win path should reach victory.")
	assert_true(event_ids.has("visibility_updated"), "Scenario should include fog/visibility updates.")
	assert_true(event_ids.has("entity_moved"), "Scenario should drive at least one move command.")
	assert_true(event_ids.has("entity_attacked"), "Scenario should drive attack commands.")
	assert_true(event_ids.has("tile_marked"), "Scenario should include Ash Seer mark events.")
	assert_true(event_ids.has("marked_tile_detonated"), "Scenario should include Ash Seer detonation events.")
	assert_true(event_ids.has("level_victory_reached"), "Scenario should emit a victory outcome event.")
	assert_true(weapons_used.has("sword"), "Scenario should use sword attack shape.")
	assert_true(weapons_used.has("staff"), "Scenario should use staff attack shape.")
	assert_true(entries.size() >= result_value.events.size(), "Scenario should produce enough explanation entries for the event log.")
	assert_equal(result_value.metadata.get("enemy_count"), 2, "Scenario should include two prototype enemies.")


func _scripted_loss_path_reaches_defeat_with_cause() -> void:
	var result_value: ActionResult = Epic1MicroCombatScenario.new().run_loss_path()
	var event_ids: Array[String] = _event_ids(result_value.events)
	var outcome_event: DomainEvent = result_value.events[result_value.events.size() - 1]

	assert_true(result_value.succeeded, "Loss path should run headlessly.")
	assert_equal(result_value.metadata.get("outcome"), "defeat", "Loss path should reach defeat.")
	assert_true(event_ids.has("level_defeat_reached"), "Loss path should emit a defeat outcome event.")
	assert_equal(outcome_event.payload.get("defeated_player_id"), "hero", "Defeat outcome should identify the hero.")
	assert_equal(outcome_event.payload.get("cause_event_id"), "damage_applied", "Defeat outcome should preserve damage cause metadata.")
	assert_true(int(outcome_event.payload.get("final_damage", 0)) > 0, "Defeat outcome should record final damage.")


func _scenario_replay_is_deterministic_without_timing() -> void:
	var first: ActionResult = Epic1MicroCombatScenario.new().run_win_path()
	var second: ActionResult = Epic1MicroCombatScenario.new().run_win_path()

	assert_true(first.succeeded, "First deterministic scenario run should succeed.")
	assert_true(second.succeeded, "Second deterministic scenario run should succeed.")
	assert_equal(_event_dictionaries(first.events), _event_dictionaries(second.events), "Scenario event logs should be reproducible.")
	assert_equal(first.metadata.get("explanation_entries"), second.metadata.get("explanation_entries"), "Scenario explanations should be reproducible.")
	assert_equal(first.metadata.get("outcome_state"), second.metadata.get("outcome_state"), "Scenario outcome snapshots should be reproducible.")
	assert_equal(first.metadata.get("timing_records"), [], "Timing should be disabled by default.")


func _timing_records_are_development_gated_and_event_neutral() -> void:
	var without_timing: ActionResult = Epic1MicroCombatScenario.new().run_win_path(false)
	var with_timing: ActionResult = Epic1MicroCombatScenario.new().run_win_path(true)
	var timing_records: Array = with_timing.metadata.get("timing_records", [])

	assert_true(with_timing.succeeded, "Timing-enabled scenario should still run.")
	assert_equal(_event_dictionaries(with_timing.events), _event_dictionaries(without_timing.events), "Timing instrumentation must not affect domain events.")
	assert_true(timing_records.size() > 0, "Timing-enabled scenario should record local timing data.")
	assert_false(without_timing.metadata.get("timing_records", []).size() > 0, "Timing should remain disabled unless explicitly requested.")


func _event_ids(events: Array[DomainEvent]) -> Array[String]:
	var result: Array[String] = []
	for event: DomainEvent in events:
		result.append(String(DomainEvent.id_for_type(event.event_type)))
	return result


func _event_dictionaries(events: Array[DomainEvent]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: DomainEvent in events:
		result.append(event.to_dictionary())
	return result
