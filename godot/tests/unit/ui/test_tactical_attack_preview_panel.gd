extends "res://tests/unit/test_case.gd"

# Story 14.2 (Task 2 — the F2 armed-preview panel) — TacticalAttackPreviewPanel coverage. Proves the scene-free
# projection reads ONLY the pinned VM slots (preview + commit_flow + action_availability) and decides the
# armed-vs-not state + the panel content:
#   - the EXACT PANEL_KEYS set for BOTH the armed and un-armed projections (a key never silently appears/vanishes);
#   - a LIVE armed attack (built through the real TacticalAttackCommitFlow -> the VM the way render() derives it)
#     projects is_armed: true with the target cell, the expected damage, the weapon reach, and confirm/cancel
#     enabled — proving Task 1's data flow (the preview derived from the armed commit flow actually populates the
#     VM preview/action_availability);
#   - the adjacent-ranged warning + blocker state surface;
#   - a move preview / a stale attack preview / an empty VM project is_armed: false (no crash);
#   - zero mutation of the input VM dict.
# str() (never eager String(nullable)) is used in assert messages (the 14.1 retro test-honesty note).

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalAttackPreviewPanel = preload("res://scripts/ui/view_models/tactical_attack_preview_panel.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_panel_keys_are_exact_for_armed_and_unarmed()
	_live_armed_attack_projects_the_panel()
	_synthetic_armed_panel_surfaces_warning_and_blocker_state()
	_move_preview_is_not_armed()
	_stale_attack_preview_without_commit_flow_is_not_armed()
	_empty_vm_is_not_armed_without_crash()
	_projection_does_not_mutate_the_input()
	return result()


# ---- exact-key discipline ------------------------------------------------------------------------

func _panel_keys_are_exact_for_armed_and_unarmed() -> void:
	_assert_exact_keys(TacticalAttackPreviewPanel.from_board_vm({}), TacticalAttackPreviewPanel.PANEL_KEYS, "The un-armed panel must carry EXACTLY the PANEL_KEYS set.")
	var armed: Dictionary = TacticalAttackPreviewPanel.from_board_vm(_synthetic_armed_vm())
	_assert_exact_keys(armed, TacticalAttackPreviewPanel.PANEL_KEYS, "The armed panel must carry EXACTLY the PANEL_KEYS set.")


# ---- the live data flow (Task 1 + Task 2) --------------------------------------------------------

func _live_armed_attack_projects_the_panel() -> void:
	# A real armed attack: hero (0,2) previews a bow strike on enemy_iron (3,2) on the revealed micro board.
	var board: BoardState = _visible_board(BoardFixtureFactory.micro_combat_board())
	var streams: RngStreamSet = RngStreamSet.new(4201)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
	var arm: Variant = flow.tap_attack_target(context, &"hero", Vector2i(3, 2), _weapon(&"bow"), _support(&"none"), null, TacticalCommandBridge.new())
	assert_false(arm.submitted, "Setup: the first bow tap should ARM, not commit.")
	var commit_flow: Dictionary = flow.to_dictionary()
	assert_equal(commit_flow.get("mode"), "attack_preview", "Setup: the flow should be armed (attack_preview). Got %s." % str(commit_flow.get("mode")))

	# Build the VM the way render() does: the preview slot is DERIVED from the armed commit flow (no new query).
	var vm: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": commit_flow.get("preview", {}),
		"commit_flow": commit_flow
	}).to_dictionary()
	var panel: Dictionary = TacticalAttackPreviewPanel.from_board_vm(vm)

	assert_equal(panel.get("is_armed"), true, "A live armed attack projects is_armed: true.")
	assert_equal(panel.get("target_cell"), {"x": 3, "y": 2}, "The panel carries the armed target cell. Got %s." % str(panel.get("target_cell")))
	assert_equal(panel.get("confirm_enabled"), true, "A valid armed attack enables Confirm (Task 1 availability populates).")
	assert_equal(panel.get("cancel_enabled"), true, "A valid armed attack enables Cancel.")
	var meta: Dictionary = (commit_flow.get("preview", {}) as Dictionary).get("metadata", {})
	assert_equal(panel.get("expected_damage"), int(meta.get("expected_damage", -999)), "The panel reports the preview's expected damage.")
	assert_equal(panel.get("weapon_reach"), int(meta.get("weapon_reach", -999)), "The panel reports the preview's weapon reach.")
	assert_false(String(panel.get("armed_label", "")).is_empty(), "The armed label (the non-color NFR9 channel) must be non-empty.")
	assert_true(String(panel.get("armed_label", "")).contains("enemy_iron"), "The armed label names the target enemy. Got %s." % str(panel.get("armed_label")))
	assert_false((panel.get("lines", []) as Array).is_empty(), "The armed panel provides render lines.")


# ---- synthetic slot content ----------------------------------------------------------------------

func _synthetic_armed_panel_surfaces_warning_and_blocker_state() -> void:
	var panel: Dictionary = TacticalAttackPreviewPanel.from_board_vm(_synthetic_armed_vm())
	assert_equal(panel.get("is_armed"), true, "The synthetic armed VM projects is_armed: true.")
	assert_equal(panel.get("blocker_state"), "clear", "The panel surfaces the blocker state. Got %s." % str(panel.get("blocker_state")))
	assert_equal(panel.get("targeting_shape"), "straight_line", "The panel surfaces the targeting shape. Got %s." % str(panel.get("targeting_shape")))
	var warnings: Array = panel.get("warnings", [])
	assert_equal(warnings.size(), 1, "The panel surfaces the adjacent-ranged warning. Got %s." % str(warnings))
	assert_true(String(warnings[0] if warnings.size() > 0 else "").contains("Adjacent"), "The warning text is surfaced. Got %s." % str(warnings))


# ---- un-armed states -----------------------------------------------------------------------------

func _move_preview_is_not_armed() -> void:
	var vm: Dictionary = {
		"preview": {"kind": "move", "target_cell": {"x": 1, "y": 1}},
		"commit_flow": {"mode": "none"},
		"action_availability": {"confirm": {"enabled": false}, "cancel": {"enabled": false}}
	}
	var panel: Dictionary = TacticalAttackPreviewPanel.from_board_vm(vm)
	assert_equal(panel.get("is_armed"), false, "A move preview is not an armed attack.")
	assert_equal(panel.get("target_cell"), null, "An un-armed panel has no target cell.")
	assert_equal(panel.get("armed_label"), "", "An un-armed panel has an empty armed label.")
	assert_equal((panel.get("lines", []) as Array).size(), 0, "An un-armed panel has no lines.")
	assert_equal(panel.get("confirm_enabled"), false, "An un-armed panel disables Confirm.")


func _stale_attack_preview_without_commit_flow_is_not_armed() -> void:
	# An attack-kind preview WITHOUT a live attack_preview commit flow (mode none) is NOT armed — the commit flow is
	# the live-armed signal (Task 1: the armed state is the SESSION's commit flow, never a bare preview).
	var vm: Dictionary = {
		"preview": {"kind": "attack", "target_cell": {"x": 2, "y": 1}, "metadata": {}},
		"commit_flow": {"mode": "none"},
		"action_availability": {}
	}
	assert_equal(TacticalAttackPreviewPanel.from_board_vm(vm).get("is_armed"), false, "An attack preview with no live commit flow is not armed.")


func _empty_vm_is_not_armed_without_crash() -> void:
	assert_equal(TacticalAttackPreviewPanel.from_board_vm({}).get("is_armed"), false, "An empty VM projects not-armed without crashing.")


# ---- purity --------------------------------------------------------------------------------------

func _projection_does_not_mutate_the_input() -> void:
	var vm: Dictionary = _synthetic_armed_vm()
	var before: Dictionary = vm.duplicate(true)
	TacticalAttackPreviewPanel.from_board_vm(vm)
	assert_equal(vm, before, "from_board_vm must not mutate the input VM dict.")


# ---- fixtures / helpers --------------------------------------------------------------------------

func _synthetic_armed_vm() -> Dictionary:
	return {
		"preview": {
			"kind": "attack",
			"target_cell": {"x": 2, "y": 1},
			"target_entity_id": "enemy_1",
			"metadata": {
				"weapon_reach": 3,
				"targeting_shape": "straight_line",
				"blocker_state": "clear",
				"expected_damage": 2,
				"expected_base_damage": 2,
				"warnings": [{"id": "adjacent_ranged_penalty", "text": "Adjacent target reduces bow damage from 4 to 2."}]
			}
		},
		"commit_flow": {"mode": "attack_preview"},
		"action_availability": {
			"confirm": {"enabled": true, "reason": "valid"},
			"cancel": {"enabled": true, "reason": "available"}
		}
	}


func _visible_board(board: BoardState) -> BoardState:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true
	return board


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> Variant:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _assert_exact_keys(actual: Dictionary, expected: Array, message: String) -> void:
	var keys: Array = actual.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	assert_equal(keys, want, message)
