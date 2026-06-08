extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyTurnResolver = preload("res://scripts/tactical/turns/enemy_turn_resolver.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalAttackCommitFlowResult = preload("res://scripts/ui/view_models/tactical_attack_commit_flow_result.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_first_enemy_tap_enters_preview_without_command_or_mutation()
	_same_target_second_tap_commits_once_through_bridge()
	_explicit_confirm_commits_once_when_preview_is_still_valid()
	_cancel_clears_preview_without_command_or_mutation()
	_different_enemy_replaces_preview_without_committing_previous_target()
	_different_tile_clears_preview_without_command_or_mutation()
	_invalidated_pending_targets_clear_without_command()
	_unavailable_commit_result_does_not_advance_enemy_turn()
	_refresh_changed_target_reports_target_changed()
	_successful_commit_result_allows_enemy_turn_resolver_to_advance()
	_presenter_dictionary_contains_only_safe_values()
	return result()


func _first_enemy_tap_enters_preview_without_command_or_mutation() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.micro_combat_board())
	var streams: RngStreamSet = RngStreamSet.new(2301)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var pending_telegraphs: Array[Dictionary] = [{"id": "ash_mark", "target": _cell(4, 2)}]
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending_telegraphs)
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log)
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	var result_value: TacticalAttackCommitFlowResult = flow.tap_attack_target(
		context,
		&"hero",
		Vector2i(3, 2),
		_weapon(&"bow"),
		_support(&"none"),
		null
	)
	var flow_data: Dictionary = flow.to_dictionary()
	var preview: Dictionary = flow_data.get("preview", {})

	assert_false(result_value.submitted, "First visible enemy tap should preview without submitting a command.")
	assert_equal(result_value.command_result, null, "First tap should not expose a raw command result.")
	assert_equal(flow_data.get("mode"), "attack_preview", "First tap should enter attack preview mode.")
	assert_equal(flow_data.get("actor_id"), "hero", "Flow should track copied actor id.")
	assert_equal(flow_data.get("target_cell"), _cell(3, 2), "Flow should track copied target cell.")
	assert_equal(flow_data.get("target_entity_id"), "enemy_iron", "Flow should track copied target entity id.")
	assert_equal(flow_data.get("weapon_id"), "bow", "Flow should track copied weapon id.")
	assert_equal(preview.get("kind"), "attack", "Flow preview should preserve attack preview kind.")
	assert_equal(preview.get("commit_available"), true, "Valid first tap preview should be commit-capable.")
	assert_equal(flow_data.get("confirm_available"), true, "Confirm should be available for a valid pending attack preview.")
	assert_equal(flow_data.get("cancel_available"), true, "Cancel should be available while attack preview mode is active.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log), before, "First-tap preview must not mutate board, turn, RNG, telegraphs, or event log.")
	_assert_no_forbidden_references(flow_data, "Flow dictionary should not expose raw domain, command, resource, or scene references.")
	_assert_no_forbidden_references(result_value.to_dictionary(), "Flow result dictionary should not expose raw command results.")


func _same_target_second_tap_commits_once_through_bridge() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2302)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
	var target_cell: Vector2i = Vector2i(2, 1)

	var first_tap: TacticalAttackCommitFlowResult = flow.tap_attack_target(context, &"hero", target_cell, _weapon(&"sword"), _support(&"none"), null)
	var before_commit: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var second_tap: TacticalAttackCommitFlowResult = flow.tap_attack_target(context, &"hero", target_cell, _weapon(&"sword"), _support(&"none"), null)

	assert_false(first_tap.submitted, "First tap should not submit before the same-target second tap.")
	assert_true(second_tap.submitted, "Same-target second tap should submit a command.")
	assert_true(second_tap.command_result != null and second_tap.command_result.succeeded, "Same-target second tap should expose a successful command result for downstream systems.")
	assert_equal(second_tap.submitted_command_id, "attack", "Second tap should identify the submitted bridge command id.")
	assert_equal(second_tap.command_result.events.size(), 2, "One sword attack should emit exactly attack and damage events.")
	assert_equal(_event_count(second_tap.command_result.events, DomainEvent.Type.DAMAGE_APPLIED), 1, "Second tap should apply damage exactly once.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 6, "Second tap should mutate target HP exactly once through command execution.")
	assert_equal(bool(second_tap.command_result.metadata.get("advances_turn", false)), true, "Committed attack result should expose turn advancement metadata.")
	assert_equal(flow.to_dictionary().get("mode"), "none", "Successful commit should clear pending attack preview mode.")
	assert_false(before_commit == _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), "Only the second tap should mutate tactical state.")
	_assert_no_forbidden_references(second_tap.to_dictionary(), "Second-tap result dictionary should remain presenter-safe.")


func _explicit_confirm_commits_once_when_preview_is_still_valid() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2303)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), _support(&"none"), null)
	var confirm_result: TacticalAttackCommitFlowResult = flow.confirm_attack(context, _weapon(&"sword"), _support(&"none"), null)

	assert_true(confirm_result.submitted, "Explicit confirm should submit the pending valid attack.")
	assert_true(confirm_result.command_result != null and confirm_result.command_result.succeeded, "Explicit confirm should return the successful command result.")
	assert_equal(confirm_result.submitted_command_id, "attack", "Explicit confirm should identify the bridge attack command.")
	assert_equal(_event_count(confirm_result.command_result.events, DomainEvent.Type.DAMAGE_APPLIED), 1, "Explicit confirm should apply damage exactly once.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 6, "Explicit confirm should commit exactly one sword attack.")
	assert_equal(flow.to_dictionary().get("mode"), "none", "Explicit confirm should clear pending preview mode after command success.")


func _cancel_clears_preview_without_command_or_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2304)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [{"id": "pending"}])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), _support(&"none"), null)
	var before_cancel: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var cancel_result: TacticalAttackCommitFlowResult = flow.cancel()

	assert_false(cancel_result.submitted, "Cancel should not submit a command.")
	assert_equal(cancel_result.command_result, null, "Cancel should not expose a command result.")
	assert_equal(cancel_result.reason, "cancelled", "Cancel should expose a stable reason.")
	assert_equal(flow.to_dictionary().get("mode"), "none", "Cancel should clear attack preview mode.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before_cancel, "Cancel must not mutate board, turn, RNG, telegraphs, or event log.")


func _different_enemy_replaces_preview_without_committing_previous_target() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_multiple_ordering()
	var streams: RngStreamSet = RngStreamSet.new(2305)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(4, 2), _weapon(&"sword"), _support(&"none"), null)
	var before_switch: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var switch_result: TacticalAttackCommitFlowResult = flow.tap_attack_target(context, &"hero", Vector2i(2, 2), _weapon(&"sword"), _support(&"none"), null)
	var flow_data: Dictionary = flow.to_dictionary()

	assert_false(switch_result.submitted, "Tapping a different enemy should replace preview without submitting the previous target.")
	assert_equal(switch_result.command_result, null, "Target switch should not expose a command result.")
	assert_equal(flow_data.get("mode"), "attack_preview", "Different valid enemy should start a fresh attack preview.")
	assert_equal(flow_data.get("target_entity_id"), "enemy_a", "Fresh preview should track the newly tapped target.")
	assert_equal(board.get_entity(&"enemy_b").current_hp, 10, "Previous target should not take damage on target switch.")
	assert_equal(board.get_entity(&"enemy_a").current_hp, 10, "New target should not take damage until commit.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before_switch, "Target switch preview must not mutate board, turn, RNG, telegraphs, or event log.")


func _different_tile_clears_preview_without_command_or_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2306)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), _support(&"none"), null)
	var before_clear: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var clear_result: TacticalAttackCommitFlowResult = flow.clear_for_non_attack_tile(Vector2i(0, 0))

	assert_false(clear_result.submitted, "Selecting a non-attack tile should not submit a command.")
	assert_equal(clear_result.command_result, null, "Non-attack tile clear should not expose a command result.")
	assert_equal(clear_result.reason, "non_attack_tile", "Non-attack tile clear should expose a stable reason.")
	assert_equal(flow.to_dictionary().get("mode"), "none", "Non-attack tile selection should clear pending attack preview mode.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before_clear, "Non-attack tile clear must not mutate board, turn, RNG, telegraphs, or event log.")


func _invalidated_pending_targets_clear_without_command() -> void:
	for scenario: Dictionary in [
		{"id": "dead_target", "reason": "dead_target"},
		{"id": "hidden_target", "reason": "not_visible"},
		{"id": "friendly_target", "reason": "friendly_target"},
		{"id": "out_of_range", "reason": "out_of_range"},
		{"id": "blocked_line", "reason": "blocked_line", "weapon_id": &"bow", "target_cell": Vector2i(3, 1)},
		{"id": "wrong_phase", "reason": "wrong_phase"},
		{"id": "wrong_actor", "reason": "wrong_phase"}
	]:
		_assert_pending_invalidation_clears_without_command(scenario)


func _unavailable_commit_result_does_not_advance_enemy_turn() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2308)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), _support(&"none"), null)
	turn_state.phase = TacticalTurnState.Phase.ENEMY_PLANNING
	var before_unavailable_commit: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var unavailable_commit: TacticalAttackCommitFlowResult = flow.confirm_attack(context, _weapon(&"sword"), _support(&"none"), null)
	var resolver_result: ActionResult = EnemyTurnResolver.new(EnemyRepository.create_baseline_repository(), &"hero").resolve_after_player_action(context, unavailable_commit.command_result)

	assert_false(unavailable_commit.submitted, "Unavailable commit should not be counted as submitted.")
	assert_equal(unavailable_commit.command_result, null, "Unavailable commit should not expose a failed command result as a submitted action.")
	assert_equal(unavailable_commit.reason, "wrong_phase", "Unavailable commit should expose the command bridge validation reason.")
	assert_true(resolver_result.succeeded, "Enemy resolver should ignore missing player command results without error.")
	assert_equal(resolver_result.metadata.get("resolved"), false, "Unavailable commits should not resolve enemy turns.")
	assert_equal(resolver_result.metadata.get("reason"), "missing_player_result", "Enemy resolver should preserve missing-result reason.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before_unavailable_commit, "Unavailable commit and enemy resolver should not mutate tactical state.")


func _refresh_changed_target_reports_target_changed() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2311)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), _support(&"none"), null)
	context.board = _attack_board_with_enemy_id(&"enemy_2")
	var refresh_result: TacticalAttackCommitFlowResult = flow.refresh_or_clear(context, _weapon(&"sword"))

	assert_false(refresh_result.submitted, "Refresh should not submit when the occupying target changed.")
	assert_equal(refresh_result.command_result, null, "Changed target refresh should not expose a command result.")
	assert_equal(refresh_result.reason, "target_changed", "Changed valid target refresh should not clear with a misleading valid reason.")
	assert_equal(flow.to_dictionary().get("mode"), "none", "Changed target refresh should clear pending attack preview mode.")


func _successful_commit_result_allows_enemy_turn_resolver_to_advance() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_adjacent_melee()
	var streams: RngStreamSet = RngStreamSet.new(2309)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	flow.tap_attack_target(context, &"hero", Vector2i(3, 2), _weapon(&"sword"), _support(&"none"), null)
	var commit_result: TacticalAttackCommitFlowResult = flow.confirm_attack(context, _weapon(&"sword"), _support(&"none"), null)
	var hero_hp_after_commit: int = board.get_entity(&"hero").current_hp
	var enemy_result: ActionResult = EnemyTurnResolver.new(EnemyRepository.create_baseline_repository(), &"hero").resolve_after_player_action(context, commit_result.command_result)

	assert_true(commit_result.submitted and commit_result.command_result.succeeded, "Successful commit should return a successful player result.")
	assert_true(enemy_result.succeeded, "Enemy resolver should accept successful committed player actions.")
	assert_equal(enemy_result.metadata.get("resolved"), true, "Successful committed attacks should allow enemy advancement.")
	assert_equal(int(enemy_result.metadata.get("enemy_count", 0)), 1, "One living adjacent enemy should resolve after the committed player action.")
	assert_equal(turn_state.turn_number, 2, "Enemy resolution should advance the turn number only after successful commit.")
	assert_true(board.get_entity(&"hero").current_hp < hero_hp_after_commit, "Enemy advancement should occur after the successful command result is supplied.")


func _presenter_dictionary_contains_only_safe_values() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2310)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	var preview_result: TacticalAttackCommitFlowResult = flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), _support(&"none"), null)
	var flow_data: Dictionary = flow.to_dictionary()
	var view_model_data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": flow_data.get("preview", {}),
		"commit_flow": flow_data
	}).to_dictionary()
	var availability: Dictionary = view_model_data.get("action_availability", {})
	var bare_attack_view_model: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": flow_data.get("preview", {})
	}).to_dictionary()
	var bare_attack_availability: Dictionary = bare_attack_view_model.get("action_availability", {})
	var stale_flow_data: Dictionary = flow_data.duplicate(true)
	stale_flow_data["target_entity_id"] = "stale_enemy"
	var stale_flow_view_model: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": flow_data.get("preview", {}),
		"commit_flow": stale_flow_data
	}).to_dictionary()
	var stale_flow_availability: Dictionary = stale_flow_view_model.get("action_availability", {})
	var invalid_preview: Dictionary = (flow_data.get("preview", {}) as Dictionary).duplicate(true)
	invalid_preview["available"] = false
	invalid_preview["target_valid"] = false
	invalid_preview["commit_available"] = false
	invalid_preview["reason"] = "dead_target"
	invalid_preview["commit_reason"] = "dead_target"
	var invalid_flow_view_model: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": invalid_preview,
		"commit_flow": flow_data
	}).to_dictionary()
	var invalid_flow_availability: Dictionary = invalid_flow_view_model.get("action_availability", {})
	var override_view_model: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": flow_data.get("preview", {}),
		"action_availability": {
			"confirm": {
				"enabled": true,
				"reason": "presenter_override"
			},
			"cancel": {
				"enabled": true,
				"reason": "presenter_override"
			}
		}
	}).to_dictionary()
	var override_availability: Dictionary = override_view_model.get("action_availability", {})

	assert_false(preview_result.submitted, "Presenter safety setup should remain preview-only.")
	assert_equal((availability.get("confirm", {}) as Dictionary).get("enabled"), true, "Attack confirm should be available only with active commit flow metadata.")
	assert_equal((availability.get("cancel", {}) as Dictionary).get("enabled"), true, "Cancel should be available while attack preview flow is active.")
	assert_equal((bare_attack_availability.get("confirm", {}) as Dictionary).get("enabled"), false, "Bare attack preview dictionaries should not enable confirm without pending flow state.")
	assert_equal((bare_attack_availability.get("cancel", {}) as Dictionary).get("enabled"), false, "Bare attack preview dictionaries should not enable cancel without pending flow state.")
	assert_equal((stale_flow_availability.get("confirm", {}) as Dictionary).get("enabled"), false, "Stale commit flow should not enable confirm for a different target.")
	assert_equal((stale_flow_availability.get("confirm", {}) as Dictionary).get("reason"), "stale_commit_flow", "Stale commit flow should expose a stable mismatch reason.")
	assert_equal((stale_flow_availability.get("cancel", {}) as Dictionary).get("enabled"), false, "Stale commit flow should not enable cancel for a different target.")
	assert_equal((invalid_flow_availability.get("confirm", {}) as Dictionary).get("enabled"), false, "Invalid active flow previews should not enable confirm.")
	assert_equal((invalid_flow_availability.get("confirm", {}) as Dictionary).get("reason"), "dead_target", "Invalid active flow previews should preserve concrete commit reasons.")
	assert_equal((override_availability.get("confirm", {}) as Dictionary).get("enabled"), false, "Presenter overrides should not enable confirm without active matching flow.")
	assert_equal((override_availability.get("cancel", {}) as Dictionary).get("enabled"), false, "Presenter overrides should not enable cancel without active matching flow.")
	_assert_no_forbidden_references(flow_data, "Flow state dictionary should be value-only.")
	_assert_no_forbidden_references(preview_result.to_dictionary(), "Flow result dictionary should be value-only.")
	_assert_no_forbidden_references(view_model_data, "Board view-model should sanitize commit flow dictionaries.")


func _assert_pending_invalidation_clears_without_command(scenario: Dictionary) -> void:
	var scenario_id: String = String(scenario.get("id", ""))
	var weapon_id: StringName = StringName(str(scenario.get("weapon_id", &"sword")))
	var target_cell: Vector2i = scenario.get("target_cell", Vector2i(2, 1))
	var board: BoardState = BoardFixtureFactory.attack_preview_open_lane() if scenario_id == "blocked_line" else BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2400)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	var preview_result: TacticalAttackCommitFlowResult = flow.tap_attack_target(context, &"hero", target_cell, _weapon(weapon_id), _support(&"none"), null)
	assert_false(preview_result.submitted, "%s setup should only create a pending preview." % scenario_id)
	assert_equal(flow.to_dictionary().get("mode"), "attack_preview", "%s setup should enter attack preview mode." % scenario_id)
	_apply_invalidation_scenario(context, scenario_id, target_cell)
	var before_invalidation: Dictionary = _tactical_snapshot_dictionary(context.board, streams, turn_state, context.pending_telegraphs, event_log)
	var invalid_result: TacticalAttackCommitFlowResult = flow.confirm_attack(context, _weapon(weapon_id), _support(&"none"), null)

	assert_false(invalid_result.submitted, "%s should not submit a command." % scenario_id)
	assert_equal(invalid_result.command_result, null, "%s should clear before command execution." % scenario_id)
	assert_equal(invalid_result.reason, String(scenario.get("reason", "")), "%s should expose the revalidation reason." % scenario_id)
	assert_equal(flow.to_dictionary().get("mode"), "none", "%s should clear pending attack preview mode." % scenario_id)
	assert_equal(_tactical_snapshot_dictionary(context.board, streams, turn_state, context.pending_telegraphs, event_log), before_invalidation, "%s clear must not mutate board, turn, RNG, telegraphs, or event log." % scenario_id)


func _apply_invalidation_scenario(context: TacticalActionContext, scenario_id: String, target_cell: Vector2i) -> void:
	match scenario_id:
		"dead_target":
			var setup_result: ActionResult = context.board.apply_events([
				DomainEvent.damage_applied(context.board.next_sequence_id(), &"hero", &"enemy_1", 10, 10, 0, 10)
			])
			assert_true(setup_result.succeeded, "Dead target setup should apply damage.")
		"hidden_target":
			context.board.get_cell(target_cell).visible = false
		"friendly_target":
			context.board = BoardFixtureFactory.attack_preview_friendly_target()
		"out_of_range":
			var move_result: ActionResult = context.board.apply_events([
				DomainEvent.entity_moved(context.board.next_sequence_id(), &"hero", Vector2i(1, 1), Vector2i(0, 1), 1, 3)
			])
			assert_true(move_result.succeeded, "Out-of-range setup should move the actor.")
		"blocked_line":
			var terrain_result: ActionResult = context.board.set_cell_terrain_for_setup(Vector2i(1, 1), BoardCell.Terrain.WALL)
			assert_true(terrain_result.succeeded, "Blocked-line setup should add a blocker.")
		"wrong_phase":
			context.turn_state.phase = TacticalTurnState.Phase.ENEMY_PLANNING
		"wrong_actor":
			context.turn_state.active_actor_id = &"other_actor"


func _attack_board_with_enemy_id(enemy_id: StringName) -> BoardState:
	var snapshot: Dictionary = BoardFixtureFactory.attack_preview_adjacent_enemy().to_snapshot()
	for cell_data: Dictionary in snapshot.get("cells", []):
		if String(cell_data.get("occupant_id", "")) == "enemy_1":
			cell_data["occupant_id"] = String(enemy_id)
	for entity_data: Dictionary in snapshot.get("entities", []):
		if String(entity_data.get("entity_id", "")) == "enemy_1":
			entity_data["entity_id"] = String(enemy_id)
	var result_value: ActionResult = BoardState.try_from_snapshot(snapshot)
	assert_true(result_value.succeeded, "Target-change helper should create a valid board.")
	return result_value.metadata.get("board") as BoardState


func _visible_board(board: BoardState) -> BoardState:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true
	return board


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> Variant:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _cell(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y
	}


func _event_count(events: Array[DomainEvent], event_type: int) -> int:
	var count: int = 0
	for event: DomainEvent in events:
		if event.event_type == event_type:
			count += 1
	return count


func _assert_no_forbidden_references(value: Variant, message: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var data: Dictionary = value
			for key: Variant in data.keys():
				_assert_no_forbidden_references(data[key], message)
		TYPE_ARRAY:
			for item: Variant in value:
				_assert_no_forbidden_references(item, message)
		TYPE_OBJECT:
			assert_false(value is BoardState, message)
			assert_false(value is BoardCell, message)
			assert_false(value is TacticalEntityState, message)
			assert_false(value is TacticalActionContext, message)
			assert_false(value is ActionResult, message)
			assert_false(value is AttackCommand, message)
			assert_false(value is WeaponDefinition, message)
			assert_false(value is SupportDefinition, message)
			assert_false(value is Resource, message)
			assert_false(value is Node, message)
			assert_false(value is Control, message)


func _tactical_snapshot_dictionary(
	board: BoardState,
	streams: RngStreamSet,
	turn_state: TacticalTurnState,
	pending_telegraphs: Array[Dictionary],
	event_log: Array[DomainEvent]
) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), pending_telegraphs, event_log)
	assert_true(result_value.succeeded, "Test helper should export a tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()
