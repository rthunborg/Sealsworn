extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackPreviewContractMatrix = preload("res://tests/fixtures/tactical/attack_preview_contract_matrix.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_legal_previews_report_stable_metadata_from_repository_definitions()
	_core_validation_reasons_follow_stable_order()
	_invalid_previews_report_stable_reasons_without_mutation()
	_target_entity_previews_do_not_leak_hidden_target_facts()
	_target_cell_previews_reject_stale_occupant_links()
	_wand_ignores_blockers_but_still_requires_visibility()
	_ranged_adjacency_penalties_update_damage_and_warning_text()
	_preview_is_pure_and_repeated_metadata_is_deterministic()
	_story_1_9_contract_matrix_matches_preview_results()
	_cleared_corpse_cell_is_non_targetable()
	return result()


func _legal_previews_report_stable_metadata_from_repository_definitions() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	var board: BoardState = BoardFixtureFactory.attack_preview_open_lane()
	var weapon: WeaponDefinition = repository.get_weapon(&"crossbow")

	var result_value: ActionResult = query.preview_target_cell(board, &"hero", Vector2i(3, 1), weapon)

	assert_true(result_value.succeeded, "Crossbow preview should accept a visible straight-line target through repository definitions.")
	assert_false(result_value.has_events(), "Legal attack previews should not emit domain events.")
	assert_equal(result_value.metadata.get("legal"), true, "Legal preview metadata should be explicit.")
	assert_equal(result_value.metadata.get("reason"), "valid", "Legal preview reason should be stable.")
	assert_equal(result_value.metadata.get("actor_id"), "hero", "Preview should report actor id.")
	assert_equal(result_value.metadata.get("target_entity_id"), "enemy_1", "Preview should report visible target entity id.")
	assert_equal(result_value.metadata.get("target_cell"), {"x": 3, "y": 1}, "Preview should serialize target cell.")
	assert_equal(result_value.metadata.get("weapon_id"), "crossbow", "Preview should report weapon id.")
	assert_equal(result_value.metadata.get("targeting_shape"), "straight_line", "Preview should report targeting shape.")
	assert_equal(result_value.metadata.get("range"), 3, "Preview should report weapon range.")
	assert_equal(result_value.metadata.get("distance"), 3, "Preview should report line distance separately from weapon range.")


func _core_validation_reasons_follow_stable_order() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	var sword: WeaponDefinition = repository.get_weapon(&"sword")
	var board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy()

	_assert_result_reason(query.preview_target_cell(null, &"hero", Vector2i(2, 1), sword), "invalid_board")
	_assert_result_reason(query.preview_target_cell(board, &"hero", Vector2i(2, 1), null), "invalid_weapon")
	_assert_result_reason(query.preview_target_cell(board, &"missing_actor", Vector2i(2, 1), sword), "invalid_actor")
	_assert_result_reason(query.preview_target_cell(BoardFixtureFactory.attack_preview_dead_actor(), &"hero", Vector2i(2, 1), sword), "dead_actor")
	_assert_result_reason(query.preview_target_cell(board, &"hero", Vector2i(1, 1), sword), "same_cell")
	_assert_result_reason(query.preview_target_cell(board, &"hero", Vector2i(9, 9), sword), "out_of_bounds")


func _invalid_previews_report_stable_reasons_without_mutation() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()

	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_diagonal_enemy(), repository.get_weapon(&"sword"), Vector2i(1, 1), "not_aligned")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_open_lane(), repository.get_weapon(&"sword"), Vector2i(3, 1), "out_of_range")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_blocked_lane(), repository.get_weapon(&"bow"), Vector2i(4, 1), "blocked_line")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_hidden_enemy(), repository.get_weapon(&"bow"), Vector2i(2, 1), "not_visible")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_memory_enemy(), repository.get_weapon(&"bow"), Vector2i(2, 1), "not_visible")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_empty_target(), repository.get_weapon(&"bow"), Vector2i(2, 1), "missing_target")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_dead_target(), repository.get_weapon(&"sword"), Vector2i(2, 1), "dead_target")
	_assert_preview_reason(query, BoardFixtureFactory.attack_preview_friendly_target(), repository.get_weapon(&"sword"), Vector2i(2, 1), "friendly_target")


func _target_entity_previews_do_not_leak_hidden_target_facts() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	var hidden_result: ActionResult = query.preview_target_entity(
		BoardFixtureFactory.attack_preview_hidden_enemy(),
		&"hero",
		&"enemy_1",
		repository.get_weapon(&"bow")
	)
	var missing_result: ActionResult = query.preview_target_entity(
		BoardFixtureFactory.attack_preview_hidden_enemy(),
		&"hero",
		&"missing_enemy",
		repository.get_weapon(&"bow")
	)
	var invalid_actor_result: ActionResult = query.preview_target_entity(
		BoardFixtureFactory.attack_preview_hidden_enemy(),
		&"missing_actor",
		&"enemy_1",
		repository.get_weapon(&"bow")
	)

	assert_equal(hidden_result.metadata.get("reason"), "missing_target", "Hidden entity-id previews should not distinguish hidden current truth from missing ids.")
	assert_equal(missing_result.metadata.get("reason"), "missing_target", "Missing entity-id previews should match hidden entity-id previews.")
	assert_false(hidden_result.metadata.has("target_cell"), "Hidden entity-id previews must not expose hidden target position.")
	assert_false(hidden_result.metadata.has("target_faction"), "Hidden entity-id previews must not expose hidden target faction.")
	assert_false(hidden_result.metadata.has("current_hp"), "Hidden entity-id previews must not expose hidden target HP.")
	assert_equal(invalid_actor_result.metadata.get("reason"), "invalid_actor", "Entity-id preview should validate actor before target existence.")


func _target_cell_previews_reject_stale_occupant_links() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	var board: BoardState = BoardFixtureFactory.attack_preview_open_lane()
	board.get_cell(Vector2i(2, 1)).occupant_id = &"enemy_1"

	var result_value: ActionResult = query.preview_target_cell(board, &"hero", Vector2i(2, 1), repository.get_weapon(&"sword"))

	assert_true(result_value.is_error(), "Attack preview should reject stale occupant links.")
	assert_equal(result_value.metadata.get("reason"), "missing_target", "Stale occupant links should be treated as missing target truth.")


func _wand_ignores_blockers_but_still_requires_visibility() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()

	var blocked_result: ActionResult = query.preview_target_cell(
		BoardFixtureFactory.attack_preview_blocked_lane(),
		&"hero",
		Vector2i(4, 1),
		repository.get_weapon(&"wand")
	)
	var hidden_result: ActionResult = query.preview_target_cell(
		BoardFixtureFactory.attack_preview_hidden_enemy(),
		&"hero",
		Vector2i(2, 1),
		repository.get_weapon(&"wand")
	)

	assert_true(blocked_result.succeeded, "Wand should ignore terrain blockers for a visible target.")
	assert_equal(blocked_result.metadata.get("blocker_ignored"), true, "Wand preview should report the blocker override.")
	assert_equal(blocked_result.metadata.get("blocker_cells"), [{"x": 2, "y": 1}], "Wand should still report ignored blocker cells.")
	assert_true(_metadata_entry_ids(blocked_result.metadata.get("effects", [])).has("ignore_blockers"), "Wand preview should explain the blocker override as an effect.")
	assert_true(String(blocked_result.metadata.get("explanation", "")).contains("ignores"), "Wand explanation should be player/debug-readable.")
	assert_true(hidden_result.is_error(), "Wand should still require target visibility.")
	assert_equal(hidden_result.metadata.get("reason"), "not_visible", "Wand should reject hidden targets as not_visible.")


func _ranged_adjacency_penalties_update_damage_and_warning_text() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()

	var bow_result: ActionResult = query.preview_target_cell(
		BoardFixtureFactory.attack_preview_adjacent_enemy(),
		&"hero",
		Vector2i(2, 1),
		repository.get_weapon(&"bow")
	)
	var staff_result: ActionResult = query.preview_target_cell(
		BoardFixtureFactory.attack_preview_adjacent_enemy(),
		&"hero",
		Vector2i(2, 1),
		repository.get_weapon(&"staff")
	)

	assert_true(bow_result.succeeded, "Bow preview should allow adjacent visible targets with a warning.")
	assert_equal(bow_result.metadata.get("expected_base_damage"), 2, "Bow adjacent preview should floor 3 * 0.7 to 2.")
	assert_equal(_metadata_entry_ids(bow_result.metadata.get("warnings", [])), ["adjacent_ranged_penalty"], "Bow adjacent preview should include the stable penalty warning id.")
	assert_true(String(bow_result.metadata.get("warnings", [])[0].get("text", "")).contains("3 to 2"), "Bow warning text should explain expected damage.")
	assert_true(staff_result.succeeded, "Staff preview should allow adjacent visible targets with a warning.")
	assert_equal(staff_result.metadata.get("expected_base_damage"), 2, "Staff adjacent preview should floor 4 * 0.5 to 2.")
	assert_equal(_metadata_entry_ids(staff_result.metadata.get("warnings", [])), ["adjacent_ranged_penalty"], "Staff adjacent preview should include the stable penalty warning id.")
	assert_true(String(staff_result.metadata.get("warnings", [])[0].get("text", "")).contains("4 to 2"), "Staff warning text should explain expected damage.")


func _preview_is_pure_and_repeated_metadata_is_deterministic() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	var board: BoardState = BoardFixtureFactory.attack_preview_entity_blocked_lane()
	var streams: RngStreamSet = RngStreamSet.new(8811)
	var board_before: Dictionary = board.to_snapshot()
	var sequence_before: int = board.next_sequence_id()
	var tactical_snapshot_before: Dictionary = _tactical_snapshot_dictionary(board, streams)
	var rng_before: Dictionary = streams.to_snapshot()

	var first_result: ActionResult = query.preview_target_cell(board, &"hero", Vector2i(4, 1), repository.get_weapon(&"wand"))
	var second_result: ActionResult = query.preview_target_cell(board, &"hero", Vector2i(4, 1), repository.get_weapon(&"wand"))

	assert_true(first_result.succeeded, "Wand preview should be legal through entity blockers.")
	assert_false(first_result.has_events(), "Preview should never emit domain events.")
	assert_false(second_result.has_events(), "Repeated preview should never emit domain events.")
	assert_equal(first_result.metadata, second_result.metadata, "Repeated previews from an unchanged snapshot should be identical.")
	assert_equal(board.to_snapshot(), board_before, "Preview should not mutate board snapshots.")
	assert_equal(board.next_sequence_id(), sequence_before, "Preview should not advance board sequence ids.")
	assert_equal(_tactical_snapshot_dictionary(board, streams), tactical_snapshot_before, "Preview should not mutate tactical snapshot data.")
	assert_equal(streams.to_snapshot(), rng_before, "Preview should not consume gameplay RNG streams.")


func _story_1_9_contract_matrix_matches_preview_results() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var query: AttackPreviewQuery = AttackPreviewQuery.new()

	for contract: Dictionary in AttackPreviewContractMatrix.baseline_cases():
		var board: BoardState = _contract_board(String(contract.get("fixture", "")))
		var weapon: WeaponDefinition = repository.get_weapon(contract.get("weapon_id"))
		assert_true(board != null, "Story 1.9 contract %s should reference a known fixture." % contract.get("id"))
		var result_value: ActionResult = query.preview_target_cell(board, &"hero", contract.get("target_cell"), weapon)
		var metadata: Dictionary = result_value.metadata

		assert_equal(metadata.get("reason"), contract.get("expected_reason"), "Story 1.9 contract %s should keep stable reason." % contract.get("id"))
		if int(contract.get("expected_base_damage", -1)) >= 0:
			assert_equal(metadata.get("expected_base_damage"), contract.get("expected_base_damage"), "Story 1.9 contract %s should keep expected base damage." % contract.get("id"))
		assert_equal(metadata.get("blocker_ignored"), contract.get("expected_blocker_ignored"), "Story 1.9 contract %s should keep blocker override contract." % contract.get("id"))
		if contract.has("expected_warning_ids"):
			assert_equal(_metadata_entry_ids(metadata.get("warnings", [])), contract.get("expected_warning_ids"), "Story 1.9 contract %s should keep warning ids." % contract.get("id"))
		if contract.has("expected_effect_ids"):
			assert_equal(_metadata_entry_ids(metadata.get("effects", [])), contract.get("expected_effect_ids"), "Story 1.9 contract %s should keep effect ids." % contract.get("id"))


func _assert_preview_reason(
	query: AttackPreviewQuery,
	board: BoardState,
	weapon: WeaponDefinition,
	target_cell: Vector2i,
	expected_reason: String
) -> void:
	var before: Dictionary = board.to_snapshot()
	var sequence_before: int = board.next_sequence_id()
	var result_value: ActionResult = query.preview_target_cell(board, &"hero", target_cell, weapon)

	assert_true(result_value.is_error(), "Attack preview should reject %s." % expected_reason)
	assert_equal(result_value.error_code, &"invalid_attack_preview", "Attack preview should use the stable preview error code.")
	assert_equal(result_value.metadata.get("legal"), false, "Invalid preview metadata should be explicit.")
	assert_equal(result_value.metadata.get("reason"), expected_reason, "Attack preview should expose the expected stable reason.")
	assert_false(result_value.has_events(), "Invalid attack preview should not emit domain events.")
	assert_equal(board.to_snapshot(), before, "Invalid attack preview should not mutate board snapshots.")
	assert_equal(board.next_sequence_id(), sequence_before, "Invalid attack preview should not advance sequence ids.")
	if expected_reason == "not_visible":
		assert_false(result_value.metadata.has("target_entity_id"), "Hidden or memory targets must not expose current target ids.")
		assert_false(result_value.metadata.has("target_faction"), "Hidden or memory targets must not expose current target faction.")
		assert_false(result_value.metadata.has("current_hp"), "Hidden or memory targets must not expose current target HP.")


func _assert_result_reason(result_value: ActionResult, expected_reason: String) -> void:
	assert_true(result_value.is_error(), "Attack preview should reject %s." % expected_reason)
	assert_equal(result_value.error_code, &"invalid_attack_preview", "Attack preview should use the stable preview error code.")
	assert_equal(result_value.metadata.get("legal"), false, "Invalid preview metadata should be explicit.")
	assert_equal(result_value.metadata.get("reason"), expected_reason, "Attack preview should expose the expected stable reason.")
	assert_false(result_value.has_events(), "Invalid attack preview should not emit domain events.")


func _contract_board(fixture_name: String) -> BoardState:
	match fixture_name:
		"attack_preview_open_lane":
			return BoardFixtureFactory.attack_preview_open_lane()
		"attack_preview_adjacent_enemy":
			return BoardFixtureFactory.attack_preview_adjacent_enemy()
		"attack_preview_blocked_lane":
			return BoardFixtureFactory.attack_preview_blocked_lane()
		"attack_preview_diagonal_enemy":
			return BoardFixtureFactory.attack_preview_diagonal_enemy()
		"attack_preview_empty_target":
			return BoardFixtureFactory.attack_preview_empty_target()
		"attack_preview_hidden_enemy":
			return BoardFixtureFactory.attack_preview_hidden_enemy()
		"attack_preview_memory_enemy":
			return BoardFixtureFactory.attack_preview_memory_enemy()
		"attack_preview_dead_target":
			return BoardFixtureFactory.attack_preview_dead_target()
		"attack_preview_friendly_target":
			return BoardFixtureFactory.attack_preview_friendly_target()
		_:
			return null


func _metadata_entry_ids(entries_value: Variant) -> Array[String]:
	var result_value: Array[String] = []
	if not entries_value is Array:
		return result_value
	var entries: Array = entries_value
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			result_value.append(String((entry_value as Dictionary).get("id", "")))
		else:
			result_value.append(String(entry_value))
	return result_value


func _tactical_snapshot_dictionary(board: BoardState, streams: RngStreamSet) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(result_value.succeeded, "Test helper should export a top-level tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()


# Story 14.1 (AC1): a corpse-cleared cell reads as missing_target for the attack preview (targeting keys off the
# cell's occupant_id, which corpse-clear vacates) — so a corpse is non-targetable for free.
func _cleared_corpse_cell_is_non_targetable() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_kill_board()
	var weapon: WeaponDefinition = WeaponRepository.create_baseline_repository().get_weapon(&"sword")
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	assert_true(query.preview_target_cell(board, &"hero", Vector2i(2, 1), weapon).succeeded, "Setup: the living adjacent enemy is targetable.")
	assert_true(board.apply_events([DomainEvent.damage_applied(board.next_sequence_id(), &"hero", &"enemy_1", 3, 3, 0, 10, {})]).succeeded, "Setup: the enemy dies (corpse-clear).")
	var preview: ActionResult = query.preview_target_cell(board, &"hero", Vector2i(2, 1), weapon)
	assert_true(preview.is_error(), "A corpse cell is not a legal attack target.")
	assert_equal(preview.metadata.get("reason"), "missing_target", "A cleared corpse cell reads as missing_target (targeting keys off occupant_id).")
