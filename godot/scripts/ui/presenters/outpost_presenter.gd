extends Control

# Story 11.5 (AC1-AC4) — the OUTPOST presenter: the real OutpostViewModel-bound outpost scene the run-end return lands
# on (the polished meta dashboard + the first-death/first-victory reveal beats + the manual-seed warning + the profile
# recovery render + the start-another-descent affordance). It REPLACES the 11.3 minimal run-end landing as the run-end
# nav target (the RunFlowRouter `outpost` destination now routes here; the minimal `run_end` landing survives ONLY as the
# gameplay shell's fail-loud NON-terminal dead-end).
#
# ⭐ IT MIRRORS route_map_presenter / hero_select_presenter's posture VERBATIM: it READS a pinned VM projection (the
# OutpostViewModel the RunEndProfileBridge builds at the run-end, projected through the OutpostRenderView render-decision
# seam), MAPS fields to NON-COLOR visuals (icon/label/text — the appendix §14 color-independence rule), SUBMITS ONLY the
# start-another-descent request (through the EXISTING RunFlowController.start seam — the AUTHORITATIVE fail-closed
# RunOrchestrator.start), OWNS no domain/profile truth, and LEAKS no live handle. It NEVER mutates domain/profile state
# directly — the RunEndProfileBridge (the caller-driven run-end command family) owns the profile mutation; this presenter
# renders the result + closes the loop.
#
# ⭐ TESTABILITY (the retro G1/G2 posture — the scene-free harness has NO SceneTree): this Control is verified BY
# CONSTRUCTION (the scene-load compile guardrail test_run_flow_scenes_load.gd covers outpost.tscn; it reads pinned VM keys
# through the OutpostRenderView). The TESTABLE logic (the recovery-mode branch, the manual-seed warning, the reveal-beat
# presence, the deferred-space markers, the run-end -> profile bridge sequence, the start-descent seam) lives in the
# fail-closed RefCounted seams (OutpostRenderView / RunEndProfileBridge / OutpostViewModel / RunFlowController), all
# unit-tested. This presenter is thin glue.

const RunEndProfileBridge = preload("res://scripts/ui/flow/run_end_profile_bridge.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const OutpostRenderView = preload("res://scripts/ui/view_models/outpost_render_view.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# The default seed for a one-tap re-descend when the outpost offers no explicit seed-entry surface (the FR1 loop-closure
# affordance; a manual-seed entry is a later concern). The legacy no-class start (an empty class id) is always startable,
# so a one-tap re-descend closes the loop; the fresh run picks a new route from this seed (NOT the prior run's route).
const DEFAULT_DESCENT_SEED: int = 4242

var _render_view: OutpostRenderView = null
var _content: VBoxContainer = null

func _ready() -> void:
	_build_layout()
	_render_view = _build_render_view()
	_render_outpost()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"outpost_ready", {"is_recovery": _render_view.is_recovery()})


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# §7.4 / §14: a scrollable stack on phone_portrait -> a multi-panel dashboard on desktop. The scrollable stack is the
	# baseline (it reaches every profile without off-screen content); the desktop multi-panel is a later polish pass on
	# the same VM (the layout treatment does not change the read contract). The scroll container guarantees the descend
	# affordance + the reveal beats are never off-screen on phone_portrait.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	scroll.add_child(_content)


# Build the OutpostRenderView from the run-end -> profile bridge (the terminal run's OutpostViewModel), or the fail-closed
# empty projection when there is no seated run-flow / no terminal run (a direct-load outpost with no just-ended run).
func _build_render_view() -> OutpostRenderView:
	var flow: RunFlowController = _flow()
	if flow != null:
		var outpost: OutpostViewModel = flow.finalize_run_end()
		if outpost != null:
			return OutpostRenderView.from_view_model(outpost)
	# No seated terminal run: a valid fresh/no-run outpost (has_summary == false, every beat absent). The player can still
	# start a descent. (A direct-boot outpost is not the primary path in v0 but must not crash.)
	return OutpostRenderView.from_view_model(OutpostViewModel.new(null))


# Render the outpost surface: the recovery banner (AC3, if any), the meta readout (AC1/AC4), the manual-seed warning
# (AC4, if any), the run summary (AC1), the reveal beats (AC2), the deferred named spaces (AC1), and the descend
# affordance (AC1/FR1). Every meaning carries a non-color channel (text/icon/label).
func _render_outpost() -> void:
	for child: Node in _content.get_children():
		child.queue_free()

	var title: Label = Label.new()
	title.text = "The Outpost"
	_content.add_child(title)

	# AC3: the recovery banner (text + icon, not color-only) — the two modes read differently.
	if _render_view.is_recovery():
		_render_recovery_banner()

	# AC1/AC4: the meta readout (the AWARDED Oath-Shard total from the profile + Echoes count) — number+label, non-color.
	_render_meta_readout()

	# AC4: the manual-seed no-progression warning (a labeled banner, text+icon) — a READOUT of the existing flags.
	if _render_view.shows_manual_seed_warning():
		_render_warning_banner(_render_view.manual_seed_warning_line())

	# AC1: the just-ended run summary (branch on its has_summary gate — "no just-ended run", not a zeroed sheet).
	_render_run_summary()

	# AC2: the reveal beats (each on its own has_beat gate) with a Skip/Dismiss affordance (>=44x44, always reachable).
	if _render_view.shows_first_death_beat():
		_render_reveal_beat("Remembrance", _render_view.first_death_line())
	if _render_view.shows_first_victory_beat():
		_render_reveal_beat("Ascension", _render_view.first_victory_line())

	# AC1: the four deferred named spaces (each display_name + an EXPLICIT "deferred" marker — never silently omitted).
	_render_named_spaces()

	# AC1/FR1: the start-another-descent affordance (>=44x44) — closes the loop.
	_render_descend_affordance()


# AC3: the recovery banner. A distinct text+icon per mode so "profile not found / could not load" (load failure — fresh
# 0-shard fallback) reads differently from "save failed — retry" (write failure — real totals behind the banner). The
# WRITE-failure mode carries a retry affordance (>=44x44) that re-attempts the profile write.
func _render_recovery_banner() -> void:
	var mode: String = _render_view.recovery_mode()
	var icon: String = "[!]" if mode == OutpostRenderView.RECOVERY_MODE_WRITE_FAILURE else "[?]"
	var banner: Label = Label.new()
	banner.text = "%s %s" % [icon, _render_view.recovery_note()]
	_content.add_child(banner)

	if _render_view.has_retry_affordance():
		var retry_button: Button = Button.new()
		retry_button.text = "Retry Save"
		retry_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
		retry_button.pressed.connect(_on_retry_save_pressed)
		_content.add_child(retry_button)


func _render_meta_readout() -> void:
	# AC4 (G3 Option A): the AWARDED total is the PROFILE's (OutpostRenderView.awarded_oath_shards -> profile.oath_shards);
	# the summary's oath_shards_earned STAYS 0/not_yet_supported (shown as an honest "not yet tallied" note in the summary).
	var meta: Label = Label.new()
	meta.text = "Oath Shards: %d" % _render_view.awarded_oath_shards()
	_content.add_child(meta)


func _render_warning_banner(line: String) -> void:
	var banner: Label = Label.new()
	# A labeled banner (text + a warning icon, not a color tint).
	banner.text = "[!] %s" % line
	_content.add_child(banner)


func _render_run_summary() -> void:
	if not _render_view.shows_run_summary():
		var none_label: Label = Label.new()
		none_label.text = "No just-ended run."
		_content.add_child(none_label)
		return
	# AC4 (G3 Option A): an honest "not yet tallied" note for the Oath-Shards-earned field (the summary's field STAYS 0 /
	# not_yet_supported; the AWARDED total is the outpost-level readout above).
	if _render_view.summary_oath_shards_not_yet_tallied():
		var tally_note: Label = Label.new()
		tally_note.text = "Oath Shards earned this run: not yet tallied"
		_content.add_child(tally_note)


# AC2: a reveal beat card with the resolved line (inherently non-color text) + a Skip/Dismiss control (>=44x44, always
# reachable). The Skip/Dismiss is a PURE PRESENTATION NO-OP (FR65): it stops rendering the beat card + submits NO command
# + mutates NO flag (the latch was set by the record command in the bridge, independently of the display). There is NO
# "skip command".
func _render_reveal_beat(heading: String, line: String) -> void:
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))

	var heading_label: Label = Label.new()
	heading_label.text = heading
	card.add_child(heading_label)

	var line_label: Label = Label.new()
	line_label.text = line
	card.add_child(line_label)

	var dismiss_button: Button = Button.new()
	dismiss_button.text = "Dismiss"
	dismiss_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	# The dismiss is a structural no-op: simply free the card (no command, no mutation). The rest of the outpost stands.
	dismiss_button.pressed.connect(card.queue_free)
	card.add_child(dismiss_button)

	_content.add_child(card)


func _render_named_spaces() -> void:
	for marker_value: Variant in _render_view.named_space_markers():
		var marker: Dictionary = marker_value
		var label: Label = Label.new()
		# An icon/label tile with an EXPLICIT deferred marker (the visible-exception discipline — never silently omitted).
		var deferred_marker: String = "  (coming soon)" if bool(marker.get("is_deferred", false)) else ""
		label.text = "[#] %s%s" % [String(marker.get("display_name", "")), deferred_marker]
		_content.add_child(label)


# AC1/FR1: the start-another-descent affordance. It routes through the OutpostViewModel.start_run_request seam (surfacing
# the manual-seed warning if a manual seed is used), and on is_startable hands a FRESH RunFlowController.start(...) the
# request, clears the terminal run-flow handle, seats the new controller, and navigates to route_map — a new seed -> a new
# route -> a new run (the prior run is NOT reused, structural via RunState.new_run). A one-tap re-descend (the legacy
# no-class start is always startable); a hero re-pick is available by returning through hero_select in a later surface.
func _render_descend_affordance() -> void:
	var descend_button: Button = Button.new()
	descend_button.text = "Descend Again"
	descend_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	descend_button.disabled = not _render_view.can_start_descent()
	descend_button.pressed.connect(_on_descend_pressed)
	_content.add_child(descend_button)


func _on_descend_pressed() -> void:
	# The outpost produces a start REQUEST (the AC1 seam) via a FRESH OutpostViewModel; on is_startable it hands the
	# request to a FRESH RunFlowController.start(...) — the AUTHORITATIVE fail-closed start. A one-tap re-descend uses the
	# default seed + the legacy no-class start (always startable). The prior terminal run is NOT reused (a new controller +
	# a new RunState.new_run via start).
	var request: Dictionary = OutpostViewModel.new(null).start_run_request(DEFAULT_DESCENT_SEED, false, &"")
	if not bool(request.get("is_startable", false)):
		return

	var controller: RunFlowController = RunFlowController.new()
	var start: Dictionary = controller.start(
		int(String(request.get("root_seed", "0")).to_int()),
		bool(request.get("is_manual_seed", false)),
		StringName(String(request.get("class_id", "")))
	)
	if not bool(start.get("started", false)):
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"outpost_descend_rejected", {"error_code": String(start.get("error_code", ""))})
		return

	# Clear the terminal run-flow handle (a fresh descent starts clean) then seat the new controller (the 11.3 posture —
	# GameSession holds the live handle across scene changes).
	if has_node("/root/GameSession"):
		GameSession.clear_run_flow()
		GameSession.set_run_flow(controller)
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("route_map")


# AC3: retry the profile write on a WRITE-failure recovery. Re-drive the run-end -> profile bridge (which re-attempts the
# write) and re-render. On a successful retry the recovery banner clears; on a repeated failure it re-renders the banner
# (fail-loud, never a silent swallow). The profile is intact in memory (the write failed, not the read), so a retry is
# safe + idempotent (the latch was already recorded; a re-record rejects idempotently — the bridge handles it).
func _on_retry_save_pressed() -> void:
	_render_view = _build_render_view()
	_render_outpost()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"outpost_retry_save", {"is_recovery": _render_view.is_recovery()})


func _flow() -> RunFlowController:
	if not has_node("/root/GameSession"):
		return null
	return GameSession.run_flow() as RunFlowController
