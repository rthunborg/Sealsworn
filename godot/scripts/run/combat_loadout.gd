class_name CombatLoadout
extends RefCounted

# Story 12.2 (AC1) — the CLASS-KIT -> LIVE-COMBAT LOADOUT SOURCE. The small, scene-free RefCounted DTO that derives the
# live-combat hero loadout ({ hp, weapon_id, support }) from the run's applied StartingKit (run.starting_kit), formally
# CLOSING the Story 11.2 "class-kit -> combat-loadout is a later story" boundary. Before 12.2 the live driver was armed
# with the flat scripted default (LiveCombatResolver.DEFAULT_HERO_HP 60 / sword); this DTO makes the hero fight with the
# SELECTED class's kit (StartingKit.baseline_hp / weapon_id / support_id — all three MVP classes carry 18 baseline_hp).
#
# ⭐ IT OWNS NO GAMEPLAY DECISION A COMMAND/RESOLVER DOES NOT — it is a pure read + resolve of the recorded kit. It draws
# NO RNG, submits NO command, mints NO event, mutates nothing. The loadout DECISION lives in the domain/flow layer (this
# DTO + RunFlowController); the shell is a thin observer that passes the derived loadout into the unchanged orchestrator
# seam. It resolves the support id through the SupportRepository boundary (validated supports only), exactly as
# RunStartCommand resolved it at record time.
#
# ⭐ FAIL-OPEN FALLBACK (AC1 — the null-kit / legacy / seed-only run must still resolve): for_run(run, ...) with a
# null starting_kit (a seed-only / empty-class / pre-5.3 run) yields the DRIVER DEFAULT loadout
# (LiveCombatResolver.DEFAULT_HERO_HP / DEFAULT_HERO_WEAPON / no support) so the run still resolves — it NEVER crashes on
# a kit-less start (the T3 Necromancer/Shadeblade guard: this story does NOT author their kit, but the loadout source
# must not choke on a hypothetical kit-less class). A kit whose weapon_id fails to resolve at the resolver boundary is
# the resolver's own fail-closed unknown_hero_weapon concern (the kit ids are validated to resolve at record time by
# RunStartCommand, so a well-formed run always resolves here).
#
# ⭐ SUPPORT SEMANTICS (AC3/AC4 — the intentional class-path change): the resolved support is the hero's loadout support.
# The neutral SUPPORT_NONE (Ranger's real no-op) resolves to a null support — the neutral / no-support path stays
# byte-identical to the flat sword default (it never draws the `combat` stream). A warrior `shield` / pyromancer `tome`
# resolves to a real SupportDefinition; threading it into AttackCommand engages the seeded shield_block roll / the +1
# tome bonus on the `combat` stream — the INTENTIONAL, seeded, reproducible AC4 change on the CLASS path only.

const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")

# The derived live-combat loadout. hp/weapon_id are always populated; support is the resolved SupportDefinition (or null
# for SUPPORT_NONE / a kit-less run — a null support is the byte-identical no-support path).
var hp: int = LiveCombatResolver.DEFAULT_HERO_HP
var weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON
var support: SupportDefinition = null
# The kit-derived flag: true when the loadout came from a run's StartingKit; false when it fell back to the driver
# default (a null-kit / legacy / seed-only run). A pure read for tests / diagnostics — not a gameplay decision.
var derived_from_kit: bool = false
# The kit's two passive ids, RECORDED-VERBATIM (the AC3 derivation "the loadout derives from ... passives" — the kit's
# passive ids are part of the applied loadout / already registered on run.rules_resolver by RunStartCommand). There is
# NO passive-combat-effect engine (scripts/rules/conditions/ stays EMPTY) — these are recorded, not newly effect-wired.
var class_passive_id: StringName = &""
var equipment_synergy_passive_id: StringName = &""

func _init(
	new_hp: int = LiveCombatResolver.DEFAULT_HERO_HP,
	new_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON,
	new_support: SupportDefinition = null,
	new_derived_from_kit: bool = false,
	new_class_passive_id: StringName = &"",
	new_equipment_synergy_passive_id: StringName = &""
) -> void:
	hp = new_hp
	weapon_id = new_weapon_id
	support = new_support
	derived_from_kit = new_derived_from_kit
	class_passive_id = new_class_passive_id
	equipment_synergy_passive_id = new_equipment_synergy_passive_id


# Derive the live-combat loadout from a seated RunState. Reads run.starting_kit for the HP / weapon / support / passive
# ids; falls open to the driver default when the kit is absent (a null-kit / legacy / seed-only run). The support id is
# resolved through the injected SupportRepository (validated supports only); SUPPORT_NONE (or an unresolved id) yields a
# null support (the byte-identical no-support path). A null run also falls open to the default.
static func for_run(run: RunState, support_repository: SupportRepository = null) -> CombatLoadout:
	if run == null or run.starting_kit == null:
		return load("res://scripts/run/combat_loadout.gd").new()
	return for_kit(run.starting_kit, support_repository)


# Derive the loadout from a StartingKit directly (the seam the controller/tests share). Resolves the support id through
# the repository; SUPPORT_NONE / an unresolved id yields a null support. The baseline_hp / weapon_id come straight off
# the kit (validated to resolve at record time). A null kit falls open to the driver default.
static func for_kit(kit: StartingKit, support_repository: SupportRepository = null) -> CombatLoadout:
	if kit == null:
		return load("res://scripts/run/combat_loadout.gd").new()
	var resolved_support: SupportDefinition = _resolve_support(kit.support_id, support_repository)
	return load("res://scripts/run/combat_loadout.gd").new(
		kit.baseline_hp,
		kit.weapon_id,
		resolved_support,
		true,
		kit.class_passive_id,
		kit.equipment_synergy_passive_id
	)


# The support id resolved to a validated SupportDefinition, or null for the neutral SUPPORT_NONE / an empty / unresolved
# id. A null support is the no-support path (byte-identical to the flat sword default — it never carries a `combat`-stream
# draw). The repository defaults to the baseline support roster (the same roster RunStartCommand resolves against).
static func _resolve_support(support_id: StringName, support_repository: SupportRepository) -> SupportDefinition:
	if support_id == &"" or support_id == SupportDefinition.SUPPORT_NONE:
		return null
	var repository: SupportRepository = support_repository if support_repository != null else SupportRepository.create_baseline_repository()
	if repository == null:
		return null
	return repository.get_support(support_id)
