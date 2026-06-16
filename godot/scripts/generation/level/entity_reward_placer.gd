class_name EntityRewardPlacer
extends RefCounted

# Deterministic enemy + reward placement shared by BOTH layout generators (Epic 3, Story 3.5).
#
# SIBLING-KEEPER: SmallLevelLayoutGenerator and MediumLevelLayoutGenerator are siblings (same fixed
# draw order, same shrinking-pool selection, same fingerprint format, same TacticalWrinklePlacer).
# Enemy + reward placement is the same logic for both, so it lives here as a small shared RefCounted
# helper rather than being copy-pasted. It is intentionally NOT a general placement framework — it
# places ENEMIES (board entities) and abstract REWARD MARKERS (payload data) and nothing else.
#
# WHAT THIS STORY PLACES:
#   - ENEMIES (AC1): up to recipe.enemy_budget enemies on legal unoccupied non-entrance/exit/wall/
#     blocker/wrinkle cells, every cell reachable from the entrance, resolved THROUGH EnemyRepository,
#     emitted as TacticalEntityState (entity_type = ENEMY) board-entity dictionaries. The enemy KIND
#     set is drawn from a CANONICAL fixed order (PLACEMENT_ENEMY_ORDER) so selection is deterministic
#     and independent of repository registration order (mirrors TacticalWrinklePlacer.REALIZABLE_KINDS).
#   - REWARD MARKERS (AC2): up to recipe.reward_count abstract reward markers {x, y, optional} on legal
#     floor/hazard cells. Rewards are PAYLOAD DATA, NOT board entities (there is no reward entity type,
#     and this story does not add one). A reward marked `optional` is "behind danger" (see
#     _reward_behind_danger). The standalone reward-table + concrete loot CONTENT (FR52) is DEFERRED to
#     Epic 6 (see Story 3.5.5).
#
# WHAT THIS STORY DOES NOT DO (scope guards):
#   - A RewardTableDefinition / RewardTableRepository or concrete loot contents -> Epic 6.
#   - A new TacticalEntityState.EntityType (rewards are markers, not entities).
#   - Enemy AI / enemy turns / hazard damage / combat / any rules-kernel behavior — placement only
#     positions the enemies as domain entities; behaviors are Epic 1 systems NOT invoked by generation.
#   - The full validator + bounded retry (Story 3.6) — the reward-reachability check here is the
#     focused AC2 check only and will likely be subsumed by 3.6's comprehensive validator.
#   - The player / hero entity (Epic 4 run/level-entry flow places it, NOT generation).
#
# AC3 DETERMINISM CONTRACT (identical in spirit to the blocker + wrinkle draws): every placement-
# affecting random choice (enemy count, enemy positions, enemy kinds, reward count, reward positions)
# is drawn through GenerationRequest.draw_layout_int, which routes EXCLUSIVELY through
# RngStreamSet.STREAM_LEVEL. NEVER randi()/randf(), NEVER a RandomNumberGenerator, NEVER another
# stream — the `rewards`/`loot` streams are reserved for RUNTIME reward/loot RESOLUTION (Epic 6+), NOT
# level-generation placement (see the RNG Stream Contract in the story). The placement draws are
# APPENDED AFTER the generator's existing blocker + wrinkle draws in a FIXED, documented order so the
# existing terrain behaviour is preserved and the terrain seed-regression fingerprints stay stable.
#
# FIXED PLACEMENT DRAW ORDER (appended after blocker count/positions + wrinkle kinds/positions):
#   5. enemy_count       : one draw_layout_int over [enemy_budget_min .. enemy_budget_max] (clamped to
#                          the remaining candidate count). Drawn even when the band collapses to a single
#                          value so the stream advances identically across recipes (mirrors blocker count).
#   6/7. enemy placement : for each of the drawn enemy_count enemies, INTERLEAVED in a fixed order — first
#                          an enemy_position draw (draw_layout_int over the *current* candidate list index;
#                          rejection-free shrinking pool shared with the blockers + wrinkles so an enemy
#                          never collides with a blocker, wrinkle, or another enemy), then an enemy_kind
#                          draw (draw_layout_int over [0 .. placement_definitions.size()-1] selecting an
#                          enemy kind from the canonical PLACEMENT_ENEMY_ORDER, with replacement).
#   8. reward_count      : one draw_layout_int over [reward_count_min .. reward_count_max] (clamped to the
#                          remaining candidate count after enemies are removed).
#   9. reward_position   : reward_count draws, each a draw_layout_int over the *current* candidate list
#                          index (the shrinking pool the enemies left), so a reward never collides with an
#                          enemy, blocker, wrinkle, entrance, or exit.
#
# CORRIDOR/ENTRANCE/EXIT/HAZARD SAFETY (AC1): enemy + reward cells are drawn from the SAME candidate
# pool the blockers + wrinkles use, which already excludes the reserved central corridor row + the
# entrance + the exit + every WALL. A HAZARD cell IS occupiable (walkable + sight-transparent — only
# WALL blocks), so an enemy or reward MAY legally sit on/adjacent to one — this is exactly what makes a
# "reward behind danger" expressible.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")

# Placed enemies share a single non-player faction. Generation does not model faction politics; the
# labyrinth's enemies are one hostile side (the player/hero faction is placed by the run flow, Epic 4).
const ENEMY_FACTION := &"labyrinth"

# Canonical enemy-id order used for deterministic kind selection. The recipe carries an enemy BUDGET
# (count band), not an enemy allowlist, so the placeable kinds are the repository's enemy ids resolved
# in THIS fixed order (registration-order-independent, mirroring TacticalWrinklePlacer.REALIZABLE_KINDS).
# These ids match EnemyRepository.BASELINE_ENEMY_IDS; any id missing from the repository is skipped so
# a custom repository with a subset still places deterministically.
const PLACEMENT_ENEMY_ORDER: Array[StringName] = [
	&"iron_cultist",
	&"gate_brute",
	&"ash_seer"
]

# Fixed 4-neighbour offsets, iterated in this order for the deterministic reward-reachability flood
# fill. Matches the generators' NEIGHBOUR_OFFSETS order so reachability is consistent across the
# codebase.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]


# Resolve the placeable enemy definitions THROUGH the repository boundary (AC3 — never a raw file read
# or a hardcoded enemy list), in the canonical PLACEMENT_ENEMY_ORDER. A null/empty repository (or a
# repository missing every canonical id) is a structured error rather than a crash or a silent
# no-placement when the budget is > 0. Returns ActionResult.ok([], {"definitions": [EnemyDefinition...]})
# when at least one canonical enemy resolves.
static func resolve_placement_definitions(enemy_repository: EnemyRepository) -> ActionResult:
	if enemy_repository == null:
		return ActionResult.error(&"missing_enemy_repository", {
			"reason": "enemy_repository_required_for_placement"
		})
	var definitions: Array[EnemyDefinition] = []
	for enemy_id: StringName in PLACEMENT_ENEMY_ORDER:
		if enemy_repository.has_enemy(enemy_id):
			var definition: EnemyDefinition = enemy_repository.get_enemy(enemy_id)
			if definition != null:
				definitions.append(definition)
	if definitions.is_empty():
		return ActionResult.error(&"no_placeable_enemy", {
			"reason": "enemy_repository_has_no_canonical_enemy"
		})
	return ActionResult.ok([], {"definitions": definitions})


# Place the enemies deterministically and return a structured ActionResult.
#
# On success: ActionResult.ok([], {"enemies": [<entity dict>, ...], "remaining_pool": [Vector2i...]})
# where each enemy dict is the EXACT TacticalEntityState.to_dictionary() shape (entity_type id string
# "enemy", position {x,y}, etc.) in placement order, and remaining_pool is the candidate pool AFTER the
# placed enemy cells were removed (so the reward step draws from the SAME shrinking set). `consumer_prefix`
# namespaces the RNG draw context (e.g. "small_layout" / "medium_layout") without changing draw values.
#
# `candidate_pool` is the blocker+wrinkle candidate list AFTER the blockers AND wrinkles have been
# removed; it is duplicated internally so the caller's pool is not mutated. `definitions` is the
# canonical-order placeable enemy list from resolve_placement_definitions.
#
# Behaviour:
#   - enemy_budget_max <= 0 places NO enemies and draws NOTHING (the placement draws are skipped so the
#     stream advances identically for a no-enemy recipe), returning an empty enemy list + the pool intact.
#   - The count is drawn over [enemy_budget_min .. enemy_budget_max] CLAMPED to the candidate count
#     (mirrors the blocker-count clamp), so the budget can never exceed available cells.
#   - If the pool empties before the drawn count is reached (degenerate tiny board), it places as many
#     as it can and stops; the caller's per-recipe count assertion (>= budget_min) is the tripwire. For
#     the baseline 8x8/14x12 boards the pool is far larger than the budget, so this never binds.
static func place_enemies(
	request: GenerationRequest,
	streams: RngStreamSet,
	recipe: LevelRecipeDefinition,
	definitions: Array,
	candidate_pool: Array[Vector2i],
	consumer_prefix: String
) -> ActionResult:
	var pool: Array[Vector2i] = candidate_pool.duplicate()
	if recipe.enemy_budget_max <= 0 or definitions.is_empty():
		return ActionResult.ok([], {"enemies": [], "remaining_pool": pool})

	# FIXED PLACEMENT DRAW #5: enemy count over the budget band, clamped to the candidate count.
	var minimum: int = max(0, recipe.enemy_budget_min)
	var maximum: int = recipe.enemy_budget_max
	maximum = min(maximum, pool.size())
	minimum = min(minimum, maximum)
	var count_draw: ActionResult = request.draw_layout_int(streams, minimum, maximum, {
		"consumer": "%s_enemy_count" % consumer_prefix
	})
	if count_draw.is_error():
		return count_draw
	var enemy_count: int = int(count_draw.metadata.get("value"))

	var placed: Array[Dictionary] = []
	for selection_index: int in range(enemy_count):
		if pool.is_empty():
			break

		# FIXED PLACEMENT DRAW #6: select a cell from the shared shrinking pool (no collisions).
		var cell_draw: ActionResult = request.draw_layout_int(streams, 0, pool.size() - 1, {
			"consumer": "%s_enemy_position" % consumer_prefix,
			"selection_index": selection_index
		})
		if cell_draw.is_error():
			return cell_draw
		var picked_index: int = int(cell_draw.metadata.get("value"))
		var cell: Vector2i = pool[picked_index]
		pool.remove_at(picked_index)

		# FIXED PLACEMENT DRAW #7: select an enemy kind from the canonical order (with replacement).
		var kind_draw: ActionResult = request.draw_layout_int(streams, 0, definitions.size() - 1, {
			"consumer": "%s_enemy_kind" % consumer_prefix,
			"selection_index": selection_index
		})
		if kind_draw.is_error():
			return kind_draw
		var definition: EnemyDefinition = definitions[int(kind_draw.metadata.get("value"))]

		placed.append(_entity_dictionary(selection_index, definition, cell))

	return ActionResult.ok([], {"enemies": placed, "remaining_pool": pool})


# Place the intended reward markers deterministically and return a structured ActionResult.
#
# On success: ActionResult.ok([], {"rewards": [{x, y, optional}, ...], "optional_count": int}) in
# placement order. Rewards are PAYLOAD MARKERS (NOT board entities). `candidate_pool` is the pool AFTER
# the enemies were removed; it is duplicated internally. `terrain_grid` is the row-major terrain (read
# only) used to compute the behind-danger flag. `allow_reward_behind_danger` gates whether a reward MAY
# be placed behind danger: when false (e.g. Small), a candidate cell that is behind danger is SKIPPED
# (drawn but not placed) so no mandatory reward is stranded near an unavoidable hazard.
#
# Behaviour:
#   - reward_count_max <= 0 places NO rewards and draws NOTHING (a Small level MAY place zero rewards —
#     that is valid), returning an empty list.
#   - The count is drawn over [reward_count_min .. reward_count_max] CLAMPED to the candidate count.
#   - A reward is `optional = true` IFF it is behind danger (the cell itself or any 4-neighbour is
#     HAZARD terrain — see _reward_behind_danger). `optional` does NOT make a reward unreachable; the
#     caller's reward-reachability validator asserts every placed reward is reachable.
static func place_rewards(
	request: GenerationRequest,
	streams: RngStreamSet,
	recipe: LevelRecipeDefinition,
	candidate_pool: Array[Vector2i],
	terrain_grid: Array,
	consumer_prefix: String
) -> ActionResult:
	var pool: Array[Vector2i] = candidate_pool.duplicate()
	if recipe.reward_count_max <= 0:
		return ActionResult.ok([], {"rewards": [], "optional_count": 0})

	# FIXED PLACEMENT DRAW #8: reward count over the band, clamped to the candidate count.
	var minimum: int = max(0, recipe.reward_count_min)
	var maximum: int = recipe.reward_count_max
	maximum = min(maximum, pool.size())
	minimum = min(minimum, maximum)
	var count_draw: ActionResult = request.draw_layout_int(streams, minimum, maximum, {
		"consumer": "%s_reward_count" % consumer_prefix
	})
	if count_draw.is_error():
		return count_draw
	var reward_count: int = int(count_draw.metadata.get("value"))

	var placed: Array[Dictionary] = []
	var optional_count: int = 0
	for selection_index: int in range(reward_count):
		if pool.is_empty():
			break

		# FIXED PLACEMENT DRAW #9: select a cell from the shared shrinking pool (no collisions).
		var cell_draw: ActionResult = request.draw_layout_int(streams, 0, pool.size() - 1, {
			"consumer": "%s_reward_position" % consumer_prefix,
			"selection_index": selection_index
		})
		if cell_draw.is_error():
			return cell_draw
		var picked_index: int = int(cell_draw.metadata.get("value"))
		var cell: Vector2i = pool[picked_index]
		pool.remove_at(picked_index)

		var behind_danger: bool = _reward_behind_danger(terrain_grid, cell)
		# When the recipe forbids behind-danger rewards (Small), do NOT place a reward behind danger —
		# skip the drawn cell rather than place a mandatory reward near an unavoidable hazard. The draw
		# still advanced (FIXED draw order preserved), but no marker is emitted for this slot.
		if behind_danger and not recipe.allow_reward_behind_danger:
			continue

		if behind_danger:
			optional_count += 1
		placed.append({
			"x": cell.x,
			"y": cell.y,
			"optional": behind_danger
		})

	return ActionResult.ok([], {"rewards": placed, "optional_count": optional_count})


# AC2 REWARD-REACHABILITY VALIDATION — a focused, separately-named check (NOT the 3.6 comprehensive
# validator). Runs a 4-neighbour flood fill from the entrance over non-WALL cells and asserts EVERY
# intended reward cell is in the reachable set. A reachable reward PASSES; an UNREACHABLE intended
# reward FAILS with a structured error (`unreachable_reward`) carrying COMPACT diagnostics (the
# offending reward coordinate + the reachable-cell count) — never a full grid dump. Pure query over the
# terrain grid: draws NO RNG and mutates nothing.
#
# Because generated rewards are drawn from the corridor-respecting remaining pool, they are reachable by
# construction; the FAILURE path is reachable today only via a hand-built malformed candidate (mirror
# the Medium AC2 hand-built-candidate test pattern).
static func validate_reward_reachability(layout: Dictionary, rewards: Array) -> ActionResult:
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var terrain_grid: Array = layout.get("terrain", [])
	var entrance: Vector2i = _cell_from_dict(layout.get("entrance", {}))

	if width <= 0 or height <= 0 or terrain_grid.size() != height:
		return ActionResult.error(&"invalid_layout_shape", {
			"width": width,
			"height": height,
			"terrain_rows": terrain_grid.size()
		})
	for y: int in range(height):
		var shape_row: Array = terrain_grid[y]
		if shape_row.size() != width:
			return ActionResult.error(&"invalid_layout_shape", {
				"width": width,
				"height": height,
				"row_index": y,
				"row_width": shape_row.size()
			})

	var reachable: Dictionary = _flood_reachable(width, height, terrain_grid, entrance)
	for reward_value: Variant in rewards:
		var reward: Dictionary = reward_value
		var cell: Vector2i = Vector2i(int(reward.get("x")), int(reward.get("y")))
		if not reachable.has(cell):
			return ActionResult.error(&"unreachable_reward", {
				"reason": "reward_not_reachable_from_entrance",
				"reward": {"x": cell.x, "y": cell.y},
				"entrance": {"x": entrance.x, "y": entrance.y},
				"reachable_cell_count": reachable.size()
			})

	return ActionResult.ok([], {
		"reward_count": rewards.size(),
		"reachable_cell_count": reachable.size()
	})


# Build the EXACT TacticalEntityState.to_dictionary() shape for a placed enemy. A stable deterministic
# entity_id (enemy_0, enemy_1, ... in placement order), the shared non-player faction, full HP from the
# definition, blocks_movement from the definition, definition_id = the enemy id (lower-snake). The dict
# is validated by BoardState.try_from_snapshot when the board is built (validate-then-reject). NOTE: the
# board snapshot's OCCUPANT INVARIANT (cell occupant_id ⟷ blocking entity cross-consistency) is handled
# by the generator's build_board_snapshot, which sets the matching occupant_id on each blocking enemy's
# CELL — this placer only emits the entity dicts.
static func _entity_dictionary(selection_index: int, definition: EnemyDefinition, cell: Vector2i) -> Dictionary:
	return {
		"entity_id": "enemy_%d" % selection_index,
		"entity_type": String(TacticalEntityState.ENTITY_TYPE_ENEMY),
		"faction": String(ENEMY_FACTION),
		"position": {"x": cell.x, "y": cell.y},
		"current_hp": definition.max_hp,
		"max_hp": definition.max_hp,
		"blocks_movement": definition.blocks_movement,
		"definition_id": String(definition.enemy_id)
	}


# BEHIND-DANGER PREDICATE (v0, documented): a reward cell is "behind danger" IFF the cell itself OR any
# of its 4-neighbours is HAZARD terrain. HAZARD is the only v0 danger terrain (walkable + sight-
# transparent), so a reward adjacent to a hazard pocket is the expressible "guarded/skippable" reward.
# This does NOT consider enemies (enemy proximity is a 3.6+ concern); v0 keys danger off HAZARD terrain.
static func _reward_behind_danger(terrain_grid: Array, cell: Vector2i) -> bool:
	if _terrain_at(terrain_grid, cell) == BoardCell.Terrain.HAZARD:
		return true
	for offset: Vector2i in NEIGHBOUR_OFFSETS:
		var neighbour: Vector2i = cell + offset
		if _in_grid(terrain_grid, neighbour) and _terrain_at(terrain_grid, neighbour) == BoardCell.Terrain.HAZARD:
			return true
	return false


# Deterministic 4-neighbour flood fill from `origin` over non-WALL cells. Returns a Dictionary used as a
# visited set (Vector2i -> true). Pure query: no RNG, no mutation. If the origin is a WALL or out of
# bounds, the result is empty. Mirrors MediumLevelLayoutGenerator._flood_reachable so reward
# reachability uses the same walkability model (only WALL blocks).
static func _flood_reachable(width: int, height: int, terrain_grid: Array, origin: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not _position_in_dimensions(width, height, origin) or _is_wall(terrain_grid, origin):
		return visited

	var frontier: Array[Vector2i] = [origin]
	visited[origin] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if not _position_in_dimensions(width, height, neighbour):
				continue
			if visited.has(neighbour):
				continue
			if _is_wall(terrain_grid, neighbour):
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited


static func _terrain_at(terrain_grid: Array, cell: Vector2i) -> int:
	var row: Array = terrain_grid[cell.y]
	return int(row[cell.x])


static func _is_wall(terrain_grid: Array, cell: Vector2i) -> bool:
	return _terrain_at(terrain_grid, cell) == BoardCell.Terrain.WALL


static func _in_grid(terrain_grid: Array, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= terrain_grid.size():
		return false
	var row: Array = terrain_grid[cell.y]
	return cell.x >= 0 and cell.x < row.size()


static func _position_in_dimensions(width: int, height: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


static func _cell_from_dict(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x", -1)), int(data.get("y", -1)))
