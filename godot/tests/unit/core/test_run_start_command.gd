extends "res://tests/unit/test_case.gd"

# Story 4.6 Task 5.1 — RunStartCommand (the FIRST run_started emitter) AC1 behavior.
#
# RunStartCommand is the ONE genuinely-new command in 4.6: it BUILDS a fresh RunState from a root seed,
# generates + rehydrates the 4.2 route, parks the run on the depth-0 start node (always combat — 4.2),
# transitions NEW_RUN -> ACTIVE_ROUTE, and emits the EXISTING-but-until-now-unemitted run_started event
# (decimal-string root_seed, is_manual_seed, the bounded [8, 12] non-boss node_count). Option-A context
# shape: the command takes the seed in its constructor and execute(_state) RETURNS the live RunState in
# metadata (the `state` arg is unused — there is no run to pass in yet).
#
# This test pins: started run is in ACTIVE_ROUTE on the start node, run.validate() green, exactly one
# run_started event with a bounded node_count + decimal-string root_seed + correct is_manual_seed; manual-
# seed start sets meta_progression_eligible == false; negative seed rejects (invalid_run_seed); bad sequence
# id rejects (invalid_event_sequence_id); no-mutation-on-reject (no run built, zero events); determinism
# (same inputs -> byte-identical run.to_dictionary() + same run_started payload). It also pins the
# node_count [8, 12] bound across a seed sample (closing the 4.1 node_count defer as permanently benign).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunStartCommand = preload("res://scripts/core/commands/run_start_command.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const SAMPLE_SEEDS: Array[int] = [0, 1, 7, 42, 2026, 13, 99, 314, 777]
const PLAYABLE_CLASS_IDS: Array[StringName] = [&"warrior", &"pyromancer", &"ranger"]

func run() -> Dictionary:
	_start_produces_active_run_on_combat_start_node()
	_start_emits_exactly_one_run_started_with_bounded_node_count()
	_manual_seed_start_is_not_meta_eligible()
	_negative_seed_rejects_with_no_mutation()
	_bad_sequence_id_rejects_with_no_mutation()
	_start_is_deterministic_for_same_inputs()
	_node_count_stays_bounded_across_seed_sample()
	# Story 5.2 — the class-into-run-start seam (AC2/AC3).
	_start_with_selectable_class_records_it_and_leaves_route_unchanged()
	_start_with_empty_class_is_back_compatible_and_records_empty()
	_start_with_locked_class_rejects_fail_closed()
	_start_with_unknown_class_rejects_fail_closed()
	_start_with_class_is_deterministic_for_same_inputs()
	# Story 5.3 — kit resolution + applied-kit recording (AC1/AC2/AC3).
	_start_with_each_playable_class_records_the_resolved_kit()
	_start_with_ranger_resolves_none_support_not_a_failure()
	_start_with_bogus_starting_weapon_rejects_fail_closed()
	_start_with_bogus_starting_support_rejects_fail_closed()
	_empty_class_start_records_no_kit_and_stays_byte_identical()
	_locked_and_unknown_class_reject_before_kit_resolution()
	_start_with_kit_is_deterministic_for_same_inputs()
	_applied_kit_survives_run_to_dictionary_round_trip()
	return result()


func _start_produces_active_run_on_combat_start_node() -> void:
	var command: RunStartCommand = RunStartCommand.new(42)
	var started: ActionResult = command.execute(null)
	assert_true(started.succeeded, "Starting a run from a valid seed should succeed: %s" % started.metadata)
	var run: RunState = started.metadata.get("run") as RunState
	assert_true(run != null, "A successful run start should return the live RunState in metadata.")
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "A started run should be in PHASE_ACTIVE_ROUTE.")
	assert_false(run.is_terminal(), "A freshly started run should not be terminal.")
	assert_true(run.validate().succeeded, "A started run should validate: %s" % run.validate().metadata)

	# Parked on the depth-0 start node, which is ALWAYS a combat node (Story 4.2 — the start draws no type
	# selector and is always combat).
	var start_node: RouteNode = run.route.node_by_id(run.route.current_node_id)
	assert_true(start_node != null, "The started run should be parked on a known start node.")
	assert_equal(start_node.depth, 0, "The start node should be the depth-0 node.")
	assert_equal(start_node.type, RouteNode.TYPE_COMBAT, "The depth-0 start node is always combat (AC1 — at least one combat level is enterable).")
	assert_equal(run.route.current_node_id, run.route.nodes()[0].id, "The start pointer should be the first (depth-0) node in the route order.")
	# A fresh run has cleared nothing.
	assert_true(run.route.cleared_node_ids.is_empty(), "A freshly started run should have cleared no nodes.")


func _start_emits_exactly_one_run_started_with_bounded_node_count() -> void:
	var command: RunStartCommand = RunStartCommand.new(2026)
	var started: ActionResult = command.execute(null)
	assert_true(started.succeeded, "Run start should succeed for seed 2026: %s" % started.metadata)

	# Exactly one run_started event.
	assert_equal(started.events.size(), 1, "Run start should emit exactly one event.")
	var event: DomainEvent = started.events[0]
	assert_equal(event.event_type, DomainEvent.Type.RUN_STARTED, "The emitted event should be run_started.")
	assert_equal(event.actor_id, &"", "run_started is a system event with an empty actor id.")
	# root_seed is decimal-string encoded (int64-safe).
	assert_equal(String(event.payload.get("root_seed")), "2026", "run_started should carry the decimal-string root_seed.")
	assert_equal(event.payload.get("is_manual_seed"), false, "run_started should carry the is_manual_seed flag (false here).")
	# node_count is the route's non-boss count, bounded [8, 12].
	var node_count: int = int(event.payload.get("node_count"))
	assert_true(node_count >= 8 and node_count <= 12, "run_started node_count must be the bounded non-boss count [8, 12], got %d." % node_count)
	assert_equal(int(started.metadata.get("node_count")), node_count, "The metadata node_count should match the event node_count.")

	# The event round-trips through real JSON (the int64-string root_seed survives stringify/parse).
	var round_trip: Variant = JSON.parse_string(JSON.stringify(event.to_dictionary()))
	assert_true(round_trip is Dictionary, "run_started should survive a JSON round-trip.")
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(round_trip)
	assert_true(parse_result.succeeded, "The emitted run_started event must be a valid round-trippable event: %s" % parse_result.metadata)


func _manual_seed_start_is_not_meta_eligible() -> void:
	var command: RunStartCommand = RunStartCommand.new(42, true)
	var started: ActionResult = command.execute(null)
	assert_true(started.succeeded, "A manual-seed run start should succeed: %s" % started.metadata)
	var run: RunState = started.metadata.get("run") as RunState
	assert_true(run.is_manual_seed, "A manual-seed run should set is_manual_seed.")
	assert_false(run.meta_progression_eligible, "A manual-seed run must NOT be meta-progression eligible (invariant: eligible == not manual).")
	assert_true(run.validate().succeeded, "A manual-seed run should still validate.")
	assert_equal(started.events[0].payload.get("is_manual_seed"), true, "run_started should carry is_manual_seed == true for a manual-seed run.")


func _negative_seed_rejects_with_no_mutation() -> void:
	var command: RunStartCommand = RunStartCommand.new(-1)
	# validate() first.
	var validation: ActionResult = command.validate(null)
	assert_true(validation.is_error(), "A negative seed should be rejected by validate().")
	assert_equal(validation.error_code, &"invalid_run_seed", "A negative seed should use the stable invalid_run_seed code.")
	# execute() likewise rejects, emits zero events, builds no run.
	var started: ActionResult = command.execute(null)
	assert_true(started.is_error(), "A negative seed should be rejected by execute().")
	assert_equal(started.error_code, &"invalid_run_seed", "execute() should reject a negative seed with invalid_run_seed.")
	assert_true(started.events.is_empty(), "A rejected run start must emit zero events.")
	assert_false(started.metadata.has("run"), "A rejected run start must build no run.")


func _bad_sequence_id_rejects_with_no_mutation() -> void:
	for bad_id: int in [0, -1]:
		var command: RunStartCommand = RunStartCommand.new(42, false, bad_id)
		var validation: ActionResult = command.validate(null)
		assert_true(validation.is_error(), "A non-positive sequence id (%d) should be rejected by validate()." % bad_id)
		assert_equal(validation.error_code, &"invalid_event_sequence_id", "A bad sequence id (%d) should use the stable invalid_event_sequence_id code." % bad_id)
		var started: ActionResult = command.execute(null)
		assert_true(started.is_error(), "A bad sequence id (%d) should be rejected by execute()." % bad_id)
		assert_equal(started.error_code, &"invalid_event_sequence_id", "execute() should reject a bad sequence id (%d)." % bad_id)
		assert_true(started.events.is_empty(), "A rejected run start (bad sequence id %d) must emit zero events." % bad_id)
		assert_false(started.metadata.has("run"), "A rejected run start (bad sequence id %d) must build no run." % bad_id)


func _start_is_deterministic_for_same_inputs() -> void:
	# Same (root_seed, is_manual_seed, sequence_id) -> byte-identical resulting run.to_dictionary() + the
	# same run_started payload (route generation is a pure function of the seed; the command draws RNG only
	# via the delegated RouteGenerator.generate).
	var first: ActionResult = RunStartCommand.new(777).execute(null)
	var second: ActionResult = RunStartCommand.new(777).execute(null)
	assert_true(first.succeeded and second.succeeded, "Both deterministic starts should succeed.")
	var first_run: RunState = first.metadata.get("run") as RunState
	var second_run: RunState = second.metadata.get("run") as RunState
	assert_equal(JSON.stringify(first_run.to_dictionary()), JSON.stringify(second_run.to_dictionary()), "Same inputs must produce a byte-identical run.to_dictionary().")
	assert_equal(JSON.stringify(first.events[0].to_dictionary()), JSON.stringify(second.events[0].to_dictionary()), "Same inputs must produce a byte-identical run_started event.")


func _node_count_stays_bounded_across_seed_sample() -> void:
	# Closes the 4.1 node_count raw-JSON-number defer as PERMANENTLY BENIGN: across a seed sample the
	# run_started node_count is always the bounded non-boss count in [8, 12] (RouteGenerator MIN/MAX), so it
	# can never approach 2^53 and correctly stays a raw JSON integer (no decimal-string encoding needed).
	for seed_value: int in SAMPLE_SEEDS:
		var started: ActionResult = RunStartCommand.new(seed_value).execute(null)
		assert_true(started.succeeded, "Run start should succeed for seed %d: %s" % [seed_value, started.metadata])
		var node_count: int = int(started.events[0].payload.get("node_count"))
		assert_true(node_count >= 8 and node_count <= 12, "Seed %d: run_started node_count must stay bounded [8, 12], got %d." % [seed_value, node_count])


# Story 5.2 AC3: starting a run WITH a selectable class id records selected_class_id on the started RunState
# (domain state, not UI-only), keeps the run in ACTIVE_ROUTE + validate() green, and leaves the route + the
# run_started event byte-identical to a seed-only start of the same seed (the class adds ONLY the recorded
# field + optional metadata; it does NOT alter route generation or the event payload).
func _start_with_selectable_class_records_it_and_leaves_route_unchanged() -> void:
	var with_class: ActionResult = RunStartCommand.new(42, false, 1, &"warrior").execute(null)
	assert_true(with_class.succeeded, "Starting a run with a selectable class should succeed: %s" % with_class.metadata)
	var run: RunState = with_class.metadata.get("run") as RunState
	assert_true(run != null, "A successful class run start should return the live RunState.")
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "A class run start should be in ACTIVE_ROUTE.")
	assert_equal(run.selected_class_id, &"warrior", "AC3: the started run must RECORD the selected class id (domain state).")
	assert_true(run.validate().succeeded, "A class run start should validate: %s" % run.validate().metadata)
	# The class is surfaced via result metadata for the caller (the run_started payload stays unchanged).
	assert_equal(String(with_class.metadata.get("class_id", "")), "warrior", "The success metadata should surface the chosen class id.")

	# Route + run_started event are IDENTICAL to a seed-only start of the same seed (the class records only
	# the field; it does not perturb the deterministic route or the event schema).
	var seed_only: ActionResult = RunStartCommand.new(42).execute(null)
	var seed_only_run: RunState = seed_only.metadata.get("run") as RunState
	assert_equal(run.route.nodes().size(), seed_only_run.route.nodes().size(), "A class start must produce the same-size route as a seed-only start.")
	assert_equal(run.route.current_node_id, seed_only_run.route.current_node_id, "A class start must park on the same start node as a seed-only start.")
	assert_equal(JSON.stringify(with_class.events[0].to_dictionary()), JSON.stringify(seed_only.events[0].to_dictionary()), "A class start's run_started event must be byte-identical to a seed-only start (payload unchanged).")
	# The seed-only run records an empty class (back-compat); the only run.to_dictionary() difference is the
	# selected_class_id field.
	assert_equal(seed_only_run.selected_class_id, &"", "A seed-only start records an empty class id (legacy run).")


# Story 5.2 back-compat: the existing seed-only / (seed,is_manual) / (seed,is_manual,sequence_id)
# constructions still succeed and record an EMPTY class id (the legacy 'no class chosen' run). An empty class
# id is NOT a validation failure — it is the back-compat path the 4.6 orchestrator + tests rely on.
func _start_with_empty_class_is_back_compatible_and_records_empty() -> void:
	# All existing positional constructions still produce a valid run with an empty class id.
	for command: RunStartCommand in [
		RunStartCommand.new(7),
		RunStartCommand.new(7, false),
		RunStartCommand.new(7, false, 1),
		RunStartCommand.new(7, false, 1, &"")
	]:
		var started: ActionResult = command.execute(null)
		assert_true(started.succeeded, "A back-compat (empty-class) start should succeed.")
		var run: RunState = started.metadata.get("run") as RunState
		assert_equal(run.selected_class_id, &"", "A back-compat start must record an EMPTY class id (legacy run).")
		assert_true(run.validate().succeeded, "A back-compat start should validate.")
	# validate() must NOT reject an empty class id (it is the back-compat path, not a failure).
	var validation: ActionResult = RunStartCommand.new(7, false, 1, &"").validate(null)
	assert_true(validation.succeeded, "An empty class id must pass validate() (back-compat, not a failure).")


# Story 5.2 AC2: a LOCKED class id is rejected fail-closed in BOTH validate() and execute() with the stable
# class_not_selectable code, ZERO events, and NO run built (byte-identical no-mutation — 'no run can start
# with the locked class').
func _start_with_locked_class_rejects_fail_closed() -> void:
	var command: RunStartCommand = RunStartCommand.new(42, false, 1, &"necromancer")
	# validate() rejects.
	var validation: ActionResult = command.validate(null)
	assert_true(validation.is_error(), "AC2: a locked class should be rejected by validate().")
	assert_equal(validation.error_code, &"class_not_selectable", "A locked class should use the stable class_not_selectable code.")
	assert_equal(String(validation.metadata.get("class_id", "")), "necromancer", "The reject metadata should carry the offending class id.")
	# execute() likewise rejects, emits zero events, builds no run.
	var started: ActionResult = command.execute(null)
	assert_true(started.is_error(), "AC2: a locked class should be rejected by execute().")
	assert_equal(started.error_code, &"class_not_selectable", "execute() should reject a locked class with class_not_selectable.")
	assert_true(started.events.is_empty(), "A rejected locked-class start must emit zero events.")
	assert_false(started.metadata.has("run"), "AC2: a rejected locked-class start must build NO run.")


# Story 5.2 AC2: an UNKNOWN class id (not in the repository) is rejected fail-closed in BOTH validate() and
# execute() with the stable unknown_class code, ZERO events, and NO run built.
func _start_with_unknown_class_rejects_fail_closed() -> void:
	var command: RunStartCommand = RunStartCommand.new(42, false, 1, &"does_not_exist")
	var validation: ActionResult = command.validate(null)
	assert_true(validation.is_error(), "AC2: an unknown class should be rejected by validate().")
	assert_equal(validation.error_code, &"unknown_class", "An unknown class should use the stable unknown_class code.")
	assert_equal(String(validation.metadata.get("class_id", "")), "does_not_exist", "The reject metadata should carry the offending class id.")
	var started: ActionResult = command.execute(null)
	assert_true(started.is_error(), "AC2: an unknown class should be rejected by execute().")
	assert_equal(started.error_code, &"unknown_class", "execute() should reject an unknown class with unknown_class.")
	assert_true(started.events.is_empty(), "A rejected unknown-class start must emit zero events.")
	assert_false(started.metadata.has("run"), "AC2: a rejected unknown-class start must build NO run.")


# Story 5.2: a started run WITH a class is deterministic — same (seed, is_manual_seed, sequence_id, class_id)
# -> byte-identical run.to_dictionary() (incl. the recorded selected_class_id) + the same run_started event.
func _start_with_class_is_deterministic_for_same_inputs() -> void:
	var first: ActionResult = RunStartCommand.new(777, false, 1, &"pyromancer").execute(null)
	var second: ActionResult = RunStartCommand.new(777, false, 1, &"pyromancer").execute(null)
	assert_true(first.succeeded and second.succeeded, "Both deterministic class starts should succeed.")
	var first_run: RunState = first.metadata.get("run") as RunState
	var second_run: RunState = second.metadata.get("run") as RunState
	assert_equal(JSON.stringify(first_run.to_dictionary()), JSON.stringify(second_run.to_dictionary()), "Same inputs (with a class) must produce a byte-identical run.to_dictionary().")
	assert_equal(first_run.selected_class_id, &"pyromancer", "The deterministic class run records the chosen class.")
	assert_equal(JSON.stringify(first.events[0].to_dictionary()), JSON.stringify(second.events[0].to_dictionary()), "Same inputs (with a class) must produce a byte-identical run_started event.")


# ---- Story 5.3: kit resolution + applied-kit recording -------------------------------------------

# AC1/AC3: starting a run WITH each playable class RESOLVES that class's starting kit (weapon/support via the
# repositories) and RECORDS it on the started RunState (run.starting_kit) — matching the RESOLVED ClassRepository
# baseline (NOT hardcoded literals: the expected values are READ FROM the class definition). The kit is surfaced
# via result.metadata too. Asserts the recorded weapon/support/baseline_hp + the two passive-id references.
func _start_with_each_playable_class_records_the_resolved_kit() -> void:
	var class_repo: ClassRepository = ClassRepository.create_baseline_repository()
	for class_id: StringName in PLAYABLE_CLASS_IDS:
		var def: ClassDefinition = class_repo.get_class_definition(class_id)
		assert_true(def != null and def.is_selectable(), "Fixture sanity: %s should resolve as a selectable class." % class_id)

		var started: ActionResult = RunStartCommand.new(42, false, 1, class_id).execute(null)
		assert_true(started.succeeded, "Starting a run with %s should succeed: %s" % [class_id, started.metadata])
		var run: RunState = started.metadata.get("run") as RunState
		assert_true(run != null, "A %s start should return the live RunState." % class_id)
		# The applied kit is recorded on the RunState (domain state).
		var kit: StartingKit = run.starting_kit
		assert_true(kit != null, "AC1: a %s start must RECORD the applied StartingKit on the RunState." % class_id)
		# Every kit field matches the RESOLVED class definition (read the def — not a hardcoded literal).
		assert_equal(kit.class_id, class_id, "%s: the recorded kit class id must match." % class_id)
		assert_equal(kit.weapon_id, def.starting_weapon_id, "%s: the recorded weapon must match the class definition's starting_weapon_id." % class_id)
		assert_equal(kit.support_id, def.starting_support_id, "%s: the recorded support must match the class definition's starting_support_id." % class_id)
		assert_equal(kit.baseline_hp, def.baseline_hp, "%s: the recorded baseline_hp must match the class definition." % class_id)
		assert_equal(kit.class_passive_id, def.class_passive_id, "%s: the recorded class passive id must match (string-shape, verbatim)." % class_id)
		assert_equal(kit.equipment_synergy_passive_id, def.equipment_synergy_passive_id, "%s: the recorded equipment-synergy passive id must match (string-shape, verbatim)." % class_id)
		# The kit is surfaced via result metadata for the caller.
		assert_true(started.metadata.has("kit"), "%s: the success metadata should surface the applied kit." % class_id)
		assert_equal(String(started.metadata.get("weapon_id", "")), String(def.starting_weapon_id), "%s: the success metadata weapon_id should match." % class_id)
		assert_equal(int(started.metadata.get("baseline_hp", -1)), def.baseline_hp, "%s: the success metadata baseline_hp should match." % class_id)
		# Baseline-fact pin (cross-check the resolved baselines themselves, so a baseline drift is caught here).
		match class_id:
			&"warrior":
				assert_equal(kit.weapon_id, &"sword", "Warrior's resolved kit weapon should be sword.")
				assert_equal(kit.support_id, &"shield", "Warrior's resolved kit support should be shield.")
				assert_equal(kit.baseline_hp, 18, "Warrior's baseline HP should be 18.")
			&"pyromancer":
				assert_equal(kit.weapon_id, &"staff", "Pyromancer's resolved kit weapon should be staff.")
				assert_equal(kit.support_id, &"tome", "Pyromancer's resolved kit support should be tome.")
				assert_equal(kit.baseline_hp, 18, "Pyromancer's baseline HP should be 18.")
			&"ranger":
				assert_equal(kit.weapon_id, &"bow", "Ranger's resolved kit weapon should be bow.")
				assert_equal(kit.support_id, &"none", "Ranger's resolved kit support should be none (the real SUPPORT_NONE).")
				assert_equal(kit.baseline_hp, 18, "Ranger's baseline HP should be 18.")


# AC2 trap: Ranger's starting_support_id is &"none" (the real SUPPORT_NONE). It RESOLVES — the Ranger start must
# SUCCEED and record support == none, NOT fail with unknown_starting_support.
func _start_with_ranger_resolves_none_support_not_a_failure() -> void:
	var command: RunStartCommand = RunStartCommand.new(42, false, 1, &"ranger")
	# validate() must NOT reject Ranger (none resolves through SupportRepository).
	var validation: ActionResult = command.validate(null)
	assert_true(validation.succeeded, "Ranger's &\"none\" support MUST resolve — validate() must not reject it: %s" % validation.metadata)
	var started: ActionResult = command.execute(null)
	assert_true(started.succeeded, "A Ranger start must SUCCEED (none is a real support, not a missing item): %s" % started.metadata)
	var run: RunState = started.metadata.get("run") as RunState
	assert_equal(run.starting_kit.support_id, &"none", "Ranger's recorded support must be the real &\"none\" id (resolved, not skipped).")


# AC2: a class whose starting_weapon_id does NOT resolve against WeaponRepository rejects fail-closed in BOTH
# validate() and execute() with the stable unknown_starting_weapon code, ZERO events, NO run built, no partial
# kit. The offending weapon id rides metadata. Uses a fixture class with a real lower_snake (so the class
# validates) but non-existent weapon id, injected via a fixture ClassRepository.
func _start_with_bogus_starting_weapon_rejects_fail_closed() -> void:
	var class_repo: ClassRepository = _class_repo_with_bogus_kit(&"bogus_weapon_class", &"not_a_real_weapon", &"shield")
	var command: RunStartCommand = RunStartCommand.new(42, false, 1, &"bogus_weapon_class", class_repo)
	var validation: ActionResult = command.validate(null)
	assert_true(validation.is_error(), "AC2: a missing starting weapon should be rejected by validate().")
	assert_equal(validation.error_code, &"unknown_starting_weapon", "A missing starting weapon should use the stable unknown_starting_weapon code.")
	assert_equal(String(validation.metadata.get("weapon_id", "")), "not_a_real_weapon", "The reject metadata should carry the offending weapon id.")
	var started: ActionResult = command.execute(null)
	assert_true(started.is_error(), "AC2: a missing starting weapon should be rejected by execute().")
	assert_equal(started.error_code, &"unknown_starting_weapon", "execute() should reject a missing starting weapon with unknown_starting_weapon.")
	assert_true(started.events.is_empty(), "A rejected missing-weapon start must emit zero events.")
	assert_false(started.metadata.has("run"), "AC2: a rejected missing-weapon start must build NO run (no partial state).")
	assert_false(started.metadata.has("kit"), "A rejected missing-weapon start must surface no kit.")


# AC2: a class whose starting_support_id does NOT resolve against SupportRepository rejects fail-closed in BOTH
# validate() and execute() with the stable unknown_starting_support code, ZERO events, NO run built. The
# offending support id rides metadata. The weapon (sword) DOES resolve, so the support is the sole failure.
func _start_with_bogus_starting_support_rejects_fail_closed() -> void:
	var class_repo: ClassRepository = _class_repo_with_bogus_kit(&"bogus_support_class", &"sword", &"not_a_real_support")
	var command: RunStartCommand = RunStartCommand.new(42, false, 1, &"bogus_support_class", class_repo)
	var validation: ActionResult = command.validate(null)
	assert_true(validation.is_error(), "AC2: a missing starting support should be rejected by validate().")
	assert_equal(validation.error_code, &"unknown_starting_support", "A missing starting support should use the stable unknown_starting_support code.")
	assert_equal(String(validation.metadata.get("support_id", "")), "not_a_real_support", "The reject metadata should carry the offending support id.")
	var started: ActionResult = command.execute(null)
	assert_true(started.is_error(), "AC2: a missing starting support should be rejected by execute().")
	assert_equal(started.error_code, &"unknown_starting_support", "execute() should reject a missing starting support with unknown_starting_support.")
	assert_true(started.events.is_empty(), "A rejected missing-support start must emit zero events.")
	assert_false(started.metadata.has("run"), "AC2: a rejected missing-support start must build NO run (no partial state).")


# AC1 back-compat: an EMPTY class start records NO kit (run.starting_kit == null) AND its run.to_dictionary() is
# byte-identical to a seed-only start of the same seed (the kit/class add nothing for a legacy run). The 4.6
# seed-only path stays exactly as it was.
func _empty_class_start_records_no_kit_and_stays_byte_identical() -> void:
	var empty_class: ActionResult = RunStartCommand.new(42, false, 1, &"").execute(null)
	assert_true(empty_class.succeeded, "An empty-class start should succeed.")
	var empty_run: RunState = empty_class.metadata.get("run") as RunState
	assert_true(empty_run.starting_kit == null, "AC1 back-compat: an empty-class start must record NO kit (starting_kit == null).")
	assert_false(empty_class.metadata.has("kit"), "An empty-class start must surface no kit metadata.")

	var seed_only: ActionResult = RunStartCommand.new(42).execute(null)
	var seed_only_run: RunState = seed_only.metadata.get("run") as RunState
	assert_true(seed_only_run.starting_kit == null, "A seed-only start must record NO kit.")
	# The full run dict is byte-identical between the seed-only and explicit-empty-class starts.
	assert_equal(JSON.stringify(empty_run.to_dictionary()), JSON.stringify(seed_only_run.to_dictionary()), "An empty-class start must be byte-identical to a seed-only start (no kit, no class).")


# AC3: the 5.2 fail-closed class gate is PRESERVED — a locked/unknown class still rejects BEFORE any kit
# resolution (the reject is the class code, never a kit code; no kit is surfaced). This proves kit resolution
# runs ONLY for a confirmed-selectable class.
func _locked_and_unknown_class_reject_before_kit_resolution() -> void:
	var locked: ActionResult = RunStartCommand.new(42, false, 1, &"necromancer").execute(null)
	assert_true(locked.is_error(), "A locked class must still reject.")
	assert_equal(locked.error_code, &"class_not_selectable", "A locked class rejects with class_not_selectable (BEFORE kit resolution).")
	assert_false(locked.metadata.has("kit"), "A locked-class reject surfaces no kit (kit resolution never ran).")

	var unknown: ActionResult = RunStartCommand.new(42, false, 1, &"does_not_exist").execute(null)
	assert_true(unknown.is_error(), "An unknown class must still reject.")
	assert_equal(unknown.error_code, &"unknown_class", "An unknown class rejects with unknown_class (BEFORE kit resolution).")
	assert_false(unknown.metadata.has("kit"), "An unknown-class reject surfaces no kit (kit resolution never ran).")


# AC3: a class start WITH a kit is deterministic — same inputs -> byte-identical run.to_dictionary() (incl. the
# recorded starting_kit) + the same run_started event. The kit adds no RNG.
func _start_with_kit_is_deterministic_for_same_inputs() -> void:
	var first: ActionResult = RunStartCommand.new(777, false, 1, &"warrior").execute(null)
	var second: ActionResult = RunStartCommand.new(777, false, 1, &"warrior").execute(null)
	assert_true(first.succeeded and second.succeeded, "Both deterministic kit starts should succeed.")
	var first_run: RunState = first.metadata.get("run") as RunState
	var second_run: RunState = second.metadata.get("run") as RunState
	assert_equal(JSON.stringify(first_run.to_dictionary()), JSON.stringify(second_run.to_dictionary()), "Same inputs (with a kit) must produce a byte-identical run.to_dictionary() incl. the recorded kit.")
	assert_equal(JSON.stringify(first.events[0].to_dictionary()), JSON.stringify(second.events[0].to_dictionary()), "Same inputs (with a kit) must produce a byte-identical run_started event.")


# AC1: the applied kit survives a full RunState.to_dictionary() -> try_from_dictionary round-trip (it rides the
# FULL run dict lenient-read, the selected_class_id precedent), so a copied/round-tripped run preserves the kit.
func _applied_kit_survives_run_to_dictionary_round_trip() -> void:
	var started: ActionResult = RunStartCommand.new(42, false, 1, &"warrior").execute(null)
	var run: RunState = started.metadata.get("run") as RunState
	# Round-trip the full run dict through real JSON.
	var round_trip: Variant = JSON.parse_string(JSON.stringify(run.to_dictionary()))
	assert_true(round_trip is Dictionary, "The run dict (with a kit) must survive a JSON round-trip.")
	var parsed: ActionResult = RunState.try_from_dictionary(round_trip)
	assert_true(parsed.succeeded, "A run dict with a kit must parse back: %s" % parsed.metadata)
	var restored: RunState = parsed.metadata.get("run_state") as RunState
	assert_true(restored.starting_kit != null, "The round-tripped run must preserve the applied kit.")
	assert_equal(restored.starting_kit.weapon_id, run.starting_kit.weapon_id, "The round-tripped kit weapon must match.")
	assert_equal(restored.starting_kit.baseline_hp, run.starting_kit.baseline_hp, "The round-tripped kit baseline_hp must match.")
	assert_equal(restored.starting_kit.class_passive_id, run.starting_kit.class_passive_id, "The round-tripped kit class passive id must match.")
	# A copy() also preserves the kit.
	var copied: RunState = run.copy()
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(run.to_dictionary()), "copy() must preserve the applied kit byte-for-byte.")


# ---- Story 5.3 fixture helpers -------------------------------------------------------------------

# Build a fixture ClassRepository containing the five baseline classes PLUS one extra SELECTABLE class whose
# starting_weapon_id / starting_support_id are the supplied ids. The ids must be lower_snake (so ClassDefinition
# .validate() passes) but may be NON-EXISTENT weapon/support ids (so the kit gate fails closed). The baseline
# WeaponRepository/SupportRepository are NOT modified — they are injected with defaults by RunStartCommand, so a
# bogus kit id resolves to null there. No duplicate ids are registered (the duplicate-id trap stays untriggered).
func _class_repo_with_bogus_kit(class_id: StringName, weapon_id: StringName, support_id: StringName) -> ClassRepository:
	var repo: ClassRepository = ClassRepository.create_baseline_repository()
	var fixture: ClassDefinition = ClassDefinition.new(
		class_id,
		"Fixture Class",
		ClassDefinition.LOCK_STATE_SELECTABLE,
		"",
		weapon_id,
		support_id,
		18,
		&"fixture_class_passive",
		&"fixture_equip_synergy_passive"
	)
	var registered: ActionResult = repo.register_class(fixture)
	assert_true(registered.succeeded, "Fixture class registration should succeed: %s" % registered.metadata)
	return repo
