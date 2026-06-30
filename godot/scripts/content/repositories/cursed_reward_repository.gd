class_name CursedRewardRepository
extends RefCounted

# The fail-closed CURSED-REWARD content repository (Story 7.2) — a BYTE-FOR-STRUCTURE clone of PassiveRepository /
# ConsumableRepository. It holds the approved baseline CursedRewardDefinition set, registered through the
# ContentRepository boundary, and resolves a cursed-reward id to its typed CursedRewardDefinition via
# get_cursed_reward(id) — returning null on a miss (fail-closed; the AcceptCursedRewardCommand validate-before-use
# gate). [Decision] A repository (not an inline baseline array on the command) is used because the by-id
# validate-before-use gate is the established Epic-5/6 pattern (the fail-closed unknown_cursed_reward posture mirrors
# PassiveRepository's unknown_passive gate); a cursed reward that fails validate() is never in the repository, so it
# can never be accepted.
#
# DUPLICATE-ID NOTE: this repository inherits the central ContentRepository duplicate-id fail-loud guard (Story 6.1
# AC6, ratified all-repos posture). A second registration under an already-present cursed-reward id returns a
# structured `duplicate_cursed_reward` error (the offending id in metadata) instead of silently last-write-winning;
# the rejected definition is neither stored nor appended to cursed_reward_ids(). test_cursed_reward_repository.gd
# pins this with a duplicate-id negative.
#
# CONTENT-AS-CODE-CONSTANT (project-context): the baseline is a code constant authored as a _baseline_definitions()
# array — data/source and data/resources stay EMPTY (no JSON/.tres pipeline; Epic 6 added none).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")

const BASELINE_CURSED_REWARD_IDS: Array[StringName] = [
	&"cursed_blade_of_the_forsaken",
	&"corrupting_reforge_bargain",
	&"whispering_relic_of_the_deep"
]

var _content_repository: ContentRepository
var _cursed_reward_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> CursedRewardRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> CursedRewardRepository:
	var validated_definitions: Array[CursedRewardDefinition] = []
	for definition_value: Variant in definitions:
		var definition: CursedRewardDefinition = definition_value as CursedRewardDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: CursedRewardRepository = load("res://scripts/content/repositories/cursed_reward_repository.gd").new(content_repository)
	for definition: CursedRewardDefinition in validated_definitions:
		var result: ActionResult = repository.register_cursed_reward(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_cursed_rewards() -> ActionResult:
	for definition: CursedRewardDefinition in _baseline_definitions():
		var result: ActionResult = register_cursed_reward(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_cursed_reward(definition: CursedRewardDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_cursed_reward")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(CursedRewardDefinition.DEFINITION_TYPE, definition.cursed_reward_id, definition)
	if registration.is_error():
		return _duplicate(definition.cursed_reward_id)
	if not _cursed_reward_order.has(definition.cursed_reward_id):
		_cursed_reward_order.append(definition.cursed_reward_id)
	return ActionResult.ok([], {
		"cursed_reward_id": String(definition.cursed_reward_id)
	})


func get_cursed_reward(cursed_reward_id: StringName) -> CursedRewardDefinition:
	return _content_repository.get_definition(CursedRewardDefinition.DEFINITION_TYPE, cursed_reward_id) as CursedRewardDefinition


func has_cursed_reward(cursed_reward_id: StringName) -> bool:
	return _content_repository.has_definition(CursedRewardDefinition.DEFINITION_TYPE, cursed_reward_id)


func cursed_reward_ids() -> Array[StringName]:
	return _cursed_reward_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


# The approved baseline CURSED-REWARD set, drawn from the GDD risk examples (GDD lines 464-471). Each is a GENUINE
# tradeoff (a clear upside AND a clear downside) the player can evaluate BEFORE accepting WITHOUT hidden knowledge
# (GDD lines 461-462). This is human-reviewable content (project-context "Human review decides whether ... belongs in
# Sealsworn"): a real evocative name, a clear upside line, a clear downside line, and the honest hidden/delayed-
# consequence contract (a KNOWN-downside line OR an honest "future penalty, exact form unknown" line — never blank).
#   - cursed_blade_of_the_forsaken: "a cursed item with higher stats but a future penalty" (GDD line 467) — a gold
#     benefit (the item's resale/power framed as gold in v0) + a curse increment + an HONEST delayed-consequence line.
#   - corrupting_reforge_bargain: "reforge for cheap, but add corruption" (GDD line 469) — a gold benefit (the cheap
#     reforge framed as recovered gold) + a corruption increment, a KNOWN downside (no hidden consequence).
#   - whispering_relic_of_the_deep: an honest-UNKNOWN variant — a healing benefit + a curse increment with an honest
#     "a future penalty, exact form unknown" delayed-consequence line (the honest-unknown contract surfaced).
static func _baseline_definitions() -> Array[CursedRewardDefinition]:
	return [
		CursedRewardDefinition.new(
			&"cursed_blade_of_the_forsaken",
			"Cursed Blade of the Forsaken",
			"Claim a blade of uncommon power, worth a heavy purse of gold to one who can bear its weight.",
			"The blade is bound to a curse that settles on the bearer the moment it is taken up.",
			40,  # gold_benefit — the blade's power/worth, framed as gold in v0 (no live max-HP/passive grant to mutate)
			0,   # healing_benefit
			1,   # curse_increment — the headline downside (a curse settles on the bearer)
			0,   # corruption_increment
			0,   # gold_cost
			0,   # healing_cost
			true,  # has_delayed_consequences — the curse's bite comes later
			"The curse demands its due later in the run; the exact moment is the blade's to choose, but it will come."
		),
		CursedRewardDefinition.new(
			&"corrupting_reforge_bargain",
			"Corrupting Reforge Bargain",
			"Reforge your gear for almost nothing, recovering a handful of gold from the bargain.",
			"The reforge draws on tainted Labyrinth essence, leaving a mark of corruption on you.",
			15,  # gold_benefit — the cheap reforge framed as recovered gold
			0,   # healing_benefit
			0,   # curse_increment
			1,   # corruption_increment — the headline downside (the corruption mark)
			0,   # gold_cost
			0,   # healing_cost
			false,  # has_delayed_consequences — the cost is KNOWN and immediate
			"No hidden cost beyond the corruption: the reforge is cheap because the taint is the price."
		),
		CursedRewardDefinition.new(
			&"whispering_relic_of_the_deep",
			"Whispering Relic of the Deep",
			"Take up a relic that mends a measure of your wounds, restoring healing to your reserves.",
			"The relic whispers, and a curse takes root in whoever heeds it.",
			0,   # gold_benefit
			2,   # healing_benefit — the relic restores healing availability
			1,   # curse_increment — the headline downside (a curse takes root)
			0,   # corruption_increment
			0,   # gold_cost
			0,   # healing_cost
			true,  # has_delayed_consequences — honestly UNKNOWN
			"Honestly unknown: the relic promises a future penalty, but its exact form cannot be read before you accept."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_cursed_reward_repository", {
		"reason": String(reason)
	})


static func _duplicate(cursed_reward_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_cursed_reward", {
		"reason": "duplicate_id",
		"id": String(cursed_reward_id)
	})
