class_name AffinityRepository
extends RefCounted

# The fail-closed AFFINITY content repository (Story 7.4) — a BYTE-FOR-STRUCTURE clone of CursedRewardRepository /
# PassiveRepository. It holds the approved baseline AffinityDefinition set (the 4 MVP affinities + the neutral `none`),
# registered through the ContentRepository boundary, and resolves an affinity id to its typed AffinityDefinition via
# get_affinity(id) — returning null on a miss (fail-closed; the deterministic assignment's validate-before-use gate).
# It is the PRODUCER side of 7.4: the definitions + the neutral contract live here; the deterministic assignment that
# SELECTS one (RunOrchestrator.assign_affinity) resolves through this repository.
#
# THE AC3 NEUTRAL QUERY SURFACE: tactical_rules_for(affinity_id) is the single PURE-READ surface a tactical system
# calls ("When tactical systems query affinity rules Then they receive an empty or neutral rule set"). It returns the
# affinity's recorded tactical_rules for a real affinity, and the EMPTY set for the neutral `none` AND for an UNKNOWN
# id. [Decision] An unknown id returns the EMPTY/NEUTRAL set (lenient), NOT a crash and NOT a structured miss — AC3
# demands "an empty or neutral rule set ... no affinity side effects" for the no-affinity case, and treating an unknown
# id as neutral keeps any future caller fail-SAFE (a level whose affinity id does not resolve produces NO side effects
# rather than crashing). The validate-before-USE gate (rejecting an unknown id) is the ASSIGNMENT's job
# (RunOrchestrator.assign_affinity resolves the SELECTED id through get_affinity and fails closed on a miss); the READ
# surface a tactical system calls is deliberately neutral-on-miss.
#
# DUPLICATE-ID NOTE: this repository inherits the central ContentRepository duplicate-id fail-loud guard (Story 6.1
# AC6, ratified all-repos posture). A second registration under an already-present affinity id returns a structured
# `duplicate_affinity` error (the offending id in metadata) instead of silently last-write-winning; the rejected
# definition is neither stored nor appended to affinity_ids(). test_affinity_repository.gd pins this with a duplicate-id
# negative.
#
# CONTENT-AS-CODE-CONSTANT (project-context): the baseline is a code constant authored as a _baseline_definitions()
# array — data/source and data/resources stay EMPTY (no JSON/.tres pipeline; Epic 6/7 added none).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")

# The baseline affinity ids in stable registration order: the 4 MVP affinities (FR56; GDD lines 500-505) plus the
# neutral `none` (registered LAST). The neutral id reuses AffinityDefinition.AFFINITY_NONE (== &"none").
const BASELINE_AFFINITY_IDS: Array[StringName] = [
	&"scorched",
	&"flooded_conductive",
	&"cursed",
	&"darkness",
	&"none"
]

var _content_repository: ContentRepository
var _affinity_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> AffinityRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> AffinityRepository:
	var validated_definitions: Array[AffinityDefinition] = []
	for definition_value: Variant in definitions:
		var definition: AffinityDefinition = definition_value as AffinityDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: AffinityRepository = load("res://scripts/content/repositories/affinity_repository.gd").new(content_repository)
	for definition: AffinityDefinition in validated_definitions:
		var result: ActionResult = repository.register_affinity(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_affinities() -> ActionResult:
	for definition: AffinityDefinition in _baseline_definitions():
		var result: ActionResult = register_affinity(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_affinity(definition: AffinityDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_affinity")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(AffinityDefinition.DEFINITION_TYPE, definition.affinity_id, definition)
	if registration.is_error():
		return _duplicate(definition.affinity_id)
	if not _affinity_order.has(definition.affinity_id):
		_affinity_order.append(definition.affinity_id)
	return ActionResult.ok([], {
		"affinity_id": String(definition.affinity_id)
	})


func get_affinity(affinity_id: StringName) -> AffinityDefinition:
	return _content_repository.get_definition(AffinityDefinition.DEFINITION_TYPE, affinity_id) as AffinityDefinition


func has_affinity(affinity_id: StringName) -> bool:
	return _content_repository.has_definition(AffinityDefinition.DEFINITION_TYPE, affinity_id)


func affinity_ids() -> Array[StringName]:
	return _affinity_order.duplicate()


# The AC3 NEUTRAL QUERY SURFACE — a PURE READ (no mutation, no RNG): return the affinity's recorded tactical_rules for
# a real registered affinity, and the EMPTY/NEUTRAL set for the neutral `none` AND for an UNKNOWN id (fail-safe to
# neutral, never a crash). This is the single surface a tactical system calls to ask "what affinity rules apply to this
# level" — the no-affinity / unknown case yields an empty set so NO affinity side effects occur (AC3). The returned
# Array is a fresh DEEP copy (the caller can never mutate the definition's stored rules).
func tactical_rules_for(affinity_id: StringName) -> Array:
	var definition: AffinityDefinition = get_affinity(affinity_id)
	if definition == null:
		# Unknown id (or the neutral id never registered): fail-SAFE to the empty/neutral rule set (AC3). The
		# validate-before-USE gate (rejecting an unknown SELECTED id) is the assignment's job, not this read surface.
		return []
	# A registered affinity (real or the neutral `none`) returns its recorded rules — the neutral affinity's is EMPTY.
	return definition.tactical_rules_copy()


func content_repository() -> ContentRepository:
	return _content_repository


# The approved baseline AFFINITY set (FR56; GDD lines 500-505), authored as human-reviewable content (project-context
# "Human review decides whether ... an affinity ... belongs in Sealsworn"): each MVP affinity has a real evocative
# display name, >= 1 RECORDED tactical_rule marker describing its intended tactical PRESSURE (RECORD/EXPLANATION-ONLY
# — the 7.5 effects layer reads these; 7.4 does NOT execute them), the matching visual_tag (the existing
# affinity.<kind>.png board art id), and an honest explanation. The neutral `none` is registered LAST with an EMPTY
# rule set + EMPTY tags + a neutral explanation (the AC3 contract). The GDD descriptions (lines 502-505) are the source
# for each affinity's pressure language. NONE of these values is a hidden difficulty multiplier (the hard non-goal) —
# they are descriptive rule-marker ids + prose the effects layer will interpret.
static func _baseline_definitions() -> Array[AffinityDefinition]:
	return [
		# Scorched (GDD line 502): "failed purge protocol; fire hazards, burning terrain, and damage-over-time
		# pressure." Rule markers RECORD the fire-hazard / burning-terrain / DoT pressure (the 7.5 Scorched effects
		# layer reads these; v0 records them only).
		AffinityDefinition.new(
			&"scorched",
			"Scorched",
			[
				{
					"rule_id": "fire_hazard_cells",
					"description": "Failed purge protocol leaves fire hazards across the level that threaten any hero who lingers in them."
				},
				{
					"rule_id": "burning_terrain_spread",
					"description": "Burning terrain can spread, pressuring movement and shrinking safe positioning over the encounter."
				},
				{
					"rule_id": "damage_over_time_pressure",
					"description": "Caught heroes suffer damage-over-time pressure, rewarding decisive, short engagements over attrition."
				}
			],
			[&"scorched"] as Array[StringName],
			"Scorched: a failed purge protocol. Fire hazards and burning terrain create damage-over-time pressure — move decisively and do not linger in the flames."
		),
		# Flooded/Conductive (GDD line 503): "broken ward conduits; water/electric interactions, pathing pressure, and
		# danger zones." The art is affinity.flooded.png, so the visual tag is `flooded` (with a `conductive` cue tag).
		AffinityDefinition.new(
			&"flooded_conductive",
			"Flooded / Conductive",
			[
				{
					"rule_id": "water_electric_interaction",
					"description": "Broken ward conduits make water and electric effects interact, turning flooded tiles into conductive danger zones."
				},
				{
					"rule_id": "pathing_pressure",
					"description": "Flooded terrain reshapes viable paths, pressuring positioning and routing around the hazardous water."
				},
				{
					"rule_id": "danger_zone_marking",
					"description": "Conductive danger zones punish standing in water when an electric source is active nearby."
				}
			],
			[&"flooded", &"conductive"] as Array[StringName],
			"Flooded / Conductive: broken ward conduits. Water and electric interactions plus pathing pressure create conductive danger zones — watch where you stand when current flows."
		),
		# Cursed (GDD line 504): "corrupted oath-law; risk/reward, penalties, and dangerous bargains." (7.4 RECORDS the
		# Cursed affinity; the reward-odds modifier / "enter a cursed node for better reward odds" consumer is a later
		# story — NOT wired here.)
		AffinityDefinition.new(
			&"cursed",
			"Cursed",
			[
				{
					"rule_id": "risk_reward_bargains",
					"description": "Corrupted oath-law offers dangerous bargains — stronger rewards paid for with a tangible penalty."
				},
				{
					"rule_id": "curse_penalty_pressure",
					"description": "Acting greedily here risks a curse penalty, weighing the upside of a bargain against its lingering cost."
				}
			],
			[&"cursed"] as Array[StringName],
			"Cursed: corrupted oath-law. Risk/reward bargains and penalties tempt the greedy — weigh each dangerous bargain against the curse it may leave behind."
		),
		# Darkness (GDD line 505): "failed concealment protocol; reduced visibility, hidden threats, uncertainty, and
		# stronger fog/memory pressure." The 7.6 fairness layer reads these markers (the Darkness guardrail, GDD lines
		# 507-512); 7.4 authors the DEFINITION + assigns it, it does NOT change the fog/LOS/explored-memory model.
		AffinityDefinition.new(
			&"darkness",
			"Darkness",
			[
				{
					"rule_id": "reduced_visibility",
					"description": "Failed concealment protocol reduces visibility, shrinking how far the hero can see across the level."
				},
				{
					"rule_id": "hidden_threats",
					"description": "Threats can lurk unseen, rewarding cautious scouting over blind advances into the dark."
				},
				{
					"rule_id": "fog_memory_pressure",
					"description": "Explored memory is less reliable, pressuring the player to stay oriented under stronger fog — uncertainty, never an unavoidable ambush (the Darkness fairness guardrail)."
				}
			],
			[&"darkness"] as Array[StringName],
			"Darkness: a failed concealment protocol. Reduced visibility and hidden threats create uncertainty and fog/memory pressure — be cautious and clever, never ambushed unfairly."
		),
		# The neutral / no-affinity definition (AC3): EMPTY tactical_rules, EMPTY visual_tags, a neutral explanation.
		# Registered LAST. get_affinity(&"none") resolves it; tactical_rules_for(&"none") returns the EMPTY set.
		AffinityDefinition.neutral()
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_affinity_repository", {
		"reason": String(reason)
	})


static func _duplicate(affinity_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_affinity", {
		"reason": "duplicate_id",
		"id": String(affinity_id)
	})
