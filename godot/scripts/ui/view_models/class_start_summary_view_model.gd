class_name ClassStartSummaryViewModel
extends RefCounted

# Story 5.5 — the scene-free CLASS-START SUMMARY projection (the EPIC-5 closing smoke slice's only new
# SURFACE). It is the thin presentation contract the (future) "you started a run as <class>" surface reads at
# the point a run enters its first tactical level: it PROJECTS a STARTED RunState's class-start identity (the
# 5.2 selected_class_id + the 5.3 starting_kit + the 5.4 rules_resolver) into serializable view data with an
# EXACT key contract — a key never silently appears/vanishes (the HeroSelectViewModel / TacticalBoardViewModel
# exact-key discipline; a test pins SUMMARY_KEYS).
#
# WHAT IT IS:
#   - summarize(run) -> a flat Dictionary keyed by SUMMARY_KEYS: has_class_identity, class_id, display_name,
#     weapon_id, support_id, baseline_hp, class_passive_id, equipment_synergy_passive_id, passive_explanations
#     (the class passive THEN the equipment-synergy passive, the stable resolver order), run_started_explanations
#     (the equipment-synergy passive's window — AC2 "surfaces AT START"), and before_attack_explanations (the
#     class passive's window — AC2 "surfaces when an attack window resolves"). It reads class/passive content
#     ONLY through get_class_definition / get_passive (NEVER the reserved-native get_class) and resolves the
#     per-window explanations through the run's rules_resolver (a PURE read — the resolver draws NO RNG, mutates
#     nothing; 5.4).
#   - re_derive_kit(class_id) / re_derive_resolver(class_id) [STATIC]: the ONE canonical place a resumer
#     re-derives BOTH live services after a route-position resume (restored_run.starting_kit AND
#     restored_run.rules_resolver are NULL by design — the 4.6 inert-RngStreamSet precedent). They are
#     deterministic PURE functions of (class_id + the baseline repositories), drawing NO RNG, mirroring exactly
#     what RunStartCommand.execute seats (the kit's resolved weapon/support/baseline_hp/passive ids; the resolver
#     with the class passive registered FIRST then the equipment-synergy passive). This CLOSES the consolidated
#     5.4 re-derive-both obligation in-story.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO commands, draws NO RNG, and mutates nothing — it PROJECTS the run.
#   - It is a RefCounted DTO — NOT a Control, NOT a Node, NOT a .tscn / scene / presenter / art (the
#     UI-scene-last rule; the FR47/FR68 hero-select/HUD scenes are a later HUD story). The class-identity
#     surface is a scene-free projection only.
#   - It introduces NO active-skill concept (FR45) — it surfaces ONLY passive rule-bender explanations; the
#     projection has no active-skill key.
#   - It does NOT mutate a combat number (v0 passives are EXPLANATION-ONLY; the per-effect operation + the
#     combat HOOK sites are Epic 6). It surfaces the EXPLANATIONS + the resolver's window resolution ONLY.

const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")

# The EXACT key set of summarize() (the HeroSelectViewModel.ENTRY_KEYS / TacticalBoardViewModel exact-key
# discipline). A key never silently appears/vanishes — a test pins this. There is NO active-skill key.
const SUMMARY_KEYS: Array[String] = [
	"has_class_identity",
	"class_id",
	"display_name",
	"weapon_id",
	"support_id",
	"baseline_hp",
	"class_passive_id",
	"equipment_synergy_passive_id",
	"passive_explanations",
	"run_started_explanations",
	"before_attack_explanations"
]

var _class_repository: ClassRepository = null
var _passive_repository: PassiveRepository = null

func _init(
	new_class_repository: ClassRepository = null,
	new_passive_repository: PassiveRepository = null
) -> void:
	# Default to the baseline repositories (the HeroSelectViewModel / RunStartCommand injection posture). Tests
	# inject fixture repositories.
	_class_repository = new_class_repository if new_class_repository != null else ClassRepository.create_baseline_repository()
	_passive_repository = new_passive_repository if new_passive_repository != null else PassiveRepository.create_baseline_repository()


# Project the class-start identity of a STARTED run. A run carrying a non-empty selected_class_id + a kit + a
# resolver projects the full identity surface; an empty-class/legacy run (no kit, no resolver) projects the
# identity-ABSENT surface (the SAME key set, empty/default values, NO explanations) — fail-closed, NOT a crash,
# NOT a half-entry (the HeroSelectViewModel fail-closed-skip discipline). PURE read: no RNG, no mutation.
func summarize(run: RunState) -> Dictionary:
	if run == null or String(run.selected_class_id).is_empty():
		return _identity_absent_summary()

	# Resolve the class definition through the accessor (NEVER get_class). A class id that somehow does not
	# resolve projects the identity-absent surface (fail-closed — the projection never carries a half-entry),
	# though a started selectable-class run always resolves.
	var def: ClassDefinition = _class_repository.get_class_definition(run.selected_class_id)
	if def == null:
		return _identity_absent_summary()

	# Prefer the recorded kit (the authoritative 5.3 record). Fall back to the definition's configured kit fields
	# if a class run somehow carries no kit (defensive — a started selectable-class run always has one).
	var kit: StartingKit = run.starting_kit
	var weapon_id: String = String(kit.weapon_id) if kit != null else String(def.starting_weapon_id)
	var support_id: String = String(kit.support_id) if kit != null else String(def.starting_support_id)
	var baseline_hp: int = kit.baseline_hp if kit != null else def.baseline_hp
	var class_passive_id: String = String(kit.class_passive_id) if kit != null else String(def.class_passive_id)
	var equip_passive_id: String = String(kit.equipment_synergy_passive_id) if kit != null else String(def.equipment_synergy_passive_id)

	# Surface the per-window explanations by RESOLVING the declared windows on the run's resolver (the AC2
	# explanation surface). A class run with no resolver surfaces empty lists (defensive — a started
	# selectable-class run always seats one). Explanations are PLAIN Strings (survive any later ActionResult
	# metadata deep-copy — the project-context.md typed-Array[Dictionary] gotcha).
	var run_started_explanations: Array[String] = _explain_window(run, RuleTrigger.RUN_STARTED)
	var before_attack_explanations: Array[String] = _explain_window(run, RuleTrigger.BEFORE_ATTACK)
	# The flat all-explanations field is the class passive THEN the equipment-synergy passive (the stable
	# registration order RunStartCommand uses), derived from the resolver's registered passives.
	var passive_explanations: Array[String] = _ordered_passive_explanations(run, class_passive_id, equip_passive_id)

	return {
		"has_class_identity": true,
		"class_id": String(run.selected_class_id),
		"display_name": def.display_name,
		"weapon_id": weapon_id,
		"support_id": support_id,
		"baseline_hp": baseline_hp,
		"class_passive_id": class_passive_id,
		"equipment_synergy_passive_id": equip_passive_id,
		"passive_explanations": passive_explanations,
		"run_started_explanations": run_started_explanations,
		"before_attack_explanations": before_attack_explanations
	}


# The identity-absent projection (an empty-class / legacy run): the SAME key set, empty/default values, NO
# explanations. has_class_identity is false so a consumer can branch without inspecting the empty fields.
func _identity_absent_summary() -> Dictionary:
	var empty_explanations: Array[String] = []
	return {
		"has_class_identity": false,
		"class_id": "",
		"display_name": "",
		"weapon_id": "",
		"support_id": "",
		"baseline_hp": 0,
		"class_passive_id": "",
		"equipment_synergy_passive_id": "",
		"passive_explanations": empty_explanations.duplicate(),
		"run_started_explanations": empty_explanations.duplicate(),
		"before_attack_explanations": empty_explanations.duplicate()
	}


# Resolve a trigger window's explanations on the run's resolver (a pure read). Returns plain Strings; an
# absent resolver returns empty.
func _explain_window(run: RunState, window_id: StringName) -> Array[String]:
	if run.rules_resolver == null:
		var empty: Array[String] = []
		return empty
	return run.rules_resolver.explain(window_id)


# The two passive explanations in stable registration order (class passive THEN equipment-synergy passive),
# resolved through the PassiveRepository accessor (get_passive, NEVER get_class). This mirrors the order
# RunStartCommand registers them, so passive_explanations is the deterministic flat surface. A missing passive
# (defensive — the start gate already proved both resolve) is skipped rather than surfacing an empty line.
func _ordered_passive_explanations(_run: RunState, class_passive_id: String, equip_passive_id: String) -> Array[String]:
	var explanations: Array[String] = []
	var class_passive: PassiveDefinition = _passive_repository.get_passive(StringName(class_passive_id))
	if class_passive != null:
		explanations.append(class_passive.explanation)
	var equip_passive: PassiveDefinition = _passive_repository.get_passive(StringName(equip_passive_id))
	if equip_passive != null:
		explanations.append(equip_passive.explanation)
	return explanations


# ---- the consolidated 5.4 RE-DERIVE-BOTH obligation (the ONE canonical re-derive) ----------------

# RE-DERIVE the StartingKit from a (restored) class id — the deterministic PURE function a resumer runs after a
# route-position resume (restored_run.starting_kit is NULL by design). It MUST equal the kit RunStartCommand
# recorded on a fresh start of the same class. Draws NO RNG, mutates nothing. An empty / unknown / non-selectable
# class id re-derives null (fail-closed, back-compat — a pre-5.x payload carries no class; a locked class is not
# a startable kit). Mirrors test_run_route_position_save.gd::_kit_re_derives_from_restored_class_id.
static func re_derive_kit(class_id: StringName, class_repository: ClassRepository = null) -> StartingKit:
	if String(class_id).is_empty():
		return null
	var repo: ClassRepository = class_repository if class_repository != null else ClassRepository.create_baseline_repository()
	var def: ClassDefinition = repo.get_class_definition(class_id)
	if def == null or not def.is_selectable():
		return null
	return StartingKit.new(
		class_id,
		def.starting_weapon_id,
		def.starting_support_id,
		def.baseline_hp,
		def.class_passive_id,
		def.equipment_synergy_passive_id
	)


# RE-DERIVE the RulesResolver from a (restored) class id — the second half of the consolidated obligation
# (restored_run.rules_resolver is NULL by design). It re-derives the kit, resolves the kit's two passive ids
# through PassiveRepository.get_passive(...), and rebuilds a RulesResolver registering the class passive FIRST
# then the equipment-synergy passive (the SAME order RunStartCommand.execute uses — registration order = stable
# resolution order). The re-derived resolver's registered ids + explanations MUST equal a fresh start's. Draws
# NO RNG, mutates nothing. An empty / unknown / non-selectable class id (or a class whose passives do not
# resolve) re-derives null (fail-closed, back-compat).
static func re_derive_resolver(
	class_id: StringName,
	class_repository: ClassRepository = null,
	passive_repository: PassiveRepository = null
) -> RulesResolver:
	var kit: StartingKit = re_derive_kit(class_id, class_repository)
	if kit == null:
		return null
	var passive_repo: PassiveRepository = passive_repository if passive_repository != null else PassiveRepository.create_baseline_repository()
	var class_passive: PassiveDefinition = passive_repo.get_passive(kit.class_passive_id)
	var equip_passive: PassiveDefinition = passive_repo.get_passive(kit.equipment_synergy_passive_id)
	# Fail-closed: a class whose recorded passive ids do not resolve cannot rebuild a faithful resolver. This
	# mirrors the RunStartCommand passive gate (which already rejected an unknown passive before the run started),
	# so on the baseline path both always resolve.
	if class_passive == null or equip_passive == null:
		return null
	var resolver: RulesResolver = RulesResolver.new()
	# SAME order as RunStartCommand.execute: the class passive first, then the equipment-synergy passive.
	resolver.register_passive(class_passive)
	resolver.register_passive(equip_passive)
	return resolver
