extends "res://tests/unit/test_case.gd"

# Story 3.2 — Seed-Stable Small Level Layouts.
# Covers AC1 (deterministic per-seed layout + seed divergence + `level`-stream-only draws + no
# global fallback + recipe-budget respect + entrance/exit fairness) and AC2 (generated payload ->
# board via the STRICT BoardState.try_from_snapshot, scene-free, with a real JSON round-trip).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

func run() -> Dictionary:
	_same_seed_reproduces_identical_layout()
	_different_seeds_diverge()
	_layout_draws_only_from_level_stream()
	_cosmetic_and_combat_noise_do_not_perturb_layout()
	_blocker_count_respects_recipe_budget_band()
	_disallowed_blockers_produce_no_interior_blockers()
	_zero_budget_produces_no_interior_blockers()
	_entrance_and_exit_are_distinct_and_never_walls()
	_blockers_never_land_on_entrance_or_exit()
	_central_corridor_is_blocker_free_and_walkable()
	_layout_now_places_required_wrinkles()
	_non_small_recipe_is_rejected_structurally()
	_null_inputs_are_rejected_structurally()
	_board_round_trip_matches_acceptance_criteria_2()
	_payload_survives_real_json_transport()
	_board_rides_strict_tactical_snapshot_path()
	return result()


func _small_recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"small_combat_basic")


func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _request(root_seed: int = 1234) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed,
		&"node_1",
		&"combat",
		&"small_combat_basic",
		GenerationRequest.SIZE_SMALL,
		GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE,
		{}
	)


func _generate(root_seed: int, recipe: LevelRecipeDefinition = null) -> Dictionary:
	var request: GenerationRequest = _request(root_seed)
	var resolved_recipe: LevelRecipeDefinition = recipe
	if resolved_recipe == null:
		resolved_recipe = _small_recipe()
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, resolved_recipe, streams, _enemy_repository())
	assert_true(layout_result.succeeded, "Layout generation should succeed for a Small recipe. Error: %s" % layout_result.metadata)
	return layout_result.metadata.get("layout")


func _same_seed_reproduces_identical_layout() -> void:
	var first: Dictionary = _generate(8675309)
	var second: Dictionary = _generate(8675309)
	assert_equal(
		SmallLevelLayoutGenerator.fingerprint(first),
		SmallLevelLayoutGenerator.fingerprint(second),
		"AC1: the same seed + same recipe must reproduce a byte-identical Small layout."
	)
	assert_equal(first, second, "AC1: the same seed must reproduce an identical layout dictionary (terrain, entrance, exit, blockers).")


func _different_seeds_diverge() -> void:
	# AC1 second half: different seeds can produce meaningfully different layouts. Probe several
	# seeds and assert at least two yield distinct fingerprints (blocker layout varies by seed).
	var seeds: Array[int] = [11, 22, 33, 44, 55, 66, 77]
	var fingerprints: Dictionary = {}
	for seed_value: int in seeds:
		fingerprints[SmallLevelLayoutGenerator.fingerprint(_generate(seed_value))] = true
	assert_true(fingerprints.size() >= 2, "AC1: different seeds must be able to produce meaningfully different layouts (got %d distinct over %d seeds)." % [fingerprints.size(), seeds.size()])


func _layout_draws_only_from_level_stream() -> void:
	# Every layout-affecting draw must advance ONLY the level stream. Generate with a tracked stream
	# set, then assert no non-level stream advanced its draw index.
	var request: GenerationRequest = _request(31337)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, _small_recipe(), streams, _enemy_repository())
	assert_true(layout_result.succeeded, "Layout generation should succeed for the level-stream contract probe.")

	var snapshot: Dictionary = streams.to_snapshot()
	var stream_states: Dictionary = snapshot.get("streams")
	var level_draws: int = int(stream_states.get(String(RngStreamSet.STREAM_LEVEL)).get("draw_index"))
	assert_true(level_draws > 0, "Layout generation must consume at least one level-stream draw.")
	for stream_name: StringName in RngStreamSet.required_streams():
		if stream_name == RngStreamSet.STREAM_LEVEL:
			continue
		assert_equal(
			int(stream_states.get(String(stream_name)).get("draw_index")),
			0,
			"Layout generation must NOT draw from the %s stream (level-stream-only contract)." % String(stream_name)
		)


func _cosmetic_and_combat_noise_do_not_perturb_layout() -> void:
	# Pre-advancing cosmetic/combat streams must not change the level-affected layout (stream
	# isolation, carried from Story 1.4 / 3.1). The clean and noisy runs must produce identical
	# layouts because layout draws come exclusively from the level stream.
	var clean_request: GenerationRequest = _request(24680)
	var noisy_request: GenerationRequest = _request(24680)
	var clean_streams: RngStreamSet = RngStreamSet.new(clean_request.level_seed())
	var noisy_streams: RngStreamSet = RngStreamSet.new(noisy_request.level_seed())
	for noise_index: int in range(5):
		noisy_streams.rand_float(RngStreamSet.STREAM_COSMETIC, {"consumer": "ambient", "step": noise_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"consumer": "combat_noise", "step": noise_index})

	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var clean_layout: Dictionary = generator.generate_layout(clean_request, _small_recipe(), clean_streams, _enemy_repository()).metadata.get("layout")
	var noisy_layout: Dictionary = generator.generate_layout(noisy_request, _small_recipe(), noisy_streams, _enemy_repository()).metadata.get("layout")
	assert_equal(
		SmallLevelLayoutGenerator.fingerprint(noisy_layout),
		SmallLevelLayoutGenerator.fingerprint(clean_layout),
		"Cosmetic/combat noise must not perturb the level-affected layout (stream isolation)."
	)


func _blocker_count_respects_recipe_budget_band() -> void:
	var recipe: LevelRecipeDefinition = _small_recipe()
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		var layout: Dictionary = _generate(seed_value, recipe)
		var blocker_count: int = (layout.get("blockers") as Array).size()
		assert_true(
			blocker_count >= recipe.blocker_budget_min and blocker_count <= recipe.blocker_budget_max,
			"Blocker count %d (seed %d) must fall within the recipe budget band [%d..%d]." % [blocker_count, seed_value, recipe.blocker_budget_min, recipe.blocker_budget_max]
		)


func _disallowed_blockers_produce_no_interior_blockers() -> void:
	# allow_blockers = false (and a 0 budget, which validate() requires for allow_blockers=false)
	# must produce zero interior blockers.
	var recipe: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"small_no_blockers",
		LevelRecipeDefinition.SIZE_SMALL,
		false,
		0.0,
		0,
		0,
		2,
		4,
		0,
		1,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Small open arena with no interior blockers (test recipe)."
	)
	assert_true(recipe.validate().succeeded, "The no-blocker test recipe should validate.")
	var layout: Dictionary = _generate(909, recipe)
	assert_equal((layout.get("blockers") as Array).size(), 0, "A recipe with allow_blockers = false must place no interior blockers.")


func _zero_budget_produces_no_interior_blockers() -> void:
	var recipe: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"small_zero_budget",
		LevelRecipeDefinition.SIZE_SMALL,
		true,
		0.1,
		0,
		0,
		2,
		4,
		0,
		1,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Small arena allowing blockers but with a zero blocker budget (test recipe)."
	)
	assert_true(recipe.validate().succeeded, "The zero-budget test recipe should validate.")
	var layout: Dictionary = _generate(414, recipe)
	assert_equal((layout.get("blockers") as Array).size(), 0, "A zero blocker budget must place no interior blockers.")


func _entrance_and_exit_are_distinct_and_never_walls() -> void:
	for seed_value: int in [101, 202, 303]:
		var layout: Dictionary = _generate(seed_value)
		var entrance: Dictionary = layout.get("entrance")
		var exit_cell: Dictionary = layout.get("exit")
		assert_false(
			int(entrance.get("x")) == int(exit_cell.get("x")) and int(entrance.get("y")) == int(exit_cell.get("y")),
			"Entrance and exit must be distinct cells (seed %d)." % seed_value
		)
		var terrain_grid: Array = layout.get("terrain")
		var entrance_terrain: int = int((terrain_grid[int(entrance.get("y"))] as Array)[int(entrance.get("x"))])
		var exit_terrain: int = int((terrain_grid[int(exit_cell.get("y"))] as Array)[int(exit_cell.get("x"))])
		assert_equal(entrance_terrain, BoardCell.Terrain.ENTRANCE, "Entrance cell must carry ENTRANCE terrain (seed %d)." % seed_value)
		assert_equal(exit_terrain, BoardCell.Terrain.EXIT, "Exit cell must carry EXIT terrain (seed %d)." % seed_value)


func _blockers_never_land_on_entrance_or_exit() -> void:
	for seed_value: int in [13, 26, 39, 52, 65]:
		var layout: Dictionary = _generate(seed_value)
		var entrance: Dictionary = layout.get("entrance")
		var exit_cell: Dictionary = layout.get("exit")
		for blocker_value: Variant in (layout.get("blockers") as Array):
			var blocker: Dictionary = blocker_value
			assert_false(
				int(blocker.get("x")) == int(entrance.get("x")) and int(blocker.get("y")) == int(entrance.get("y")),
				"A blocker must never land on the entrance (seed %d)." % seed_value
			)
			assert_false(
				int(blocker.get("x")) == int(exit_cell.get("x")) and int(blocker.get("y")) == int(exit_cell.get("y")),
				"A blocker must never land on the exit (seed %d)." % seed_value
			)


func _central_corridor_is_blocker_free_and_walkable() -> void:
	# Fairness guardrail (documented simplifying assumption for Story 3.6): the central corridor row
	# connecting entrance->exit is reserved as blocker-free floor, so a path provably exists. Verify
	# the entire span between entrance and exit on that row is FLOOR/ENTRANCE/EXIT (never WALL).
	for seed_value: int in [7, 14, 21, 28, 35, 42]:
		var layout: Dictionary = _generate(seed_value)
		var entrance: Dictionary = layout.get("entrance")
		var exit_cell: Dictionary = layout.get("exit")
		var corridor_row: int = int(entrance.get("y"))
		assert_equal(int(exit_cell.get("y")), corridor_row, "Entrance and exit should share the central corridor row (seed %d)." % seed_value)
		var terrain_grid: Array = layout.get("terrain")
		var row: Array = terrain_grid[corridor_row]
		for x: int in range(int(entrance.get("x")), int(exit_cell.get("x")) + 1):
			assert_false(int(row[x]) == BoardCell.Terrain.WALL, "The central corridor (row %d, x=%d) must be free of walls so entrance can reach exit (seed %d)." % [corridor_row, x, seed_value])


func _layout_now_places_required_wrinkles() -> void:
	# Story 3.4: the Small layout now PLACES at least min_tactical_wrinkles readable wrinkles (3.2 placed
	# NONE). Each placed kind is recorded in the layout and is a subset of the recipe allowlist; for
	# small_combat_basic (allowlist choke_point + blocker_cluster, both WALL-realized) the wrinkles are
	# never HAZARD. (Exhaustive AC1/AC2/AC3 wrinkle coverage lives in test_tactical_wrinkle_placement.gd.)
	var recipe: LevelRecipeDefinition = _small_recipe()
	var allowed: Dictionary = {}
	for kind: StringName in recipe.allowed_wrinkle_kinds:
		allowed[String(kind)] = true
	for seed_value: int in [1, 2, 3, 1001, 5005]:
		var layout: Dictionary = _generate(seed_value, recipe)
		var wrinkles: Array = layout.get("wrinkle_kinds")
		assert_true(
			wrinkles.size() >= recipe.min_tactical_wrinkles,
			"Story 3.4: a Small combat layout must now place at least min_tactical_wrinkles (%d) wrinkles (seed %d placed %d)." % [recipe.min_tactical_wrinkles, seed_value, wrinkles.size()]
		)
		for kind_value: Variant in wrinkles:
			assert_true(allowed.has(String(kind_value)), "Story 3.4: a placed wrinkle kind '%s' must be in the recipe allowlist (seed %d)." % [String(kind_value), seed_value])
			assert_false(String(kind_value) == "hazard", "Story 3.4: small_combat_basic does not allow hazard, so the Small layout must never place one (seed %d)." % seed_value)


func _non_small_recipe_is_rejected_structurally() -> void:
	var medium_recipe: LevelRecipeDefinition = LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")
	var request: GenerationRequest = _request(1)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, medium_recipe, streams, _enemy_repository())
	assert_true(layout_result.is_error(), "The Small layout generator must reject a non-Small recipe (Medium is Story 3.3).")
	assert_equal(layout_result.error_code, &"unsupported_size_class_for_layout", "A non-Small recipe should use the stable structured error code.")


func _null_inputs_are_rejected_structurally() -> void:
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var streams: RngStreamSet = RngStreamSet.new(1)
	assert_true(generator.generate_layout(null, _small_recipe(), streams, _enemy_repository()).is_error(), "A null request must be rejected structurally, not crash.")
	assert_true(generator.generate_layout(_request(1), null, streams, _enemy_repository()).is_error(), "A null recipe must be rejected structurally, not crash.")
	assert_true(generator.generate_layout(_request(1), _small_recipe(), null, _enemy_repository()).is_error(), "A null stream set must be rejected structurally, not crash.")


func _board_round_trip_matches_acceptance_criteria_2() -> void:
	# AC2 (Story 3.2) + Story 3.5: a generated Small payload converts to a board via
	# BoardState.try_from_snapshot; bounds match the Small size; entrance/exit terrains are correct;
	# blockers are WALL; the board now carries placed enemies (within the recipe budget); board is
	# RefCounted, not a Node. (Exhaustive enemy/reward AC coverage lives in test_enemy_reward_placement.gd.)
	var recipe: LevelRecipeDefinition = _small_recipe()
	var layout: Dictionary = _generate(2024, recipe)
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var board_result: ActionResult = generator.build_board_snapshot(layout)
	assert_true(board_result.succeeded, "AC2: the generated layout must convert to a board through the strict validator. Error: %s" % board_result.metadata)

	var board_variant: Variant = board_result.metadata.get("board")
	assert_false(board_variant is Node, "AC2: the generated board must be scene-independent domain state, not a Node.")
	var board: BoardState = board_variant
	assert_equal(board.width, 8, "AC2: board width should match the Small size (8).")
	assert_equal(board.height, 8, "AC2: board height should match the Small size (8).")
	assert_true(
		board.entity_count() >= recipe.enemy_budget_min and board.entity_count() <= recipe.enemy_budget_max,
		"Story 3.5: the generated Small board must carry enemies within the recipe budget [%d..%d] (got %d)." % [recipe.enemy_budget_min, recipe.enemy_budget_max, board.entity_count()]
	)
	# Story 3.5: the layout now carries a `rewards` payload marker list (may be empty for Small — its
	# reward_count band is 0..1 — but the key must be present).
	assert_true(layout.has("rewards"), "Story 3.5: the Small layout must carry a `rewards` payload marker list.")

	var entrance: Dictionary = layout.get("entrance")
	var exit_cell: Dictionary = layout.get("exit")
	assert_equal(
		board.get_cell(Vector2i(int(entrance.get("x")), int(entrance.get("y")))).terrain,
		BoardCell.Terrain.ENTRANCE,
		"AC2: the entrance cell must be ENTRANCE terrain on the board."
	)
	assert_equal(
		board.get_cell(Vector2i(int(exit_cell.get("x")), int(exit_cell.get("y")))).terrain,
		BoardCell.Terrain.EXIT,
		"AC2: the exit cell must be EXIT terrain on the board."
	)
	for blocker_value: Variant in (layout.get("blockers") as Array):
		var blocker: Dictionary = blocker_value
		assert_equal(
			board.get_cell(Vector2i(int(blocker.get("x")), int(blocker.get("y")))).terrain,
			BoardCell.Terrain.WALL,
			"AC2: each blocker cell must be WALL terrain on the board."
		)


func _payload_survives_real_json_transport() -> void:
	# Epic 3 retro / Epic 1-2 lesson: verify generated-level seed stability through the REAL JSON
	# transport, never native dicts. The board snapshot must survive JSON.stringify -> parse_string
	# and re-convert through the strict validator.
	var layout: Dictionary = _generate(98765)
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var board_snapshot: Dictionary = generator.build_board_snapshot(layout).metadata.get("board_snapshot")

	var json_text: String = JSON.stringify(board_snapshot)
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "The board snapshot must survive JSON stringify/parse as a dictionary.")
	var restore_result: ActionResult = BoardState.try_from_snapshot(parsed)
	assert_true(restore_result.succeeded, "The JSON-round-tripped board snapshot must restore through the strict validator. Error: %s" % restore_result.metadata)
	var restored_board: BoardState = restore_result.metadata.get("board")
	assert_equal(restored_board.width, 8, "The JSON-round-tripped board must preserve its width.")
	assert_equal(restored_board.height, 8, "The JSON-round-tripped board must preserve its height.")


func _board_rides_strict_tactical_snapshot_path() -> void:
	# The generated board should ride the SAME strict TacticalSnapshot.parse -> BoardState path the
	# save/resume layer uses (validate-then-reject, never coerce). Build a tactical snapshot from the
	# generated board + a fresh stream set and assert it parses.
	var layout: Dictionary = _generate(56789)
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	var streams: RngStreamSet = RngStreamSet.new(56789)

	var snapshot_result: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(snapshot_result.succeeded, "The generated board must build a valid TacticalSnapshot through from_domain. Error: %s" % snapshot_result.metadata)
	var snapshot: TacticalSnapshot = snapshot_result.metadata.get("snapshot")

	var json_dict: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_dict is Dictionary, "The tactical snapshot must survive a JSON round-trip.")
	var parse_result: ActionResult = TacticalSnapshot.parse(json_dict)
	assert_true(parse_result.succeeded, "The generated-level tactical snapshot must re-parse through the strict TacticalSnapshot.parse path. Error: %s" % parse_result.metadata)
