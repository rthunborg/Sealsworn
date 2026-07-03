extends "res://tests/unit/test_case.gd"

# Story 8.6 (AC1-AC4) — OutpostViewModel: the scene-free OUTPOST view-model / read-projection assembly.
#
# OutpostViewModel AGGREGATES the five prior Epic-8 read surfaces into ONE serializable outpost surface a later outpost
# .tscn renders: the ProfileSnapshot cross-run meta (Oath Shards / Echoes / unlock progress / class mastery / first-death
# — source truth), the (optional) just-ended RunSummary, the HeroSelectViewModel class roster (delegated), the (optional)
# FirstDeathNarrativeBeat, plus the named-space metadata (AC2), the start-another-descent request seam (AC3), and the
# structured recovery/fresh-profile path (AC4). It is a PURE READ — it draws ZERO RNG, submits NO command, emits NO
# event, and mutates NOTHING.
#
# This test pins:
#   AC1 — the exact top-level DICTIONARY_KEYS (a key never appears/vanishes) + mutation-independence; the profile-meta
#     readout reads Oath Shards / Echoes / unlock progress / class mastery / first-death from the PROFILE (source truth);
#     the run-summary sub-dict is present (populated for a just-ended run, empty otherwise); the class-options roster
#     delegates to HeroSelectViewModel; building/reading leaves the profile + any run byte-identical.
#   AC2 — named_spaces() has EXACTLY the four GDD spaces with stable lower_snake ids + the pinned per-entry key set + the
#     deferred markers; the descent_stair maps to the start-another-descent affordance; the metadata drives no state.
#   AC3 — start_run_request(...) for a selectable class is startable; for a locked/unknown class NOT startable
#     (fail-closed); handing the request to a fresh RunOrchestrator.start(...) produces a NEW run in PHASE_ACTIVE_ROUTE
#     with empty cleared_node_ids and leaves the prior terminal run byte-identical (prior-run-not-reused, STRUCTURAL); a
#     manual-seed request -> meta_progression_eligible == false on the started run.
#   AC4 — a profile_not_found -> ProfileSnapshot.fresh() outpost builds a valid 0-shard surface (no crash, no progress);
#     an unsupported_profile_schema read surfaces a structured recovery_state (no crash, no invalid meta state, profile
#     untouched); the fresh profile grants NO progress.
#   Plus the first-death render hand-off (the beat sub-dict; a dismiss is a structural no-op; off-critical-path) and the
#     ZERO-RNG / pure-read guarantee.

const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const FirstDeathNarrativeBeat = preload("res://scripts/run/first_death_narrative_beat.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

# The pinned top-level key set (sorted). A key never silently appears/vanishes (the RunSummary / HeroSelectViewModel
# exact-key discipline).
const EXPECTED_TOP_LEVEL_KEYS: Array[String] = [
	"can_start_run",
	"class_mastery",
	"class_options",
	"echoes",
	"first_death_beat",
	"first_death_recorded",
	"has_profile",
	"named_spaces",
	"oath_shards",
	"recovery_state",
	"run_summary",
	"selectable_class_ids",
	"unlock_progress"
]

const EXPECTED_NAMED_SPACE_IDS: Array[String] = [
	"memory_archive",
	"hall_of_oaths",
	"seal_table",
	"descent_stair"
]

const TEST_PROFILE_PATH := "user://test_outpost_profile.json"

func run() -> Dictionary:
	# AC1
	_projection_has_the_exact_pinned_top_level_key_set()
	_projection_is_a_pure_copy_not_a_live_handle()
	_profile_meta_reads_from_the_profile_source_truth()
	_run_summary_sub_dict_is_populated_for_a_just_ended_run()
	_run_summary_sub_dict_is_empty_when_no_run_just_ended()
	_class_options_delegate_to_hero_select_view_model()
	_selectable_class_ids_are_strings_on_both_surfaces()
	_building_and_reading_leaves_the_profile_and_run_byte_identical()
	_oath_shards_read_from_profile_not_the_zero_summary_field()
	# AC2
	_named_spaces_are_exactly_the_four_gdd_spaces_with_stable_ids()
	_named_space_entries_expose_the_exact_pinned_key_set_and_deferred_marker()
	_descent_stair_maps_to_start_another_descent()
	_named_spaces_are_a_pure_copy_not_a_live_handle()
	# AC3
	_start_run_request_for_a_selectable_class_is_startable()
	_start_run_request_for_a_locked_or_unknown_class_is_not_startable()
	_empty_class_start_run_request_is_startable_legacy_no_class()
	_starting_from_an_outpost_holding_a_terminal_run_does_not_reuse_it()
	_manual_seed_request_started_run_is_meta_ineligible()
	# AC1 render / 8.5 hand-off
	_first_death_beat_is_rendered_when_present()
	_first_death_beat_is_empty_when_absent_and_off_critical_path()
	_first_death_dismiss_is_a_structural_no_op()
	# AC4
	_fresh_profile_outpost_is_a_valid_zero_shard_surface()
	_null_profile_projects_the_fresh_profile_default()
	_incompatible_profile_surfaces_a_structured_recovery_state()
	_recovery_outpost_grants_no_progress_and_never_crashes()
	_write_failure_recovery_with_loaded_profile_shows_real_totals()
	_load_failure_recovery_still_shows_the_fresh_profile()
	# Determinism
	_read_is_deterministic_and_rng_free()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A profile with populated cross-run meta (the "returning player" fixture). oath_shards / echoes / unlock_progress /
# class_mastery / first_death_recorded are all NON-empty so the aggregation's read-from-profile path is exercised.
func _populated_profile() -> ProfileSnapshot:
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 12
	profile.echoes = ["echo_of_salt", "echo_of_tide"]
	profile.unlock_progress = {
		"seal_fragments": ["seal_a", "seal_b"],
		"_last_merged_run_seed": "4242",
		"variety_flag_1": true
	}
	profile.class_mastery = {"warrior": 3}
	profile.first_death_recorded = true
	profile.last_awarded_run_seed = "4242"
	return profile


# A run forced into a terminal phase (FAILED or COMPLETED) over a route with one combat start node + one elite + one
# boss, all cleared, with a specific seed + economy. Built directly so the read DTO can be exercised without driving a
# full command sequence (the test_run_summary.gd / test_run_end_outcome.gd _terminal_run precedent).
func _terminal_run(phase: StringName, seed_value: int, is_manual_seed: bool) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var elite: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_CLEARED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_CLEARED, [])
	var route: RouteState = RouteState.new([start, elite, boss], "node-2-0", ["node-0-0", "node-1-0", "node-2-0"])
	var economy: RiskEconomyState = RiskEconomyState.new(25, 0, 2, 1, not is_manual_seed, [])
	var run: RunState = RunState.new(phase, seed_value, is_manual_seed, not is_manual_seed, route, &"", null, null, null, null, economy)
	assert_true(run.validate().succeeded, "Setup: the terminal %s run should validate." % String(phase))
	return run


# ---- AC1: the exact pinned top-level key set -----------------------------------------------------

func _projection_has_the_exact_pinned_top_level_key_set() -> void:
	# Checked for a real-profile, a fresh-profile, and a recovery projection (they all share the shape). A key never
	# silently appears/vanishes.
	var real: Dictionary = OutpostViewModel.new(_populated_profile()).to_dictionary()
	var fresh: Dictionary = OutpostViewModel.new(null).to_dictionary()
	var recovery: Dictionary = OutpostViewModel.for_recovery(&"unsupported_profile_schema").to_dictionary()

	for projected: Dictionary in [real, fresh, recovery]:
		var keys: Array = projected.keys()
		keys.sort()
		assert_equal(keys, EXPECTED_TOP_LEVEL_KEYS, "The outpost projection must expose EXACTLY the pinned top-level key set (no extra/missing key).")

	# The recovery_state sub-dict has its own pinned shape.
	var recovery_state: Dictionary = recovery.get("recovery_state")
	var rk: Array = recovery_state.keys()
	rk.sort()
	assert_equal(rk, ["code", "has_recovery", "is_recoverable"], "The recovery_state sub-dict must expose EXACTLY the pinned key set.")


func _projection_is_a_pure_copy_not_a_live_handle() -> void:
	# The projection is pure serializable data: mutating a returned sub-dict/list must not affect a fresh projection (no
	# shared live handle leaks out of the view model).
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var first: Dictionary = view_model.to_dictionary()
	(first.get("echoes") as Array).append("MUTATED_ECHO")
	(first.get("unlock_progress") as Dictionary)["MUTATED_KEY"] = true
	(first.get("class_mastery") as Dictionary)["MUTATED_KEY"] = 99
	(first.get("named_spaces") as Array).clear()
	(first.get("class_options") as Array).clear()

	var second: Dictionary = view_model.to_dictionary()
	assert_equal((second.get("echoes") as Array).size(), 2, "Mutating a returned echoes list must not perturb a fresh projection.")
	assert_false((second.get("unlock_progress") as Dictionary).has("MUTATED_KEY"), "Mutating a returned unlock_progress must not perturb a fresh projection.")
	assert_false((second.get("class_mastery") as Dictionary).has("MUTATED_KEY"), "Mutating a returned class_mastery must not perturb a fresh projection.")
	assert_equal((second.get("named_spaces") as Array).size(), 4, "Mutating a returned named_spaces list must not perturb a fresh projection.")
	assert_equal((second.get("class_options") as Array).size(), 5, "Mutating a returned class_options list must not perturb a fresh projection.")


func _profile_meta_reads_from_the_profile_source_truth() -> void:
	# AC1: Oath Shards / Echoes / unlock progress / class mastery / first-death are read from the PROFILE (source truth),
	# NOT invented in the view model.
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var data: Dictionary = view_model.to_dictionary()

	assert_equal(int(data.get("oath_shards")), 12, "oath_shards is read from profile.oath_shards (the AWARDED total).")
	assert_true(bool(data.get("has_profile")), "A real loaded profile projects has_profile == true.")
	assert_true(bool(data.get("first_death_recorded")), "first_death_recorded is read from the profile.")

	var echoes: Array = data.get("echoes")
	assert_true(echoes.has("echo_of_salt") and echoes.has("echo_of_tide"), "echoes are read from profile.echoes.")

	var unlock_progress: Dictionary = data.get("unlock_progress")
	assert_true((unlock_progress.get("seal_fragments") as Array).has("seal_a"), "unlock_progress carries the Seal-Fragment set from the profile.")
	assert_equal(String(unlock_progress.get("_last_merged_run_seed")), "4242", "unlock_progress carries the merge idempotency marker verbatim.")

	var class_mastery: Dictionary = data.get("class_mastery")
	assert_equal(int(class_mastery.get("warrior")), 3, "class_mastery is read from the profile.")

	# The recovery_state is the healthy no-recovery state for a real profile.
	var recovery_state: Dictionary = data.get("recovery_state")
	assert_false(bool(recovery_state.get("has_recovery")), "A healthy real profile has has_recovery == false.")


func _run_summary_sub_dict_is_populated_for_a_just_ended_run() -> void:
	# AC1: when a run just ended, the run_summary sub-dict is populated (has_summary == true) from the supplied RunSummary.
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, 4242, false)
	var events: Array = [DomainEvent.run_failed(1, {"cause": "hero_death", "node_id": "node-1-0", "cleared_node_count": 3})]
	var summary: RunSummary = RunSummary.build(run, events)
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile(), summary)

	var run_summary: Dictionary = view_model.to_dictionary().get("run_summary")
	assert_true(bool(run_summary.get("has_summary")), "A just-ended run's summary is populated (has_summary == true).")
	assert_equal(run_summary.get("outcome_or_cause"), "hero_death", "The outpost surfaces the run's death cause from the summary.")
	assert_equal(int((run_summary.get("run_scoped") as Dictionary).get("nodes_cleared")), 3, "The outpost surfaces the run's nodes_cleared from the summary.")
	# notable_loot is rendered DIRECTLY (single-sourced/deduped from item_gained by 8.2 — no second dedup here).
	assert_true((run_summary.get("run_scoped") as Dictionary).has("notable_loot"), "The outpost renders the summary's notable_loot directly.")


func _run_summary_sub_dict_is_empty_when_no_run_just_ended() -> void:
	# AC1: when the outpost opens with no just-ended run (a fresh session — a null summary arg), the run_summary sub-dict
	# is the fail-closed empty projection (has_summary == false).
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var run_summary: Dictionary = view_model.to_dictionary().get("run_summary")
	assert_false(bool(run_summary.get("has_summary")), "With no just-ended run the run_summary sub-dict is the empty projection (has_summary == false).")
	# The empty summary still has the pinned sub-dict shape (a consumer branches on has_summary without inspecting fields).
	assert_true(run_summary.has("run_scoped"), "The empty run_summary still carries the pinned run_scoped sub-dict.")


func _class_options_delegate_to_hero_select_view_model() -> void:
	# AC1: the class-options roster delegates to HeroSelectViewModel (same entries in class_ids() order). The view model
	# does NOT re-project the roster.
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var class_options: Array = view_model.class_options()
	assert_equal(class_options.size(), 5, "The class-options roster projects the 5 MVP classes (delegated to HeroSelectViewModel).")

	var ordered_ids: Array[String] = []
	for entry: Variant in class_options:
		ordered_ids.append(String((entry as Dictionary).get("class_id", "")))
	assert_equal(ordered_ids, ["warrior", "pyromancer", "ranger", "necromancer", "shadeblade"], "The roster is in ClassRepository.class_ids() order (the 5.2 projection).")

	# The projection also carries the per-class HeroSelectViewModel entry shape (class_id/display_name/selectable/unlock_hint).
	var warrior: Dictionary = class_options[0]
	assert_true(warrior.has("selectable") and warrior.has("unlock_hint"), "Each roster entry carries the delegated HeroSelectViewModel entry shape.")

	# The selectable partition is surfaced as the AC3 start-run affordance.
	var selectable: Array = view_model.to_dictionary().get("selectable_class_ids")
	assert_true(selectable.has("warrior") and selectable.has("pyromancer") and selectable.has("ranger"), "selectable_class_ids surfaces the playable roster.")
	assert_false(selectable.has("necromancer"), "A locked class is NOT in selectable_class_ids.")
	assert_true(bool(view_model.to_dictionary().get("can_start_run")), "A start is possible (there is a selectable class).")


func _selectable_class_ids_are_strings_on_both_surfaces() -> void:
	# AC1 / API-shape standardization: the selectable_class_ids field returns the SAME element type on BOTH surfaces — the
	# typed accessor selectable_class_ids() AND the to_dictionary() "selectable_class_ids" key both return Array[String]
	# (the codebase idiom that dictionary projections are JSON-safe plain Strings). Neither surface leaks StringName (a
	# strict ==/dictionary-key comparison against the wrong type could silently miss). Both surfaces AGREE element-for-element.
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())

	var accessor_ids: Array[String] = view_model.selectable_class_ids()
	var dict_ids: Array = view_model.to_dictionary().get("selectable_class_ids")

	# The accessor is a typed Array[String] — every element is a plain String, not a StringName.
	assert_false(accessor_ids.is_empty(), "The selectable roster is non-empty in the baseline.")
	for id: Variant in accessor_ids:
		assert_true(id is String, "Every selectable_class_ids() element is a plain String (not a StringName).")
	for id: Variant in dict_ids:
		assert_true(id is String, "Every to_dictionary()['selectable_class_ids'] element is a plain String (not a StringName).")

	# Both surfaces AGREE (same ids, same String element type) — a consumer reading either gets identical, comparable data.
	assert_equal(accessor_ids, dict_ids, "The accessor and the dict projection expose the SAME selectable_class_ids (same String elements).")
	# A strict String == comparison matches (the whole point of standardizing on String — no StringName trap).
	assert_true(accessor_ids.has("warrior"), "A strict String lookup ('warrior') matches on the standardized accessor.")


func _building_and_reading_leaves_the_profile_and_run_byte_identical() -> void:
	# AC1 source-truth: building/reading the outpost view model NEVER mutates the profile or the run (a pure read).
	var profile: ProfileSnapshot = _populated_profile()
	var profile_before: Dictionary = profile.to_dictionary()

	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, 777, false)
	var run_before: Dictionary = run.to_dictionary()

	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var view_model: OutpostViewModel = OutpostViewModel.new(profile, summary, FirstDeathNarrativeBeat.for_first_death())
	# Read it a few times + take a request (all pure reads).
	view_model.to_dictionary()
	view_model.named_spaces()
	view_model.class_options()
	view_model.start_run_request(999, false, &"warrior")
	view_model.to_dictionary()

	assert_equal(profile.to_dictionary(), profile_before, "Building/reading the outpost view model must leave the profile byte-identical (a pure read).")
	assert_equal(run.to_dictionary(), run_before, "Building/reading the outpost view model must leave the run byte-identical (a pure read).")


func _oath_shards_read_from_profile_not_the_zero_summary_field() -> void:
	# ⭐ The AWARDED Oath-Shard total is the PROFILE's, not the summary's — RunSummary.profile_meta.oath_shards_earned
	# STAYS 0/not-yet-supported (the summary reads no profile). The outpost reads the profile.
	var profile: ProfileSnapshot = _populated_profile()  # oath_shards == 12
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, 5, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var view_model: OutpostViewModel = OutpostViewModel.new(profile, summary)
	var data: Dictionary = view_model.to_dictionary()

	assert_equal(int(data.get("oath_shards")), 12, "The outpost's oath_shards reads the PROFILE's awarded total (12), not the summary's 0.")
	# Confirm the summary field itself is still the 0 placeholder (the outpost did NOT wire it).
	assert_equal(int((data.get("run_summary") as Dictionary).get("profile_meta").get("oath_shards_earned")), 0, "RunSummary.profile_meta.oath_shards_earned STAYS 0 (the summary reads no profile).")


# ---- AC2: named-space metadata -------------------------------------------------------------------

func _named_spaces_are_exactly_the_four_gdd_spaces_with_stable_ids() -> void:
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var spaces: Array = view_model.named_spaces()
	assert_equal(spaces.size(), 4, "There are EXACTLY the four fixed GDD outpost spaces (no more, no fewer).")

	var ids: Array[String] = []
	for space: Variant in spaces:
		ids.append(String((space as Dictionary).get("space_id", "")))
	assert_equal(ids, EXPECTED_NAMED_SPACE_IDS, "The named spaces are the four GDD spaces with stable lower_snake ids in the fixed order.")

	# The display names are the GDD strings (gdd.md line 271).
	var by_id: Dictionary = {}
	for space: Variant in spaces:
		by_id[String((space as Dictionary).get("space_id", ""))] = space
	assert_equal(String((by_id.get("memory_archive") as Dictionary).get("display_name")), "Memory Archive", "memory_archive display name.")
	assert_equal(String((by_id.get("hall_of_oaths") as Dictionary).get("display_name")), "Hall of Oaths", "hall_of_oaths display name.")
	assert_equal(String((by_id.get("seal_table") as Dictionary).get("display_name")), "Seal Table", "seal_table display name.")
	assert_equal(String((by_id.get("descent_stair") as Dictionary).get("display_name")), "Gate or Descent Stair", "descent_stair display name.")


func _named_space_entries_expose_the_exact_pinned_key_set_and_deferred_marker() -> void:
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	for space: Variant in view_model.named_spaces():
		var keys: Array = (space as Dictionary).keys()
		keys.sort()
		assert_equal(keys, ["display_name", "maps_to", "space_id", "status"], "Each named-space entry exposes EXACTLY the pinned key set.")
		# Every v0 space is `deferred` (no interactive content) — the visible-exception-marker discipline.
		assert_equal(String((space as Dictionary).get("status")), "deferred", "Every v0 named space is marked `deferred` (no interactive content yet).")


func _descent_stair_maps_to_start_another_descent() -> void:
	# AC2/AC3: the Gate/Descent Stair is the space that maps to the start-another-descent affordance (the only space with
	# a live affordance in v0). Its maps_to note points at the start-run seam.
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var descent_stair: Dictionary = {}
	for space: Variant in view_model.named_spaces():
		if String((space as Dictionary).get("space_id")) == "descent_stair":
			descent_stair = space
	assert_false(descent_stair.is_empty(), "The descent_stair named space is present.")
	assert_equal(String(descent_stair.get("maps_to")), "start_another_descent", "The descent_stair maps to the start-another-descent affordance (AC3).")


func _named_spaces_are_a_pure_copy_not_a_live_handle() -> void:
	# The named-space metadata is DATA only — mutating a returned entry must not perturb the const registry (drives no
	# state, holds no truth).
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var first: Array = view_model.named_spaces()
	(first[0] as Dictionary)["display_name"] = "MUTATED"
	var second: Array = view_model.named_spaces()
	assert_equal(String((second[0] as Dictionary).get("display_name")), "Memory Archive", "Mutating a returned named-space entry must not perturb the const registry.")


# ---- AC3: the start-another-descent request seam -------------------------------------------------

func _start_run_request_for_a_selectable_class_is_startable() -> void:
	# AC3: a request for a selectable class is startable + carries the class + seed-eligibility settings + the pinned shape.
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var request: Dictionary = view_model.start_run_request(123456789, false, &"warrior")

	var keys: Array = request.keys()
	keys.sort()
	assert_equal(keys, ["class_id", "is_manual_seed", "is_startable", "root_seed"], "The start request exposes EXACTLY the pinned key set.")
	assert_true(bool(request.get("is_startable")), "A request for a selectable class (warrior) is startable.")
	assert_equal(String(request.get("class_id")), "warrior", "The request carries the selected class id.")
	assert_equal(String(request.get("root_seed")), "123456789", "The request carries the decimal-string-encoded seed.")
	assert_false(bool(request.get("is_manual_seed")), "A normal-seed request is not manual-seed.")


func _start_run_request_for_a_locked_or_unknown_class_is_not_startable() -> void:
	# AC3 fail-closed: a request for a LOCKED class (necromancer) or an UNKNOWN class produces a NOT-startable request
	# (is_startable == false — via the HeroSelectViewModel pre-gate). The AUTHORITATIVE gate is still RunStartCommand.
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	assert_false(bool(view_model.start_run_request(1, false, &"necromancer").get("is_startable")), "A locked class produces a NOT-startable request (fail-closed).")
	assert_false(bool(view_model.start_run_request(1, false, &"does_not_exist").get("is_startable")), "An unknown class produces a NOT-startable request (fail-closed).")


func _empty_class_start_run_request_is_startable_legacy_no_class() -> void:
	# AC3: an EMPTY class id is the legacy no-class start (startable — the RunStartCommand back-compat path).
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var request: Dictionary = view_model.start_run_request(1, false, &"")
	assert_true(bool(request.get("is_startable")), "An empty class id is the legacy no-class start (startable).")
	assert_equal(String(request.get("class_id")), "", "The empty-class request carries an empty class id.")


func _starting_from_an_outpost_holding_a_terminal_run_does_not_reuse_it() -> void:
	# AC3 (the load-bearing test): build a start request FROM an outpost holding a TERMINAL prior run, hand it to a FRESH
	# RunOrchestrator.start(...), and assert the NEW run is in PHASE_ACTIVE_ROUTE with EMPTY cleared_node_ids (a fresh
	# route, NOT the prior run's cleared set), and the prior terminal run is BYTE-IDENTICAL (untouched). Prior-run-not-
	# reused is STRUCTURAL via RunState.new_run(...).
	var prior_run: RunState = _terminal_run(RunState.PHASE_FAILED, 4242, false)
	assert_equal(prior_run.route.cleared_node_ids.size(), 3, "Setup: the prior terminal run has 3 cleared nodes.")
	var prior_before: Dictionary = prior_run.to_dictionary()

	# The outpost holds the terminal prior run (for the SUMMARY) but never threads it into the start path.
	var summary: RunSummary = RunSummary.build(prior_run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile(), summary)

	# The outpost produces a REQUEST; the caller starts the run via a FRESH orchestrator (a NEW seed -> a new route).
	var request: Dictionary = view_model.start_run_request(987654321, false, &"warrior")
	assert_true(bool(request.get("is_startable")), "Setup: the warrior start request is startable.")

	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start_result: Variant = orchestrator.start(int(String(request.get("root_seed")).to_int()), bool(request.get("is_manual_seed")), StringName(String(request.get("class_id"))))
	assert_true(start_result.succeeded, "The fresh orchestrator start (from the request) succeeds: %s" % start_result.metadata)

	var new_run: RunState = orchestrator.run
	assert_equal(new_run.phase, RunState.PHASE_ACTIVE_ROUTE, "The started run is a NEW run in PHASE_ACTIVE_ROUTE.")
	assert_true(new_run.route.cleared_node_ids.is_empty(), "The NEW run has EMPTY cleared_node_ids (a fresh route — NOT the prior run's cleared set).")
	assert_equal(String(new_run.selected_class_id), "warrior", "The NEW run records the selected class from the request.")
	assert_equal(str(new_run.root_seed), "987654321", "The NEW run uses the request's fresh seed (not the prior run's 4242).")

	# The prior terminal run is left BYTE-IDENTICAL (untouched — the outpost never threaded it into the start path).
	assert_equal(prior_run.to_dictionary(), prior_before, "The prior terminal run is left byte-identical (prior-run-not-reused, STRUCTURAL).")
	assert_equal(prior_run.route.cleared_node_ids.size(), 3, "The prior run's cleared set is untouched (still 3).")


func _manual_seed_request_started_run_is_meta_ineligible() -> void:
	# AC3 seed-eligibility: a MANUAL-seed request threads is_manual_seed into the start; the started run reports
	# meta_progression_eligible == false (the existing lockstep — 8.6 does NOT re-implement eligibility).
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var request: Dictionary = view_model.start_run_request(555, true, &"warrior")
	assert_true(bool(request.get("is_manual_seed")), "The request carries the manual-seed flag.")

	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start_result: Variant = orchestrator.start(int(String(request.get("root_seed")).to_int()), bool(request.get("is_manual_seed")), StringName(String(request.get("class_id"))))
	assert_true(start_result.succeeded, "The manual-seed start succeeds: %s" % start_result.metadata)
	assert_false(orchestrator.run.meta_progression_eligible, "A manual-seed run is meta-ineligible (the seed-eligibility lockstep).")

	# A normal-seed start is eligible (the contrast).
	var normal_request: Dictionary = view_model.start_run_request(556, false, &"warrior")
	var normal_orchestrator: RunOrchestrator = RunOrchestrator.new()
	normal_orchestrator.start(int(String(normal_request.get("root_seed")).to_int()), false, &"warrior")
	assert_true(normal_orchestrator.run.meta_progression_eligible, "A normal-seed run is meta-eligible.")


# ---- AC1 render / the 8.5 first-death hand-off ---------------------------------------------------

func _first_death_beat_is_rendered_when_present() -> void:
	# AC1 render (the 8.5 hand-off): the outpost includes the FirstDeathNarrativeBeat sub-dict when a beat is present (the
	# resolved line + is_skippable == true).
	var beat: FirstDeathNarrativeBeat = FirstDeathNarrativeBeat.for_first_death()
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile(), null, beat)
	var beat_data: Dictionary = view_model.to_dictionary().get("first_death_beat")

	assert_true(bool(beat_data.get("has_beat")), "A present first-death beat is rendered (has_beat == true).")
	assert_equal(String(beat_data.get("line_id")), "first_death", "The beat carries the first-death line id.")
	assert_equal(String(beat_data.get("line")), FirstDeathNarrativeBeat.FIRST_DEATH_LINE, "The beat carries the resolved first-death line prose.")
	assert_true(bool(beat_data.get("is_skippable")), "The first-death beat is skippable (FR65).")

	# The beat is also readable from a first_death_recorded event (the from_event seam).
	var event: DomainEvent = DomainEvent.first_death_recorded(1, {"line_id": "first_death", "is_skippable": true})
	var event_beat_vm: OutpostViewModel = OutpostViewModel.new(_populated_profile(), null, FirstDeathNarrativeBeat.from_event(event))
	assert_true(bool(event_beat_vm.to_dictionary().get("first_death_beat").get("has_beat")), "The beat is rendered from a first_death_recorded event too.")


func _first_death_beat_is_empty_when_absent_and_off_critical_path() -> void:
	# AC1 render / AC3 off-critical-path: a null/absent beat projects the fail-closed empty beat (has_beat == false) and
	# NEVER blocks the rest of the outpost surface (the summary, the class options, the start-run action all still work).
	var view_model: OutpostViewModel = OutpostViewModel.new(_populated_profile())  # no beat
	var data: Dictionary = view_model.to_dictionary()
	assert_false(bool((data.get("first_death_beat") as Dictionary).get("has_beat")), "An absent beat projects the fail-closed empty beat (has_beat == false).")

	# The outpost surface stands WITHOUT the beat.
	assert_equal((data.get("class_options") as Array).size(), 5, "The class options are present without a beat (off-critical-path).")
	assert_true(bool(data.get("can_start_run")), "A start is possible without a beat (lore reading is NOT required to start another descent).")
	assert_true(bool(view_model.start_run_request(1, false, &"warrior").get("is_startable")), "The start-run action does not read the beat as a precondition.")


func _first_death_dismiss_is_a_structural_no_op() -> void:
	# AC1 render (Task 3.2): a build + read + simulated DISMISS leaves the profile + any run byte-identical (the dismiss is
	# a structural no-op — there is NO dismiss command; the beat DTO is read-only and the flag was set independently by
	# 8.5's command). A "dismiss" is simply the outpost not rendering the beat further — it mutates NOTHING.
	var profile: ProfileSnapshot = _populated_profile()
	var profile_before: Dictionary = profile.to_dictionary()
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, 4242, false)
	var run_before: Dictionary = run.to_dictionary()

	var beat: FirstDeathNarrativeBeat = FirstDeathNarrativeBeat.for_first_death()
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var view_model: OutpostViewModel = OutpostViewModel.new(profile, summary, beat)

	# Read the beat (render it), then "dismiss" (simply build a NEW projection with NO beat — the presentation no-op). No
	# command, no mutation.
	assert_true(bool(view_model.to_dictionary().get("first_death_beat").get("has_beat")), "The beat renders.")
	var dismissed: OutpostViewModel = OutpostViewModel.new(profile, summary)  # the dismiss: no beat
	assert_false(bool(dismissed.to_dictionary().get("first_death_beat").get("has_beat")), "The dismissed outpost simply does not render the beat further.")

	assert_equal(profile.to_dictionary(), profile_before, "A dismiss leaves the profile byte-identical (the first-death flag is unchanged — no dismiss mutation).")
	assert_equal(run.to_dictionary(), run_before, "A dismiss leaves the run byte-identical.")
	# The profile's first-death flag was ALREADY set (by 8.5's command) independently of the beat display.
	assert_true(profile.first_death_recorded, "The first-death flag stays set (it was set independently of the beat display).")


# ---- AC4: the structured recovery / fresh-profile path -------------------------------------------

func _fresh_profile_outpost_is_a_valid_zero_shard_surface() -> void:
	# AC4: an outpost built from a FRESH profile (ProfileSnapshot.fresh() — the profile_not_found recovery path) is a
	# VALID surface: 0 Oath Shards, empty Echoes/unlock progress/class mastery, first-death not recorded, the full class
	# roster. No crash, no invalid meta state.
	var view_model: OutpostViewModel = OutpostViewModel.new(ProfileSnapshot.fresh())
	var data: Dictionary = view_model.to_dictionary()

	assert_true(bool(data.get("has_profile")), "A supplied fresh profile is still a supplied profile (has_profile == true).")
	assert_equal(int(data.get("oath_shards")), 0, "The fresh-profile outpost has 0 Oath Shards (no unintended progress).")
	assert_true((data.get("echoes") as Array).is_empty(), "The fresh-profile outpost has empty Echoes.")
	assert_true((data.get("unlock_progress") as Dictionary).is_empty(), "The fresh-profile outpost has empty unlock progress.")
	assert_true((data.get("class_mastery") as Dictionary).is_empty(), "The fresh-profile outpost has empty class mastery.")
	assert_false(bool(data.get("first_death_recorded")), "The fresh-profile outpost has first-death not recorded.")
	assert_equal((data.get("class_options") as Array).size(), 5, "The fresh-profile outpost still projects the full class roster.")
	assert_true(bool(data.get("can_start_run")), "The fresh-profile outpost can start a run.")


func _null_profile_projects_the_fresh_profile_default() -> void:
	# AC4: a null/absent profile projects the fresh-profile default (has_profile == false distinguishes it from a real
	# profile). No crash. This is the profile_not_found -> fresh() path modeled structurally in the view model.
	var view_model: OutpostViewModel = OutpostViewModel.new(null)
	var data: Dictionary = view_model.to_dictionary()
	assert_false(bool(data.get("has_profile")), "A null profile projects has_profile == false (the fresh-profile default).")
	assert_equal(int(data.get("oath_shards")), 0, "A null-profile outpost has 0 Oath Shards.")
	assert_equal((data.get("class_options") as Array).size(), 5, "A null-profile outpost still projects the full class roster (no crash).")

	# The actual profile_not_found recovery flow: a repository read of an absent file -> the caller starts fresh() -> the
	# outpost. Proves the end-to-end AC4 recovery path uses the structured result, not a crash.
	_cleanup()
	var repository: ProfileRepository = ProfileRepository.new()
	var read_result: Variant = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.is_error() and read_result.error_code == &"profile_not_found", "A read of an absent profile surfaces profile_not_found.")
	var recovered_vm: OutpostViewModel = OutpostViewModel.new(ProfileSnapshot.fresh())
	assert_equal(int(recovered_vm.to_dictionary().get("oath_shards")), 0, "The profile_not_found -> fresh() recovery builds a valid 0-shard outpost.")


func _incompatible_profile_surfaces_a_structured_recovery_state() -> void:
	# AC4: an INCOMPATIBLE profile (unsupported_profile_schema from the repository read) is represented as a STRUCTURED
	# recovery_state (a flag + the structured code), NOT a crash. 8.6 CONSUMES the existing structured result.
	_cleanup()
	# Write a future-schema profile so the read surfaces unsupported_profile_schema (the migration reject).
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": ProfileSnapshot.SCHEMA_VERSION + 10, "content_version": "future"}))
	file.flush()
	file = null

	var repository: ProfileRepository = ProfileRepository.new()
	var read_result: Variant = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.is_error(), "An incompatible profile read fails (the migration reject).")
	assert_equal(read_result.error_code, &"unsupported_profile_schema", "The incompatible read surfaces unsupported_profile_schema.")

	# The caller builds a recovery outpost from the structured code (a later HUD story renders the recover affordance).
	var view_model: OutpostViewModel = OutpostViewModel.for_recovery(read_result.error_code)
	var data: Dictionary = view_model.to_dictionary()

	var recovery_state: Dictionary = data.get("recovery_state")
	assert_true(bool(recovery_state.get("has_recovery")), "The incompatible-profile outpost surfaces a recovery state (has_recovery == true).")
	assert_equal(String(recovery_state.get("code")), "unsupported_profile_schema", "The recovery state carries the structured code.")
	assert_true(bool(recovery_state.get("is_recoverable")), "The recovery is recoverable (a fresh-profile fallback / retry affordance).")
	# No invalid meta state: the recovery surface is a valid 0-shard fresh surface (NOT a crash, NOT half-state).
	assert_false(bool(data.get("has_profile")), "The recovery outpost has has_profile == false (a fresh/recovery surface).")
	assert_equal(int(data.get("oath_shards")), 0, "The recovery outpost has 0 Oath Shards (no invalid meta state).")
	assert_equal((data.get("class_options") as Array).size(), 5, "The recovery outpost still projects the full class roster (no crash).")
	_cleanup()


func _recovery_outpost_grants_no_progress_and_never_crashes() -> void:
	# AC4: a recovery-state outpost grants NO progress (0 Oath Shards, empty homes — no invalid meta state) and never
	# mutates a profile (there is no profile to mutate — the fresh default). Also covers a write-failure recovery code.
	var view_model: OutpostViewModel = OutpostViewModel.for_recovery(&"profile_save_open_failed")
	var data: Dictionary = view_model.to_dictionary()
	assert_true(bool((data.get("recovery_state") as Dictionary).get("has_recovery")), "A write-failure recovery state is surfaced.")
	assert_equal(String((data.get("recovery_state") as Dictionary).get("code")), "profile_save_open_failed", "The write-failure recovery carries its structured code.")
	assert_equal(int(data.get("oath_shards")), 0, "The recovery outpost grants no Oath Shards.")
	assert_true((data.get("echoes") as Array).is_empty(), "The recovery outpost has empty Echoes (no invalid meta state).")
	assert_true((data.get("unlock_progress") as Dictionary).is_empty(), "The recovery outpost has empty unlock progress.")
	# The start-run affordance still works in a recovery state (a fresh start is always possible).
	assert_true(bool(view_model.start_run_request(1, false, &"warrior").get("is_startable")), "The recovery outpost can still start a fresh run.")


func _write_failure_recovery_with_loaded_profile_shows_real_totals() -> void:
	# AC4 (profile-WRITE failure): a profile_save_* code means the profile was successfully READ and the player accumulated
	# REAL progress THIS session; only the WRITE failed. The caller holds the intact loaded profile and passes it to
	# for_recovery(code, loaded_profile) so the surface shows the player's REAL Oath-Shard / Echoes / unlock totals BEHIND
	# the retry banner (has_profile == true) — NOT a misleading 0-shard surface. The recovery_state still carries the
	# structured write-failure code. The loaded profile is read verbatim (byte-identical — a pure read).
	var loaded_profile: ProfileSnapshot = _populated_profile()  # oath_shards == 12, non-empty echoes/unlock/mastery
	var loaded_before: Dictionary = loaded_profile.to_dictionary()

	var view_model: OutpostViewModel = OutpostViewModel.for_recovery(&"profile_save_replace_failed", loaded_profile)
	var data: Dictionary = view_model.to_dictionary()

	# The recovery banner is surfaced with the structured write-failure code + retry affordance.
	var recovery_state: Dictionary = data.get("recovery_state")
	assert_true(bool(recovery_state.get("has_recovery")), "A write-failure recovery state is surfaced.")
	assert_equal(String(recovery_state.get("code")), "profile_save_replace_failed", "The write-failure recovery carries its structured code.")
	assert_true(bool(recovery_state.get("is_recoverable")), "The write failure is recoverable (a retry affordance).")

	# ⭐ The REAL loaded totals show BEHIND the retry banner (NOT a false 0-shard surface) — the whole point of the fix.
	assert_true(bool(data.get("has_profile")), "A write-failure recovery WITH a loaded profile has has_profile == true (real profile behind the banner).")
	assert_equal(int(data.get("oath_shards")), 12, "The write-failure recovery shows the player's REAL Oath-Shard total (12), NOT a false 0.")
	assert_true((data.get("echoes") as Array).has("echo_of_salt"), "The write-failure recovery shows the player's REAL discovered Echoes.")
	assert_true((data.get("unlock_progress") as Dictionary).has("seal_fragments"), "The write-failure recovery shows the player's REAL unlock progress.")
	assert_equal(int((data.get("class_mastery") as Dictionary).get("warrior")), 3, "The write-failure recovery shows the player's REAL class mastery.")
	assert_true(bool(data.get("first_death_recorded")), "The write-failure recovery shows the player's REAL first-death latch.")

	# The loaded profile is left byte-identical (a pure read — the recovery surface never mutates it).
	assert_equal(loaded_profile.to_dictionary(), loaded_before, "The write-failure recovery reads the loaded profile verbatim (byte-identical — a pure read).")


func _load_failure_recovery_still_shows_the_fresh_profile() -> void:
	# AC4 (profile-LOAD failure — the current/default behavior, still correct): for a load-failure code
	# (unsupported_profile_schema / profile_not_found) there is NO valid loaded profile, so for_recovery(code) (no
	# loaded_profile) falls back to ProfileSnapshot.fresh() — a valid 0-shard surface (has_profile == false). This is the
	# honest recovery representation (no real totals exist to show). Contrasted directly with the write-failure case above.
	var view_model: OutpostViewModel = OutpostViewModel.for_recovery(&"unsupported_profile_schema")
	var data: Dictionary = view_model.to_dictionary()

	var recovery_state: Dictionary = data.get("recovery_state")
	assert_true(bool(recovery_state.get("has_recovery")), "A load-failure recovery state is surfaced.")
	assert_equal(String(recovery_state.get("code")), "unsupported_profile_schema", "The load-failure recovery carries its structured code.")
	# The fresh 0-shard surface (has_profile == false) — NO real totals exist for a load failure.
	assert_false(bool(data.get("has_profile")), "A load-failure recovery (no loaded profile) has has_profile == false (the fresh default).")
	assert_equal(int(data.get("oath_shards")), 0, "The load-failure recovery shows the FRESH profile (0 Oath Shards — no real totals to show).")
	assert_true((data.get("echoes") as Array).is_empty(), "The load-failure recovery shows empty Echoes (the fresh profile).")
	assert_true((data.get("unlock_progress") as Dictionary).is_empty(), "The load-failure recovery shows empty unlock progress (the fresh profile).")
	assert_false(bool(data.get("first_death_recorded")), "The load-failure recovery shows the fresh first-death latch (false).")


# ---- determinism: the view model draws ZERO RNG (a pure read/assembly) ---------------------------

func _read_is_deterministic_and_rng_free() -> void:
	# Same inputs -> identical projection (a pure read of the profile + summary + beat + roster + named spaces). Building
	# twice and reading twice are byte-identical (no RNG, no mutation, no events).
	var profile: ProfileSnapshot = _populated_profile()
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var beat: FirstDeathNarrativeBeat = FirstDeathNarrativeBeat.for_first_death()

	var first: Dictionary = OutpostViewModel.new(profile, summary, beat).to_dictionary()
	var second: Dictionary = OutpostViewModel.new(profile, summary, beat).to_dictionary()
	assert_equal(JSON.stringify(first), JSON.stringify(second), "Two outpost projections from the same inputs are byte-identical (a pure read; ZERO RNG).")

	# The same view model read twice is identical.
	var view_model: OutpostViewModel = OutpostViewModel.new(profile, summary, beat)
	assert_equal(JSON.stringify(view_model.to_dictionary()), JSON.stringify(view_model.to_dictionary()), "Reading the same view model twice is byte-identical.")


func _cleanup() -> void:
	for path: String in [TEST_PROFILE_PATH, "%s.tmp" % TEST_PROFILE_PATH, "%s.bak" % TEST_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
