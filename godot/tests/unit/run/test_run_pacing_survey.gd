extends "res://tests/unit/test_case.gd"

# Story 4.6 Task 7.1 — the deterministic headless pacing SURVEY (AC5). v0 has NO real per-node content time
# (placeholder nodes resolve instantly; combat is auto-resolved on successful level generation), so the
# literal "20-35 minute" wall-clock CANNOT be measured honestly from the headless shell. What CAN be measured
# deterministically is the STRUCTURAL pacing surface available today: route length / tier count, the non-boss
# node-COUNT distribution across seeds ([8, 12] + boss), and the node-TYPE mix (combat/elite/shop/reforge/
# gambling/event/secret counts). This test MEASURES + RECORDS that structural surface; the human minute
# targets (20-35 / 5-15 / 45) are a tester-note OVERLAY recorded in the story's Completion Notes.
#
# It makes NO generator / route-weight / recipe change to "fix" pacing — the constant route depth and exact
# node-frequency tuning are explicitly Epic-10 / tracked-follow-up territory (the 4.2 [Review][Decision]
# follow-up). This test only MEASURES + FLAGS the structural characteristics (e.g. the constant 8-tier depth)
# so a human note has something concrete to attach to.

const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")

# A seed sample wide enough to surface the node-COUNT and node-TYPE distributions.
const SURVEY_SEEDS: Array[int] = [0, 1, 2, 3, 5, 7, 11, 13, 17, 42, 99, 100, 256, 314, 777, 1000, 2026, 9999]

func run() -> Dictionary:
	_route_depth_is_constant_8_tiers_across_seeds()
	_non_boss_node_count_distribution_is_bounded_8_to_12()
	_node_type_mix_exercises_a_variety_across_the_seed_sample()
	_exactly_one_terminal_boss_per_route()
	return result()


# Boss-depth survey: every route is a constant 8 tiers (depth-0 start + 6 interior tiers + boss at depth 7).
# This is the known pacing CHARACTERISTIC the 4.2 retro note #7 / the constant-route-depth follow-up flags:
# the [8, 12] node-count variation lives entirely in column WIDTH, never route LENGTH. 4.6 MEASURES + records
# it (a tracked tuning note); the FIX (variable depth) is the Epic-10 pacing pass, NOT this shell.
func _route_depth_is_constant_8_tiers_across_seeds() -> void:
	var observed_boss_depths: Dictionary = {}
	for seed_value: int in SURVEY_SEEDS:
		var route: RouteState = _route_for_seed(seed_value)
		var boss_depth: int = _boss_depth(route)
		observed_boss_depths[boss_depth] = true
		# Boss at depth 7 => 8 tiers (depths 0..7). This is a STRUCTURAL pacing measurement, recorded here.
		assert_equal(boss_depth, 7, "Seed %d: the boss should sit at depth 7 (a constant 8-tier route) — the known constant-depth pacing characteristic." % seed_value)
	# Exactly one distinct boss depth across the whole sample (constant route length).
	assert_equal(observed_boss_depths.size(), 1, "Route depth is CONSTANT across seeds (a single boss depth) — recorded as a tracked pacing characteristic (the [8,12] variation is all in column WIDTH).")


# Non-boss node-COUNT distribution: every route has a non-boss count in [8, 12] (RouteGenerator MIN/MAX). The
# survey records the observed distribution; the test asserts the bound (closing the 4.1 node_count defer as
# permanently benign at the structural level too).
func _non_boss_node_count_distribution_is_bounded_8_to_12() -> void:
	var count_distribution: Dictionary = {}  # node_count -> occurrences (recorded surface)
	for seed_value: int in SURVEY_SEEDS:
		var route: RouteState = _route_for_seed(seed_value)
		var non_boss: int = _non_boss_count(route)
		assert_true(non_boss >= 8 and non_boss <= 12, "Seed %d: non-boss node count must be bounded [8, 12], got %d." % [seed_value, non_boss])
		count_distribution[non_boss] = int(count_distribution.get(non_boss, 0)) + 1
	# The survey must observe at least one route (sanity); the distribution itself is the recorded surface.
	var total_observed: int = 0
	for count_key: int in count_distribution.keys():
		total_observed += int(count_distribution[count_key])
	assert_equal(total_observed, SURVEY_SEEDS.size(), "The pacing survey must measure every seed in the sample.")


# Node-TYPE mix: across the seed sample a VARIETY of node types is realized (not only combat). The survey
# records the union of types seen; the test asserts the mix exercises both combat AND non-combat structure so
# the playtest information surface (clue-driven choices) has genuine variety to act on.
func _node_type_mix_exercises_a_variety_across_the_seed_sample() -> void:
	var type_totals: Dictionary = {}  # node_type -> total count across the sample (recorded surface)
	var combat_total: int = 0
	var non_combat_non_boss_total: int = 0
	for seed_value: int in SURVEY_SEEDS:
		var route: RouteState = _route_for_seed(seed_value)
		for node: RouteNode in route.nodes():
			type_totals[String(node.type)] = int(type_totals.get(String(node.type), 0)) + 1
			if node.type == RouteNode.TYPE_COMBAT or node.type == RouteNode.TYPE_ELITE_COMBAT:
				combat_total += 1
			elif node.type != RouteNode.TYPE_BOSS:
				non_combat_non_boss_total += 1
	assert_true(combat_total >= 1, "The node-type mix must include combat/elite nodes across the sample (combat info surface).")
	assert_true(non_combat_non_boss_total >= 1, "The node-type mix must include NON-combat placeholder nodes across the sample (tradeoff info surface).")
	# At least three DISTINCT node types appear across the sample (combat + boss + at least one non-combat) —
	# the variety the route-information playtest depends on.
	assert_true(type_totals.size() >= 3, "The node-type mix must realize at least three distinct node types across the sample, got %d." % type_totals.size())


# Exactly one terminal boss per route (the run-end boundary the orchestrator drives to run_completed).
func _exactly_one_terminal_boss_per_route() -> void:
	for seed_value: int in SURVEY_SEEDS:
		var route: RouteState = _route_for_seed(seed_value)
		var boss_count: int = 0
		for node: RouteNode in route.nodes():
			if node.type == RouteNode.TYPE_BOSS:
				boss_count += 1
		assert_equal(boss_count, 1, "Seed %d: a route must have exactly one terminal boss." % seed_value)


# ---- helpers -------------------------------------------------------------------------------------

func _route_for_seed(seed_value: int) -> RouteState:
	var generation = RouteGenerator.generate(seed_value)
	assert_true(not generation.is_error(), "Route generation should succeed for seed %d." % seed_value)
	var route: RouteState = RouteGenerator.route_from_result(generation)
	assert_true(route != null, "route_from_result should rehydrate a route for seed %d." % seed_value)
	return route


func _boss_depth(route: RouteState) -> int:
	for node: RouteNode in route.nodes():
		if node.type == RouteNode.TYPE_BOSS:
			return node.depth
	return -1


func _non_boss_count(route: RouteState) -> int:
	var count: int = 0
	for node: RouteNode in route.nodes():
		if node.type != RouteNode.TYPE_BOSS:
			count += 1
	return count
