extends "res://tests/unit/test_case.gd"

# Story 7.6 Task 4 (AC1 second half, AC3) — the Darkness FAIRNESS GUARDRAIL (the heart of FR58). These prove
# DarknessFairnessQuery is the board-scoped, affinity-aware "no unavoidable damage from unseen space" check:
#   - PASS for a FAIR Darkness level: entrance safe at the reduced radius, no reachable hazard unseen-BEFORE-CONTACT at
#     the reduced radius (a fresh all-FLOOR Small board passes by construction; a Medium board with reachable hazards
#     passes because each is necessarily seen from an adjacent step-from cell before contact — see below).
#   - SEEDED Darkness levels pass first-reveal + unseen-space checks (AC3): drive the approved Small + Medium seeds
#     through the real generator, assign Darkness, and assert the fairness check passes — and on a (non-expected)
#     failure the message carries seed + phase + fairness reason.
#   - FAIL LOUD for an UNFAIR Darkness level (AC3 "failures report seed, phase, and fairness reason"): spawning ON a
#     hazard / ON an enemy fails (the predicate-(a) safe-first-reveal semantic — the v0 "unavoidable, no see-first-step"
#     configs).
#   - PURE: the check draws no RNG, mutates nothing; same (board, affinity, seed) -> identical verdict.
#   - NEUTRAL / non-Darkness: a legal not-applicable pass (no reduced radius to re-assert).
#
# ⭐ STORY 10.8 — predicate (b) was STRENGTHENED from static-from-ENTRANCE to MOVING reduced-radius LoS
# ("seen-before-contact"). A reachable hazard is now fair iff the hero necessarily SEES it from some reachable
# 4-neighbour step-from cell BEFORE they can step onto it (which, under the v0 facts — hazards walkable +
# sight-transparent, adjacent-cell LoS unoccludable, reduced radius >= 1 — is true for EVERY reachable hazard). The
# 7.6 case that placed a reachable hazard "far down an OPEN corridor" (entrance-unseen at radius 2) and asserted FAIL
# is DELIBERATELY converted below to a PASS (`_far_corridor_hazard_is_seen_before_contact_and_passes`), because that
# exact config is now legitimately fair under seen-before-contact. The retained FAIL cases are predicate (a)
# (entrance-on-hazard / entity-on-entrance) — the only genuinely-unfair configs the v0 terrain vocabulary can express.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DarknessFairnessQuery = preload("res://scripts/generation/level/darkness_fairness_query.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# The approved Small + Medium seeds the existing seed-regression suite pins (the AC3 "seeded Darkness levels" set).
const APPROVED_SEEDS: Array[int] = [1001, 2002, 3003, 4004, 5005]

func run() -> Dictionary:
	_fair_darkness_board_passes()
	_seeded_darkness_levels_pass_first_reveal_and_unseen_space_checks()
	# Story 10.8 — the moving-LoS proof: the old far-corridor FAIL board is now a legitimate PASS (seen-before-contact).
	_far_corridor_hazard_is_seen_before_contact_and_passes()
	_hazard_visible_at_reduced_radius_passes()
	_entrance_on_hazard_fails_loud()
	_entity_on_entrance_fails_loud()
	# Story 10.8 — the retained "genuinely-unfair still FAILS" proof (predicate (a): the v0 unavoidable/no-see-first config).
	_genuinely_unfair_predicate_a_still_fails_loud()
	_sealed_unreachable_hazard_does_not_fail()
	_neutral_level_is_not_applicable()
	_check_is_pure_no_mutation()
	_failure_carries_seed_phase_and_reason()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


# Build a BoardState from a terrain grid + optional enemy entities, mirroring the generator's build_board_snapshot
# occupant invariant (set occupant_id on each blocking entity's cell). Entrance terrain marks the entrance cell.
func _board_from_grid(width: int, height: int, terrain_grid: Array, entities: Array = []) -> BoardState:
	var occupant_by_cell: Dictionary = {}
	for entity_value: Variant in entities:
		var entity: Dictionary = entity_value
		if bool(entity.get("blocks_movement", true)):
			var pos: Dictionary = entity.get("position")
			occupant_by_cell[Vector2i(int(pos.get("x")), int(pos.get("y")))] = String(entity.get("entity_id"))
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": int((terrain_grid[y] as Array)[x]),
				"occupant_id": occupant_by_cell.get(Vector2i(x, y), ""),
				"explored": false,
				"visible": false
			})
	var snapshot: Dictionary = {
		"width": width,
		"height": height,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": entities.duplicate(true)
	}
	var build: ActionResult = BoardState.try_from_snapshot(snapshot)
	assert_true(build.succeeded, "Setup: the hand-built fairness board should build. Error: %s" % build.metadata)
	return build.metadata.get("board") as BoardState


# An open grid: WALL border ring, FLOOR interior, ENTRANCE on the central-left, EXIT on the central-right (mirrors the
# generator's construction so a hand-built candidate is a realistic fair layout).
func _open_grid(width: int, height: int) -> Array:
	var corridor_row: int = height / 2
	var grid: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == corridor_row:
				terrain = BoardCell.Terrain.ENTRANCE
			elif x == width - 2 and y == corridor_row:
				terrain = BoardCell.Terrain.EXIT
			row.append(terrain)
		grid.append(row)
	return grid


func _set_terrain(grid: Array, x: int, y: int, terrain: int) -> void:
	(grid[y] as Array)[x] = terrain


func _enemy_dict(entity_id: String, cell: Vector2i) -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_type": String(TacticalEntityState.ENTITY_TYPE_ENEMY),
		"faction": "labyrinth",
		"position": {"x": cell.x, "y": cell.y},
		"current_hp": 10,
		"max_hp": 10,
		"blocks_movement": true,
		"definition_id": "iron_cultist"
	}


func _board_terrain_snapshot(board: BoardState) -> Array:
	var result: Array = []
	for board_cell: BoardCell in board.cells():
		result.append([board_cell.position.x, board_cell.position.y, board_cell.terrain])
	return result


# ---- fair board passes ---------------------------------------------------------------------------

func _fair_darkness_board_passes() -> void:
	# A large open all-FLOOR Darkness board: no hazard => nothing unseen can hurt the hero => fair by construction.
	var grid: Array = _open_grid(11, 11)
	var board: BoardState = _board_from_grid(11, 11, grid)
	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "777")
	assert_true(check.succeeded, "AC1/AC3: a fair (all-FLOOR) Darkness board passes the fairness check. Error: %s" % check.metadata)
	assert_equal(check.metadata.get("darkness_fairness_applicable"), true, "The fairness check applies to a Darkness level.")
	assert_equal(int(check.metadata.get("hazard_count")), 0, "An all-FLOOR Darkness board has no hazards.")
	assert_true(int(check.metadata.get("reduced_radius")) < 4, "The pass report carries the Darkness-reduced radius.")


func _seeded_darkness_levels_pass_first_reveal_and_unseen_space_checks() -> void:
	# AC3: drive the approved seeds through the real generator, assign Darkness, run the fairness check. v0 generated
	# boards are all-FLOOR, so a generated Darkness board passes first-reveal + unseen-space by construction — and this
	# proves it deterministically across the seed-regression catalog (the AC3 "seeded Darkness levels are generated and
	# simulated" + "first reveal and unseen-space checks pass").
	var recipe_repo: LevelRecipeRepository = LevelRecipeRepository.create_baseline_repository()
	var enemy_repo: EnemyRepository = EnemyRepository.create_baseline_repository()
	for seed: int in APPROVED_SEEDS:
		var request: GenerationRequest = GenerationRequest.new(
			seed, &"node_1", &"combat", &"small_combat_basic",
			GenerationRequest.SIZE_SMALL, GenerationRequest.DIFFICULTY_STANDARD,
			GenerationRequest.AFFINITY_NONE, {}
		)
		var generation: Variant = LevelGenerator.generate(request, recipe_repo, enemy_repo)
		assert_true(generation.succeeded, "Setup: seed %s should generate a valid Small level." % seed)
		var payload: Dictionary = generation.payload
		var seed_text: String = String(payload.get("level_seed", str(seed)))
		var board: BoardState = BoardState.from_snapshot(payload.get("board"))
		assert_true(board != null, "Setup: seed %s board snapshot should rehydrate." % seed)
		# Assign Darkness to this generated level + run the fairness check at the reduced radius.
		var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), seed_text)
		# AC3 failure reporting: if it ever fails, surface seed + phase + fairness reason in the assert message.
		assert_true(check.succeeded, "AC3: seeded Darkness level passes first-reveal + unseen-space. seed=%s phase=%s reason=%s" % [
			seed_text,
			String(check.metadata.get("phase", "")),
			String(check.metadata.get("fairness_reason", ""))
		])


# ---- Story 10.8: the MOVING-LoS proof (seen-before-contact) ---------------------------------------

func _far_corridor_hazard_is_seen_before_contact_and_passes() -> void:
	# ⭐ STORY 10.8 DELIBERATE FLIP (was `_unseen_hazard_at_reduced_radius_fails_loud`, an ASSERT-FAIL): a Darkness board
	# with a reachable HAZARD cell placed FAR down the open corridor (distance 7 from the entrance, well beyond the
	# reduced radius 2) is NOW a legitimate PASS. Under the v0-STATIC-from-entrance predicate this FAILED
	# `darkness_unseen_hazard` (the hazard is entrance-unseen at radius 2). Under the STRENGTHENED moving reduced-radius
	# LoS predicate it PASSES: the hazard is walkable + sight-transparent, so the hero necessarily stands on an adjacent
	# reachable FLOOR "step-from" cell the turn before they could step onto it, and from that cell the hazard is at
	# distance 1 (<= reduced radius) with unoccludable adjacent-cell LoS — i.e. it is SEEN BEFORE CONTACT. Fair.
	var width: int = 14
	var height: int = 12
	var grid: Array = _open_grid(width, height)
	var corridor_row: int = height / 2
	# Hazard at x=8 on the corridor row: distance from entrance (1,6) is 7 > reduced radius 2 (entrance-unseen), reachable
	# via the open corridor. This is the EXACT 7.6 fixture whose verdict flips FAIL -> PASS under seen-before-contact.
	_set_terrain(grid,8, corridor_row, BoardCell.Terrain.HAZARD)
	var board: BoardState = _board_from_grid(width, height, grid)

	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "424242")
	assert_true(check.succeeded, "AC1/AC2 (10.8): an entrance-unseen but seen-before-contact reachable hazard PASSES the moving-LoS fairness check (was FAIL under static-from-entrance). Error: %s" % check.metadata)
	assert_equal(check.metadata.get("darkness_fairness_applicable"), true, "The check applies to a Darkness level.")
	assert_equal(int(check.metadata.get("hazard_count")), 1, "The far-corridor hazard is counted.")
	assert_equal(int(check.metadata.get("reachable_seen_hazard_count")), 1, "The reachable hazard is proven seen-before-contact (reachable-and-seen).")


func _hazard_visible_at_reduced_radius_passes() -> void:
	# A Darkness board with a HAZARD cell placed WITHIN the reduced radius + with line of sight from the entrance — it is
	# SEEN on first reveal at the reduced radius, so it is fair (seen + avoidable; the LevelValidator "seen => fair"
	# principle held at the reduced radius).
	var width: int = 11
	var height: int = 11
	var grid: Array = _open_grid(width, height)
	var corridor_row: int = height / 2
	# Hazard adjacent to the entrance (x=2 on the corridor): distance 1 <= reduced radius 2, open LoS -> seen. Fair.
	_set_terrain(grid,2, corridor_row, BoardCell.Terrain.HAZARD)
	var board: BoardState = _board_from_grid(width, height, grid)

	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "9")
	assert_true(check.succeeded, "A hazard SEEN at the reduced radius is fair (seen + avoidable). Error: %s" % check.metadata)
	assert_equal(int(check.metadata.get("hazard_count")), 1, "The pass report counts the (fairly-seen) hazard.")
	assert_equal(int(check.metadata.get("reachable_seen_hazard_count")), 1, "The seen hazard is counted as reachable-and-seen.")


# ---- fail loud: safe-first-reveal semantic -------------------------------------------------------

func _entrance_on_hazard_fails_loud() -> void:
	var width: int = 9
	var height: int = 9
	var grid: Array = _open_grid(width, height)
	var corridor_row: int = height / 2
	# Put HAZARD on the entrance cell itself (forced turn-1 damage).
	_set_terrain(grid,1, corridor_row, BoardCell.Terrain.HAZARD)
	var board: BoardState = _board_from_grid(width, height, grid)
	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "5", Vector2i(1, corridor_row))
	assert_true(check.is_error(), "Spawning ON a hazard fails the Darkness fairness check.")
	assert_equal(String(check.metadata.get("fairness_reason")), String(DarknessFairnessQuery.REASON_ENTRANCE_ON_HAZARD), "The failure reports entrance_on_hazard.")
	assert_equal(String(check.metadata.get("seed")), "5", "The failure reports the seed.")


func _entity_on_entrance_fails_loud() -> void:
	var width: int = 9
	var height: int = 9
	var grid: Array = _open_grid(width, height)
	var corridor_row: int = height / 2
	# An enemy ON the entrance cell (the player would spawn on an enemy). Build with the entity occupant on the entrance.
	var board: BoardState = _board_from_grid(width, height, grid, [_enemy_dict("enemy_on_entrance", Vector2i(1, corridor_row))])
	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "6", Vector2i(1, corridor_row))
	assert_true(check.is_error(), "An entity on the entrance fails the Darkness fairness check.")
	assert_equal(String(check.metadata.get("fairness_reason")), String(DarknessFairnessQuery.REASON_ENTITY_ON_ENTRANCE), "The failure reports entity_on_entrance.")


func _genuinely_unfair_predicate_a_still_fails_loud() -> void:
	# Story 10.8 — the moving-LoS predicate strengthening did NOT weaken the guardrail for GENUINELY-unfair boards. Under
	# the v0 terrain vocabulary the only "unavoidable, no see-first-step" configs are predicate (a): HAZARD on the
	# entrance cell (forced turn-1 damage — there is no earlier cell to see it from). This proves the strengthened check
	# still FAILS LOUD for that config with the stable reason + top-level code (a sight-blocking hazard / forced-teleport
	# movement — the OTHER genuinely-unfair classes — do not exist in v0, so predicate (a) is the retained live FAIL). If
	# a future story adds a sight-blocking hazard, the moving-LoS predicate-(b) LoS check re-trips `darkness_unseen_hazard`.
	var width: int = 10
	var height: int = 10
	var grid: Array = _open_grid(width, height)
	var corridor_row: int = height / 2
	_set_terrain(grid, 1, corridor_row, BoardCell.Terrain.HAZARD)  # HAZARD on the entrance cell (1, corridor).
	var board: BoardState = _board_from_grid(width, height, grid)
	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "108108", Vector2i(1, corridor_row))
	assert_true(check.is_error(), "Story 10.8: a genuinely-unfair (entrance-on-hazard) Darkness board still FAILS LOUD under moving-LoS.")
	assert_equal(String(check.error_code), "darkness_fairness_violation", "The failure carries the stable top-level error code.")
	assert_equal(String(check.metadata.get("fairness_reason")), String(DarknessFairnessQuery.REASON_ENTRANCE_ON_HAZARD), "The retained FAIL is the predicate-(a) entrance_on_hazard config.")
	assert_equal(String(check.metadata.get("seed")), "108108", "The failure reports the seed verbatim.")


func _sealed_unreachable_hazard_does_not_fail() -> void:
	# A HAZARD cell SEALED behind walls (terrain-unreachable from the entrance) cannot be stepped on, so it is NOT an
	# unseen-damage source — it must NOT fail the check (a hazard you can never reach hurts no one).
	var width: int = 11
	var height: int = 11
	var grid: Array = _open_grid(width, height)
	# Carve a fully walled 1-cell pocket in a corner with a hazard inside it (ring it with WALL so it is unreachable).
	# Interior corner near (width-2, 1). Put walls around (width-3, 2) and a hazard at (width-3, 2).
	var hx: int = width - 3
	var hy: int = 2
	_set_terrain(grid,hx, hy, BoardCell.Terrain.HAZARD)
	_set_terrain(grid,hx - 1, hy, BoardCell.Terrain.WALL)
	_set_terrain(grid,hx + 1, hy, BoardCell.Terrain.WALL)
	_set_terrain(grid,hx, hy - 1, BoardCell.Terrain.WALL)
	_set_terrain(grid,hx, hy + 1, BoardCell.Terrain.WALL)
	var board: BoardState = _board_from_grid(width, height, grid)
	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "11")
	assert_true(check.succeeded, "A SEALED (unreachable) hazard is not an unseen-damage source — it does not fail. Error: %s" % check.metadata)
	assert_equal(int(check.metadata.get("hazard_count")), 1, "The sealed hazard is counted...")
	assert_equal(int(check.metadata.get("reachable_seen_hazard_count")), 0, "...but it is not reachable, so it is not a fairness risk.")


# ---- neutral / purity ----------------------------------------------------------------------------

func _neutral_level_is_not_applicable() -> void:
	var board: BoardState = _board_from_grid(9, 9, _open_grid(9, 9))
	for affinity_id: StringName in [AffinityDefinition.AFFINITY_NONE, &"scorched", &"flooded_conductive", &"cursed", &"unknown_id"]:
		var check: ActionResult = DarknessFairnessQuery.new().check_board(board, affinity_id, _repository(), "1")
		assert_true(check.succeeded, "%s is a legal not-applicable fairness result." % String(affinity_id))
		assert_equal(check.metadata.get("darkness_fairness_applicable"), false, "%s is not a Darkness level — the Darkness fairness check does not apply." % String(affinity_id))


func _check_is_pure_no_mutation() -> void:
	var width: int = 11
	var height: int = 11
	var grid: Array = _open_grid(width, height)
	_set_terrain(grid,2, height / 2, BoardCell.Terrain.HAZARD)
	var board: BoardState = _board_from_grid(width, height, grid)
	var before: Array = _board_terrain_snapshot(board)
	var first: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "3")
	var second: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), "3")
	assert_equal(first.succeeded, second.succeeded, "AC3: the fairness verdict is deterministic.")
	assert_equal(first.metadata.get("reachable_seen_hazard_count"), second.metadata.get("reachable_seen_hazard_count"), "The fairness diagnostics are deterministic.")
	assert_equal(_board_terrain_snapshot(board), before, "The fairness check mutates NO board state (pure query).")
	assert_false(first.has_events(), "The fairness check emits ZERO events (pure query).")


func _failure_carries_seed_phase_and_reason() -> void:
	# Belt-and-suspenders for the AC3 contract: the full failure shape carries all three (seed + phase + fairness reason)
	# AND the stable top-level error code, exercised via a decimal-string seed (the int64 discipline). Story 10.8: the
	# old far-corridor-hazard FAIL board now PASSES under moving-LoS, so this uses a config that STILL fails — a
	# predicate-(a) entrance-on-hazard board (the retained v0 unavoidable/no-see-first config).
	var width: int = 14
	var height: int = 12
	var grid: Array = _open_grid(width, height)
	var corridor_row: int = height / 2
	_set_terrain(grid, 1, corridor_row, BoardCell.Terrain.HAZARD)  # HAZARD on the entrance cell -> entrance_on_hazard FAIL.
	var board: BoardState = _board_from_grid(width, height, grid)
	var big_seed: String = "9223372036854775807"  # int64 max as a decimal string (the seed-string discipline).
	var check: ActionResult = DarknessFairnessQuery.new().check_board(board, &"darkness", _repository(), big_seed, Vector2i(1, corridor_row))
	assert_true(check.is_error(), "An unfair Darkness board fails loud.")
	assert_equal(String(check.error_code), "darkness_fairness_violation", "AC3: ONE stable top-level error code for the failure class.")
	assert_equal(String(check.metadata.get("seed")), big_seed, "AC3: the seed is carried verbatim (decimal-string safe for int64).")
	assert_equal(String(check.metadata.get("phase")), "validation", "AC3: the failure reports the validation phase.")
	assert_false(String(check.metadata.get("fairness_reason", "")).is_empty(), "AC3: the failure reports a stable fairness reason.")
	# Both the predicate-(a) entrance codes AND the predicate-(b) unseen-hazard code map to the validation phase (one
	# fairness phase vocabulary — the 7.6 contract, unchanged by 10.8).
	assert_equal(DarknessFairnessQuery.phase_for_reason(DarknessFairnessQuery.REASON_ENTRANCE_ON_HAZARD), &"validation", "The entrance-on-hazard reason maps to the validation phase.")
	assert_equal(DarknessFairnessQuery.phase_for_reason(DarknessFairnessQuery.REASON_UNSEEN_HAZARD), &"validation", "The unseen-hazard reason maps to the validation phase.")
