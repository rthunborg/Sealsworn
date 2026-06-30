class_name EventViewModel
extends RefCounted

# Story 7.3 — the scene-free RISK/REWARD EVENT VIEW MODEL (FR54, AC1). It is the thin presentation contract the (future)
# event modal SCENE reads: it PROJECTS a risk/reward event (resolved through EventRepository) into serializable modal
# data with an EXACT pinned key contract — a key never silently appears/vanishes (the CursedRewardViewModel exact-key
# discipline; a test pins MODAL_KEYS + CHOICE_KEYS). It surfaces the AC1 contract BEFORE choosing: the event's prompt
# (the readable situation), and — per CHOICE — the readable choice_text + the concrete reward amounts + the concrete risk
# amounts + the raised risk-flag ids, surfaced honestly so "the player understands the trade before accepting" (GDD lines
# 461-471).
#
# It is the direct sibling of CursedRewardViewModel (the 7.2 read surface): same posture, same fail-closed discipline,
# for EventDefinition (a multi-CHOICE definition) instead of CursedRewardDefinition (a single tradeoff).
#
# WHAT IT IS:
#   - project_event(event_id) -> a Dictionary keyed by MODAL_KEYS surfacing the event's display fields + a `choices`
#     Array of per-choice dicts (each keyed by CHOICE_KEYS). It reads the event through EventRepository.get_event(id) —
#     never FileAccess / load() / JSON.parse in a hot path.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws NO RNG, and mutates nothing — it is a PURE read of approved
#     static content. It does NOT submit the choose command itself (the command bridge / a later HUD story owns the
#     choose call site — the SAME residual the cursed-reward modal left).
#   - It is a RefCounted DTO — NOT a Control, NOT a Node, NOT a .tscn / scene / presenter / icon ART (the UI-scene-last
#     rule; the real modal scene is a later HUD story). This is the data contract.
#
# FAIL-CLOSED (the CursedRewardViewModel._identity_absent_modal discipline): an unresolved event id (null get_event)
# projects an identity-ABSENT modal — the SAME MODAL_KEYS set, empty/default values, an EMPTY choices list,
# has_event == false — never a crash, never a half-entry. A consumer branches on has_event without inspecting the empty
# fields.

const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")

# The EXACT top-level key set of every projection (the MODAL_KEYS exact-key discipline). has_event gates whether the
# other fields are meaningful.
const MODAL_KEYS: Array[String] = [
	"has_event",
	"event_id",
	"display_name",
	"prompt",
	"choices"
]

# The EXACT per-choice key set (each entry in the `choices` Array). Surfaces the AC1 readable choice + its concrete
# reward/risk amounts + the raised risk-flag ids BEFORE the player picks.
const CHOICE_KEYS: Array[String] = [
	"choice_id",
	"choice_text",
	"gold_benefit",
	"healing_benefit",
	"curse_increment",
	"corruption_increment",
	"gold_cost",
	"healing_cost",
	"risk_flags",
	"is_genuine_tradeoff",
	"is_safe"
]

var _event_repository: EventRepository = null

func _init(new_event_repository: EventRepository = null) -> void:
	# Default to the baseline event repository (the CursedRewardViewModel injection posture; tests inject a fixture
	# repository). Resolves the event's modal fields through get_event(id).
	_event_repository = new_event_repository if new_event_repository != null else EventRepository.create_baseline_repository()


# Project an event by its id into the EXACT-MODAL_KEYS modal dict. An unresolved id (null get_event) projects the
# identity-absent modal (fail-closed). PURE read: no RNG, no mutation.
func project_event(event_id: StringName) -> Dictionary:
	var definition: EventDefinition = _event_repository.get_event(event_id)
	if definition == null:
		return _identity_absent_modal()
	return _project(definition)


# The present-event projection: plain String/int/bool/Array data only (no live EventDefinition/EventChoiceDefinition
# handle leaks out — the CursedRewardViewModel._project discipline).
func _project(definition: EventDefinition) -> Dictionary:
	var choices: Array = []
	for choice: EventChoiceDefinition in definition.choices:
		if choice == null:
			continue
		choices.append(_project_choice(choice))
	return {
		"has_event": true,
		"event_id": String(definition.event_id),
		"display_name": definition.display_name,
		"prompt": definition.prompt,
		"choices": choices
	}


# A single choice's present projection (the AC1 readable trade): the choice_text + the concrete reward amounts + the
# concrete risk amounts + the raised risk-flag ids (plain Strings).
func _project_choice(choice: EventChoiceDefinition) -> Dictionary:
	var flags: Array = []
	for flag_value: Variant in choice.risk_flags:
		flags.append(String(flag_value))
	return {
		"choice_id": String(choice.choice_id),
		"choice_text": choice.choice_text,
		# The REWARD side (AC1): the concrete benefit amounts.
		"gold_benefit": choice.gold_benefit,
		"healing_benefit": choice.healing_benefit,
		# The RISK side (AC1): the concrete risk amounts + any resource cost.
		"curse_increment": choice.curse_increment,
		"corruption_increment": choice.corruption_increment,
		"gold_cost": choice.gold_cost,
		"healing_cost": choice.healing_cost,
		# The raised risk-flag ids (the AC2 future-danger record, surfaced honestly BEFORE choosing).
		"risk_flags": flags,
		# Readability helpers: whether this choice is a genuine tradeoff vs a safe decline.
		"is_genuine_tradeoff": choice.is_genuine_tradeoff(),
		"is_safe": choice.is_safe()
	}


# The identity-absent projection (an unresolved/null input): the SAME MODAL_KEYS set, empty/default values, an EMPTY
# choices list, has_event == false so a consumer can branch without inspecting the empty fields.
func _identity_absent_modal() -> Dictionary:
	return {
		"has_event": false,
		"event_id": "",
		"display_name": "",
		"prompt": "",
		"choices": []
	}
