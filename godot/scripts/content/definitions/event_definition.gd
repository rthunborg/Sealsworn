class_name EventDefinition
extends Resource

# A typed, validated RISK/REWARD EVENT definition (Story 7.3, FR54) — the content-layer truth for a risk/reward node's
# tempting choice (the GDD "Risk/reward events can ask the player to risk HP, curses, gold, future safety, secrets,
# corrupted rewards, sacrificial doors, or elite enemies for stronger outcomes", line 175). It mirrors
# CursedRewardDefinition / GoldRewardDefinition VERBATIM in shape (a DEFINITION_TYPE const, @export fields, an _init
# copying inputs, validate() -> ActionResult returning invalid_event_definition + {reason:"invalid_field", field:...}
# per field, the shared _is_lower_snake_id helper) — an event is a CursedRewardDefinition with a CHOICE LIST + per-choice
# risk flags. It is mirrored from an APPROVED code-constant baseline through the EventRepository boundary (NO JSON
# pipeline — data/source and data/resources stay empty; the Epic-6/7 content-as-code-constant posture).
#
# THE AC1/AC2 EVENT CONTRACT (a risk/reward event offers a readable, tempting CHOICE with KNOWN risks):
#   - event_id:      lower_snake stable id (validated).
#   - display_name:  the evocative human-facing name (non-empty) — feeds the view model.
#   - prompt:        the readable situation the player faces (non-empty — the GDD "tempting choices with known risks";
#                    "the player understands the trade before accepting", lines 461-471).
#   - choices:       a NON-EMPTY Array[EventChoiceDefinition] (>= 1 — an event with no choices is meaningless). Each
#                    choice is a typed sub-resource carrying a UNIQUE lower_snake choice_id, a readable choice_text, and
#                    its REWARD + RISK fields (see EventChoiceDefinition). At LEAST ONE choice must be a GENUINE risk
#                    tradeoff (a reward AND a risk OR a raised flag) so the node is a real decision; a "safe/decline/
#                    leave" choice MAY be offered as an ADDITIONAL option (it raises no risk and grants little/nothing).
#
# validate() rejects fail-loud (never coerce): a non-lower_snake event_id; a blank display_name/prompt; an empty
# choices list; a DUPLICATE choice_id within the event; any per-choice validation error (delegated to
# EventChoiceDefinition.validate(), prefixed with the choice index); AND a NO-GENUINE-TRADEOFF event (no choice is a
# genuine reward+risk tradeoff — the node would be a free reward or a pure penalty, not a decision). The
# at-least-one-tradeoff rule is explicit + tested.
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): a risk flag is a RECORDED player-facing future-danger marker, NOT a
# difficulty knob — nothing here scales enemy stats/HP/damage/rewards/RNG/run length. A risk/reward event is a readable
# player-facing tradeoff plus a recorded flag.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")

const DEFINITION_TYPE := &"event"

@export var event_id: StringName = &""
@export var display_name: String = ""
@export var prompt: String = ""
# The choices the player may take (>= 1; a typed sub-resource list). REJECT empty.
@export var choices: Array[EventChoiceDefinition] = []

func _init(
	new_event_id: StringName = &"",
	new_display_name: String = "",
	new_prompt: String = "",
	new_choices: Array = []
) -> void:
	event_id = new_event_id
	display_name = new_display_name
	prompt = new_prompt
	# Copy the input into a typed Array[EventChoiceDefinition] (a typed @export array assigned an untyped literal at a
	# call site would otherwise mis-type). A non-EventChoiceDefinition entry is kept as null so validate() REJECTS it
	# (do NOT silently drop a malformed entry — the author must fix it).
	var copied_choices: Array[EventChoiceDefinition] = []
	for choice_value: Variant in new_choices:
		copied_choices.append(choice_value as EventChoiceDefinition)
	choices = copied_choices


# Pure read: validate the event id, the display/prompt text, the choice list (non-empty, unique ids, each choice
# valid), and the at-least-one-genuine-tradeoff rule. Returns ok or a per-field invalid_event_definition error.
func validate() -> ActionResult:
	if not _is_lower_snake_id(event_id):
		return _invalid(&"event_id")
	if display_name.strip_edges().is_empty():
		return _invalid(&"display_name")
	if prompt.strip_edges().is_empty():
		return _invalid(&"prompt")
	# An event MUST offer at least one choice (an event with no choices is meaningless — REJECT empty).
	if choices.is_empty():
		return _invalid(&"choices")
	var seen_choice_ids: Dictionary = {}
	var has_genuine_tradeoff: bool = false
	for index: int in range(choices.size()):
		var choice: EventChoiceDefinition = choices[index]
		if choice == null:
			return _invalid_choice(index, &"choice")
		var choice_validation: ActionResult = choice.validate()
		if choice_validation.is_error():
			# Surface the offending field with the choice INDEX (a fabricated/typo'd choice is rejected per-field).
			return _invalid_choice(index, StringName(String(choice_validation.metadata.get("field"))))
		# A duplicate choice_id within the event is rejected (each choice must be uniquely addressable for the
		# choose command — a duplicate id would make the selection ambiguous).
		var choice_id_text: String = String(choice.choice_id)
		if seen_choice_ids.has(choice_id_text):
			return _invalid_choice(index, &"choice_id")
		seen_choice_ids[choice_id_text] = true
		if choice.is_genuine_tradeoff():
			has_genuine_tradeoff = true
	# The at-least-one-genuine-tradeoff rule: the event must offer at least one choice that is a real reward+risk
	# decision (otherwise the node is a free reward or a pure penalty, not a tempting risk/reward choice). A safe
	# "decline" choice is fine as an ADDITIONAL option but cannot be the ONLY one.
	if not has_genuine_tradeoff:
		return _invalid(&"choices")
	return ActionResult.ok()


# Resolve a choice by its id (null on a miss — the choose command fails closed on an off-offer/unknown choice id).
func get_choice(choice_id: StringName) -> EventChoiceDefinition:
	for choice: EventChoiceDefinition in choices:
		if choice != null and choice.choice_id == choice_id:
			return choice
	return null


# The ordered list of this event's choice ids (lower_snake StringNames) — the EventOffer stores this offered set.
func choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice: EventChoiceDefinition in choices:
		if choice != null:
			ids.append(choice.choice_id)
	return ids


static func _is_lower_snake_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text != text.to_lower():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


static func _invalid(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_event_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})


static func _invalid_choice(index: int, field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_event_definition", {
		"reason": "invalid_choice",
		"choice_index": index,
		"field": String(field_name)
	})
