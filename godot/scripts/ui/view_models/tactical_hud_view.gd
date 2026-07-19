class_name TacticalHudView
extends RefCounted

# Story 14.10 (AC1/AC3 — the F9 fix) — the PURE, SCENE-FREE PLAYER-HUD render-decision seam. Given the live run,
# the (optional) live board, and the board VM's `turn` slot, it composes the render-ready HUD facts the presenter
# draws into the `status` region as styled discrete elements: HP / gold / backpack / node-progress + a HUMAN turn
# label (never the snake_case `player_planning` phase id) + the class display name.
#
# ⭐ IT REUSES THE SHIPPED PROJECTIONS — it re-derives NOTHING:
#   - HP / gold / bag / nodes / class-id come from RunHudViewModel.from_run(run, board) (the 11.3 pinned 11-key
#     projection — the SINGLE source of the in-run run-context; there is NO run-level HP field on RunState, which
#     is exactly why that projection exists — do NOT read RunState HP directly).
#   - the human turn label maps the board VM `turn.phase` (TacticalTurnState.id_for_phase, snake_case) to a
#     player-facing string via the ONE centralized phase->display-name map (the 14.6 single-helper heuristic).
#   - the class display name resolves through ClassStartSummaryViewModel.summarize(run).display_name (the
#     class-repository display-name path) — NEVER the raw selected_class_id.
#
# ⭐ IT IS A PURE READ. It mints NO event, consumes NO RNG, mutates NOTHING (not the run, not the board), adds NO
# board-VM key (the 16-key TacticalBoardViewModel gate holds — the HUD is a SEPARATE read surface, exactly like
# RunHudViewModel / LiveAffinityReadModel compose alongside the board VM), and leaks NO live handle (a FRESH
# plain-data dictionary each call). It is a RefCounted DTO — NOT a Control/Node/scene.
#
# ⭐ FAIL-CLOSED (the RunHudViewModel / RunEndOutcome discipline): a null run projects the EMPTY HUD fact
# (has_hud == false, zeroed fields, a neutral turn label). The pinned key set is IDENTICAL for the present and
# absent projections (a key never silently appears/vanishes).
#
# NFR9 (accessibility): every projected field is a TEXT channel (HP `N/M`, gold, bag `N/M`, node `N/M`, the human
# turn word) — legible with color removed. The turn label is a WORD ("Your Turn" / "Enemy Turn"), never a raw id.

const RunHudViewModel = preload("res://scripts/ui/view_models/run_hud_view_model.gd")
const ClassStartSummaryViewModel = preload("res://scripts/ui/view_models/class_start_summary_view_model.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")

# The EXACT top-level key set (pinned by test — the RunHudViewModel.DICTIONARY_KEYS exact-key discipline). A key
# never silently appears/vanishes; the present and absent projections carry the SAME set. has_hud gates whether the
# run-context fields are meaningful; has_hp gates whether the HP fields are meaningful.
const VIEW_KEYS: Array[String] = [
	"has_hud",
	"hp_current",
	"hp_max",
	"has_hp",
	"gold",
	"bag_count",
	"bag_capacity",
	"nodes_cleared",
	"nodes_total",
	"turn_label",
	"turn_is_player",
	"class_display_name"
]

# The centralized turn-phase -> human display-name map (the 14.6 single-helper heuristic — ONE mapping closes all
# sites). NEVER render a snake_case phase id to the player. player_resolving/enemy_* read as "Enemy Turn" (the
# player's planning window is over once an action is resolving); environment_resolving reads as the hazard beat; an
# unknown / absent phase reads as a neutral dash.
const TURN_LABEL_PLAYER := "Your Turn"
const TURN_LABEL_ENEMY := "Enemy Turn"
const TURN_LABEL_HAZARDS := "Hazards Resolving"
const TURN_LABEL_NONE := "—"


# Project the player-HUD facts from the live run (+ the OPTIONAL live board for the on-screen fight) and the board
# VM `turn` slot (a plain {turn_number, phase, active_actor_id} dict). A null run projects the fail-closed empty
# fact; an empty / absent turn slot projects the neutral turn label. A FRESH dictionary each call.
static func project(run: RunState, board: BoardState = null, turn: Dictionary = {}) -> Dictionary:
	var hud: Dictionary = RunHudViewModel.from_run(run, board).to_dictionary()
	var has_run: bool = bool(hud.get("has_run", false))
	var phase_id: String = String(turn.get("phase", ""))
	return {
		"has_hud": has_run,
		"hp_current": int(hud.get("hero_current_hp", 0)),
		"hp_max": int(hud.get("hero_max_hp", 0)),
		"has_hp": bool(hud.get("has_hero_hp", false)),
		"gold": int(hud.get("gold", 0)),
		"bag_count": int(hud.get("inventory_count", 0)),
		"bag_capacity": int(hud.get("inventory_capacity", 0)),
		"nodes_cleared": int(hud.get("cleared_node_count", 0)),
		"nodes_total": int(hud.get("total_node_count", 0)),
		"turn_label": turn_label_for(phase_id),
		"turn_is_player": phase_id == String(TacticalTurnState.PHASE_PLAYER_PLANNING),
		"class_display_name": _class_display_name(run)
	}


# Map a snake_case turn-phase id to its human display name (the ONE mapping — mirror it, do not scatter presenter
# literals). An empty / unrecognized id reads as the neutral fallback. NEVER returns a snake_case id.
static func turn_label_for(phase_id: String) -> String:
	if phase_id == String(TacticalTurnState.PHASE_PLAYER_PLANNING):
		return TURN_LABEL_PLAYER
	if (
		phase_id == String(TacticalTurnState.PHASE_PLAYER_RESOLVING)
		or phase_id == String(TacticalTurnState.PHASE_ENEMY_PLANNING)
		or phase_id == String(TacticalTurnState.PHASE_ENEMY_RESOLVING)
	):
		return TURN_LABEL_ENEMY
	if phase_id == String(TacticalTurnState.PHASE_ENVIRONMENT_RESOLVING):
		return TURN_LABEL_HAZARDS
	return TURN_LABEL_NONE


# Resolve the class display name through the class-repository display-name path (ClassStartSummaryViewModel — a
# PURE read; the passive-repository arg is unused by summarize). A null run / an identity-absent run (no kit / an
# unresolved class) yields an empty string (the HUD omits the class line). NEVER returns the raw selected_class_id.
static func _class_display_name(run: RunState) -> String:
	if run == null:
		return ""
	var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
	if not bool(summary.get("has_class_identity", false)):
		return ""
	return String(summary.get("display_name", ""))
