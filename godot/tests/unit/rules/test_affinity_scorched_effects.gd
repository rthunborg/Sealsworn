extends "res://tests/unit/test_case.gd"

# Story 7.5 Task 2 — Scorched effects (AC1): hazard-cell placement + a DoT/hazard-damage RESOLUTION through the EXISTING
# DAMAGE_APPLIED event, explainable in previews + logs. These prove:
#   - STAMP: Scorched stamps fire-hazard cells as BoardCell.Terrain.HAZARD (NOT WALL) — they do NOT block movement/LOS
#     (the 3.4 contract: only WALL blocks occupancy/LOS; HAZARD is walkable + sight-transparent).
#   - FAIRNESS: a hazard is never stamped on a cell an entity occupies (no unavoidable damage at spawn — seen,
#     avoidable, fair by construction).
#   - DoT EVENT: an entity standing in a Scorched hazard cell takes the expected DAMAGE_APPLIED with correct HP
#     arithmetic (hp_before - final_damage == hp_after, floored at 0), via AffinityHazardDamageCommand.
#   - NO-MUTATION REJECT: an invalid effect target (no entity / entity not in a hazard cell / dead target) leaves the
#     board byte-identical + emits ZERO events.
#   - EXPLAINABILITY: the affected cells are previewable (AffinityPreviewQuery) + the hazard-damage event is logged
#     readably (CombatExplanationLog).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityHazardDamageCommand = preload("res://scripts/core/commands/affinity_hazard_damage_command.gd")
const AffinityPreviewQuery = preload("res://scripts/tactical/targeting/affinity_preview_query.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatExplanationLog = preload("res://scripts/tactical/outcomes/combat_explanation_log.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

func run() -> Dictionary:
	_scorched_stamps_hazard_terrain_not_wall()
	_hazard_terrain_does_not_block_movement_or_los()
	_hazard_is_never_stamped_on_an_occupied_cell()
	_entity_in_a_hazard_cell_takes_the_expected_damage_event()
	_hazard_damage_floors_hp_at_zero()
	_hazard_damage_rejects_an_entity_not_in_a_hazard_cell_with_no_mutation()
	_hazard_damage_rejects_a_missing_target_with_no_mutation()
	_hazard_damage_rejects_a_dead_target_with_no_mutation()
	_scorched_cells_are_previewable()
	_hazard_damage_event_is_logged_readably()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


func _floor_board(width: int = 5, height: int = 4) -> BoardState:
	var board: BoardState = BoardState.new()
	var create: ActionResult = CreateBoardCommand.new(width, height).execute(board)
	assert_true(create.succeeded, "Setup: the fixture board should create.")
	return board


func _place(board: BoardState, entity: TacticalEntityState) -> void:
	var place_result: ActionResult = board.place_entity_for_setup(entity)
	assert_true(place_result.succeeded, "Setup: entity placement should succeed: %s" % String(place_result.error_code))


func _player(entity_id: StringName, position: Vector2i, current_hp: int = 18) -> TacticalEntityState:
	return TacticalEntityState.new(entity_id, TacticalEntityState.EntityType.PLAYER, &"player", position, current_hp, 18, true)


func _scorched_board() -> BoardState:
	# A board with Scorched hazards stamped, a player STANDING IN a hazard cell (the realistic "entity ENTERED a hazard"
	# state — fairness stamps hazards on EMPTY cells, then a unit moves onto one), and an enemy on a non-hazard cell.
	var board: BoardState = _floor_board(5, 4)
	# Place the enemy at (1, 0): (1 + 0) odd -> NOT a hazard cell (used for the reject path).
	_place(board, _enemy_at(&"enemy_1", Vector2i(1, 0)))
	# Apply Scorched FIRST (stamps even-parity unoccupied cells, incl. (2,0) and (4,0)).
	var apply: ActionResult = AffinityEffectResolver.new().apply_board_effects(board, &"scorched", _repository())
	assert_true(apply.succeeded, "Setup: Scorched apply should succeed.")
	assert_equal(board.get_cell(Vector2i(2, 0)).terrain, BoardCell.Terrain.HAZARD, "Setup: (2,0) should be a stamped hazard cell.")
	# THEN place the hero ONTO a stamped hazard cell (2,0) — HAZARD is walkable, so an entity can occupy it.
	_place(board, _player(&"hero", Vector2i(2, 0)))
	return board


func _enemy_at(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(entity_id, TacticalEntityState.EntityType.ENEMY, &"enemy", position, 10, 10, true)


func _terrain_at(board: BoardState, cell: Vector2i) -> int:
	return board.get_cell(cell).terrain


func _board_terrain_snapshot(board: BoardState) -> Array:
	var result: Array = []
	for board_cell: BoardCell in board.cells():
		result.append([board_cell.position.x, board_cell.position.y, board_cell.terrain])
	return result


# ---- stamp + fairness ----------------------------------------------------------------------------

func _scorched_stamps_hazard_terrain_not_wall() -> void:
	var board: BoardState = _floor_board(5, 4)
	_place(board, _player(&"hero", Vector2i(0, 1)))  # (0,1) odd -> NOT a hazard cell, so the hero is safe.
	var apply: ActionResult = AffinityEffectResolver.new().apply_board_effects(board, &"scorched", _repository())
	assert_true(apply.succeeded, "Scorched apply should succeed.")
	var stamped: Array = apply.metadata.get("stamped_hazard_cells", [])
	assert_false(stamped.is_empty(), "Scorched should stamp at least one hazard cell.")
	# Every stamped cell is HAZARD terrain (never WALL).
	for cell_data: Variant in stamped:
		var cell: Vector2i = Vector2i(int((cell_data as Dictionary).get("x")), int((cell_data as Dictionary).get("y")))
		assert_equal(_terrain_at(board, cell), BoardCell.Terrain.HAZARD, "A stamped Scorched cell is HAZARD terrain.")
		assert_false(_terrain_at(board, cell) == BoardCell.Terrain.WALL, "A Scorched hazard cell must NOT be WALL.")


func _hazard_terrain_does_not_block_movement_or_los() -> void:
	var board: BoardState = _scorched_board()
	# A hazard cell at (2,0) must be walkable (can_occupy succeeds) + sight-transparent (does not block LOS).
	var hazard_cell: BoardCell = board.get_cell(Vector2i(4, 0))  # (4,0) even -> hazard, and unoccupied.
	assert_equal(hazard_cell.terrain, BoardCell.Terrain.HAZARD, "Setup: (4,0) should be a hazard cell.")
	assert_false(hazard_cell.terrain_blocks_occupancy(), "HAZARD must not block occupancy (only WALL does).")
	assert_false(hazard_cell.blocks_line_of_sight(), "HAZARD must not block line of sight (only WALL does).")
	# can_occupy on an unoccupied hazard cell succeeds (walkable).
	assert_true(board.can_occupy(Vector2i(4, 0), &"hero").succeeded, "An unoccupied HAZARD cell must be occupiable (walkable).")


func _hazard_is_never_stamped_on_an_occupied_cell() -> void:
	var board: BoardState = _floor_board(5, 4)
	# Place an entity on an EVEN-parity cell (which would otherwise be a hazard cell): (2,0). Fairness: it must NOT be
	# stamped as HAZARD (no unavoidable spawn damage).
	_place(board, _player(&"hero", Vector2i(2, 0)))
	var apply: ActionResult = AffinityEffectResolver.new().apply_board_effects(board, &"scorched", _repository())
	assert_true(apply.succeeded, "Scorched apply should succeed.")
	assert_equal(_terrain_at(board, Vector2i(2, 0)), BoardCell.Terrain.FLOOR, "FAIRNESS: an occupied even-parity cell is NOT stamped as a hazard (the entity's spawn cell stays safe FLOOR).")


# ---- DoT event arithmetic ------------------------------------------------------------------------

func _entity_in_a_hazard_cell_takes_the_expected_damage_event() -> void:
	var board: BoardState = _scorched_board()
	# The hero is at (2,0), a hazard cell. Apply the hazard DoT.
	var hp_before: int = board.get_entity(&"hero").current_hp
	var command: AffinityHazardDamageCommand = AffinityHazardDamageCommand.new(&"hero")
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.succeeded, "An entity in a hazard cell should take hazard damage: %s" % String(result_value.error_code))
	assert_true(result_value.has_events(), "The hazard tick should emit a domain event.")
	var event: DomainEvent = result_value.events[0]
	assert_equal(event.event_type, DomainEvent.Type.DAMAGE_APPLIED, "The hazard tick reuses the DAMAGE_APPLIED event.")
	# HP arithmetic: hp_before - final_damage == hp_after.
	var final_damage: int = int(event.payload.get("final_damage"))
	var hp_after: int = int(event.payload.get("hp_after"))
	assert_equal(int(event.payload.get("hp_before")), hp_before, "hp_before matches the pre-tick HP.")
	assert_equal(hp_after, max(0, hp_before - final_damage), "hp_after == max(0, hp_before - final_damage).")
	assert_equal(String(event.payload.get("damage_type")), "burning", "The Scorched DoT damage_type is `burning`.")
	# The board reflects the new HP.
	assert_equal(board.get_entity(&"hero").current_hp, hp_after, "The board entity HP reflects the applied hazard damage.")
	# actor == target (self-inflicted by occupancy).
	assert_equal(String(event.actor_id), "hero", "The hazard-damage actor is the affected entity itself (self-inflicted by occupancy).")
	assert_equal(String(event.payload.get("target_entity_id")), "hero", "The hazard-damage target is the affected entity.")


func _hazard_damage_floors_hp_at_zero() -> void:
	# A low-HP (1 HP) entity standing in a hazard cell taking more damage than its HP: hp_after floors at 0, never
	# negative. Place the hero, stamp its cell to HAZARD directly (the "entity is in a hazard cell" state), then apply a
	# lethal (5) hazard amount.
	var board: BoardState = _floor_board(5, 4)
	_place(board, _player(&"hero", Vector2i(2, 0), 1))
	board.set_cell_terrain_for_setup(Vector2i(2, 0), BoardCell.Terrain.HAZARD)
	var command: AffinityHazardDamageCommand = AffinityHazardDamageCommand.new(&"hero", 5)
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.succeeded, "A 1-HP entity in a hazard cell should take damage flooring at 0.")
	assert_equal(int(result_value.events[0].payload.get("hp_after")), 0, "HP floors at 0 (never negative).")
	assert_true(board.get_entity(&"hero").is_dead(), "The entity is dead after lethal hazard damage.")


# ---- no-mutation reject paths --------------------------------------------------------------------

func _hazard_damage_rejects_an_entity_not_in_a_hazard_cell_with_no_mutation() -> void:
	var board: BoardState = _scorched_board()
	# enemy_1 is at (0,1), an ODD cell -> NOT a hazard. The command must reject WITHOUT mutating the board.
	var before: Array = _board_terrain_snapshot(board)
	var enemy_hp_before: int = board.get_entity(&"enemy_1").current_hp
	var command: AffinityHazardDamageCommand = AffinityHazardDamageCommand.new(&"enemy_1")
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.is_error(), "An entity NOT in a hazard cell is rejected.")
	assert_equal(result_value.error_code, &"invalid_affinity_hazard_damage", "The reject uses the stable error code.")
	assert_equal(String(result_value.metadata.get("reason")), "target_not_in_hazard", "The reject names the not-in-hazard reason.")
	assert_false(result_value.has_events(), "A rejected hazard tick emits ZERO events.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, enemy_hp_before, "A rejected hazard tick does not change HP.")
	assert_equal(_board_terrain_snapshot(board), before, "A rejected hazard tick leaves the board byte-identical.")


func _hazard_damage_rejects_a_missing_target_with_no_mutation() -> void:
	var board: BoardState = _scorched_board()
	var before: Array = _board_terrain_snapshot(board)
	var command: AffinityHazardDamageCommand = AffinityHazardDamageCommand.new(&"ghost")
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.is_error(), "A missing target is rejected.")
	assert_equal(String(result_value.metadata.get("reason")), "missing_target", "The reject names the missing-target reason.")
	assert_false(result_value.has_events(), "A rejected hazard tick emits ZERO events.")
	assert_equal(_board_terrain_snapshot(board), before, "A rejected hazard tick leaves the board byte-identical.")


func _hazard_damage_rejects_a_dead_target_with_no_mutation() -> void:
	var board: BoardState = _floor_board(5, 4)
	_place(board, _player(&"hero", Vector2i(2, 0), 0))  # dead (0 HP) on an even cell.
	# (2,0) is occupied so not auto-stamped; stamp it directly so the only reject reason is the dead target.
	board.set_cell_terrain_for_setup(Vector2i(2, 0), BoardCell.Terrain.HAZARD)
	var before: Array = _board_terrain_snapshot(board)
	var command: AffinityHazardDamageCommand = AffinityHazardDamageCommand.new(&"hero")
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.is_error(), "A dead target is rejected.")
	assert_equal(String(result_value.metadata.get("reason")), "dead_target", "The reject names the dead-target reason.")
	assert_false(result_value.has_events(), "A rejected hazard tick emits ZERO events.")
	assert_equal(_board_terrain_snapshot(board), before, "A rejected hazard tick leaves the board byte-identical.")


# ---- explainability ------------------------------------------------------------------------------

func _scorched_cells_are_previewable() -> void:
	var board: BoardState = _scorched_board()
	var preview: ActionResult = AffinityPreviewQuery.new().preview_board(board, &"scorched", _repository())
	assert_true(preview.succeeded, "The Scorched preview should succeed.")
	assert_true(bool(preview.metadata.get("has_effects")), "The Scorched preview reports effects.")
	assert_false((preview.metadata.get("hazard_cells", []) as Array).is_empty(), "AC1: the Scorched preview lists the affected hazard cells.")
	# The Scorched hazard cue id is surfaced (so the presenter can map it to a non-color channel).
	assert_true((preview.metadata.get("cue_ids", []) as Array).has("affinity_scorched_hazard"), "AC1: the Scorched hazard cue id is surfaced in the preview.")
	# A readable warning is present.
	assert_false((preview.metadata.get("warnings", []) as Array).is_empty(), "AC1: the Scorched preview surfaces a readable warning.")


func _hazard_damage_event_is_logged_readably() -> void:
	var board: BoardState = _scorched_board()
	var command: AffinityHazardDamageCommand = AffinityHazardDamageCommand.new(&"hero")
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.succeeded, "Setup: the hazard tick should succeed.")
	var entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(result_value.events)
	assert_equal(entries.size(), 1, "The hazard tick produces one log entry.")
	var summary: String = String(entries[0].get("summary", ""))
	assert_true(summary.contains("burning"), "AC1: the log entry names the burning damage type.")
	assert_true(summary.contains("Scorched fire hazard"), "AC1: the log entry attributes the damage to a Scorched fire hazard (not a weapon attacker).")
	assert_true(summary.contains("hero"), "AC1: the log entry names the affected entity.")
