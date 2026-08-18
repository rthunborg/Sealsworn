class_name EventOutcomeViewModel
extends RefCounted

# Story 15.5 (AC3) — the scene-free EVENT-OUTCOME VIEW MODEL (FR54, NFR9). It is the thin presentation contract the
# event-node outcome SURFACE reads AFTER the player picks a choice: it PROJECTS a resolved risk/reward event into
# serializable "what changed" data with an EXACT pinned key contract (OUTCOME_KEYS — a key never silently appears/
# vanishes; a test pins it). It surfaces the AC3 contract: the concrete gold/healing/curse/corruption BEFORE/AFTER
# deltas + the raised risk-flag ids, so the player is "shown what happened and what changed before returning to the
# route" — an event node NEVER resolves invisibly into a route-screen counter increment.
#
# ⭐ IT READS THE EVENT NODE'S EXISTING RESOLUTION DATA (AC3 — "no new domain data invented"). Its source is the
# ChooseEventOptionCommand result metadata (choose_event_option_command.gd:271-285: event_id / choice_id / risk_flags /
# gold_before/after / healing_before/after / curse_before/after / corruption_before/after / applies_curse) — surfaced
# either straight off that command result OR off RunOrchestrator.resolve_event_node_live's merged result (the SAME keys).
# It computes the signed DELTAS (after - before) so the surface reads "Gold +25, Curse +1" honestly. It is the direct
# sibling of EventViewModel (the BEFORE-choice modal projection); this is the AFTER-choice outcome projection.
#
# ⭐ IT IS A PURE READ: it owns NO domain truth, submits NO command, draws NO RNG, and mutates nothing. It is a
# RefCounted DTO — NOT a Control / Node / .tscn (the UI-scene-last rule; the real outcome surface is the event-node
# overlay verified by construction + the compile guardrail). This is the data contract the overlay maps to Labels.
#
# ⭐ FAIL-CLOSED (the EventViewModel._identity_absent discipline): a null / error / non-resolving result projects the
# identity-ABSENT outcome — the SAME OUTCOME_KEYS set, empty/zero values, has_outcome == false — never a crash, never a
# half-entry. A consumer branches on has_outcome without inspecting the empty fields. A SAFE / decline choice (a zero-net
# tradeoff) still projects has_outcome == true with all-zero deltas + no flags (the honest "you chose safely — nothing
# changed", NOT rendered as a bare empty result — AC4's honesty requirement applied to the event surface).

const ActionResult = preload("res://scripts/core/results/action_result.gd")

# The EXACT top-level key set of every projection (the exact-key discipline — a key never silently appears/vanishes;
# pinned by test_event_outcome_view_model.gd). has_outcome gates whether the other fields are meaningful.
const OUTCOME_KEYS: Array[String] = [
	"has_outcome",
	"event_id",
	"choice_id",
	"gold_before",
	"gold_after",
	"gold_delta",
	"healing_before",
	"healing_after",
	"healing_delta",
	"curse_before",
	"curse_after",
	"curse_delta",
	"corruption_before",
	"corruption_after",
	"corruption_delta",
	"risk_flags",
	"applies_curse"
]

# Whether a resolved event outcome is present (a real applied choice). A null / error / non-event result -> false.
var has_outcome: bool = false
var event_id: String = ""
var choice_id: String = ""
var gold_before: int = 0
var gold_after: int = 0
var healing_before: int = 0
var healing_after: int = 0
var curse_before: int = 0
var curse_after: int = 0
var corruption_before: int = 0
var corruption_after: int = 0
# The raised risk-flag ids (plain Strings, in declared order) — the AC2/AC3 "future danger" record surfaced honestly.
var risk_flags: Array = []
# Whether the chosen choice applied a curse/corruption increment (the surface highlights the curse side when true).
var applies_curse: bool = false


# Build the outcome projection from a resolved-event ActionResult (the ChooseEventOptionCommand result OR the
# RunOrchestrator.resolve_event_node_live result — both carry the SAME outcome metadata keys). A null / errored result
# projects the identity-absent outcome (fail-closed). PURE read: no RNG, no mutation.
static func from_result(result: ActionResult) -> EventOutcomeViewModel:
	if result == null or result.is_error():
		return _identity_absent()
	return from_metadata(result.metadata)


# Build directly from the outcome METADATA dict (the ChooseEventOptionCommand / resolve_event_node_live result
# metadata). A non-dict / event-id-less metadata projects the identity-absent outcome (fail-closed — never a half-entry).
static func from_metadata(metadata: Dictionary) -> EventOutcomeViewModel:
	if not metadata.has("event_id"):
		return _identity_absent()
	var view_model: EventOutcomeViewModel = EventOutcomeViewModel.new()
	view_model.has_outcome = true
	view_model.event_id = String(metadata.get("event_id", ""))
	view_model.choice_id = String(metadata.get("choice_id", ""))
	view_model.gold_before = int(metadata.get("gold_before", 0))
	view_model.gold_after = int(metadata.get("gold_after", 0))
	view_model.healing_before = int(metadata.get("healing_before", 0))
	view_model.healing_after = int(metadata.get("healing_after", 0))
	view_model.curse_before = int(metadata.get("curse_before", 0))
	view_model.curse_after = int(metadata.get("curse_after", 0))
	view_model.corruption_before = int(metadata.get("corruption_before", 0))
	view_model.corruption_after = int(metadata.get("corruption_after", 0))
	view_model.risk_flags = _string_array(metadata.get("risk_flags", []))
	view_model.applies_curse = bool(metadata.get("applies_curse", false))
	return view_model


# The exact-key projection (the EventViewModel exact-key discipline): plain String/int/bool/Array data only (no live
# handle leaks out). A FRESH dict each call (the risk_flags list is a fresh copy) so a caller's mutation never perturbs
# this DTO. The signed deltas (after - before) are computed here so the surface reads "Gold +25 / Curse +1" honestly.
func to_dictionary() -> Dictionary:
	return {
		"has_outcome": has_outcome,
		"event_id": event_id,
		"choice_id": choice_id,
		"gold_before": gold_before,
		"gold_after": gold_after,
		"gold_delta": gold_after - gold_before,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"healing_delta": healing_after - healing_before,
		"curse_before": curse_before,
		"curse_after": curse_after,
		"curse_delta": curse_after - curse_before,
		"corruption_before": corruption_before,
		"corruption_after": corruption_after,
		"corruption_delta": corruption_after - corruption_before,
		"risk_flags": risk_flags.duplicate(),
		"applies_curse": applies_curse
	}


# Whether the outcome is a zero-net SAFE choice (no gold/healing/curse/corruption change AND no raised flags). The
# surface uses this to render an honest "you chose safely — nothing changed" rather than a bare empty result (AC4's
# honesty requirement applied to the event outcome: an empty result must never read as "you got nothing" by accident).
func is_safe_outcome() -> bool:
	if not has_outcome:
		return false
	return gold_after == gold_before \
		and healing_after == healing_before \
		and curse_after == curse_before \
		and corruption_after == corruption_before \
		and risk_flags.is_empty()


# The identity-absent projection (a null / errored / non-event result): the SAME OUTCOME_KEYS set, empty/zero values,
# has_outcome == false so a consumer branches without inspecting the empty fields.
static func _identity_absent() -> EventOutcomeViewModel:
	return EventOutcomeViewModel.new()


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
