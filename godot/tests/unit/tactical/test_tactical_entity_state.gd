extends "res://tests/unit/test_case.gd"

const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

func run() -> Dictionary:
	_entity_dictionary_round_trips()
	_invalid_entity_dictionary_returns_action_result()
	_alive_and_dead_queries_use_hp()
	return result()


func _entity_dictionary_round_trips() -> void:
	var entity: TacticalEntityState = TacticalEntityState.new(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(2, 3),
		12,
		18,
		true
	)

	var parse_result: ActionResult = TacticalEntityState.try_from_dictionary(entity.to_dictionary())
	var restored: TacticalEntityState = parse_result.metadata.get("entity") as TacticalEntityState

	assert_true(parse_result.succeeded, "Valid entity dictionaries should parse successfully.")
	assert_equal(restored.entity_id, &"hero", "Entity snapshot should preserve id.")
	assert_equal(restored.entity_type, TacticalEntityState.EntityType.PLAYER, "Entity snapshot should preserve type.")
	assert_equal(restored.faction, &"player", "Entity snapshot should preserve faction.")
	assert_equal(restored.position, Vector2i(2, 3), "Entity snapshot should preserve position.")
	assert_equal(restored.current_hp, 12, "Entity snapshot should preserve current HP.")
	assert_equal(restored.max_hp, 18, "Entity snapshot should preserve max HP.")
	assert_true(restored.blocks_movement, "Entity snapshot should preserve movement blocking.")
	assert_true(restored.is_alive(), "Positive HP entities should be alive.")


func _invalid_entity_dictionary_returns_action_result() -> void:
	var parse_result: ActionResult = TacticalEntityState.try_from_dictionary({
		"entity_id": "",
		"entity_type": "player",
		"faction": "player",
		"position": {"x": 0, "y": 0},
		"current_hp": 19,
		"max_hp": 18,
		"blocks_movement": true
	})
	var invalid_type_result: ActionResult = TacticalEntityState.try_from_dictionary({
		"entity_id": "hero",
		"entity_type": 999,
		"faction": "player",
		"position": {"x": 0, "y": 0},
		"current_hp": 18,
		"max_hp": 18,
		"blocks_movement": true
	})
	var missing_position_result: ActionResult = TacticalEntityState.try_from_dictionary({
		"entity_id": "hero",
		"entity_type": "player",
		"faction": "player",
		"position": {"y": 0},
		"current_hp": 18,
		"max_hp": 18,
		"blocks_movement": true
	})
	var string_hp_result: ActionResult = TacticalEntityState.try_from_dictionary({
		"entity_id": "hero",
		"entity_type": "player",
		"faction": "player",
		"position": {"x": 0, "y": 0},
		"current_hp": "18",
		"max_hp": 18,
		"blocks_movement": true
	})
	var string_blocks_result: ActionResult = TacticalEntityState.try_from_dictionary({
		"entity_id": "hero",
		"entity_type": "player",
		"faction": "player",
		"position": {"x": 0, "y": 0},
		"current_hp": 18,
		"max_hp": 18,
		"blocks_movement": "true"
	})

	assert_true(parse_result.is_error(), "Invalid entity data should be reported through ActionResult.")
	assert_equal(parse_result.error_code, &"invalid_entity_data", "Invalid entity data should use a stable error code.")
	assert_true(invalid_type_result.is_error(), "Unsupported numeric entity types should be rejected.")
	assert_equal(invalid_type_result.error_code, &"invalid_entity_data", "Unsupported entity types should use a stable error code.")
	assert_true(missing_position_result.is_error(), "Missing position coordinates should be rejected.")
	assert_equal(missing_position_result.error_code, &"invalid_entity_data", "Malformed positions should use a stable error code.")
	assert_true(string_hp_result.is_error(), "String HP fields should not be coerced into valid data.")
	assert_equal(string_hp_result.error_code, &"invalid_entity_data", "Malformed HP fields should use a stable error code.")
	assert_true(string_blocks_result.is_error(), "String movement flags should not be coerced into valid data.")
	assert_equal(string_blocks_result.error_code, &"invalid_entity_data", "Malformed movement flags should use a stable error code.")


func _alive_and_dead_queries_use_hp() -> void:
	var entity: TacticalEntityState = TacticalEntityState.new(
		&"defeated_enemy",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(1, 1),
		0,
		10,
		true
	)

	assert_false(entity.is_alive(), "Zero HP entities should not be alive.")
	assert_true(entity.is_dead(), "Zero HP entities should be dead.")
