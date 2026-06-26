class_name RunState
extends RefCounted

# Scene-independent run-progression state machine (Story 4.1). RunState is the architecture's
# RunState machine ([game-architecture.md] §State Management line 330): phases new_run -> active_
# route -> node_resolution -> completed/failed. It records the AC1 truth (root seed, manual-seed
# eligibility, current phase, current node pointer via the route, cleared nodes via the route, and
# the derived available route choices) and rejects invalid transitions with a structured
# ActionResult and ZERO mutation.
#
# IT IS NOT route generation (Story 4.2 — draws the `map` stream; 4.1 draws NO RNG), route
# choice/commit (Story 4.3), node entry/exit + level-request creation (Story 4.4), or per-node-type
# resolution (Story 4.5). It is a pure, deterministic function of its inputs and composes into the
# existing RunSnapshot — it does NOT fork a parallel run-save format.
#
# Mirrors CombatOutcomeState's small-state-machine + serialization precedent (STATE_* constants,
# is_terminal(), validate() -> ActionResult, to_dictionary(), copy(), try_/from_dictionary).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")

# Phase machine ([game-architecture.md] line 330). lower_snake wire ids held in UPPER_SNAKE consts.
const PHASE_NEW_RUN := &"new_run"
const PHASE_ACTIVE_ROUTE := &"active_route"
const PHASE_NODE_RESOLUTION := &"node_resolution"
const PHASE_COMPLETED := &"completed"
const PHASE_FAILED := &"failed"

# Key under which the run phase is NESTED inside the route_state payload, so the pinned 23-key
# RunSnapshot top-level no-surprise-key gate stays green untouched (Task 4.3 decision).
const RUN_PHASE_KEY := &"run_phase"

# Story 5.3: key under which the selected class id is NESTED inside the route_state payload of
# to_run_snapshot_fields(), so a between-node route-position save carries the class (closing the 5.2 -> 5.3
# persistence defer) WITHOUT adding a new top-level RunSnapshot key (the pinned 23-key gate stays green). The
# kit is NOT persisted — it is RE-DERIVED from the class id on restore (a deterministic pure function of the
# class + the baseline repos), so this single nested id is the entire route-position persistence surface.
const SELECTED_CLASS_ID_KEY := &"selected_class_id"

var phase: StringName = PHASE_NEW_RUN
var root_seed: int = 0
var is_manual_seed: bool = false
var meta_progression_eligible: bool = true
var route: RouteState = null
# The selected hero class id (Story 5.2). An ADDITIVE live-run field: default &"" is a legacy "no class
# chosen" run (still valid — RunStartCommand's empty-class back-compat path). RunStartCommand records it
# AFTER new_run() when the hero-select confirm path supplies a selectable class. It is DELIBERATELY NOT a
# required validate() field (an empty class is a valid run) and DELIBERATELY NOT in to_run_snapshot_fields()
# / the route-position save this story (Option A — the pinned 23-key RunSnapshot gate stays green untouched;
# Story 5.3 owns class persistence alongside the derived kit). It rides to_dictionary()/try_from_dictionary
# (the FULL run dict, NOT the 23-key snapshot) lenient-read so copied/round-tripped runs preserve the class.
var selected_class_id: StringName = &""
# The APPLIED starting kit (Story 5.3). An ADDITIVE + LENIENT run-progression field: default null is a legacy
# "no kit" run (a seed-only / empty-class start records NO kit; pre-5.3 run dicts / saves parse with null). It
# is RECORDED by RunStartCommand AFTER selected_class_id when a confirmed-selectable class starts a run (the
# resolved weapon/support ids + baseline_hp + the two passive-id references). DELIBERATELY NOT a required
# validate() field (an empty-class/legacy run has no kit and must still validate). It rides
# to_dictionary()/try_from_dictionary (the FULL run dict, NOT the 23-key RunSnapshot) lenient-read so a copied/
# round-tripped run preserves the kit. It is DELIBERATELY NOT serialized into the route-position save — the kit
# is RE-DERIVED from selected_class_id on restore (see SELECTED_CLASS_ID_KEY), keeping the save minimal.
var starting_kit: StartingKit = null
# The run's rules-kernel resolver holding the registered STARTING passives (Story 5.4). An ADDITIVE + LENIENT
# run-progression field: default null is a legacy "no resolver" run (a seed-only / empty-class start seats NO
# resolver; pre-5.4 run dicts / saves parse with null). RunStartCommand SEATS it AFTER starting_kit when a
# confirmed-selectable class starts a run — it registers the class's two resolved PassiveDefinitions (the
# class passive + the equipment-synergy passive) into a RulesResolver keyed by their declared trigger windows.
# This is the AC1 "available to the rules kernel through explicit trigger windows" run-domain surface (NOT a
# global / autoload / side-channel — it lives on the RunState).
#
# It is DELIBERATELY NOT a required validate() field (an empty-class/legacy run has no resolver and must still
# validate). It is DELIBERATELY NOT serialized — it is a LIVE RefCounted service (like the run-level
# RngStreamSet on RunOrchestrator and the 5.3 starting_kit), RE-DERIVED from selected_class_id on restore
# (re-derive the kit -> resolve the two passive ids -> rebuild the resolver), so it is NOT in
# to_dictionary() / to_run_snapshot_fields() / the 23-key RunSnapshot. copy() carries the reference (a live
# re-derivable service; a copied run keeps the same registered passives — the resolver is immutable content).
var rules_resolver: RulesResolver = null
# The run's small inventory + equipment domain model (Story 6.2). An ADDITIVE + LENIENT run-progression field:
# it defaults to a fresh EMPTY InventoryState (never null), so a legacy / seed-only / empty-class run carries an
# empty backpack rather than a null — the pickup command never needs a null guard. PickupItemCommand mutates it
# (records a gained item + emits item_gained). It is DELIBERATELY NOT a required validate() field (an empty
# inventory is a valid run; a pre-6.2 run dict with no inventory key parses to a fresh empty one). It rides
# to_dictionary()/try_from_dictionary (the FULL run dict, NOT the 23-key RunSnapshot) lenient-read so a copied/
# round-tripped run preserves the backpack/equipment. It is DELIBERATELY NOT serialized into the route-position
# save (the RunSnapshot.inventory/equipment placeholders stay EMPTY this story — there is no live in-node
# inventory save yet; a later story that owns the in-node save wires the model into those existing fields).
# copy() DEEP-copies it (the backpack slot list must not be shared by reference).
var inventory: InventoryState = null
# The run's PENDING reward offer (Story 6.3). An ADDITIVE + LENIENT run-progression field: default null is "no
# pending offer" (most of the time there is no offer — a legacy / pre-6.3 / between-offer run carries null). The
# reward GENERATE path (RunOrchestrator.generate_reward_offer) ROLLS a deterministic offer through the run-level
# RngStreamSet and STORES it here as `pending`; ResolveRewardCommand applies the chosen entry and flips it to
# `resolved`. It is DELIBERATELY NOT a required validate() field (a run with no offer is valid; a pre-6.3 run dict
# with no offer key parses to null). It is SERIALIZABLE DATA ONLY (a RewardOffer value object — NEVER a live
# RewardTableDefinition/RngStreamSet). It rides to_dictionary()/try_from_dictionary (the FULL run dict, NOT the
# 23-key RunSnapshot) lenient-read so a copied/round-tripped run preserves a pending offer. It is DELIBERATELY
# NOT serialized into the route-position save (a between-NODE route choice is composed AFTER the node resolves, by
# which point the offer is already resolved — the live in-node reward-offer save is a later story; the
# RunSnapshot 23-key gate stays untouched). copy() null-safe DEEP-copies it (the offered-entries list must not be
# shared by reference).
var pending_reward_offer: RewardOffer = null

func _init(
	new_phase: StringName = PHASE_NEW_RUN,
	new_root_seed: int = 0,
	new_is_manual_seed: bool = false,
	new_meta_progression_eligible: bool = true,
	new_route: RouteState = null,
	new_selected_class_id: StringName = &"",
	new_starting_kit: StartingKit = null,
	new_rules_resolver: RulesResolver = null,
	new_inventory: InventoryState = null,
	new_pending_reward_offer: RewardOffer = null
) -> void:
	phase = new_phase
	root_seed = new_root_seed
	is_manual_seed = new_is_manual_seed
	meta_progression_eligible = new_meta_progression_eligible
	route = new_route if new_route != null else load("res://scripts/run/route_state.gd").new()
	selected_class_id = new_selected_class_id
	starting_kit = new_starting_kit
	rules_resolver = new_rules_resolver
	# Default to a fresh EMPTY inventory (never null) so the backpack is always present.
	inventory = new_inventory if new_inventory != null else load("res://scripts/run/inventory_state.gd").new()
	# Default to null (no pending offer). Unlike the inventory, null is the meaningful "nothing to resolve" state.
	pending_reward_offer = new_pending_reward_offer


# AC1 "new run" entry point: a fresh run in PHASE_NEW_RUN with the manual-seed eligibility invariant
# applied, an empty current-node pointer, and no cleared nodes. Draws NO RNG (run-state init is a
# pure function of its inputs; the `map` stream's first consumer is Story 4.2).
static func new_run(
	root_seed: int,
	is_manual_seed: bool = false,
	route: RouteState = null
) -> RunState:
	var run_route: RouteState = route if route != null else load("res://scripts/run/route_state.gd").new()
	# A fresh run is parked at a route choice, not inside a node.
	run_route.current_node_id = ""
	run_route.cleared_node_ids = []
	return load("res://scripts/run/run_state.gd").new(
		PHASE_NEW_RUN,
		root_seed,
		is_manual_seed,
		not is_manual_seed,
		run_route
	)


func is_terminal() -> bool:
	return phase == PHASE_COMPLETED or phase == PHASE_FAILED


func can_transition_to(next_phase: StringName) -> bool:
	return _legal_next_phases(phase).has(next_phase)


# Validated transition. On a legal edge: mutate `phase` and return ok. On an illegal edge: return a
# structured error and mutate NOTHING (the run-state object stays byte-identical).
func transition_to(next_phase: StringName) -> ActionResult:
	if not can_transition_to(next_phase):
		return ActionResult.error(&"invalid_run_transition", {
			"from": String(phase),
			"to": String(next_phase)
		})
	phase = next_phase
	return ActionResult.ok()


func validate() -> ActionResult:
	if not _is_supported_phase(phase):
		return ActionResult.error(&"invalid_run_phase", {
			"field": "phase",
			"phase": String(phase)
		})
	# Manual-seed invariant (mirror RunSnapshot.from_between_level): a manual-seed run is NEVER
	# meta-eligible. The actual meta gate is Epic 8; 4.1 only records eligibility.
	if meta_progression_eligible != (not is_manual_seed):
		return ActionResult.error(&"invalid_run_meta_eligibility", {
			"field": "meta_progression_eligible",
			"is_manual_seed": is_manual_seed,
			"meta_progression_eligible": meta_progression_eligible
		})
	if route == null:
		return ActionResult.error(&"invalid_run_route", {"field": "route"})
	# Delegate route integrity to RouteState.validate().
	return route.validate()


# Derived AC1 "available route choices" — convenience pass-through to the route graph.
func available_choice_ids() -> Array[String]:
	if route == null:
		var empty: Array[String] = []
		return empty
	return route.available_choice_ids()


func to_dictionary() -> Dictionary:
	# root_seed is a full int64. JSON numbers are IEEE-754 doubles (52-bit mantissa), so it MUST be
	# decimal-string encoded or JSON.stringify/parse_string silently truncates beyond 2^53 (epic-3
	# retro Action Item #5). Read it back tolerantly (int / integral-float / decimal-string).
	return {
		"phase": String(phase),
		"root_seed": str(root_seed),
		"is_manual_seed": is_manual_seed,
		"meta_progression_eligible": meta_progression_eligible,
		"route": _route_or_new().to_dictionary(),
		# Story 5.2: the selected class id rides the FULL run dict (NOT the 23-key RunSnapshot). It is a small
		# lower_snake StringName, serialized as a plain String. try_from_dictionary reads it back leniently
		# (defaults &"" when absent) so every pre-5.2 run dict still parses.
		"selected_class_id": String(selected_class_id),
		# Story 5.3: the applied kit rides the FULL run dict too (NOT the 23-key RunSnapshot). null (a legacy/
		# empty-class run) serializes as a JSON null; a recorded kit serializes via its exact-key to_dictionary().
		# try_from_dictionary reads it back leniently (null/absent -> null) so every pre-5.3 run dict still parses.
		"starting_kit": null if starting_kit == null else starting_kit.to_dictionary(),
		# Story 6.2: the inventory/equipment model rides the FULL run dict (NOT the 23-key RunSnapshot — the
		# RunSnapshot.inventory/equipment placeholders stay empty this story). It is never null (a default-empty
		# InventoryState), so it always serializes via its exact-key to_dictionary(). try_from_dictionary reads it
		# back leniently (absent -> a fresh empty model) so every pre-6.2 run dict still parses.
		"inventory": _inventory_or_new().to_dictionary(),
		# Story 6.3: the pending reward offer rides the FULL run dict (NOT the 23-key RunSnapshot). null (no pending
		# offer) serializes as a JSON null; a pending offer serializes via its exact-key to_dictionary().
		# try_from_dictionary reads it back leniently (null/absent -> null) so every pre-6.3 run dict still parses.
		"pending_reward_offer": null if pending_reward_offer == null else pending_reward_offer.to_dictionary()
	}


func copy() -> RunState:
	return load("res://scripts/run/run_state.gd").new(
		phase,
		root_seed,
		is_manual_seed,
		meta_progression_eligible,
		_route_or_new().copy(),
		selected_class_id,
		null if starting_kit == null else starting_kit.copy(),
		# Story 5.4: carry the resolver REFERENCE on a copy. The resolver is a LIVE service over IMMUTABLE
		# content (registered PassiveDefinition resources), so sharing the reference is safe — a copied run
		# resolves the SAME registered passives. It is NOT in to_dictionary(), so a copy()'s to_dictionary()
		# stays byte-identical to the source's regardless (the round-trip tests rely on this).
		rules_resolver,
		# Story 6.2: DEEP-copy the inventory (the backpack slot list must not be shared by reference, so a
		# mutation of the copy's backpack never perturbs the source — mirroring the starting_kit deep copy).
		_inventory_or_new().copy(),
		# Story 6.3: null-safe DEEP-copy the pending offer (the offered-entries list must not be shared by
		# reference, so a mutation of the copy's offer never perturbs the source — mirroring the starting_kit
		# deep copy; null stays null).
		null if pending_reward_offer == null else pending_reward_offer.copy()
	)


# Bridge into the EXISTING RunSnapshot fields (Task 4.2). Populates the already-existing run/route
# snapshot fields rather than forking a parallel run-save format. The run phase is NESTED inside the
# route_state payload (RUN_PHASE_KEY) so the pinned 23-key RunSnapshot top-level gate stays green
# (Task 4.3). This is a pure read: it draws no RNG and mutates nothing.
#
# Returns a Dictionary keyed by RunSnapshot field names: root_seed (int), is_manual_seed (bool),
# meta_progression_eligible (bool), route_state (Dictionary), current_route_node_id (String),
# revealed_route_node_ids (Array[String]).
func to_run_snapshot_fields() -> Dictionary:
	var current_route: RouteState = _route_or_new()
	var route_payload: Dictionary = current_route.to_dictionary()
	# Nest the phase inside the route payload (no new top-level RunSnapshot key).
	route_payload[String(RUN_PHASE_KEY)] = String(phase)
	# Story 5.3: NEST the selected class id inside the route payload too (the SAME mechanism as run_phase), so a
	# between-node route-position save carries the class through the existing restore seam WITHOUT a new
	# top-level RunSnapshot key (the pinned 23-key gate stays green). This closes the 5.2 -> 5.3 persistence
	# defer: a run resumed from a route-position save rehydrates the SAME class (and re-derives its kit) instead
	# of &"". The kit itself is NOT nested — it is re-derived from this id on restore. An empty class id nests
	# "" (a legacy run carries no class, restores to &"").
	route_payload[String(SELECTED_CLASS_ID_KEY)] = String(selected_class_id)

	# Derive the revealed-node id list from the route nodes (reveal_state revealed OR cleared).
	# Cleared nodes were necessarily revealed; both surface in revealed_route_node_ids for the
	# existing RunSnapshot field. Order follows the stable node order.
	var revealed_ids: Array[String] = []
	for route_node: RouteNode in current_route.nodes():
		if route_node.reveal_state == RouteNode.REVEAL_REVEALED \
				or route_node.reveal_state == RouteNode.REVEAL_CLEARED:
			revealed_ids.append(route_node.id)

	return {
		"root_seed": root_seed,
		"is_manual_seed": is_manual_seed,
		"meta_progression_eligible": meta_progression_eligible,
		"route_state": route_payload,
		"current_route_node_id": current_route.current_node_id,
		"revealed_route_node_ids": revealed_ids
	}


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not _has_string_like_field(data, &"phase"):
		return ActionResult.error(&"invalid_run_phase", {"field": "phase"})
	if not _has_bool_field(data, &"is_manual_seed"):
		return ActionResult.error(&"invalid_run_state", {"field": "is_manual_seed"})
	if not _has_bool_field(data, &"meta_progression_eligible"):
		return ActionResult.error(&"invalid_run_state", {"field": "meta_progression_eligible"})

	var route_result: ActionResult = RouteState.try_from_dictionary(_route_dictionary(data))
	if route_result.is_error():
		return route_result
	var parsed_route: RouteState = route_result.metadata.get("route") as RouteState

	var run_state: RunState = load("res://scripts/run/run_state.gd").new(
		StringName(String(_field(data, &"phase"))),
		_int64_or_zero(_field(data, &"root_seed")),
		bool(_field(data, &"is_manual_seed")),
		bool(_field(data, &"meta_progression_eligible")),
		parsed_route,
		# Lenient: a pre-5.2 run dict has no selected_class_id key -> default &"" (legacy no-class run).
		_string_name_or_empty(_field(data, &"selected_class_id") if _has_field(data, &"selected_class_id") else &""),
		# Lenient: a pre-5.3 run dict has no starting_kit key (or null) -> default null (legacy no-kit run); a
		# present kit dict is reconstructed leniently via StartingKit.try_from_dictionary.
		_starting_kit_or_null(_field(data, &"starting_kit") if _has_field(data, &"starting_kit") else null),
		# Story 5.4: the rules resolver is a LIVE re-derivable service, NOT serialized -> not read back here
		# (the _init default null is correct; a restored run re-derives it from selected_class_id).
		null,
		# Story 6.2: lenient inventory decode. A pre-6.2 run dict has no inventory key -> _init defaults a fresh
		# empty InventoryState (never null). A present inventory dict is reconstructed leniently via
		# InventoryState.try_from_dictionary so a partial/legacy inventory dict still parses.
		_inventory_or_new_from(_field(data, &"inventory") if _has_field(data, &"inventory") else null),
		# Story 6.3: lenient reward-offer decode. A pre-6.3 run dict has no pending_reward_offer key (or null) ->
		# default null (no pending offer). A present offer dict is reconstructed leniently via
		# RewardOffer.try_from_dictionary so a partial/legacy offer dict still parses.
		_reward_offer_or_null(_field(data, &"pending_reward_offer") if _has_field(data, &"pending_reward_offer") else null)
	)
	var validation: ActionResult = run_state.validate()
	if validation.is_error():
		return validation
	return ActionResult.ok([], {"run_state": run_state})


static func from_dictionary(data: Dictionary) -> RunState:
	var result: ActionResult = try_from_dictionary(data)
	if result.is_error():
		push_error("RunState parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("run_state") as RunState


# Reconstruct a RunState from the EXISTING RunSnapshot fields produced by to_run_snapshot_fields().
# Reads the phase from the nested RUN_PHASE_KEY inside route_state. Mirrors the lenient-read /
# strict-validate split: the route payload is strictly validated via RouteState.try_from_dictionary.
static func try_from_run_snapshot_fields(fields: Dictionary) -> ActionResult:
	var route_payload: Dictionary = _dictionary_or_empty(fields.get("route_state", {}))
	var phase_value: Variant = route_payload.get(String(RUN_PHASE_KEY), PHASE_NEW_RUN)
	if not (phase_value is String or phase_value is StringName):
		return ActionResult.error(&"invalid_run_phase", {"field": String(RUN_PHASE_KEY)})

	var route_result: ActionResult = RouteState.try_from_dictionary(route_payload)
	if route_result.is_error():
		return route_result
	var parsed_route: RouteState = route_result.metadata.get("route") as RouteState

	# The current-node pointer is written in TWO places by to_run_snapshot_fields(): the canonical
	# top-level RunSnapshot.current_route_node_id field AND (mirrored) inside the route_state payload.
	# RouteState.try_from_dictionary read it from the nested payload only. Cross-check the canonical
	# top-level field so it cannot be silently ignored: if it is present and non-empty, it is the
	# source of truth (a future writer / save migration may set ONLY the top-level field), so prefer
	# it over the nested value. A disagreement with a non-empty nested pointer is a corrupt save and
	# is rejected fail-loud rather than silently resolved. The resulting pointer is still subject to
	# the structural known-node check below via validate() (delegates to RouteState.validate()).
	var top_level_node_id: Variant = fields.get("current_route_node_id", "")
	if top_level_node_id is String or top_level_node_id is StringName:
		var top_level_current: String = String(top_level_node_id)
		if not top_level_current.is_empty():
			if not parsed_route.current_node_id.is_empty() \
					and parsed_route.current_node_id != top_level_current:
				return ActionResult.error(&"route_node_pointer_conflict", {
					"field": "current_route_node_id",
					"top_level": top_level_current,
					"nested": parsed_route.current_node_id
				})
			parsed_route.current_node_id = top_level_current
	elif top_level_node_id != null:
		return ActionResult.error(&"invalid_run_state", {"field": "current_route_node_id"})

	# Story 5.3: read the selected class id back from the nested route_state key (lenient: a pre-5.3 route-position
	# payload has no SELECTED_CLASS_ID_KEY -> default &"", the legacy no-class run, which still validates). The
	# kit is NOT in the save — a caller that needs the applied kit RE-DERIVES it from this restored class id
	# through the content repositories (a deterministic pure function of the class + the baseline repos).
	var restored_class_id: StringName = _string_name_or_empty(route_payload.get(String(SELECTED_CLASS_ID_KEY), &""))

	var run_state: RunState = load("res://scripts/run/run_state.gd").new(
		StringName(String(phase_value)),
		_int64_or_zero(fields.get("root_seed", 0)),
		bool(fields.get("is_manual_seed", false)),
		bool(fields.get("meta_progression_eligible", true)),
		parsed_route,
		restored_class_id
	)
	var validation: ActionResult = run_state.validate()
	if validation.is_error():
		return validation
	return ActionResult.ok([], {"run_state": run_state})


func _route_or_new() -> RouteState:
	if route == null:
		route = load("res://scripts/run/route_state.gd").new()
	return route


# Story 6.2: the inventory is never null in practice (the _init default), but guard defensively against a
# direct null assignment so to_dictionary()/copy() always have a model.
func _inventory_or_new() -> InventoryState:
	if inventory == null:
		inventory = load("res://scripts/run/inventory_state.gd").new()
	return inventory


static func _legal_next_phases(from_phase: StringName) -> Array[StringName]:
	# Legal edges (story Task 3.2):
	#   NEW_RUN          -> ACTIVE_ROUTE
	#   ACTIVE_ROUTE     -> NODE_RESOLUTION, FAILED (abandon/death at a choice)
	#   NODE_RESOLUTION  -> ACTIVE_ROUTE (back to a choice after a node clears), COMPLETED, FAILED
	#   COMPLETED / FAILED -> terminal (no outgoing edges)
	match from_phase:
		PHASE_NEW_RUN:
			return [PHASE_ACTIVE_ROUTE]
		PHASE_ACTIVE_ROUTE:
			return [PHASE_NODE_RESOLUTION, PHASE_FAILED]
		PHASE_NODE_RESOLUTION:
			return [PHASE_ACTIVE_ROUTE, PHASE_COMPLETED, PHASE_FAILED]
		_:
			var none: Array[StringName] = []
			return none


static func _is_supported_phase(value: StringName) -> bool:
	return (
		value == PHASE_NEW_RUN
		or value == PHASE_ACTIVE_ROUTE
		or value == PHASE_NODE_RESOLUTION
		or value == PHASE_COMPLETED
		or value == PHASE_FAILED
	)


# Extract the embedded route dictionary from a RunState.to_dictionary() payload, tolerating a
# missing/non-dict route field by falling back to an empty (still structurally valid) route.
static func _route_dictionary(data: Dictionary) -> Dictionary:
	if not _has_field(data, &"route"):
		return {"nodes": []}
	var route_value: Variant = _field(data, &"route")
	if not route_value is Dictionary:
		return {"nodes": []}
	return route_value


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


# int64 decode tolerant of int / integral-float / decimal-string (copy of the RunSnapshot /
# RngStreamSet helper — the int64/real-JSON rule applied to the run/route snapshot).
static func _int64_or_zero(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return 0
			return int(numeric_value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if text.is_valid_int():
				return text.to_int()
			return 0
		_:
			return 0


# Lenient StringName decode for the additive selected_class_id field: accept a String/StringName, default
# &"" for anything else (a missing/absent/non-string value resolves to the legacy no-class run).
static func _string_name_or_empty(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""


# Lenient StartingKit decode for the additive starting_kit field: a Dictionary is reconstructed via
# StartingKit.try_from_dictionary; anything else (null / absent / non-dict) resolves to null (the legacy no-kit
# run). Mirrors the selected_class_id leniency so every pre-5.3 run dict still parses.
static func _starting_kit_or_null(value: Variant) -> StartingKit:
	if value is Dictionary:
		return StartingKit.try_from_dictionary(value)
	return null


# Lenient InventoryState decode for the additive inventory field: a Dictionary is reconstructed via
# InventoryState.try_from_dictionary; anything else (null / absent / non-dict) -> a fresh EMPTY InventoryState
# (never null, mirroring the _init default), so every pre-6.2 run dict still parses to a usable empty backpack.
static func _inventory_or_new_from(value: Variant) -> InventoryState:
	if value is Dictionary:
		return InventoryState.try_from_dictionary(value)
	return load("res://scripts/run/inventory_state.gd").new()


# Lenient RewardOffer decode for the additive pending_reward_offer field: a Dictionary is reconstructed via
# RewardOffer.try_from_dictionary; anything else (null / absent / non-dict) -> null (no pending offer). Mirrors
# the starting_kit leniency so every pre-6.3 run dict still parses.
static func _reward_offer_or_null(value: Variant) -> RewardOffer:
	if value is Dictionary:
		return RewardOffer.try_from_dictionary(value)
	return null


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	if not _has_field(data, field_name):
		return false
	var value: Variant = _field(data, field_name)
	return value is String or value is StringName


static func _has_bool_field(data: Dictionary, field_name: StringName) -> bool:
	if not _has_field(data, field_name):
		return false
	return typeof(_field(data, field_name)) == TYPE_BOOL
