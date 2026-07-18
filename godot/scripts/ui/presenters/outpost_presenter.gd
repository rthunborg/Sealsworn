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

const OutpostSpendBridge = preload("res://scripts/ui/flow/outpost_spend_bridge.gd")
const RunEndProfileBridge = preload("res://scripts/ui/flow/run_end_profile_bridge.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunSeedSource = preload("res://scripts/ui/flow/run_seed_source.gd")
const OutpostRenderView = preload("res://scripts/ui/view_models/outpost_render_view.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# Story 14.4 (AC1): there is NO fixed re-descend seed anymore. The one-tap "Descend Again" seed comes from the pure
# RunSeedSource seam — in v0 GameSession.get_root_seed() is always 0 (nothing configures it live), so a re-descend
# takes the ENTROPY branch and gets a genuinely fresh, DIFFERENT room every time (the F11 same-room fix). The old
# fixed DEFAULT_DESCENT_SEED = 4242 is gone.

var _render_view: OutpostRenderView = null
var _content: VBoxContainer = null
# Story 11.6: the caller-driven spend seam the presenter drives on a spend request (load -> spend -> persist -> rebuild).
# A throwaway on the real profile path (it drives ProfileRepository directly — the 11.5 posture; no SaveManager
# delegator). Lazily created so a test-driven presenter can inject one if needed; the default drives the real profile.
var _spend_bridge: OutpostSpendBridge = null

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

	# Story 11.6 (AC1/FR59): the shallow meta menu — the Seal Table spend affordances (spend Oath Shards to unlock a
	# class). Rendered as a DISTINCT section (the seal_table/hall_of_oaths named-space tiles above stay `deferred` overview
	# markers; this is the REALIZED live spend surface — [Decision] the spend menu is a distinct surface, so the overview
	# tiles are not mislabeled). Skipped on a recovery surface (a load/write failure has no live spend affordance).
	if not _render_view.is_recovery():
		_render_spend_menu()

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


# Story 11.6 (AC1/FR59): render the shallow meta menu — one spend tile per spendable class unlock (from the
# OutpostRenderView.class_unlock_options render decisions). Each tile shows the class + the cost (number+label) + the
# state via a NON-COLOR channel (an "Unlocked" marker for an applied unlock; the cost + an enabled Spend button for an
# affordable one; the insufficient note for an unaffordable one). The Spend button (>=44x44) submits a spend REQUEST to
# the OutpostSpendBridge (NOT a raw command — the presenter never mutates the profile directly), which loads -> spends ->
# persists -> rebuilds; on failure the insufficient/error message renders fail-loud (never a silent no-op).
func _render_spend_menu() -> void:
	var options: Array = _render_view.class_unlock_options()
	if options.is_empty():
		return

	var heading: Label = Label.new()
	heading.text = "Seal Table — Class Unlocks"
	_content.add_child(heading)

	for option_value: Variant in options:
		var option: Dictionary = option_value
		var unlock_id: String = String(option.get("unlock_id", ""))
		var display_name: String = String(option.get("display_name", ""))
		var cost: int = int(option.get("cost", 0))
		var state: String = String(option.get("state", ""))

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))

		var label: Label = Label.new()
		# A non-color channel: the state reads by text/icon, the cost by number+label.
		if state == OutpostRenderView.SPEND_STATE_APPLIED:
			label.text = "[x] %s — Unlocked" % display_name
		else:
			label.text = "[#] %s — Cost: %d Oath Shards" % [display_name, cost]
		row.add_child(label)

		if state == OutpostRenderView.SPEND_STATE_AFFORDABLE:
			var spend_button: Button = Button.new()
			spend_button.text = "Unlock"
			spend_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
			# Bind the unlock id into the handler (submits a spend REQUEST to the bridge).
			spend_button.pressed.connect(_on_spend_pressed.bind(unlock_id))
			row.add_child(spend_button)
		elif state == OutpostRenderView.SPEND_STATE_INSUFFICIENT:
			# Fail-loud: an unaffordable unlock shows the insufficient note (never a silent no-op).
			var note: Label = Label.new()
			note.text = "[!] %s" % OutpostRenderView.INSUFFICIENT_SHARDS_NOTE
			row.add_child(note)

		_content.add_child(row)


# Story 11.6 (AC1/FR59): a spend button submitted a REQUEST for `unlock_id`. Drive the OutpostSpendBridge (load -> spend
# -> persist -> rebuild off the LOADED profile — never the presenter's stale view), rebuild the render view from the
# returned outpost, and re-render (the meta readout + the class options reflect the spend; an unaffordable spend re-
# renders the insufficient note fail-loud). The presenter NEVER mutates the profile directly — the bridge owns the
# load->command->persist. The prior render view is replaced by the rebuilt one (off the persisted profile).
func _on_spend_pressed(unlock_id: String) -> void:
	var bridge: OutpostSpendBridge = _spend_bridge if _spend_bridge != null else OutpostSpendBridge.new()
	_spend_bridge = bridge
	var outpost: OutpostViewModel = bridge.spend(unlock_id)
	if outpost != null:
		_render_view = OutpostRenderView.from_view_model(outpost)
	_render_outpost()
	if has_node("/root/Diagnostics"):
		var result_code: String = ""
		if bridge.last_spend_result() != null and bridge.last_spend_result().is_error():
			result_code = String(bridge.last_spend_result().error_code)
		Diagnostics.info(&"ui", &"outpost_spend", {"unlock_id": unlock_id, "error_code": result_code})


func _on_descend_pressed() -> void:
	# The outpost produces a start REQUEST then hands it to a FRESH RunFlowController.start(...) — the AUTHORITATIVE
	# fail-closed start. Story 14.4 (AC1): the seed now comes from the pure RunSeedSource seam (the impure entropy read
	# is the one _new_run_entropy() line) — in v0 GameSession.get_root_seed() is 0, so a one-tap re-descend takes the
	# ENTROPY branch and gets a genuinely fresh, DIFFERENT room every time (the F11 same-room fix), NOT the old fixed
	# 4242. Only the root_seed VALUE (now entropy, decimal-string-encoded) and is_manual_seed VALUE change; the inline
	# request keeps its existing key shape (this presenter does NOT call OutpostViewModel.start_run_request, so the VM
	# START_REQUEST_KEYS pin is untouched). The empty class id is UNCONDITIONALLY startable
	# (OutpostViewModel.start_run_request's class_is_startable == true for an empty class id). The prior terminal run is
	# NOT reused (a new controller + a new RunState.new_run via start). (A future seed-entry / hero-re-pick surface would
	# build the request through the VM's start_run_request seam to re-gate a chosen class.)
	var configured_seed: int = 0
	if has_node("/root/GameSession"):
		configured_seed = GameSession.get_root_seed()
	var seed_decision: Dictionary = RunSeedSource.resolve(configured_seed, _new_run_entropy())
	var request: Dictionary = {
		"root_seed": str(int(seed_decision.get("root_seed", 0))),
		"is_manual_seed": bool(seed_decision.get("is_manual_seed", false)),
		"class_id": String(&""),
		"is_startable": true
	}
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


# Story 14.4 (AC3): the ONE impure line — a one-time OS-entropy seed SOURCE for a normal (unconfigured) re-descend.
# A LOCAL RandomNumberGenerator seeded from OS entropy, NOT a named gameplay RngStreamSet stream and NOT the global
# randi()/randf() (the seed source is chosen BEFORE any stream exists — streams derive FROM it). randomize() reseeds
# from a high-resolution source each call, so a rapid re-descend picks a fresh seed (a fixed 1-second-resolution
# clock would collide and re-create the same-room bug). The PURE manual-vs-entropy decision + normalization lives in
# RunSeedSource (unit-tested with an injected fixed entropy).
func _new_run_entropy() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()
