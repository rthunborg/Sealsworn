class_name BossBoardFixtureFactory
extends RefCounted

# Story 9.3 test fixtures — the LIVE Larval Avatar boss board. Builds the 9.1 arena (BossArenaBuilder), restores the
# board from its snapshot, instantiates the boss as a real TacticalEntityState at the reserved boss_slot (HP from the
# 9.2 BossDefinition — the definition supplies max_hp > 0, so the entity validates), and places the hero. This is the
# live-loop seam 9.3 fills: 9.1 shipped the arena with an EMPTY entities array + a boss_slot marker; 9.2 shipped the
# definition; 9.3 puts a live boss on the board. All boards are headless + deterministic (the arena draws ZERO RNG).
#
# The arena is a 12x12 walled room: boss_slot at (6,1) (top-center interior), entrance/player-start at (6,10)
# (bottom-center). Interior cells (1..10) are FLOOR. Fixtures place the hero where each test needs it.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossArenaBuilder = preload("res://scripts/generation/boss/boss_arena_builder.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const BossRepository = preload("res://scripts/content/repositories/boss_repository.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

const BOSS_ENTITY_ID := &"larval_avatar"


# The baseline Larval Avatar definition (the 9.2 content, read through the repository — NOT re-authored).
static func boss_definition() -> BossDefinition:
	return BossRepository.create_baseline_repository().get_boss(BOSS_ENTITY_ID)


# The reserved boss_slot cell from the 9.1 arena (top-center interior) — read from the ACTUAL built arena payload's
# boss_slot marker (not a duplicated constant), so the Task-8 cross-check asserts the live boss sits at the real
# reserved marker and a future arena-layout change to the slot can never silently desync the fixture from the arena.
static func boss_slot_cell() -> Vector2i:
	return _build_arena().get("boss_slot_cell", _boss_slot_cell())


# The entrance / player-start cell from the 9.1 arena (bottom-center interior).
static func entrance_cell() -> Vector2i:
	return _entrance_cell()


# The live boss board with the hero at the given cell and the boss at the current HP. `boss_current_hp < 0` means full
# HP (max_hp from the definition). The hero and boss are cardinally alignable along column 6 by default (both at x==6).
# The boss is placed at the arena's ACTUAL reserved boss_slot (read from the built payload, not a duplicated constant),
# so a future arena-layout change to the slot desyncs nothing and the Task-8 cross-check asserts the real marker.
static func boss_arena(hero_cell: Vector2i, boss_current_hp: int = -1) -> BoardState:
	var built: Dictionary = _build_arena()
	var board: BoardState = built.get("board") as BoardState
	var slot_cell: Vector2i = built.get("boss_slot_cell", _boss_slot_cell())
	var definition: BossDefinition = boss_definition()
	var resolved_hp: int = boss_current_hp
	if resolved_hp < 0:
		resolved_hp = definition.max_hp
	_place_boss(board, definition, resolved_hp, slot_cell)
	_place_hero(board, hero_cell)
	_reveal_all(board)
	return board


# The boss board with the hero placed WITHIN telegraph range + line of sight of the boss (directly below it in the same
# column), so a damaging ability telegraphs. Default HP is full (phase 0).
static func boss_arena_hero_in_range(boss_current_hp: int = -1) -> BoardState:
	# Boss at (6,1); hero at (6,4) — Manhattan distance 3 (<= TELEGRAPH_RANGE 6), same column (clear LoS down the arena).
	return boss_arena(Vector2i(6, 4), boss_current_hp)


# The boss board with the hero FAR from the boss (at the entrance), out of telegraph range, so the boss skitters
# (approaches) instead. Default HP is full (phase 0).
static func boss_arena_hero_far() -> BoardState:
	# Boss at (6,1); hero at the entrance (6,10) — Manhattan distance 9 (> TELEGRAPH_RANGE 6).
	return boss_arena(_entrance_cell(), -1)


# Build the 9.1 arena and return BOTH the restored board and the arena's ACTUAL reserved boss_slot cell (read from the
# built payload, not a duplicated constant — so the live boss is placed at the real marker the arena reserved).
static func _build_arena() -> Dictionary:
	var request: BossEncounterRequest = BossEncounterRequest.new(4242, &"node_boss_finale")
	var result: GenerationResult = BossArenaBuilder.new().build(request)
	if not result.succeeded:
		push_error("Boss arena fixture build failed: %s" % String(result.error_code))
		return {"board": BoardState.new(), "boss_slot_cell": _boss_slot_cell()}
	var board_snapshot: Dictionary = result.payload.get("board_snapshot", {})
	var board: BoardState = BoardState.from_snapshot(board_snapshot)
	if board == null:
		push_error("Boss arena fixture snapshot restore failed.")
		return {"board": BoardState.new(), "boss_slot_cell": _boss_slot_cell()}
	var slot: Dictionary = result.payload.get("boss_slot", {})
	var slot_cell: Vector2i = Vector2i(int(slot.get("x", _boss_slot_cell().x)), int(slot.get("y", _boss_slot_cell().y)))
	return {"board": board, "boss_slot_cell": slot_cell}


static func _place_boss(board: BoardState, definition: BossDefinition, current_hp: int, slot_cell: Vector2i) -> void:
	var boss: TacticalEntityState = TacticalEntityState.new(
		BOSS_ENTITY_ID,
		TacticalEntityState.EntityType.ENEMY,
		&"boss",
		slot_cell,
		current_hp,
		definition.max_hp,
		true,
		BOSS_ENTITY_ID
	)
	var result: ActionResult = board.place_entity_for_setup(boss)
	if result.is_error():
		push_error("Boss fixture placement failed: %s" % String(result.error_code))


static func _place_hero(board: BoardState, hero_cell: Vector2i) -> void:
	var hero: TacticalEntityState = TacticalEntityState.new(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		hero_cell,
		18,
		18,
		true,
		&"hero"
	)
	var result: ActionResult = board.place_entity_for_setup(hero)
	if result.is_error():
		push_error("Hero fixture placement failed: %s" % String(result.error_code))


static func _reveal_all(board: BoardState) -> void:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true


static func _boss_slot_cell() -> Vector2i:
	return Vector2i(BossArenaBuilder.ARENA_WIDTH / 2, 1)


static func _entrance_cell() -> Vector2i:
	return Vector2i(BossArenaBuilder.ARENA_WIDTH / 2, BossArenaBuilder.ARENA_HEIGHT - 2)
