extends "res://tests/unit/test_case.gd"

# Story 6.1 AC3 — the deterministic reward-offer FIXTURE proving the rewards/loot named-stream contract. The
# RewardOfferBuilder draws a reward offer from an approved RewardTableDefinition through an INJECTED RngStreamSet
# on the named STREAM_REWARDS / STREAM_LOOT. This fixture proves, at the FIXTURE level (a standalone
# RngStreamSet, NOT a live run — the live flow is Story 6.3):
#   (a) DETERMINISM   — same seed + same pre-draw state -> byte-identical offer.
#   (b) DIVERGENCE    — different seeds -> >= 2 distinct outcomes across a small sample (the draw keys off the
#                       stream, not a constant).
#   (c) STREAM PROOF  — the draw's metadata.stream_name == "rewards" / "loot" (the named stream was used, not
#                       another).
#   (d) STATE-REPRO   — after drawing, the stream's post-draw state (snapshot/try_restore round-trip) reproduces
#                       the SAME next draw (the test_run_route_position_save.gd reproduction idiom).
#   (e) NO-RNG-LEAK   — the builder + this fixture contain no randi/randf/RandomNumberGenerator (asserted by
#                       construction here; grep-confirmed at the suite level — Story Task 5.2 (e)).
# The builder ACCEPTS the injected RngStreamSet so Story 6.3 hands it the orchestrator's run-level streams (the
# T2 seam) without reshaping it.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RewardOfferBuilder = preload("res://scripts/content/reward_offer_builder.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")
const RewardTableRepository = preload("res://scripts/content/repositories/reward_table_repository.gd")

const SEED_SAMPLE: Array[int] = [0, 1, 2, 3, 5, 7, 11, 42, 99, 2026]

func run() -> Dictionary:
	_offer_is_deterministic_for_same_seed_and_state()
	_offer_diverges_across_seeds()
	_offer_draws_through_the_named_rewards_stream()
	_offer_draws_through_the_named_loot_stream()
	_post_draw_state_reproduces_the_next_draw()
	_builder_rejects_invalid_inputs_fail_closed()
	_offer_only_selects_real_table_entries()
	return result()


func _baseline_table() -> RewardTableDefinition:
	return RewardTableRepository.create_baseline_repository().get_reward_table(&"standard_combat_reward")


func _offer_is_deterministic_for_same_seed_and_state() -> void:
	var table: RewardTableDefinition = _baseline_table()
	# Two fresh stream sets at the SAME seed (same pre-draw state) must build a BYTE-IDENTICAL offer.
	for seed_value: int in SEED_SAMPLE:
		var first_streams: RngStreamSet = RngStreamSet.new(seed_value)
		var second_streams: RngStreamSet = RngStreamSet.new(seed_value)
		var first: ActionResult = RewardOfferBuilder.new().build_offer(first_streams, RngStreamSet.STREAM_REWARDS, table)
		var second: ActionResult = RewardOfferBuilder.new().build_offer(second_streams, RngStreamSet.STREAM_REWARDS, table)
		assert_true(first.succeeded, "Seed %d: the first offer should build." % seed_value)
		assert_true(second.succeeded, "Seed %d: the second offer should build." % seed_value)
		assert_equal(
			JSON.stringify(first.metadata.get("offer")),
			JSON.stringify(second.metadata.get("offer")),
			"Seed %d: the same seed + same pre-draw state must reproduce a byte-identical offer." % seed_value
		)


func _offer_diverges_across_seeds() -> void:
	# Across the seed sample the builder must produce >= 2 DISTINCT offers (the draw genuinely keys off the
	# stream — it is not a constant).
	var table: RewardTableDefinition = _baseline_table()
	var distinct_offers: Dictionary = {}
	for seed_value: int in SEED_SAMPLE:
		var streams: RngStreamSet = RngStreamSet.new(seed_value)
		var offer: ActionResult = RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_REWARDS, table)
		assert_true(offer.succeeded, "Seed %d: the offer should build." % seed_value)
		distinct_offers[JSON.stringify(offer.metadata.get("offer").get("selected"))] = true
	assert_true(distinct_offers.size() >= 2, "Across the seed sample the offer must diverge (>= 2 distinct selections), proving it keys off the stream.")


func _offer_draws_through_the_named_rewards_stream() -> void:
	var table: RewardTableDefinition = _baseline_table()
	var streams: RngStreamSet = RngStreamSet.new(42)
	var offer: ActionResult = RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_REWARDS, table)
	assert_true(offer.succeeded, "The rewards-stream offer should build.")
	assert_equal(String(offer.metadata.get("stream_name")), "rewards", "The draw must use the named 'rewards' stream (not another).")
	assert_equal(String(offer.metadata.get("offer").get("stream_name")), "rewards", "The offer payload should record the rewards stream.")


func _offer_draws_through_the_named_loot_stream() -> void:
	var table: RewardTableDefinition = _baseline_table()
	var streams: RngStreamSet = RngStreamSet.new(42)
	var offer: ActionResult = RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_LOOT, table)
	assert_true(offer.succeeded, "The loot-stream offer should build.")
	assert_equal(String(offer.metadata.get("stream_name")), "loot", "The draw must use the named 'loot' stream when asked.")


func _post_draw_state_reproduces_the_next_draw() -> void:
	# After building an offer (one draw on the rewards stream), the stream's post-draw state must reproduce the
	# SAME next draw — proving the offer advanced the stream deterministically (the route-position reproduction
	# idiom). Capture the next draw from the LIVE post-offer streams, then from a snapshot/try_restore copy.
	var table: RewardTableDefinition = _baseline_table()
	var streams: RngStreamSet = RngStreamSet.new(2026)
	var offer: ActionResult = RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_REWARDS, table)
	assert_true(offer.succeeded, "The offer should build for the state-reproduction proof.")

	# Snapshot the post-offer streams; the restored copy must reproduce the SAME next rewards draw the live
	# streams produce. (Peek the live next draw from a restored copy so the live streams stay untouched, then
	# compare a second restored copy — both restore the same post-offer state and must agree.)
	var post_offer_snapshot: Dictionary = streams.to_snapshot()
	var copy_a: RngStreamSet = RngStreamSet.new(0)
	assert_true(copy_a.try_restore(post_offer_snapshot).succeeded, "The post-offer snapshot should restore.")
	var copy_b: RngStreamSet = RngStreamSet.new(0)
	assert_true(copy_b.try_restore(post_offer_snapshot).succeeded, "The post-offer snapshot should restore a second time.")
	var draw_a: ActionResult = copy_a.rand_int(RngStreamSet.STREAM_REWARDS, 0, 1000000, {})
	var draw_b: ActionResult = copy_b.rand_int(RngStreamSet.STREAM_REWARDS, 0, 1000000, {})
	assert_true(draw_a.succeeded and draw_b.succeeded, "Both post-restore next draws should succeed.")
	assert_equal(draw_a.metadata.get("value"), draw_b.metadata.get("value"), "The post-offer state must reproduce the SAME next draw (state round-trip).")
	# And the post-offer state_after the builder reported equals the snapshot's restored rewards state.
	assert_equal(draw_a.metadata.get("state_before"), offer.metadata.get("state_after"), "The next draw's state_before must equal the offer's reported post-draw state (the stream advanced exactly one draw).")


func _builder_rejects_invalid_inputs_fail_closed() -> void:
	var table: RewardTableDefinition = _baseline_table()
	var streams: RngStreamSet = RngStreamSet.new(1)
	# Null streams.
	assert_true(RewardOfferBuilder.new().build_offer(null, RngStreamSet.STREAM_REWARDS, table).is_error(), "A null stream set must fail closed.")
	# An off-allowlist stream name (e.g. the map stream) must be rejected — only rewards/loot are allowed.
	var bad_stream: ActionResult = RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_MAP, table)
	assert_true(bad_stream.is_error(), "Drawing a reward offer through a non-rewards/loot stream must fail closed.")
	assert_equal(bad_stream.error_code, &"invalid_offer_stream_name", "An off-allowlist stream name should use the stable code.")
	# Null table.
	assert_true(RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_REWARDS, null).is_error(), "A null table must fail closed.")
	# An invalid (empty) table.
	var empty_table: RewardTableDefinition = RewardTableDefinition.new(&"empty_table", [])
	assert_true(RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_REWARDS, empty_table).is_error(), "An invalid table must fail closed.")


func _offer_only_selects_real_table_entries() -> void:
	# Every built selection must be one of the table's actual entries (no fabricated category/content_id).
	var table: RewardTableDefinition = _baseline_table()
	var entry_keys: Dictionary = {}
	for entry_value: Variant in table.reward_entries():
		var entry: Dictionary = entry_value
		entry_keys["%s/%s" % [String(entry.get("category")), String(entry.get("content_id"))]] = true
	for seed_value: int in SEED_SAMPLE:
		var streams: RngStreamSet = RngStreamSet.new(seed_value)
		var offer: ActionResult = RewardOfferBuilder.new().build_offer(streams, RngStreamSet.STREAM_REWARDS, table)
		assert_true(offer.succeeded, "Seed %d: the offer should build." % seed_value)
		var selected: Dictionary = offer.metadata.get("offer").get("selected")
		var key: String = "%s/%s" % [String(selected.get("category")), String(selected.get("content_id"))]
		assert_true(entry_keys.has(key), "Seed %d: the selected offer (%s) must be a real table entry." % [seed_value, key])
