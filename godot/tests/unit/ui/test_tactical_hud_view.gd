extends "res://tests/unit/test_case.gd"

# Story 14.10 Task 1/Task 5 — TacticalHudView (AC1/AC3): the styled PLAYER-HUD render-decision seam.
#
# TacticalHudView is the thin fail-closed RefCounted READ surface the tactical board presenter draws into the
# `status` region as discrete styled elements (HP / gold / bag / node-progress + a HUMAN turn indicator + the class
# display name). It composes the shipped RunHudViewModel (HP/gold/bag/nodes/class) with the board VM `turn` slot,
# resolves the turn-phase snake_case id to a human label (the ONE centralized map — no snake_case ever reaches the
# player), and resolves the class display name through the class-repository path. It pins an EXACT key set, projects
# a has_hud gate for the absent state, mints NO event, draws NO RNG, mutates NOTHING, adds NO board-VM key, and
# leaks no live handle. This test pins those contracts.

const TacticalHudView = preload("res://scripts/ui/view_models/tactical_hud_view.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# The pinned top-level key set (sorted). A key never silently appears/vanishes (the exact-key discipline).
const EXPECTED_KEYS: Array[String] = [
	"bag_capacity",
	"bag_count",
	"class_display_name",
	"gold",
	"has_hp",
	"has_hud",
	"hp_current",
	"hp_max",
	"nodes_cleared",
	"nodes_total",
	"turn_is_player",
	"turn_label"
]

func run() -> Dictionary:
	_null_run_projects_fail_closed_empty()
	_projects_run_context_from_run_and_board()
	_turn_label_maps_every_phase_to_a_human_string()
	_turn_label_for_helper_never_leaks_snake_case()
	_exact_key_set_pinned()
	_class_display_name_resolves_to_a_display_name_not_the_raw_id()
	_projection_is_a_pure_copy_no_live_handle_leak()
	return result()


# AC1/AC3 fail-closed: a null run projects the empty HUD fact (has_hud == false, zeroed fields, a NEUTRAL turn label
# — never a crash, never a snake_case id).
func _null_run_projects_fail_closed_empty() -> void:
	var data: Dictionary = TacticalHudView.project(null, null, {})
	assert_equal(data.get("has_hud"), false, "A null run must project has_hud == false (fail-closed).")
	assert_equal(data.get("has_hp"), false, "A null run must project has_hp == false.")
	assert_equal(data.get("hp_current"), 0, "A null run must project 0 current HP.")
	assert_equal(data.get("hp_max"), 0, "A null run must project 0 max HP.")
	assert_equal(data.get("gold"), 0, "A null run must project 0 gold.")
	assert_equal(data.get("bag_count"), 0, "A null run must project 0 bag count.")
	assert_equal(data.get("nodes_total"), 0, "A null run must project 0 total nodes.")
	assert_equal(data.get("turn_is_player"), false, "A null run must project turn_is_player == false.")
	assert_equal(data.get("turn_label"), TacticalHudView.TURN_LABEL_NONE, "A null run projects the neutral turn label.")
	assert_equal(data.get("class_display_name"), "", "A null run projects an empty class display name.")


# AC1: the run-context fields read the shipped RunHudViewModel (HP from the live board hero; gold/nodes/bag from the
# run) and the turn slot maps to the human label.
func _projects_run_context_from_run_and_board() -> void:
	var run: RunState = _run_with_route(["a", "b", "c", "d"], ["a", "b"], &"warrior")
	run.risk_economy = RiskEconomyState.new(29, 0, 0, 0, true, [])
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var hero: TacticalEntityState = board.get_entity(&"hero")
	assert_true(hero != null, "Fixture board must carry a hero entity for the HP-source test.")
	var turn: Dictionary = _turn_dict(TacticalTurnState.Phase.PLAYER_PLANNING)
	var data: Dictionary = TacticalHudView.project(run, board, turn)
	assert_equal(data.get("has_hud"), true, "A real run projects has_hud == true.")
	assert_equal(data.get("has_hp"), true, "A board with a hero projects has_hp == true.")
	assert_equal(data.get("hp_current"), hero.current_hp, "HP current must read the board entity HP.")
	assert_equal(data.get("hp_max"), hero.max_hp, "HP max must read the board entity max HP.")
	assert_equal(data.get("gold"), 29, "Gold must read RiskEconomyState.gold.")
	assert_equal(data.get("nodes_total"), 4, "Total nodes must read the route node count.")
	assert_equal(data.get("nodes_cleared"), 2, "Cleared nodes must read the cleared_node_ids count.")
	assert_equal(data.get("turn_label"), TacticalHudView.TURN_LABEL_PLAYER, "player_planning maps to the player turn label.")
	assert_equal(data.get("turn_is_player"), true, "player_planning projects turn_is_player == true.")


# AC1/NFR9: EVERY turn phase maps to a HUMAN label (never the snake_case id), and only player_planning is the
# player's turn.
func _turn_label_maps_every_phase_to_a_human_string() -> void:
	var run: RunState = _run_with_route(["a"], [], &"warrior")
	var expected_labels: Dictionary = {
		TacticalTurnState.Phase.PLAYER_PLANNING: TacticalHudView.TURN_LABEL_PLAYER,
		TacticalTurnState.Phase.PLAYER_RESOLVING: TacticalHudView.TURN_LABEL_ENEMY,
		TacticalTurnState.Phase.ENEMY_PLANNING: TacticalHudView.TURN_LABEL_ENEMY,
		TacticalTurnState.Phase.ENEMY_RESOLVING: TacticalHudView.TURN_LABEL_ENEMY,
		TacticalTurnState.Phase.ENVIRONMENT_RESOLVING: TacticalHudView.TURN_LABEL_HAZARDS
	}
	for phase_value: int in expected_labels.keys():
		var phase_id: String = String(TacticalTurnState.id_for_phase(phase_value))
		var data: Dictionary = TacticalHudView.project(run, null, _turn_dict(phase_value))
		var label: String = String(data.get("turn_label", ""))
		assert_equal(label, String(expected_labels[phase_value]), "Phase %s must map to its human turn label." % phase_id)
		# The projected label must NEVER be the raw snake_case phase id (the F9 leak guard).
		assert_true(label != phase_id, "Turn label for %s must not leak the snake_case id." % phase_id)
		var is_player: bool = phase_value == TacticalTurnState.Phase.PLAYER_PLANNING
		assert_equal(data.get("turn_is_player"), is_player, "Only player_planning is the player's turn (%s)." % phase_id)
	# An empty / unknown turn slot reads as the neutral label (never a crash, never a snake_case leak).
	var empty_turn_data: Dictionary = TacticalHudView.project(run, null, {})
	assert_equal(empty_turn_data.get("turn_label"), TacticalHudView.TURN_LABEL_NONE, "An empty turn slot maps to the neutral label.")


# AC1: the static turn-label helper covers all phases + the unknown fallback, and NEVER returns a snake_case id.
func _turn_label_for_helper_never_leaks_snake_case() -> void:
	for phase_value: int in [
		TacticalTurnState.Phase.PLAYER_PLANNING,
		TacticalTurnState.Phase.PLAYER_RESOLVING,
		TacticalTurnState.Phase.ENEMY_PLANNING,
		TacticalTurnState.Phase.ENEMY_RESOLVING,
		TacticalTurnState.Phase.ENVIRONMENT_RESOLVING
	]:
		var phase_id: String = String(TacticalTurnState.id_for_phase(phase_value))
		var label: String = TacticalHudView.turn_label_for(phase_id)
		assert_true(not label.is_empty(), "The turn label for %s must be non-empty." % phase_id)
		assert_true(label != phase_id, "turn_label_for(%s) must not return the snake_case id." % phase_id)
	# An unknown id falls back to the neutral label.
	assert_equal(TacticalHudView.turn_label_for("something_unknown"), TacticalHudView.TURN_LABEL_NONE, "An unknown phase id maps to the neutral label.")
	assert_equal(TacticalHudView.turn_label_for(""), TacticalHudView.TURN_LABEL_NONE, "An empty phase id maps to the neutral label.")


# AC3: the projection exposes EXACTLY the pinned key set — the present AND absent projections carry the SAME set.
func _exact_key_set_pinned() -> void:
	var run: RunState = _run_with_route(["a"], [], &"warrior")
	var keys: Array = TacticalHudView.project(run, null, _turn_dict(TacticalTurnState.Phase.PLAYER_PLANNING)).keys()
	keys.sort()
	assert_equal(keys, EXPECTED_KEYS, "The HUD projection must expose EXACTLY the pinned key set.")
	var empty_keys: Array = TacticalHudView.project(null, null, {}).keys()
	empty_keys.sort()
	assert_equal(empty_keys, EXPECTED_KEYS, "The empty projection must expose the SAME pinned key set (no key vanishes).")


# AC1/AC3: the class name resolves to a DISPLAY name through the class-repository path — never the raw snake_case id.
func _class_display_name_resolves_to_a_display_name_not_the_raw_id() -> void:
	var run: RunState = _run_with_route(["a"], [], &"warrior")
	run.starting_kit = StartingKit.new(&"warrior", &"sword", &"none", 42, &"", &"")
	var data: Dictionary = TacticalHudView.project(run, null, _turn_dict(TacticalTurnState.Phase.PLAYER_PLANNING))
	var class_display: String = String(data.get("class_display_name", ""))
	assert_true(not class_display.is_empty(), "A class-identity run must project a non-empty class display name.")
	assert_true(class_display != "warrior", "The class display name must be a DISPLAY name, not the raw snake_case id.")


# AC3 no-live-handle: mutating a returned field never perturbs a fresh projection (a fresh dict each call).
func _projection_is_a_pure_copy_no_live_handle_leak() -> void:
	var run: RunState = _run_with_route(["a", "b"], ["a"], &"warrior")
	run.risk_economy = RiskEconomyState.new(11, 0, 0, 0, true, [])
	var first: Dictionary = TacticalHudView.project(run, null, _turn_dict(TacticalTurnState.Phase.PLAYER_PLANNING))
	first["gold"] = 999
	first["turn_label"] = "MUTATED"
	var second: Dictionary = TacticalHudView.project(run, null, _turn_dict(TacticalTurnState.Phase.PLAYER_PLANNING))
	assert_equal(second.get("gold"), 11, "Mutating a returned HUD field must not perturb a fresh projection.")
	assert_equal(second.get("turn_label"), TacticalHudView.TURN_LABEL_PLAYER, "Mutating a returned label must not perturb a fresh projection.")
	assert_equal(run.risk_economy.gold, 11, "The HUD projection must not mutate the source economy.")


# --- helpers ---------------------------------------------------------------

func _turn_dict(phase_value: int) -> Dictionary:
	return {
		"turn_number": 1,
		"phase": String(TacticalTurnState.id_for_phase(phase_value)),
		"active_actor_id": "hero"
	}


func _run_with_route(node_ids: Array, cleared_ids: Array, class_id: StringName) -> RunState:
	var nodes: Array[RouteNode] = []
	for node_id: Variant in node_ids:
		nodes.append(RouteNode.new(String(node_id), RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [], []))
	var route: RouteState = RouteState.new(nodes, "", cleared_ids)
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	run.selected_class_id = class_id
	return run
