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
const CurseDefinition = preload("res://scripts/content/definitions/curse_definition.gd")

# Registered passives in registration order (the stable resolution order). Holds PassiveDefinition resources
# ONLY (AC3 — no active-skill activation; a passive is a passive rule-bender).
var _registered_passives: Array[PassiveDefinition] = []

# Story 7.2 (AC3): registered CURSE/CORRUPTION effects in registration order, the curse/corruption analogue of
# _registered_passives. [Decision] Option A — a SEPARATE typed registry rather than broadening _registered_passives
# to a shared base (which would force an ugly cast and risk the 5.4 typed-passive contract). A curse is a rule source
# that satisfies the SAME fires_in_window(window_id) + explanation shape; resolve_curses(window) returns the matching
# curses and explain(window) merges curse explanations AFTER the passive explanations in stable order, so resolve()
# keeps its strict Array[PassiveDefinition] return untouched.
var _registered_curses: Array[CurseDefinition] = []

# Register a starting passive into the resolver. Registration order is the stable resolution order. A null
# definition is ignored (defensive — the caller resolves through the fail-closed PassiveRepository first, so
# a null never reaches here on the happy path). Draws no RNG, mutates no tactical state.
func register_passive(definition: PassiveDefinition) -> void:
	if definition == null:
		return
	_registered_passives.append(definition)


# Story 7.2 (AC3): register a CURSE/CORRUPTION effect into the resolver. Registration order is the stable resolution
# order (curses resolve AFTER passives in explain(); among curses, in registration order). A null definition is
# ignored (defensive — the caller seats a validated curse). Draws no RNG, mutates no tactical state (the curse's
# economy-side penalty is applied by the command, NOT here — the resolver is a PURE READ).
func register_curse(definition: CurseDefinition) -> void:
	if definition == null:
		return
	_registered_curses.append(definition)


# Resolve a trigger window: return the registered passives whose trigger_windows contain `window_id`, in
# STABLE registration order. An unregistered/non-matching window returns an empty array. Pure read.
func resolve(window_id: StringName) -> Array[PassiveDefinition]:
	var matching: Array[PassiveDefinition] = []
	for definition: PassiveDefinition in _registered_passives:
		if definition.fires_in_window(window_id):
			matching.append(definition)
	return matching


# Story 7.2 (AC3): resolve a trigger window for CURSE/CORRUPTION effects — return the registered curses whose
# trigger_windows contain `window_id`, in STABLE registration order. An unregistered/non-matching window returns an
# empty array. Pure read (mirrors resolve() for passives).
func resolve_curses(window_id: StringName) -> Array[CurseDefinition]:
	var matching: Array[CurseDefinition] = []
	for definition: CurseDefinition in _registered_curses:
		if definition.fires_in_window(window_id):
			matching.append(definition)
	return matching


# The readable explanation entries for a trigger window — each matching passive's explanation FOLLOWED BY each
# matching curse's explanation (Story 7.2 AC3), in the same STABLE order as resolve() / resolve_curses(). The
# architecture's Readability Rule surface (player/debug-readable). The curse explanations IDENTIFY their source (AC3).
# A non-matching window returns an empty array. Pure read; deterministic.
func explain(window_id: StringName) -> Array[String]:
	var explanations: Array[String] = []
	for definition: PassiveDefinition in resolve(window_id):
		explanations.append(definition.explanation)
	# Story 7.2: append curse explanations AFTER passive explanations (stable order — curses resolve after passives).
	for curse: CurseDefinition in resolve_curses(window_id):
		explanations.append(curse.explanation)
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


# Story 7.2: the ids of every registered curse, in registration order. Used to surface the registered curse set via
# command metadata and to assert the resolver holds exactly the expected curses.
func registered_curse_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: CurseDefinition in _registered_curses:
		ids.append(definition.curse_id)
	return ids


func registered_curse_count() -> int:
	return _registered_curses.size()
