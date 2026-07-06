extends "res://tests/unit/test_case.gd"

# Story 11.4 (AC1/AC3) — the LIVE AFFINITY CALL SITE on the run flow (RunOrchestrator.resolve_combat_node_live): the
# affinity's FIRST live wiring on the live board, layered on the 11.2 live combat path. Covers:
#   - AC1 assignment call site: an unassigned node is ASSIGNED its affinity ONCE (the assign-if-absent guard the 7.4
#           review deferred to "the later per-node-assign story" — that is 11.4); a pre-assigned node is NOT re-rolled
#           (idempotency — the `map` stream is not touched a second time).
#   - AC1 Scorched: a Scorched node stamps HAZARD cells on the live board + surfaces the live board for the render.
#   - AC1 Cursed: a Cursed node SEATS the cursed-affinity rule source on the run's RulesResolver (register_curse) so the
#           kernel resolves + explains the Cursed pressure via explain(level_entered); a re-drive does not double-seat.
#   - AC1 neutral fingerprint safety: the DEFAULT (auto-resolve) run_to_completion stays byte-identical (the live
#           affinity path is on the LIVE combat path only — it does not perturb the non-live route-position determinism).
#   - AC3 Darkness fairness on the live path: a live Darkness node RUNS DarknessFairnessQuery.check_board on the live
#           board (a fair v0 board passes by construction), and the resolve metadata REFLECTS the query verdict (the HUD
#           single-authority — the verdict the HUD reads is the query's, not a re-derived one).
#   - AC3 Darkness fairness VIOLATION on the live path (Round-1 M1): an intentionally-unfair Darkness board injected
#           through the orchestrator's live-path fairness seam (_check_darkness_fairness_live) STOPS with the query's
#           verbatim fairness_reason + seed + phase (+ the node id/type) and NO partial run progression (the pure query
#           clears no node, advances no turn). NOTE: the real LevelGenerator emits all-FLOOR v0 boards, so this STOP path
#           is unreachable through the real generator — the injection covers the orchestrator wiring the fair-pass case
#           cannot exercise.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DarknessFairnessQuery = preload("res://scripts/generation/level/darkness_fairness_query.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# A verified seed whose depth-0 node is a combat node a strong sword hero clears (the run advances past it) — the 11.2
# LIVE_SEED. Used to drive the live affinity call site to a real terminal outcome.
const LIVE_SEED: int = 4242

func run() -> Dictionary:
	_unassigned_node_is_assigned_its_affinity_once_on_the_live_path()
	_pre_assigned_node_is_not_re_rolled_on_a_re_drive()
	_scorched_node_stamps_hazard_cells_on_the_live_board()
	_cursed_node_seats_the_cursed_affinity_rule_source_once()
	_darkness_node_runs_the_fairness_check_and_reflects_the_verdict()
	_darkness_fairness_violation_on_the_live_path_stops_with_no_partial_progression()
	_neutral_default_run_to_completion_is_repeatable()
	return result()


# ---- AC1: the assign-if-absent guard (once-per-node) ----------------------------------------------

func _unassigned_node_is_assigned_its_affinity_once_on_the_live_path() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var node_id: String = orchestrator.run.route.current_node_id
	# The node carries NO affinity yet (a fresh run).
	assert_equal(orchestrator.assigned_affinity_for(node_id), AffinityDefinition.AFFINITY_NONE, "Setup: a fresh node has no assigned affinity (reads `none`).")

	var resolved: ActionResult = orchestrator.resolve_current_node_live()
	assert_true(resolved.succeeded, "The live resolution should succeed: %s" % resolved.metadata)
	# The node was ASSIGNED an affinity on the live path (the assign-if-absent guard fired) + it is recorded on the run.
	var assigned: StringName = orchestrator.assigned_affinity_for(node_id)
	assert_false(String(assigned).is_empty(), "The live path ASSIGNS the node's affinity (the assign-if-absent guard).")
	assert_equal(String(resolved.metadata.get("affinity_id")), String(assigned), "The resolve metadata surfaces the assigned affinity id.")


func _pre_assigned_node_is_not_re_rolled_on_a_re_drive() -> void:
	# A node PRE-ASSIGNED an affinity is NOT re-rolled: the `map` stream is not drawn a second time (idempotency). Force a
	# specific affinity, snapshot the `map` stream, resolve, and assert the stream + the recorded affinity are unchanged.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var node_id: String = orchestrator.run.route.current_node_id
	orchestrator.run.assigned_affinities[node_id] = String(&"cursed")
	var map_before: Dictionary = _map_stream_snapshot(orchestrator.streams)

	var resolved: ActionResult = orchestrator.resolve_current_node_live()
	assert_true(resolved.succeeded, "The live resolution should succeed for a pre-assigned node: %s" % resolved.metadata)
	assert_equal(orchestrator.assigned_affinity_for(node_id), StringName("cursed"), "A pre-assigned affinity is NOT re-rolled (still cursed).")
	assert_equal(_map_stream_snapshot(orchestrator.streams), map_before, "A pre-assigned node does NOT draw the `map` stream a second time (assign-if-absent idempotency).")


# ---- AC1: Scorched on the live board --------------------------------------------------------------

func _scorched_node_stamps_hazard_cells_on_the_live_board() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var node_id: String = orchestrator.run.route.current_node_id
	orchestrator.run.assigned_affinities[node_id] = String(&"scorched")

	var resolved: ActionResult = orchestrator.resolve_current_node_live()
	assert_true(resolved.succeeded, "A Scorched live node should resolve: %s" % resolved.metadata)
	assert_equal(String(resolved.metadata.get("affinity_id")), "scorched", "The resolve carries the Scorched affinity id.")
	# The live board is surfaced for the render (Task 4) + it carries STAMPED Scorched HAZARD cells.
	var board = resolved.metadata.get("board")
	assert_true(board is BoardState, "The live combat node surfaces the live board for the on-screen render (Task 4).")
	assert_true(_hazard_cell_count(board) > 0, "A Scorched live board carries STAMPED HAZARD cells (the effect applied on the live board).")


# ---- AC1: Cursed on the live run ------------------------------------------------------------------

func _cursed_node_seats_the_cursed_affinity_rule_source_once() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var node_id: String = orchestrator.run.route.current_node_id
	orchestrator.run.assigned_affinities[node_id] = String(&"cursed")

	var resolved: ActionResult = orchestrator.resolve_current_node_live()
	assert_true(resolved.succeeded, "A Cursed live node should resolve: %s" % resolved.metadata)
	# The cursed-affinity rule source is SEATED on the run's RulesResolver + resolvable/explainable via the kernel.
	assert_true(orchestrator.run.rules_resolver != null, "A Cursed node SEATS a RulesResolver on the run.")
	var curse_ids: Array = orchestrator.run.rules_resolver.registered_curse_ids()
	assert_true(curse_ids.has(StringName("curse_affinity_cursed")), "The cursed-affinity rule source is registered (register_curse — the AC1 Cursed seam).")
	var explanations: Array = orchestrator.run.rules_resolver.explain(&"level_entered")
	assert_true(explanations.size() >= 1, "The kernel EXPLAINS the Cursed pressure via explain(level_entered) — the RESOLVE+EXPLAIN v0 posture.")
	assert_true(String(explanations[0]).to_lower().contains("cursed"), "The Cursed explanation identifies the affinity pressure.")

	# A re-drive does not DOUBLE-SEAT the curse (idempotency — a duplicate registered curse would double its explanation).
	# The start node is now cleared; resolve it again directly (the already-cleared path does not re-enter), so re-seat
	# via a second resolve_combat_node_live on the SAME node to prove the seating guard.
	var second: ActionResult = orchestrator.resolve_combat_node_live(orchestrator.run.route.node_by_id(node_id))
	assert_true(second.succeeded or second.is_error(), "A second resolve returns a structured result (cleared/again).")
	assert_equal(orchestrator.run.rules_resolver.registered_curse_ids().size(), curse_ids.size(), "A re-drive does NOT double-seat the cursed-affinity rule source (idempotent seating).")


# ---- AC3: Darkness fairness on the live path + the HUD single-authority ----------------------------

func _darkness_node_runs_the_fairness_check_and_reflects_the_verdict() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var node_id: String = orchestrator.run.route.current_node_id
	orchestrator.run.assigned_affinities[node_id] = String(&"darkness")

	var resolved: ActionResult = orchestrator.resolve_current_node_live()
	assert_true(resolved.succeeded, "A live Darkness node should resolve (a fair v0 board passes): %s" % resolved.metadata)
	# The fairness check RAN on the live path + the resolve REFLECTS the query verdict (the HUD single-authority — AC3).
	var fairness: Dictionary = resolved.metadata.get("darkness_fairness", {})
	assert_equal(fairness.get("darkness_fairness_applicable"), true, "The DarknessFairnessQuery RAN on the live Darkness board (fairness applicable).")
	assert_equal(int(fairness.get("reduced_radius")), DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS, "The verdict carries the Darkness-reduced radius (the query's value, reflected).")
	assert_equal(int(fairness.get("hazard_count")), 0, "A v0 all-FLOOR Darkness board has no hazards (fair by construction).")
	# The verdict the HUD reflects is the DarknessFairnessQuery's OWN report — a non-Darkness affinity is not-applicable.
	# (Force a real non-Darkness affinity — Scorched — so the assign-if-absent guard does not re-roll it. Forcing `none`
	# would read as unassigned and re-roll to whatever the seed yields.)
	var non_darkness: RunOrchestrator = RunOrchestrator.new()
	assert_true(non_darkness.start(LIVE_SEED, false).succeeded, "Setup: a second run for the not-applicable case.")
	var non_darkness_node: String = non_darkness.run.route.current_node_id
	non_darkness.run.assigned_affinities[non_darkness_node] = String(&"scorched")
	var non_darkness_resolved: ActionResult = non_darkness.resolve_current_node_live()
	assert_equal((non_darkness_resolved.metadata.get("darkness_fairness", {}) as Dictionary).get("darkness_fairness_applicable"), false, "A non-Darkness (Scorched) live node's fairness is a legal not-applicable verdict.")


# ---- AC3 (Round-1 M1): a Darkness fairness VIOLATION on the live path STOPS with no partial progression ----

func _darkness_fairness_violation_on_the_live_path_stops_with_no_partial_progression() -> void:
	# Round-1 M1: the fair-pass live case is covered above, but the VIOLATION propagation through the orchestrator seam
	# (_check_darkness_fairness_live restoring the board, carrying the query's failure metadata + node id/type, and
	# resolve_combat_node_live returning it as a hard STOP) is exercised by no test — because the REAL LevelGenerator
	# emits all-FLOOR v0 boards, so a real live Darkness node cannot produce an unfair board (the STOP path is
	# structurally unreachable through the real generator). Inject a hand-built UNFAIR Darkness board (a reachable HAZARD
	# cell UNSEEN at the reduced radius) through the live-path fairness seam and assert: (1) it STOPS (is_error) with the
	# query's verbatim fairness_reason + seed + phase, (2) the orchestrator attaches the node id/type, (3) NO partial run
	# progression occurred (the pure query cleared no node / advanced no turn) — the single-authority + fail-loud contract.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var cleared_before: int = orchestrator.run.route.cleared_node_ids.size()
	var map_before: Dictionary = _map_stream_snapshot(orchestrator.streams)

	# A hand-built Darkness node + a GenerationResult whose payload board is UNFAIR: a reachable HAZARD cell placed well
	# beyond the Darkness-reduced radius (unseen from the entrance at that radius) — "damage from unseen space" (FR58).
	var node: RouteNode = RouteNode.new("m1_darkness_violation_node", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED)
	var seed_text: String = "919191"
	var generation: GenerationResult = GenerationResult.ok({
		"board": _unfair_darkness_board_snapshot(),
		"entrance": {"x": 1, "y": 6},
		"level_seed": seed_text
	})

	var fairness: ActionResult = orchestrator._check_darkness_fairness_live(generation, StringName("darkness"), node)
	assert_true(fairness.is_error(), "M1: an unfair Darkness board STOPS the live fairness check (fail-loud, no partial progression).")
	assert_equal(String(fairness.error_code), String(&"darkness_fairness_violation"), "M1: the STOP carries the darkness_fairness_violation top-level code.")
	# The query's verbatim failure fields are carried through the orchestrator seam (the single authority — not re-derived).
	assert_equal(String(fairness.metadata.get("fairness_reason")), String(DarknessFairnessQuery.REASON_UNSEEN_HAZARD), "M1: the STOP reports the query's unseen-hazard fairness reason verbatim.")
	assert_equal(String(fairness.metadata.get("seed")), seed_text, "M1: the STOP reports the level seed verbatim.")
	assert_false(String(fairness.metadata.get("phase", "")).is_empty(), "M1: the STOP reports the fairness phase.")
	# The orchestrator attaches the node context to the failure (mirroring live_combat_failed).
	assert_equal(String(fairness.metadata.get("node_id")), node.id, "M1: the orchestrator attaches the node id to the fairness violation.")
	assert_equal(String(fairness.metadata.get("node_type")), String(node.type), "M1: the orchestrator attaches the node type to the fairness violation.")
	# NO partial progression: the pure fairness query cleared no node + drew no `map` RNG (it advances no turn, runs no command).
	assert_equal(orchestrator.run.route.cleared_node_ids.size(), cleared_before, "M1: a fairness violation clears NO node (no partial run progression).")
	assert_equal(_map_stream_snapshot(orchestrator.streams), map_before, "M1: the fairness check consumes NO RNG (the pure-query contract).")


# ---- AC1: the DEFAULT (non-live) run_to_completion is REPEATABLE -----------------------------------

func _neutral_default_run_to_completion_is_repeatable() -> void:
	# The 11.4 live affinity wiring is on the LIVE combat path only — the DEFAULT auto-resolve run_to_completion (the path
	# the seed-regression fingerprints depend on) must stay untouched by it. This test proves REPEATABILITY/DETERMINISM:
	# two fresh DEFAULT runs of the same seed IN THIS BUILD reach the same terminal result + the same final stream state
	# (so the live affinity path — reached only via the LIVE flow — perturbs no DEFAULT-path draw). It does NOT prove
	# non-regression vs main (both runs are post-11.4); the actual byte-for-byte non-regression guard is the pinned
	# `tools/dump_*` seed-regression fingerprint suites (test_small/medium_level_layout_seed_regression,
	# test_route_generation_seed_regression, test_seed_batch_regression, test_finale_seed_regression), which are compared
	# against the committed fingerprints and stay byte-identical.
	var first: RunOrchestrator = RunOrchestrator.new()
	assert_true(first.start(LIVE_SEED, false).succeeded, "Setup: first run start.")
	var first_result: ActionResult = first.run_to_completion()
	var second: RunOrchestrator = RunOrchestrator.new()
	assert_true(second.start(LIVE_SEED, false).succeeded, "Setup: second run start.")
	var second_result: ActionResult = second.run_to_completion()
	assert_equal(first_result.succeeded, second_result.succeeded, "Two DEFAULT runs of the same seed reach the same terminal result (repeatable).")
	assert_equal(first.streams.to_snapshot(), second.streams.to_snapshot(), "The DEFAULT run_to_completion stream state is REPEATABLE across two runs of the same seed (the live affinity wiring does not perturb the DEFAULT path); the `tools/dump_*` seed-regression suites are the non-regression-vs-main guard.")


# ---- helpers -------------------------------------------------------------------------------------

func _hazard_cell_count(board) -> int:
	var count: int = 0
	if board == null:
		return 0
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain == BoardCell.Terrain.HAZARD:
			count += 1
	return count


# The `map`-stream slice of a stream-set snapshot (the assignment draws exclusively through `map`, so a re-roll would
# advance its state/draw_index). Compares only the `map` entry so an unrelated stream advance never falses the assertion.
func _map_stream_snapshot(streams: RngStreamSet) -> Dictionary:
	var snapshot: Dictionary = streams.to_snapshot()
	var streams_field: Dictionary = snapshot.get("streams", {})
	return (streams_field.get(String(RngStreamSet.STREAM_MAP), {}) as Dictionary).duplicate(true)


# A BOARD SNAPSHOT (the wire dict the orchestrator restores via BoardState.try_from_snapshot) for an INTENTIONALLY-UNFAIR
# Darkness board (Round-1 M1): a 14x12 open grid (WALL border, FLOOR interior, ENTRANCE at (1,6), EXIT at (12,6)) with a
# reachable HAZARD at (8,6) on the corridor row — distance 7 from the entrance, well beyond the Darkness-reduced radius
# (2), so it is UNSEEN from the entrance = "damage from unseen space" (FR58). Mirrors the fail-loud fixture in
# test_darkness_fairness.gd::_unseen_hazard_at_reduced_radius_fails_loud, expressed as a serialized snapshot.
func _unfair_darkness_board_snapshot() -> Dictionary:
	var width: int = 14
	var height: int = 12
	var corridor_row: int = height / 2
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == corridor_row:
				terrain = BoardCell.Terrain.ENTRANCE
			elif x == width - 2 and y == corridor_row:
				terrain = BoardCell.Terrain.EXIT
			elif x == 8 and y == corridor_row:
				# The unseen reachable hazard beyond the reduced radius (the FR58 violation Darkness introduces).
				terrain = BoardCell.Terrain.HAZARD
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": terrain,
				"occupant_id": "",
				"explored": false,
				"visible": false
			})
	return {
		"width": width,
		"height": height,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": []
	}
