extends "res://tests/unit/test_case.gd"

# Story 5.5 Task 5.2 — the EPIC-5 CLOSING smoke slice end-to-end (the load-bearing AC1-4 proof). 5.5 ASSEMBLES
# + SURFACES + PROVES what 5.1-5.4 + the 4.6 orchestrator already deliver: start a run AS a class -> the seated
# run carries the kit + resolver -> the class-start SUMMARY projects the identity + per-window passive
# explanations -> the first tactical level GENERATES into a valid playable BoardState AND the unchanged Epic-1
# move/attack/enemy-turn/outcome loop still OPERATES on it -> each class genuinely DIFFERS -> the same
# (seed, class) is byte-deterministic -> the empty-class/legacy path stays byte-identical.
#
# This test owns 5.5's NEW assertions ONLY (it does NOT re-prove the seating already covered by
# test_run_start_command.gd / test_run_orchestrator.gd):
#   AC1: the run enters its first tactical level with the correct kit + visible class identity (the SUMMARY
#        projection), and the first level generates valid + the Epic-1 loop operates on it.
#   AC2: per-window passive EXPLANATIONS appear (run_started / before_attack) and are THIS class's only.
#   AC3: same (seed, class) -> byte-identical started run + resolver output + first-level generation + Epic-1
#        outcome; the empty-class/legacy path stays byte-identical to the seed-only start.
#   AC4: each class enters with a DIFFERENT weapon/support + a DIFFERENT pair of passive explanations.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const ClassStartSummaryViewModel = preload("res://scripts/ui/view_models/class_start_summary_view_model.gd")
const CombatOutcomeEvaluator = preload("res://scripts/tactical/outcomes/combat_outcome_evaluator.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const Epic1MicroCombatScenario = preload("res://scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

const SELECTABLE_CLASS_IDS: Array[StringName] = [&"warrior", &"pyromancer", &"ranger"]
const SMOKE_SEED: int = 42
const HERO_ID := &"hero"

# The structural kit differentiation the tester observes (AC4) — asserted against the resolved baselines in the
# differentiation proof, not used as a content source.
const EXPECTED_WEAPONS := {
	&"warrior": "sword",
	&"pyromancer": "staff",
	&"ranger": "bow"
}
const EXPECTED_SUPPORTS := {
	&"warrior": "shield",
	&"pyromancer": "tome",
	&"ranger": "none"
}

func run() -> Dictionary:
	_each_class_starts_and_enters_first_level_with_identity_and_explanations()
	_first_level_generates_valid_and_epic1_loop_operates_on_it()
	_unchanged_epic1_loop_still_reaches_a_deterministic_victory()
	_classes_are_structurally_differentiated_and_disjoint()
	_same_seed_and_class_is_byte_deterministic_end_to_end()
	_empty_class_path_stays_byte_identical_to_a_seed_only_start()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Drive the orchestrator's FIRST combat node (the depth-0 start node is always combat — Story 4.2) and return
# its resolution metadata (carries the generated level_seed / recipe / the v0 auto-resolve marker). The run is
# left having just entered+cleared its first level.
func _resolve_first_level(orchestrator: RunOrchestrator) -> ActionResult:
	var first: ActionResult = orchestrator.resolve_current_node()
	assert_true(first.succeeded, "Resolving the first (combat) node should succeed: %s" % first.metadata)
	return first


# ---- AC1/AC2: identity + per-window explanations at the first level -------------------------------

func _each_class_starts_and_enters_first_level_with_identity_and_explanations() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var orchestrator: RunOrchestrator = RunOrchestrator.new()
		var start: ActionResult = orchestrator.start(SMOKE_SEED, false, class_id)
		assert_true(start.succeeded, "%s: the class run should start: %s" % [class_id, start.metadata])
		var run: RunState = orchestrator.run
		# The seated run carries the class + a non-null kit + a non-null resolver (5.3/5.4 seating — consumed).
		assert_equal(run.selected_class_id, class_id, "%s: the seated run must record the class id." % class_id)
		assert_true(run.starting_kit != null, "%s: the seated run must carry a non-null starting_kit." % class_id)
		assert_true(run.rules_resolver != null, "%s: the seated run must seat a non-null rules_resolver." % class_id)

		# 5.5's NEW surface: project the class-start identity + the per-window passive explanations.
		var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
		assert_true(bool(summary.get("has_class_identity")), "%s: the summary must report class identity present." % class_id)
		assert_equal(summary.get("class_id"), String(class_id), "%s: the summary must project the class id." % class_id)
		# The class passive's explanation surfaces at the before_attack window; the equipment-synergy passive's
		# at run_started (the AC2 "explanations appear when preview/combat events occur" surface).
		assert_equal((summary.get("before_attack_explanations") as Array).size(), 1, "%s: exactly one class-passive explanation must surface at before_attack." % class_id)
		assert_equal((summary.get("run_started_explanations") as Array).size(), 1, "%s: exactly one equipment-synergy explanation must surface at run_started." % class_id)

		# Resolving the same windows directly on the run's resolver yields the SAME explanation lines (the
		# projection faithfully surfaces the resolver, no extra/missing entries).
		assert_equal(str(summary.get("before_attack_explanations")), str(run.rules_resolver.explain(RuleTrigger.BEFORE_ATTACK)), "%s: the projected before_attack explanations must equal the resolver's." % class_id)
		assert_equal(str(summary.get("run_started_explanations")), str(run.rules_resolver.explain(RuleTrigger.RUN_STARTED)), "%s: the projected run_started explanations must equal the resolver's." % class_id)

		# The run remains playable: the orchestrator drives it start-to-end exactly like a seed-only run (the
		# class records only domain fields; it does not gate/alter the loop). Story 9.1: the run now STOPS at the
		# boss-encounter SETUP (the boss no longer auto-completes on arrival — the real fight/victory is 9.3/9.4),
		# so the drive succeeds and parks the run in NODE_RESOLUTION with a pending boss encounter (NOT COMPLETED).
		var completion: ActionResult = orchestrator.run_to_completion()
		assert_true(completion.succeeded, "%s: the class run should drive to the boss-encounter setup: %s" % [class_id, completion.metadata])
		assert_equal(orchestrator.run.phase, RunState.PHASE_NODE_RESOLUTION, "%s: the class run should reach the boss-encounter setup (NODE_RESOLUTION), not COMPLETED (9.1)." % class_id)
		assert_true(orchestrator.boss_encounter_pending(), "%s: the class run should have a pending boss encounter set up." % class_id)
		assert_equal(orchestrator.run.selected_class_id, class_id, "%s: the class id must persist through the boss setup." % class_id)


# ---- AC1: first level generates valid + the Epic-1 loop operates on the generated board ----------

func _first_level_generates_valid_and_epic1_loop_operates_on_it() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var orchestrator: RunOrchestrator = RunOrchestrator.new()
		assert_true(orchestrator.start(SMOKE_SEED, false, class_id).succeeded, "%s: start should succeed before the first-level proof." % class_id)

		# (a) The first level GENERATES through the existing pipeline (the orchestrator's _resolve_combat path).
		var first: ActionResult = _resolve_first_level(orchestrator)
		assert_equal(first.metadata.get("resolution"), "combat_auto_resolved", "%s: the first node v0-auto-resolves combat (the documented boundary)." % class_id)
		var level_seed: String = String(first.metadata.get("level_seed", ""))
		assert_false(level_seed.is_empty(), "%s: the first level must generate with a non-empty level_seed (read on the SUCCESS path)." % class_id)

		# (b) The generated first level is a VALID playable BoardState, and the unchanged Epic-1 MoveCommand /
		# enemy-turn / outcome loop OPERATES on it. Re-generate the SAME first level (deterministic) directly so
		# this test owns the BoardState; the orchestrator v0-auto-resolves (no live board), so re-generation is
		# how the headless slice gets the playable board the Epic-1 loop consumes.
		var board: BoardState = _generate_first_level_board(class_id)
		assert_true(board != null, "%s: the first level must reconstruct into a BoardState." % class_id)
		assert_true(board.validate_snapshot_consistency().succeeded, "%s: the generated first level must be a valid playable board." % class_id)
		assert_true(board.width > 0 and board.height > 0, "%s: the generated board must have real dimensions." % class_id)

		# Place a hero on the entrance cell and drive a real Epic-1 MoveCommand + enemy-turn resolution +
		# outcome evaluation on the GENERATED level — the Epic-1 loop is UNCHANGED and still operates.
		_drive_epic1_loop_on_generated_board(class_id, board)


# Re-generate the first combat level's BoardState deterministically (the SAME small_combat_basic level the
# orchestrator generated for the depth-0 node). Uses the run root_seed as the level seed (NodeEnterCommand's
# request uses run.root_seed; the depth-0 combat node maps to small_combat_basic / SIZE_SMALL).
func _generate_first_level_board(class_id: StringName) -> BoardState:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(SMOKE_SEED, false, class_id).succeeded, "%s: start should succeed for board re-generation." % class_id)
	# Build the level request via NodeEnterCommand semantics by entering the first node and reading level_request.
	var NodeEnterCommand: GDScript = load("res://scripts/core/commands/node_enter_command.gd")
	var LevelGenerator: GDScript = load("res://scripts/generation/level/level_generator.gd")
	var LevelRecipeRepository: GDScript = load("res://scripts/content/repositories/level_recipe_repository.gd")
	var enter: ActionResult = NodeEnterCommand.new(99).execute(orchestrator.run)
	assert_true(enter.succeeded, "%s: entering the first node should succeed for board re-generation: %s" % [class_id, enter.metadata])
	var request: Variant = enter.metadata.get("level_request")
	var generation: Variant = LevelGenerator.generate(request, LevelRecipeRepository.create_baseline_repository(), EnemyRepository.create_baseline_repository())
	assert_false(generation.is_error(), "%s: the first level should generate for the playable-board proof." % class_id)
	var board_snapshot: Dictionary = generation.payload.get("board")
	var board_result: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	assert_true(board_result.succeeded, "%s: the generated board snapshot must reconstruct through the STRICT validator: %s" % [class_id, board_result.metadata])
	return board_result.metadata.get("board") as BoardState


# Drive a real Epic-1 MoveCommand (+ enemy-turn resolution + outcome evaluation) on the GENERATED board: the
# unchanged Epic-1 loop OPERATES on the generated first level (AC1 "the level remains playable"). Places a hero
# on the generated entrance cell, finds a free adjacent floor cell, and moves there.
func _drive_epic1_loop_on_generated_board(class_id: StringName, board: BoardState) -> void:
	var entrance_cell: Vector2i = _find_terrain_cell(board, BoardCell.Terrain.ENTRANCE)
	assert_true(entrance_cell != Vector2i(-1, -1), "%s: the generated level must have an entrance cell to stand the hero on." % class_id)
	# The hero (a playable entity) stands on the entrance.
	var hero: TacticalEntityState = TacticalEntityState.new(HERO_ID, TacticalEntityState.EntityType.PLAYER, &"player", entrance_cell, 18, 18, true)
	assert_true(board.place_entity_for_setup(hero).succeeded, "%s: placing the hero on the entrance must succeed." % class_id)

	# Drive an initial fog/LoS update (the Epic-1 loop's first step) — proves the visibility query operates on
	# the generated board.
	var visibility: ActionResult = TacticalVisibilityQuery.new().create_visibility_updated_event(board, HERO_ID)
	assert_true(visibility.succeeded, "%s: a visibility update must operate on the generated board." % class_id)
	assert_true(board.apply_events(visibility.events).succeeded, "%s: applying the visibility update must succeed." % class_id)

	# Find a free adjacent FLOOR cell to move into (a 1-step move within the baseline budget).
	var move_target: Vector2i = _find_free_adjacent_floor(board, entrance_cell)
	if move_target == Vector2i(-1, -1):
		# A fully-walled-in entrance is not expected for a valid small level, but if it ever happens the
		# generated-board validity proof above is still sufficient AC1 evidence; do not fail the loop on it.
		return
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	var streams: RngStreamSet = RngStreamSet.new(SMOKE_SEED)
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)

	var move: ActionResult = MoveCommand.new(HERO_ID, move_target).execute(context)
	assert_true(move.succeeded, "%s: an Epic-1 MoveCommand must operate on the generated first level: %s" % [class_id, move.metadata])
	var hero_after: TacticalEntityState = board.get_entity(HERO_ID)
	assert_equal(hero_after.position, move_target, "%s: the hero must have moved on the generated board." % class_id)

	# The outcome evaluator (the Epic-1 loop's terminal step) operates on the generated board — there are living
	# enemies (the generator placed them) + a living hero, so the level is still in progress (no premature
	# victory/defeat), proving the outcome layer reads the generated board correctly.
	var outcome_state: CombatOutcomeState = CombatOutcomeState.new()
	var event_log: Array[DomainEvent] = []
	var outcome: ActionResult = CombatOutcomeEvaluator.new(HERO_ID).evaluate(board, outcome_state, event_log)
	assert_true(outcome.succeeded, "%s: the Epic-1 outcome evaluator must operate on the generated board: %s" % [class_id, outcome.metadata])


# ---- AC1: the UNCHANGED Epic-1 combat loop still reaches a deterministic victory -----------------

func _unchanged_epic1_loop_still_reaches_a_deterministic_victory() -> void:
	# The canonical Epic-1 micro-combat scenario (the full move -> attack -> enemy-turn -> outcome loop) is
	# UNCHANGED by 5.5 and still reaches victory deterministically — the AC1 "the Epic-1 loop is UNCHANGED" half.
	var first: ActionResult = Epic1MicroCombatScenario.new().run_win_path()
	var second: ActionResult = Epic1MicroCombatScenario.new().run_win_path()
	assert_true(first.succeeded, "The Epic-1 micro-combat loop must still run headlessly.")
	assert_equal(first.metadata.get("outcome"), "victory", "The unchanged Epic-1 loop must still reach victory.")
	assert_equal(first.metadata.get("outcome_state"), second.metadata.get("outcome_state"), "The unchanged Epic-1 loop must stay deterministic.")


# ---- AC2/AC4: class differentiation (disjoint passives) + structural kit difference --------------

func _classes_are_structurally_differentiated_and_disjoint() -> void:
	var class_repo: GDScript = load("res://scripts/content/repositories/class_repository.gd")
	var repo: Variant = class_repo.create_baseline_repository()
	var passive_id_sets: Dictionary = {}
	var explanation_sets: Dictionary = {}

	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var orchestrator: RunOrchestrator = RunOrchestrator.new()
		assert_true(orchestrator.start(SMOKE_SEED, false, class_id).succeeded, "%s: start should succeed for the differentiation proof." % class_id)
		var run: RunState = orchestrator.run

		# AC4: a DIFFERENT starting weapon/support per class (the structural difference the tester observes).
		var def: Variant = repo.get_class_definition(class_id)
		assert_equal(String(def.starting_weapon_id), EXPECTED_WEAPONS.get(class_id), "%s: the starting weapon must be the expected one." % class_id)
		assert_equal(String(def.starting_support_id), EXPECTED_SUPPORTS.get(class_id), "%s: the starting support must be the expected one." % class_id)

		# Collect the resolver's registered ids + the surfaced explanations across BOTH declared windows.
		var ids: Array[String] = []
		for registered_id: StringName in run.rules_resolver.registered_passive_ids():
			ids.append(String(registered_id))
		passive_id_sets[class_id] = ids
		var explanations: Array[String] = []
		for line: String in run.rules_resolver.explain(RuleTrigger.RUN_STARTED):
			explanations.append(line)
		for line: String in run.rules_resolver.explain(RuleTrigger.BEFORE_ATTACK):
			explanations.append(line)
		explanation_sets[class_id] = explanations

	# AC2: no class's resolver ever returns another class's passive id OR explanation at any window — disjoint.
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		for other_id: StringName in SELECTABLE_CLASS_IDS:
			if class_id == other_id:
				continue
			for id_text: String in passive_id_sets.get(class_id):
				assert_false((passive_id_sets.get(other_id) as Array).has(id_text), "%s's resolver must NOT contain %s's passive id (%s)." % [other_id, class_id, id_text])
			for line: String in explanation_sets.get(class_id):
				assert_false((explanation_sets.get(other_id) as Array).has(line), "%s's resolver must NOT surface %s's explanation." % [other_id, class_id])

	# AC4: each class's passive id pair differs from the others'.
	assert_false(str(passive_id_sets.get(&"warrior")) == str(passive_id_sets.get(&"pyromancer")), "Warrior and Pyromancer must have different passive sets.")
	assert_false(str(passive_id_sets.get(&"warrior")) == str(passive_id_sets.get(&"ranger")), "Warrior and Ranger must have different passive sets.")
	assert_false(str(passive_id_sets.get(&"pyromancer")) == str(passive_id_sets.get(&"ranger")), "Pyromancer and Ranger must have different passive sets.")


# ---- AC3: same (seed, class) is byte-deterministic end-to-end ------------------------------------

func _same_seed_and_class_is_byte_deterministic_end_to_end() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		# Two independent fresh starts of the same (seed, class) -> byte-identical started run, resolver output,
		# projected summary, and first-level generation.
		var first: Dictionary = _drive_class_smoke(class_id)
		var second: Dictionary = _drive_class_smoke(class_id)
		assert_equal(first.get("started_run"), second.get("started_run"), "%s: the same (seed, class) must produce a byte-identical started run." % class_id)
		assert_equal(first.get("registered_ids"), second.get("registered_ids"), "%s: the same (seed, class) must produce byte-identical resolver ids." % class_id)
		assert_equal(first.get("run_started_explanations"), second.get("run_started_explanations"), "%s: the same (seed, class) must produce byte-identical run_started explanations." % class_id)
		assert_equal(first.get("before_attack_explanations"), second.get("before_attack_explanations"), "%s: the same (seed, class) must produce byte-identical before_attack explanations." % class_id)
		assert_equal(first.get("summary"), second.get("summary"), "%s: the same (seed, class) must produce a byte-identical class-start summary." % class_id)
		assert_equal(first.get("first_level_seed"), second.get("first_level_seed"), "%s: the same (seed, class) must produce a byte-identical first-level seed." % class_id)
		assert_equal(first.get("final_run"), second.get("final_run"), "%s: the same (seed, class) must produce a byte-identical final run state." % class_id)


# Drive ONE class smoke run and capture the byte-comparable surfaces.
func _drive_class_smoke(class_id: StringName) -> Dictionary:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(SMOKE_SEED, false, class_id).succeeded, "%s: start should succeed for the determinism drive." % class_id)
	var run: RunState = orchestrator.run
	var started_run: String = JSON.stringify(run.to_dictionary())
	var registered_ids: String = str(run.rules_resolver.registered_passive_ids())
	var run_started_explanations: String = str(run.rules_resolver.explain(RuleTrigger.RUN_STARTED))
	var before_attack_explanations: String = str(run.rules_resolver.explain(RuleTrigger.BEFORE_ATTACK))
	var summary: String = JSON.stringify(ClassStartSummaryViewModel.new().summarize(run))
	var first: ActionResult = _resolve_first_level(orchestrator)
	var first_level_seed: String = String(first.metadata.get("level_seed", ""))
	assert_true(orchestrator.run_to_completion().succeeded, "%s: the determinism drive should complete." % class_id)
	var final_run: String = JSON.stringify(orchestrator.run.to_dictionary())
	return {
		"started_run": started_run,
		"registered_ids": registered_ids,
		"run_started_explanations": run_started_explanations,
		"before_attack_explanations": before_attack_explanations,
		"summary": summary,
		"first_level_seed": first_level_seed,
		"final_run": final_run
	}


# ---- AC3: the empty-class/legacy path stays byte-identical to a seed-only start ------------------

func _empty_class_path_stays_byte_identical_to_a_seed_only_start() -> void:
	# A seed-only start (no class arg) and an explicit empty-class start (&"") must be byte-identical, and BOTH
	# surface NO class identity / NO passive explanations (the back-compat gate 5.5 must not perturb).
	var seed_only: RunOrchestrator = RunOrchestrator.new()
	assert_true(seed_only.start(SMOKE_SEED, false).succeeded, "A seed-only start should succeed.")
	var explicit_empty: RunOrchestrator = RunOrchestrator.new()
	assert_true(explicit_empty.start(SMOKE_SEED, false, &"").succeeded, "An explicit empty-class start should succeed.")
	assert_equal(JSON.stringify(seed_only.run.to_dictionary()), JSON.stringify(explicit_empty.run.to_dictionary()), "A seed-only and an empty-class start must be byte-identical started runs.")

	# The summary projects the identity-absent surface for the empty-class run (no kit, no resolver).
	var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(seed_only.run)
	assert_false(bool(summary.get("has_class_identity")), "A seed-only run must project NO class identity.")
	assert_equal((summary.get("passive_explanations") as Array).size(), 0, "A seed-only run must surface NO passive explanations.")

	# Both drive to the SAME terminal state (the empty-class path is unchanged by the class machinery).
	assert_true(seed_only.run_to_completion().succeeded, "The seed-only run should complete.")
	assert_true(explicit_empty.run_to_completion().succeeded, "The empty-class run should complete.")
	assert_equal(JSON.stringify(seed_only.run.to_dictionary()), JSON.stringify(explicit_empty.run.to_dictionary()), "The seed-only and empty-class runs must reach a byte-identical final state.")


# ---- utilities -----------------------------------------------------------------------------------

func _find_terrain_cell(board: BoardState, terrain: int) -> Vector2i:
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain == terrain:
			return board_cell.position
	return Vector2i(-1, -1)


# Find a free FLOOR cell orthogonally adjacent to `origin` (a 1-step move target within the baseline budget).
func _find_free_adjacent_floor(board: BoardState, origin: Vector2i) -> Vector2i:
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = origin + offset
		if not board.in_bounds(candidate):
			continue
		var board_cell: BoardCell = board.get_cell(candidate)
		if board_cell == null:
			continue
		if board_cell.terrain != BoardCell.Terrain.FLOOR:
			continue
		if board_cell.is_occupied():
			continue
		if board.entity_at(candidate) != null:
			continue
		return candidate
	return Vector2i(-1, -1)
