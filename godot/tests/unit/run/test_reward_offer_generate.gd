extends "res://tests/unit/test_case.gd"

# Story 6.3 Task 3 — the reward GENERATE path (RunOrchestrator.generate_reward_offer /
# generate_passive_reward_offer): the FIRST live reward roll through the run + the T2 inert-stream fix. Pins:
#   - GENERATE draws a DETERMINISTIC offer through the RUN-LEVEL RngStreamSet on the named rewards/loot stream
#     (metadata.stream_name == "rewards"/"loot"; the offer is stored on RunState as `pending`; a reward_offered
#     event is emitted; the sequence counter advances);
#   - SAME seed reproduces a byte-identical offer; a DIFFERENT seed diverges (the draw keys off the stream);
#   - the T2 fix (replacing the inert-stream false confidence): a route-position snapshot composed AFTER a reward
#     draw round-trips a stream whose NEXT rewards draw reproduces (the run-level stream ADVANCED, and the
#     route-position save persists the advanced stream — interrupted == uninterrupted once RNG advances mid-run);
#   - an unknown table id fails closed (no fabricated offer); a generate while an offer is still pending fails
#     closed (no silently-dropped offer);
#   - the AC4 passive offer yields THREE DISTINCT passive choices (draw-without-replacement through the run-level
#     stream); every offered passive id is a real baseline passive id.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const GoldRewardRepository = preload("res://scripts/content/repositories/gold_reward_repository.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const ResolveRewardCommand = preload("res://scripts/core/commands/resolve_reward_command.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const SAVE_PATH := "user://test_reward_offer_generate_save.json"
const SEED_SAMPLE: Array[int] = [1, 7, 42, 99, 2026]

func run() -> Dictionary:
	_generate_draws_a_deterministic_offer_through_the_rewards_stream()
	_generate_can_draw_through_the_loot_stream()
	_same_seed_reproduces_a_byte_identical_offer()
	_different_seeds_diverge()
	_generate_advances_the_run_level_stream_and_route_position_save_persists_it()
	_unknown_table_fails_closed()
	_generate_while_an_offer_is_pending_fails_closed()
	_passive_offer_yields_three_distinct_passive_choices()
	_passive_offer_is_deterministic_for_same_seed()
	# Story 7.1 (the T1 wire-off): GENERATE rolls a concrete gold amount within the band; RESOLVE credits it.
	_gold_offer_generates_a_rolled_amount_within_the_band_and_resolve_credits_it()
	_gold_offer_is_deterministic_for_same_seed()
	_non_gold_offer_rolls_no_gold()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A fresh started orchestrator (seeds both the run + the run-level streams from root_seed).
func _started(seed_value: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Seed %d: start should succeed." % seed_value)
	return orchestrator


func _write_through_repository(snapshot: RunSnapshot) -> void:
	var write_result: ActionResult = SaveRepository.new().write_run_snapshot(snapshot, SAVE_PATH)
	assert_true(write_result.succeeded, "Writing the route-position snapshot should succeed: %s" % write_result.metadata)


# ---- AC1: deterministic generate through the run-level streams -----------------------------------

func _generate_draws_a_deterministic_offer_through_the_rewards_stream() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var generate: ActionResult = orchestrator.generate_reward_offer(&"standard_combat_reward")
	assert_true(generate.succeeded, "Generating a reward offer should succeed: %s" % generate.metadata)
	# The draw used the named rewards stream.
	assert_equal(String(generate.metadata.get("stream_name")), "rewards", "The reward draw must use the named rewards stream.")
	# The offer is stored on RunState as pending.
	assert_true(orchestrator.run.pending_reward_offer != null, "The generated offer must be stored on RunState.")
	assert_true(orchestrator.run.pending_reward_offer.is_pending(), "The stored offer must be pending.")
	assert_equal(orchestrator.run.pending_reward_offer.table_id, &"standard_combat_reward", "The stored offer must carry the table id.")
	assert_equal(orchestrator.run.pending_reward_offer.offered_entries.size(), 1, "A standard offer carries one offered entry.")
	assert_equal(String(orchestrator.run.pending_reward_offer.stream_name), "rewards", "The stored offer records the rewards stream.")
	# A reward_offered event was emitted + is payload-valid.
	assert_equal(generate.events.size(), 1, "Generating a reward offer emits exactly one event.")
	assert_equal(generate.events[0].event_type, DomainEvent.Type.REWARD_OFFERED, "The emitted event should be reward_offered.")
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(generate.events[0].to_dictionary())))
	assert_true(parsed.succeeded, "The emitted reward_offered event should pass payload validation: %s" % parsed.metadata)


func _generate_can_draw_through_the_loot_stream() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var generate: ActionResult = orchestrator.generate_reward_offer(&"standard_combat_reward", RngStreamSet.STREAM_LOOT)
	assert_true(generate.succeeded, "Generating a loot offer should succeed: %s" % generate.metadata)
	assert_equal(String(generate.metadata.get("stream_name")), "loot", "The draw must use the named loot stream when asked.")
	assert_equal(String(orchestrator.run.pending_reward_offer.stream_name), "loot", "The stored offer records the loot stream.")


func _same_seed_reproduces_a_byte_identical_offer() -> void:
	for seed_value: int in SEED_SAMPLE:
		var a: RunOrchestrator = _started(seed_value)
		var b: RunOrchestrator = _started(seed_value)
		assert_true(a.generate_reward_offer(&"standard_combat_reward").succeeded, "Seed %d: offer A should generate." % seed_value)
		assert_true(b.generate_reward_offer(&"standard_combat_reward").succeeded, "Seed %d: offer B should generate." % seed_value)
		assert_equal(
			JSON.stringify(a.run.pending_reward_offer.to_dictionary()),
			JSON.stringify(b.run.pending_reward_offer.to_dictionary()),
			"Seed %d: the same seed + same pre-draw state must reproduce a byte-identical offer." % seed_value
		)


func _different_seeds_diverge() -> void:
	var distinct: Dictionary = {}
	for seed_value: int in SEED_SAMPLE:
		var orchestrator: RunOrchestrator = _started(seed_value)
		assert_true(orchestrator.generate_reward_offer(&"standard_combat_reward").succeeded, "Seed %d: offer should generate." % seed_value)
		var entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
		distinct["%s/%s" % [String(entry.get("category")), String(entry.get("content_id"))]] = true
	assert_true(distinct.size() >= 2, "Across the seed sample the generated offer must diverge (>= 2 distinct selections), proving it keys off the stream.")


# ---- T2 fix: the run-level stream advances + the route-position save persists it ------------------

func _generate_advances_the_run_level_stream_and_route_position_save_persists_it() -> void:
	# The T2 inert-stream fix (REPLACING the false-confidence inert round-trip): draw a reward through the run
	# BEFORE composing the route-position snapshot, then assert the restored stream reproduces the NEXT rewards
	# draw (the run-level stream ADVANCED, and the route-position save persists the advanced stream).
	var orchestrator: RunOrchestrator = _started(2026)
	# Capture the pre-draw rewards draw_index to prove the draw advances the run-level set.
	var pre_snapshot: Dictionary = orchestrator.streams.to_snapshot()
	var pre_rewards: Dictionary = (pre_snapshot.get("streams") as Dictionary).get("rewards")
	assert_equal(int(pre_rewards.get("draw_index")), 0, "Setup: the rewards stream starts at draw_index 0 (inert).")

	# Draw a reward through the run-level streams (this advances orchestrator.streams' rewards stream). Story 7.1: a
	# GOLD offer draws a SECOND time on the SAME stream (the gold-amount roll within the band), so for a seed whose
	# offer is gold the stream advances by 2; a non-gold offer advances by 1. The T2 proof is that the stream
	# ADVANCED (not inert) and the route-position save persists the advanced state — assert advancement (> 0), not an
	# exact count (which now depends on whether the drawn offer is gold).
	assert_true(orchestrator.generate_reward_offer(&"standard_combat_reward").succeeded, "The reward generate should succeed for the T2 proof.")
	var post_snapshot: Dictionary = orchestrator.streams.to_snapshot()
	var post_rewards: Dictionary = (post_snapshot.get("streams") as Dictionary).get("rewards")
	assert_true(int(post_rewards.get("draw_index")) >= 1, "The reward draw must ADVANCE the run-level rewards stream (draw_index 0 -> >= 1; a gold offer rolls a second amount draw) — the T2 fix (not inert).")

	# Peek the LIVE post-draw next rewards draw from a restored copy (so the live streams stay untouched).
	var expected_streams: RngStreamSet = RngStreamSet.new(0)
	assert_true(expected_streams.try_restore(post_snapshot).succeeded, "The post-draw snapshot should restore for the expected-draw peek.")
	var expected_draw: ActionResult = expected_streams.rand_int(RngStreamSet.STREAM_REWARDS, 0, 1000000, {})
	assert_true(expected_draw.succeeded, "The expected next rewards draw should succeed.")

	# Compose the route-position snapshot AFTER the reward draw, write + read it through the REAL repository, and
	# assert the restored run-level streams reproduce the EXACT next rewards draw (the advanced stream round-trips).
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	assert_true(snapshot != null, "compose_route_position_snapshot should return a snapshot after a reward draw.")
	_write_through_repository(snapshot)
	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Resuming the post-reward-draw route position should succeed: %s" % restore.metadata)
	var restored_streams: RngStreamSet = restore.metadata.get("rng_streams") as RngStreamSet
	assert_true(restored_streams != null, "The route-position resume should return restored RNG streams.")
	var restored_draw: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_REWARDS, 0, 1000000, {})
	assert_true(restored_draw.succeeded, "The restored next rewards draw should succeed.")
	assert_equal(restored_draw.metadata.get("value"), expected_draw.metadata.get("value"), "The restored run-level streams must reproduce the EXACT next REWARDS draw — the route-position save persists the stream the reward roll advanced (T2 fix).")


# ---- fail-closed ---------------------------------------------------------------------------------

func _unknown_table_fails_closed() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var rejected: ActionResult = orchestrator.generate_reward_offer(&"does_not_exist")
	assert_true(rejected.is_error(), "Generating from an unknown table id must fail closed.")
	assert_equal(rejected.error_code, &"unknown_reward_table", "An unknown table should use the stable unknown_reward_table code.")
	assert_true(orchestrator.run.pending_reward_offer == null, "A failed generate must store NO offer (no fabricated default).")
	assert_false(rejected.has_events(), "A failed generate must emit no event.")


func _generate_while_an_offer_is_pending_fails_closed() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	assert_true(orchestrator.generate_reward_offer(&"standard_combat_reward").succeeded, "The first generate should succeed.")
	var second: ActionResult = orchestrator.generate_reward_offer(&"elite_combat_reward")
	assert_true(second.is_error(), "Generating a second offer while one is pending must fail closed (no silently-dropped offer).")
	assert_equal(second.error_code, &"reward_offer_pending", "A pending-offer generate should use the stable reward_offer_pending code.")
	assert_equal(orchestrator.run.pending_reward_offer.table_id, &"standard_combat_reward", "The first (still-pending) offer must be preserved.")


# ---- AC4: three distinct passive choices ---------------------------------------------------------

func _passive_offer_yields_three_distinct_passive_choices() -> void:
	var passive_ids: Array[StringName] = PassiveRepository.BASELINE_PASSIVE_IDS
	for seed_value: int in SEED_SAMPLE:
		var orchestrator: RunOrchestrator = _started(seed_value)
		var generate: ActionResult = orchestrator.generate_passive_reward_offer(&"passive_reward_choice")
		assert_true(generate.succeeded, "Seed %d: the passive offer should generate: %s" % [seed_value, generate.metadata])
		var offer: RewardOffer = orchestrator.run.pending_reward_offer
		assert_equal(offer.offered_entries.size(), 3, "Seed %d: an AC4 passive 3-choice offer carries THREE choices." % seed_value)
		# The three are DISTINCT passive content ids, each a real baseline passive id.
		var seen: Dictionary = {}
		for entry_value: Variant in offer.offered_entries:
			var entry: Dictionary = entry_value
			assert_equal(String(entry.get("category")), "passive", "Seed %d: every offered entry is a passive." % seed_value)
			var content_id: StringName = StringName(String(entry.get("content_id")))
			assert_false(seen.has(content_id), "Seed %d: the three passive choices must be DISTINCT (no duplicate %s)." % [seed_value, String(content_id)])
			seen[content_id] = true
			assert_true(passive_ids.has(content_id), "Seed %d: the offered passive %s must be a real baseline passive id." % [seed_value, String(content_id)])
		# A reward_offered event carrying the three entries was emitted + is payload-valid.
		assert_equal(generate.events.size(), 1, "Seed %d: the passive generate emits one reward_offered event." % seed_value)
		var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(generate.events[0].to_dictionary())))
		assert_true(parsed.succeeded, "Seed %d: the passive reward_offered event should pass payload validation: %s" % [seed_value, parsed.metadata])
		assert_equal((parsed.metadata.get("event") as DomainEvent).payload.get("offered_entries").size(), 3, "Seed %d: the event payload carries the three offered entries." % seed_value)


func _passive_offer_is_deterministic_for_same_seed() -> void:
	for seed_value: int in SEED_SAMPLE:
		var a: RunOrchestrator = _started(seed_value)
		var b: RunOrchestrator = _started(seed_value)
		assert_true(a.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Seed %d: passive offer A should generate." % seed_value)
		assert_true(b.generate_passive_reward_offer(&"passive_reward_choice").succeeded, "Seed %d: passive offer B should generate." % seed_value)
		assert_equal(
			JSON.stringify(a.run.pending_reward_offer.to_dictionary()),
			JSON.stringify(b.run.pending_reward_offer.to_dictionary()),
			"Seed %d: the same seed must reproduce a byte-identical passive 3-choice offer (deterministic draw-without-replacement)." % seed_value
		)


# ---- Story 7.1: the GENERATE gold roll + the RESOLVE credit (the T1 wire-off) --------------------

# Find the FIRST seed in `seeds` whose `standard_combat_reward` offer is a GOLD entry; returns the started
# orchestrator (with the gold offer pending) or null if no seed in the set yields gold. A deterministic helper (each
# offer is a pure function of the seed through the named rewards stream).
func _orchestrator_with_gold_offer(seeds: Array[int]) -> RunOrchestrator:
	for seed_value: int in seeds:
		var orchestrator: RunOrchestrator = _started(seed_value)
		assert_true(orchestrator.generate_reward_offer(&"standard_combat_reward").succeeded, "Seed %d: generate should succeed." % seed_value)
		var entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
		if String(entry.get("category")) == "gold":
			return orchestrator
	return null


func _gold_offer_generates_a_rolled_amount_within_the_band_and_resolve_credits_it() -> void:
	# A wide seed scan finds a gold offer (small_gold_purse, band 5..15). GENERATE rolls a CONCRETE amount within the
	# band and stores it on the offer; RESOLVE credits the wallet by exactly that amount, drawing ZERO new RNG.
	var seeds: Array[int] = [1, 2, 3, 4, 5, 7, 13, 42, 99, 2026, 314, 777, 8675309]
	var orchestrator: RunOrchestrator = _orchestrator_with_gold_offer(seeds)
	assert_true(orchestrator != null, "At least one sampled seed must yield a gold offer from standard_combat_reward.")
	var offer: RewardOffer = orchestrator.run.pending_reward_offer
	assert_equal(String((offer.offered_entries[0] as Dictionary).get("content_id")), "small_gold_purse", "The gold offer is the small_gold_purse (band 5..15).")
	# The rolled amount is WITHIN the small_gold_purse band [5, 15] (from the baseline GoldRewardRepository).
	var gold_def = GoldRewardRepository.create_baseline_repository().get_gold_reward(&"small_gold_purse")
	assert_true(offer.gold_amount >= gold_def.gold_min, "The rolled gold (%d) must be >= the band min (%d)." % [offer.gold_amount, gold_def.gold_min])
	assert_true(offer.gold_amount <= gold_def.gold_max, "The rolled gold (%d) must be <= the band max (%d)." % [offer.gold_amount, gold_def.gold_max])
	assert_true(offer.gold_amount > 0, "The rolled gold must be positive (the band min is 5).")

	# RESOLVE credits the wallet by EXACTLY the rolled amount (ZERO new RNG — the amount was rolled at GENERATE).
	var pre_streams: Dictionary = orchestrator.streams.to_snapshot()
	var rolled: int = offer.gold_amount
	var resolved: ActionResult = ResolveRewardCommand.new(&"gold", &"small_gold_purse", 1).execute(orchestrator.run)
	assert_true(resolved.succeeded, "Resolving the gold offer should succeed: %s" % resolved.metadata)
	assert_equal(orchestrator.run.risk_economy.gold, rolled, "RESOLVE must credit the wallet by exactly the GENERATE-rolled amount.")
	assert_equal(orchestrator.streams.to_snapshot(), pre_streams, "RESOLVE must draw ZERO new RNG (the streams are byte-identical).")


func _gold_offer_is_deterministic_for_same_seed() -> void:
	# The rolled gold amount is a deterministic function of the seed (the same seed reproduces the same amount).
	var seeds: Array[int] = [1, 2, 3, 4, 5, 7, 13, 42, 99, 2026, 314, 777, 8675309]
	# Find a gold seed deterministically.
	var gold_seed: int = -1
	for seed_value: int in seeds:
		var probe: RunOrchestrator = _started(seed_value)
		probe.generate_reward_offer(&"standard_combat_reward")
		if String((probe.run.pending_reward_offer.offered_entries[0] as Dictionary).get("category")) == "gold":
			gold_seed = seed_value
			break
	assert_true(gold_seed >= 0, "A gold seed must exist in the sample.")
	var a: RunOrchestrator = _started(gold_seed)
	var b: RunOrchestrator = _started(gold_seed)
	a.generate_reward_offer(&"standard_combat_reward")
	b.generate_reward_offer(&"standard_combat_reward")
	assert_equal(a.run.pending_reward_offer.gold_amount, b.run.pending_reward_offer.gold_amount, "The same seed must roll the SAME concrete gold amount (deterministic).")


func _non_gold_offer_rolls_no_gold() -> void:
	# A NON-gold offer rolls no gold (gold_amount stays 0). Find a seed whose offer is not gold.
	var seeds: Array[int] = [1, 2, 3, 4, 5, 7, 13, 42, 99, 2026]
	var found_non_gold: bool = false
	for seed_value: int in seeds:
		var orchestrator: RunOrchestrator = _started(seed_value)
		orchestrator.generate_reward_offer(&"standard_combat_reward")
		var entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
		if String(entry.get("category")) != "gold":
			found_non_gold = true
			assert_equal(orchestrator.run.pending_reward_offer.gold_amount, 0, "Seed %d: a non-gold offer (%s) must roll NO gold (gold_amount 0)." % [seed_value, String(entry.get("category"))])
	assert_true(found_non_gold, "At least one sampled seed must yield a non-gold offer.")


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
