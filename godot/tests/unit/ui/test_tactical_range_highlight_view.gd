extends "res://tests/unit/test_case.gd"

# Story 14.10 Task 3/Task 5 — TacticalRangeHighlightView (AC2/AC3): the move-range + attack-range highlight seam.
#
# TacticalRangeHighlightView is the pure, scene-free RefCounted READ the presenter draws as additive board overlays.
# It REUSES the EXISTING queries (TacticalMovementQuery.validate_target for the move range, AttackPreviewQuery.
# preview_target_cell for the attack range) — no new domain query, no new BFS. It is turn-gated (highlights only on
# the player's PLANNING turn with a living hero), pins an EXACT key set, draws NO RNG, and mutates NOTHING. This test
# pins those contracts against a fixture board.

const TacticalRangeHighlightView = preload("res://scripts/ui/view_models/tactical_range_highlight_view.gd")
const TacticalMovementQuery = preload("res://scripts/tactical/movement/tactical_movement_query.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

const HERO_ID := &"hero"

# The pinned top-level key set (sorted). A key never silently appears/vanishes (the exact-key discipline).
const EXPECTED_KEYS: Array[String] = [
	"attack_cells",
	"has_highlights",
	"move_cells",
	"reason"
]

func run() -> Dictionary:
	_move_cells_match_the_movement_query_on_a_fixture()
	_attack_cells_match_the_attack_preview_query()
	_corpse_is_excluded_from_attack_cells()
	_no_highlights_when_not_player_turn()
	_no_highlights_when_hero_dead()
	_no_highlights_when_board_is_null()
	_seam_is_a_pure_read_no_mutation()
	_exact_key_set_pinned()
	return result()


# AC2: the move highlights EXACTLY equal the movement-query legal set (budget 3) over the whole board — the Manhattan
# pre-filter drops no legal cell and includes no illegal one.
func _move_cells_match_the_movement_query_on_a_fixture() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_open_lane() # 6x3, hero (0,1), enemy (3,1), revealed
	var weapon: WeaponDefinition = _weapon(&"sword")
	var data: Dictionary = TacticalRangeHighlightView.project(board, HERO_ID, weapon, _player_turn())
	assert_equal(data.get("has_highlights"), true, "A live player turn projects has_highlights == true.")

	var query: TacticalMovementQuery = TacticalMovementQuery.new()
	var expected: Dictionary = {}
	for y: int in range(board.height):
		for x: int in range(board.width):
			var res: ActionResult = query.validate_target(board, HERO_ID, Vector2i(x, y), TacticalMovementQuery.DEFAULT_MOVEMENT_BUDGET)
			if res.succeeded and String(res.metadata.get("reason", "")) == "valid":
				expected["%d,%d" % [x, y]] = true

	var actual: Dictionary = _cell_lookup(data.get("move_cells", []))
	assert_equal(actual.size(), expected.size(), "move_cells count must equal the movement-query legal set.")
	for key: String in expected.keys():
		assert_true(actual.has(key), "move_cells must include the movement-query-legal cell %s." % key)
	# Spot checks: an adjacent open cell is a move highlight; the enemy-occupied + a beyond-budget cell are not.
	assert_true(actual.has("0,0"), "An adjacent open cell must be a move highlight.")
	assert_false(actual.has("3,1"), "The enemy-occupied cell must not be a move highlight.")
	assert_false(actual.has("5,1"), "A beyond-budget cell must not be a move highlight.")


# AC2: the attack highlights EXACTLY equal the attack-preview-query legal set (a range-1 sword on an adjacent enemy).
func _attack_cells_match_the_attack_preview_query() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy() # 3x3, hero (1,1), enemy (2,1)
	var weapon: WeaponDefinition = _weapon(&"sword")
	var data: Dictionary = TacticalRangeHighlightView.project(board, HERO_ID, weapon, _player_turn())
	var actual: Dictionary = _cell_lookup(data.get("attack_cells", []))
	assert_equal(actual.size(), 1, "The adjacent enemy must be the only attack highlight.")
	assert_true(actual.has("2,1"), "The adjacent enemy cell must be an attack highlight.")
	# Cross-check the query itself agrees the cell is a legal target.
	var res: ActionResult = AttackPreviewQuery.new().preview_target_cell(board, HERO_ID, Vector2i(2, 1), weapon)
	assert_true(res.succeeded and bool(res.metadata.get("legal", false)), "The attack-preview query must confirm the cell is legal.")


# AC2 (the 14.2 corpse-tap-is-inspect rule): a dead occupant is EXCLUDED from attack_cells.
func _corpse_is_excluded_from_attack_cells() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_dead_target() # hero (1,1), DEAD enemy (2,1)
	var weapon: WeaponDefinition = _weapon(&"sword")
	var data: Dictionary = TacticalRangeHighlightView.project(board, HERO_ID, weapon, _player_turn())
	assert_equal(data.get("has_highlights"), true, "The live actor is alive -> has_highlights stays true.")
	assert_true((data.get("attack_cells", []) as Array).is_empty(), "A corpse must be EXCLUDED from attack_cells.")


# AC2 turn-gate: not the player's planning turn -> empty highlight sets + the honest reason.
func _no_highlights_when_not_player_turn() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy()
	var weapon: WeaponDefinition = _weapon(&"sword")
	var turn: Dictionary = {"phase": String(TacticalTurnState.PHASE_ENEMY_PLANNING)}
	var data: Dictionary = TacticalRangeHighlightView.project(board, HERO_ID, weapon, turn)
	assert_equal(data.get("has_highlights"), false, "Not the player's turn -> has_highlights == false.")
	assert_true((data.get("move_cells", []) as Array).is_empty(), "Not the player's turn -> empty move_cells.")
	assert_true((data.get("attack_cells", []) as Array).is_empty(), "Not the player's turn -> empty attack_cells.")
	assert_equal(data.get("reason"), TacticalRangeHighlightView.REASON_NOT_PLAYER_TURN, "The reason must be not_player_turn.")


# AC2 fail-closed: a dead hero -> empty highlights + the dead_actor reason.
func _no_highlights_when_hero_dead() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_dead_actor() # hero hp 0
	var weapon: WeaponDefinition = _weapon(&"sword")
	var data: Dictionary = TacticalRangeHighlightView.project(board, HERO_ID, weapon, _player_turn())
	assert_equal(data.get("has_highlights"), false, "A dead hero -> has_highlights == false.")
	assert_true((data.get("move_cells", []) as Array).is_empty(), "A dead hero -> empty move_cells.")
	assert_equal(data.get("reason"), TacticalRangeHighlightView.REASON_DEAD_ACTOR, "The reason must be dead_actor.")


# AC2 fail-closed: a null board -> empty highlights + the no_board reason (never a crash).
func _no_highlights_when_board_is_null() -> void:
	var data: Dictionary = TacticalRangeHighlightView.project(null, HERO_ID, _weapon(&"sword"), _player_turn())
	assert_equal(data.get("has_highlights"), false, "A null board -> has_highlights == false.")
	assert_equal(data.get("reason"), TacticalRangeHighlightView.REASON_NO_BOARD, "The reason must be no_board.")


# AC3: the seam is a PURE read — it draws no RNG and mutates the board 0 (the pre/post snapshot is byte-identical).
func _seam_is_a_pure_read_no_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_open_lane()
	var weapon: WeaponDefinition = _weapon(&"sword")
	var before: Dictionary = board.to_snapshot()
	var data: Dictionary = TacticalRangeHighlightView.project(board, HERO_ID, weapon, _player_turn())
	assert_equal(data.get("has_highlights"), true, "Precondition: highlights were computed (a live read).")
	var after: Dictionary = board.to_snapshot()
	assert_equal(after, before, "The seam must not mutate the board snapshot (pure read, no RNG).")


# AC3: the projection exposes EXACTLY the pinned key set — present AND absent projections carry the SAME set.
func _exact_key_set_pinned() -> void:
	var board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy()
	var present_keys: Array = TacticalRangeHighlightView.project(board, HERO_ID, _weapon(&"sword"), _player_turn()).keys()
	present_keys.sort()
	assert_equal(present_keys, EXPECTED_KEYS, "The highlight projection must expose EXACTLY the pinned key set.")
	var absent_keys: Array = TacticalRangeHighlightView.project(null, HERO_ID, null, {}).keys()
	absent_keys.sort()
	assert_equal(absent_keys, EXPECTED_KEYS, "The empty projection must expose the SAME pinned key set (no key vanishes).")


# --- helpers ---------------------------------------------------------------

func _player_turn() -> Dictionary:
	return {"phase": String(TacticalTurnState.PHASE_PLAYER_PLANNING)}


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _cell_lookup(cells: Variant) -> Dictionary:
	var lookup: Dictionary = {}
	if not cells is Array:
		return lookup
	for cell_value: Variant in cells as Array:
		if cell_value is Dictionary:
			var cell: Dictionary = cell_value
			lookup["%d,%d" % [int(cell.get("x", 0)), int(cell.get("y", 0))]] = true
	return lookup
