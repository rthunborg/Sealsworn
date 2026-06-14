extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalBoardZoomState = preload("res://scripts/ui/view_models/tactical_board_zoom_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalInspectView = preload("res://scripts/ui/view_models/tactical_inspect_view.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")
const TacticalMovementPreview = preload("res://scripts/ui/view_models/tactical_movement_preview.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const REQUIRED_REGIONS: Array[String] = [
	"board",
	"preview",
	"confirm_cancel",
	"inspect",
	"status",
	"log_or_outcome"
]
const PRIMARY_CONTROLS: Array[String] = [
	"preview",
	"confirm",
	"cancel",
	"inspect",
	"status"
]

func run() -> Dictionary:
	_resolves_phone_portrait_with_board_first_priority()
	_resolves_phone_landscape_with_side_panels()
	_resolves_tablet_for_tablet_fixtures()
	_resolves_desktop_for_wide_fixture()
	_exposes_stable_orientation_ids()
	_profile_dictionary_exposes_stable_keys_and_cue_ids()
	_safe_area_shrinks_content_area_and_keeps_controls_inside()
	_malformed_viewport_values_return_stable_fallback()
	_malformed_safe_area_and_content_scale_return_stable_fallback()
	_layout_dictionaries_are_deep_copies_with_no_forbidden_references()
	_thresholds_are_exposed_as_named_constants()
	_board_view_model_carries_sanitized_layout_slot()
	_layout_change_preserves_selection_preview_and_no_mutation()
	_layout_change_preserves_attack_commit_flow_without_command()
	_layout_change_preserves_inspect_and_zoom_without_command()
	_layout_change_does_not_enable_stale_attack_confirm()
	return result()


func _resolves_phone_portrait_with_board_first_priority() -> void:
	var profile: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0)
	}).to_dictionary()
	var regions: Dictionary = profile.get("regions", {})
	var board_region: Dictionary = regions.get("board", {})

	assert_equal(profile.get("profile_id"), "phone_portrait", "390x844 should resolve to phone_portrait.")
	assert_equal(profile.get("orientation"), "portrait", "390x844 should report portrait orientation.")
	assert_equal(profile.get("board_priority"), "primary", "Phone portrait should prioritize the board.")
	assert_equal(profile.get("available"), true, "Valid phone portrait viewport should be available.")
	assert_equal(profile.get("reason"), "valid", "Valid phone portrait viewport should report valid reason.")
	assert_true(_area(board_region) > 0, "Phone portrait board region should be non-empty.")
	assert_true(_board_is_largest_region(regions), "Phone portrait board region must be the largest first-priority region.")
	assert_true((profile.get("cue_ids", []) as Array).has("layout_profile_phone_portrait"), "Phone portrait should expose its profile cue id.")
	_assert_primary_controls_reachable_inside_content(profile)


func _resolves_phone_landscape_with_side_panels() -> void:
	var profile: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(844.0, 390.0)
	}).to_dictionary()
	var regions: Dictionary = profile.get("regions", {})
	var board_region: Dictionary = regions.get("board", {})
	var confirm_region: Dictionary = regions.get("confirm_cancel", {})

	assert_equal(profile.get("profile_id"), "phone_landscape", "844x390 should resolve to phone_landscape.")
	assert_equal(profile.get("orientation"), "landscape", "844x390 should report landscape orientation.")
	assert_true((profile.get("cue_ids", []) as Array).has("layout_profile_phone_landscape"), "Phone landscape should expose its profile cue id.")
	# Controls should move to a side region: confirm/cancel must not span the full width edge-to-edge.
	assert_true(float(confirm_region.get("width", 0.0)) < float(profile.get("content_area", {}).get("width", 0.0)), "Phone landscape should move confirm/cancel to a side region, not full width.")
	assert_true(_area(board_region) > 0, "Phone landscape board region should be non-empty.")
	_assert_primary_controls_reachable_inside_content(profile)


func _resolves_tablet_for_tablet_fixtures() -> void:
	var portrait_tablet: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(834.0, 1194.0)
	}).to_dictionary()
	var landscape_tablet: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(1194.0, 834.0)
	}).to_dictionary()

	assert_equal(portrait_tablet.get("profile_id"), "tablet", "834x1194 should resolve to tablet.")
	assert_equal(portrait_tablet.get("orientation"), "portrait", "834x1194 should report portrait orientation.")
	assert_equal(landscape_tablet.get("profile_id"), "tablet", "1194x834 should resolve to tablet.")
	assert_equal(landscape_tablet.get("orientation"), "landscape", "1194x834 should report landscape orientation.")
	assert_true((portrait_tablet.get("cue_ids", []) as Array).has("layout_profile_tablet"), "Tablet should expose its profile cue id.")
	_assert_primary_controls_reachable_inside_content(portrait_tablet)
	_assert_primary_controls_reachable_inside_content(landscape_tablet)


func _resolves_desktop_for_wide_fixture() -> void:
	var profile: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(1440.0, 900.0)
	}).to_dictionary()

	assert_equal(profile.get("profile_id"), "desktop", "1440x900 should resolve to desktop.")
	assert_equal(profile.get("orientation"), "landscape", "1440x900 should report landscape orientation.")
	assert_equal(profile.get("density"), "comfortable", "Desktop should use comfortable density.")
	assert_true((profile.get("cue_ids", []) as Array).has("layout_profile_desktop"), "Desktop should expose its profile cue id.")
	_assert_primary_controls_reachable_inside_content(profile)


func _exposes_stable_orientation_ids() -> void:
	var square: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(900.0, 900.0)
	}).to_dictionary()
	assert_equal(square.get("orientation"), "square", "Equal width/height should report square orientation.")
	assert_true(["phone_portrait", "phone_landscape", "tablet", "desktop"].has(square.get("profile_id")), "Square viewports should still resolve a stable profile id.")


func _profile_dictionary_exposes_stable_keys_and_cue_ids() -> void:
	var profile: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0)
	}).to_dictionary()

	assert_equal(_sorted_keys(profile), [
		"available",
		"board_priority",
		"content_area",
		"content_scale",
		"control_slots",
		"cue_ids",
		"density",
		"kind",
		"minimum_touch_target",
		"orientation",
		"profile_id",
		"reason",
		"regions",
		"safe_area",
		"spacing",
		"viewport_size"
	], "Layout profile should expose stable top-level dictionary keys.")
	assert_equal(profile.get("kind"), "layout_profile", "Layout profile should report a stable kind.")
	var regions: Dictionary = profile.get("regions", {})
	for region_name: String in REQUIRED_REGIONS:
		assert_true(regions.has(region_name), "Layout profile regions should include %s." % region_name)
	var control_slots: Dictionary = profile.get("control_slots", {})
	for control_name: String in PRIMARY_CONTROLS:
		assert_true(control_slots.has(control_name), "Layout profile control slots should include %s." % control_name)


func _safe_area_shrinks_content_area_and_keeps_controls_inside() -> void:
	var profile: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0),
		"safe_area": Rect2i(0, 47, 390, 763)
	}).to_dictionary()
	var content_area: Dictionary = profile.get("content_area", {})

	assert_equal(float(content_area.get("y", 0.0)), 47.0, "Safe area top inset should push the content area down.")
	assert_equal(float(content_area.get("height", 0.0)), 763.0, "Safe area should shrink the interactive content height.")
	assert_true(float(content_area.get("height", 0.0)) < 844.0, "Safe area should shrink the content area below the raw viewport height.")
	assert_true((profile.get("cue_ids", []) as Array).has("layout_safe_area_applied"), "Applied safe area should expose a stable cue id.")
	_assert_primary_controls_reachable_inside_content(profile)
	# Every region must also stay inside the safe-area-derived content area.
	var regions: Dictionary = profile.get("regions", {})
	for region_name: String in REQUIRED_REGIONS:
		var region: Dictionary = regions.get(region_name, {})
		if _area(region) <= 0:
			continue
		assert_true(_rect_inside(region, content_area), "Region %s must stay inside the safe-area content region." % region_name)


func _malformed_viewport_values_return_stable_fallback() -> void:
	var cases: Array[Dictionary] = [
		{"id": "zero", "viewport_size": Vector2(0.0, 0.0)},
		{"id": "negative", "viewport_size": Vector2(-390.0, 844.0)},
		{"id": "nan", "viewport_size": Vector2(NAN, 844.0)},
		{"id": "infinity", "viewport_size": Vector2(INF, 844.0)}
	]
	for case_data: Dictionary in cases:
		var profile: Dictionary = TacticalLayoutProfile.from_viewport({
			"viewport_size": case_data.get("viewport_size")
		}).to_dictionary()
		assert_equal(profile.get("available"), false, "%s viewport should be unavailable." % String(case_data.get("id", "")))
		assert_equal(profile.get("reason"), "fallback_invalid_viewport", "%s viewport should expose a stable fallback reason." % String(case_data.get("id", "")))
		assert_equal(profile.get("profile_id"), "phone_portrait", "%s fallback should resolve to the conservative phone_portrait profile id." % String(case_data.get("id", "")))
		assert_true((profile.get("cue_ids", []) as Array).has("layout_fallback"), "%s fallback should expose the layout_fallback cue id." % String(case_data.get("id", "")))
		# Even a fallback should expose the required region and control slot keys so presenters never crash.
		var regions: Dictionary = profile.get("regions", {})
		for region_name: String in REQUIRED_REGIONS:
			assert_true(regions.has(region_name), "%s fallback regions should include %s." % [String(case_data.get("id", "")), region_name])


func _malformed_safe_area_and_content_scale_return_stable_fallback() -> void:
	# A malformed safe area must not throw; it should fall back to the full viewport as content area.
	var bad_safe_area: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0),
		"safe_area": {"x": "left", "y": 0, "width": 390, "height": 844}
	}).to_dictionary()
	assert_equal(bad_safe_area.get("available"), true, "A malformed safe area should not disable an otherwise valid viewport.")
	assert_equal(float(bad_safe_area.get("content_area", {}).get("width", 0.0)), 390.0, "A malformed safe area should fall back to the full viewport width.")
	assert_false((bad_safe_area.get("cue_ids", []) as Array).has("layout_safe_area_applied"), "An ignored safe area should not claim it was applied.")

	# A malformed content scale must not throw; it should fall back to a scale of 1.0.
	var bad_scale: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0),
		"content_scale": NAN
	}).to_dictionary()
	assert_equal(bad_scale.get("available"), true, "A malformed content scale should not disable an otherwise valid viewport.")
	assert_equal(float(bad_scale.get("content_scale", 0.0)), 1.0, "A malformed content scale should fall back to 1.0.")


func _layout_dictionaries_are_deep_copies_with_no_forbidden_references() -> void:
	var profile_helper: TacticalLayoutProfile = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0)
	})
	var first: Dictionary = profile_helper.to_dictionary()
	(first.get("regions", {}) as Dictionary)["board"]["width"] = -1.0
	(first.get("control_slots", {}) as Dictionary)["confirm"]["reachable"] = false
	(first.get("cue_ids", []) as Array).append("mutated")
	var second: Dictionary = profile_helper.to_dictionary()

	assert_true(float((second.get("regions", {}) as Dictionary).get("board", {}).get("width", 0.0)) > 0.0, "Editing a returned layout dictionary must not mutate cached region data.")
	assert_equal(((second.get("control_slots", {}) as Dictionary).get("confirm", {}) as Dictionary).get("reachable"), true, "Editing a returned layout dictionary must not mutate cached control slot data.")
	assert_false((second.get("cue_ids", []) as Array).has("mutated"), "Editing a returned layout dictionary must not mutate cached cue ids.")
	_assert_no_forbidden_references(second, "Layout dictionaries should be presenter-safe deep copies.")


func _thresholds_are_exposed_as_named_constants() -> void:
	assert_true(TacticalLayoutProfile.PHONE_MAX_DIMENSION > 0, "Phone threshold should be a positive named constant.")
	assert_true(TacticalLayoutProfile.DESKTOP_MIN_WIDTH >= TacticalLayoutProfile.PHONE_MAX_DIMENSION, "Desktop threshold should be a tunable named constant.")
	assert_true(TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET.x > 0.0, "Minimum touch target should be a positive named constant.")


func _board_view_model_carries_sanitized_layout_slot() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var layout: Dictionary = TacticalLayoutProfile.from_viewport({
		"viewport_size": Vector2(390.0, 844.0)
	}).to_dictionary()
	layout["raw_board"] = board
	layout["regions"]["raw_entity"] = board.get_entity(&"enemy_iron")

	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"layout": layout
	}).to_dictionary()
	var carried_layout: Dictionary = data.get("layout", {})

	assert_true(data.has("layout"), "Board view-model should expose a layout slot.")
	assert_equal(carried_layout.get("profile_id"), "phone_portrait", "Board view-model should carry the layout profile id.")
	assert_equal(carried_layout.get("raw_board"), null, "Board view-model layout slot should strip raw BoardState references.")
	assert_equal((carried_layout.get("regions", {}) as Dictionary).get("raw_entity"), null, "Board view-model layout regions should strip raw entity references.")
	# A default board VM without a layout option should expose an empty presenter-safe layout dictionary.
	var no_layout: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {}).to_dictionary()
	assert_equal(no_layout.get("layout"), {}, "Layout should default to an empty presenter-safe dictionary.")
	_assert_no_forbidden_references(data, "Board view-model layout integration should stay presenter-safe.")


func _layout_change_preserves_selection_preview_and_no_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var streams: RngStreamSet = RngStreamSet.new(2501)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var preview: Dictionary = TacticalMovementPreview.from_query(board, &"hero", Vector2i(1, 2)).to_dictionary()

	var portrait: Dictionary = _board_data_with_layout(board, turn_state, preview, Vector2(390.0, 844.0))
	var landscape: Dictionary = _board_data_with_layout(board, turn_state, preview, Vector2(844.0, 390.0))
	var tablet: Dictionary = _board_data_with_layout(board, turn_state, preview, Vector2(834.0, 1194.0))

	assert_equal((portrait.get("layout", {}) as Dictionary).get("profile_id"), "phone_portrait", "Portrait sizing should produce the phone_portrait layout.")
	assert_equal((landscape.get("layout", {}) as Dictionary).get("profile_id"), "phone_landscape", "Landscape sizing should produce the phone_landscape layout.")
	assert_equal((tablet.get("layout", {}) as Dictionary).get("profile_id"), "tablet", "Tablet sizing should produce the tablet layout.")

	# Selection + preview must persist identically across every profile change.
	for data: Dictionary in [portrait, landscape, tablet]:
		assert_equal(data.get("selected_cell"), _cell(0, 2), "Selected cell must persist across layout changes.")
		assert_equal(data.get("selected_entity_id"), "hero", "Selected entity must persist across layout changes.")
		assert_equal((data.get("preview", {}) as Dictionary).get("target_cell"), _cell(1, 2), "Preview target must persist across layout changes.")
		assert_equal((data.get("preview", {}) as Dictionary).get("kind"), "move", "Preview kind must persist across layout changes.")
		assert_equal(((data.get("action_availability", {}) as Dictionary).get("move", {}) as Dictionary).get("enabled"), true, "Move availability must persist across layout changes.")

	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Layout/profile changes must not mutate board, turn, RNG, telegraphs, or event log.")


func _layout_change_preserves_attack_commit_flow_without_command() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var streams: RngStreamSet = RngStreamSet.new(2502)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
	var tap_result: Variant = flow.tap_attack_target(context, &"hero", Vector2i(3, 2), _weapon(&"bow"), _support(&"none"), null)
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var flow_data: Dictionary = flow.to_dictionary()

	# Desktop -> phone-sized layout change while an attack commit flow is active.
	var desktop: Dictionary = _board_data_with_attack_flow(board, turn_state, flow_data, Vector2(1440.0, 900.0))
	var phone: Dictionary = _board_data_with_attack_flow(board, turn_state, flow_data, Vector2(390.0, 844.0))

	assert_false(tap_result.submitted, "First attack tap should be preview-only.")
	assert_equal((desktop.get("layout", {}) as Dictionary).get("profile_id"), "desktop", "Wide sizing should produce desktop layout.")
	assert_equal((phone.get("layout", {}) as Dictionary).get("profile_id"), "phone_portrait", "Phone sizing should produce phone_portrait layout.")
	for data: Dictionary in [desktop, phone]:
		assert_equal((data.get("commit_flow", {}) as Dictionary).get("mode"), "attack_preview", "Active commit flow must persist across layout changes.")
		assert_equal((data.get("commit_flow", {}) as Dictionary).get("target_cell"), _cell(3, 2), "Commit-flow target must persist across layout changes.")
		assert_equal((data.get("commit_flow", {}) as Dictionary).get("weapon_id"), "bow", "Commit-flow weapon must persist across layout changes.")
		assert_equal(((data.get("action_availability", {}) as Dictionary).get("confirm", {}) as Dictionary).get("enabled"), true, "Confirm must remain enabled by matching commit-flow metadata, not by layout.")
	assert_equal(flow.to_dictionary().get("mode"), "attack_preview", "Rebuilding layout must not submit or clear the attack flow.")
	assert_equal(board.get_entity(&"enemy_iron").current_hp, 10, "Layout change during attack preview must not damage the target.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Layout change during attack preview must not mutate tactical snapshot data.")


func _layout_change_preserves_inspect_and_zoom_without_command() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var streams: RngStreamSet = RngStreamSet.new(2503)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(1, 2), {
		"actor_id": &"hero"
	}).to_dictionary()
	var zoom: Dictionary = TacticalBoardZoomState.from_options({
		"board_size": Vector2i(6, 6),
		"cell_size": Vector2(48.0, 48.0),
		"focused_cell": Vector2i(1, 2),
		"zoom": 1.5
	}).to_dictionary()

	var portrait: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"inspect": inspect,
		"zoom": zoom,
		"layout": _layout(Vector2(390.0, 844.0))
	}).to_dictionary()
	var tablet: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"inspect": inspect,
		"zoom": zoom,
		"layout": _layout(Vector2(1194.0, 834.0))
	}).to_dictionary()

	for data: Dictionary in [portrait, tablet]:
		assert_equal((data.get("inspect", {}) as Dictionary).get("target_cell"), _cell(1, 2), "Inspect target must persist across layout changes.")
		assert_equal((data.get("zoom", {}) as Dictionary).get("focused_cell"), _cell(1, 2), "Zoom focused cell must persist across layout changes.")
		assert_true((data.get("action_availability", {}) as Dictionary).has("inspect"), "Inspect availability must remain present across layout changes.")
	assert_equal(board.get_entity(&"enemy_iron").current_hp, 10, "Layout change during inspect must not submit commands.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Layout change during inspect/zoom must not mutate tactical snapshot data.")


func _layout_change_does_not_enable_stale_attack_confirm() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var streams: RngStreamSet = RngStreamSet.new(2504)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
	flow.tap_attack_target(context, &"hero", Vector2i(3, 2), _weapon(&"bow"), _support(&"none"), null)
	var flow_data: Dictionary = flow.to_dictionary()
	# Build a preview pointing at a DIFFERENT target so commit-flow metadata is stale.
	var stale_preview: Dictionary = {
		"kind": "attack",
		"available": true,
		"reason": "valid",
		"actor_id": "hero",
		"target_cell": {"x": 1, "y": 5},
		"target_entity_id": "enemy_seer",
		"commit_available": true,
		"commit_reason": "valid",
		"metadata": {"weapon_id": "bow"}
	}

	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": stale_preview,
		"commit_flow": flow_data,
		"layout": _layout(Vector2(390.0, 844.0)),
		"action_availability": {
			"confirm": {"enabled": true, "reason": "presenter_override"},
			"cancel": {"enabled": true, "reason": "presenter_override"}
		}
	}).to_dictionary()
	var availability: Dictionary = data.get("action_availability", {})

	assert_equal((availability.get("confirm", {}) as Dictionary).get("enabled"), false, "Layout plus presenter override must not enable confirm for a stale commit flow.")
	assert_equal((availability.get("confirm", {}) as Dictionary).get("reason"), "stale_commit_flow", "Stale confirm must expose the stale_commit_flow reason.")
	assert_equal((availability.get("cancel", {}) as Dictionary).get("enabled"), false, "Layout plus presenter override must not enable cancel for a stale commit flow.")


# --- helpers ---------------------------------------------------------------

func _layout(viewport_size: Vector2) -> Dictionary:
	return TacticalLayoutProfile.from_viewport({
		"viewport_size": viewport_size
	}).to_dictionary()


func _board_data_with_layout(board: BoardState, turn_state: TacticalTurnState, preview: Dictionary, viewport_size: Vector2) -> Dictionary:
	return TacticalBoardViewModel.from_domain(board, turn_state, {
		"selection": {
			"selected_cell": Vector2i(0, 2),
			"selected_entity_id": &"hero"
		},
		"preview": preview,
		"layout": _layout(viewport_size)
	}).to_dictionary()


func _board_data_with_attack_flow(board: BoardState, turn_state: TacticalTurnState, flow_data: Dictionary, viewport_size: Vector2) -> Dictionary:
	return TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": flow_data.get("preview", {}),
		"commit_flow": flow_data,
		"layout": _layout(viewport_size)
	}).to_dictionary()


func _assert_primary_controls_reachable_inside_content(profile: Dictionary) -> void:
	var control_slots: Dictionary = profile.get("control_slots", {})
	var regions: Dictionary = profile.get("regions", {})
	var content_area: Dictionary = profile.get("content_area", {})
	var minimum_touch_target: Dictionary = profile.get("minimum_touch_target", {})
	for control_name: String in PRIMARY_CONTROLS:
		var slot: Dictionary = control_slots.get(control_name, {})
		assert_true(slot.has("region"), "Control %s must name a region." % control_name)
		assert_equal(slot.get("reachable"), true, "Control %s must be reachable." % control_name)
		var region_name: String = String(slot.get("region", ""))
		var region: Dictionary = regions.get(region_name, {})
		assert_true(_area(region) > 0, "Control %s region %s must be non-empty." % [control_name, region_name])
		assert_true(_rect_inside(region, content_area), "Control %s region %s must stay inside the content area." % [control_name, region_name])
		assert_true(float(region.get("width", 0.0)) >= float(minimum_touch_target.get("x", 0.0)), "Control %s region must be at least one touch target wide." % control_name)
		assert_true(float(region.get("height", 0.0)) >= float(minimum_touch_target.get("y", 0.0)), "Control %s region must be at least one touch target tall." % control_name)


func _board_is_largest_region(regions: Dictionary) -> bool:
	var board_area: float = _area(regions.get("board", {}))
	for region_name: String in regions.keys():
		if region_name == "board":
			continue
		if _area(regions.get(region_name, {})) > board_area:
			return false
	return board_area > 0.0


func _area(region: Variant) -> float:
	if not region is Dictionary:
		return 0.0
	var data: Dictionary = region
	return float(data.get("width", 0.0)) * float(data.get("height", 0.0))


func _rect_inside(inner: Dictionary, outer: Dictionary) -> bool:
	var inner_x: float = float(inner.get("x", 0.0))
	var inner_y: float = float(inner.get("y", 0.0))
	var inner_right: float = inner_x + float(inner.get("width", 0.0))
	var inner_bottom: float = inner_y + float(inner.get("height", 0.0))
	var outer_x: float = float(outer.get("x", 0.0))
	var outer_y: float = float(outer.get("y", 0.0))
	var outer_right: float = outer_x + float(outer.get("width", 0.0))
	var outer_bottom: float = outer_y + float(outer.get("height", 0.0))
	return inner_x >= outer_x - 0.01 and inner_y >= outer_y - 0.01 and inner_right <= outer_right + 0.01 and inner_bottom <= outer_bottom + 0.01


func _reveal_all(board: BoardState) -> void:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> Variant:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _cell(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y
	}


func _sorted_keys(data: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in data.keys():
		keys.append(String(key))
	keys.sort()
	return keys


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
			assert_false(value is DomainEvent, message)
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
