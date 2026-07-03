class_name BossRepository
extends RefCounted

# The fail-closed BOSS content repository (Story 9.2, FR63, AC1) — the single approved-content boundary for the Larval
# Avatar boss definition, mirroring EnemyRepository VERBATIM: a create_baseline_repository() + a _baseline_definitions()
# CODE CONSTANT authoring the single Larval Avatar, register_boss(def) through the generic ContentRepository boundary
# (inheriting the fail-loud duplicate-id guard, surfaced as a per-type duplicate_boss error), and a fail-closed
# get_boss(id)/has_boss(id)/boss_ids().
#
# CONTENT STAYS A CODE CONSTANT (project-context): the Larval Avatar is authored as a _baseline_definitions() code
# constant, exactly like EnemyRepository._baseline_definitions(). There is STILL NO .tres/JSON content pipeline —
# data/source and data/resources stay EMPTY scaffolding (NO new content family/subdir; the Echo/Seal-Fragment
# precedent). The JSON-source -> typed-Resource mirror is a deliberately-deferred later decision.
#
# THIS FILLS THE 9.1 SLOT: the baseline boss id == BossDefinition.BOSS_ID == BossEncounterRequest.BOSS_ENTITY_ID
# ("larval_avatar", the slot BossArenaBuilder reserved with is_placeholder: true) — a test cross-checks all three so
# they can never drift. 9.2 authors the boss as a validated content DEFINITION, NOT (yet) a live board entity.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const BossActionDefinition = preload("res://scripts/content/definitions/boss_action_definition.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")

# The boss ids the baseline registers, in stable order (the only required MVP boss — FR63). Pinned by test against the
# actually-registered set.
const BASELINE_BOSS_IDS: Array[StringName] = [
	BossDefinition.BOSS_ID
]

var _content_repository: ContentRepository
var _boss_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> BossRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> BossRepository:
	var validated_definitions: Array[BossDefinition] = []
	for definition_value: Variant in definitions:
		var definition: BossDefinition = definition_value as BossDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: BossRepository = load("res://scripts/content/repositories/boss_repository.gd").new(content_repository)
	for definition: BossDefinition in validated_definitions:
		var registration: ActionResult = repository.register_boss(definition)
		if registration.is_error():
			return null
	return repository


func register_baseline_bosses() -> ActionResult:
	for definition: BossDefinition in _baseline_definitions():
		var result: ActionResult = register_boss(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_boss(definition: BossDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_boss")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(BossDefinition.DEFINITION_TYPE, definition.boss_id, definition)
	if registration.is_error():
		return _duplicate(definition.boss_id)
	if not _boss_order.has(definition.boss_id):
		_boss_order.append(definition.boss_id)
	return ActionResult.ok([], {
		"boss_id": String(definition.boss_id)
	})


func get_boss(boss_id: StringName) -> BossDefinition:
	return _content_repository.get_definition(BossDefinition.DEFINITION_TYPE, boss_id) as BossDefinition


func has_boss(boss_id: StringName) -> bool:
	return _content_repository.has_definition(BossDefinition.DEFINITION_TYPE, boss_id)


func boss_ids() -> Array[StringName]:
	return _boss_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


# The Larval Avatar baseline (FR63) — the ONLY required MVP boss, authored as a readable 3-phase escalation:
#   phase 0 emergence   (100%): it wakes and lashes out, a legible opening.
#   phase 1 adaptation  ( 60%): it learns the hero's shape and adds a corrupting mark.
#   phase 2 desperation ( 25%): cornered, it strikes harder and floods the arena.
# Thresholds strictly decrease (100 -> 60 -> 25); each phase carries its legal-action set (each action = a legal
# action + telegraph + damage rule) + a phase explanation. Escalation is AUTHORED content, NOT a difficulty tier.
static func _baseline_definitions() -> Array[BossDefinition]:
	return [
		BossDefinition.new(
			BossDefinition.BOSS_ID,
			36,
			[
				BossPhaseDefinition.new(
					&"emergence",
					100,
					[
						BossActionDefinition.new(
							&"lash",
							"The Larval Avatar coils, telegraphing a heavy lash.",
							6,
							&"physical",
							"Lashes the adjacent hero for physical damage after a one-turn telegraph."
						),
						BossActionDefinition.new(
							&"skitter",
							"The Larval Avatar shifts its bulk, seeking a new angle.",
							0,
							&"physical",
							"Repositions without dealing damage, closing distance on the hero."
						)
					],
					"Emergence: the Avatar wakes and tests the hero with legible, telegraphed lashes."
				),
				BossPhaseDefinition.new(
					&"adaptation",
					60,
					[
						BossActionDefinition.new(
							&"lash",
							"The Larval Avatar coils tighter, its lash coming faster.",
							8,
							&"physical",
							"A stronger lash for physical damage, learned from the hero's openings."
						),
						BossActionDefinition.new(
							&"corrupt_mark",
							"The Larval Avatar's carapace weeps, marking the hero's tile.",
							5,
							&"corruption",
							"Marks the hero's tile and detonates it for corruption damage on a later turn."
						)
					],
					"Adaptation: the Avatar learns the hero's shape and adds a corrupting mark to punish standing still."
				),
				BossPhaseDefinition.new(
					&"desperation",
					25,
					[
						BossActionDefinition.new(
							&"frenzied_lash",
							"The Larval Avatar thrashes, telegraphing a frenzied strike.",
							11,
							&"physical",
							"A desperate high-damage lash; the widest telegraph the Avatar shows."
						),
						BossActionDefinition.new(
							&"corrupt_flood",
							"The Larval Avatar splits its hide, corruption pooling outward.",
							7,
							&"corruption",
							"Floods nearby tiles with corruption, pressuring the hero off safe ground."
						)
					],
					"Desperation: cornered below a quarter health, the Avatar strikes hardest and floods the arena."
				)
			],
			"The Larval Avatar is the finale's readable test: three escalating phases that check whether the run's preparation holds."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_boss_repository", {
		"reason": String(reason)
	})


static func _duplicate(boss_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_boss", {
		"reason": "duplicate_id",
		"id": String(boss_id)
	})
