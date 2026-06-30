extends "res://tests/unit/test_case.gd"

# Story 7.5 Task 1 — the NARROW affinity tactical-effect resolver (the FIRST occupant of scripts/rules/operations/).
# These prove the resolver is a deterministic, PURE-DOMAIN dispatch over a BoardState given an assigned affinity:
#   - DISPATCH: it routes Scorched -> hazard cells, Flooded -> conductive/pathing marks; Cursed -> a kernel rule source
#     (no board effect); Darkness -> NO-OP (7.6 owns it); neutral `none` / unknown -> NO effects (AC3 carried forward).
#   - PURE DOMAIN: resolve_board_plan mutates nothing; apply_board_effects mutates ONLY the passed board (no scene
#     node, no RNG). Running twice on equivalent boards yields identical plans (the AC2 determinism invariant).
#   - NAMED-RNG: the resolver draws ZERO RNG (a deterministic v0). (Asserted indirectly — no stream is even passed.)
#
# It dispatches off the 7.4 AffinityRepository.tactical_rules_for markers (CONSUMED, not re-authored). Scorched/Flooded
# board specifics live in test_affinity_scorched_effects.gd / test_affinity_flooded_effects.gd; Cursed in
# test_affinity_cursed_effects.gd; this suite is the resolver's dispatch + determinism + purity contract.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const CurseDefinition = preload("res://scripts/content/definitions/curse_definition.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

func run() -> Dictionary:
	_neutral_none_produces_no_effects()
	_unknown_affinity_produces_no_effects()
	_darkness_is_a_no_op_in_7_5()
	_scorched_dispatches_to_hazard_cells()
	_flooded_dispatches_to_conductive_and_pathing_marks()
	_cursed_produces_no_board_effect_but_a_kernel_rule_source()
	_resolve_board_plan_is_pure_no_mutation()
	_apply_board_effects_mutates_only_the_passed_board()
	_same_board_and_affinity_yield_identical_plans()
	_null_or_empty_board_is_handled()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


func _floor_board(width: int = 5, height: int = 4) -> BoardState:
	# A plain all-FLOOR board with one player + one enemy (occupying two cells). All cells FLOOR except the two
	# occupied cells (still FLOOR terrain; just occupied).
	var board: BoardState = BoardState.new()
	var create: ActionResult = CreateBoardCommand.new(width, height).execute(board)
	assert_true(create.succeeded, "Setup: the fixture board should create.")
	_place(board, _player(&"hero", Vector2i(0, 0)))
	_place(board, _enemy(&"enemy_1", Vector2i(width - 1, height - 1)))
	return board


func _place(board: BoardState, entity: TacticalEntityState) -> void:
	var place_result: ActionResult = board.place_entity_for_setup(entity)
	assert_true(place_result.succeeded, "Setup: entity placement should succeed.")


func _player(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(entity_id, TacticalEntityState.EntityType.PLAYER, &"player", position, 18, 18, true)


func _enemy(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(entity_id, TacticalEntityState.EntityType.ENEMY, &"enemy", position, 10, 10, true)


func _board_terrain_snapshot(board: BoardState) -> Array:
	var result: Array = []
	for board_cell: BoardCell in board.cells():
		result.append([board_cell.position.x, board_cell.position.y, board_cell.terrain])
	return result


# ---- neutral / unknown / darkness: NO effects (AC3 carried forward; 7.6 owns Darkness) ------------

func _neutral_none_produces_no_effects() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	var plan: Dictionary = resolver.resolve_board_plan(_floor_board(), AffinityDefinition.AFFINITY_NONE, _repository())
	assert_false(bool(plan.get("has_effects")), "AC3: the neutral `none` affinity produces NO affinity effects.")
	assert_true((plan.get("scorched_hazard_cells", []) as Array).is_empty(), "Neutral produces no hazard cells.")
	assert_true((plan.get("conductive_danger_cells", []) as Array).is_empty(), "Neutral produces no conductive cells.")
	assert_true((plan.get("pathing_pressure_cells", []) as Array).is_empty(), "Neutral produces no pathing cells.")
	assert_true((plan.get("cues", []) as Array).is_empty(), "Neutral produces no cues.")


func _unknown_affinity_produces_no_effects() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	# An unknown/unassigned id: the 7.4 tactical_rules_for returns the EMPTY set (fail-SAFE), so NO effects.
	var plan: Dictionary = resolver.resolve_board_plan(_floor_board(), &"not_a_real_affinity", _repository())
	assert_false(bool(plan.get("has_effects")), "An unknown affinity id produces NO effects (fail-safe to neutral).")
	# apply_board_effects on an unknown id stamps nothing and leaves the board terrain unchanged.
	var board: BoardState = _floor_board()
	var before: Array = _board_terrain_snapshot(board)
	var apply: ActionResult = resolver.apply_board_effects(board, &"not_a_real_affinity", _repository())
	assert_true(apply.succeeded, "apply_board_effects on an unknown id succeeds as a no-op.")
	assert_true((apply.metadata.get("stamped_hazard_cells", []) as Array).is_empty(), "An unknown id stamps no hazard cells.")
	assert_equal(_board_terrain_snapshot(board), before, "An unknown id leaves the board terrain byte-identical.")


func _darkness_is_a_no_op_in_7_5() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	# Darkness IS a registered affinity (its definition + markers exist) but its EFFECT is 7.6's — 7.5's resolver is a
	# deliberate NO-OP for it (no board effect, no cues).
	var plan: Dictionary = resolver.resolve_board_plan(_floor_board(), &"darkness", _repository())
	assert_false(bool(plan.get("has_effects")), "Darkness produces NO board effect in 7.5 (its effect is 7.6).")
	assert_true((plan.get("cues", []) as Array).is_empty(), "Darkness surfaces no 7.5 cues.")


# ---- dispatch: Scorched / Flooded / Cursed -------------------------------------------------------

func _scorched_dispatches_to_hazard_cells() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	var plan: Dictionary = resolver.resolve_board_plan(_floor_board(), &"scorched", _repository())
	assert_true(bool(plan.get("has_effects")), "Scorched dispatches to a real effect.")
	assert_false((plan.get("scorched_hazard_cells", []) as Array).is_empty(), "Scorched produces hazard cells.")
	assert_true((plan.get("conductive_danger_cells", []) as Array).is_empty(), "Scorched produces NO conductive cells (that is Flooded's branch).")


func _flooded_dispatches_to_conductive_and_pathing_marks() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	var plan: Dictionary = resolver.resolve_board_plan(_floor_board(), &"flooded_conductive", _repository())
	assert_true(bool(plan.get("has_effects")), "Flooded dispatches to a real effect.")
	assert_false((plan.get("conductive_danger_cells", []) as Array).is_empty(), "Flooded produces conductive danger cells.")
	assert_false((plan.get("pathing_pressure_cells", []) as Array).is_empty(), "Flooded produces pathing-pressure cells.")
	assert_true((plan.get("scorched_hazard_cells", []) as Array).is_empty(), "Flooded stamps NO hazard terrain (its marks are data-only).")


func _cursed_produces_no_board_effect_but_a_kernel_rule_source() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	# Cursed routes through the rules kernel, NOT the board: resolve_board_plan is a no-op for it.
	var plan: Dictionary = resolver.resolve_board_plan(_floor_board(), &"cursed", _repository())
	assert_false(bool(plan.get("has_effects")), "Cursed produces NO board effect (it routes through the rules kernel).")
	# The Cursed rule source IS produced by the static factory (the caller seats it on the resolver).
	var rule_source: CurseDefinition = AffinityEffectResolver.cursed_affinity_rule_source(&"cursed", _repository())
	assert_true(rule_source != null, "AC3: Cursed produces a curse-like rule source for the rules kernel.")
	assert_true(rule_source.validate().succeeded, "The Cursed rule source is a valid CurseDefinition.")
	assert_true(rule_source.fires_in_window(RuleTrigger.LEVEL_ENTERED), "The Cursed rule source fires in a valid window (level_entered).")
	# A non-Cursed affinity produces NO rule source.
	assert_true(AffinityEffectResolver.cursed_affinity_rule_source(&"scorched", _repository()) == null, "A non-Cursed affinity produces no curse rule source.")
	assert_true(AffinityEffectResolver.cursed_affinity_rule_source(AffinityDefinition.AFFINITY_NONE, _repository()) == null, "The neutral affinity produces no curse rule source.")


# ---- purity + determinism ------------------------------------------------------------------------

func _resolve_board_plan_is_pure_no_mutation() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	# resolve_board_plan must NOT mutate the board terrain (it is the pure PLAN, not the apply). Run Scorched (the one
	# that DOES stamp on apply) through resolve_board_plan and confirm the board terrain is unchanged.
	var board: BoardState = _floor_board()
	var before: Array = _board_terrain_snapshot(board)
	resolver.resolve_board_plan(board, &"scorched", _repository())
	resolver.resolve_board_plan(board, &"flooded_conductive", _repository())
	assert_equal(_board_terrain_snapshot(board), before, "resolve_board_plan must not mutate the board (it is a pure read).")


func _apply_board_effects_mutates_only_the_passed_board() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	# apply_board_effects for Scorched stamps HAZARD cells on the passed board; a SECOND board passed separately is
	# untouched (no shared/global state).
	var board_a: BoardState = _floor_board()
	var board_b: BoardState = _floor_board()
	var before_b: Array = _board_terrain_snapshot(board_b)
	var apply: ActionResult = resolver.apply_board_effects(board_a, &"scorched", _repository())
	assert_true(apply.succeeded, "apply_board_effects for Scorched should succeed.")
	assert_false((apply.metadata.get("stamped_hazard_cells", []) as Array).is_empty(), "Scorched stamps at least one hazard cell.")
	# board_a now has HAZARD cells; board_b is untouched.
	var hazard_count_a: int = _hazard_count(board_a)
	assert_true(hazard_count_a > 0, "board_a should have HAZARD cells after apply.")
	assert_equal(_board_terrain_snapshot(board_b), before_b, "A separate board must be untouched (no global/shared state).")


func _same_board_and_affinity_yield_identical_plans() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	for affinity_id: StringName in [&"scorched", &"flooded_conductive"]:
		var first: Dictionary = resolver.resolve_board_plan(_floor_board(), affinity_id, _repository())
		var second: Dictionary = resolver.resolve_board_plan(_floor_board(), affinity_id, _repository())
		assert_equal(first.get("scorched_hazard_cells"), second.get("scorched_hazard_cells"), "AC2: %s hazard cells are deterministic." % String(affinity_id))
		assert_equal(first.get("conductive_danger_cells"), second.get("conductive_danger_cells"), "AC2: %s conductive cells are deterministic." % String(affinity_id))
		assert_equal(first.get("pathing_pressure_cells"), second.get("pathing_pressure_cells"), "AC2: %s pathing cells are deterministic." % String(affinity_id))
		assert_equal(first.get("explanation"), second.get("explanation"), "AC2: %s explanation is deterministic." % String(affinity_id))


func _null_or_empty_board_is_handled() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	var null_plan: Dictionary = resolver.resolve_board_plan(null, &"scorched", _repository())
	assert_false(bool(null_plan.get("has_effects")), "A null board yields an empty plan.")
	var empty_board: BoardState = BoardState.new()
	var empty_plan: Dictionary = resolver.resolve_board_plan(empty_board, &"scorched", _repository())
	assert_false(bool(empty_plan.get("has_effects")), "An uncreated board yields an empty plan.")
	var apply: ActionResult = resolver.apply_board_effects(null, &"scorched", _repository())
	assert_true(apply.is_error(), "apply_board_effects on a null board fails closed.")


func _hazard_count(board: BoardState) -> int:
	var count: int = 0
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain == BoardCell.Terrain.HAZARD:
			count += 1
	return count
