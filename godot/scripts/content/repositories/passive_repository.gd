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
# DUPLICATE-ID NOTE: as of Story 6.1 (AC6), this repository — like all its siblings and the new Epic-6
# loot/reward repos — inherits the central ContentRepository duplicate-id fail-loud guard. A second
# registration under an already-present passive id returns a structured `duplicate_passive` error (the
# offending id in metadata) instead of silently last-write-winning; the rejected definition is neither stored
# nor appended to passive_ids(). The carried Epic-5 cross-cutting [Review][Defer] is closed here.
# test_passive_repository.gd pins this with a duplicate-id negative.

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

	var registration: ActionResult = _content_repository.register_definition(PassiveDefinition.DEFINITION_TYPE, definition.passive_id, definition)
	if registration.is_error():
		return _duplicate(definition.passive_id)
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
#
# STORY 6.4 — each baseline now carries the FR47 reward-modal fields + the FR77 served pillars. This is
# human-reviewable content (project-context.md "Human review decides whether ... a passive ... belongs in
# Sealsworn"): a real evocative flavor line, an EXPLICIT exact_mechanical_effects string (v0 passives are
# explanation-only, so the mechanics string describes the intended bend in player-readable terms — but it is
# EXPLICIT, not mysterious; GDD line 340), real Consume (power / build-identity) + Destroy (safety /
# purification / resources / refusal) text, the honest-unknown downside contract (these baselines have KNOWN
# effects -> has_unknown_consequences = false + a concrete consequences_text), the ICON_PLACEHOLDER sentinel
# (no icon art is authored this story), and at least one genuinely-fitting served pillar each. The pillar
# vocabulary is the fixed GDD four: tactical_clarity / build_synergy / risk / mystery.
static func _baseline_definitions() -> Array[PassiveDefinition]:
	return [
		PassiveDefinition.new(
			&"warrior_unbreakable_guard",
			"Unbreakable Guard",
			PassiveDefinition.KIND_CLASS,
			[RuleTrigger.BEFORE_ATTACK],
			"Unbreakable Guard (warrior class passive) steels the hero before an incoming attack.",
			PassiveDefinition.ICON_PLACEHOLDER,
			"An oath sworn over a shield-wall that never broke, and never will.",
			"Before an incoming attack resolves, braces the hero to reduce the damage about to be taken.",
			"Consume to carry the guard for the rest of the run as standing damage reduction against incoming blows.",
			"Destroy to release the oath, cleansing a measure of corruption from the hero.",
			false,
			"No hidden cost: the guard reduces incoming damage exactly as stated.",
			[PassiveDefinition.PILLAR_TACTICAL_CLARITY, PassiveDefinition.PILLAR_RISK]
		),
		PassiveDefinition.new(
			&"warrior_blade_and_board",
			"Blade and Board",
			PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
			[RuleTrigger.RUN_STARTED],
			"Blade and Board (warrior equipment synergy) pairs sword and shield as the run begins.",
			PassiveDefinition.ICON_PLACEHOLDER,
			"Steel in one hand, oak in the other; a soldier's whole world in two weights.",
			"When the run begins, links the equipped sword and shield so the pairing reinforces the warrior's stance.",
			"Consume to lock in the sword-and-shield pairing as a lasting part of your build identity.",
			"Destroy to dissolve the pairing, recovering salvage worth a small handful of gold.",
			false,
			"No hidden cost: the synergy only strengthens an already-equipped sword and shield.",
			[PassiveDefinition.PILLAR_BUILD_SYNERGY, PassiveDefinition.PILLAR_TACTICAL_CLARITY]
		),
		PassiveDefinition.new(
			&"pyromancer_kindling_focus",
			"Kindling Focus",
			PassiveDefinition.KIND_CLASS,
			[RuleTrigger.BEFORE_ATTACK],
			"Kindling Focus (pyromancer class passive) gathers flame before an attack.",
			PassiveDefinition.ICON_PLACEHOLDER,
			"The first spark is always the hungriest; she has learned to feed it slowly.",
			"Before an attack resolves, gathers flame so the pyromancer's outgoing strike carries added fire damage.",
			"Consume to keep the kindling as a permanent edge of bonus fire damage on your attacks.",
			"Destroy to smother the flame, banking the heat as a temporary burst of resolve.",
			false,
			"No hidden cost: the gathered flame adds to your own outgoing damage, not the enemy's.",
			[PassiveDefinition.PILLAR_BUILD_SYNERGY, PassiveDefinition.PILLAR_RISK]
		),
		PassiveDefinition.new(
			&"pyromancer_arcane_conduit",
			"Arcane Conduit",
			PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
			[RuleTrigger.RUN_STARTED],
			"Arcane Conduit (pyromancer equipment synergy) channels staff and tome as the run begins.",
			PassiveDefinition.ICON_PLACEHOLDER,
			"Staff and tome speak to one another in a tongue older than the Labyrinth.",
			"When the run begins, channels the equipped staff and tome together so the pairing amplifies arcane output.",
			"Consume to bind the staff-and-tome conduit into your build as a lasting amplifier.",
			"Destroy to sever the conduit, reclaiming a charge of arcane essence for later use.",
			false,
			"No hidden cost: the conduit amplifies your own arcane output and nothing else.",
			[PassiveDefinition.PILLAR_BUILD_SYNERGY]
		),
		PassiveDefinition.new(
			&"ranger_steady_aim",
			"Steady Aim",
			PassiveDefinition.KIND_CLASS,
			[RuleTrigger.BEFORE_ATTACK],
			"Steady Aim (ranger class passive) settles the shot before an attack.",
			PassiveDefinition.ICON_PLACEHOLDER,
			"Breath held, world narrowed to a single line; only the shot remains.",
			"Before an attack resolves, settles the ranger's aim to improve the outgoing shot's accuracy and reach.",
			"Consume to keep the steadied aim as a permanent accuracy bonus on your ranged attacks.",
			"Destroy to loose the held breath, granting a brief surge of focus for the next encounter.",
			false,
			"No hidden cost: the steadier aim improves only your own shots.",
			[PassiveDefinition.PILLAR_TACTICAL_CLARITY, PassiveDefinition.PILLAR_BUILD_SYNERGY]
		),
		PassiveDefinition.new(
			&"ranger_hunters_quiver",
			"Hunter's Quiver",
			PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
			[RuleTrigger.RUN_STARTED],
			"Hunter's Quiver (ranger equipment synergy) readies the bow's arrows as the run begins.",
			PassiveDefinition.ICON_PLACEHOLDER,
			"Every arrow is fletched for a different death; the hunter knows each one by touch.",
			"When the run begins, readies the equipped bow's quiver so the pairing keeps a fuller supply of arrows on hand.",
			"Consume to keep the readied quiver as a lasting part of your ranged build.",
			"Destroy to break down the quiver, recovering its arrows as a small cache of resources.",
			false,
			"No hidden cost: the readied quiver only benefits an already-equipped bow.",
			[PassiveDefinition.PILLAR_BUILD_SYNERGY]
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_passive_repository", {
		"reason": String(reason)
	})


static func _duplicate(passive_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_passive", {
		"reason": "duplicate_id",
		"id": String(passive_id)
	})
