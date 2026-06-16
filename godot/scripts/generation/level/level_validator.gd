class_name LevelValidator
extends RefCounted

# Comprehensive deterministic level validator (Epic 3, Story 3.6) — the validation/safety capstone of
# the generation pipeline. Checks a BUILT candidate (the layout dict + the validated BoardState + the
# `rewards` marker list) against every FR36 / Story-3.6 fairness constraint and emits a structured
# pass/fail REPORT. It is the COMPREHENSIVE SUPERSET that subsumes + strengthens the two focused
# checks already in place:
#   - MediumLevelLayoutGenerator.validate_readability (excessive_blockage / unreachable_exit /
#     unreadable_first_reveal) — REUSED for the readability subset; its codes/diagnostics are unchanged
#     and still test-pinned (3.3). LevelValidator calls it directly for the readability + first-reveal
#     subset rather than forking the BFS, so there is ONE canonical readability bound.
#   - EntityRewardPlacer.validate_reward_reachability (TERRAIN-only reward reachability) — STRENGTHENED
#     here to be ENTITY-AWARE for MANDATORY rewards (closing the 3.5 Round-2 terrain-only Low). The
#     placer's terrain-only check stays in place (test-pinned, 3.5); the validator adds the entity-aware
#     pass on top.
#
# PURE QUERY (the validate_readability precedent): LevelValidator reads the layout + BoardState + rewards
# and returns a report. It draws NO RNG (never advances any stream), executes NO commands, applies NO
# events, and mutates neither the board nor the source state. Wiring it into the LevelGenerator success
# path must keep the `_layout_draws_only_from_level_stream` assertions GREEN. [project-context.md
# "snapshots/validation are pure reads"; NFR14]
#
# SEPARATE NAMED CHECKS, FIRST-FAILURE SHORT-CIRCUIT, COMPACT DIAGNOSTICS: each check is a private method
# returning a stable lower-snake code on failure with COMPACT diagnostics (counts / coordinates / ratios
# — NEVER a full grid dump, mirroring validate_readability). The checks run in a FIXED, documented order
# (see CHECK_ORDER below); the FIRST failure short-circuits and is the reported failure. On PASS the
# report carries compact counts (reachable count, interior-wall count, first-reveal count, entity/reward
# counts checked).
#
# SIZE-AGNOSTIC: the SAME checks run for Small and Medium candidates. Small had no validator of its own
# before 3.6 (it relied on the construction guarantee + the placer's reward-reachability); 3.6 gives both
# sizes the full pass. The approved Small (8x8) + Medium (14x12) seeds PASS by construction; the FAIL
# branches are driven by hand-built candidates.
#
# THE CHECK SET (each a stable code; the FIXED order short-circuits on the first failure). The order runs
# the cheap terrain reachability first, THEN placement legality (a precondition for the entity-aware
# solvability), THEN the entity-aware soft-lock, THEN gates/rewards/readability/first-reveal:
#   (a) unreachable_exit          — entrance->exit 4-neighbour TERRAIN flood over non-WALL cells (reuses
#                                    the SAME walkability model as validate_readability). [PHASE_PATHING]
#   (b) illegal_enemy_placement   — every entity on a legal occupiable non-entrance/exit cell, no two
#                                    blocking entities share a cell, every enemy cell entrance-reachable
#                                    (entity-aware). RE-ASSERTS at the validation layer what
#                                    try_from_snapshot enforces at build time + adds entrance-reachability
#                                    + entrance/exit exclusion. Runs BEFORE the entity-aware soft-lock so an
#                                    enemy standing ON the exit is reported as the (root-cause) illegal
#                                    placement, not as a downstream soft-lock. [PHASE_ENEMIES]
#   (c) soft_lock_detected        — ENTITY-AWARE: the exit must be reachable AROUND blocking entities
#                                    (flood over non-WALL AND non-blocking-entity cells). Movement is
#                                    symmetric over walkable cells, so "can't get back" is not a separate
#                                    v0 case; the soft-lock guard is "the exit is sealed off by terrain OR
#                                    legally-placed blocking entities." [PHASE_PATHING]
#   (d) required_gate_present     — v0 generation realizes NO class/item/keyed gate (door /
#                                    affinity_placeholder / risky_side_branch are NOT realized through
#                                    3.5), so this PASSES by construction; it FAILS only if a synthetic
#                                    gate marker sits on the mandatory path. FORWARD GUARDRAIL (hand-built
#                                    candidate-driven), not dead code. [PHASE_PATHING; FR36]
#   (e) unreachable_reward        — every MANDATORY reward (optional == false) ENTITY-AWARE reachable;
#                                    every OPTIONAL (behind-danger) reward TERRAIN-reachable (may sit by a
#                                    hazard but must not be sealed). STRENGTHENS the placer's terrain-only
#                                    check. [PHASE_VALIDATION — keeps the 3.5 unreachable_reward mapping]
#   (f) excessive_blockage        — REUSE validate_readability's interior-WALL-ratio bound (0.35).
#                                    [PHASE_VALIDATION]
#   (g) unreadable_first_reveal   — REUSE validate_readability's first-reveal bounded flood (radius 4,
#                                    min cells). [PHASE_VALIDATION]
#   (h) unsafe_first_reveal       — the entrance cell is NOT HAZARD AND no entity occupies the entrance
#                                    cell (the player is not spawned ON a hazard or ON an enemy). v0 STATIC
#                                    check (no simulated turns / hazard detonation). SAFE-FIRST-REVEAL v0
#                                    SEMANTIC (documented decision, NOT a silent weakening): an enemy or
#                                    hazard merely ADJACENT to the entrance is PERMITTED, because the
#                                    baseline LoS radius (4, FR5) reveals the entrance's full neighbourhood
#                                    on spawn — an adjacent threat is SEEN and engaged by choice, which is
#                                    fair (FR58 protects against damage from UNSEEN space, not from a
#                                    visible adjacent enemy). The baseline generator legitimately places
#                                    enemies adjacent to the entrance (the enemy pool excludes only the
#                                    entrance/exit/corridor, not adjacent cells), and the entrance cell
#                                    itself is excluded from BOTH the wrinkle pool (so it is never HAZARD)
#                                    and the enemy pool (so it is never occupied) — so the approved Small +
#                                    Medium seeds PASS by construction. A Chebyshev<=1 enemy guard was
#                                    REJECTED because it would fail legitimately-fair baseline candidates
#                                    and (worse) force the bounded retry to re-roll attempt 0, drifting the
#                                    pinned terrain fingerprints. The unavoidable-damage cases this check
#                                    actually catches: spawning ON a hazard (forced turn-1 damage) or ON an
#                                    enemy (illegal overlap). [PHASE_VALIDATION; FR5; FR58]
#
# PHASE MAPPING (AC4 — distinct phases where the architecture provides them; documented here, asserted by
# test_generation_phase_fixtures.gd): reachability + soft-lock + the no-gate guardrail report
# PHASE_PATHING (the now-available constant); illegal enemy placement reports PHASE_ENEMIES; reward
# reachability + readability + first-reveal report PHASE_VALIDATION (consistent with the existing Medium
# readability mapping AND the 3.5 `unreachable_reward -> PHASE_VALIDATION` deferred-Low contract). The
# LevelGenerator maps each check's code onto the phase via phase_for_code().
#
# SCOPE GUARDS (do NOT build here): no RewardTableDefinition/loot content (Epic 6); no new
# TacticalEntityState.EntityType; no placed player/hero entity (Epic 4 — "safe first reveal" is validated
# against the ENTRANCE cell + its LoS neighbourhood, NOT a placed hero); no realized
# door/affinity_placeholder/risky_side_branch wrinkles; no enemy AI / turns / hazard damage / combat /
# rules-kernel behavior (static proximity/terrain checks only); no real affinity rules (Epic 7); no
# manual-seed/batch CLI (3.7); no new RNG stream / result type / board parser / snapshot format.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")

# Stable check codes (lower-snake, mirroring the focused validators). Each is the error_code a failing
# check returns; the LevelGenerator maps it onto a GenerationResult phase via phase_for_code().
const CODE_UNREACHABLE_EXIT := &"unreachable_exit"
const CODE_SOFT_LOCK_DETECTED := &"soft_lock_detected"
const CODE_REQUIRED_GATE_PRESENT := &"required_gate_present"
const CODE_ILLEGAL_ENEMY_PLACEMENT := &"illegal_enemy_placement"
const CODE_UNREACHABLE_REWARD := &"unreachable_reward"
const CODE_EXCESSIVE_BLOCKAGE := &"excessive_blockage"
const CODE_UNREADABLE_FIRST_REVEAL := &"unreadable_first_reveal"
const CODE_UNSAFE_FIRST_REVEAL := &"unsafe_first_reveal"
const CODE_INVALID_CANDIDATE := &"invalid_candidate"

# v0 baseline line-of-sight radius (FR5). Documents the LoS bound the SAFE-FIRST-REVEAL v0 semantic is
# reasoned against: a threat within this radius of the entrance is SEEN on first reveal, so an adjacent
# enemy/hazard is fair (only spawning ON a hazard/enemy is unsafe — see _check_safe_first_reveal). The
# readability first-reveal FLOOD (check g) is delegated to the Medium generator's own FIRST_REVEAL_RADIUS,
# so this constant is the documented reference value, not a second flood bound.
const FIRST_REVEAL_RADIUS: int = 4

# Fixed 4-neighbour offsets, iterated in this order for the deterministic (terrain + entity-aware)
# floods. Matches the generators' + placer's NEIGHBOUR_OFFSETS so reachability is consistent across the
# codebase.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

# The check codes in the FIXED order they run (documented; the first failure short-circuits). Exposed so
# tests can assert the ordering contract without re-reading the method body. Placement legality (b) runs
# before the entity-aware soft-lock (c) so an enemy on the exit is reported as illegal placement, not a
# downstream soft-lock.
static func check_order() -> Array[StringName]:
	return [
		CODE_UNREACHABLE_EXIT,
		CODE_ILLEGAL_ENEMY_PLACEMENT,
		CODE_SOFT_LOCK_DETECTED,
		CODE_REQUIRED_GATE_PRESENT,
		CODE_UNREACHABLE_REWARD,
		CODE_EXCESSIVE_BLOCKAGE,
		CODE_UNREADABLE_FIRST_REVEAL,
		CODE_UNSAFE_FIRST_REVEAL
	]


# Map a failing check's stable code onto the GenerationResult phase it should report (AC4 distinct
# phases). Reachability / soft-lock / no-gate -> pathing; illegal enemy placement -> enemies; reward
# reachability + readability + first-reveal -> validation. The LevelGenerator calls this when mapping a
# validator failure onto a GenerationResult.error. Returns the lower-snake phase value (matching the
# GenerationResult PHASE_* constants) — kept as a plain StringName so this RefCounted does not depend on
# the GenerationResult class.
static func phase_for_code(code: StringName) -> StringName:
	match code:
		CODE_UNREACHABLE_EXIT, CODE_SOFT_LOCK_DETECTED, CODE_REQUIRED_GATE_PRESENT:
			return &"pathing"
		CODE_ILLEGAL_ENEMY_PLACEMENT:
			return &"enemies"
		_:
			# unreachable_reward / excessive_blockage / unreadable_first_reveal / unsafe_first_reveal +
			# any structural invalid_candidate report against validation (consistent with the Medium
			# readability mapping + the 3.5 unreachable_reward -> PHASE_VALIDATION contract).
			return &"validation"


# Validate a built candidate. `candidate` carries:
#   - "layout"  : the layout dict (width/height/entrance/exit/terrain[+blockers/wrinkles/rewards]) — the
#                 SAME dict the generators emit + validate_readability consumes.
#   - "board"   : the validated BoardState (from build_board_snapshot) — the entity-aware source of truth.
#   - "rewards" : the reward marker list ({x, y, optional}) — the layout's `rewards` (passed explicitly so
#                 the validator does not assume where the caller stored it).
# Returns ActionResult.ok([], {<compact pass report>}) on PASS, or ActionResult.error(<check_code>,
# {<compact diagnostics>}) on the FIRST failing check. Pure: draws no RNG, mutates nothing.
func validate(candidate: Dictionary) -> ActionResult:
	var layout: Dictionary = candidate.get("layout", {})
	var board: BoardState = candidate.get("board") as BoardState
	var rewards: Array = candidate.get("rewards", [])

	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var terrain_grid: Array = layout.get("terrain", [])
	var entrance: Vector2i = _cell_from_dict(layout.get("entrance", {}))
	var exit_cell: Vector2i = _cell_from_dict(layout.get("exit", {}))

	# Structural pre-guard (mirrors validate_readability's leading shape guard). A malformed candidate is
	# rejected with a structured invalid_candidate rather than indexing out of bounds. The BoardState is
	# required (the entity-aware checks read it).
	if board == null:
		return ActionResult.error(CODE_INVALID_CANDIDATE, {"reason": "missing_board"})
	if width <= 0 or height <= 0 or terrain_grid.size() != height:
		return ActionResult.error(CODE_INVALID_CANDIDATE, {
			"reason": "invalid_layout_shape",
			"width": width,
			"height": height,
			"terrain_rows": terrain_grid.size()
		})
	for y: int in range(height):
		var shape_row: Array = terrain_grid[y]
		if shape_row.size() != width:
			return ActionResult.error(CODE_INVALID_CANDIDATE, {
				"reason": "invalid_layout_shape",
				"width": width,
				"height": height,
				"row_index": y,
				"row_width": shape_row.size()
			})

	# Precompute the two floods used by the checks below (deterministic, pure). The terrain flood matches
	# validate_readability's walkability (only WALL blocks); the entity-aware flood additionally treats a
	# cell occupied by a blocking entity as non-traversable (the entrance origin is always traversable).
	var terrain_reachable: Dictionary = _flood_terrain(width, height, terrain_grid, entrance)
	var entity_reachable: Dictionary = _flood_entity_aware(width, height, terrain_grid, board, entrance)

	# CHECK (a) unreachable_exit — entrance->exit over non-WALL terrain.
	if not terrain_reachable.has(exit_cell):
		return ActionResult.error(CODE_UNREACHABLE_EXIT, {
			"reason": "exit_not_reachable_from_entrance",
			"entrance": {"x": entrance.x, "y": entrance.y},
			"exit": {"x": exit_cell.x, "y": exit_cell.y},
			"reachable_cell_count": terrain_reachable.size()
		})

	# CHECK (b) illegal_enemy_placement — entity legality + entrance-reachability (entity-aware). Runs
	# BEFORE the entity-aware soft-lock so an enemy ON the exit is reported as the root-cause illegal
	# placement rather than a downstream soft-lock.
	var placement_check: ActionResult = _check_legal_enemy_placement(width, height, terrain_grid, board, entrance, exit_cell, entity_reachable)
	if placement_check.is_error():
		return placement_check

	# CHECK (c) soft_lock_detected — the exit must be reachable AROUND (legally-placed) blocking entities
	# (entity-aware).
	if not entity_reachable.has(exit_cell):
		return ActionResult.error(CODE_SOFT_LOCK_DETECTED, {
			"reason": "exit_sealed_by_blocking_entities",
			"entrance": {"x": entrance.x, "y": entrance.y},
			"exit": {"x": exit_cell.x, "y": exit_cell.y},
			"entity_reachable_cell_count": entity_reachable.size()
		})

	# CHECK (d) required_gate_present — forward guardrail. v0 has no realized gates, so this PASSES unless
	# a synthetic gate marker sits on the entity-aware mandatory path (entrance-reachable region).
	var gate_check: ActionResult = _check_no_required_gate(layout, entity_reachable)
	if gate_check.is_error():
		return gate_check

	# CHECK (e) unreachable_reward — mandatory rewards entity-aware reachable; optional rewards terrain-
	# reachable (not sealed). STRENGTHENS the placer's terrain-only check.
	var reward_check: ActionResult = _check_reachable_rewards(rewards, terrain_reachable, entity_reachable)
	if reward_check.is_error():
		return reward_check

	# CHECKS (f) excessive_blockage + (g) unreadable_first_reveal — REUSE the Medium readability pass. The
	# Small generator has no validate_readability of its own, so the validator delegates to the Medium
	# generator's instance method (it is a pure terrain query — size-agnostic, works for an 8x8 grid too).
	var readability: ActionResult = MediumLevelLayoutGenerator.new().validate_readability(layout)
	if readability.is_error():
		return readability

	# CHECK (h) unsafe_first_reveal — STATIC v0 fairness: entrance not on HAZARD; no enemy Chebyshev <= 1.
	var first_reveal_check: ActionResult = _check_safe_first_reveal(terrain_grid, board, entrance)
	if first_reveal_check.is_error():
		return first_reveal_check

	# PASS — compact report (counts only, never a grid dump). Mirrors the validate_readability success
	# shape plus the entity-aware + reward + entity counts this comprehensive validator additionally
	# checked.
	return ActionResult.ok([], {
		"terrain_reachable_cell_count": terrain_reachable.size(),
		"entity_reachable_cell_count": entity_reachable.size(),
		"interior_wall_count": int(readability.metadata.get("interior_wall_count", 0)),
		"first_reveal_count": int(readability.metadata.get("first_reveal_count", 0)),
		"entity_count": board.entity_count(),
		"reward_count": rewards.size(),
		"mandatory_reward_count": _mandatory_reward_count(rewards)
	})


# CHECK (c): the candidate must contain no gate marker requiring a class/weapon/item to progress on the
# MANDATORY path. v0 generation realizes NO gates, so the only source of a gate today is a synthetic
# marker a test injects under layout["gates"] (a list of {x, y} cells). A gate that sits on an
# entrance-reachable (entity-aware) cell would block the mandatory path -> FAIL. A gate off the reachable
# region (or no gates at all) -> PASS. Documented as a FORWARD GUARDRAIL: it is exercised only by a
# hand-built candidate carrying a synthetic gate, mirroring the Medium hand-built-candidate pattern.
func _check_no_required_gate(layout: Dictionary, entity_reachable: Dictionary) -> ActionResult:
	var gates: Array = layout.get("gates", [])
	for gate_value: Variant in gates:
		var gate: Dictionary = gate_value
		var cell: Vector2i = Vector2i(int(gate.get("x")), int(gate.get("y")))
		if entity_reachable.has(cell):
			return ActionResult.error(CODE_REQUIRED_GATE_PRESENT, {
				"reason": "gate_on_mandatory_path",
				"gate": {"x": cell.x, "y": cell.y},
				"gate_kind": String(gate.get("kind", "unknown")),
				"gate_count": gates.size()
			})
	return ActionResult.ok()


# CHECK (d): every board entity must sit on a legal occupiable cell (not WALL, not the entrance, not the
# exit), no two blocking entities may share a cell, and every enemy cell must be entrance-reachable
# (entity-aware). BoardState.try_from_snapshot ALREADY enforces occupancy legality + dup-id + occupant
# cross-consistency at BUILD time, so this RE-ASSERTS placement legality at the validation layer
# (entrance/exit exclusion + entrance-reachability) — the layer the architecture validation phase owns.
# Reads entities via board.entities() (sorted copies) so it is deterministic and reads no stripped cell
# field.
func _check_legal_enemy_placement(width: int, height: int, terrain_grid: Array, board: BoardState, entrance: Vector2i, exit_cell: Vector2i, entity_reachable: Dictionary) -> ActionResult:
	var seen_blocking_cells: Dictionary = {}
	for entity: TacticalEntityState in board.entities():
		var cell: Vector2i = entity.position
		var entity_id: String = String(entity.entity_id)
		if not _position_in_dimensions(width, height, cell):
			return _illegal_placement("entity_out_of_bounds", entity_id, cell)
		if _terrain_at(terrain_grid, cell) == BoardCell.Terrain.WALL:
			return _illegal_placement("entity_on_wall", entity_id, cell)
		if cell == entrance:
			return _illegal_placement("entity_on_entrance", entity_id, cell)
		if cell == exit_cell:
			return _illegal_placement("entity_on_exit", entity_id, cell)
		if entity.blocks_movement:
			if seen_blocking_cells.has(cell):
				return _illegal_placement("blocking_entities_share_cell", entity_id, cell)
			seen_blocking_cells[cell] = true
		# Entrance-reachability: an enemy stranded behind a wall the player can never reach is an illegal
		# (unfair) placement. Entity-aware reachable excludes a cell occupied by a blocking entity, so the
		# enemy's OWN blocking cell is not in the set — check reachability via the cell's open 4-neighbours
		# instead (an enemy is "reachable" iff the player can stand adjacent to it).
		if not _cell_or_open_neighbour_reachable(width, height, terrain_grid, board, cell, entity_reachable):
			return _illegal_placement("entity_unreachable_from_entrance", entity_id, cell)
	return ActionResult.ok()


# CHECK (e): every MANDATORY reward (optional == false) must be ENTITY-AWARE reachable from the entrance;
# every OPTIONAL (behind-danger) reward must still be TERRAIN-reachable (it may sit adjacent to a hazard
# but must not be sealed off). This SUBSUMES + STRENGTHENS EntityRewardPlacer.validate_reward_reachability
# (terrain-only) by additionally accounting for blocking entities on the mandatory path.
func _check_reachable_rewards(rewards: Array, terrain_reachable: Dictionary, entity_reachable: Dictionary) -> ActionResult:
	for reward_value: Variant in rewards:
		var reward: Dictionary = reward_value
		var cell: Vector2i = Vector2i(int(reward.get("x")), int(reward.get("y")))
		var optional: bool = bool(reward.get("optional", false))
		if optional:
			# Optional/behind-danger reward: must not be sealed off by terrain (terrain-reachable), but is
			# allowed to be guarded (it may sit by a hazard, and a blocking enemy may stand between it and
			# the player — the player can choose to skip it).
			if not terrain_reachable.has(cell):
				return ActionResult.error(CODE_UNREACHABLE_REWARD, {
					"reason": "optional_reward_terrain_sealed",
					"reward": {"x": cell.x, "y": cell.y},
					"optional": true,
					"terrain_reachable_cell_count": terrain_reachable.size()
				})
		else:
			# Mandatory reward: must be reachable AROUND blocking entities (entity-aware), not merely over
			# open terrain.
			if not entity_reachable.has(cell):
				return ActionResult.error(CODE_UNREACHABLE_REWARD, {
					"reason": "mandatory_reward_not_reachable_from_entrance",
					"reward": {"x": cell.x, "y": cell.y},
					"optional": false,
					"entity_reachable_cell_count": entity_reachable.size()
				})
	return ActionResult.ok()


# CHECK (h): the player must not spawn ON an unavoidable-damage source (FR36 "safe first reveal" / FR58
# darkness fairness). v0 STATIC check (no simulated enemy turns / hazard detonation): the entrance cell
# itself must NOT be HAZARD terrain (forced turn-1 damage with no choice), and no entity may occupy the
# entrance cell (the player is not spawned ON an enemy). See the SAFE-FIRST-REVEAL v0 SEMANTIC note in the
# file header: a threat merely ADJACENT to the entrance is PERMITTED because the baseline LoS radius (4,
# FR5) reveals it on spawn (so it is SEEN and engaged by choice — FR58 protects against UNSEEN damage),
# and a Chebyshev<=1 guard would fail legitimate baseline candidates + force a fingerprint-drifting retry.
# The readability first-reveal flood (check g) separately enforces the entrance can orient within the LoS
# radius. The FIRST_REVEAL_RADIUS constant documents the v0 LoS radius this semantic is reasoned against.
func _check_safe_first_reveal(terrain_grid: Array, board: BoardState, entrance: Vector2i) -> ActionResult:
	if _terrain_at(terrain_grid, entrance) == BoardCell.Terrain.HAZARD:
		return ActionResult.error(CODE_UNSAFE_FIRST_REVEAL, {
			"reason": "entrance_on_hazard",
			"entrance": {"x": entrance.x, "y": entrance.y}
		})
	for entity: TacticalEntityState in board.entities():
		if entity.position == entrance:
			return ActionResult.error(CODE_UNSAFE_FIRST_REVEAL, {
				"reason": "entity_on_entrance",
				"entrance": {"x": entrance.x, "y": entrance.y},
				"entity_id": String(entity.entity_id),
				"entity_cell": {"x": entity.position.x, "y": entity.position.y}
			})
	return ActionResult.ok()


# An enemy cell is "reachable from the entrance" iff the player can stand on it (terrain-reachable around
# blocking entities) OR can stand on one of its open (non-WALL, non-blocking-entity) 4-neighbours. Because
# the entity-aware flood excludes a cell occupied by a blocking entity, a blocking enemy's own cell is
# never in the set; an enemy is fairly reachable iff an adjacent open cell is reachable.
func _cell_or_open_neighbour_reachable(width: int, height: int, terrain_grid: Array, board: BoardState, cell: Vector2i, entity_reachable: Dictionary) -> bool:
	if entity_reachable.has(cell):
		return true
	for offset: Vector2i in NEIGHBOUR_OFFSETS:
		var neighbour: Vector2i = cell + offset
		if entity_reachable.has(neighbour):
			return true
	return false


# Deterministic 4-neighbour TERRAIN flood from `origin` over non-WALL cells. Returns a visited set
# (Vector2i -> true). Pure query. IDENTICAL walkability to MediumLevelLayoutGenerator._flood_reachable /
# EntityRewardPlacer._flood_reachable (only WALL blocks) so terrain reachability is consistent everywhere.
func _flood_terrain(width: int, height: int, terrain_grid: Array, origin: Vector2i) -> Dictionary:
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


# Deterministic 4-neighbour ENTITY-AWARE flood from `origin`: a cell is traversable iff it is non-WALL
# AND not occupied by a `blocks_movement` entity. The `origin` (entrance) is always traversable even if it
# carries terrain (it is FLOOR/ENTRANCE by construction; a blocking entity on the entrance is rejected by
# the placement check anyway). Occupancy is read from the ENTITY list (board.entity_at / entities()),
# NOT a raw cell occupant_id field — try_from_snapshot STRIPS the cell occupant_id and re-derives it, so a
# raw cell read would be empty. Pure query. [retro-notes epic-3 Story 3-5 occupant-invariant CORRECTION]
func _flood_entity_aware(width: int, height: int, terrain_grid: Array, board: BoardState, origin: Vector2i) -> Dictionary:
	var blocked_by_entity: Dictionary = _blocking_entity_cells(board)
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
			if blocked_by_entity.has(neighbour):
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited


# The set of cells occupied by a blocking entity (Vector2i -> true), read from the entity list (the source
# of truth; the cell occupant_id is stripped by try_from_snapshot).
func _blocking_entity_cells(board: BoardState) -> Dictionary:
	var blocked: Dictionary = {}
	for entity: TacticalEntityState in board.entities():
		if entity.blocks_movement:
			blocked[entity.position] = true
	return blocked


func _mandatory_reward_count(rewards: Array) -> int:
	var count: int = 0
	for reward_value: Variant in rewards:
		if not bool((reward_value as Dictionary).get("optional", false)):
			count += 1
	return count


func _illegal_placement(reason: String, entity_id: String, cell: Vector2i) -> ActionResult:
	return ActionResult.error(CODE_ILLEGAL_ENEMY_PLACEMENT, {
		"reason": reason,
		"entity_id": entity_id,
		"cell": {"x": cell.x, "y": cell.y}
	})


static func _terrain_at(terrain_grid: Array, cell: Vector2i) -> int:
	var row: Array = terrain_grid[cell.y]
	return int(row[cell.x])


static func _is_wall(terrain_grid: Array, cell: Vector2i) -> bool:
	return _terrain_at(terrain_grid, cell) == BoardCell.Terrain.WALL


static func _position_in_dimensions(width: int, height: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


static func _cell_from_dict(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x", -1)), int(data.get("y", -1)))
