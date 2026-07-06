extends "res://tests/unit/test_case.gd"

# Story 11.2 (AC1/AC4) — LiveCombatResolver: the SCENE-FREE LIVE COMBAT DRIVER that resolves a generated combat level to a
# TERMINAL CombatOutcomeState (STATE_VICTORY / STATE_DEFEAT) from REAL tactical play on the board (a scripted hero driving
# MoveCommand/AttackCommand + the existing EnemyTurnResolver + CombatOutcomeEvaluator), NOT the v0 auto-resolve-to-success.
#
# Covers:
#   - AC1 — a live VICTORY: a strong hero drives the fight to a real STATE_VICTORY (all enemies dead), the outcome coming
#           from the BOARD (living-enemy count 0), not from "the level generated".
#   - AC2 (the resolver half) — a live DEFEAT: a weak (1 HP) hero is felled by the real enemy turns to a real STATE_DEFEAT
#           (hero at 0 HP), the live hero-death detection the run-end SOURCE keys off.
#   - AC4 — DETERMINISM: the SAME (seed, loadout) -> the SAME terminal outcome + the SAME round count + a byte-identical
#           event log (no randi/randf — the loop draws gameplay RNG ONLY through the injected run-level RngStreamSet; the
#           default sword/staff hero draws ZERO combat RNG so the injected stream is untouched).
#   - a degenerate zero-enemy board resolves to an immediate victory (never enters a hero turn needing a target).
#   - a rejected board snapshot / an unknown hero weapon surface structured errors (no fabricated outcome).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")

# A canonical seed whose generated Small combat board a strong sword hero clears (verified), and which a 1-HP hero loses.
const VICTORY_SEED: int = 4242
# A second verified winning seed (the AC1 test drives two independent seeds to a real board victory).
const SECOND_VICTORY_SEED: int = 99

func run() -> Dictionary:
	_live_victory_comes_from_the_board_outcome()
	_live_defeat_comes_from_a_real_hero_death()
	_resolution_is_byte_deterministic_for_a_fixed_seed()
	_default_hero_draws_zero_combat_rng()
	_zero_enemy_board_is_an_immediate_victory()
	_rejects_a_corrupt_board_snapshot()
	_rejects_an_unknown_hero_weapon()
	# Story 11.4 (AC1) — the LIVE Scorched affinity call site on the live board.
	_neutral_affinity_is_byte_identical_to_the_plain_live_combat()
	_scorched_stamps_hazard_cells_and_ticks_the_burning_dot()
	_scorched_live_effect_is_byte_deterministic_and_zero_rng()
	_scorched_dot_kills_a_lingering_hero_through_the_board_death_source()
	_non_scorched_affinity_stamps_no_terrain_and_ticks_no_dot()
	# Story 11.4 (Round-2 L4) — the L1 refactor's own protected path: a PRE-STAMPED Scorched board still ticks.
	_pre_stamped_scorched_board_still_ticks_the_dot()
	return result()


# ---- AC1: a live VICTORY is decided by the board outcome -------------------------------------------

func _live_victory_comes_from_the_board_outcome() -> void:
	for seed_value: int in [VICTORY_SEED, SECOND_VICTORY_SEED]:
		var generation: GenerationResult = _generate_small_combat(seed_value)
		assert_true(generation.succeeded, "Setup: seed %d should generate a Small combat level." % seed_value)
		# Confirm the generated board actually carries enemies (a real fight, not a walkover-by-emptiness).
		var enemy_count: int = _enemy_count(generation.payload.get("board", {}))
		assert_true(enemy_count >= 1, "Setup: seed %d should place at least one enemy (a real fight)." % seed_value)

		var streams: RngStreamSet = RngStreamSet.new(seed_value)
		var result_value: ActionResult = LiveCombatResolver.new().resolve(
			generation.payload.get("board", {}), generation.payload.get("entrance", {}), streams
		)
		assert_true(result_value.succeeded, "seed %d: a strong hero should resolve the fight: %s" % [seed_value, result_value.metadata])
		assert_true(bool(result_value.metadata.get("is_victory")), "seed %d: the outcome should be a live VICTORY." % seed_value)
		assert_equal(String(result_value.metadata.get("outcome")), CombatOutcomeState.STATE_VICTORY, "seed %d: the terminal outcome_state is victory." % seed_value)
		# The board decided it: the live board has ZERO living enemies (the CombatOutcomeEvaluator victory condition), NOT
		# a "level generated" flag.
		var board = result_value.metadata.get("board")
		assert_equal(_living_enemy_count(board), 0, "seed %d: a live victory leaves ZERO living enemies on the board." % seed_value)
		assert_true(board.get_entity(&"hero").is_alive(), "seed %d: the hero survives a victory." % seed_value)


# ---- AC2 (resolver half): a live DEFEAT is a real hero death --------------------------------------

func _live_defeat_comes_from_a_real_hero_death() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	assert_true(generation.succeeded, "Setup: the level should generate.")

	# A 1-HP dagger hero is felled by the real enemy turns (the enemies advance + strike) — a real board DEFEAT.
	var streams: RngStreamSet = RngStreamSet.new(VICTORY_SEED)
	var result_value: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), streams, 1, &"dagger"
	)
	assert_true(result_value.succeeded, "A 1-HP hero fight should resolve (to a defeat): %s" % result_value.metadata)
	assert_true(bool(result_value.metadata.get("is_defeat")), "A 1-HP hero should be DEFEATED by the real enemy turns.")
	assert_equal(String(result_value.metadata.get("outcome")), CombatOutcomeState.STATE_DEFEAT, "The terminal outcome_state is defeat.")
	# The board decided it: the hero is DEAD (0 HP) on the live board — the hero-0-HP detection the run-end SOURCE keys off.
	var board = result_value.metadata.get("board")
	assert_true(board.get_entity(&"hero").is_dead(), "A live defeat leaves the hero DEAD (0 HP) on the board — the live hero-death detection.")


# ---- AC4: byte-determinism for a fixed seed -------------------------------------------------------

func _resolution_is_byte_deterministic_for_a_fixed_seed() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var first: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)
	)
	var second: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)
	)
	assert_true(first.succeeded and second.succeeded, "Both live resolutions should succeed.")
	assert_equal(String(first.metadata.get("outcome")), String(second.metadata.get("outcome")), "The same seed must produce the same outcome.")
	assert_equal(int(first.metadata.get("rounds")), int(second.metadata.get("rounds")), "The same seed must produce the same round count.")
	# The event log is byte-identical (JSON round-trip of every event dict).
	assert_equal(_event_dicts(first.events), _event_dicts(second.events), "The same seed must produce a byte-identical live-combat event log.")


func _default_hero_draws_zero_combat_rng() -> void:
	# The DEFAULT hero (sword, no proc, no shield) draws ZERO `combat` RNG — the injected run-level stream set is
	# byte-identical before/after a full live victory. This is the determinism guard: the live loop does not perturb the
	# stream advancement the non-live route-position save depends on (beyond what generation already drew).
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var streams: RngStreamSet = RngStreamSet.new(VICTORY_SEED)
	var before: Dictionary = streams.to_snapshot()
	var result_value: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), streams
	)
	assert_true(result_value.succeeded and bool(result_value.metadata.get("is_victory")), "Setup: the default hero should win.")
	assert_equal(streams.to_snapshot(), before, "The default sword hero must draw ZERO RNG (the injected stream set is unchanged).")


# ---- edge + error paths ---------------------------------------------------------------------------

func _zero_enemy_board_is_an_immediate_victory() -> void:
	# A degenerate board with NO enemies is already a victory (the evaluator's living_enemy_count == 0) — the loop never
	# needs a hero action. Hand-build a minimal 3x3 board snapshot with only floor + an entrance cell.
	var snapshot: Dictionary = _empty_board_snapshot()
	var streams: RngStreamSet = RngStreamSet.new(1)
	var result_value: ActionResult = LiveCombatResolver.new().resolve(snapshot, {"x": 0, "y": 1}, streams)
	assert_true(result_value.succeeded, "A zero-enemy board should resolve: %s" % result_value.metadata)
	assert_true(bool(result_value.metadata.get("is_victory")), "A zero-enemy board is an immediate victory.")
	assert_equal(int(result_value.metadata.get("rounds")), 0, "A zero-enemy victory takes ZERO rounds (decided before any hero turn).")


func _rejects_a_corrupt_board_snapshot() -> void:
	var result_value: ActionResult = LiveCombatResolver.new().resolve({"width": 3}, {"x": 0, "y": 0}, RngStreamSet.new(1))
	assert_true(result_value.is_error(), "A corrupt board snapshot must be rejected (no fabricated outcome).")
	assert_equal(result_value.error_code, &"invalid_board_snapshot", "A rejected board uses the stable invalid_board_snapshot code.")


func _rejects_an_unknown_hero_weapon() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var result_value: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(1), 40, &"not_a_weapon"
	)
	assert_true(result_value.is_error(), "An unknown hero weapon must be rejected.")
	assert_equal(result_value.error_code, &"unknown_hero_weapon", "A missing weapon uses the stable unknown_hero_weapon code.")


# ---- Story 11.4 (AC1): the live Scorched affinity call site ---------------------------------------

# A neutral `none` affinity + a real repo is BYTE-IDENTICAL to the plain 11.2/11.3 call (no affinity params): no HAZARD
# stamped, the SAME terminal outcome, round count, and event log. This is the fingerprint-safety guard — a neutral level
# does not perturb the live combat the 11.2/11.3 tests pin.
func _neutral_affinity_is_byte_identical_to_the_plain_live_combat() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var plain: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)
	)
	var neutral: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED),
		60, &"sword", &"none", AffinityRepository.create_baseline_repository()
	)
	assert_true(plain.succeeded and neutral.succeeded, "Both the plain + neutral-affinity live fights should resolve.")
	assert_equal(int(plain.metadata.get("rounds")), int(neutral.metadata.get("rounds")), "A neutral `none` affinity takes the SAME rounds as the plain live combat.")
	assert_equal(_event_dicts(plain.events), _event_dicts(neutral.events), "A neutral `none` affinity is BYTE-IDENTICAL to the plain live combat (no affinity effect perturbs it).")
	# No HAZARD terrain was stamped on the neutral board.
	assert_equal(_hazard_cell_count(neutral.metadata.get("board")), 0, "A neutral live board carries ZERO stamped HAZARD cells.")


# Scorched STAMPS HAZARD cells onto the live board (the AffinityEffectResolver effect surface) + the burning DoT fires
# for an entity that ends a turn on a hazard cell — a DAMAGE_APPLIED(damage_type=burning, weapon_id=scorched_hazard)
# event with the fixed amount, ZERO RNG. Proven on the verified victory seed (the fight still reaches a real board
# victory — the DoT does not break the scripted driver).
func _scorched_stamps_hazard_cells_and_ticks_the_burning_dot() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var result_value: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED),
		60, &"sword", &"scorched", AffinityRepository.create_baseline_repository()
	)
	assert_true(result_value.succeeded, "A Scorched live fight should resolve: %s" % result_value.metadata)
	assert_true(bool(result_value.metadata.get("is_victory")), "The Scorched fight still reaches a real board victory (the DoT does not stall the driver).")
	# The live board carries STAMPED Scorched HAZARD cells (the effect surface applied BEFORE the fight).
	assert_true(_hazard_cell_count(result_value.metadata.get("board")) > 0, "Scorched STAMPS HAZARD cells onto the live board.")
	# The burning DoT fired: at least one DAMAGE_APPLIED(burning, scorched_hazard, fixed amount) event is in the log.
	var burning: Array = _burning_events(result_value.events)
	assert_true(burning.size() > 0, "The Scorched burning DoT fires for an entity that ends a turn on a hazard cell.")
	var first: Dictionary = burning[0]
	assert_equal(String(first.get("weapon_id", "")), "scorched_hazard", "The burning DoT names the Scorched hazard source (scorched_hazard).")
	assert_equal(int(first.get("final_damage", 0)), 2, "The burning DoT deals the FIXED authored amount (2 — no RNG).")
	assert_true((first.get("rng_draws", []) as Array).is_empty(), "The burning DoT draws ZERO RNG (rng_draws is empty).")


# The Scorched live effect is BYTE-DETERMINISTIC (same seed -> same effect cells + same events + same rounds) and draws
# ZERO gameplay RNG (the injected stream is unchanged — the assignment draw is the orchestrator's, the effects are
# ZERO-RNG). The FR57 determinism guard for the live affinity path.
func _scorched_live_effect_is_byte_deterministic_and_zero_rng() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var repo: AffinityRepository = AffinityRepository.create_baseline_repository()
	var first: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED), 60, &"sword", &"scorched", repo
	)
	var second: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED), 60, &"sword", &"scorched", repo
	)
	assert_equal(_event_dicts(first.events), _event_dicts(second.events), "A fixed seed produces a BYTE-IDENTICAL Scorched live-affinity event log (FR57).")
	assert_equal(int(first.metadata.get("rounds")), int(second.metadata.get("rounds")), "A fixed seed produces the same Scorched round count.")
	# Zero gameplay RNG: the injected run-level stream set is unchanged by the Scorched effect + DoT.
	var streams: RngStreamSet = RngStreamSet.new(VICTORY_SEED)
	var before: Dictionary = streams.to_snapshot()
	LiveCombatResolver.new().resolve(generation.payload.get("board", {}), generation.payload.get("entrance", {}), streams, 60, &"sword", &"scorched", repo)
	assert_equal(streams.to_snapshot(), before, "The Scorched effect + burning DoT draw ZERO RNG (the injected stream is unchanged).")


# A hero that lingers in Scorched fire BURNS TO DEATH — the DoT death flows through the board (0 HP) to a real
# STATE_DEFEAT (the 11.2 hero-death source), NOT a parallel death path. A hand-built board forces the low-HP hero to
# stand on a hazard cell adjacent to the entrance to reach the enemy.
func _scorched_dot_kills_a_lingering_hero_through_the_board_death_source() -> void:
	# A 3x1-interior corridor: entrance(1,1) - hazard-eligible(2,1) - enemy(3,1). The even-parity cell (2,1) is stamped
	# HAZARD by Scorched; a 1-HP hero stepping onto it to approach the enemy burns to death (2 dmg > 1 HP).
	var snapshot: Dictionary = _scorched_corridor_snapshot()
	var result_value: ActionResult = LiveCombatResolver.new().resolve(
		snapshot, {"x": 1, "y": 1}, RngStreamSet.new(7), 1, &"sword", &"scorched", AffinityRepository.create_baseline_repository()
	)
	assert_true(result_value.succeeded, "The Scorched corridor fight should resolve (to a defeat): %s" % result_value.metadata)
	assert_true(bool(result_value.metadata.get("is_defeat")), "A 1-HP hero that steps into Scorched fire is DEFEATED (the DoT kills it).")
	var board = result_value.metadata.get("board")
	assert_true(board.get_entity(&"hero").is_dead(), "The DoT death leaves the hero DEAD (0 HP) on the board — the 11.2 hero-death source.")
	# The killing blow was a burning DoT event (not an enemy attack).
	var burning: Array = _burning_events(result_value.events)
	assert_true(burning.size() > 0, "A burning DoT event fired (the Scorched fire, not an enemy, is a death source).")


# A non-Scorched affinity (Flooded/Cursed/Darkness) stamps NO terrain (their effects are data/kernel/visibility) and
# ticks NO DoT — the live board terrain + event log match the neutral live combat.
func _non_scorched_affinity_stamps_no_terrain_and_ticks_no_dot() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var repo: AffinityRepository = AffinityRepository.create_baseline_repository()
	for affinity_id: StringName in [&"flooded_conductive", &"cursed", &"darkness"]:
		var result_value: ActionResult = LiveCombatResolver.new().resolve(
			generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED), 60, &"sword", affinity_id, repo
		)
		assert_true(result_value.succeeded, "A %s live fight should resolve." % affinity_id)
		assert_equal(_hazard_cell_count(result_value.metadata.get("board")), 0, "%s stamps NO terrain (no HAZARD cells)." % affinity_id)
		assert_equal(_burning_events(result_value.events).size(), 0, "%s ticks NO burning DoT (only Scorched stamps hazards)." % affinity_id)


# Story 11.4 (Round-2 L4) — pin the L1 refactor's PROTECTED PATH: a PRE-STAMPED Scorched board still ticks the DoT.
# The Round-1 L1 fix rederived `_scorched_hazard_active` from the affinity effect PLAN (resolve_board_plan's
# scorched_hazard_cells — which INCLUDES cells already Terrain.HAZARD) rather than from apply_board_effects' stamped-DIFF,
# so the burning DoT still fires when `resolve` is handed a board whose Scorched cells are ALREADY HAZARD (the empty-diff
# condition, where the OLD diff-based flag would have gone false and silently disabled the DoT). Every other Scorched
# test starts from a fresh all-FLOOR restore, so the first stamp always yields a non-empty diff — the old and new
# implementations are indistinguishable there. This test resolves TWICE against the SAME already-stamped Scorched board
# state and asserts the second resolve STILL ticks, proving the plan-derived flag is stamp-invariant.
func _pre_stamped_scorched_board_still_ticks_the_dot() -> void:
	var repo: AffinityRepository = AffinityRepository.create_baseline_repository()

	# First resolve on the fresh all-FLOOR corridor (a 1-HP hero that steps into Scorched fire burns) — the ordinary
	# path, which stamps the even-parity HAZARD cell(s) and ticks. Establishes the baseline that Scorched fires here.
	var first: ActionResult = LiveCombatResolver.new().resolve(
		_scorched_corridor_snapshot(), {"x": 1, "y": 1}, RngStreamSet.new(7), 1, &"sword", &"scorched", repo
	)
	assert_true(first.succeeded, "Setup: the first Scorched corridor resolve should succeed: %s" % first.metadata)
	assert_true(_burning_events(first.events).size() > 0, "Setup: the first (fresh-board) Scorched resolve ticks the burning DoT.")

	# Build the SAME board, already Scorched-STAMPED: restore the corridor board, apply the Scorched effect to stamp its
	# HAZARD cells, then snapshot it back out. This snapshot's Scorched cells are ALREADY Terrain.HAZARD.
	var restore: ActionResult = BoardState.try_from_snapshot(_scorched_corridor_snapshot())
	assert_true(restore.succeeded, "Setup: the corridor board should restore.")
	var stamped_board: BoardState = restore.metadata.get("board") as BoardState
	var stamp: ActionResult = AffinityEffectResolver.new().apply_board_effects(stamped_board, &"scorched", repo)
	assert_true(stamp.succeeded, "Setup: the Scorched effect should stamp the corridor board.")
	assert_true((stamp.metadata.get("stamped_hazard_cells", []) as Array).size() > 0, "Setup: the first stamp marks at least one HAZARD cell.")
	assert_true(_hazard_cell_count(stamped_board) > 0, "Setup: the pre-stamped board carries Scorched HAZARD cells.")
	var pre_stamped_snapshot: Dictionary = stamped_board.to_snapshot()

	# The EXACT empty-diff condition the L1 refactor protects: re-applying Scorched to a board restored from the
	# already-stamped snapshot stamps NOTHING new (every Scorched cell is already HAZARD, so apply's stamped diff is
	# EMPTY) — the case where the OLD diff-based flag would have gone false and silently disabled the DoT.
	var re_restore: ActionResult = BoardState.try_from_snapshot(pre_stamped_snapshot)
	assert_true(re_restore.succeeded, "Setup: the pre-stamped board should re-restore.")
	var re_apply: ActionResult = AffinityEffectResolver.new().apply_board_effects(re_restore.metadata.get("board") as BoardState, &"scorched", repo)
	assert_true(re_apply.succeeded, "Setup: re-applying Scorched to the pre-stamped board succeeds.")
	assert_equal((re_apply.metadata.get("stamped_hazard_cells", []) as Array).size(), 0, "The pre-stamped board yields an EMPTY apply diff (every Scorched cell is already HAZARD) — the empty-diff condition L1 targets.")

	# The PROTECTED PATH: resolve on the PRE-STAMPED Scorched snapshot. Despite the empty apply-diff, the plan-derived
	# `_scorched_hazard_active` is TRUE (resolve_board_plan reports the already-HAZARD cells as plan-eligible), so the
	# burning DoT STILL ticks — proving the flag is stamp-invariant (a pre-stamped/memoized Scorched board is not
	# silently de-fanged).
	var second: ActionResult = LiveCombatResolver.new().resolve(
		pre_stamped_snapshot, {"x": 1, "y": 1}, RngStreamSet.new(7), 1, &"sword", &"scorched", repo
	)
	assert_true(second.succeeded, "The pre-stamped Scorched resolve should succeed: %s" % second.metadata)
	var burning: Array = _burning_events(second.events)
	assert_true(burning.size() > 0, "A PRE-STAMPED Scorched board STILL ticks the burning DoT (the plan-derived flag is stamp-invariant — L1's protected path).")
	assert_equal(String((burning[0] as Dictionary).get("weapon_id", "")), "scorched_hazard", "The pre-stamped DoT names the Scorched hazard source (scorched_hazard).")
	assert_equal(int((burning[0] as Dictionary).get("final_damage", 0)), 2, "The pre-stamped DoT deals the FIXED authored amount (2 — no RNG).")


# ---- helpers -------------------------------------------------------------------------------------

func _generate_small_combat(seed_value: int) -> GenerationResult:
	var request: GenerationRequest = GenerationRequest.new(seed_value, &"node_1_0", &"combat", &"small_combat_basic", GenerationRequest.SIZE_SMALL)
	return LevelGenerator.generate(request, LevelRecipeRepository.create_baseline_repository(), EnemyRepository.create_baseline_repository())


func _enemy_count(board_snapshot: Dictionary) -> int:
	var count: int = 0
	for entity_value: Variant in board_snapshot.get("entities", []):
		if String((entity_value as Dictionary).get("entity_type", "")) == "enemy":
			count += 1
	return count


func _living_enemy_count(board) -> int:
	var count: int = 0
	for entity in board.entities():
		if entity.entity_type == entity.EntityType.ENEMY and entity.is_alive():
			count += 1
	return count


func _empty_board_snapshot() -> Dictionary:
	# A minimal valid all-floor board (no entities), built through CreateBoardCommand so the snapshot shape is exactly the
	# real BoardState.to_snapshot() shape (nested position cells, etc.) — never a hand-mangled dict.
	var board: BoardState = BoardState.new()
	var create_result: ActionResult = CreateBoardCommand.new(3, 3).execute(board)
	assert_true(create_result.succeeded, "Setup: the empty board should build.")
	return board.to_snapshot()


func _event_dicts(events: Array) -> Array:
	var out: Array = []
	for event_value: Variant in events:
		if event_value is DomainEvent:
			out.append((event_value as DomainEvent).to_dictionary())
	return out


# Story 11.4 helpers -------------------------------------------------------------------------------

# The count of Terrain.HAZARD cells on a live board (the Scorched effect stamps these; a neutral / non-Scorched board
# has zero).
func _hazard_cell_count(board) -> int:
	var count: int = 0
	if board == null:
		return 0
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain == BoardCell.Terrain.HAZARD:
			count += 1
	return count


# The burning DoT DAMAGE_APPLIED event payloads in a live-combat log (the Scorched hazard ticks). Filters on
# damage_type == burning (the AffinityHazardDamageCommand marker).
func _burning_events(events: Array) -> Array:
	var out: Array = []
	for event_value: Variant in events:
		if not event_value is DomainEvent:
			continue
		var event: DomainEvent = event_value
		if String(event.payload.get("damage_type", "")) == "burning":
			out.append(event.payload)
	return out


# A hand-built 5x3 board (WALL border, a 3-cell FLOOR corridor row: entrance(1,1) - floor(2,1) - enemy(3,1)). The even-
# parity cell (2,1) ((2+1)=3 is odd — so NOT even; adjust: entrance(1,1) parity even, (2,1) parity odd, (3,1) parity
# even). Scorched stamps EVEN-parity eligible FLOOR cells, so (3,1) (the enemy cell) is occupied (excluded); (1,1) is
# ENTRANCE (excluded). Use a 7-wide corridor so an EVEN-parity FLOOR cell sits on the hero's path to the enemy.
func _scorched_corridor_snapshot() -> Dictionary:
	# Layout (width 7, height 3): row 1 is the corridor. entrance(1,1); floor (2,1),(3,1),(4,1),(5,1); enemy at (5,1).
	# EVEN-parity FLOOR cells on the corridor: (3,1) ((3+1)=4 even) — the hero must step through it to reach the enemy.
	var width: int = 7
	var height: int = 3
	var enemy: Dictionary = {
		"entity_id": "enemy_a",
		"entity_type": "enemy",
		"faction": "labyrinth",
		"position": {"x": 5, "y": 1},
		"current_hp": 10,
		"max_hp": 10,
		"blocks_movement": true,
		"definition_id": "iron_cultist"
	}
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == 1:
				terrain = BoardCell.Terrain.ENTRANCE
			var occupant: String = "enemy_a" if (x == 5 and y == 1) else ""
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": terrain,
				"occupant_id": occupant,
				"explored": true,
				"visible": true
			})
	return {
		"width": width,
		"height": height,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": [enemy]
	}
