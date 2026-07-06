extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 2 — RunHudViewModel (AC2, Contract gap G1): the in-run HUD run-context projection.
#
# RunHudViewModel is the thin fail-closed RefCounted READ surface the in-run HUD `status` region composes
# alongside the tactical board VM's `turn` slot. It AGGREGATES the run-level context the TacticalBoardViewModel
# does NOT carry, from the EXISTING domain sources the 11.1 appendix §16 G1 row names:
#   - hero HP: the hero TacticalEntityState HP on the board during a level; the class StartingKit.baseline_hp
#     baseline (there is NO run-level HP field on RunState — which is WHY this projection exists);
#   - node progress: RouteState.cleared_node_ids count vs the total RouteState.nodes() count;
#   - gold: RiskEconomyState.gold;
#   - inventory / consumed-passive access: the run InventoryState backpack occupancy.
#
# It pins an EXACT key set, projects a has_*-style gate for the absent/empty state, mints NO event, consumes NO
# RNG, mutates NOTHING, and leaks no live handle into the domain (a returned-field mutation never perturbs the
# source). This test pins those contracts.

const RunHudViewModel = preload("res://scripts/ui/view_models/run_hud_view_model.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# The pinned top-level key set (sorted). A key never silently appears/vanishes (the exact-key discipline).
const EXPECTED_KEYS: Array[String] = [
	"cleared_node_count",
	"gold",
	"has_hero_hp",
	"has_run",
	"hero_current_hp",
	"hero_max_hp",
	"inventory_capacity",
	"inventory_count",
	"node_progress_ratio",
	"selected_class_id",
	"total_node_count"
]

func run() -> Dictionary:
	_from_null_run_projects_fail_closed_empty()
	_projects_gold_node_progress_and_class_from_run()
	_reads_hero_hp_from_the_board_entity_during_a_level()
	_falls_back_to_starting_kit_baseline_hp_without_a_board()
	_exact_key_set_pinned()
	_absent_hero_hp_when_no_board_and_no_kit()
	_inventory_occupancy_is_projected()
	_projection_is_a_pure_copy_no_live_handle_leak()
	_node_progress_ratio_is_fraction_cleared()
	return result()


# G1 fail-closed: a null run projects the empty fact (has_run == false) — never a crash, never a half-fact.
func _from_null_run_projects_fail_closed_empty() -> void:
	var view_model: RunHudViewModel = RunHudViewModel.from_run(null)
	var data: Dictionary = view_model.to_dictionary()
	assert_equal(data.get("has_run"), false, "A null run must project has_run == false (fail-closed).")
	assert_equal(data.get("has_hero_hp"), false, "A null run must project has_hero_hp == false.")
	assert_equal(data.get("gold"), 0, "A null run must project 0 gold.")
	assert_equal(data.get("total_node_count"), 0, "A null run must project 0 total nodes.")
	assert_equal(data.get("cleared_node_count"), 0, "A null run must project 0 cleared nodes.")
	assert_equal(data.get("selected_class_id"), "", "A null run must project an empty class id.")


# G1: gold from RiskEconomyState.gold; node progress from cleared_node_ids vs nodes(); class from selected_class_id.
func _projects_gold_node_progress_and_class_from_run() -> void:
	var run: RunState = _run_with_route(["a", "b", "c", "d"], ["a", "b"], &"warrior")
	run.risk_economy = RiskEconomyState.new(37, 0, 0, 0, true, [])
	var data: Dictionary = RunHudViewModel.from_run(run).to_dictionary()
	assert_equal(data.get("has_run"), true, "A real run must project has_run == true.")
	assert_equal(data.get("gold"), 37, "Gold must read RiskEconomyState.gold.")
	assert_equal(data.get("total_node_count"), 4, "Total node count must read RouteState.nodes().size().")
	assert_equal(data.get("cleared_node_count"), 2, "Cleared node count must read RouteState.cleared_node_ids.size().")
	assert_equal(data.get("selected_class_id"), "warrior", "Selected class id must be projected verbatim.")


# G1: during a level the hero HP reads the hero TacticalEntityState on the board (the live source of truth).
func _reads_hero_hp_from_the_board_entity_during_a_level() -> void:
	var run: RunState = _run_with_route(["a", "b"], [], &"warrior")
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	# The micro-combat board's hero is entity id &"hero"; damage it so max != current.
	var hero: TacticalEntityState = board.get_entity(&"hero")
	assert_true(hero != null, "Fixture board must carry a hero entity for the HP-source test.")
	var data: Dictionary = RunHudViewModel.from_run(run, board).to_dictionary()
	assert_equal(data.get("has_hero_hp"), true, "A board with a hero must project has_hero_hp == true.")
	assert_equal(data.get("hero_current_hp"), hero.current_hp, "Hero current HP must read the board entity HP.")
	assert_equal(data.get("hero_max_hp"), hero.max_hp, "Hero max HP must read the board entity max HP.")


# G1: without a board (between levels), the hero HP baseline reads StartingKit.baseline_hp.
func _falls_back_to_starting_kit_baseline_hp_without_a_board() -> void:
	var run: RunState = _run_with_route(["a"], [], &"warrior")
	run.starting_kit = StartingKit.new(&"warrior", &"sword", &"none", 42, &"", &"")
	var data: Dictionary = RunHudViewModel.from_run(run, null).to_dictionary()
	assert_equal(data.get("has_hero_hp"), true, "A run with a starting kit must project a baseline hero HP.")
	assert_equal(data.get("hero_current_hp"), 42, "Between levels, hero current HP falls back to StartingKit.baseline_hp.")
	assert_equal(data.get("hero_max_hp"), 42, "Between levels, hero max HP falls back to StartingKit.baseline_hp.")


func _exact_key_set_pinned() -> void:
	var run: RunState = _run_with_route(["a"], [], &"warrior")
	var keys: Array = RunHudViewModel.from_run(run).to_dictionary().keys()
	keys.sort()
	assert_equal(keys, EXPECTED_KEYS, "The HUD projection must expose EXACTLY the pinned key set (no extra/missing key).")
	# The null projection must expose the SAME key set (fail-closed, no key vanishes).
	var empty_keys: Array = RunHudViewModel.from_run(null).to_dictionary().keys()
	empty_keys.sort()
	assert_equal(empty_keys, EXPECTED_KEYS, "The empty projection must expose the SAME pinned key set.")


# G1 fail-closed: no board AND no kit (a fresh run with no HP source) -> has_hero_hp == false, HP 0.
func _absent_hero_hp_when_no_board_and_no_kit() -> void:
	var run: RunState = _run_with_route(["a"], [], &"")
	run.starting_kit = null
	var data: Dictionary = RunHudViewModel.from_run(run, null).to_dictionary()
	assert_equal(data.get("has_hero_hp"), false, "No board and no kit must fail-close has_hero_hp to false.")
	assert_equal(data.get("hero_current_hp"), 0, "No HP source projects 0 current HP.")
	assert_equal(data.get("hero_max_hp"), 0, "No HP source projects 0 max HP.")


# G1: inventory occupancy is projected (the inventory / consumed-passive access surface).
func _inventory_occupancy_is_projected() -> void:
	var run: RunState = _run_with_route(["a"], [], &"warrior")
	run.inventory = InventoryState.new(6, [], {})
	run.inventory.append_slot(&"minor_salve", &"consumable")
	run.inventory.append_slot(&"iron_ring", &"jewelry")
	var data: Dictionary = RunHudViewModel.from_run(run).to_dictionary()
	assert_equal(data.get("inventory_count"), 2, "Inventory count must read the backpack occupancy.")
	assert_equal(data.get("inventory_capacity"), 6, "Inventory capacity must read the backpack capacity.")


# G1 no-live-handle: mutating a returned field never perturbs the source (a fresh dict each call).
func _projection_is_a_pure_copy_no_live_handle_leak() -> void:
	var run: RunState = _run_with_route(["a", "b"], ["a"], &"warrior")
	run.risk_economy = RiskEconomyState.new(10, 0, 0, 0, true, [])
	var view_model: RunHudViewModel = RunHudViewModel.from_run(run)
	var first: Dictionary = view_model.to_dictionary()
	first["gold"] = 999
	first["cleared_node_count"] = 999
	var second: Dictionary = view_model.to_dictionary()
	assert_equal(second.get("gold"), 10, "Mutating a returned HUD field must not perturb a fresh projection.")
	assert_equal(second.get("cleared_node_count"), 1, "Mutating a returned HUD field must not perturb the cleared count.")
	# The source run economy is untouched.
	assert_equal(run.risk_economy.gold, 10, "The HUD projection must not mutate the source economy.")


# G1: the node-progress ratio is cleared/total (a convenience for the HUD progress bar), 0 when no nodes.
func _node_progress_ratio_is_fraction_cleared() -> void:
	var run: RunState = _run_with_route(["a", "b", "c", "d"], ["a", "b", "c"], &"warrior")
	var data: Dictionary = RunHudViewModel.from_run(run).to_dictionary()
	assert_true(is_equal_approx(float(data.get("node_progress_ratio", 0.0)), 0.75), "node_progress_ratio must be cleared/total (3/4).")
	# No nodes -> 0.0 ratio (no divide-by-zero).
	var empty_run: RunState = _run_with_route([], [], &"warrior")
	var empty_data: Dictionary = RunHudViewModel.from_run(empty_run).to_dictionary()
	assert_true(is_equal_approx(float(empty_data.get("node_progress_ratio", -1.0)), 0.0), "An empty route projects a 0.0 progress ratio (no divide-by-zero).")


# --- helpers ---------------------------------------------------------------

func _run_with_route(node_ids: Array, cleared_ids: Array, class_id: StringName) -> RunState:
	var nodes: Array[RouteNode] = []
	for node_id: Variant in node_ids:
		nodes.append(RouteNode.new(String(node_id), RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [], []))
	var route: RouteState = RouteState.new(nodes, "", cleared_ids)
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	run.selected_class_id = class_id
	return run
