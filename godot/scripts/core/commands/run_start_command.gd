class_name RunStartCommand
extends "res://scripts/core/commands/game_command.gd"

# The run-START command (Story 4.6) — the FIRST run_started emitter. It is the ONE genuinely-new command
# in 4.6: where the 4.3/4.4/4.5 run commands take an EXISTING RunState (in ACTIVE_ROUTE / NODE_RESOLUTION),
# this command CREATES the run. From (root_seed, is_manual_seed) it:
#   (1) generates the deterministic 8-12-non-boss-node route via RouteGenerator.generate(root_seed) (the ONE
#       place a run-affecting draw happens — the `map` stream, owned by RouteGenerator, not re-implemented),
#   (2) rehydrates the live RouteState via RouteGenerator.route_from_result(...),
#   (3) builds a fresh RunState (RunState.new_run(...)) and parks current_node_id on the depth-0 start node
#       (always combat — Story 4.2, so AC1's "enter at least one combat level" holds),
#   (4) transitions NEW_RUN -> ACTIVE_ROUTE (a legal edge), and
#   (5) emits ONE run_started DomainEvent carrying the decimal-string root_seed, is_manual_seed, and the
#       bounded [8, 12] non-boss node_count,
# returning the live RunState + the non-boss count in the result metadata. On any rejection it returns a
# structured ActionResult.error with ZERO events and builds NO run (byte-identical no-mutation contract).
#
# CONTEXT SHAPE — Option A ([Decision], per the story AC-interpretation notes): the run does not exist yet,
# so the "take a RunState directly" idiom (4.3/4.4/4.5) does not fit. This command takes the seed + flags in
# its CONSTRUCTOR and execute(_state) BUILDS and returns the new RunState in metadata; the `state` arg is
# UNUSED (accepts null). This keeps the run-start a self-contained "start a run" factory whose output is the
# live run — the cleanest fit for an orchestrator that has no run yet. Option B (a non-command service) was
# REJECTED for the event-emitting path: an emitting action must be a GameCommand returning ActionResult so
# run_started rides the same validate/execute/no-mutation/result contract as every other event.
#
# STORY 5.2 EXTENSION — start a run WITH a selected hero class: the constructor gained an OPTIONAL trailing
# class_id (default &"" = the legacy "no class chosen" back-compat run) + an injected ClassRepository (default
# baseline). When class_id is non-empty, validate() resolves it through the repository and REJECTS fail-closed
# on an unknown id (unknown_class) or a locked/non-selectable class (class_not_selectable) BEFORE building any
# RunState (AC2). On success execute() RECORDS run.selected_class_id (AC3 — the class arrives at
# NEW_RUN -> ACTIVE_ROUTE as DOMAIN state) and surfaces the id via result.metadata; the run_started event
# payload is UNCHANGED. An empty-class start stays byte-identical to today's start.
#
# STORY 5.3 EXTENSION — RESOLVE + RECORD the selected class's STARTING KIT: the constructor gained two more
# OPTIONAL trailing repos (WeaponRepository + SupportRepository, baseline defaults). For a CONFIRMED-SELECTABLE
# class (the 5.2 gate already rejected unknown/locked before this), validate() now ALSO resolves the class's
# starting_weapon_id through WeaponRepository.get_weapon(...) and starting_support_id through
# SupportRepository.get_support(...), REJECTING fail-closed on a missing item (unknown_starting_weapon /
# unknown_starting_support, the offending id in metadata) BEFORE building any RunState (AC2 — "no partial run
# state becomes active"). &"none" is a REAL baseline support (SUPPORT_NONE) and RESOLVES — Ranger's kit is
# VALID (do NOT special-case none as missing). On success execute() RECORDS the resolved StartingKit on the run
# (run.starting_kit — the resolved weapon/support ids + baseline_hp + the two class/equipment-synergy passive-id
# references) AFTER recording selected_class_id, and surfaces the kit via result.metadata. The passive ids are
# RECORDED VERBATIM as string-shape references — they are resolved against NOTHING (no passive system exists;
# Story 5.4 wires class passives into the rules kernel, Epic 6 authors the passive pool). The kit does NOT
# instantiate a tactical BoardState player (Story 5.5's smoke slice), does NOT draw RNG, and does NOT alter
# route generation, the event schema, or determinism — an empty-class start records NO kit and stays
# byte-identical to today's start.
#
# WHAT THIS IS NOT (scope boundaries):
#   - It does NOT change RouteGenerator / the `map` stream / the route fingerprints (it CONSUMES generation).
#   - It does NOT run LevelGenerator (that is the orchestrator's combat-node concern, Story 4.6 Task 3).
#   - It does NOT re-create / rename / duplicate run_completed (Story 4.5 OWNS it; 4.6 CONSUMES it).
#   - It adds NO new DomainEvent: run_started is the existing 4.1-wired event, emitted here for the first time.
#
# DETERMINISM: a started run is a pure function of (root_seed, is_manual_seed). Same inputs -> byte-identical
# run.to_dictionary() + the same run_started event. The command draws RNG ONLY via the delegated
# RouteGenerator.generate (the `map` stream); it touches no other stream directly.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

var root_seed: int = 0
var is_manual_seed: bool = false
var sequence_id: int = 1
# Story 5.2: the chosen hero class id (the hero-select confirm path supplies it). OPTIONAL, defaulting to
# &"" — an EMPTY class id is the BACK-COMPAT "no class chosen" run (the Story-4.6 seed-only start path + all
# 4.6 tests rely on this; an empty class is NOT a validation failure). It is the LAST positional constructor
# arg so every existing .new(seed) / .new(seed, is_manual) / .new(seed, is_manual, sequence_id) call is
# untouched. When NON-empty it is resolved through _class_repository in validate() and rejected fail-closed
# on unknown/locked BEFORE any RunState is built (AC2 — "no run can start with the locked class").
var class_id: StringName = &""
# Story 5.2: the class content repository, INJECTED (mirroring RunOrchestrator's repository injection),
# defaulting to the baseline repository. Only consulted when class_id is non-empty. Constructor-injected (not
# an autoload / global) so tests can supply a fixture repository.
var _class_repository: ClassRepository = null
# Story 5.3: the equipment content repositories, INJECTED (same posture as _class_repository), defaulting to
# their baseline repositories. Only consulted when class_id is non-empty AND selectable (to resolve the kit's
# starting weapon/support). Constructor-injected so tests can supply fixture repos with bogus kit ids.
var _weapon_repository: WeaponRepository = null
var _support_repository: SupportRepository = null
# Story 5.4: the passive content repository, INJECTED (same posture as the other repos), defaulting to the
# baseline repository. Only consulted when class_id is non-empty AND selectable (to resolve the class's two
# starting passive ids -> typed PassiveDefinitions). It is the LAST positional constructor arg (AFTER the 5.3
# weapon/support repos) so every existing .new(...) call still compiles unchanged. Constructor-injected so
# tests can supply a fixture passive repository (e.g. one missing a class's passive id, to prove fail-closed).
var _passive_repository: PassiveRepository = null

func _init(
	new_root_seed: int = 0,
	new_is_manual_seed: bool = false,
	new_sequence_id: int = 1,
	new_class_id: StringName = &"",
	new_class_repository: ClassRepository = null,
	new_weapon_repository: WeaponRepository = null,
	new_support_repository: SupportRepository = null,
	new_passive_repository: PassiveRepository = null
) -> void:
	command_id = &"run_start"
	root_seed = new_root_seed
	is_manual_seed = new_is_manual_seed
	sequence_id = new_sequence_id
	class_id = new_class_id
	_class_repository = new_class_repository if new_class_repository != null else ClassRepository.create_baseline_repository()
	_weapon_repository = new_weapon_repository if new_weapon_repository != null else WeaponRepository.create_baseline_repository()
	_support_repository = new_support_repository if new_support_repository != null else SupportRepository.create_baseline_repository()
	_passive_repository = new_passive_repository if new_passive_repository != null else PassiveRepository.create_baseline_repository()


# Pure read: validate the sequence id and the seed. No mutation, no event, no RNG. Option-A context: the
# `state` arg is unused (there is no run to pass in); it accepts null.
func validate(_state: Variant) -> ActionResult:
	# Self-consistency gate (mirror the 4.3/4.4/4.5 commands): execute() builds a run_started event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would
	# make the success path emit a non-round-trippable event. Reject it BEFORE anything else so a command's
	# success path can never emit an event its own validator rejects.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	# Reject a negative root_seed with a stable code BEFORE generating (mirror RouteGenerator.generate's
	# root_seed < 0 guard; the run domain elsewhere assumes a non-negative seed — RngStreamSet derives streams
	# from it, RunState/RunSnapshot string-encode it on the int64 rule).
	if root_seed < 0:
		return ActionResult.error(&"invalid_run_seed", {
			"command": String(command_id),
			"root_seed": root_seed
		})
	# Story 5.2 class gate (AC2): resolve a NON-empty class id through the injected ClassRepository and fail
	# CLOSED before building any RunState. An EMPTY class id SKIPS the gate (the back-compat "no class chosen"
	# run — the orchestrator's seed-only start + every 4.6 test rely on this; an empty class is NOT a failure).
	# This is a PURE read (no mutation, no event, no RNG) so execute() short-circuits on it, mirroring the
	# sequence_id / root_seed gates above. The error code stays lower_snake; the offending class id rides
	# metadata (a class id is already lower_snake, but never embed it in the code).
	if not class_id.is_empty():
		var def: ClassDefinition = _class_repository.get_class_definition(class_id)
		if def == null:
			# Unknown id (not registered in the repository) — fail closed.
			return ActionResult.error(&"unknown_class", {
				"command": String(command_id),
				"class_id": String(class_id)
			})
		if not def.is_selectable():
			# Resolves but is a LOCKED/non-selectable future class — fail closed ("no run can start with the
			# locked class").
			return ActionResult.error(&"class_not_selectable", {
				"command": String(command_id),
				"class_id": String(class_id),
				"lock_state": String(def.lock_state)
			})
		# Story 5.3 kit-resolution gate (AC2): resolve the SELECTABLE class's starting weapon + support against
		# the injected equipment repositories and fail CLOSED on a missing item BEFORE building any RunState
		# ("no partial run state becomes active"). This runs ONLY for a confirmed-selectable class (the unknown/
		# locked rejects above already short-circuited). It is a PURE read (no mutation, no event, no RNG), so
		# execute() short-circuits on it exactly like the class/sequence/seed gates. &"none" RESOLVES (it is the
		# real baseline SUPPORT_NONE) — Ranger's kit is VALID; do NOT special-case none as missing. Passive ids
		# are NOT resolved here (no passive system exists — Story 5.4/Epic 6 own that).
		var kit_check: ActionResult = _validate_kit_resolves(def)
		if kit_check.is_error():
			return kit_check
		# Story 5.4 passive-resolution gate (AC1): resolve the SELECTABLE class's two starting passive ids
		# (class_passive_id + equipment_synergy_passive_id) against the injected PassiveRepository and fail
		# CLOSED on a miss BEFORE building any RunState ("do not bypass command/result/event flow"; the same
		# fail-closed content discipline as the 5.3 kit gate). This runs ONLY for a confirmed-selectable class
		# (the unknown/locked + missing-weapon/support rejects above already short-circuited), so passive
		# resolution never runs for a locked/unknown/kit-invalid class. It is a PURE read (no mutation, no event,
		# no RNG), so execute() short-circuits on it exactly like the class/kit/sequence/seed gates. The empty/
		# legacy run skips the whole block (no passives).
		var passive_check: ActionResult = _validate_passives_resolve(def)
		if passive_check.is_error():
			return passive_check
	return ActionResult.ok()


# Pure read: resolve the SELECTABLE class def's starting weapon + support ids against the injected equipment
# repositories. Returns ok() when both resolve (incl. &"none" via SUPPORT_NONE), or a fail-closed structured
# error (unknown_starting_weapon / unknown_starting_support) carrying the offending id in metadata. Mirrors the
# 5.2 class-gate metadata pattern (stable lower_snake code; the id rides metadata, never the code). The caller
# guarantees def != null and def.is_selectable().
func _validate_kit_resolves(def: ClassDefinition) -> ActionResult:
	if _weapon_repository.get_weapon(def.starting_weapon_id) == null:
		return ActionResult.error(&"unknown_starting_weapon", {
			"command": String(command_id),
			"class_id": String(class_id),
			"weapon_id": String(def.starting_weapon_id)
		})
	# &"none" is the real baseline SUPPORT_NONE and resolves here — do NOT treat it as a missing support.
	if _support_repository.get_support(def.starting_support_id) == null:
		return ActionResult.error(&"unknown_starting_support", {
			"command": String(command_id),
			"class_id": String(class_id),
			"support_id": String(def.starting_support_id)
		})
	return ActionResult.ok()


# Story 5.4: pure read — resolve the SELECTABLE class def's two starting passive ids (class_passive_id +
# equipment_synergy_passive_id) against the injected PassiveRepository. Returns ok() when BOTH resolve, or a
# fail-closed structured error (unknown_class_passive / unknown_equipment_synergy_passive) carrying the
# offending passive id in metadata. Mirrors the 5.3 kit-gate metadata pattern (one stable lower_snake code per
# failure class; the id rides metadata, never the code). The caller guarantees def != null and
# def.is_selectable(). The class passive is resolved FIRST so its code is the reported failure when both miss.
func _validate_passives_resolve(def: ClassDefinition) -> ActionResult:
	if _passive_repository.get_passive(def.class_passive_id) == null:
		return ActionResult.error(&"unknown_class_passive", {
			"command": String(command_id),
			"class_id": String(class_id),
			"passive_id": String(def.class_passive_id)
		})
	if _passive_repository.get_passive(def.equipment_synergy_passive_id) == null:
		return ActionResult.error(&"unknown_equipment_synergy_passive", {
			"command": String(command_id),
			"class_id": String(class_id),
			"passive_id": String(def.equipment_synergy_passive_id)
		})
	return ActionResult.ok()


# Validate-then-mutate. On success: generate + rehydrate the route, park the start node, transition
# NEW_RUN -> ACTIVE_ROUTE, emit ONE run_started event, and return the live RunState + the bounded non-boss
# count in metadata. Draws RNG ONLY via the delegated RouteGenerator.generate (the `map` stream); builds no
# half-run on failure.
func execute(_state: Variant) -> ActionResult:
	var validation: ActionResult = validate(_state)
	if validation.is_error():
		return validation

	# (1) Generate the route (the ONE place a run-affecting draw happens — the `map` stream, owned by
	# RouteGenerator). On a structured generation failure, surface route_generation_failed carrying the inner
	# phase/code in metadata, emit ZERO events, and build NO half-run.
	var generation = RouteGenerator.generate(root_seed)
	if generation.is_error():
		return ActionResult.error(&"route_generation_failed", {
			"command": String(command_id),
			"root_seed": root_seed,
			"inner_failed_phase": String(generation.failed_phase),
			"inner_error_code": String(generation.error_code),
			"inner_reason": String(generation.reason)
		})

	# (2) Rehydrate the live RouteState from the successful generation result.
	var route: RouteState = RouteGenerator.route_from_result(generation)
	if route == null or route.nodes().is_empty():
		# Defensive: a successful generation result whose route cannot rehydrate (or is empty) is a generator
		# contract break, not a routine reject — surface it structurally rather than crashing on nodes()[0].
		return ActionResult.error(&"route_rehydration_failed", {
			"command": String(command_id),
			"root_seed": root_seed
		})

	# (3) Build a fresh RunState and park the start pointer on the depth-0 start node. RunState.new_run(...)
	# RESETS current_node_id + cleared_node_ids to fresh-run state (the 4.3 fixture trap), which is exactly
	# right here — the start IS a fresh run — so set the start pointer AFTER new_run().
	var run: RunState = RunState.new_run(root_seed, is_manual_seed, route)
	run.route.current_node_id = route.nodes()[0].id

	# (4) Transition NEW_RUN -> ACTIVE_ROUTE (a legal edge; transition_to validates it). Build the event ONLY
	# AFTER the transition succeeds (the 4.4/4.5 mutate-before-infallible-transition discipline). The
	# new_run() default phase is NEW_RUN, so this edge is always legal — but check defensively and surface a
	# structured error WITHOUT having emitted any event if it ever failed.
	var transition: ActionResult = run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	if transition.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_NEW_RUN),
			"inner_error_code": String(transition.error_code)
		})

	# Story 5.2 (AC3): RECORD the selected class on the started run so it is DOMAIN state (not UI-only). Set
	# AFTER new_run() + the start-pointer set + the NEW_RUN -> ACTIVE_ROUTE transition (the "set after new_run,
	# build event after transition" ordering). validate() already rejected an unknown/locked class, so by here
	# class_id is empty (legacy run) or a confirmed-selectable id. An empty class id records &"" (legacy no-class
	# run).
	run.selected_class_id = class_id

	# Story 5.3 (AC1): RECORD the resolved STARTING KIT on the started run so it is DOMAIN state. ONLY for a
	# non-empty + selectable class (the empty/legacy run records NO kit — back-compat). validate() already proved
	# the class resolves + is selectable AND its weapon/support resolve (the kit gate), so the resolution here
	# cannot miss — but build it through the same accessors so the recorded kit IS the resolved content. Records
	# the resolved weapon/support ids + baseline_hp + the two passive-id references VERBATIM (the passives are
	# string-shape refs resolved against NOTHING — Story 5.4/Epic 6). This applies the kit into the EXISTING
	# RunState (no parallel run format, no tactical board player — Story 5.5). Draws NO RNG.
	var applied_kit: StartingKit = null
	# Story 5.4 (AC1): build a RulesResolver, REGISTER the two resolved starting passives into it (each keyed
	# by its declared trigger window(s)), and SEAT it on the run as run domain state — AFTER recording the kit
	# (the "record after kit" ordering, mirroring "set selected_class_id after new_run, record kit after that").
	# ONLY for a non-empty + selectable class (the empty/legacy run seats NO resolver — back-compat). validate()
	# already proved both passive ids resolve (the passive gate), so the resolution here cannot miss — but build
	# it through the same accessor so the registered passives ARE the resolved content. Draws NO RNG (a content
	# lookup + a stable-order registration + a field set); applies NO combat mutation.
	var resolver: RulesResolver = null
	var class_passive_def: PassiveDefinition = null
	var equip_passive_def: PassiveDefinition = null
	if not class_id.is_empty():
		applied_kit = _resolve_starting_kit()
		run.starting_kit = applied_kit
		class_passive_def = _passive_repository.get_passive(applied_kit.class_passive_id)
		equip_passive_def = _passive_repository.get_passive(applied_kit.equipment_synergy_passive_id)
		resolver = RulesResolver.new()
		# Registration order = stable resolution order. Register the class passive first, then the
		# equipment-synergy passive (a deterministic, documented order).
		resolver.register_passive(class_passive_def)
		resolver.register_passive(equip_passive_def)
		run.rules_resolver = resolver

	# (5) Build the single run_started event AFTER the transition. node_count is the route's NON-BOSS count
	# (bounded [8, 12], RouteGenerator.PAYLOAD_NODE_COUNT_KEY / metadata.node_count) — a small bounded count,
	# carried as a raw integer (NOT decimal-string encoded; it is a count, not a seed). root_seed is decimal-
	# string encoded by the run_started factory (int64-safe).
	var non_boss_count: int = int(generation.payload.get(RouteGenerator.PAYLOAD_NODE_COUNT_KEY, 0))
	var event: DomainEvent = DomainEvent.run_started(sequence_id, {
		"root_seed": root_seed,
		"is_manual_seed": is_manual_seed,
		"node_count": non_boss_count
	})

	var result_metadata: Dictionary = {
		"run": run,
		"node_count": non_boss_count,
		"root_seed": root_seed,
		"is_manual_seed": is_manual_seed,
		# Story 5.2: surface the chosen class id to the caller via metadata ONLY (the run_started event PAYLOAD
		# stays unchanged — root_seed/is_manual_seed/node_count — keeping the event schema stable). An empty
		# class id surfaces "" (legacy run). A downstream story that needs the class IN the event appends it
		# deliberately as a SYSTEM-event field; 5.2 does not.
		"class_id": String(class_id)
	}
	# Story 5.3: surface the applied kit to the caller via metadata ONLY (the run_started event PAYLOAD stays
	# unchanged). Surface the kit dictionary + a few flat key fields for convenience; an empty-class start
	# surfaces NO kit keys (back-compat — a seed-only start's metadata is unchanged apart from the 5.2 class_id).
	if applied_kit != null:
		result_metadata["kit"] = applied_kit.to_dictionary()
		result_metadata["weapon_id"] = String(applied_kit.weapon_id)
		result_metadata["support_id"] = String(applied_kit.support_id)
		result_metadata["baseline_hp"] = applied_kit.baseline_hp
	# Story 5.4: surface the registered starting passives to the caller via metadata ONLY (the run_started event
	# PAYLOAD stays unchanged — root_seed/is_manual_seed/node_count). Surface the two passive ids, the resolver's
	# registered-id list (stable order), and the player/debug-readable explanation lines (a deterministic
	# Array[String]) — the AC2 explanation surface. An empty-class start surfaces NO passive keys (back-compat).
	# The explanations are surfaced as plain Strings (NOT a typed Array[Dictionary], which would not survive the
	# ActionResult metadata deep-copy).
	if resolver != null:
		result_metadata["class_passive_id"] = String(applied_kit.class_passive_id)
		result_metadata["equipment_synergy_passive_id"] = String(applied_kit.equipment_synergy_passive_id)
		var registered_ids: Array[String] = []
		for registered_id: StringName in resolver.registered_passive_ids():
			registered_ids.append(String(registered_id))
		result_metadata["registered_passive_ids"] = registered_ids
		var explanations: Array[String] = []
		if class_passive_def != null:
			explanations.append(class_passive_def.explanation)
		if equip_passive_def != null:
			explanations.append(equip_passive_def.explanation)
		result_metadata["passive_explanations"] = explanations
	return ActionResult.ok([event], result_metadata)


# Story 5.3: build the applied StartingKit by RESOLVING the (already-validated selectable) class def's kit
# fields through the content repositories — the weapon/support ids are resolved (validate() proved they exist),
# baseline_hp is read, and the two passive ids are recorded VERBATIM (string-shape refs, resolved against
# NOTHING). Called ONLY for a non-empty + selectable class_id (the caller guards on class_id.is_empty()). The
# recorded weapon_id/support_id are the class's CONFIGURED kit ids (which validate() proved resolve); the
# repositories are consulted via the kit gate, so this is a deterministic content read — no RNG, no mutation
# beyond the returned value object.
func _resolve_starting_kit() -> StartingKit:
	var def: ClassDefinition = _class_repository.get_class_definition(class_id)
	return StartingKit.new(
		class_id,
		def.starting_weapon_id,
		def.starting_support_id,
		def.baseline_hp,
		def.class_passive_id,
		def.equipment_synergy_passive_id
	)
