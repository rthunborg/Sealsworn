class_name PassiveRepository
extends RefCounted

# The fail-closed passive content repository (Story 5.4) — a BYTE-FOR-STRUCTURE clone of
# SupportRepository / ClassRepository. It holds the six baseline STARTING-passive definitions the three
# selectable classes reference (Warrior/Pyromancer/Ranger each have one class passive + one equipment-synergy
# passive), registered through the ContentRepository boundary, and resolves a passive id to its typed
# PassiveDefinition via get_passive(id) — returning null on a miss (fail-closed; the architecture's
# content_repository.get_passive(passive_id) accessor name, no reserved-native collision unlike get_class).
#
# These six ids MUST EXACTLY MATCH the 5.1 class baselines (class_repository.gd::_baseline_definitions()) or
# a class start would fail-closed at the RunStartCommand passive gate. They are the v0 starting-passive set;
# the broader 20-30 MVP passive POOL (FR46) + the per-effect operation model are Epic 6 — do NOT author the
# full pool here.
#
# DUPLICATE-ID NOTE: this repository inherits ContentRepository's last-write-wins behavior by construction,
# exactly like its five siblings (now SIX repos). The duplicate-id last-write-wins trap is a cross-cutting,
# human-ratified [Review][Defer] owned by a dedicated all-repos hardening story — this repository is NOT
# forked to fail-loud on a duplicate id; the new repo is folded into that ledger entry's scope. No test
# fixture registers duplicate ids.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")

const BASELINE_PASSIVE_IDS: Array[StringName] = [
	&"warrior_unbreakable_guard",
	&"warrior_blade_and_board",
	&"pyromancer_kindling_focus",
	&"pyromancer_arcane_conduit",
	&"ranger_steady_aim",
	&"ranger_hunters_quiver"
]

var _content_repository: ContentRepository
var _passive_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> PassiveRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> PassiveRepository:
	var validated_definitions: Array[PassiveDefinition] = []
	for definition_value: Variant in definitions:
		var definition: PassiveDefinition = definition_value as PassiveDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: PassiveRepository = load("res://scripts/content/repositories/passive_repository.gd").new(content_repository)
	for definition: PassiveDefinition in validated_definitions:
		var result: ActionResult = repository.register_passive(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_passives() -> ActionResult:
	for definition: PassiveDefinition in _baseline_definitions():
		var result: ActionResult = register_passive(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_passive(definition: PassiveDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_passive")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	_content_repository.register_definition(PassiveDefinition.DEFINITION_TYPE, definition.passive_id, definition)
	if not _passive_order.has(definition.passive_id):
		_passive_order.append(definition.passive_id)
	return ActionResult.ok([], {
		"passive_id": String(definition.passive_id)
	})


func get_passive(passive_id: StringName) -> PassiveDefinition:
	return _content_repository.get_definition(PassiveDefinition.DEFINITION_TYPE, passive_id) as PassiveDefinition


func has_passive(passive_id: StringName) -> bool:
	return _content_repository.has_definition(PassiveDefinition.DEFINITION_TYPE, passive_id)


func passive_ids() -> Array[StringName]:
	return _passive_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


# The six baseline STARTING-passive definitions, matching the 5.1 class baselines EXACTLY. Each is a
# PASSIVE + EXPLANATION-ONLY v0 rule-bender (no effect operation — that is Story 5.5 / Epic 6). The class
# passive (the *_unbreakable_guard / *_kindling_focus / *_steady_aim id) is KIND_CLASS; the equipment-synergy
# passive (the *_blade_and_board / *_arcane_conduit / *_hunters_quiver id) is KIND_EQUIPMENT_SYNERGY. The
# class passives declare BEFORE_ATTACK (they bend an incoming/outgoing attack); the equipment-synergy
# passives declare RUN_STARTED (the kit synergy is established when the run begins).
static func _baseline_definitions() -> Array[PassiveDefinition]:
	return [
		PassiveDefinition.new(
			&"warrior_unbreakable_guard",
			"Unbreakable Guard",
			PassiveDefinition.KIND_CLASS,
			[RuleTrigger.BEFORE_ATTACK],
			"Unbreakable Guard (warrior class passive) steels the hero before an incoming attack."
		),
		PassiveDefinition.new(
			&"warrior_blade_and_board",
			"Blade and Board",
			PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
			[RuleTrigger.RUN_STARTED],
			"Blade and Board (warrior equipment synergy) pairs sword and shield as the run begins."
		),
		PassiveDefinition.new(
			&"pyromancer_kindling_focus",
			"Kindling Focus",
			PassiveDefinition.KIND_CLASS,
			[RuleTrigger.BEFORE_ATTACK],
			"Kindling Focus (pyromancer class passive) gathers flame before an attack."
		),
		PassiveDefinition.new(
			&"pyromancer_arcane_conduit",
			"Arcane Conduit",
			PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
			[RuleTrigger.RUN_STARTED],
			"Arcane Conduit (pyromancer equipment synergy) channels staff and tome as the run begins."
		),
		PassiveDefinition.new(
			&"ranger_steady_aim",
			"Steady Aim",
			PassiveDefinition.KIND_CLASS,
			[RuleTrigger.BEFORE_ATTACK],
			"Steady Aim (ranger class passive) settles the shot before an attack."
		),
		PassiveDefinition.new(
			&"ranger_hunters_quiver",
			"Hunter's Quiver",
			PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
			[RuleTrigger.RUN_STARTED],
			"Hunter's Quiver (ranger equipment synergy) readies the bow's arrows as the run begins."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_passive_repository", {
		"reason": String(reason)
	})
