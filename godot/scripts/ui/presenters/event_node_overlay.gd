class_name EventNodeOverlay
extends Control

# Story 15.5 (AC3) — the EVENT-NODE choice/outcome SURFACE. The route map opens THIS overlay when the player picks an
# `event` node, so the node PRESENTS its risk/reward offer, the player CHOOSES, and the outcome (gold/healing/curse/
# corruption deltas + raised risk flags) is SHOWN before returning to the route — an event node NEVER resolves invisibly
# into a route-screen counter increment (the finding this story closes). It is thin glue over the testable seams:
#   - RunOrchestrator.generate_event_offer (the LIVE `events`-stream roll — live-only, so no fingerprint moves),
#   - EventViewModel (the BEFORE-choice modal projection — the prompt + the concrete trade per choice),
#   - RunOrchestrator.resolve_event_node_live (apply the pick via ChooseEventOptionCommand + clear/exit the node),
#   - EventOutcomeViewModel (the AFTER-choice outcome projection — the deltas + flags, exact-key + unit-tested).
#
# ⭐ NO-SOFT-LOCK PARTITION (the 14.6 posture): an event node ALWAYS resolves. A rejected choice (insufficient resource /
# an off-offer pick) fails closed with a VISIBLE cue and RE-SHOWS the choices — the offer stays pending, so a decline
# (always affordable) is re-pickable; never a silent stall. If the offer cannot even be GENERATED (an empty repo — not
# expected in production), the overlay falls OPEN to the placeholder resolve so the node still clears (a diagnostic cue,
# no soft-lock).
#
# ⭐ Verified BY CONSTRUCTION (the compile guardrail loads this alongside the presenters that preload it); on-screen
# legibility at the 2.0x text scale + >=44px targets is OSG-1. The testable DECISIONS live in EventViewModel /
# EventOutcomeViewModel (unit-tested) + RunOrchestrator.resolve_event_node_live (integration-tested via
# tests/integration/run/test_resolve_event_node_live.gd — Story 15.5 Review Round 2); this overlay owns no truth.

const EventViewModel = preload("res://scripts/ui/view_models/event_view_model.gd")
const EventOutcomeViewModel = preload("res://scripts/ui/view_models/event_outcome_view_model.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

const TITLE_FONT_SIZE := 26

var _flow: RunFlowController = null
var _on_dismiss: Callable = Callable()
var _panel: VBoxContainer = null

# Open the event surface over the given run-flow handle. on_dismiss is invoked when the player finishes the event (the
# host presenter frees this overlay + clears its reference + re-renders the map, so the just-cleared node is reflected).
func open(flow: RunFlowController, on_dismiss: Callable) -> void:
	_flow = flow
	_on_dismiss = on_dismiss
	_build_scaffold()
	_present_offer()


# The modal scaffold: a mouse-blocking full-rect backdrop so taps never fall through to the map, and a centered panel
# the choices / outcome render into (mirrors PauseMenuOverlay).
func _build_scaffold() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(_panel)


# Generate the LIVE offer (the `events`-stream roll — live-only) + present the choices. On a generation failure (an empty
# repo — not expected in production) fall OPEN to the placeholder resolve so the node still clears (no soft-lock) with a
# diagnostic cue, then dismiss.
func _present_offer() -> void:
	var orchestrator: RunOrchestrator = _orchestrator()
	if orchestrator == null:
		_dismiss()
		return
	var generated: Variant = orchestrator.generate_event_offer()
	if generated.is_error() or _pending_event_id().is_empty():
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"event_node_offer_unavailable", {
				"error_code": String(generated.error_code) if generated.is_error() else "no_pending_offer"
			})
		# Fail-OPEN: clear the node via the placeholder resolve so the run advances (never a soft-lock), then dismiss.
		orchestrator.resolve_current_node_live()
		_dismiss()
		return
	_show_choices("")


# Present the pending offer's prompt + one >=44px button per choice (each labelled with its concrete trade — non-color
# text, NFR9). `cue` is a visible reject line prepended when a prior pick failed closed (re-pickable — no silent stall).
func _show_choices(cue: String) -> void:
	_clear_panel()
	var projection: Dictionary = EventViewModel.new().project_event(_pending_event_id())
	_panel.add_child(_title_label(String(projection.get("display_name", "An Event"))))
	var prompt: String = String(projection.get("prompt", ""))
	if not prompt.is_empty():
		_panel.add_child(_body_label(prompt))
	if not cue.is_empty():
		_panel.add_child(_body_label(cue))
	for choice_value: Variant in projection.get("choices", []):
		var choice: Dictionary = choice_value
		var button: Button = _menu_button(_choice_label(choice), Callable())
		button.pressed.connect(_on_choice_pressed.bind(StringName(String(choice.get("choice_id", "")))))
		_panel.add_child(button)


# A single choice's button label: the readable choice text + its concrete reward/risk trade as non-color text (the AC1
# "the player understands the trade before accepting"). Zero amounts are omitted so a safe decline reads cleanly.
func _choice_label(choice: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_append_amount(parts, "Gold", int(choice.get("gold_benefit", 0)))
	_append_amount(parts, "Healing", int(choice.get("healing_benefit", 0)))
	_append_amount(parts, "Gold cost", int(choice.get("gold_cost", 0)))
	_append_amount(parts, "Healing cost", int(choice.get("healing_cost", 0)))
	_append_amount(parts, "Curse", int(choice.get("curse_increment", 0)))
	_append_amount(parts, "Corruption", int(choice.get("corruption_increment", 0)))
	var text: String = String(choice.get("choice_text", ""))
	if parts.is_empty():
		return text
	return "%s  (%s)" % [text, ", ".join(parts)]


# Apply the picked choice via the live event seam. On success -> show the outcome; on a fail-closed reject -> re-show the
# choices with a VISIBLE cue (the offer stays pending, so a decline is re-pickable — never a silent stall).
func _on_choice_pressed(choice_id: StringName) -> void:
	var orchestrator: RunOrchestrator = _orchestrator()
	if orchestrator == null:
		_dismiss()
		return
	var resolved: Variant = orchestrator.resolve_event_node_live(choice_id)
	if resolved.is_error():
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"event_node_choice_rejected", {"error_code": String(resolved.error_code)})
		_show_choices(_reject_cue(String(resolved.error_code)))
		return
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"event_node_resolved", {"choice_id": String(choice_id)})
	_show_outcome(EventOutcomeViewModel.from_result(resolved))


# Show the outcome (what changed) + a Continue affordance that returns to the route. The node is already cleared by
# resolve_event_node_live; Continue only dismisses + re-renders.
func _show_outcome(outcome: EventOutcomeViewModel) -> void:
	_clear_panel()
	_panel.add_child(_title_label("What happened"))
	for line: String in _outcome_lines(outcome):
		_panel.add_child(_body_label(line))
	_panel.add_child(_menu_button("Continue", _dismiss))


# The outcome lines (the AC3 "shown what happened and what changed"): the signed gold/healing/curse/corruption deltas +
# the raised risk flags, each as non-color text. A zero-net safe choice reads honestly ("nothing changed") — never a
# bare empty result (AC4's honesty requirement applied to the event surface).
func _outcome_lines(outcome: EventOutcomeViewModel) -> Array[String]:
	if not outcome.has_outcome:
		return ["The event passed."]
	if outcome.is_safe_outcome():
		return ["You chose safely — nothing changed."]
	var lines: Array[String] = []
	var data: Dictionary = outcome.to_dictionary()
	_append_delta_line(lines, "Gold", int(data.get("gold_delta", 0)))
	_append_delta_line(lines, "Healing", int(data.get("healing_delta", 0)))
	_append_delta_line(lines, "Curse", int(data.get("curse_delta", 0)))
	_append_delta_line(lines, "Corruption", int(data.get("corruption_delta", 0)))
	var flags: Array = data.get("risk_flags", [])
	if not flags.is_empty():
		var flag_labels: PackedStringArray = PackedStringArray()
		for flag: Variant in flags:
			flag_labels.append(String(flag).capitalize())
		lines.append("Risk raised: %s" % ", ".join(flag_labels))
	if lines.is_empty():
		lines.append("You chose safely — nothing changed.")
	return lines


func _append_amount(parts: PackedStringArray, label: String, amount: int) -> void:
	if amount != 0:
		parts.append("%s %d" % [label, amount])


func _append_delta_line(lines: Array[String], label: String, delta: int) -> void:
	if delta != 0:
		lines.append("%s %s" % [label, _signed(delta)])


func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else "%d" % value


# Map an event-choice rejection code to a HUMAN, non-color cue line (never the raw snake_case code). A decline is always
# affordable, so an insufficient-resource reject is recoverable by re-picking.
func _reject_cue(error_code: String) -> String:
	match error_code:
		"insufficient_gold": return "You cannot afford that — choose another."
		"insufficient_healing": return "Not enough healing for that — choose another."
		"invalid_event_choice": return "That choice is not available — choose another."
		"event_offer_already_resolved": return "That choice was already taken."
		_: return "That choice could not be taken — choose another."


func _dismiss() -> void:
	if _on_dismiss.is_valid():
		_on_dismiss.call()


func _title_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	return label


func _body_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


# A >=44px choice/continue button. An empty on_pressed leaves the caller to wire pressed (the choice buttons bind the id).
func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	return button


func _clear_panel() -> void:
	for child: Node in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()


func _orchestrator() -> RunOrchestrator:
	if _flow == null or _flow.run() == null:
		return null
	return _flow.orchestrator()


func _pending_event_id() -> StringName:
	var run: RunState = _flow.run() if _flow != null else null
	if run == null or run.pending_event_offer == null:
		return &""
	return run.pending_event_offer.event_id
