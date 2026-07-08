extends "res://tests/unit/test_case.gd"

# Story 12.2 (AC2/AC3/AC4) — ReferenceCombatDriver: the STRENGTHENED, LoS-AWARE WINNABILITY PROOF HARNESS (retro T2).
# It reuses the SAME building blocks LiveCombatResolver composes (board restore / affinity apply / per-action enemy phase
# / Scorched DoT / CombatOutcomeEvaluator) but drives a smarter hero (detonation-dodging + ranged kiting + melee commit)
# so the CLASS-KIT loadout (all three MVP classes at baseline_hp 18) WINS an approved combat seed where the naive
# focus-fire LiveCombatResolver driver DIES.
#
# Covers:
#   - AC2 — the APPROVED live-combat seed catalog (an INLINE annotated code const — the finale APPROVED_*_SEED_CATALOG
#           discipline, NOT a JSON / tools/dump_* artifact) is WINNABLE by every playable class: for each approved seed
#           x each class (warrior sword+shield / pyromancer staff+tome / ranger bow), the driver reaches STATE_VICTORY
#           within the round cap with the 18-HP class loadout.
#   - AC2 — the FAIL-LOUD triage path: a deliberately-unwinnable (sealed) fixture returns the structured
#           live_combat_did_not_resolve (seed + reason surfaced), never a fabricated outcome.
#   - AC2 — the naive focus-fire LiveCombatResolver PROVABLY DIES at 18 HP where the strengthened driver wins (the
#           winnability tension the story pins — an HP swap alone fails; the strengthened driver is required).
#   - AC4 — DETERMINISM: the SAME (seed, class) -> the SAME terminal outcome + round count + a byte-identical event log.
#   - AC4 — the ranger (no support, no-proc bow) draws ZERO `combat` RNG; the warrior shield ENGAGES the seeded
#           shield_block roll on the `combat` stream — on INCOMING enemy attacks, the shield-protects-its-OWNER seam (the
#           block draw runs on the enemy phase and is synced back to the run-level stream); RngStreamSet.required_streams()
#           stays 7 (no new stream / draw site).
#   - AC3 — per-class DISTINCTNESS on the SAME seed: warrior fights emit shield_block combat rolls (a block on incoming
#           enemy hits); pyromancer fights emit tome +1 bonus damage (on the hero's own attacks); ranger fights emit
#           neither — a demonstrable, non-cosmetic per-class difference (the direct input to 10.4's class-comparison AC).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const ReferenceCombatDriver = preload("res://scripts/run/reference_combat_driver.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")

# AC2 — the APPROVED live-combat seed catalog (the finale APPROVED_BOSS_SEED_CATALOG discipline: an INLINE annotated code
# const, KEPT + documented, NOT a dump-tool artifact). Each seed's depth-0-style Small combat board is WINNABLE by all
# three playable classes at 18 HP via the strengthened driver — the winnability proof input to Story 10.4 / the 10.6
# die-or-win gate. Seed 4242 is the canonical live-combat seed (test_live_run_flow.gd LIVE_SEED). Each entry documents
# the enemy mix + the tactical read the seed exercises.
const APPROVED_LIVE_COMBAT_SEED_CATALOG: Array[Dictionary] = [
	{
		"seed": 4242,
		"notes": "Canonical live-combat seed (test_live_run_flow LIVE_SEED). 1 iron_cultist + 2 ash_seers. The warrior isolates + kills the lone melee body (~9 HP lost) then mops up the stationary seers dodging every mark; the ranged classes open fire from range. The naive focus-fire sword driver DIES here at 18 HP. KEPT (canonical)."
	},
	{
		"seed": 8080,
		"notes": "1 iron_cultist + 2 ash_seers, spread layout. The warrior's longest approved clear (~33 rounds) — the melee commit + full seer mop-up. Exercises a longer mark-dodge tail. KEPT (warrior-stress)."
	},
	{
		"seed": 6006,
		"notes": "2 melee + 1 seer. The warrior fights the melee bodies one-at-a-time (never voluntarily surrounded); the ranged classes kite the melee pair. A representative two-melee clear. KEPT (representative)."
	},
	{
		"seed": 2048,
		"notes": "Mixed melee + seer mix. A mid-length clear for all three classes; exercises the ranged firing-line alignment + the melee commit under seer pressure. KEPT (representative)."
	},
	{
		"seed": 512,
		"notes": "A compact clear (pyromancer 5 rounds / ranger 7) with a longer warrior melee grind (~22). Proves a fast ranged clear and a slow-but-winnable melee clear on the same seed. KEPT (ranged-fast)."
	}
]

# The three playable classes' live loadouts (the class_repository baseline kits): weapon + support id. All at 18 HP.
const PLAYABLE_CLASSES: Array[Dictionary] = [
	{"class_id": "warrior", "weapon_id": &"sword", "support_id": &"shield"},
	{"class_id": "pyromancer", "weapon_id": &"staff", "support_id": &"tome"},
	{"class_id": "ranger", "weapon_id": &"bow", "support_id": &"none"}
]

const CLASS_HP: int = 18

func run() -> Dictionary:
	_every_approved_seed_is_winnable_by_every_class()
	_naive_focus_fire_dies_at_18_where_the_strengthened_driver_wins()
	_an_unwinnable_seed_fails_loud_for_triage()
	_resolution_is_byte_deterministic_per_seed_and_class()
	_ranger_draws_zero_combat_rng_and_warrior_shield_engages_the_combat_stream()
	_no_new_rng_stream_is_added()
	_the_three_classes_are_tactically_distinct_on_the_same_seed()
	_rejects_a_corrupt_board_snapshot_and_unknown_weapon()
	return result()


# ---- AC2: every approved seed is winnable by every playable class ---------------------------------

func _every_approved_seed_is_winnable_by_every_class() -> void:
	var supports: SupportRepository = SupportRepository.create_baseline_repository()
	for entry: Dictionary in APPROVED_LIVE_COMBAT_SEED_CATALOG:
		var seed_value: int = int(entry["seed"])
		var generation: GenerationResult = _generate(seed_value)
		assert_true(generation.succeeded, "Setup: approved seed %d should generate a Small combat level." % seed_value)
		assert_true(_enemy_count(generation.payload.get("board", {})) >= 1, "Setup: approved seed %d places at least one enemy (a real fight)." % seed_value)
		for playable: Dictionary in PLAYABLE_CLASSES:
			var result_value: ActionResult = _drive(generation, seed_value, playable, supports)
			# A failing seed x class is a HARD combat error carrying seed + class + reason (the AC2 fail-loud contract) —
			# surfaced in the assert message for triage BEFORE Story 10.4.
			assert_true(
				result_value.succeeded,
				"seed=%d class=%s reason=%s — the strengthened driver must WIN (not %s)" % [
					seed_value, String(playable["class_id"]), String(result_value.error_code), String(result_value.error_code)
				]
			)
			assert_true(
				bool(result_value.metadata.get("is_victory")),
				"seed=%d class=%s: the driver must reach STATE_VICTORY (got outcome=%s rounds=%d)" % [
					seed_value, String(playable["class_id"]), String(result_value.metadata.get("outcome")), int(result_value.metadata.get("rounds"))
				]
			)
			assert_equal(String(result_value.metadata.get("outcome")), CombatOutcomeState.STATE_VICTORY, "seed=%d class=%s: terminal outcome_state is victory." % [seed_value, String(playable["class_id"])])
			# The board decided it (ZERO living enemies), and the hero survived (a real board victory, not a fabricated one).
			var board = result_value.metadata.get("board")
			assert_equal(_living_enemy_count(board), 0, "seed=%d class=%s: a victory leaves ZERO living enemies." % [seed_value, String(playable["class_id"])])
			assert_true(board.get_entity(&"hero").is_alive(), "seed=%d class=%s: the hero survives the victory." % [seed_value, String(playable["class_id"])])


# ---- AC2: the winnability TENSION — the naive driver dies at 18 where the strengthened driver wins ----

func _naive_focus_fire_dies_at_18_where_the_strengthened_driver_wins() -> void:
	# The story's pinned winnability tension: threading baseline_hp (18) into the NAIVE focus-fire LiveCombatResolver
	# reproduces the 11.3 mid-walk death (the sword hero closes to melee + eats seer detonations). The strengthened
	# ReferenceCombatDriver WINS the same seed + loadout. An HP swap alone fails loud — the strengthened driver is
	# REQUIRED. Proven on the canonical seed 4242 with the warrior sword loadout.
	var generation: GenerationResult = _generate(4242)
	var naive: ActionResult = LiveCombatResolver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(4242), CLASS_HP, &"sword"
	)
	assert_true(naive.succeeded, "Setup: the naive resolve should complete (to a defeat).")
	assert_true(bool(naive.metadata.get("is_defeat")), "The NAIVE focus-fire driver DIES at 18 HP on seed 4242 (the 11.3 lesson — an HP swap alone fails).")

	var strengthened: ActionResult = ReferenceCombatDriver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(4242), CLASS_HP, &"sword",
		AffinityDefinition.AFFINITY_NONE, null,
		SupportRepository.create_baseline_repository().get_support(&"shield")
	)
	assert_true(strengthened.succeeded and bool(strengthened.metadata.get("is_victory")), "The STRENGTHENED driver WINS the same seed + 18-HP warrior loadout (the retro-T2 winnable hero).")


# ---- AC2: the fail-loud triage path ---------------------------------------------------------------

func _an_unwinnable_seed_fails_loud_for_triage() -> void:
	# A deliberately-unwinnable (sealed) fixture: the hero (left room) and the enemy (right room) are split by a full
	# WALL column with no gap — the hero can neither path to nor shoot the enemy, so the fight never resolves and hits
	# the round cap. The driver FAILS LOUD (live_combat_did_not_resolve carrying the round count), never a fabricated
	# outcome — the triage path a caller treats as a hard combat error (like a generation failure).
	var result_value: ActionResult = ReferenceCombatDriver.new().resolve(
		_sealed_snapshot(), {"x": 1, "y": 1}, RngStreamSet.new(1), CLASS_HP, &"sword"
	)
	assert_true(result_value.is_error(), "An unwinnable (sealed) fixture must FAIL LOUD (never a fabricated outcome).")
	assert_equal(result_value.error_code, &"live_combat_did_not_resolve", "The fail-loud uses the stable live_combat_did_not_resolve code (the triage signal).")
	assert_true(int(result_value.metadata.get("rounds", 0)) >= 1, "The fail-loud carries the round count reached (for triage).")


# ---- AC4: byte-determinism per seed + class -------------------------------------------------------

func _resolution_is_byte_deterministic_per_seed_and_class() -> void:
	var supports: SupportRepository = SupportRepository.create_baseline_repository()
	# Prove determinism across the FULL catalog x every class (the same seed + class -> same outcome + rounds + a
	# byte-identical event log). This is the FR57 determinism guard for the proof harness.
	for entry: Dictionary in APPROVED_LIVE_COMBAT_SEED_CATALOG:
		var seed_value: int = int(entry["seed"])
		var generation: GenerationResult = _generate(seed_value)
		for playable: Dictionary in PLAYABLE_CLASSES:
			var first: ActionResult = _drive(generation, seed_value, playable, supports)
			var second: ActionResult = _drive(generation, seed_value, playable, supports)
			assert_equal(String(first.metadata.get("outcome")), String(second.metadata.get("outcome")), "seed=%d class=%s: same outcome twice." % [seed_value, String(playable["class_id"])])
			assert_equal(int(first.metadata.get("rounds")), int(second.metadata.get("rounds")), "seed=%d class=%s: same round count twice." % [seed_value, String(playable["class_id"])])
			assert_equal(_event_dicts(first.events), _event_dicts(second.events), "seed=%d class=%s: byte-identical event log twice (FR57)." % [seed_value, String(playable["class_id"])])


# ---- AC4: RNG discipline (the ranger draws zero; the warrior shield engages the combat stream) -----

func _ranger_draws_zero_combat_rng_and_warrior_shield_engages_the_combat_stream() -> void:
	var generation: GenerationResult = _generate(4242)
	var supports: SupportRepository = SupportRepository.create_baseline_repository()

	# The ranger (bow, NO support, no proc) draws ZERO `combat` RNG — the injected run-level stream set is byte-identical
	# before/after a full victory (the byte-identical no-support path — it perturbs no stream).
	var ranger_streams: RngStreamSet = RngStreamSet.new(4242)
	var ranger_before: Dictionary = ranger_streams.to_snapshot()
	var ranger: ActionResult = ReferenceCombatDriver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), ranger_streams, CLASS_HP, &"bow"
	)
	assert_true(ranger.succeeded and bool(ranger.metadata.get("is_victory")), "Setup: the ranger should win seed 4242.")
	assert_equal(ranger_streams.to_snapshot(), ranger_before, "The ranger (no support, no-proc bow) draws ZERO combat RNG (the injected stream set is unchanged — the byte-identical no-support path).")

	# The warrior shield ENGAGES the seeded shield_block roll on the `combat` stream — the INTENTIONAL class-path draw, now
	# on INCOMING enemy attacks (the shield protects its OWNER). The enemy-phase block draw is synced back to the run-level
	# stream, so the injected stream ADVANCES (a real, seeded draw) and the event log carries shield_block combat rolls.
	var warrior_streams: RngStreamSet = RngStreamSet.new(4242)
	var warrior_before: Dictionary = warrior_streams.to_snapshot()
	var warrior: ActionResult = ReferenceCombatDriver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), warrior_streams, CLASS_HP, &"sword",
		AffinityDefinition.AFFINITY_NONE, null,
		supports.get_support(&"shield")
	)
	assert_true(warrior.succeeded and bool(warrior.metadata.get("is_victory")), "Setup: the warrior should win seed 4242.")
	assert_true(warrior_streams.to_snapshot() != warrior_before, "The warrior shield ENGAGES the `combat` stream (the run-level stream ADVANCES — the INTENTIONAL class-path draw, synced back from the enemy phase).")
	assert_true(_shield_block_roll_count(warrior.events) > 0, "The warrior fight emits shield_block combat rolls (the seeded off-hand draw on incoming enemy attacks).")


func _no_new_rng_stream_is_added() -> void:
	# AC4: the strengthened driver opens NO new RNG stream — the 7 named streams are invariant (the only gameplay RNG is
	# the `combat` stream via the existing AttackCommand draws).
	assert_equal(RngStreamSet.required_streams().size(), 7, "The 7 named RNG streams are invariant (no new stream for the reference driver).")


# ---- AC3: per-class distinctness on the same seed -------------------------------------------------

func _the_three_classes_are_tactically_distinct_on_the_same_seed() -> void:
	# On the SAME seed, each class produces a demonstrable, non-cosmetic difference in the RESOLVED fight (the direct
	# input to 10.4's class-comparison AC):
	#   - warrior sword+shield -> shield_block `combat` rolls present (a block chance on INCOMING enemy hits — the shield
	#     protects its OWNER); melee grind (a distinct round count).
	#   - pyromancer staff+tome -> tome +1 bonus damage present on the hero's own attacks (support_bonus_damage > 0); NO
	#     shield_block.
	#   - ranger bow+none -> NEITHER a shield_block NOR a tome bonus (the real no-op support).
	var generation: GenerationResult = _generate(4242)
	var supports: SupportRepository = SupportRepository.create_baseline_repository()

	var warrior: ActionResult = _drive(generation, 4242, PLAYABLE_CLASSES[0], supports)
	var pyromancer: ActionResult = _drive(generation, 4242, PLAYABLE_CLASSES[1], supports)
	var ranger: ActionResult = _drive(generation, 4242, PLAYABLE_CLASSES[2], supports)
	assert_true(warrior.succeeded and pyromancer.succeeded and ranger.succeeded, "Setup: all three classes resolve seed 4242.")

	# Warrior: the shield engages block rolls on incoming enemy attacks; the others do not.
	assert_true(_shield_block_roll_count(warrior.events) > 0, "WARRIOR is distinct: its shield engages shield_block `combat` rolls (a block chance on INCOMING enemy hits — the shield protects its owner).")
	assert_equal(_shield_block_roll_count(pyromancer.events), 0, "PYROMANCER carries NO shield_block roll (it wields a tome, not a shield).")
	assert_equal(_shield_block_roll_count(ranger.events), 0, "RANGER carries NO shield_block roll (its support is the real no-op none).")

	# Pyromancer: the tome adds +1 bonus damage on its OWN staff attacks; the others deal no support bonus.
	assert_true(_max_support_bonus_damage(pyromancer.events) > 0, "PYROMANCER is distinct: its tome adds +1 bonus damage to its own staff attacks (support_bonus_damage > 0).")
	assert_equal(_max_support_bonus_damage(warrior.events), 0, "WARRIOR deals NO support bonus damage (a shield adds armor/block on defense, not bonus damage).")
	assert_equal(_max_support_bonus_damage(ranger.events), 0, "RANGER deals NO support bonus damage (the no-op none support).")

	# The resolved fights differ in shape (round count) — a demonstrable per-class difference, not merely a label.
	var warrior_rounds: int = int(warrior.metadata.get("rounds"))
	var pyromancer_rounds: int = int(pyromancer.metadata.get("rounds"))
	var ranger_rounds: int = int(ranger.metadata.get("rounds"))
	assert_true(
		warrior_rounds != pyromancer_rounds or pyromancer_rounds != ranger_rounds or warrior_rounds != ranger_rounds,
		"The three classes resolve the SAME seed in DIFFERENT round counts (war=%d pyr=%d rng=%d) — a demonstrable per-class difference." % [warrior_rounds, pyromancer_rounds, ranger_rounds]
	)


# ---- error paths ----------------------------------------------------------------------------------

func _rejects_a_corrupt_board_snapshot_and_unknown_weapon() -> void:
	var corrupt: ActionResult = ReferenceCombatDriver.new().resolve({"width": 3}, {"x": 0, "y": 0}, RngStreamSet.new(1), CLASS_HP, &"sword")
	assert_true(corrupt.is_error(), "A corrupt board snapshot must be rejected (no fabricated outcome).")
	assert_equal(corrupt.error_code, &"invalid_board_snapshot", "A rejected board uses the stable invalid_board_snapshot code.")

	var generation: GenerationResult = _generate(4242)
	var unknown: ActionResult = ReferenceCombatDriver.new().resolve(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(1), CLASS_HP, &"not_a_weapon"
	)
	assert_true(unknown.is_error(), "An unknown hero weapon must be rejected.")
	assert_equal(unknown.error_code, &"unknown_hero_weapon", "A missing weapon uses the stable unknown_hero_weapon code.")


# ---- helpers -------------------------------------------------------------------------------------

func _drive(generation: GenerationResult, seed_value: int, playable: Dictionary, supports: SupportRepository) -> ActionResult:
	var support: SupportDefinition = null
	if StringName(playable["support_id"]) != SupportDefinition.SUPPORT_NONE:
		support = supports.get_support(StringName(playable["support_id"]))
	# hero_support is the TRAILING param (aligned with InteractiveCombatSession.begin); the affinity pair is passed as its
	# neutral default so the trailing support lands in the right slot.
	return ReferenceCombatDriver.new().resolve(
		generation.payload.get("board", {}),
		generation.payload.get("entrance", {}),
		RngStreamSet.new(seed_value),
		CLASS_HP,
		StringName(playable["weapon_id"]),
		AffinityDefinition.AFFINITY_NONE,
		null,
		support
	)


func _generate(seed_value: int) -> GenerationResult:
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


func _event_dicts(events: Array) -> Array:
	var out: Array = []
	for event_value: Variant in events:
		if event_value is DomainEvent:
			out.append((event_value as DomainEvent).to_dictionary())
	return out


# The number of shield_block `combat`-stream rolls in a live-combat log (the warrior off-hand signal).
func _shield_block_roll_count(events: Array) -> int:
	var count: int = 0
	for event_value: Variant in events:
		if not event_value is DomainEvent:
			continue
		var event: DomainEvent = event_value
		for draw_value: Variant in event.payload.get("rng_draws", []):
			if String((draw_value as Dictionary).get("effect_id", "")) == "shield_block":
				count += 1
	return count


# The maximum support_bonus_damage across all damage events (the pyromancer tome +1 signal; 0 when no bonus support).
func _max_support_bonus_damage(events: Array) -> int:
	var best: int = 0
	for event_value: Variant in events:
		if not event_value is DomainEvent:
			continue
		var event: DomainEvent = event_value
		var bonus: int = int(event.payload.get("support_bonus_damage", 0))
		if bonus > best:
			best = bonus
	return best


# A sealed board: hero (left room) and enemy (right room) split by a full WALL column (no gap) — the fight can never
# resolve (mutually unreachable), so the driver hits the round cap and fails loud. The unwinnable triage fixture.
func _sealed_snapshot() -> Dictionary:
	var width: int = 7
	var height: int = 5
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
			if x == 0 or y == 0 or x == width - 1 or y == height - 1 or x == 3:
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
