extends "res://tests/unit/test_case.gd"

# Story 12.2 (AC1) — CombatLoadout: the CLASS-KIT -> LIVE-COMBAT LOADOUT SOURCE. Derives the live-combat hero loadout
# ({ hp, weapon_id, support }) from the run's applied StartingKit (run.starting_kit), formally closing the 11.2
# "class-kit -> combat-loadout is a later story" boundary.
#
# Covers:
#   - AC1 — the loadout for a warrior/pyromancer/ranger run DERIVES from run.starting_kit: HP == baseline_hp (18),
#           weapon_id == the class weapon, support == the resolved class support (shield/tome), and the neutral
#           SUPPORT_NONE (ranger) resolves to a null support (the no-support byte-identical path).
#   - AC1 — the kit's passive ids are recorded on the derived loadout (the "loadout derives from ... passives"
#           derivation — recorded verbatim, NOT a new passive-combat-effect engine).
#   - AC1 — FAIL-OPEN: a null-kit / null run falls back to the driver default (DEFAULT_HERO_HP 60 / sword / no support)
#           so a seed-only / kit-less run still resolves (never a crash).

const CombatLoadout = preload("res://scripts/run/combat_loadout.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")

const LIVE_SEED: int = 4242

func run() -> Dictionary:
	_warrior_loadout_derives_from_the_kit_with_a_shield_support()
	_pyromancer_loadout_derives_from_the_kit_with_a_tome_support()
	_ranger_loadout_derives_from_the_kit_with_a_null_none_support()
	_kit_passive_ids_are_recorded_on_the_loadout()
	_null_kit_run_falls_back_to_the_driver_default()
	_null_run_falls_back_to_the_driver_default()
	_for_kit_resolves_a_direct_kit()
	return result()


# ---- AC1: each class loadout derives HP/weapon/support from the applied kit -----------------------

func _warrior_loadout_derives_from_the_kit_with_a_shield_support() -> void:
	var run: RunState = _started_run(&"warrior")
	var loadout: CombatLoadout = CombatLoadout.for_run(run)
	assert_true(loadout.derived_from_kit, "The warrior loadout is derived from the kit (not the driver default).")
	assert_equal(loadout.hp, 18, "The warrior live HP derives from StartingKit.baseline_hp (18 — NOT the flat DEFAULT_HERO_HP 60).")
	assert_equal(String(loadout.weapon_id), "sword", "The warrior weapon derives from the kit (sword).")
	assert_true(loadout.support != null, "The warrior support resolves to a real SupportDefinition (shield).")
	assert_equal(String(loadout.support.support_id), String(SupportDefinition.SUPPORT_SHIELD), "The warrior support is the shield (armor + block chance).")


func _pyromancer_loadout_derives_from_the_kit_with_a_tome_support() -> void:
	var run: RunState = _started_run(&"pyromancer")
	var loadout: CombatLoadout = CombatLoadout.for_run(run)
	assert_true(loadout.derived_from_kit, "The pyromancer loadout is derived from the kit.")
	assert_equal(loadout.hp, 18, "The pyromancer live HP derives from the kit baseline_hp (18).")
	assert_equal(String(loadout.weapon_id), "staff", "The pyromancer weapon derives from the kit (staff — ranged).")
	assert_true(loadout.support != null, "The pyromancer support resolves to a real SupportDefinition (tome).")
	assert_equal(String(loadout.support.support_id), String(SupportDefinition.SUPPORT_TOME), "The pyromancer support is the tome (+1 staff bonus).")


func _ranger_loadout_derives_from_the_kit_with_a_null_none_support() -> void:
	var run: RunState = _started_run(&"ranger")
	var loadout: CombatLoadout = CombatLoadout.for_run(run)
	assert_true(loadout.derived_from_kit, "The ranger loadout is derived from the kit.")
	assert_equal(loadout.hp, 18, "The ranger live HP derives from the kit baseline_hp (18).")
	assert_equal(String(loadout.weapon_id), "bow", "The ranger weapon derives from the kit (bow — ranged).")
	assert_true(loadout.support == null, "The ranger support (&\"none\" == SUPPORT_NONE) resolves to a NULL support (the byte-identical no-support path).")


func _kit_passive_ids_are_recorded_on_the_loadout() -> void:
	# AC1 — the loadout "derives from ... passives": the kit's two passive ids are RECORDED on the derived loadout (the
	# derivation), NOT a new passive-combat-effect engine. This is the recorded string-shape reference, matching the kit.
	var run: RunState = _started_run(&"warrior")
	var loadout: CombatLoadout = CombatLoadout.for_run(run)
	assert_equal(String(loadout.class_passive_id), "warrior_unbreakable_guard", "The class passive id is recorded on the loadout (verbatim from the kit).")
	assert_equal(String(loadout.equipment_synergy_passive_id), "warrior_blade_and_board", "The equipment-synergy passive id is recorded on the loadout (verbatim from the kit).")


# ---- AC1: fail-open fallback to the driver default -----------------------------------------------

func _null_kit_run_falls_back_to_the_driver_default() -> void:
	# A seed-only / empty-class run records NO kit (run.starting_kit == null). The loadout must fall OPEN to the driver
	# default so the run still resolves (never a crash on a kit-less start — the T3 guard).
	var run: RunState = _started_run(&"")  # a seed-only start seats no kit
	assert_true(run.starting_kit == null, "Setup: a seed-only run records NO starting_kit.")
	var loadout: CombatLoadout = CombatLoadout.for_run(run)
	assert_false(loadout.derived_from_kit, "A null-kit run falls back to the driver default (not kit-derived).")
	assert_equal(loadout.hp, LiveCombatResolver.DEFAULT_HERO_HP, "A null-kit run uses the driver default HP (60).")
	assert_equal(String(loadout.weapon_id), String(LiveCombatResolver.DEFAULT_HERO_WEAPON), "A null-kit run uses the driver default weapon (sword).")
	assert_true(loadout.support == null, "A null-kit run carries no support (the byte-identical default path).")


func _null_run_falls_back_to_the_driver_default() -> void:
	var loadout: CombatLoadout = CombatLoadout.for_run(null)
	assert_false(loadout.derived_from_kit, "A null run falls back to the driver default.")
	assert_equal(loadout.hp, LiveCombatResolver.DEFAULT_HERO_HP, "A null run uses the driver default HP (60).")
	assert_equal(String(loadout.weapon_id), String(LiveCombatResolver.DEFAULT_HERO_WEAPON), "A null run uses the driver default weapon (sword).")


func _for_kit_resolves_a_direct_kit() -> void:
	# The for_kit seam resolves a StartingKit directly (the controller/tests share it). A hand-built warrior-shape kit
	# resolves the shield support through the baseline repository.
	var kit: StartingKit = StartingKit.new(&"warrior", &"sword", &"shield", 18, &"warrior_unbreakable_guard", &"warrior_blade_and_board")
	var loadout: CombatLoadout = CombatLoadout.for_kit(kit)
	assert_true(loadout.derived_from_kit, "A direct kit derives the loadout.")
	assert_equal(loadout.hp, 18, "The direct-kit HP is the kit baseline_hp.")
	assert_equal(String(loadout.support.support_id), String(SupportDefinition.SUPPORT_SHIELD), "The direct-kit support resolves the shield through the baseline repository.")


# ---- helpers -------------------------------------------------------------------------------------

func _started_run(class_id: StringName) -> RunState:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start = orchestrator.start(LIVE_SEED, false, class_id)
	assert_true(start.succeeded, "Setup: start(%s) should succeed: %s" % [String(class_id), start.metadata])
	return orchestrator.run
