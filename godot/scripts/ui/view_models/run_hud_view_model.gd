class_name RunHudViewModel
extends RefCounted

# Story 11.3 (AC2, Contract gap G1 — the 11.1 appendix §1.3 / §16 G1, owned by 11.3) — the scene-free IN-RUN HUD
# RUN-CONTEXT projection. It is the thin fail-closed RefCounted READ surface the in-run HUD `status` region
# composes ALONGSIDE the TacticalBoardViewModel's `turn` slot (the region -> slot map, appendix §1.2). It
# AGGREGATES the run-level context the tactical board VM does NOT carry, from the EXISTING domain sources the
# appendix §16 G1 row names:
#   - HERO HP: during a level the hero TacticalEntityState HP on the live board (the source of truth while a
#     fight is on screen); BETWEEN levels the class StartingKit.baseline_hp baseline. There is NO run-level HP
#     field on RunState — which is precisely WHY this projection exists (the 11.1 Round-1 review's hero-HP
#     mis-source-on-RunState is the exact trap; HP lives on the board entity / StartingKit, not RunState).
#   - NODE PROGRESS: RouteState.cleared_node_ids count vs the total RouteState.nodes() count (a descent-progress
#     read for the HUD; NOT a difficulty knob — nothing scales anything by it).
#   - GOLD: RiskEconomyState.gold (the run wallet).
#   - INVENTORY / CONSUMED-PASSIVE ACCESS: the run InventoryState backpack occupancy + capacity (the
#     inventory/passives access surface the HUD exposes; the modal/consume flows are the EXISTING Epic-6
#     contracts — this projection only surfaces the access counts).
#
# ⭐ IT IS A PURE READ. It mints NO event, consumes NO RNG (ZERO randi/randf/RandomNumberGenerator), mutates
# NOTHING (not the run, not the board, not the economy/inventory), and leaks NO live handle into the domain (a
# FRESH plain-data dictionary each call — a mutation of a returned field never perturbs the source). It is a
# RefCounted DTO — NOT a Control/Node/scene. It mirrors the RunEndOutcome / HeroSelectViewModel / OutpostViewModel
# exact-key + fail-closed + no-live-handle projection discipline VERBATIM.
#
# ⭐ FAIL-CLOSED (the RunEndOutcome._empty / HeroSelectViewModel discipline): a null run projects the EMPTY fact
# (has_run == false + zeroed fields) so the HUD renders an empty status region rather than crashing; a run with
# no HP source (no board AND no starting kit) projects has_hero_hp == false + 0 HP. The pinned key set is
# IDENTICAL for the present and absent projections (a key never silently appears/vanishes).

const RunState = preload("res://scripts/run/run_state.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# The default live-run hero entity id (the id LiveCombatResolver / auto_play_boss_fight place the hero under, and
# the id the tactical resolvers key off). Used as the direct-lookup fallback when finding the hero on the board.
const HERO_ENTITY_ID := &"hero"

# The EXACT top-level key set (pinned by test — the RunEndOutcome.DICTIONARY_KEYS exact-key discipline). A key
# never silently appears or vanishes; the present and absent projections carry the SAME set. has_run gates
# whether the run-context fields are meaningful; has_hero_hp gates whether the HP fields are meaningful.
const DICTIONARY_KEYS: Array[String] = [
	"has_run",
	"has_hero_hp",
	"hero_current_hp",
	"hero_max_hp",
	"gold",
	"cleared_node_count",
	"total_node_count",
	"node_progress_ratio",
	"inventory_count",
	"inventory_capacity",
	"selected_class_id"
]

var has_run: bool = false
var has_hero_hp: bool = false
var hero_current_hp: int = 0
var hero_max_hp: int = 0
var gold: int = 0
var cleared_node_count: int = 0
var total_node_count: int = 0
var node_progress_ratio: float = 0.0
var inventory_count: int = 0
var inventory_capacity: int = 0
var selected_class_id: String = ""

# Build the run-HUD projection from the live run (+ the OPTIONAL live board for the on-screen fight). During a
# level the caller passes the live BoardState so the hero HP reads the board entity; BETWEEN levels it passes
# null and the baseline reads StartingKit.baseline_hp. A null run projects the fail-closed empty fact.
static func from_run(run: RunState, board: BoardState = null) -> RunHudViewModel:
	var view_model: RunHudViewModel = load("res://scripts/ui/view_models/run_hud_view_model.gd").new()
	if run == null:
		return view_model

	view_model.has_run = true
	view_model.selected_class_id = String(run.selected_class_id)

	# Gold from the risk-economy wallet (defaults 0 if the economy is somehow absent — fail-closed).
	if run.risk_economy != null:
		view_model.gold = maxi(0, run.risk_economy.gold)

	# Node progress from the route: cleared vs total. A null/empty route projects 0/0 with a 0.0 ratio (no
	# divide-by-zero).
	if run.route != null:
		view_model.total_node_count = run.route.node_count()
		view_model.cleared_node_count = run.route.cleared_node_ids.size()
		if view_model.total_node_count > 0:
			view_model.node_progress_ratio = float(view_model.cleared_node_count) / float(view_model.total_node_count)

	# Inventory occupancy (the inventory/consumed-passive access surface). The run inventory defaults non-null,
	# but guard defensively.
	if run.inventory != null:
		view_model.inventory_count = run.inventory.size()
		view_model.inventory_capacity = run.inventory.capacity

	# Hero HP: the live board entity during a level, else the StartingKit.baseline_hp baseline between levels.
	var hero: TacticalEntityState = _find_hero(board)
	if hero != null:
		view_model.has_hero_hp = true
		view_model.hero_current_hp = hero.current_hp
		view_model.hero_max_hp = hero.max_hp
	elif run.starting_kit != null and run.starting_kit.baseline_hp > 0:
		view_model.has_hero_hp = true
		view_model.hero_current_hp = run.starting_kit.baseline_hp
		view_model.hero_max_hp = run.starting_kit.baseline_hp

	return view_model


# Find the hero entity on the board: prefer the direct id lookup (the live-loop placement id), else the FIRST
# PLAYER-type entity (robust to a differently-id'd hero). Returns null when there is no board or no player entity.
static func _find_hero(board: BoardState) -> TacticalEntityState:
	if board == null:
		return null
	var direct: TacticalEntityState = board.get_entity(HERO_ENTITY_ID)
	if direct != null:
		return direct
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type == TacticalEntityState.EntityType.PLAYER:
			return entity
	return null


# Exact-key projection (the RunEndOutcome.to_dictionary discipline): plain int/float/bool/String data only (no
# live RunState / BoardState / entity handle leaks out). A FRESH dictionary each call so a mutation of the
# returned dict never perturbs this DTO or the run it read.
func to_dictionary() -> Dictionary:
	return {
		"has_run": has_run,
		"has_hero_hp": has_hero_hp,
		"hero_current_hp": hero_current_hp,
		"hero_max_hp": hero_max_hp,
		"gold": gold,
		"cleared_node_count": cleared_node_count,
		"total_node_count": total_node_count,
		"node_progress_ratio": node_progress_ratio,
		"inventory_count": inventory_count,
		"inventory_capacity": inventory_capacity,
		"selected_class_id": selected_class_id
	}
