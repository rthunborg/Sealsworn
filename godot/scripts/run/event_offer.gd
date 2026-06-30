class_name EventOffer
extends RefCounted

# The PENDING risk/reward EVENT OFFER (Story 7.3) — a scene-free, SERIALIZABLE value object recorded on RunState
# (alongside inventory / starting_kit / pending_reward_offer / risk_economy) that holds ONE generated-but-unresolved
# event offer until it is resolved. It is the AC1 "offers a deterministic event choice" run-domain surface: the OFFER
# (which event + which choices appear) is ROLLED ONCE at GENERATE time (the only RNG draw, through the run-level
# RngStreamSet on the `events` stream via RunOrchestrator.generate_event_offer) and STORED here as `pending`; the
# ChooseEventOptionCommand applies the chosen choice (deterministically — no new draw, the choice amounts are AUTHORED
# on the definition) and flips this to `resolved`. A second choose against a `resolved` offer fails closed (AC3
# no-double-apply).
#
# IT IS SERIALIZABLE DATA ONLY (mirroring RewardOffer): it stores the offered event id, the offered choice ids, the
# SELECTED choice id (set on resolve), the draw provenance (stream_name / roll / draw_index / state_after from the
# orchestrator's draw metadata), and a pending/resolved status. It NEVER holds a live EventDefinition / RngStreamSet /
# Resource — those are NOT in the run dict. The offered-choice-ids list is a plain Array of plain Strings (the
# project-context "metadata-carried lists are plain" rule — this object normalizes whatever it is handed into clean
# plain strings).
#
# Mirrors RewardOffer's exact-key to_dictionary() contract (a key never silently appears/vanishes — the key set is
# pinned by test_event_offer.gd), the lenient try_from_dictionary (a value object, no reject path — a partial/legacy
# dict defaults cleanly), and the deep copy() (the offered-choice-ids list must NOT be shared by reference). It is
# DELIBERATELY NOT serialized into the route-position RunSnapshot (the offer rides only the FULL
# RunState.to_dictionary()/try_from_dictionary — the 6.3 RewardOffer posture VERBATIM); it carries NO new top-level
# snapshot key.

# The two stable offer statuses (lower_snake). An offer is born `pending` and flips to `resolved` exactly once.
const STATUS_PENDING := &"pending"
const STATUS_RESOLVED := &"resolved"

const STATUSES: Array[StringName] = [
	STATUS_PENDING,
	STATUS_RESOLVED
]

# The stable key set of to_dictionary() (pinned by test). A key never silently appears or vanishes.
const DICTIONARY_KEYS: Array[String] = [
	"event_id",
	"status",
	"offered_choice_ids",
	"selected_choice_id",
	"stream_name",
	"roll",
	"draw_index",
	"state_after"
]

# The event the offer was drawn from (lower_snake). A by-id reference only — the definition itself is NOT stored.
var event_id: StringName = &""
# pending until resolved; resolved after a successful ChooseEventOptionCommand. Anything else resolves to pending.
var status: StringName = STATUS_PENDING
# The offered choice ids (the event's choice set the player may pick from). A plain Array of plain Strings.
var offered_choice_ids: Array = []
# The SELECTED choice id (empty until resolve). Set by ChooseEventOptionCommand on success.
var selected_choice_id: StringName = &""
# The named stream the draw advanced (events) — provenance only.
var stream_name: String = ""
# The draw roll (the selection roll the orchestrator reported) — provenance only. A non-negative int.
var roll: int = 0
# The draw index the offer advanced the stream to (the orchestrator's draw_index) — provenance only. A non-negative int.
var draw_index: int = 0
# The post-draw stream state (the orchestrator's state_after) — provenance only. A full int64 (decimal-string encoded
# in to_dictionary() so it survives JSON, mirroring the RngStreamSet/RewardOffer seed discipline).
var state_after: int = 0

func _init(
	new_event_id: StringName = &"",
	new_status: StringName = STATUS_PENDING,
	new_offered_choice_ids: Array = [],
	new_selected_choice_id: StringName = &"",
	new_stream_name: String = "",
	new_roll: int = 0,
	new_draw_index: int = 0,
	new_state_after: int = 0
) -> void:
	event_id = new_event_id
	status = new_status if STATUSES.has(new_status) else STATUS_PENDING
	offered_choice_ids = _normalize_choice_ids(new_offered_choice_ids)
	selected_choice_id = new_selected_choice_id
	stream_name = new_stream_name
	roll = new_roll if new_roll >= 0 else 0
	draw_index = new_draw_index if new_draw_index >= 0 else 0
	state_after = new_state_after


func is_pending() -> bool:
	return status == STATUS_PENDING


func is_resolved() -> bool:
	return status == STATUS_RESOLVED


# Whether `choice_id` is one of the offered choice ids. Used by the choose command to reject a selection that is not
# actually on the offer (AC2/AC3 — only an offered choice can be resolved).
func has_offered_choice(choice_id: StringName) -> bool:
	return offered_choice_ids.has(String(choice_id))


# Exact-key serialization (the RewardOffer precedent). state_after is a full int64 (NOT a small bounded int) so it is
# decimal-string encoded (JSON-double-safe). A FRESH dictionary (with a deep-copied choice-id list) is returned each
# call so a mutation of the returned dict never perturbs the model.
func to_dictionary() -> Dictionary:
	return {
		"event_id": String(event_id),
		"status": String(status),
		"offered_choice_ids": offered_choice_ids.duplicate(),
		"selected_choice_id": String(selected_choice_id),
		"stream_name": stream_name,
		"roll": roll,
		"draw_index": draw_index,
		# Full int64 -> decimal string (survives JSON; read back leniently as int / integral-float / string).
		"state_after": str(state_after)
	}


# Lenient reconstruction (mirrors RewardOffer.try_from_dictionary leniency): a missing/invalid field defaults cleanly
# so a partial/legacy dict still parses. Returns an EventOffer (never null) — a value object, not a validated domain
# entity, so it has no reject path.
static func try_from_dictionary(data: Dictionary) -> EventOffer:
	return load("res://scripts/run/event_offer.gd").new(
		StringName(String(data.get("event_id", ""))),
		StringName(String(data.get("status", STATUS_PENDING))),
		data.get("offered_choice_ids", []),
		StringName(String(data.get("selected_choice_id", ""))),
		String(data.get("stream_name", "")),
		_int_or_zero(data.get("roll", 0)),
		_int_or_zero(data.get("draw_index", 0)),
		_int64_or_zero(data.get("state_after", 0))
	)


# Deep copy (the offered-choice-ids list is deep-copied so a copy never shares mutable state with the source —
# mutating the copy's list must not perturb the source).
func copy() -> EventOffer:
	return load("res://scripts/run/event_offer.gd").new(
		event_id,
		status,
		offered_choice_ids,
		selected_choice_id,
		stream_name,
		roll,
		draw_index,
		state_after
	)


# Normalize an arbitrary offered-choice-ids input into a clean Array of plain non-empty Strings (drop blanks /
# non-strings; dedup is NOT applied — the offered set mirrors the definition's choice order, which the parent
# definition already guarantees is unique). Deep-copies (no shared reference with the input).
static func _normalize_choice_ids(raw: Variant) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for value: Variant in (raw as Array):
		if not (value is String or value is StringName):
			continue
		var text: String = String(value)
		if text.is_empty():
			continue
		result.append(text)
	return result


# Lenient small-int decode (roll / draw_index): accept an int / integral-float / decimal-string, else 0.
static func _int_or_zero(value: Variant) -> int:
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


# Lenient int64 decode (state_after): accept an int / integral-float / decimal-string (the int64-safe wire form),
# else 0. Mirrors the RngStreamSet/RewardOffer seed decode.
static func _int64_or_zero(value: Variant) -> int:
	return _int_or_zero(value)
