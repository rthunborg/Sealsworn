class_name EventRepository
extends RefCounted

# The fail-closed RISK/REWARD EVENT content repository (Story 7.3) — a BYTE-FOR-STRUCTURE clone of
# CursedRewardRepository / PassiveRepository. It holds the approved baseline EventDefinition set, registered through the
# ContentRepository boundary, and resolves an event id to its typed EventDefinition via get_event(id) — returning null
# on a miss (fail-closed; the generate_event_offer / ChooseEventOptionCommand validate-before-use gate). An event that
# fails validate() is never in the repository, so it can never be offered or chosen.
#
# DUPLICATE-ID NOTE: this repository inherits the central ContentRepository duplicate-id fail-loud guard (Story 6.1
# AC6, ratified all-repos posture). A second registration under an already-present event id returns a structured
# `duplicate_event` error (the offending id in metadata) instead of silently last-write-winning; the rejected
# definition is neither stored nor appended to event_ids(). test_event_repository.gd pins this with a duplicate-id
# negative.
#
# CONTENT-AS-CODE-CONSTANT (project-context): the baseline is a code constant authored as a _baseline_definitions()
# array — data/source and data/resources stay EMPTY (no JSON/.tres pipeline; Epic 6/7 added none).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")

const BASELINE_EVENT_IDS: Array[StringName] = [
	&"smugglers_cache",
	&"corrupting_reforge",
	&"forsaken_armory"
]

var _content_repository: ContentRepository
var _event_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> EventRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> EventRepository:
	var validated_definitions: Array[EventDefinition] = []
	for definition_value: Variant in definitions:
		var definition: EventDefinition = definition_value as EventDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: EventRepository = load("res://scripts/content/repositories/event_repository.gd").new(content_repository)
	for definition: EventDefinition in validated_definitions:
		var result: ActionResult = repository.register_event(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_events() -> ActionResult:
	for definition: EventDefinition in _baseline_definitions():
		var result: ActionResult = register_event(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_event(definition: EventDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_event")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(EventDefinition.DEFINITION_TYPE, definition.event_id, definition)
	if registration.is_error():
		return _duplicate(definition.event_id)
	if not _event_order.has(definition.event_id):
		_event_order.append(definition.event_id)
	return ActionResult.ok([], {
		"event_id": String(definition.event_id)
	})


func get_event(event_id: StringName) -> EventDefinition:
	return _content_repository.get_definition(EventDefinition.DEFINITION_TYPE, event_id) as EventDefinition


func has_event(event_id: StringName) -> bool:
	return _content_repository.has_definition(EventDefinition.DEFINITION_TYPE, event_id)


func event_ids() -> Array[StringName]:
	return _event_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


# The approved baseline RISK/REWARD EVENT set, drawn from the GDD risk examples (GDD lines 466-471). Each is a
# readable, tempting choice the player can evaluate BEFORE accepting (GDD lines 461-462 — the same human-reviewable bar
# the 7.2 cursed-reward baselines met). The three GDD AC2 templates are realised:
#   - smugglers_cache: "accept gold now and increase elite chance later" (GDD line 470) — a choice giving gold NOW +
#     raising an `elite_chance` risk flag (the FLAG is the future-danger record; 7.3 is the PRODUCER, a later story
#     READS it), plus a safe "leave it" decline choice (the GDD safety option that grants nothing + raises no risk).
#   - corrupting_reforge: "reforge for cheap, but add corruption" (GDD line 469) — a choice giving gold (the cheap
#     reforge framed as recovered gold) + a corruption increment, versus a safe "pay full price / walk away" decline.
#   - forsaken_armory: "gain a strong passive, but lose max HP" (GDD line 466) — modeled (per the story [Decision], the
#     SAME boundary 7.2 drew) as the ECONOMY side (a gold/healing benefit) + a RECORDED penalty (a curse increment) + a
#     `max_hp_loss` future-danger flag, NOT a literal passive grant or a live HP mutation (v0 has no live max-HP). Plus
#     a safe "leave the armory" decline.
static func _baseline_definitions() -> Array[EventDefinition]:
	return [
		EventDefinition.new(
			&"smugglers_cache",
			"The Smuggler's Cache",
			"A smuggler offers you a purse of gold now, on the condition that you draw the attention of the Labyrinth's elite hunters later. Take the gold, or leave the cache untouched.",
			[
				EventChoiceDefinition.new(
					&"take_the_gold",
					"Take the gold now and accept that the elites will hunt you later.",
					35,  # gold_benefit — gold NOW
					0,   # healing_benefit
					0,   # curse_increment
					0,   # corruption_increment
					0,   # gold_cost
					0,   # healing_cost
					["elite_chance"]  # the future-danger record (a later story reads it; 7.3 only raises it)
				),
				EventChoiceDefinition.new(
					&"leave_the_cache",
					"Leave the cache untouched and draw no extra attention.",
					0, 0, 0, 0, 0, 0, []  # safe decline: no reward, no risk, no flag
				)
			]
		),
		EventDefinition.new(
			&"corrupting_reforge",
			"The Corrupting Reforge",
			"A tainted forge offers to reforge your gear for almost nothing, recovering a handful of gold from the bargain — but its essence leaves a mark of corruption on you. Reforge cheaply, or walk away.",
			[
				EventChoiceDefinition.new(
					&"reforge_cheaply",
					"Reforge for almost nothing, recovering gold, and accept the mark of corruption.",
					18,  # gold_benefit — the cheap reforge framed as recovered gold
					0,   # healing_benefit
					0,   # curse_increment
					1,   # corruption_increment — the headline risk (the corruption mark)
					0,   # gold_cost
					0,   # healing_cost
					[]   # corruption increment IS the risk; no extra flag needed
				),
				EventChoiceDefinition.new(
					&"walk_away",
					"Walk away from the tainted forge and keep your gear as it is.",
					0, 0, 0, 0, 0, 0, []  # safe decline
				)
			]
		),
		EventDefinition.new(
			&"forsaken_armory",
			"The Forsaken Armory",
			"An armory of the forsaken holds gear of uncommon power, but to bear it you must swear an oath that weakens you — a curse settles, and your strength will be tested later. Claim the gear, or leave the armory.",
			[
				EventChoiceDefinition.new(
					&"claim_the_gear",
					"Claim the powerful gear and accept the curse and the weakening it brings.",
					45,  # gold_benefit — the gear's power/worth, framed as gold in v0 (no live passive grant / max-HP)
					0,   # healing_benefit
					1,   # curse_increment — the recorded penalty (a curse settles)
					0,   # corruption_increment
					0,   # gold_cost
					0,   # healing_cost
					["max_hp_loss"]  # the "lose max HP" future-danger record (a flag, not a live HP mutation)
				),
				EventChoiceDefinition.new(
					&"leave_the_armory",
					"Leave the armory and bear no curse.",
					0, 0, 0, 0, 0, 0, []  # safe decline
				)
			]
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_event_repository", {
		"reason": String(reason)
	})


static func _duplicate(event_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_event", {
		"reason": "duplicate_id",
		"id": String(event_id)
	})
