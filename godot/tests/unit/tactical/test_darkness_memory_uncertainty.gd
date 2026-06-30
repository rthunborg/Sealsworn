extends "res://tests/unit/test_case.gd"

# Story 7.6 Task 3 (AC2) — Darkness memory distortion: communicate UNCERTAINTY, keep VISIBLE truth reliable. These prove
# the Darkness-aware inspect/memory read (DarknessVisibilityLayer.visible_facts_for_cell):
#   - MEMORY UNCERTAINTY (AC2 first half): under Darkness, a `memory`-state cell (explored-but-not-currently-visible) is
#     flagged STALE/UNCERTAIN (memory_uncertain + the non-color uncertainty cue id) — fog_memory_pressure surfaced.
#   - VISIBLE TRUTH STAYS RELIABLE (AC2 second half, load-bearing): a `visible`-state cell's facts are BYTE-IDENTICAL
#     under Darkness vs neutral (Darkness NEVER distorts a currently-visible cell — only memory + radius).
#   - HIDDEN LEAKS NOTHING: a `hidden` cell still exposes no facts under Darkness (the Epic-1 fog contract — Darkness
#     does not leak hidden facts).
#   - ADDITIVE / OPT-IN: for neutral / non-Darkness the read is BYTE-IDENTICAL to the existing
#     TacticalVisibilityQuery.visible_facts_for_cell (the Epic-1 visibility tests pin the default; never changed).
#   - The annotation is a READ-LAYER annotation only: it does NOT mutate stored BoardCell state (the cell's persisted
#     fields are untouched).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

func run() -> Dictionary:
	_memory_cell_is_flagged_uncertain_under_darkness()
	_visible_cell_facts_are_byte_identical_under_darkness_vs_neutral()
	_hidden_cell_leaks_no_facts_under_darkness()
	_neutral_read_is_byte_identical_to_the_existing_query()
	_memory_annotation_does_not_mutate_stored_cell_state()
	_memory_pressure_marker_drop_is_fail_safe()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


# A small board with one enemy at (1,1). The cell at (1,1) can be driven through hidden -> memory -> visible by toggling
# its explored/visible flags (the existing test_tactical_visibility_query.gd pattern).
func _board_with_enemy() -> BoardState:
	var board: BoardState = BoardState.new()
	var create: ActionResult = CreateBoardCommand.new(4, 4).execute(board)
	assert_true(create.succeeded, "Setup: the fixture board should create.")
	var enemy: TacticalEntityState = TacticalEntityState.new(&"enemy_1", TacticalEntityState.EntityType.ENEMY, &"enemy", Vector2i(1, 1), 10, 10, true)
	var place: ActionResult = board.place_entity_for_setup(enemy)
	assert_true(place.succeeded, "Setup: enemy placement should succeed.")
	return board


# ---- AC2 first half: memory uncertainty ----------------------------------------------------------

func _memory_cell_is_flagged_uncertain_under_darkness() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _board_with_enemy()
	var cell: Vector2i = Vector2i(1, 1)
	# Make the cell a `memory` cell: explored but not currently visible.
	board.get_cell(cell).explored = true
	board.get_cell(cell).visible = false

	var fact: Dictionary = layer.visible_facts_for_cell(query, board, cell, &"darkness", _repository()).metadata.get("fact", {})
	assert_equal(String(fact.get("visibility_state")), "memory", "The cell is in the memory state.")
	assert_equal(fact.get("authoritative"), false, "Memory remains non-authoritative (the structural guarantee).")
	assert_equal(fact.get("memory_uncertain"), true, "AC2: under Darkness, a memory cell is flagged uncertain/stale.")
	assert_equal(String(fact.get("memory_certainty")), "uncertain", "AC2: the memory certainty is surfaced as uncertain.")
	assert_equal(String(fact.get("uncertainty_cue_id")), DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN, "AC2: the memory cell carries the Darkness uncertainty cue id.")
	# The memory cell still does NOT leak the live occupant (the Epic-1 memory contract — memory shows stale terrain only).
	assert_false(fact.has("occupant_id"), "Darkness memory still does not expose the live occupant (only its reliability is flagged).")


# ---- AC2 second half (load-bearing): visible truth stays reliable ---------------------------------

func _visible_cell_facts_are_byte_identical_under_darkness_vs_neutral() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _board_with_enemy()
	var cell: Vector2i = Vector2i(1, 1)
	# Make the cell a `visible` cell: currently visible (and explored).
	board.get_cell(cell).explored = true
	board.get_cell(cell).visible = true

	var neutral_fact: Dictionary = query.visible_facts_for_cell(board, cell).metadata.get("fact", {})
	var darkness_fact: Dictionary = layer.visible_facts_for_cell(query, board, cell, &"darkness", _repository()).metadata.get("fact", {})
	assert_equal(String(darkness_fact.get("visibility_state")), "visible", "The cell is currently visible.")
	assert_equal(darkness_fact.get("authoritative"), true, "A visible cell stays authoritative under Darkness.")
	# The load-bearing AC2 guarantee: Darkness NEVER distorts a currently-visible cell. The visible fact is byte-identical.
	assert_equal(darkness_fact, neutral_fact, "AC2: a visible cell's facts are byte-identical under Darkness vs neutral (the live truth stays reliable).")
	assert_false(darkness_fact.has("memory_uncertain"), "AC2: a visible cell carries NO uncertainty flag (only memory is uncertain).")
	# It still exposes the authoritative live occupant.
	assert_equal(String(darkness_fact.get("occupant_id")), "enemy_1", "The visible cell still exposes the live occupant authoritatively.")
	assert_equal(int(darkness_fact.get("current_hp")), 10, "The visible cell still exposes the live occupant HP authoritatively.")


# ---- hidden leaks nothing ------------------------------------------------------------------------

func _hidden_cell_leaks_no_facts_under_darkness() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _board_with_enemy()
	var cell: Vector2i = Vector2i(1, 1)
	# A hidden cell: never seen (default explored=false, visible=false).
	var neutral_fact: Dictionary = query.visible_facts_for_cell(board, cell).metadata.get("fact", {})
	var darkness_fact: Dictionary = layer.visible_facts_for_cell(query, board, cell, &"darkness", _repository()).metadata.get("fact", {})
	assert_equal(String(darkness_fact.get("visibility_state")), "hidden", "The cell is hidden.")
	assert_equal(darkness_fact, neutral_fact, "A hidden cell is byte-identical under Darkness (no fact leak — the Epic-1 fog contract).")
	assert_false(darkness_fact.has("terrain"), "A hidden cell exposes no terrain under Darkness.")
	assert_false(darkness_fact.has("memory_uncertain"), "A hidden cell carries no memory-uncertainty flag (it is not memory).")


# ---- additive / opt-in: neutral byte-identical ---------------------------------------------------

func _neutral_read_is_byte_identical_to_the_existing_query() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var cell: Vector2i = Vector2i(1, 1)
	# Across all three visibility states, neutral / non-Darkness routes the layer to the byte-identical existing fact.
	for affinity_id: StringName in [AffinityDefinition.AFFINITY_NONE, &"scorched", &"flooded_conductive", &"cursed", &"not_a_real_affinity"]:
		for state: String in ["hidden", "memory", "visible"]:
			var board: BoardState = _board_with_enemy()
			if state == "memory":
				board.get_cell(cell).explored = true
			elif state == "visible":
				board.get_cell(cell).explored = true
				board.get_cell(cell).visible = true
			var neutral_fact: Dictionary = query.visible_facts_for_cell(board, cell).metadata.get("fact", {})
			var layer_fact: Dictionary = layer.visible_facts_for_cell(query, board, cell, affinity_id, _repository()).metadata.get("fact", {})
			assert_equal(layer_fact, neutral_fact, "%s/%s: the layer read is byte-identical to the existing query (additive, default unchanged)." % [String(affinity_id), state])


# ---- read-layer only: no stored state mutation ---------------------------------------------------

func _memory_annotation_does_not_mutate_stored_cell_state() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _board_with_enemy()
	var cell: Vector2i = Vector2i(1, 1)
	board.get_cell(cell).explored = true
	board.get_cell(cell).visible = false
	var before: Dictionary = board.get_cell(cell).to_dictionary()

	layer.visible_facts_for_cell(query, board, cell, &"darkness", _repository())

	assert_equal(board.get_cell(cell).to_dictionary(), before, "AC2: the memory-uncertainty annotation is a READ-layer annotation — it does NOT mutate stored BoardCell state.")


func _memory_pressure_marker_drop_is_fail_safe() -> void:
	# A Darkness affinity whose definition carries NO fog_memory_pressure marker must NOT flag memory (fail-safe — the
	# annotation rides off the recorded marker).
	var darkness_no_memory: AffinityDefinition = AffinityDefinition.new(
		&"darkness",
		"Darkness",
		[{"rule_id": "reduced_visibility", "description": "Reduced sight only, no memory pressure (fail-safe probe)."}],
		[] as Array[StringName],
		"A Darkness affinity with reduced visibility but no memory-pressure marker."
	)
	var repo: AffinityRepository = AffinityRepository.create_repository_from_definitions([darkness_no_memory])
	assert_true(repo != null, "Setup: the no-memory-pressure darkness fixture repo should build.")
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _board_with_enemy()
	var cell: Vector2i = Vector2i(1, 1)
	board.get_cell(cell).explored = true
	var fact: Dictionary = layer.visible_facts_for_cell(query, board, cell, &"darkness", repo).metadata.get("fact", {})
	assert_false(fact.has("memory_uncertain"), "Without the fog_memory_pressure marker, a memory cell is NOT flagged uncertain (fail-safe).")
