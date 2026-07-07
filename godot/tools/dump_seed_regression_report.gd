extends SceneTree

# One-shot dev tool (Story 10.2): dump the CONSOLIDATED seed-regression report across all six named systems
# (tactical, generation, route, reward/passive, affinity, boss) for eyeballing / re-pinning. Prints one
# `[PASS|FAIL] system / seed: fingerprint` line per fixture, calling each system's SINGLE canonical
# fingerprint/determinism source (NO second format) — the same sources the consolidated regression suite
# (tests/integration/test_seed_regression_suite.gd) asserts. This driver is the human-eyeball / re-pin
# companion to that suite (the dump_seed_batch_report.gd precedent, generalized to all six systems).
#
# NOT a test (lives under tools/, NOT auto-discovered by the headless runner; provably excluded from every
# export preset via the tools/** exclude_filter — it cannot ship in a production build). DEBUG/manual-seed
# tool: it grants NO progression and writes NO `user://` artifact (it only prints). Build-profile-appropriate
# (a tools/ SceneTree script, never shipped as gameplay). Run via PowerShell:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_seed_regression_report.gd
#
# RE-PIN DISCIPLINE (AC4): a fingerprint changes ONLY with an INTENTIONAL generator/system change re-pinned in
# the SAME PR via the matching per-system tools/dump_* (dump_seed_batch_report.gd / dump_route_fingerprints.gd
# / the finale inline catalog) — NEVER hand-edited to silence a drift. This driver only READS + PRINTS; it
# does not pin anything. The consolidated suite is the tripwire; this is the eyeball.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BossArenaBuilder = preload("res://scripts/generation/boss/boss_arena_builder.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")

const SeedBatchRegressionTest = preload("res://tests/unit/generation/test_seed_batch_regression.gd")
const RouteSeedRegressionTest = preload("res://tests/unit/generation/test_route_generation_seed_regression.gd")
const FinaleSeedRegressionTest = preload("res://tests/integration/finale/test_finale_seed_regression.gd")

func _init() -> void:
	var recipes := LevelRecipeRepository.create_baseline_repository()
	var enemies := EnemyRepository.create_baseline_repository()

	print("=== CONSOLIDATED SEED REGRESSION REPORT (Story 10.2) ===")
	print("Format: [PASS|FAIL] system / seed: fingerprint (from each system's canonical source)")

	_report_generation(recipes, enemies)
	_report_route()
	_report_boss()
	_report_reward()
	_report_affinity()
	_report_tactical()

	print("=== END REPORT ===")
	quit()


func _report_generation(recipes: LevelRecipeRepository, enemies: EnemyRepository) -> void:
	print("--- generation (Small/Medium; source SmallLevelLayoutGenerator.fingerprint / MediumLevelLayoutGenerator.fingerprint) ---")
	for entry: Dictionary in SeedBatchRegressionTest.APPROVED_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))
		var recipe_id: String = String(entry.get("recipe_id"))
		var size_class: String = String(entry.get("size_class"))
		var expected: String = String(entry.get("fingerprint"))
		var recipe: LevelRecipeDefinition = recipes.get_recipe(StringName(recipe_id))
		if recipe == null:
			print("[FAIL] generation / %d (%s): unknown_recipe" % [seed_value, recipe_id])
			continue
		var request := GenerationRequest.new(
			seed_value, &"node_1", &"combat", StringName(recipe_id),
			StringName(size_class), GenerationRequest.DIFFICULTY_STANDARD, GenerationRequest.AFFINITY_NONE, {}
		)
		var streams := RngStreamSet.new(seed_value)
		var actual: String
		if size_class == "small":
			var small_result: ActionResult = SmallLevelLayoutGenerator.new().generate_layout(request, recipe, streams, enemies)
			actual = SmallLevelLayoutGenerator.fingerprint(small_result.metadata.get("layout")) if small_result.succeeded else "<layout_failed>"
		else:
			var medium_result: ActionResult = MediumLevelLayoutGenerator.new().generate_layout(request, recipe, streams, enemies)
			actual = MediumLevelLayoutGenerator.fingerprint(medium_result.metadata.get("layout")) if medium_result.succeeded else "<layout_failed>"
		var status: String = "PASS" if actual == expected else "FAIL"
		print("[%s] generation / %d (%s): %s" % [status, seed_value, recipe_id, actual])


func _report_route() -> void:
	print("--- route (source RouteGenerator.fingerprint) ---")
	var keys: Array = RouteSeedRegressionTest.APPROVED_FINGERPRINTS.keys()
	keys.sort()
	for seed_key: Variant in keys:
		var root_seed: int = int(seed_key)
		var expected: String = String(RouteSeedRegressionTest.APPROVED_FINGERPRINTS[seed_key])
		var generation: GenerationResult = RouteGenerator.generate(root_seed)
		if generation.is_error():
			print("[FAIL] route / %d: <generate_failed:%s>" % [root_seed, String(generation.error_code)])
			continue
		var actual: String = RouteGenerator.fingerprint(RouteGenerator.route_from_result(generation))
		var status: String = "PASS" if actual == expected else "FAIL"
		print("[%s] route / %d: %s" % [status, root_seed, actual])


func _report_boss() -> void:
	print("--- boss/finale (source: live setup composite — fixed arena + ZERO-RNG AI, no layout fingerprint) ---")
	for entry: Dictionary in FinaleSeedRegressionTest.APPROVED_BOSS_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))
		var first: GenerationResult = BossArenaBuilder.new().build(BossEncounterRequest.new(seed_value, &"node_7_0"))
		var second: GenerationResult = BossArenaBuilder.new().build(BossEncounterRequest.new(seed_value, &"node_7_0"))
		if not (first.succeeded and second.succeeded):
			print("[FAIL] boss / %d: <arena_build_failed>" % seed_value)
			continue
		var fp_one: String = _boss_setup_fingerprint(first.payload)
		var fp_two: String = _boss_setup_fingerprint(second.payload)
		var status: String = "PASS" if fp_one == fp_two else "FAIL"
		print("[%s] boss / %d: %s" % [status, seed_value, fp_one])


func _report_reward() -> void:
	print("--- reward/passive (source: per-seed offer payload via RunOrchestrator.generate_reward_offer) ---")
	for seed_value: int in [1, 7, 42, 99, 2026, 314, 777, 8675309]:
		var a: RunOrchestrator = RunOrchestrator.new()
		var b: RunOrchestrator = RunOrchestrator.new()
		a.start(seed_value, false)
		b.start(seed_value, false)
		a.generate_reward_offer(&"standard_combat_reward")
		b.generate_reward_offer(&"standard_combat_reward")
		var fp_a: String = _reward_fingerprint(a)
		var fp_b: String = _reward_fingerprint(b)
		var status: String = "PASS" if fp_a == fp_b else "FAIL"
		# The full serialized offer is long; print a short hash-like prefix for eyeballing.
		print("[%s] reward / %d: %s" % [status, seed_value, fp_a.substr(0, 80)])


func _report_affinity() -> void:
	print("--- affinity (source: RunOrchestrator.assign_affinity selected id, per implemented affinity) ---")
	for seed_value: int in [1, 7, 42, 99, 2026, 314, 777, 8675309]:
		var a: RunOrchestrator = RunOrchestrator.new()
		var b: RunOrchestrator = RunOrchestrator.new()
		a.start(seed_value, false)
		b.start(seed_value, false)
		var node_a = a.run.route.nodes()[0]
		var node_b = b.run.route.nodes()[0]
		var assign_a: ActionResult = a.assign_affinity(node_a)
		var assign_b: ActionResult = b.assign_affinity(node_b)
		var id_a: String = String(assign_a.metadata.get("affinity_id")) if assign_a.succeeded else "<assign_failed>"
		var id_b: String = String(assign_b.metadata.get("affinity_id")) if assign_b.succeeded else "<assign_failed>"
		var status: String = "PASS" if id_a == id_b else "FAIL"
		print("[%s] affinity / %d: %s" % [status, seed_value, id_a])


func _report_tactical() -> void:
	print("--- tactical (source: board snapshot + ordered applied-event log composite) ---")
	for seed_value: int in [1, 7, 42, 99, 2026, 314, 777, 8675309]:
		# Two identical committed-move sequences from the same seed reproduce a byte-identical composite.
		var fp_one: String = _tactical_composite(seed_value)
		var fp_two: String = _tactical_composite(seed_value)
		var status: String = "PASS" if fp_one == fp_two else "FAIL"
		print("[%s] tactical / %d: <composite %d bytes>" % [status, seed_value, fp_one.length()])


# ---- helpers (mirror the consolidated suite's canonical composites) -------------------------------

func _boss_setup_fingerprint(payload: Dictionary) -> String:
	var board: Dictionary = payload.get("board_snapshot", {})
	var width: int = int(board.get("width", 0))
	var height: int = int(board.get("height", 0))
	var terrain: String = ""
	for cell_value: Variant in board.get("cells", []):
		var cell: Dictionary = cell_value
		terrain += str(int(cell.get("terrain", 0)))
	var entrance: Dictionary = payload.get("entrance", {})
	var slot: Dictionary = payload.get("boss_slot", {})
	return "%dx%d|e%d,%d|b%d,%d|%s" % [
		width, height,
		int(entrance.get("x", -1)), int(entrance.get("y", -1)),
		int(slot.get("x", -1)), int(slot.get("y", -1)),
		terrain
	]


func _reward_fingerprint(orchestrator: RunOrchestrator) -> String:
	if orchestrator.run.pending_reward_offer == null:
		return "<no-offer>"
	return JSON.stringify(orchestrator.run.pending_reward_offer.to_dictionary())


func _tactical_composite(seed_value: int) -> String:
	var BoardFixtureFactory = load("res://tests/fixtures/tactical/board_fixture_factory.gd")
	var DomainEvent = load("res://scripts/core/events/domain_event.gd")
	var board = BoardFixtureFactory.edge_corner_movement()
	var streams := RngStreamSet.new(seed_value)
	var log: Array = []
	var move_one = DomainEvent.entity_moved(board.next_sequence_id(), &"hero", board.get_entity(&"hero").position, Vector2i(1, 0), 1, 3)
	board.apply_event(move_one)
	log.append(move_one.to_dictionary())
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat", "step": "tac1"})
	var move_two = DomainEvent.entity_moved(board.next_sequence_id(), &"hero", board.get_entity(&"hero").position, Vector2i(2, 0), 1, 3)
	board.apply_event(move_two)
	log.append(move_two.to_dictionary())
	streams.rand_float(RngStreamSet.STREAM_LOOT, {"system": "loot", "step": "tac2"})
	var composite: Dictionary = {"board": board.to_snapshot(), "events": log, "rng": streams.to_snapshot()}
	return JSON.stringify(JSON.parse_string(JSON.stringify(composite)))
