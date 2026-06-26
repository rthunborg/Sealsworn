class_name RulesResolver
extends RefCounted

# The minimal deterministic rules-kernel resolver (Story 5.4) — the STARTING-passive seam. It holds the
# passives REGISTERED at run-start (each keyed by its declared trigger window(s)) and, given a trigger-window
# id, returns the matching passives in a STABLE deterministic order, each surfacing its readable explanation.
# This is the AC1 "available to the rules kernel through explicit trigger windows" application + the AC2
# "deterministic ... explanation entries" resolution.
#
# STABLE ORDER ([Decision]): registration order (the architecture's "stable queue and ordering"). resolve()
# returns the registered passives whose trigger_windows contain the queried window, in the order they were
# registered. Same registration sequence + same window -> byte-identical resolve()/explain() output (the AC2
# determinism guarantee).
#
# It is a PURE READ (like a snapshot / LevelValidator): it draws NO RNG, runs NO commands, and mutates no
# tactical state. v0 starting passives are PASSIVE + EXPLANATION-ONLY rule-benders — resolving a window
# surfaces the registered passive + its explanation; it does NOT mutate an HP/movement/damage number (that
# per-effect OPERATION is Story 5.5 / Epic 6).
#
# SCOPE: 5.4 wires the STARTING-passive registration + trigger-window collection + explanation ONLY. The full
# kernel's RuleCondition / RuleTarget / RuleOperation evaluation, stacking/conflict/duration handling, and the
# combat HOOK sites that FIRE these windows are Epic 6 (and Story 5.5) — scripts/rules/{conditions,operations}
# stay EMPTY scaffolding. It is a scene-free RefCounted service (no Node/scene/autoload).

const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")

# Registered passives in registration order (the stable resolution order). Holds PassiveDefinition resources
# ONLY (AC3 — no active-skill activation; a passive is a passive rule-bender).
var _registered_passives: Array[PassiveDefinition] = []

# Register a starting passive into the resolver. Registration order is the stable resolution order. A null
# definition is ignored (defensive — the caller resolves through the fail-closed PassiveRepository first, so
# a null never reaches here on the happy path). Draws no RNG, mutates no tactical state.
func register_passive(definition: PassiveDefinition) -> void:
	if definition == null:
		return
	_registered_passives.append(definition)


# Resolve a trigger window: return the registered passives whose trigger_windows contain `window_id`, in
# STABLE registration order. An unregistered/non-matching window returns an empty array. Pure read.
func resolve(window_id: StringName) -> Array[PassiveDefinition]:
	var matching: Array[PassiveDefinition] = []
	for definition: PassiveDefinition in _registered_passives:
		if definition.fires_in_window(window_id):
			matching.append(definition)
	return matching


# The readable explanation entries for a trigger window — each matching passive's explanation, in the same
# STABLE order as resolve(). The architecture's Readability Rule surface (player/debug-readable). A
# non-matching window returns an empty array. Pure read; deterministic.
func explain(window_id: StringName) -> Array[String]:
	var explanations: Array[String] = []
	for definition: PassiveDefinition in resolve(window_id):
		explanations.append(definition.explanation)
	return explanations


# The ids of every registered passive, in registration order. Used to surface the registered set via command
# metadata and to assert the resolver holds exactly the expected starting passives.
func registered_passive_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: PassiveDefinition in _registered_passives:
		ids.append(definition.passive_id)
	return ids


func registered_passive_count() -> int:
	return _registered_passives.size()
