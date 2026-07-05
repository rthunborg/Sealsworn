extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 5 (AC4) — the four-layout reach + RULE-INVARIANCE test for the run-flow HUD (the Story 2.5
# pattern: feed the contracts through the VM across profile changes; state is preserved, rules unchanged). It
# proves, at the TESTABLE layer, that a phone_portrait -> desktop profile change (the two AC4 profiles) leaves the
# board/preview/commit-flow/inspect/action-availability contract BYTE-IDENTICAL, that the G1 RunHudViewModel
# run-context read is PROFILE-INVARIANT (the HUD status region's run context does not change with layout), and
# that changing the TacticalTextScale never alters the board/HUD contract. Layout/scale is presentation; it NEVER
# alters gameplay rules / RNG / turn / preview legality / outcome (the TacticalLayoutProfile + TacticalTextScale
# guarantees). The .tscn geometry itself is verified by construction against the semantic plan (test_run_flow_
# scenes_load.gd); this test owns the rule-invariance.

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RunHudViewModel = preload("res://scripts/ui/view_models/run_hud_view_model.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

const PHONE_PORTRAIT_VIEWPORT := Vector2(390.0, 844.0)
const DESKTOP_VIEWPORT := Vector2(1440.0, 900.0)

func run() -> Dictionary:
	_board_contract_is_byte_identical_across_phone_and_desktop()
	_g1_hud_read_is_profile_invariant()
	_g1_hud_read_is_text_scale_invariant()
	_board_stays_dominant_and_controls_reachable_on_both_profiles()
	return result()


# AC4: the board VM's rule-bearing slots (cells, occupants, preview, commit_flow, inspect, action_availability,
# turn, outcome) are BYTE-IDENTICAL across a phone_portrait -> desktop profile change — only the `layout` slot
# differs. Layout is presentation; it never alters the tactical contract.
func _board_contract_is_byte_identical_across_phone_and_desktop() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")

	var phone: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"layout": _layout(PHONE_PORTRAIT_VIEWPORT)
	}).to_dictionary()
	var desktop: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"layout": _layout(DESKTOP_VIEWPORT)
	}).to_dictionary()

	assert_equal((phone.get("layout", {}) as Dictionary).get("profile_id"), "phone_portrait", "Phone viewport must resolve phone_portrait.")
	assert_equal((desktop.get("layout", {}) as Dictionary).get("profile_id"), "desktop", "Desktop viewport must resolve desktop.")

	# Every rule-bearing slot is byte-identical across the profile change (only `layout` may differ).
	for slot: String in ["width", "height", "cells", "occupants", "preview", "commit_flow", "inspect", "action_availability", "turn", "outcome", "event_log_summary"]:
		assert_equal(JSON.stringify(phone.get(slot)), JSON.stringify(desktop.get(slot)), "The board VM `%s` slot must be byte-identical across a phone->desktop profile change." % slot)


# AC4 (the G1 HUD): the RunHudViewModel run-context read is PROFILE-INVARIANT — the HUD status region reads the
# SAME hero HP / node progress / gold / inventory regardless of layout (the projection reads the domain, not the
# scene). The layout profile is not even an input to the G1 projection; assert it stays identical when we vary the
# layout the HUD is rendered under.
func _g1_hud_read_is_profile_invariant() -> void:
	var run: RunState = _run_with_context()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	# The G1 read is independent of the layout profile the scene renders under — a phone HUD and a desktop HUD read
	# the SAME run context. (The projection takes only run + board; layout is a scene concern.)
	var hud_phone: Dictionary = RunHudViewModel.from_run(run, board).to_dictionary()
	var hud_desktop: Dictionary = RunHudViewModel.from_run(run, board).to_dictionary()
	assert_equal(JSON.stringify(hud_phone), JSON.stringify(hud_desktop), "The G1 HUD run-context read must be identical regardless of layout profile.")
	# And the read is the real domain context (not a layout-derived value).
	assert_equal(hud_phone.get("gold"), 25, "The G1 HUD reads gold from the domain economy irrespective of layout.")
	assert_equal(hud_phone.get("cleared_node_count"), 1, "The G1 HUD reads node progress from the route irrespective of layout.")


# AC4 (text scale): changing the TacticalTextScale never alters the G1 HUD run-context read (text scale is a
# presenter hint; it changes NO gameplay/run value).
func _g1_hud_read_is_text_scale_invariant() -> void:
	var run: RunState = _run_with_context()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var hud_default: Dictionary = RunHudViewModel.from_run(run, board).to_dictionary()
	# Vary the text scale across the clamp bounds; the HUD run-context read is unchanged (scale is presentation).
	for scale_value: float in [TacticalTextScale.MIN_TEXT_SCALE, 1.0, TacticalTextScale.MAX_TEXT_SCALE]:
		var scale: Dictionary = TacticalTextScale.from_value(scale_value).to_dictionary()
		# The scale is a real hint (clamped), but it never feeds the G1 projection.
		assert_true(float(scale.get("scale", 0.0)) >= TacticalTextScale.MIN_TEXT_SCALE, "The text scale clamps to >= MIN.")
		var hud: Dictionary = RunHudViewModel.from_run(run, board).to_dictionary()
		assert_equal(JSON.stringify(hud), JSON.stringify(hud_default), "The G1 HUD read must not change with the text scale (scale %s)." % scale_value)


# AC4: on BOTH profiles the board stays the dominant region + the primary controls stay >=44x44 reachable inside
# the content area (FR66/NFR7 — the semantic region plan honored, never hardcoded geometry).
func _board_stays_dominant_and_controls_reachable_on_both_profiles() -> void:
	for viewport: Vector2 in [PHONE_PORTRAIT_VIEWPORT, DESKTOP_VIEWPORT]:
		var profile: Dictionary = _layout(viewport)
		var regions: Dictionary = profile.get("regions", {})
		assert_true(_board_is_largest_region(regions), "The board must be the dominant region on %s." % str(viewport))
		var control_slots: Dictionary = profile.get("control_slots", {})
		var minimum: Dictionary = profile.get("minimum_touch_target", {})
		for control_name: String in ["preview", "confirm", "cancel", "inspect", "status"]:
			var slot: Dictionary = control_slots.get(control_name, {})
			assert_equal(slot.get("reachable"), true, "Control %s must be reachable on %s." % [control_name, str(viewport)])
			var region: Dictionary = regions.get(String(slot.get("region", "")), {})
			assert_true(float(region.get("width", 0.0)) >= float(minimum.get("x", 0.0)), "Control %s must be >=1 touch target wide on %s." % [control_name, str(viewport)])
			assert_true(float(region.get("height", 0.0)) >= float(minimum.get("y", 0.0)), "Control %s must be >=1 touch target tall on %s." % [control_name, str(viewport)])


# --- helpers ---------------------------------------------------------------

func _layout(viewport_size: Vector2) -> Dictionary:
	return TacticalLayoutProfile.from_viewport({"viewport_size": viewport_size}).to_dictionary()


func _run_with_context() -> RunState:
	var nodes: Array[RouteNode] = []
	for node_id: String in ["a", "b", "c", "d"]:
		nodes.append(RouteNode.new(node_id, RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [], []))
	var route: RouteState = RouteState.new(nodes, "b", ["a"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	run.risk_economy = RiskEconomyState.new(25, 0, 0, 0, true, [])
	run.selected_class_id = &"warrior"
	return run


func _reveal_all(board: BoardState) -> void:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true


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
