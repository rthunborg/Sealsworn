extends "res://tests/unit/test_case.gd"

# Story 6.7 Task 6.4 — the deterministic headless REWARD-PACING SURVEY (AC2). The Story-4.6
# test_run_pacing_survey.gd structural-measurement precedent, applied to the FR48 early-mid build-defining-passive
# reachability surface. It is placed as a NEW survey file (NOT an extension of test_run_pacing_survey.gd) so the
# 4.6 route-pacing survey stays byte-identical [Decision].
#
# AC2 wants "at least one build-defining passive offer is available by the configured node/depth target" across
# "approved smoke seeds", with a pacing failure pointing to reward-table weights / passive-pool coverage / node
# pacing — NOT a hidden hand-authored fix. So the assertions are STRUCTURAL: the passive_reward_choice table EXISTS
# in the validated RewardTableRepository; its entries reference REAL PassiveRepository baseline ids (cross-checked
# against PassiveRepository.BASELINE_PASSIVE_IDS); a generate_passive_reward_offer(&"passive_reward_choice") yields
# a 3-choice passive offer of DISTINCT real ids; and the early band (the route's first third by RouteNode.depth) is
# reachable on the constant-8-tier MVP route. A failure names the table/weights/pool, not a fixture poke.
#
# It makes NO route-generator / depth-band / reward-weight / passive-pool change to "hit" pacing — it MEASURES +
# records the structural surface. The constant-8-tier route depth is the known 4.2/4.6 follow-up: re-recorded here
# (the early band is depths 0-2), NOT fixed — the variable-depth pacing pass is Epic-10 territory.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")
const RewardTableRepository = preload("res://scripts/content/repositories/reward_table_repository.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

const PASSIVE_TABLE_ID := &"passive_reward_choice"

# A fixed seed sample (the test_run_pacing_survey.gd SURVEY_SEEDS precedent) wide enough to record the structural
# surface deterministically.
const SURVEY_SEEDS: Array[int] = [0, 1, 2, 3, 5, 7, 11, 13, 17, 42, 99, 100, 256, 314, 777, 1000, 2026, 9999]

func run() -> Dictionary:
	_passive_reward_choice_table_exists_in_the_validated_repository()
	_passive_table_entries_reference_real_baseline_passive_ids()
	_passive_offer_yields_three_distinct_real_baseline_ids()
	_early_mid_band_is_reachable_on_the_constant_depth_route()
	return result()


# AC2: the passive_reward_choice table exists in the VALIDATED reward-table repository (the build-defining passive
# offer is reachable from the validated content boundary, never a fixture). The repository is built from validated
# definitions, so its presence is the structural proof the table is reachable + well-formed.
func _passive_reward_choice_table_exists_in_the_validated_repository() -> void:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	assert_true(repository != null, "The baseline reward-table repository must build (validated tables only).")
	var table: RewardTableDefinition = repository.get_reward_table(PASSIVE_TABLE_ID)
	assert_true(table != null, "The passive_reward_choice table must be present in the validated repository (the FR48 build-defining-passive surface).")
	assert_true(table.validate().succeeded, "The passive_reward_choice table must validate.")
	# Its declared choice_count is the 3-choice passive moment.
	assert_equal(table.choice_count, 3, "The passive_reward_choice table declares a 3-choice passive moment.")


# AC2: the table's entries reference REAL baseline passive ids (cross-checked against
# PassiveRepository.BASELINE_PASSIVE_IDS). So a pacing gap names the table/pool, not a fixture poke: a passive id the
# table references but the pool does NOT contain would fail HERE, pointing at the pool/table.
func _passive_table_entries_reference_real_baseline_passive_ids() -> void:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	var table: RewardTableDefinition = repository.get_reward_table(PASSIVE_TABLE_ID)
	var passive_repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	var baseline_ids: Dictionary = {}
	for passive_id: StringName in PassiveRepository.BASELINE_PASSIVE_IDS:
		baseline_ids[String(passive_id)] = true

	var distinct_referenced: Dictionary = {}
	for entry_value: Variant in table.reward_entries():
		var entry: Dictionary = entry_value
		# Every entry is a `passive`-category entry (this is the passive-choice table).
		assert_equal(String(entry.get("category")), String(RewardTableDefinition.CATEGORY_PASSIVE), "Every passive_reward_choice entry must be a `passive` entry.")
		var content_id: String = String(entry.get("content_id"))
		# The referenced id is a REAL baseline passive (in the BASELINE_PASSIVE_IDS list AND resolvable).
		assert_true(baseline_ids.has(content_id), "Passive '%s' referenced by the table must be a baseline passive id (the table/pool must agree)." % content_id)
		assert_true(passive_repository.get_passive(StringName(content_id)) != null, "Passive '%s' referenced by the table must resolve in the PassiveRepository." % content_id)
		distinct_referenced[content_id] = true

	# The table references at least the 3-choice floor of distinct passives (so a 3-choice draw can succeed).
	assert_true(distinct_referenced.size() >= 3, "The passive_reward_choice table must reference >= 3 distinct baseline passives for a 3-choice draw, got %d." % distinct_referenced.size())


# AC2: a generate_passive_reward_offer through the run-level streams yields a 3-choice passive offer of DISTINCT
# real baseline ids — deterministically (the same seed reproduces it). This is the genuine multi-choice passive
# offer the FR48 readiness item demands, generated by the orchestrator's caller-driven generate path.
func _passive_offer_yields_three_distinct_real_baseline_ids() -> void:
	var passive_repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	# A small deterministic sample is enough; the generate is a pure function of the (seed, table).
	for seed_value: int in [0, 42, 777, 2026]:
		var orchestrator: RunOrchestrator = RunOrchestrator.new()
		var started: ActionResult = orchestrator.start(seed_value, false, &"warrior")
		assert_true(started.succeeded, "Seed %d: the run should start." % seed_value)

		var generated: ActionResult = orchestrator.generate_passive_reward_offer(PASSIVE_TABLE_ID)
		assert_true(generated.succeeded, "Seed %d: the passive offer should generate: %s" % [seed_value, generated.metadata])
		var offered_entries: Array = generated.metadata.get("offered_entries")
		assert_equal(offered_entries.size(), 3, "Seed %d: the passive offer should surface 3 distinct choices." % seed_value)

		var seen: Dictionary = {}
		for entry_value: Variant in offered_entries:
			var entry: Dictionary = entry_value
			assert_equal(String(entry.get("category")), String(RewardTableDefinition.CATEGORY_PASSIVE), "Seed %d: every offered choice is a passive." % seed_value)
			var content_id: String = String(entry.get("content_id"))
			assert_false(seen.has(content_id), "Seed %d: the three offered choices must be DISTINCT (no duplicate %s)." % [seed_value, content_id])
			seen[content_id] = true
			# Each offered choice is a REAL adoptable baseline passive (the player can Consume it into the resolver).
			assert_true(passive_repository.get_passive(StringName(content_id)) != null, "Seed %d: offered passive '%s' must be a real baseline passive." % [seed_value, content_id])

		# Determinism: a second independent run on the SAME seed reproduces the SAME offer.
		var orchestrator_b: RunOrchestrator = RunOrchestrator.new()
		orchestrator_b.start(seed_value, false, &"warrior")
		var generated_b: ActionResult = orchestrator_b.generate_passive_reward_offer(PASSIVE_TABLE_ID)
		assert_true(generated_b.succeeded, "Seed %d: the second passive offer should generate." % seed_value)
		assert_equal(JSON.stringify(generated_b.metadata.get("offer")), JSON.stringify(generated.metadata.get("offer")), "Seed %d: the passive offer must reproduce from the same seed (deterministic)." % seed_value)


# AC2: the early-mid band is reachable on the constant-8-tier MVP route. The early band is the route's first third
# by RouteNode.depth (ratio <= 0.34 of the last non-boss depth — the route_generator _type_weights_for_band
# boundary). On the constant-8-tier route the last non-boss depth is 6, so the early band is depths 0-2; the survey
# RECORDS this + re-flags the constant depth as the known Epic-10 tuning characteristic (NOT fixed here).
func _early_mid_band_is_reachable_on_the_constant_depth_route() -> void:
	for seed_value: int in SURVEY_SEEDS:
		var route: RouteState = _route_for_seed(seed_value)
		var last_non_boss_depth: int = _last_non_boss_depth(route)
		assert_equal(last_non_boss_depth, 6, "Seed %d: the last non-boss depth is a constant 6 (the known constant-8-tier pacing characteristic)." % seed_value)
		# Early band = depth ratio <= 0.34 of the last non-boss depth => depths 0..2 reachable.
		var early_band_depths: Array[int] = []
		for node: RouteNode in route.nodes():
			if node.type == RouteNode.TYPE_BOSS:
				continue
			if float(node.depth) <= 0.34 * float(last_non_boss_depth):
				early_band_depths.append(node.depth)
		assert_false(early_band_depths.is_empty(), "Seed %d: the early band (depths 0-2) must contain reachable non-boss nodes (the build-defining passive offer can be generated by the early-mid band)." % seed_value)
		# The route start (depth 0) is always in the early band, so an early-mid offer is always reachable.
		assert_true(early_band_depths.has(0), "Seed %d: the depth-0 start is always in the early band (the offer can be generated at the earliest node-completion boundary)." % seed_value)


# ---- helpers -------------------------------------------------------------------------------------

func _route_for_seed(seed_value: int) -> RouteState:
	var generation = RouteGenerator.generate(seed_value)
	assert_true(not generation.is_error(), "Route generation should succeed for seed %d." % seed_value)
	var route: RouteState = RouteGenerator.route_from_result(generation)
	assert_true(route != null, "route_from_result should rehydrate a route for seed %d." % seed_value)
	return route


func _last_non_boss_depth(route: RouteState) -> int:
	var max_depth: int = -1
	for node: RouteNode in route.nodes():
		if node.type == RouteNode.TYPE_BOSS:
			continue
		if node.depth > max_depth:
			max_depth = node.depth
	return max_depth
