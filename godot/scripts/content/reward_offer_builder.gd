class_name RewardOfferBuilder
extends RefCounted

# A PURE, deterministic reward-offer builder (Story 6.1, AC3). GIVEN an INJECTED RngStreamSet + a stream name
# (STREAM_REWARDS or STREAM_LOOT) + a RewardTableDefinition, it draws a deterministic offer by weighted-picking
# an entry from the table, and returns a serializable offer dict inside an ActionResult.
#
# DETERMINISM + STREAM CONTRACT: it draws EXCLUSIVELY through the injected set's rand_int on the named stream.
# It NEVER mints a RandomNumberGenerator, NEVER calls randi()/randf(), NEVER touches another stream. So the same
# seed + same pre-draw stream state reproduce a byte-identical offer, and a different seed diverges. The draw's
# ActionResult metadata (stream_name / draw_index / state_before / state_after) is surfaced on the offer result
# so a caller/test can assert the named stream was used and reproduce the next draw.
#
# THE INJECTED-SET SEAM (T2, owner Story 6.3 — NOT 6.1): the builder ACCEPTS the RngStreamSet it draws through
# rather than minting its own. Story 6.1 proves the contract at the FIXTURE level (a standalone RngStreamSet in
# a test); Story 6.3 (the first LIVE reward roll through the run) hands this same builder the orchestrator's
# run-level `streams` so the route-position save persists the stream the offer actually advanced — WITHOUT
# reshaping this builder. Do NOT fork a parallel offer path in 6.3; extend this one.
#
# It is a PURE read of the table + a single draw through the handed-in stream: no global state, no save, no
# command, no mutation of the table.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")

# The streams a reward/loot offer is allowed to draw through (AC3 — the reserved named streams).
const ALLOWED_STREAMS: Array[StringName] = [
	RngStreamSet.STREAM_REWARDS,
	RngStreamSet.STREAM_LOOT
]

# Build a single deterministic reward offer from `table`, drawing through `streams` on `stream_name`. Returns
# an ActionResult: on success metadata.offer is the serializable offer dict and metadata carries the draw's
# stream_name/draw_index/state_before/state_after; on failure a structured error (never a crash / a fabricated
# default).
func build_offer(streams: RngStreamSet, stream_name: StringName, table: RewardTableDefinition) -> ActionResult:
	if streams == null:
		return _error(&"invalid_offer_streams")
	if not ALLOWED_STREAMS.has(stream_name):
		return _error(&"invalid_offer_stream_name")
	if table == null:
		return _error(&"invalid_offer_table")
	var table_validation: ActionResult = table.validate()
	if table_validation.is_error():
		return _error(&"invalid_offer_table")

	var entries: Array = table.reward_entries()
	var total_weight: int = table.total_weight()
	if total_weight <= 0:
		return _error(&"invalid_offer_table")

	# Weighted pick: draw a roll in [0, total_weight - 1] through the named stream, then walk the cumulative
	# weight bands to select the entry. Deterministic per (seed, pre-draw state).
	var draw: ActionResult = streams.rand_int(stream_name, 0, total_weight - 1, {"consumer": "reward_offer_builder"})
	if draw.is_error():
		return draw
	var roll: int = int(draw.metadata.get("value"))

	var selected: Dictionary = {}
	var cumulative: int = 0
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		cumulative += int(entry.get("weight"))
		if roll < cumulative:
			selected = {
				"category": String(entry.get("category")),
				"content_id": String(entry.get("content_id"))
			}
			break

	if selected.is_empty():
		# Unreachable when total_weight is correct, but never fabricate a default — fail closed.
		return _error(&"offer_selection_failed")

	var offer: Dictionary = {
		"table_id": String(table.table_id),
		"stream_name": String(draw.metadata.get("stream_name")),
		"roll": roll,
		"selected": selected
	}
	return ActionResult.ok([], {
		"offer": offer,
		"stream_name": draw.metadata.get("stream_name"),
		"draw_index": draw.metadata.get("draw_index"),
		"state_before": draw.metadata.get("state_before"),
		"state_after": draw.metadata.get("state_after")
	})


static func _error(code: StringName) -> ActionResult:
	return ActionResult.error(code, {"reason": "invalid_offer"})
