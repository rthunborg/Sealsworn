class_name PauseMenuViewModel
extends RefCounted

# Story 15.4 (Review D1) — the scene-free PAUSE-MENU DECISION + RUN-METRICS projection. It is the SINGLE testable
# authority behind the ONE shared pause surface both the live board (gameplay_shell_presenter) and the route map
# (route_map_presenter) show — so the "what entries are available + which run metrics to surface" decision lives in
# one unit-tested place, not forked per presenter. It owns NO run truth and drives NO navigation: it PROJECTS a
# decision + a metrics read the presenter renders; the Save & Exit action rides the EXISTING QuitRunBridge /
# SaveManager seams, and Options rides the EXISTING SettingsManager seams.
#
# ⭐ PURE READ: from_run(run) reads only already-available run seams (selected class, route progress/depth,
# cleared-node count, gold/corruption from the run economy). It adds NO domain state and NO snapshot key — every
# metric is a metric that already exists behind a current read. It draws no RNG, mutates nothing, mints no event.
#
# ⭐ SAVE & EXIT IS PHASE-GATED: offer_save_and_exit is true only for a seated NON-terminal run (a resumable route
# position). A null / terminal run offers no Save & Exit (a completed/failed run routes to run-end/outpost, not a
# resumable quit — mirroring QuitRunBridge.compose_quit_save returning null there). Resume + Options are always
# offered (you can always dismiss the menu and always adjust preferences).
#
# ⭐ EXACT-KEY (the ratified seam discipline): to_dictionary() has a pinned key set (DICTIONARY_KEYS), and the
# nested metrics dict has its own pinned key set (METRICS_KEYS) — a key never silently appears or vanishes.

const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

# The stable top-level key set of to_dictionary() (pinned by test).
const DICTIONARY_KEYS: Array[String] = [
	"offer_resume",
	"offer_save_and_exit",
	"offer_options",
	"metrics"
]

# The stable key set of the nested metrics dict (pinned by test). Every value is a pure read of existing run state.
const METRICS_KEYS: Array[String] = [
	"class_display",
	"depth",
	"cleared_nodes",
	"total_nodes",
	"gold",
	"corruption"
]

var offer_resume: bool = true
var offer_save_and_exit: bool = false
var offer_options: bool = true
var metrics: Dictionary = {}

# Build the pause-menu projection from the seated run. A null / terminal run offers no Save & Exit and projects
# empty/default metrics (a defensive path — the pause menu is only opened mid-run, but this stays fail-safe).
static func from_run(run: RunState) -> PauseMenuViewModel:
	var view: PauseMenuViewModel = load("res://scripts/ui/view_models/pause_menu_view_model.gd").new()
	view.offer_resume = true
	view.offer_options = true
	view.offer_save_and_exit = run != null and not run.is_terminal()
	view.metrics = _metrics_for(run)
	return view


# Project the run metrics from existing read seams ONLY (selected class, route progress/depth, gold, corruption). A
# null run yields the neutral defaults. Adds NO new domain state and reads NO metric that is not already available.
static func _metrics_for(run: RunState) -> Dictionary:
	if run == null:
		return {
			"class_display": "—",
			"depth": 0,
			"cleared_nodes": 0,
			"total_nodes": 0,
			"gold": 0,
			"corruption": 0
		}
	var cleared_nodes: int = 0
	var total_nodes: int = 0
	var depth: int = 0
	if run.route != null:
		cleared_nodes = run.route.cleared_node_ids.size()
		total_nodes = run.route.node_count()
		var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
		if current != null:
			depth = current.depth
	var gold: int = 0
	var corruption: int = 0
	if run.risk_economy != null:
		gold = run.risk_economy.gold
		corruption = run.risk_economy.corruption
	return {
		"class_display": _class_display(run.selected_class_id),
		"depth": depth,
		"cleared_nodes": cleared_nodes,
		"total_nodes": total_nodes,
		"gold": gold,
		"corruption": corruption
	}


# A human display label for the selected class id (a pure display read — never raw snake_case). An empty / legacy
# seed-only run (no class) reads "—". String.capitalize() converts snake_case to Title Case.
static func _class_display(class_id: StringName) -> String:
	if String(class_id).is_empty():
		return "—"
	return String(class_id).capitalize()


# Exact-key projection: plain data only (no live handle leaks out). A fresh dictionary each call; the nested metrics
# dict is duplicated so a caller can never mutate the projection.
func to_dictionary() -> Dictionary:
	return {
		"offer_resume": offer_resume,
		"offer_save_and_exit": offer_save_and_exit,
		"offer_options": offer_options,
		"metrics": metrics.duplicate(true)
	}
