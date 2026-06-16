extends "res://tests/unit/test_case.gd"

# Story 3.3 — Seed-Stable Medium Level Layouts.
# Covers AC1 (deterministic per-seed layout + seed divergence + `level`-stream-only draws + stream
# isolation + no global fallback + recipe-budget respect + entrance/exit fairness + reserved
# corridor walkability), AC2 (the THREE readability rejections — excessive blockage / unreachable
# exit / unreadable first reveal — each a structured PHASE_VALIDATION-style error with COMPACT
# diagnostics, exercised by deliberately-malformed hand-built candidates; approved layouts PASS),
# and the generated payload -> board conversion via the STRICT BoardState.try_from_snapshot
# (scene-free, real JSON round-trip, strict TacticalSnapshot path).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const MEDIUM_WIDTH: int = 14
const MEDIUM_HEIGHT: int = 12

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
	_non_medium_recipe_is_rejected_structurally()
	_null_inputs_are_rejected_structurally()
	_approved_layout_passes_readability_validation()
	_excessive_blockage_candidate_is_rejected_with_diagnostics()
	_unreachable_exit_candidate_is_rejected_with_diagnostics()
	_unreadable_first_reveal_candidate_is_rejected_with_diagnostics()
	_validate_readability_rejects_malformed_shape()
	_build_board_snapshot_rejects_malformed_shape()
	_board_round_trip_matches_acceptance_criteria()
	_payload_survives_real_json_transport()
	_board_rides_strict_tactical_snapshot_path()
	return result()


func _medium_recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")


func _request(root_seed: int = 1234) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed,
		&"node_1",
		&"combat",
		&"medium_combat_basic",
		GenerationRequest.SIZE_MEDIUM,
		GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE,
		{}
	)


func _generate(root_seed: int, recipe: LevelRecipeDefinition = null) -> Dictionary:
	var request: GenerationRequest = _request(root_seed)
	var resolved_recipe: LevelRecipeDefinition = recipe
	if resolved_recipe == null:
		resolved_recipe = _medium_recipe()
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, resolved_recipe, streams)
	assert_true(layout_result.succeeded, "Layout generation should succeed for a Medium recipe. Error: %s" % layout_result.metadata)
	return layout_result.metadata.get("layout")


func _same_seed_reproduces_identical_layout() -> void:
	var first: Dictionary = _generate(8675309)
	var second: Dictionary = _generate(8675309)
	assert_equal(
		MediumLevelLayoutGenerator.fingerprint(first),
		MediumLevelLayoutGenerator.fingerprint(second),
		"AC1: the same seed + same recipe must reproduce a byte-identical Medium layout."
	)
	assert_equal(first, second, "AC1: the same seed must reproduce an identical layout dictionary (terrain, entrance, exit, blockers).")


func _different_seeds_diverge() -> void:
	# AC1 second half: different seeds can produce meaningfully different layouts. Probe several seeds
	# and assert at least two yield distinct fingerprints (blocker layout varies by seed).
	var seeds: Array[int] = [11, 22, 33, 44, 55, 66, 77]
	var fingerprints: Dictionary = {}
	for seed_value: int in seeds:
		fingerprints[MediumLevelLayoutGenerator.fingerprint(_generate(seed_value))] = true
	assert_true(fingerprints.size() >= 2, "AC1: different seeds must be able to produce meaningfully different layouts (got %d distinct over %d seeds)." % [fingerprints.size(), seeds.size()])


func _layout_draws_only_from_level_stream() -> void:
	# Every layout-affecting draw must advance ONLY the level stream. Generate with a tracked stream
	# set, then assert no non-level stream advanced its draw index.
	var request: GenerationRequest = _request(31337)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, _medium_recipe(), streams)
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
	# isolation, carried from Story 1.4 / 3.1 / 3.2). The clean and noisy runs must produce identical
	# layouts because layout draws come exclusively from the level stream.
	var clean_request: GenerationRequest = _request(24680)
	var noisy_request: GenerationRequest = _request(24680)
	var clean_streams: RngStreamSet = RngStreamSet.new(clean_request.level_seed())
	var noisy_streams: RngStreamSet = RngStreamSet.new(noisy_request.level_seed())
	for noise_index: int in range(5):
		noisy_streams.rand_float(RngStreamSet.STREAM_COSMETIC, {"consumer": "ambient", "step": noise_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"consumer": "combat_noise", "step": noise_index})

	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var clean_layout: Dictionary = generator.generate_layout(clean_request, _medium_recipe(), clean_streams).metadata.get("layout")
	var noisy_layout: Dictionary = generator.generate_layout(noisy_request, _medium_recipe(), noisy_streams).metadata.get("layout")
	assert_equal(
		MediumLevelLayoutGenerator.fingerprint(noisy_layout),
		MediumLevelLayoutGenerator.fingerprint(clean_layout),
		"Cosmetic/combat noise must not perturb the level-affected layout (stream isolation)."
	)


func _blocker_count_respects_recipe_budget_band() -> void:
	var recipe: LevelRecipeDefinition = _medium_recipe()
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
		&"medium_no_blockers",
		LevelRecipeDefinition.SIZE_MEDIUM,
		false,
		0.0,
		0,
		0,
		3,
		6,
		1,
		2,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Medium open arena with no interior blockers (test recipe)."
	)
	assert_true(recipe.validate().succeeded, "The no-blocker test recipe should validate.")
	var layout: Dictionary = _generate(909, recipe)
	assert_equal((layout.get("blockers") as Array).size(), 0, "A recipe with allow_blockers = false must place no interior blockers.")


func _zero_budget_produces_no_interior_blockers() -> void:
	var recipe: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"medium_zero_budget",
		LevelRecipeDefinition.SIZE_MEDIUM,
		true,
		0.1,
		0,
		0,
		3,
		6,
		1,
		2,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Medium arena allowing blockers but with a zero blocker budget (test recipe)."
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
	# Construction guarantee (documented; Story 3.6 owns the formal replacement): the central corridor
	# row connecting entrance->exit is reserved as blocker-free floor, so a path provably exists.
	# Verify the entire span between entrance and exit on that row is FLOOR/ENTRANCE/EXIT (never WALL).
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


func _non_medium_recipe_is_rejected_structurally() -> void:
	var small_recipe: LevelRecipeDefinition = LevelRecipeRepository.create_baseline_repository().get_recipe(&"small_combat_basic")
	var request: GenerationRequest = _request(1)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, small_recipe, streams)
	assert_true(layout_result.is_error(), "The Medium layout generator must reject a non-Medium recipe (Small is Story 3.2).")
	assert_equal(layout_result.error_code, &"unsupported_size_class_for_layout", "A non-Medium recipe should use the stable structured error code.")


func _null_inputs_are_rejected_structurally() -> void:
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var streams: RngStreamSet = RngStreamSet.new(1)
	assert_true(generator.generate_layout(null, _medium_recipe(), streams).is_error(), "A null request must be rejected structurally, not crash.")
	assert_true(generator.generate_layout(_request(1), null, streams).is_error(), "A null recipe must be rejected structurally, not crash.")
	assert_true(generator.generate_layout(_request(1), _medium_recipe(), null).is_error(), "A null stream set must be rejected structurally, not crash.")


func _approved_layout_passes_readability_validation() -> void:
	# AC2: a generated (approved-seed) Medium layout PASSES all three readability checks — the
	# rejection paths are exercised by deliberately-malformed candidates below, not by approved seeds.
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	for seed_value: int in [1001, 2002, 3003, 4004, 5005, 12345]:
		var layout: Dictionary = _generate(seed_value)
		var validation: ActionResult = generator.validate_readability(layout)
		assert_true(validation.succeeded, "AC2: an approved-seed Medium layout (seed %d) must pass the readability validation. Error: %s" % [seed_value, validation.metadata])


func _excessive_blockage_candidate_is_rejected_with_diagnostics() -> void:
	# AC2 (a): a candidate whose interior is mostly WALL must be rejected as excessively blocked, with
	# compact diagnostics (counts/ratio/bound), not a full grid dump. The excessive-blockage check
	# runs first, so a near-fully-walled interior trips it.
	var terrain_grid: Array = _open_terrain_grid()
	# Wall almost the entire interior (leave only the corridor row open).
	for y: int in range(1, MEDIUM_HEIGHT - 1):
		if y == MEDIUM_HEIGHT / 2:
			continue
		for x: int in range(1, MEDIUM_WIDTH - 1):
			_set_terrain(terrain_grid, x, y, BoardCell.Terrain.WALL)
	var layout: Dictionary = _layout_from_grid(terrain_grid)

	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var validation: ActionResult = generator.validate_readability(layout)
	assert_true(validation.is_error(), "AC2: an over-blocked candidate must be rejected.")
	assert_equal(validation.error_code, &"excessive_blockage", "AC2: an over-blocked candidate must use the excessive_blockage code.")
	# Compact diagnostics: counts/ratio/bound present; NOT a full grid.
	assert_true(validation.metadata.has("interior_wall_count"), "AC2: excessive_blockage diagnostics must report the interior wall count.")
	assert_true(validation.metadata.has("wall_ratio"), "AC2: excessive_blockage diagnostics must report the offending wall ratio.")
	assert_true(validation.metadata.has("max_wall_ratio"), "AC2: excessive_blockage diagnostics must report the readability bound.")
	assert_false(validation.metadata.has("terrain"), "AC2: diagnostics must stay compact (no full terrain grid dump).")


func _unreachable_exit_candidate_is_rejected_with_diagnostics() -> void:
	# AC2 (b): a candidate where a full interior WALL column separates entrance from exit must be
	# rejected as having an unreachable exit. The wall column is sparse enough to pass the
	# excessive-blockage check first.
	var terrain_grid: Array = _open_terrain_grid()
	# Vertical WALL wall at x=6 spanning every interior row — fully partitions left from right.
	for y: int in range(1, MEDIUM_HEIGHT - 1):
		_set_terrain(terrain_grid, 6, y, BoardCell.Terrain.WALL)
	var layout: Dictionary = _layout_from_grid(terrain_grid)

	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var validation: ActionResult = generator.validate_readability(layout)
	assert_true(validation.is_error(), "AC2: an exit-walled candidate must be rejected.")
	assert_equal(validation.error_code, &"unreachable_exit", "AC2: an exit-walled candidate must use the unreachable_exit code.")
	# Compact diagnostics: entrance + exit coordinates + reachable-cell count.
	assert_true(validation.metadata.has("entrance"), "AC2: unreachable_exit diagnostics must report the entrance coordinate.")
	assert_true(validation.metadata.has("exit"), "AC2: unreachable_exit diagnostics must report the exit coordinate.")
	assert_true(validation.metadata.has("reachable_cell_count"), "AC2: unreachable_exit diagnostics must report the reachable-cell count.")


func _unreadable_first_reveal_candidate_is_rejected_with_diagnostics() -> void:
	# AC2 (c): a candidate that passes excessive-blockage AND keeps the exit reachable, but where the
	# entrance opens into a 1-wide tunnel so the area visible/reachable within the baseline LoS radius
	# (4) is too small to orient, must be rejected as an unreadable first reveal. We wall rows 5 and 7
	# for x=1..5, leaving only the corridor row (6) open near the entrance — entrance still reaches
	# the open right half (and the exit) via row 6, so checks (a) and (b) pass first.
	var terrain_grid: Array = _open_terrain_grid()
	for x: int in range(1, 6):
		_set_terrain(terrain_grid, x, 5, BoardCell.Terrain.WALL)
		_set_terrain(terrain_grid, x, 7, BoardCell.Terrain.WALL)
	var layout: Dictionary = _layout_from_grid(terrain_grid)

	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	# Sanity: the exit must still be reachable (so we are genuinely isolating the first-reveal check,
	# not accidentally tripping unreachable_exit).
	var validation: ActionResult = generator.validate_readability(layout)
	assert_true(validation.is_error(), "AC2: a boxed-in-first-reveal candidate must be rejected.")
	assert_equal(validation.error_code, &"unreadable_first_reveal", "AC2: a boxed-in-first-reveal candidate must use the unreadable_first_reveal code (exit still reachable, interior not over-blocked).")
	# Compact diagnostics: the visible-cell count + the minimum + the radius used.
	assert_true(validation.metadata.has("first_reveal_count"), "AC2: unreadable_first_reveal diagnostics must report the visible-cell count.")
	assert_true(validation.metadata.has("min_first_reveal_cells"), "AC2: unreadable_first_reveal diagnostics must report the minimum.")
	assert_true(validation.metadata.has("radius"), "AC2: unreadable_first_reveal diagnostics must report the radius used.")


func _validate_readability_rejects_malformed_shape() -> void:
	# A hand-built layout whose declared dimensions disagree with the terrain grid is rejected with a
	# structured error rather than crashing.
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var malformed: Dictionary = {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"entrance": {"x": 1, "y": 6},
		"exit": {"x": 12, "y": 6},
		"blockers": [],
		"terrain": []
	}
	var validation: ActionResult = generator.validate_readability(malformed)
	assert_true(validation.is_error(), "A malformed-shape layout must be rejected by validate_readability, not crash.")
	assert_equal(validation.error_code, &"invalid_layout_shape", "A malformed-shape layout must use the invalid_layout_shape code.")


func _build_board_snapshot_rejects_malformed_shape() -> void:
	# The leading shape guard on build_board_snapshot (closes the 3.2-deferred Low for this generator):
	# a layout whose width/height disagree with the terrain grid returns a structured error.
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var malformed: Dictionary = {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"terrain": []
	}
	var board_result: ActionResult = generator.build_board_snapshot(malformed)
	assert_true(board_result.is_error(), "A malformed-shape layout must be rejected by build_board_snapshot, not crash.")
	assert_equal(board_result.error_code, &"invalid_layout_shape", "A malformed-shape layout must use the invalid_layout_shape code.")


func _board_round_trip_matches_acceptance_criteria() -> void:
	# AC1: a generated Medium payload converts to a board via BoardState.try_from_snapshot; bounds
	# match the Medium size (14x12); entrance/exit terrains are correct; blockers are WALL;
	# entity_count == 0; board is RefCounted, not a Node.
	var layout: Dictionary = _generate(2024)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board_result: ActionResult = generator.build_board_snapshot(layout)
	assert_true(board_result.succeeded, "AC1: the generated layout must convert to a board through the strict validator. Error: %s" % board_result.metadata)

	var board_variant: Variant = board_result.metadata.get("board")
	assert_false(board_variant is Node, "AC1: the generated board must be scene-independent domain state, not a Node.")
	var board: BoardState = board_variant
	assert_equal(board.width, MEDIUM_WIDTH, "AC1: board width should match the Medium size (14).")
	assert_equal(board.height, MEDIUM_HEIGHT, "AC1: board height should match the Medium size (12).")
	assert_equal(board.entity_count(), 0, "AC1: the generated board must carry no entities this story.")

	var entrance: Dictionary = layout.get("entrance")
	var exit_cell: Dictionary = layout.get("exit")
	assert_equal(
		board.get_cell(Vector2i(int(entrance.get("x")), int(entrance.get("y")))).terrain,
		BoardCell.Terrain.ENTRANCE,
		"AC1: the entrance cell must be ENTRANCE terrain on the board."
	)
	assert_equal(
		board.get_cell(Vector2i(int(exit_cell.get("x")), int(exit_cell.get("y")))).terrain,
		BoardCell.Terrain.EXIT,
		"AC1: the exit cell must be EXIT terrain on the board."
	)
	for blocker_value: Variant in (layout.get("blockers") as Array):
		var blocker: Dictionary = blocker_value
		assert_equal(
			board.get_cell(Vector2i(int(blocker.get("x")), int(blocker.get("y")))).terrain,
			BoardCell.Terrain.WALL,
			"AC1: each blocker cell must be WALL terrain on the board."
		)


func _payload_survives_real_json_transport() -> void:
	# Epic 3 retro / Epic 1-2 lesson: verify generated-level seed stability through the REAL JSON
	# transport, never native dicts. The board snapshot must survive JSON.stringify -> parse_string
	# and re-convert through the strict validator.
	var layout: Dictionary = _generate(98765)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board_snapshot: Dictionary = generator.build_board_snapshot(layout).metadata.get("board_snapshot")

	var json_text: String = JSON.stringify(board_snapshot)
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "The board snapshot must survive JSON stringify/parse as a dictionary.")
	var restore_result: ActionResult = BoardState.try_from_snapshot(parsed)
	assert_true(restore_result.succeeded, "The JSON-round-tripped board snapshot must restore through the strict validator. Error: %s" % restore_result.metadata)
	var restored_board: BoardState = restore_result.metadata.get("board")
	assert_equal(restored_board.width, MEDIUM_WIDTH, "The JSON-round-tripped board must preserve its width.")
	assert_equal(restored_board.height, MEDIUM_HEIGHT, "The JSON-round-tripped board must preserve its height.")


func _board_rides_strict_tactical_snapshot_path() -> void:
	# The generated board should ride the SAME strict TacticalSnapshot.parse -> BoardState path the
	# save/resume layer uses (validate-then-reject, never coerce). Build a tactical snapshot from the
	# generated board + a fresh stream set and assert it parses.
	var layout: Dictionary = _generate(56789)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	var streams: RngStreamSet = RngStreamSet.new(56789)

	var snapshot_result: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(snapshot_result.succeeded, "The generated board must build a valid TacticalSnapshot through from_domain. Error: %s" % snapshot_result.metadata)
	var snapshot: TacticalSnapshot = snapshot_result.metadata.get("snapshot")

	var json_dict: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_dict is Dictionary, "The tactical snapshot must survive a JSON round-trip.")
	var parse_result: ActionResult = TacticalSnapshot.parse(json_dict)
	assert_true(parse_result.succeeded, "The generated-level tactical snapshot must re-parse through the strict TacticalSnapshot.parse path. Error: %s" % parse_result.metadata)


# --- Hand-built candidate helpers (for the AC2 rejection-path tests) ---------------------------
# Build a base "open" terrain grid that mirrors the generator's construction (border ring = WALL,
# interior = FLOOR, entrance/exit on the central row) so a candidate is a realistic layout with
# specific cells overridden by the test.
func _open_terrain_grid() -> Array:
	var corridor_row: int = MEDIUM_HEIGHT / 2
	var terrain_grid: Array = []
	for y: int in range(MEDIUM_HEIGHT):
		var row: Array = []
		for x: int in range(MEDIUM_WIDTH):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == MEDIUM_WIDTH - 1 or y == MEDIUM_HEIGHT - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == corridor_row:
				terrain = BoardCell.Terrain.ENTRANCE
			elif x == MEDIUM_WIDTH - 2 and y == corridor_row:
				terrain = BoardCell.Terrain.EXIT
			row.append(terrain)
		terrain_grid.append(row)
	return terrain_grid


func _set_terrain(terrain_grid: Array, x: int, y: int, terrain: int) -> void:
	(terrain_grid[y] as Array)[x] = terrain


func _layout_from_grid(terrain_grid: Array) -> Dictionary:
	var blockers: Array = []
	for y: int in range(1, MEDIUM_HEIGHT - 1):
		for x: int in range(1, MEDIUM_WIDTH - 1):
			if int((terrain_grid[y] as Array)[x]) == BoardCell.Terrain.WALL:
				blockers.append({"x": x, "y": y})
	return {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"entrance": {"x": 1, "y": MEDIUM_HEIGHT / 2},
		"exit": {"x": MEDIUM_WIDTH - 2, "y": MEDIUM_HEIGHT / 2},
		"blockers": blockers,
		"terrain": terrain_grid
	}
