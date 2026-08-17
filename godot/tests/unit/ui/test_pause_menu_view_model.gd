extends "res://tests/unit/test_case.gd"

# Story 15.4 (Review D1) — the scene-free PAUSE-MENU DECISION + RUN-METRICS projection behind the ONE shared pause
# surface. This pins: the entries offered (Resume + Options always; Save & Exit only for a seated NON-terminal run);
# the run-metrics projection from EXISTING read seams (selected class, depth, route progress, gold, corruption); and
# the exact top-level + nested-metrics key sets (a key never silently appears or vanishes). It adds NO domain state
# and reads NO metric that is not already available — a pure read.

const PauseMenuViewModel = preload("res://scripts/ui/view_models/pause_menu_view_model.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

func run() -> Dictionary:
	_from_run_projects_metrics_from_existing_reads()
	_non_terminal_run_offers_save_and_exit()
	_terminal_and_null_run_offer_no_save_and_exit()
	_null_run_projects_neutral_defaults()
	_to_dictionary_pins_the_exact_key_sets()
	return result()


# The metrics are pure reads of existing run state: selected class (human display), current-node depth, cleared/total
# route progress, and gold/corruption from the run economy.
func _from_run_projects_metrics_from_existing_reads() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(42, false, &"warrior").succeeded, "Setup: a warrior start should succeed.")
	var run: RunState = orchestrator.run
	run.risk_economy.apply_gold_delta(42)
	run.risk_economy.set_corruption(3)

	var view: PauseMenuViewModel = PauseMenuViewModel.from_run(run)
	var metrics: Dictionary = view.metrics
	assert_equal(String(metrics.get("class_display")), "Warrior", "The class metric must be the human display of the selected class id.")
	var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
	assert_equal(int(metrics.get("depth")), current.depth, "The depth metric must be the current node's depth (a pure read).")
	assert_equal(int(metrics.get("cleared_nodes")), run.route.cleared_node_ids.size(), "The cleared-nodes metric must be the run's cleared count.")
	assert_equal(int(metrics.get("total_nodes")), run.route.node_count(), "The total-nodes metric must be the route's node count.")
	assert_true(int(metrics.get("total_nodes")) > 0, "The route should have nodes to report.")
	assert_equal(int(metrics.get("gold")), 42, "The gold metric must read the run economy wallet.")
	assert_equal(int(metrics.get("corruption")), 3, "The corruption metric must read the run economy corruption.")


# A seated NON-terminal run offers Resume + Save & Exit + Options.
func _non_terminal_run_offers_save_and_exit() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(42, false, &"warrior").succeeded, "Setup: start should succeed.")
	var view: PauseMenuViewModel = PauseMenuViewModel.from_run(orchestrator.run)
	assert_true(view.offer_resume, "A non-terminal run offers Resume.")
	assert_true(view.offer_save_and_exit, "A non-terminal run offers Save & Exit (a resumable route position).")
	assert_true(view.offer_options, "A non-terminal run offers Options.")


# A terminal (completed/failed) run OR a null run offers NO Save & Exit (no resumable route position). Resume +
# Options stay offered.
func _terminal_and_null_run_offer_no_save_and_exit() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(42, false, &"warrior").succeeded, "Setup: start should succeed.")
	assert_true(orchestrator.resolve_run_end(&"completed").succeeded, "Setup: completing the run should succeed.")
	assert_true(orchestrator.run.is_terminal(), "Setup: the run is terminal.")
	var terminal_view: PauseMenuViewModel = PauseMenuViewModel.from_run(orchestrator.run)
	assert_false(terminal_view.offer_save_and_exit, "A terminal run must NOT offer Save & Exit.")
	assert_true(terminal_view.offer_resume, "A terminal run still offers Resume.")
	assert_true(terminal_view.offer_options, "A terminal run still offers Options.")

	var null_view: PauseMenuViewModel = PauseMenuViewModel.from_run(null)
	assert_false(null_view.offer_save_and_exit, "A null run must NOT offer Save & Exit.")


# A null run projects neutral default metrics (a defensive path) — never a crash.
func _null_run_projects_neutral_defaults() -> void:
	var view: PauseMenuViewModel = PauseMenuViewModel.from_run(null)
	var metrics: Dictionary = view.metrics
	assert_equal(String(metrics.get("class_display")), "—", "A null run projects a neutral class display.")
	assert_equal(int(metrics.get("depth")), 0, "A null run projects depth 0.")
	assert_equal(int(metrics.get("cleared_nodes")), 0, "A null run projects 0 cleared nodes.")
	assert_equal(int(metrics.get("total_nodes")), 0, "A null run projects 0 total nodes.")
	assert_equal(int(metrics.get("gold")), 0, "A null run projects 0 gold.")
	assert_equal(int(metrics.get("corruption")), 0, "A null run projects 0 corruption.")


# The exact-key contract: to_dictionary() carries EXACTLY DICTIONARY_KEYS and the nested metrics dict carries
# EXACTLY METRICS_KEYS.
func _to_dictionary_pins_the_exact_key_sets() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(42, false, &"warrior").succeeded, "Setup: start should succeed.")
	var data: Dictionary = PauseMenuViewModel.from_run(orchestrator.run).to_dictionary()
	assert_equal(data.keys().size(), PauseMenuViewModel.DICTIONARY_KEYS.size(), "to_dictionary() must have exactly the pinned top-level key count.")
	for key: String in PauseMenuViewModel.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must carry the pinned key %s." % key)
	var metrics: Dictionary = data.get("metrics")
	assert_equal(metrics.keys().size(), PauseMenuViewModel.METRICS_KEYS.size(), "The metrics dict must have exactly the pinned key count.")
	for metric_key: String in PauseMenuViewModel.METRICS_KEYS:
		assert_true(metrics.has(metric_key), "The metrics dict must carry the pinned key %s." % metric_key)
