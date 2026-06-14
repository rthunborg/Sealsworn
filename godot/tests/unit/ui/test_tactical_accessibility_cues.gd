extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const AttackPreviewContractMatrix = preload("res://tests/fixtures/tactical/attack_preview_contract_matrix.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalAttackCommitFlowResult = preload("res://scripts/ui/view_models/tactical_attack_commit_flow_result.gd")
const TacticalAttackPreview = preload("res://scripts/ui/view_models/tactical_attack_preview.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalInspectView = preload("res://scripts/ui/view_models/tactical_inspect_view.gd")
const TacticalMovementPreview = preload("res://scripts/ui/view_models/tactical_movement_preview.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const NON_COLOR_CHANNELS: Array[String] = ["shape", "icon", "label", "pattern", "text"]

func run() -> Dictionary:
	_model_exposes_stable_color_independent_envelope()
	_every_critical_meaning_has_a_non_color_channel()
	_real_movement_preview_cue_ids_all_have_accessibility_mappings()
	_real_attack_preview_cue_ids_all_have_accessibility_mappings()
	_real_inspect_and_telegraph_cue_ids_all_have_accessibility_mappings()
	_no_critical_cue_relies_on_color_alone()
	_preview_and_committed_feedback_are_distinct_without_color()
	_audio_feedback_cues_always_have_visual_or_textual_equivalents()
	_feedback_maps_from_active_preview_and_committed_result()
	_text_scale_clamps_to_named_bounds()
	_malformed_text_scale_falls_back_to_one_with_stable_reason()
	_text_scale_change_never_mutates_tactical_truth()
	_text_scale_change_never_alters_preview_legality_or_action_availability()
	_accessibility_dictionaries_are_deep_copies_and_reference_free()
	_building_accessibility_data_does_not_execute_commands_or_mutate_state()
	_board_view_model_carries_sanitized_accessibility_slot()
	return result()


func _model_exposes_stable_color_independent_envelope() -> void:
	var data: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary()

	assert_equal(_sorted_keys(data), [
		"available",
		"color_independent",
		"cue_ids",
		"cues",
		"feedback",
		"kind",
		"reason",
		"text_scale"
	], "Accessibility model should expose a stable top-level envelope.")
	assert_equal(data.get("kind"), "accessibility", "Accessibility model should identify its kind.")
	assert_equal(data.get("color_independent"), true, "Accessibility model should assert color independence.")
	assert_equal(data.get("available"), true, "Accessibility model should default to available.")
	assert_equal(data.get("reason"), "valid", "Accessibility model should default to a stable valid reason.")
	assert_true(data.get("cues") is Dictionary, "Accessibility model should expose a cues dictionary.")
	assert_true(data.get("text_scale") is Dictionary, "Accessibility model should expose a text-scale dictionary.")
	var text_scale: Dictionary = data.get("text_scale", {})
	assert_equal(text_scale.get("scale"), 1.0, "Default text scale should be 1.0.")
	assert_equal(text_scale.get("requested"), 1.0, "Default requested text scale should be 1.0.")
	assert_equal(text_scale.get("clamped"), false, "Default text scale should not be clamped.")


func _every_critical_meaning_has_a_non_color_channel() -> void:
	var cues: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary().get("cues", {})
	var critical_meanings: Array[String] = [
		"move_preview_valid",
		"move_preview_invalid",
		"attack_preview_valid",
		"attack_preview_invalid",
		"attack_preview_blocked_line",
		"attack_preview_blocker_ignored",
		"attack_preview_adjacent_warning",
		"telegraph_pending",
		"telegraph_due",
		"danger_damage",
		"inspect_visible",
		"inspect_memory",
		"inspect_hidden_unexplored",
		"commit_available",
		"commit_unavailable",
		"feedback_preview",
		"feedback_committed"
	]
	for cue_id: String in critical_meanings:
		assert_true(cues.has(cue_id), "Critical meaning '%s' should be registered in the accessibility model." % cue_id)
		var entry: Dictionary = cues.get(cue_id, {})
		var channels: Array = entry.get("channels", [])
		assert_true(_has_non_color_channel(channels), "Critical meaning '%s' must declare at least one non-color channel." % cue_id)
		assert_false(String(entry.get("severity", "")).is_empty(), "Critical meaning '%s' should expose a stable severity id." % cue_id)


func _real_movement_preview_cue_ids_all_have_accessibility_mappings() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var valid_preview: Dictionary = TacticalMovementPreview.from_query(board, &"hero", Vector2i(1, 0), 3).to_dictionary()
	var invalid_preview: Dictionary = TacticalMovementPreview.from_query(board, &"hero", Vector2i(0, 0), 3).to_dictionary()

	assert_true(bool(valid_preview.get("available")), "Movement audit fixture should expose a valid preview case.")
	assert_false(bool(invalid_preview.get("available")), "Movement audit fixture should expose an invalid preview case.")
	_assert_cue_ids_have_accessibility_mappings(valid_preview.get("cue_ids", []), "movement valid preview")
	_assert_cue_ids_have_accessibility_mappings(invalid_preview.get("cue_ids", []), "movement invalid preview")


func _real_attack_preview_cue_ids_all_have_accessibility_mappings() -> void:
	var seen_reasons: Dictionary = {}
	for matrix_case: Dictionary in AttackPreviewContractMatrix.baseline_cases():
		var board: BoardState = _fixture_board(String(matrix_case.get("fixture", "")))
		if board == null:
			continue
		var weapon: WeaponDefinition = _weapon(StringName(String(matrix_case.get("weapon_id", ""))))
		var target_cell: Vector2i = matrix_case.get("target_cell", Vector2i.ZERO)
		var preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", target_cell, weapon).to_dictionary()
		_assert_cue_ids_have_accessibility_mappings(preview.get("cue_ids", []), "attack preview case %s" % String(matrix_case.get("id", "")))
		seen_reasons[String(preview.get("reason", ""))] = true

	# Make sure the audit actually exercised the critical attack-preview meanings.
	assert_true(seen_reasons.has("valid"), "Attack preview audit should include a valid case.")
	assert_true(seen_reasons.has("blocked_line"), "Attack preview audit should include a blocked-line case.")


func _real_inspect_and_telegraph_cue_ids_all_have_accessibility_mappings() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var streams: RngStreamSet = RngStreamSet.new(2611)
	var pending_due: Dictionary = _telegraph("ash_due", Vector2i(1, 2), 1, 2, 4)
	var memory_cell: BoardCell = board.get_cell(Vector2i(5, 2))
	memory_cell.visible = false
	memory_cell.explored = true
	var hidden_cell: BoardCell = board.get_cell(Vector2i(6, 4))
	hidden_cell.visible = false
	hidden_cell.explored = false
	# Turn number 3 makes the due telegraph register as telegraph_due.
	var turn_state: TacticalTurnState = TacticalTurnState.new(3, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [pending_due])

	var visible_inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(1, 2), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	}).to_dictionary()
	var memory_inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(5, 2), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	}).to_dictionary()
	var hidden_inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(6, 4), {
		"actor_id": &"hero"
	}).to_dictionary()

	var visible_cues: Array = visible_inspect.get("cue_ids", [])
	assert_true(visible_cues.has("inspect_visible"), "Visible inspect should expose the inspect_visible cue.")
	assert_true(visible_cues.has("telegraph_due"), "Due telegraph should expose the telegraph_due cue.")
	assert_true(visible_cues.has("danger_damage"), "Telegraph with damage should expose the danger_damage cue.")
	assert_true((memory_inspect.get("cue_ids", []) as Array).has("inspect_memory"), "Memory inspect should expose the inspect_memory cue.")
	assert_true((hidden_inspect.get("cue_ids", []) as Array).has("inspect_hidden_unexplored"), "Hidden inspect should expose the inspect_hidden_unexplored cue.")
	_assert_cue_ids_have_accessibility_mappings(visible_cues, "visible inspect with due telegraph")
	_assert_cue_ids_have_accessibility_mappings(memory_inspect.get("cue_ids", []), "memory inspect")
	_assert_cue_ids_have_accessibility_mappings(hidden_inspect.get("cue_ids", []), "hidden inspect")

	# Also confirm a pending (not yet due) telegraph registers and is mapped.
	var pending_context: TacticalActionContext = TacticalActionContext.new(
		board,
		TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero"),
		streams,
		[_telegraph("ash_pending", Vector2i(1, 2), 1, 3, 5)]
	)
	var pending_inspect: Dictionary = TacticalInspectView.from_context(pending_context, Vector2i(1, 2), {
		"actor_id": &"hero"
	}).to_dictionary()
	assert_true((pending_inspect.get("cue_ids", []) as Array).has("telegraph_pending"), "Pending telegraph should expose telegraph_pending cue.")
	_assert_cue_ids_have_accessibility_mappings(pending_inspect.get("cue_ids", []), "pending telegraph inspect")


func _no_critical_cue_relies_on_color_alone() -> void:
	var cues: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary().get("cues", {})
	for cue_id: Variant in cues.keys():
		var entry: Dictionary = cues.get(cue_id, {})
		var channels: Array = entry.get("channels", [])
		assert_false(channels.has("color"), "Cue '%s' must not register a 'color' channel as a critical meaning channel." % String(cue_id))
		assert_true(_has_non_color_channel(channels), "Cue '%s' must carry at least one non-color channel so meaning survives color stripping." % String(cue_id))
		for channel_value: Variant in channels:
			assert_true(NON_COLOR_CHANNELS.has(String(channel_value)), "Cue '%s' channel '%s' should be a known non-color channel." % [String(cue_id), String(channel_value)])


func _preview_and_committed_feedback_are_distinct_without_color() -> void:
	var data: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary()
	var cues: Dictionary = data.get("cues", {})
	var preview_entry: Dictionary = cues.get("feedback_preview", {})
	var committed_entry: Dictionary = cues.get("feedback_committed", {})
	var preview_channels: Array = preview_entry.get("channels", [])
	var committed_channels: Array = committed_entry.get("channels", [])

	assert_true(_has_non_color_channel(preview_channels), "feedback_preview must have a non-color channel.")
	assert_true(_has_non_color_channel(committed_channels), "feedback_committed must have a non-color channel.")
	# The two states must be visually distinguishable with color removed: the channel sets differ.
	assert_false(_arrays_equal_as_set(preview_channels, committed_channels), "feedback_preview and feedback_committed must differ in their non-color channels so a player can tell preview from committed without color.")

	# The feedback slot should also surface the current state explicitly with a non-color channel.
	var feedback: Dictionary = data.get("feedback", {})
	assert_true(feedback.has("preview"), "Feedback slot should describe the preview state.")
	assert_true(feedback.has("committed"), "Feedback slot should describe the committed state.")
	assert_equal((feedback.get("preview", {}) as Dictionary).get("cue_id"), "feedback_preview", "Feedback preview should map to the feedback_preview cue id.")
	assert_equal((feedback.get("committed", {}) as Dictionary).get("cue_id"), "feedback_committed", "Feedback committed should map to the feedback_committed cue id.")


func _audio_feedback_cues_always_have_visual_or_textual_equivalents() -> void:
	var data: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary()
	var cues: Dictionary = data.get("cues", {})
	var audio_cue_ids: Array[String] = []
	for cue_id: Variant in cues.keys():
		var entry: Dictionary = cues.get(cue_id, {})
		if not entry.has("audio_cue_id"):
			continue
		var audio_cue_id: String = String(entry.get("audio_cue_id", ""))
		assert_false(audio_cue_id.is_empty(), "Cue '%s' audio_cue_id must be a stable non-empty id." % String(cue_id))
		audio_cue_ids.append(audio_cue_id)
		# Every cue with an audio id must still carry a visual/textual channel (audio absent must not hide meaning).
		assert_true(_has_non_color_channel(entry.get("channels", [])), "Cue '%s' with audio must still carry a non-color visual/textual channel so the meaning survives with audio muted." % String(cue_id))

	assert_true(audio_cue_ids.has("audio_feedback_preview"), "feedback_preview should declare its parallel audio cue id.")
	assert_true(audio_cue_ids.has("audio_feedback_committed"), "feedback_committed should declare its parallel audio cue id.")

	# Audio-absent equivalence: with audio omitted, the visual/textual distinction must still hold.
	var muted: Dictionary = TacticalAccessibilityModel.from_state({"audio_available": false}).to_dictionary()
	var muted_feedback: Dictionary = muted.get("feedback", {})
	assert_equal((muted_feedback.get("preview", {}) as Dictionary).get("audio_available"), false, "Muted feedback should mark audio unavailable.")
	assert_true((muted_feedback.get("preview", {}) as Dictionary).get("visual_available", false), "Muted feedback preview must keep its visual/textual channel available.")
	assert_true((muted_feedback.get("committed", {}) as Dictionary).get("visual_available", false), "Muted feedback committed must keep its visual/textual channel available.")
	var preview_channels: Array = (muted_feedback.get("preview", {}) as Dictionary).get("channels", [])
	var committed_channels: Array = (muted_feedback.get("committed", {}) as Dictionary).get("channels", [])
	assert_false(_arrays_equal_as_set(preview_channels, committed_channels), "With audio absent, preview and committed must remain visually distinct.")


func _feedback_maps_from_active_preview_and_committed_result() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(2612)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

	# Active preview state -> feedback_preview active, feedback_committed inactive.
	flow.tap_attack_target(context, &"hero", Vector2i(2, 1), _weapon(&"sword"), null, null)
	var preview_state: Dictionary = flow.to_dictionary()
	var preview_model: Dictionary = TacticalAccessibilityModel.from_state({
		"commit_flow": preview_state
	}).to_dictionary()
	var preview_feedback: Dictionary = preview_model.get("feedback", {})
	assert_equal((preview_feedback.get("preview", {}) as Dictionary).get("active"), true, "Active attack preview should mark feedback_preview active.")
	assert_equal((preview_feedback.get("committed", {}) as Dictionary).get("active"), false, "Active attack preview should not mark feedback_committed active.")
	assert_true((preview_model.get("cue_ids", []) as Array).has("feedback_preview"), "Active preview model should surface the feedback_preview cue id.")

	# Successful committed result -> feedback_committed active.
	var commit_result: TacticalAttackCommitFlowResult = flow.confirm_attack(context, _weapon(&"sword"), null, null)
	assert_true(commit_result.submitted, "Confirm should submit the pending attack for the committed-feedback mapping.")
	var committed_model: Dictionary = TacticalAccessibilityModel.from_state({
		"commit_flow": flow.to_dictionary(),
		"commit_result": commit_result.to_dictionary()
	}).to_dictionary()
	var committed_feedback: Dictionary = committed_model.get("feedback", {})
	assert_equal((committed_feedback.get("committed", {}) as Dictionary).get("active"), true, "Successful commit result should mark feedback_committed active.")
	assert_true((committed_model.get("cue_ids", []) as Array).has("feedback_committed"), "Committed model should surface the feedback_committed cue id.")


func _text_scale_clamps_to_named_bounds() -> void:
	var min_scale: float = TacticalTextScale.MIN_TEXT_SCALE
	var max_scale: float = TacticalTextScale.MAX_TEXT_SCALE
	var below: Dictionary = TacticalTextScale.from_request(min_scale - 0.5).to_dictionary()
	var above: Dictionary = TacticalTextScale.from_request(max_scale + 0.5).to_dictionary()
	var inside: Dictionary = TacticalTextScale.from_request(1.25).to_dictionary()

	assert_equal(below.get("scale"), min_scale, "Below-bound text scale should clamp to MIN_TEXT_SCALE.")
	assert_equal(below.get("requested"), min_scale - 0.5, "Below-bound text scale should preserve the requested value.")
	assert_equal(below.get("clamped"), true, "Below-bound text scale should report clamped.")
	assert_equal(below.get("reason"), "clamped_min", "Below-bound text scale should expose a stable clamped-min reason.")
	assert_equal(above.get("scale"), max_scale, "Above-bound text scale should clamp to MAX_TEXT_SCALE.")
	assert_equal(above.get("clamped"), true, "Above-bound text scale should report clamped.")
	assert_equal(above.get("reason"), "clamped_max", "Above-bound text scale should expose a stable clamped-max reason.")
	assert_equal(inside.get("scale"), 1.25, "In-bounds text scale should pass through unchanged.")
	assert_equal(inside.get("clamped"), false, "In-bounds text scale should not report clamped.")
	assert_equal(inside.get("reason"), "valid", "In-bounds text scale should expose a valid reason.")
	assert_true(inside.has("label_scale_hint"), "Text scale should expose a presenter label sizing hint.")
	assert_true(inside.has("spacing_hint"), "Text scale should expose a presenter spacing hint.")
	assert_true(float(inside.get("label_scale_hint", 0.0)) > 0.0, "Label scale hint should be positive.")
	assert_true(float(inside.get("spacing_hint", 0.0)) > 0.0, "Spacing hint should be positive.")


func _malformed_text_scale_falls_back_to_one_with_stable_reason() -> void:
	var nan_scale: Dictionary = TacticalTextScale.from_request(NAN).to_dictionary()
	var inf_scale: Dictionary = TacticalTextScale.from_request(INF).to_dictionary()
	var zero_scale: Dictionary = TacticalTextScale.from_request(0.0).to_dictionary()
	var negative_scale: Dictionary = TacticalTextScale.from_request(-2.0).to_dictionary()
	var non_numeric_scale: Dictionary = TacticalTextScale.from_value("huge").to_dictionary()

	for malformed: Dictionary in [nan_scale, inf_scale, zero_scale, negative_scale, non_numeric_scale]:
		assert_equal(malformed.get("scale"), 1.0, "Malformed text scale should fall back to 1.0.")
		assert_equal(malformed.get("clamped"), true, "Malformed text scale should report clamped/coerced.")
		assert_equal(malformed.get("reason"), "invalid_scale", "Malformed text scale should preserve a stable invalid reason rather than a misleading valid.")


func _text_scale_change_never_mutates_tactical_truth() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.micro_combat_board())
	var streams: RngStreamSet = RngStreamSet.new(2613)
	var turn_state: TacticalTurnState = TacticalTurnState.new(2, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var pending_telegraphs: Array[Dictionary] = [_telegraph("ash_mark", Vector2i(3, 2), 1, 3, 4)]
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log)

	for requested_scale: float in [0.5, 1.0, 1.5, 2.0, 3.5]:
		TacticalAccessibilityModel.from_state({"text_scale": requested_scale}).to_dictionary()
		TacticalTextScale.from_request(requested_scale).to_dictionary()

	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log), before, "Changing text scale must not mutate board, RNG, turn, telegraphs, outcome, or event log.")


func _text_scale_change_never_alters_preview_legality_or_action_availability() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.attack_command_survive_board())
	var baseline_preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", Vector2i(2, 1), _weapon(&"sword")).to_dictionary()

	var baseline_vm: Dictionary = TacticalBoardViewModel.from_domain(board, null, _availability_options(board, 1.0)).to_dictionary()
	var scaled_vm: Dictionary = TacticalBoardViewModel.from_domain(board, null, _availability_options(board, 3.0)).to_dictionary()
	var clamped_vm: Dictionary = TacticalBoardViewModel.from_domain(board, null, _availability_options(board, 99.0)).to_dictionary()

	# Preview legality must be identical regardless of text scale.
	var rescaled_preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", Vector2i(2, 1), _weapon(&"sword")).to_dictionary()
	assert_equal(rescaled_preview.get("available"), baseline_preview.get("available"), "Attack preview legality must not change with text scale.")
	assert_equal(rescaled_preview.get("reason"), baseline_preview.get("reason"), "Attack preview reason must not change with text scale.")

	assert_equal(scaled_vm.get("action_availability"), baseline_vm.get("action_availability"), "Action availability must not change with text scale.")
	assert_equal(clamped_vm.get("action_availability"), baseline_vm.get("action_availability"), "Action availability must not change with clamped text scale.")
	assert_equal(scaled_vm.get("preview"), baseline_vm.get("preview"), "Preview contract must not change with text scale.")


func _accessibility_dictionaries_are_deep_copies_and_reference_free() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var context: TacticalActionContext = TacticalActionContext.new(board, null, null, [])
	var model: TacticalAccessibilityModel = TacticalAccessibilityModel.from_state({
		"text_scale": 1.5,
		"raw_context": context,
		"raw_board": board,
		"commit_flow": {
			"mode": "attack_preview",
			"raw_context": context,
			"target_cell": Vector2i(2, 1)
		}
	})

	var first_dictionary: Dictionary = model.to_dictionary()
	(first_dictionary.get("cues", {}) as Dictionary)["feedback_preview"]["severity"] = "presenter_mutation"
	(first_dictionary.get("text_scale", {}) as Dictionary)["scale"] = 99.0
	(first_dictionary.get("feedback", {}) as Dictionary)["preview"]["active"] = true

	var second_dictionary: Dictionary = model.to_dictionary()

	assert_equal(((second_dictionary.get("cues", {}) as Dictionary).get("feedback_preview", {}) as Dictionary).get("severity"), "info", "Accessibility model should return fresh cue dictionaries.")
	assert_equal((second_dictionary.get("text_scale", {}) as Dictionary).get("scale"), 1.5, "Accessibility model should return fresh text-scale copies.")
	assert_false((second_dictionary.get("feedback", {}) as Dictionary).has("raw_context"), "Feedback slot should never carry raw context references.")
	_assert_no_forbidden_references(second_dictionary, "Accessibility data should not expose raw domain, command, resource, scene, node, theme, font, or callable references.")


func _building_accessibility_data_does_not_execute_commands_or_mutate_state() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.attack_command_survive_board())
	var streams: RngStreamSet = RngStreamSet.new(2614)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var pending_telegraphs: Array[Dictionary] = []
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log)
	var enemy_hp_before: int = board.get_entity(&"enemy_1").current_hp

	# Build an attack preview to source feedback_preview from, then build accessibility data many times.
	var preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", Vector2i(2, 1), _weapon(&"sword")).to_dictionary()
	for _iteration: int in range(5):
		TacticalAccessibilityModel.from_state({
			"text_scale": 2.0,
			"preview": preview,
			"audio_available": true
		}).to_dictionary()

	assert_equal(board.get_entity(&"enemy_1").current_hp, enemy_hp_before, "Building accessibility data must not damage entities (no command execution).")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log), before, "Building accessibility data must not mutate board, turn, RNG, telegraphs, outcome, or event log.")


func _board_view_model_carries_sanitized_accessibility_slot() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.micro_combat_board())
	var context: TacticalActionContext = TacticalActionContext.new(board, null, null, [])
	var accessibility: Dictionary = TacticalAccessibilityModel.from_state({"text_scale": 1.5}).to_dictionary()
	accessibility["raw_board"] = board
	accessibility["raw_context"] = context

	var data: Dictionary = TacticalBoardViewModel.from_domain(board, null, {
		"accessibility": accessibility
	}).to_dictionary()
	var carried: Dictionary = data.get("accessibility", {})

	assert_true(data.has("accessibility"), "Board VM should expose an accessibility slot when supplied.")
	assert_equal(carried.get("kind"), "accessibility", "Board VM should carry the accessibility kind.")
	assert_equal(carried.get("color_independent"), true, "Board VM should carry the color-independence assertion.")
	assert_equal(carried.get("raw_board"), null, "Board VM accessibility slot should strip raw BoardState references.")
	assert_equal(carried.get("raw_context"), null, "Board VM accessibility slot should strip raw context references.")
	assert_equal((carried.get("text_scale", {}) as Dictionary).get("scale"), 1.5, "Board VM should preserve copied text-scale data.")
	_assert_no_forbidden_references(data, "Board VM accessibility integration should stay presenter-safe.")

	# Default behavior: without an accessibility option, the slot is an empty presenter-safe dictionary.
	var default_data: Dictionary = TacticalBoardViewModel.from_domain(board, null, {}).to_dictionary()
	assert_equal(default_data.get("accessibility"), {}, "Accessibility should default to an empty presenter-safe dictionary.")


# --- helpers ---------------------------------------------------------------

func _availability_options(board: BoardState, text_scale: float) -> Dictionary:
	var preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", Vector2i(2, 1), _weapon(&"sword")).to_dictionary()
	return {
		"preview": preview,
		"accessibility": TacticalAccessibilityModel.from_state({"text_scale": text_scale}).to_dictionary()
	}


func _assert_cue_ids_have_accessibility_mappings(cue_ids: Variant, context_label: String) -> void:
	var model: TacticalAccessibilityModel = TacticalAccessibilityModel.from_state()
	var cues: Dictionary = model.to_dictionary().get("cues", {})
	if not cue_ids is Array:
		return
	for cue_id_value: Variant in cue_ids:
		var cue_id: String = String(cue_id_value)
		# Availability/cancel cues are presentation-flow markers; the critical-meaning set is what AC1 audits.
		if cue_id == "preview_effect" or cue_id == "cancel_available":
			continue
		assert_true(cues.has(cue_id), "Cue '%s' emitted by %s must have an accessibility mapping." % [cue_id, context_label])
		var entry: Dictionary = cues.get(cue_id, {})
		assert_true(_has_non_color_channel(entry.get("channels", [])), "Cue '%s' from %s must register at least one non-color channel." % [cue_id, context_label])


func _has_non_color_channel(channels: Variant) -> bool:
	if not channels is Array:
		return false
	for channel_value: Variant in channels:
		if NON_COLOR_CHANNELS.has(String(channel_value)):
			return true
	return false


func _arrays_equal_as_set(first: Variant, second: Variant) -> bool:
	if not first is Array or not second is Array:
		return false
	var first_set: Dictionary = {}
	var second_set: Dictionary = {}
	for value: Variant in first:
		first_set[String(value)] = true
	for value: Variant in second:
		second_set[String(value)] = true
	return first_set == second_set


func _fixture_board(fixture_name: String) -> BoardState:
	match fixture_name:
		"attack_preview_adjacent_enemy":
			return BoardFixtureFactory.attack_preview_adjacent_enemy()
		"attack_preview_blocked_lane":
			return BoardFixtureFactory.attack_preview_blocked_lane()
		"attack_preview_diagonal_enemy":
			return BoardFixtureFactory.attack_preview_diagonal_enemy()
		"attack_preview_open_lane":
			return BoardFixtureFactory.attack_preview_open_lane()
		"attack_preview_hidden_enemy":
			return BoardFixtureFactory.attack_preview_hidden_enemy()
		"attack_preview_memory_enemy":
			return BoardFixtureFactory.attack_preview_memory_enemy()
		"attack_preview_empty_target":
			return BoardFixtureFactory.attack_preview_empty_target()
		"attack_preview_dead_target":
			return BoardFixtureFactory.attack_preview_dead_target()
		"attack_preview_friendly_target":
			return BoardFixtureFactory.attack_preview_friendly_target()
		_:
			return null


func _visible_board(board: BoardState) -> BoardState:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true
	return board


func _telegraph(telegraph_id: String, marked_cell: Vector2i, created_turn: int, due_turn: int, damage: int) -> Dictionary:
	return {
		"telegraph_id": telegraph_id,
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"target_entity_id": "hero",
		"marked_cell": _cell(marked_cell.x, marked_cell.y),
		"created_turn_number": created_turn,
		"due_turn_number": due_turn,
		"damage": damage,
		"damage_type": "fire",
		"status": "pending"
	}


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _cell(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y
	}


func _sorted_keys(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in data.keys():
		result.append(String(key))
	result.sort()
	return result


func _assert_no_forbidden_references(value: Variant, message: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var data: Dictionary = value
			for key: Variant in data.keys():
				_assert_no_forbidden_references(data[key], message)
		TYPE_ARRAY:
			for item: Variant in value:
				_assert_no_forbidden_references(item, message)
		TYPE_CALLABLE:
			assert_false(true, message)
		TYPE_OBJECT:
			assert_false(value is BoardState, message)
			assert_false(value is BoardCell, message)
			assert_false(value is TacticalEntityState, message)
			assert_false(value is DomainEvent, message)
			assert_false(value is TacticalActionContext, message)
			assert_false(value is ActionResult, message)
			assert_false(value is WeaponDefinition, message)
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
