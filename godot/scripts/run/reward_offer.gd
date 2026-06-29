class_name RewardOffer
extends RefCounted

# The PENDING reward OFFER (Story 6.3) — a scene-free, SERIALIZABLE value object recorded on RunState (alongside
# inventory / starting_kit / rules_resolver) that holds ONE generated-but-unresolved reward offer until it is
# resolved. It is the AC1 "the offer is stored in DOMAIN STATE until resolved" run-domain surface: the reward is
# ROLLED ONCE at GENERATE time (the only RNG draw, through the run-level RngStreamSet via RewardOfferBuilder) and
# STORED here as `pending`; the ResolveRewardCommand applies the chosen entry (deterministically — no new draw)
# and flips this to `resolved`. A second resolve against a `resolved` offer fails closed (AC3 no-double-apply).
#
# IT IS SERIALIZABLE DATA ONLY (mirroring InventoryState / StartingKit): it stores the table id, the offered
# {category, content_id} entries, the SELECTED entry (set on resolve), the draw provenance (roll / draw_index /
# state_after from the builder's metadata), and a pending/resolved status. It NEVER holds a live
# RewardTableDefinition / RngStreamSet / Resource — those are NOT in the run dict. The offered-entries list is a
# plain Array of plain Dictionaries (project-context "metadata-carried dictionary lists" rule — Array[Dictionary]
# does not survive ActionResult metadata deep-copy, so an offer built from a generate-result's metadata must be
# received as untyped Array; this object normalizes whatever it is handed into clean plain dicts).
#
# Mirrors InventoryState's exact-key to_dictionary() contract (a key never silently appears/vanishes — the key
# set is pinned by test_reward_offer.gd), the lenient try_from_dictionary (a value object, no reject path — a
# partial/legacy dict defaults cleanly), and the deep copy() (the offered-entries list + selected dict must NOT
# be shared by reference). It is DELIBERATELY NOT serialized into the route-position RunSnapshot this story (the
# offer rides only the FULL RunState.to_dictionary()/try_from_dictionary); it carries NO new top-level snapshot
# key.

# The two stable offer statuses (lower_snake). An offer is born `pending` and flips to `resolved` exactly once.
const STATUS_PENDING := &"pending"
const STATUS_RESOLVED := &"resolved"

const STATUSES: Array[StringName] = [
	STATUS_PENDING,
	STATUS_RESOLVED
]

# The per-offered-entry dictionary keys (pinned; a key never silently appears/vanishes — test-asserted).
const ENTRY_KEYS: Array[String] = [
	"category",
	"content_id"
]

# The stable key set of to_dictionary() (pinned by test). A key never silently appears or vanishes.
const DICTIONARY_KEYS: Array[String] = [
	"table_id",
	"status",
	"offered_entries",
	"selected_entry",
	"stream_name",
	"roll",
	"draw_index",
	"state_after",
	"gold_amount"
]

# The reward table the offer was drawn from (lower_snake). A by-id reference only — the table itself is NOT stored.
var table_id: StringName = &""
# pending until resolved; resolved after a successful ResolveRewardCommand. Anything else resolves to pending.
var status: StringName = STATUS_PENDING
# The offered {category, content_id} entries (one for a standard reward; three distinct for an AC4 passive
# 3-choice moment). A plain Array of plain Dictionaries.
var offered_entries: Array = []
# The SELECTED {category, content_id} entry (empty until resolve). Set by ResolveRewardCommand on success.
var selected_entry: Dictionary = {}
# The named stream the draw advanced (rewards / loot) — provenance only.
var stream_name: String = ""
# The draw roll (the weighted-pick roll the builder reported) — provenance only. A non-negative int.
var roll: int = 0
# The draw index the offer advanced the stream to (the builder's draw_index) — provenance only. A non-negative int.
var draw_index: int = 0
# The post-draw stream state (the builder's state_after) — provenance only. A full int64 (decimal-string encoded
# in to_dictionary() so it survives JSON, mirroring the RngStreamSet/RunState seed discipline).
var state_after: int = 0
# Story 7.1: the CONCRETE gold amount rolled at GENERATE time when this offer's selected entry is a GOLD reward (the
# GoldRewardDefinition declares a gold_min..gold_max BAND, NOT a fixed amount — Epic 6 never rolled it, leaving gold
# outcome-record-only). The orchestrator rolls gold_min..gold_max via the run-level rewards/loot stream ALONGSIDE the
# offer draw and stores the concrete amount HERE, so ResolveRewardCommand credits the wallet by exactly this amount
# DETERMINISTICALLY (drawing ZERO new RNG on resolve — the Epic-6 zero-new-RNG-on-resolve invariant holds). A
# non-gold offer rolls no gold (this stays 0). A small bounded NON-NEGATIVE int (NOT a seed — no decimal-string
# encoding; the 5.3/6.2 baseline_hp/capacity precedent).
var gold_amount: int = 0

func _init(
	new_table_id: StringName = &"",
	new_status: StringName = STATUS_PENDING,
	new_offered_entries: Array = [],
	new_selected_entry: Dictionary = {},
	new_stream_name: String = "",
	new_roll: int = 0,
	new_draw_index: int = 0,
	new_state_after: int = 0,
	new_gold_amount: int = 0
) -> void:
	table_id = new_table_id
	status = new_status if STATUSES.has(new_status) else STATUS_PENDING
	offered_entries = _normalize_entries(new_offered_entries)
	selected_entry = _normalize_entry_or_empty(new_selected_entry)
	stream_name = new_stream_name
	roll = new_roll if new_roll >= 0 else 0
	draw_index = new_draw_index if new_draw_index >= 0 else 0
	state_after = new_state_after
	gold_amount = new_gold_amount if new_gold_amount >= 0 else 0


func is_pending() -> bool:
	return status == STATUS_PENDING


func is_resolved() -> bool:
	return status == STATUS_RESOLVED


# Whether `entry` (a {category, content_id} pair) is one of the offered entries. Used by the resolve command to
# reject a selection that is not actually on the offer (AC2/AC3 — only an offered entry can be resolved).
func has_offered_entry(category: StringName, content_id: StringName) -> bool:
	for entry_value: Variant in offered_entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if StringName(String(entry.get("category"))) == category \
				and StringName(String(entry.get("content_id"))) == content_id:
			return true
	return false


# Exact-key serialization (the InventoryState / StartingKit precedent). state_after is a full int64 (NOT a small
# bounded int) so it is decimal-string encoded (JSON-double-safe, mirroring RngStreamSet.to_snapshot()). A FRESH
# dictionary (with deep-copied entries) is returned each call so a mutation of the returned dict never perturbs
# the model.
func to_dictionary() -> Dictionary:
	var entries_copy: Array = []
	for entry_value: Variant in offered_entries:
		if entry_value is Dictionary:
			entries_copy.append((entry_value as Dictionary).duplicate(true))
	return {
		"table_id": String(table_id),
		"status": String(status),
		"offered_entries": entries_copy,
		"selected_entry": selected_entry.duplicate(true),
		"stream_name": stream_name,
		"roll": roll,
		"draw_index": draw_index,
		# Full int64 -> decimal string (survives JSON; read back leniently as int / integral-float / string).
		"state_after": str(state_after),
		# Story 7.1: the rolled concrete gold amount (a small bounded int, NOT a seed — stays numeric, no
		# decimal-string encoding). 0 for a non-gold offer.
		"gold_amount": gold_amount
	}


# Lenient reconstruction (mirrors InventoryState.try_from_dictionary leniency): a missing/invalid field defaults
# cleanly so a partial/legacy dict still parses. Returns a RewardOffer (never null) — a value object, not a
# validated domain entity, so it has no reject path.
static func try_from_dictionary(data: Dictionary) -> RewardOffer:
	return load("res://scripts/run/reward_offer.gd").new(
		StringName(String(data.get("table_id", ""))),
		StringName(String(data.get("status", STATUS_PENDING))),
		data.get("offered_entries", []),
		data.get("selected_entry", {}),
		String(data.get("stream_name", "")),
		_int_or_zero(data.get("roll", 0)),
		_int_or_zero(data.get("draw_index", 0)),
		_int64_or_zero(data.get("state_after", 0)),
		# Story 7.1: lenient gold_amount decode (a small bounded int; a pre-7.1 offer dict has no gold_amount key -> 0).
		_int_or_zero(data.get("gold_amount", 0))
	)


# Deep copy (the offered-entries list + selected dict are deep-copied so a copy never shares mutable state with
# the source — mutating the copy's entries must not perturb the source).
func copy() -> RewardOffer:
	return load("res://scripts/run/reward_offer.gd").new(
		table_id,
		status,
		offered_entries,
		selected_entry,
		stream_name,
		roll,
		draw_index,
		state_after,
		gold_amount
	)


# Normalize an arbitrary offered-entries input into a clean Array of plain {category, content_id} dicts. Each
# entry that is a Dictionary is reshaped to EXACTLY the pinned entry keys (category + content_id as plain
# Strings); a non-dict entry is skipped. This both deep-copies (no shared reference) and guarantees the entry
# shape so a round-tripped/metadata-carried list can never inject a surprise key.
static func _normalize_entries(raw: Variant) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for entry_value: Variant in (raw as Array):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		result.append({
			"category": String(entry.get("category", "")),
			"content_id": String(entry.get("content_id", ""))
		})
	return result


# Normalize a single selected-entry input: a {category, content_id} dict -> a clean plain dict; an empty/non-dict
# (or one missing either key) -> an empty dict (no selection). Deep-copies.
static func _normalize_entry_or_empty(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var entry: Dictionary = raw as Dictionary
	if not entry.has("category") or not entry.has("content_id"):
		return {}
	var category: String = String(entry.get("category", ""))
	var content_id: String = String(entry.get("content_id", ""))
	if category.is_empty() or content_id.is_empty():
		return {}
	return {
		"category": category,
		"content_id": content_id
	}


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
# else 0. Mirrors the RngStreamSet/RunState seed decode.
static func _int64_or_zero(value: Variant) -> int:
	return _int_or_zero(value)
