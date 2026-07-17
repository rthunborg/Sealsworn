extends Control

# Story 11.3 (AC2/AC4) — the TACTICAL-BOARD presenter. It RENDERS the board from TacticalBoardViewModel.
# to_dictionary() (the pinned top-level keys) into the region -> slot map (appendix §1.2): board <- cells/
# occupants/zoom, preview <- preview, confirm_cancel <- commit_flow/action_availability, inspect <- inspect,
# status <- turn + the G1 RunHudViewModel, log_or_outcome <- event_log_summary/outcome. It SUBMITS player intent
# through TacticalCommandBridge.build_command(context, intent) (move/attack/inspect) with the two-step attack
# commit via TacticalAttackCommitFlow and the passive-reward modal via PassiveRewardModalViewModel +
# PassiveRewardCommitFlow — all the EXISTING Epic-2/6 contracts (NOT a parallel presentation path). It reads the
# VM's pinned keys ONLY; it NEVER mutates BoardState/RunState directly (the bridge/commands own mutation).
#
# The scene honors the semantic TacticalLayoutProfile region plan (injected viewport/safe-area -> the profile ->
# the region vocabulary), never hardcoded geometry (AC4); text respects the TacticalTextScale clamp. Changing the
# profile/scale NEVER alters board/RNG/turn/preview legality/outcome (the profile/scale guarantees — proven at the
# TESTABLE layer in test_tactical_layout_profiles.gd). This Control is verified BY CONSTRUCTION; the TESTABLE
# logic (the board VM, the bridge, the commit flow, the layout invariance, the G1 HUD) is all unit-tested.

const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const RunHudViewModel = preload("res://scripts/ui/view_models/run_hud_view_model.gd")
const LiveAffinityReadModel = preload("res://scripts/ui/view_models/live_affinity_read_model.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const PassiveRewardModalViewModel = preload("res://scripts/ui/view_models/passive_reward_modal_view_model.gd")
const PassiveRewardCommitFlow = preload("res://scripts/ui/view_models/passive_reward_commit_flow.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const InteractiveCombatSession = preload("res://scripts/run/interactive_combat_session.gd")
# Story 13.1 — the live tile-grid render + tap hit-test seams. The DRAW surface is a thin Control; the fit +
# hit-test + tap-routing DECISIONS live in tested RefCounted seams (the AC4 "assertable logic in RefCounted
# seams" rule). TacticalBoardZoomState carries class_name, so it is referenced directly for typing.
const TacticalBoardGrid = preload("res://scripts/ui/presenters/tactical_board_grid.gd")
const TacticalBoardGridFit = preload("res://scripts/ui/view_models/tactical_board_grid_fit.gd")
const TacticalBoardTapRouter = preload("res://scripts/ui/view_models/tactical_board_tap_router.gd")
# Story 14.2 — the two scene-free RefCounted seams (F2/F3): the ARMED-attack panel projection (highlight + damage
# panel + confirm/cancel enablement, read from the pinned VM preview/commit_flow/action_availability slots) and the
# rejection-cue projection (a non-color message for every rejected command). The presenter draws their output; the
# armed-vs-not and reject-vs-benign DECISIONS live in the seams and are unit-tested (no SceneTree presenter test).
const TacticalAttackPreviewPanel = preload("res://scripts/ui/view_models/tactical_attack_preview_panel.gd")
const TacticalRejectionFeedback = preload("res://scripts/ui/view_models/tactical_rejection_feedback.gd")
# Story 14.3 (F6/F7/F8) — the in-combat event-log + hit-feedback layer, all presentation over the pinned VM slots.
# CombatExplanationLog (the EXISTING scene-free event->line transform) turns the bound session's accumulated domain
# events into the log entries render() routes into the VM's EXISTING `event_log_summary` slot (Task 1). The two new
# scene-free RefCounted seams project that slot: TacticalCombatLogView -> the log-region lines + damage numbers;
# TacticalCombatFeedback -> the move/hit/death/telegraph ANIMATION PLAN for the events newer than the last-animated
# sequence. The presenter draws their output + plays bounded self-terminating tweens; the DECISIONS live in the seams.
const CombatExplanationLog = preload("res://scripts/tactical/outcomes/combat_explanation_log.gd")
const TacticalCombatLogView = preload("res://scripts/ui/view_models/tactical_combat_log_view.gd")
const TacticalCombatFeedback = preload("res://scripts/ui/view_models/tactical_combat_feedback.gd")
# Story 13.2 — the post-victory reward HUD (an ADDITIVE overlay surface, NOT a board-VM key). It renders
# run.pending_reward_offer via the RewardHudViewModel projection (which reuses PassiveRewardModalViewModel's pinned
# MODAL_KEYS) and drives the two-step Consume/Destroy via the already-imported PassiveRewardCommitFlow. The resolving
# click routes back to the hosting shell (which owns the RewardResolutionBridge + the orchestrator).
const RewardHudViewModel = preload("res://scripts/ui/view_models/reward_hud_view_model.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")

# The approved board art (godot/assets/, all `approved` in the manifest). Loaded DEFENSIVELY at runtime (never
# preload) so the presenter SCRIPT compiles even where the machine-local import cache (.godot/, gitignored) is
# absent — the compile guardrail stays green on a fresh checkout. On any imported build the real art renders;
# an un-imported dev checkout degrades to a flat terrain-colored tile (never a crash, never a black board).
const TILE_TEXTURE_PATHS := {
	"floor": "res://assets/tiles/tile.floor.png",
	"wall": "res://assets/tiles/tile.wall.png",
	"hazard": "res://assets/tiles/tile.hazard.png",
	"entrance": "res://assets/tiles/tile.entrance.png",
	"exit": "res://assets/tiles/tile.exit.png"
}
# The affinity FLOOR variants (full-tile, not overlays — the manifest v0 posture), keyed by the level's
# affinity_id. Note the id `flooded_conductive` maps to the `affinity.flooded.png` art.
const AFFINITY_TEXTURE_PATHS := {
	"scorched": "res://assets/tiles/affinities/affinity.scorched.png",
	"flooded_conductive": "res://assets/tiles/affinities/affinity.flooded.png",
	"cursed": "res://assets/tiles/affinities/affinity.cursed.png",
	"darkness": "res://assets/tiles/affinities/affinity.darkness.png"
}
const CLASS_TEXTURE_PATHS := {
	"warrior": "res://assets/characters/char.warrior.png",
	"pyromancer": "res://assets/characters/char.pyromancer.png",
	"ranger": "res://assets/characters/char.ranger.png"
}
const ENEMY_TEXTURE_PATHS := {
	"iron_cultist": "res://assets/enemies/enemy.iron_cultist.png",
	"gate_brute": "res://assets/enemies/enemy.gate_brute.png",
	"ash_seer": "res://assets/enemies/enemy.ash_seer.png",
	"larval_avatar": "res://assets/enemies/boss.larval_avatar.png"
}

# Non-color draw channels (grayscale/silhouette-safe): fog is a featureless dark fill (no terrain leak), memory
# is a dimmed (brightness) modulate, hazards carry an outline pattern, the hero carries a distinct border, and
# every occupant carries an HP bar (a length/shape channel). Fallback tile colors are for the un-imported dev
# state only; the shipped non-color channel is the approved silhouette-distinct art.
const FOG_FILL_COLOR := Color(0.05, 0.05, 0.08, 1.0)
const MEMORY_MODULATE := Color(0.5, 0.5, 0.58, 1.0)
const GRID_LINE_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const HAZARD_OUTLINE_COLOR := Color(0.95, 0.75, 0.1, 1.0)
const HERO_MARKER_COLOR := Color(0.3, 0.85, 1.0, 1.0)
const ENEMY_MARKER_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const HP_BAR_BG_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const HP_BAR_FILL_COLOR := Color(0.25, 0.85, 0.35, 1.0)
const TERRAIN_FALLBACK_COLORS := {
	BoardCell.Terrain.FLOOR: Color(0.22, 0.2, 0.25, 1.0),
	BoardCell.Terrain.WALL: Color(0.42, 0.42, 0.48, 1.0),
	BoardCell.Terrain.HAZARD: Color(0.5, 0.3, 0.12, 1.0),
	BoardCell.Terrain.ENTRANCE: Color(0.16, 0.34, 0.5, 1.0),
	BoardCell.Terrain.EXIT: Color(0.16, 0.5, 0.34, 1.0)
}
const HERO_FALLBACK_COLOR := Color(0.2, 0.55, 0.9, 1.0)
const ENEMY_FALLBACK_COLOR := Color(0.82, 0.26, 0.26, 1.0)
# Story 14.1 (F8) — the persistent corpse/loot-marker decal channel. A dead occupant renders a DESATURATED,
# FLATTENED "remains" footprint (a short + wide rect hugging the cell floor) with a dark marker outline and NO HP
# bar and NO bright friend/foe border — a SHAPE/POSITION non-color channel (NFR9) so a corpse never reads as a
# live unit (the F8 defect: "corpses look alive").
const CORPSE_MODULATE := Color(0.42, 0.42, 0.48, 0.85)
const CORPSE_FILL_COLOR := Color(0.16, 0.13, 0.14, 0.9)
const CORPSE_OUTLINE_COLOR := Color(0.32, 0.28, 0.28, 0.85)
# Story 14.2 (F2/F3) — the ARMED-attack target highlight (a distinct DOUBLE inset outline — the SHAPE channel is the
# NFR9 signal, not the hue) and the optional rejected-cell nudge marker (a distinct thick outline). Both are
# SHAPE/POSITION channels; the accessible cue is the armed-preview LABEL and the reject MESSAGE line, never color alone.
const ARMED_TARGET_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const REJECT_MARKER_COLOR := Color(0.95, 0.3, 0.35, 0.9)
# Story 14.3 (AC2/F8) — the move/hit/death/telegraph feedback ANIMATION channels. Each is drawn as a TRANSIENT,
# self-freeing overlay node tweened by a bounded Godot Tween (NOT a per-frame _process redraw loop — the board grid's
# one-draw-per-render perf rule stays intact once the short tween completes). Every cue is a SHAPE/POSITION/MOTION
# channel (NFR9): a transient overlay appearing + fading (a temporal channel) and the floating damage-number TEXT, not
# hue alone — a hit stays legible via the log line + the number, a death via the persistent corpse decal (14.1). Zero
# RNG (fully deterministic tweens). Colors are cosmetic tints on those shape/motion channels.
const HIT_FLASH_COLOR := Color(1.0, 0.85, 0.25, 0.55)
const DEATH_FADE_COLOR := Color(0.55, 0.08, 0.1, 0.6)
const TELEGRAPH_PULSE_COLOR := Color(1.0, 0.55, 0.15, 0.5)
const SLIDE_MARKER_COLOR := Color(0.85, 0.92, 1.0, 0.55)
const DAMAGE_NUMBER_COLOR := Color(1.0, 0.92, 0.4, 1.0)
const SLIDE_DURATION := 0.16
const HIT_FLASH_DURATION := 0.28
const DAMAGE_NUMBER_DURATION := 0.6
const DAMAGE_NUMBER_RISE := 22.0
const DEATH_FADE_DURATION := 0.5
const TELEGRAPH_PULSE_DURATION := 0.5

# The region -> slot vocabulary (the appendix §1.2 region plan; the TacticalLayoutProfile region names).
const REGION_NAMES: Array[String] = [
	"board",
	"preview",
	"confirm_cancel",
	"inspect",
	"status",
	"log_or_outcome"
]

# The two-step attack commit flow (arm -> confirm) — the EXISTING Epic-2 contract, not a re-implementation.
var _commit_flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
# The command bridge — the tap-submission seam (validates before mutation).
var _command_bridge: TacticalCommandBridge = TacticalCommandBridge.new()
# The region -> control panel map (built from the semantic layout profile).
var _region_panels: Dictionary = {}

# The live rendering inputs (set by the shell presenter that hosts this board): the live BoardState, its turn
# state, the live RunState (for the G1 HUD), and the current text scale.
var _board: BoardState = null
var _turn_state = null
var _run: RunState = null
var _text_scale: float = TacticalTextScale.DEFAULT_TEXT_SCALE
# Story 11.4 (AC2) — the live level's assigned affinity id + the DarknessFairnessQuery verdict, set by the hosting
# shell. The presenter surfaces the affinity read (id/rule/affected cells/cues) via LiveAffinityReadModel — a SEPARATE
# read surface the status/log region composes (exactly like the G1 HUD), NOT a key on the board VM's pinned set.
var _affinity_id: StringName = AffinityDefinition.AFFINITY_NONE
var _affinity_fairness: Dictionary = {}

# Story 12.1 — the LIVE interactive-fight session (set by the hosting shell when a combat/elite node begins). When
# bound, the board's tap methods route each player action into the STEP-DRIVEN session (which owns the SAME command
# bridge + two-step commit flow), instead of the shell driving the atomic auto-resolver. The session owns the live
# board/turn/outcome; the presenter renders a read of it (no scene node owns tactical truth). `_on_action_committed`
# is the shell callback invoked after each COMMITTED action so the shell re-renders + routes on a terminal outcome.
var _session: InteractiveCombatSession = null
var _on_action_committed: Callable = Callable()

# Story 13.2 — the post-victory reward HUD state. `_passive_commit_flow` is the two-step Consume/Destroy arm->confirm
# view state (the EXISTING Epic-6 contract, finally instantiated + wired). `_reward_overlay`/`_reward_box` are the
# additive clickable overlay (built lazily, drawn on top of the board so it captures the tap). `_on_reward_resolution`
# is the shell callback invoked on a RESOLVING click (a generic accept / a confirmed passive commit); a cancel/back-out
# never calls it (the two-step un-arms internally, zero mutation). `_reward_active` gates rendering.
var _passive_commit_flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
var _reward_overlay: Panel = null
var _reward_box: VBoxContainer = null
var _on_reward_resolution: Callable = Callable()
var _reward_active: bool = false
# Story 13.2 (Task 5 — the carried 13-1 inspect-feedback defer): the last interactive inspect facts (the tapped
# cell), surfaced in the inspect region so an inspect tap produces on-screen feedback. Reset on a new fight bind.
var _last_inspect: Dictionary = {}

# Story 13.1 — the live tile-grid surface (built in _build_regions), the board Panel that hosts it, and the
# SHARED per-render geometry object used for BOTH the tile draw (cell_rect) and the tap hit-test
# (screen_to_cell) so a click can never land on the wrong cell. `_last_board_vm` is the exact VM snapshot the
# grid last drew (the tap router reads it, so the hit-test decides against what the player actually sees). The
# texture cache lazily resolves the approved art once per path.
var _board_grid: TacticalBoardGrid = null
var _board_panel: Panel = null
var _board_geometry: TacticalBoardZoomState = null
var _last_board_vm: Dictionary = {}
var _texture_cache: Dictionary = {}
# Story 14.1 (AC2/F1) — the always-visible Wait / End-Turn control (built in _build_regions, hosted in the
# confirm/cancel region). Routed to the live session's submit_wait so the player can ALWAYS advance the turn
# (the F1 soft-lock backstop). Shown only while a live fight is bound; a no-op otherwise.
var _wait_button: Button = null
# Story 14.2 (AC1/F2) — the explicit Confirm / Cancel attack affordances (built in _build_regions, hosted in the
# confirm/cancel region). Shown ONLY while a live attack is armed (the armed-preview panel reports is_armed);
# hidden otherwise. Confirm re-taps the armed cell (the confirming commit); Cancel un-arms with zero mutation.
var _confirm_button: Button = null
var _cancel_button: Button = null
# Story 14.2 (AC2/F3) — the last rejection cue produced by a live tap (via TacticalRejectionFeedback). Surfaced as
# a transient non-color message line in the preview region (when no attack is armed) + an optional rejected-cell
# marker. Reset on a new fight bind; replaced on every live tap (a success/benign tap clears it — has_cue false).
var _last_reject_cue: Dictionary = {}
# Story 14.3 (AC2/F8) — the highest event sequence_id already animated. render() plays the move/hit/death/telegraph
# tweens ONLY for events NEWER than this (TacticalCombatFeedback.plan), then advances it to the plan's high-water
# mark — so each event animates EXACTLY once and an arm/inspect/cancel/rejected render (which adds no events) animates
# nothing. Reset on a new fight bind to the session log's current max (0 when empty) so a bind never replays history.
var _last_animated_sequence_id: int = 0

func _ready() -> void:
	_build_regions()
	render()


# Build the semantic region panels from the injected viewport (never hardcoded geometry). Each region is a Panel
# positioned by the TacticalLayoutProfile plan; the board region stays the dominant region on every profile.
func _build_regions() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var profile: Dictionary = _layout_profile().to_dictionary()
	var regions: Dictionary = profile.get("regions", {})
	for region_name: String in REGION_NAMES:
		var rect: Dictionary = regions.get(region_name, {})
		var panel: Panel = Panel.new()
		panel.position = Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)))
		panel.size = Vector2(float(rect.get("width", 0.0)), float(rect.get("height", 0.0)))
		add_child(panel)
		var label: Label = Label.new()
		label.name = "content"
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(label)
		_region_panels[region_name] = label
		# Story 13.1 — the dominant board region hosts the live tile-grid Control ON TOP of its (now empty)
		# text label. Added last so it draws over the label and receives the tap first; the label yields input.
		if region_name == "board":
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_board_panel = panel
			_board_grid = TacticalBoardGrid.new()
			_board_grid.name = "board_grid"
			_board_grid.position = Vector2.ZERO
			_board_grid.size = panel.size
			_board_grid.cell_tapped.connect(_on_board_grid_tapped)
			panel.add_child(_board_grid)
	_build_wait_control()
	_build_confirm_cancel_controls()


# Resolve the layout profile from the real viewport/safe-area (the presenter injects them; the profile is the
# semantic source of truth — the scene honors it, does not re-derive geometry).
func _layout_profile() -> TacticalLayoutProfile:
	var viewport_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0)
	return TacticalLayoutProfile.from_viewport({
		"viewport_size": viewport_size,
		"content_scale": _text_scale
	})


# Set the live rendering inputs from the hosting shell (the live board/turn/run + text scale + the live level's assigned
# affinity id + the DarknessFairnessQuery verdict). Does NOT own the board — it renders a read of it. The affinity id +
# fairness verdict default to the neutral / empty read (the fail-closed "no affinity" render) for a caller that omits them.
func bind_live_state(
	board: BoardState,
	turn_state,
	run: RunState,
	text_scale: float = TacticalTextScale.DEFAULT_TEXT_SCALE,
	affinity_id: StringName = AffinityDefinition.AFFINITY_NONE,
	affinity_fairness: Dictionary = {}
) -> void:
	_board = board
	_turn_state = turn_state
	_run = run
	_text_scale = text_scale
	_affinity_id = affinity_id
	_affinity_fairness = affinity_fairness


# Render the board VM slots + the G1 HUD into the region panels. A null board renders the empty VM (from_domain
# (null) -> a zero-cell VM — an empty board, not a crash). The status region composes the VM's turn slot with the
# G1 run-context read (NEVER scene state).
func render() -> void:
	# Story 14.2 (Task 1 — the F2 root fix): during a LIVE fight the armed-attack state lives in the bound SESSION's
	# commit flow (_session.commit_flow_state()), NOT the presenter's own _commit_flow (which is always empty in a
	# live fight). Source the live flow when a session is bound; keep the presenter's own flow for the non-live tap
	# methods. The commit-flow state embeds the full attack preview as its `preview` sub-dict while armed
	# (TacticalAttackCommitFlow._state_from_preview) — route it into the VM's `preview` slot so the VM's preview /
	# commit_flow / action_availability reflect the LIVE armed attack (no new domain query; the 16 top-level keys are
	# unchanged — only their CONTENTS populate during a live armed attack). Not armed -> the empty preview.
	var commit_flow: Dictionary = _session.commit_flow_state() if _session != null else _commit_flow.to_dictionary()
	var preview_option: Dictionary = commit_flow.get("preview", {}) if String(commit_flow.get("mode", "")) == "attack_preview" else {}
	var text_scale: Dictionary = TacticalTextScale.from_value(_text_scale).to_dictionary()
	var accessibility: Dictionary = TacticalAccessibilityModel.from_state({
		"text_scale": _text_scale,
		"commit_flow": commit_flow
	}).to_dictionary()
	var layout: Dictionary = _layout_profile().to_dictionary()
	# Story 14.3 (Task 1 — the F6/F7 root fix): during a LIVE fight the emitted per-action domain events are sitting on
	# the bound SESSION (_session.event_log()), but render() never sourced them — so the VM's EXISTING event_log_summary
	# slot stayed [] and the log region printed the literal "Log: 0 events". Turn the accumulated events into log entries
	# (CombatExplanationLog is a STATELESS event->line transform; the SOURCE of truth is the session's domain events) and
	# route them into the EXISTING event_log_summary slot (the exact analog of the 14.2 `preview` fix — the 16 top-level
	# keys are unchanged; only this slot's CONTENTS populate during a live fight). The non-live path keeps it empty.
	var log_entries: Array[Dictionary] = []
	if _session != null:
		log_entries = CombatExplanationLog.new().build_entries(_session.event_log())
	var vm: Dictionary = TacticalBoardViewModel.from_domain(_board, _turn_state, {
		"commit_flow": commit_flow,
		"preview": preview_option,
		"layout": layout,
		"accessibility": accessibility,
		"event_log_summary": log_entries
	}).to_dictionary()

	# Story 14.2 — project the ARMED-attack panel ONCE from the pinned VM slots (the board highlight + the damage
	# panel + the confirm/cancel enablement all read this projection — never a re-derived domain query).
	var panel: Dictionary = TacticalAttackPreviewPanel.from_board_vm(vm)
	var is_armed: bool = bool(panel.get("is_armed", false))

	# Story 13.1 — the board region renders a real tile grid (a pure projection of the VM). Story 14.2 adds the
	# armed-target highlight + the optional rejected-cell marker on top (via the panel + the last reject cue).
	_render_board_grid(vm, layout, panel)
	# Story 14.2 (F2) — the preview region shows the visible armed-attack panel while armed, else the honest
	# "nothing armed" prompt + any transient rejection cue — never the raw "Preview: none" debug string.
	_set_region_text("preview", _preview_region_text(panel))
	# Story 14.2 (F2) — on the live path the Confirm/Cancel + Wait buttons ARE the affordance; do not surface the
	# raw "Confirm:false Cancel:false (mode none)" debug dump (the F2/F9 symptom). The non-live path keeps it.
	if _session != null:
		_set_region_text("confirm_cancel", "")
	else:
		_set_region_text("confirm_cancel", _confirm_cancel_text(vm.get("commit_flow", {}), vm.get("action_availability", {})))
	# Story 11.4 (AC2) — the affinity read (a SEPARATE read surface, NOT a board-VM key). Composed into the inspect +
	# status + log regions so the affinity + its rule read BEFORE + DURING play, and the affected cells surface on inspect.
	var affinity: Dictionary = LiveAffinityReadModel.new().project(_affinity_id, _board, _affinity_fairness)
	_set_region_text("inspect", _inspect_text(vm.get("inspect", {}), affinity))
	# The status region = the VM turn slot COMPOSED with the G1 run-context projection (the appendix §1.3 G1) + the
	# affinity badge (the affinity id/display-name/rule visible before + during play — FR55).
	_set_region_text("status", _status_text(vm.get("turn", {}), affinity))
	# Story 14.3 (F6/F7) — the log region now renders the live per-action lines (from the sourced event_log_summary)
	# instead of "Log: 0 events". A live-fight VM `outcome` stays empty here (the run-end beat/summary is Story 14.5),
	# so the log lines show; the terminal victory/defeat event naturally appears as the last log line.
	_set_region_text("log_or_outcome", _log_text(vm))
	# Story 14.1 — the Wait control is meaningful only during a live fight (a session is bound); hide it otherwise.
	if _wait_button != null:
		_wait_button.visible = _session != null
	# Story 14.2 — the Confirm/Cancel affordances show ONLY while a live attack is armed (hidden otherwise).
	if _confirm_button != null:
		_confirm_button.visible = _session != null and is_armed
	if _cancel_button != null:
		_cancel_button.visible = _session != null and is_armed
	# Story 14.3 (AC2/F8) — play the move/hit/death/telegraph feedback for the events NEWER than the last-animated
	# sequence (the plan seam decides WHAT; the presenter plays bounded self-terminating tweens). A live session only;
	# a render with no new events (arm / inspect / cancel / rejected tap) yields an empty plan -> no animation.
	_play_new_combat_feedback(vm)


# The G1 status region: hero HP + node progress + gold + inventory from the RunHudViewModel, composed with the
# tactical turn + the affinity badge (Story 11.4 — the affinity id/display-name visible before + during play, FR55).
# The projection reads the live board (hero HP source of truth during a level) + the run.
func _status_text(turn: Dictionary, affinity: Dictionary) -> String:
	var hud: Dictionary = RunHudViewModel.from_run(_run, _board).to_dictionary()
	var hp_text: String = "HP %d/%d" % [int(hud.get("hero_current_hp", 0)), int(hud.get("hero_max_hp", 0))] if bool(hud.get("has_hero_hp", false)) else "HP --"
	return "%s | Node %d/%d | Gold %d | Bag %d/%d | Turn %s | %s" % [
		hp_text,
		int(hud.get("cleared_node_count", 0)),
		int(hud.get("total_node_count", 0)),
		int(hud.get("gold", 0)),
		int(hud.get("inventory_count", 0)),
		int(hud.get("inventory_capacity", 0)),
		String(turn.get("phase", "")),
		_affinity_badge_text(affinity)
	]


# Story 11.4 (AC2) — the affinity BADGE: the affinity display-name + its rule count, visible before + during play. A
# neutral / no-affinity read shows "Affinity: none" (the fail-closed empty read, never a half-badge). A Darkness level
# surfaces the reduced-radius delta the DarknessReadView projects.
func _affinity_badge_text(affinity: Dictionary) -> String:
	if not bool(affinity.get("has_affinity", false)):
		return "Affinity: none"
	var display_name: String = String(affinity.get("display_name", ""))
	var rule_count: int = (affinity.get("tactical_rules", []) as Array).size()
	var badge: String = "Affinity: %s (%d rules)" % [display_name, rule_count]
	var darkness: Dictionary = affinity.get("darkness", {})
	if bool(darkness.get("has_darkness", false)):
		badge += " [sight %d->%d]" % [int(darkness.get("baseline_radius", 0)), int(darkness.get("reduced_radius", 0))]
	# The fairness verdict the DarknessFairnessQuery returned (reflected, not re-derived — AC3 single authority).
	var fairness: Dictionary = affinity.get("fairness", {})
	if bool(fairness.get("darkness_fairness_applicable", false)):
		badge += " [fair]"
	return badge


# Story 14.2 (F2/F3) — the preview region text. While an attack is ARMED it renders the visible armed-preview
# panel (the non-color armed_label + the target / expected-damage / weapon-reach / blocker / warning lines, from
# the panel projection). While NOT armed it renders the honest "nothing armed" prompt PLUS any transient rejection
# cue (the F3 non-color message line — the required accessible channel). Never the raw "Preview: none" debug string.
func _preview_region_text(panel: Dictionary) -> String:
	if bool(panel.get("is_armed", false)):
		var armed_lines: Array[String] = [String(panel.get("armed_label", ""))]
		for line_value: Variant in panel.get("lines", []) as Array:
			armed_lines.append(String(line_value))
		return "\n".join(armed_lines)
	var base: String = "No attack armed — tap an enemy to preview"
	if bool(_last_reject_cue.get("has_cue", false)):
		base += "\n! %s" % String(_last_reject_cue.get("message", ""))
	return base


func _confirm_cancel_text(commit_flow: Dictionary, availability: Dictionary) -> String:
	var confirm: Dictionary = availability.get("confirm", {})
	var cancel: Dictionary = availability.get("cancel", {})
	return "Confirm:%s Cancel:%s (mode %s)" % [
		str(bool(confirm.get("enabled", false))),
		str(bool(cancel.get("enabled", false))),
		String(commit_flow.get("mode", "none"))
	]


# The inspect region: the tapped cell's visibility state + (Story 11.4, AC2/FR12/FR58) the affinity danger read — the
# affinity-affected-cell counts + the non-color cue ids surfaced through the EXISTING affinity preview / Darkness cue
# surfaces (the scene MAPS the cue_ids to visuals; it invents no new reason/cue). A neutral read appends nothing.
func _inspect_text(inspect: Dictionary, affinity: Dictionary) -> String:
	var base: String = _inspect_base_text(inspect)
	if not bool(affinity.get("has_affinity", false)):
		return base
	var preview: Dictionary = affinity.get("preview", {})
	var hazard: int = (preview.get("hazard_cells", []) as Array).size()
	var conductive: int = (preview.get("conductive_danger_cells", []) as Array).size()
	var pathing: int = (preview.get("pathing_pressure_cells", []) as Array).size()
	var cue_ids: Array = affinity.get("cue_ids", [])
	return "%s | Danger: %d hazard / %d conductive / %d pathing | Cues: %s" % [
		base, hazard, conductive, pathing, ", ".join(PackedStringArray(cue_ids))
	]


# Story 13.2 (Task 5) — the inspect region base line. Prefer the last INTERACTIVE inspect facts (the tapped cell:
# coords + visibility + occupant/HP) so an inspect tap produces real on-screen feedback (the carried 13-1 defer);
# fall back to the VM inspect slot, then the static "tap a cell" prompt when nothing has been inspected.
func _inspect_base_text(inspect: Dictionary) -> String:
	if not _last_inspect.is_empty():
		if bool(_last_inspect.get("unavailable", false)):
			return "Inspect: unavailable (%s)" % String(_last_inspect.get("reason", ""))
		var text: String = "Inspect: (%d,%d) %s" % [
			int(_last_inspect.get("x", 0)),
			int(_last_inspect.get("y", 0)),
			String(_last_inspect.get("visibility_state", ""))
		]
		if _last_inspect.has("occupant_id"):
			text += " | %s %s HP %d" % [
				String(_last_inspect.get("entity_type", "")),
				String(_last_inspect.get("occupant_id", "")),
				int(_last_inspect.get("current_hp", 0))
			]
		return text
	if inspect.is_empty():
		return "Inspect: tap a cell"
	return "Inspect: %s" % String(inspect.get("visibility_state", ""))


# Story 14.3 (F6/F7) — the log region text. The `outcome`-present branch stays honest (14.3 does NOT populate the VM
# outcome slot — the run-end summary is Story 14.5 — so this branch is dormant during a live fight). During a live
# fight the log-view seam projects the tail of per-action lines (each carrying its damage text) from the sourced
# event_log_summary; an empty log renders the honest "no events yet" (not the F6 "Log: 0 events" during a fight).
func _log_text(vm: Dictionary) -> String:
	var outcome: Dictionary = vm.get("outcome", {})
	if not outcome.is_empty() and not String(outcome.get("state_id", "")).is_empty():
		return "Outcome: %s" % String(outcome.get("state_id", ""))
	var log_view: Dictionary = TacticalCombatLogView.from_board_vm(vm)
	if not bool(log_view.get("has_entries", false)):
		return "Log: no events yet"
	return "\n".join(log_view.get("lines", []) as Array)


func _set_region_text(region_name: String, text: String) -> void:
	var label: Label = _region_panels.get(region_name, null)
	if label != null:
		label.text = text


# --- the tap seam (the EXISTING command-bridge / commit-flow contracts) ----------------------------------------

# Submit a MOVE intent through the command bridge (validate-before-mutation). The scene reads availability; the
# bridge/command owns mutation. Returns the ActionResult so a caller/test can read the outcome.
func submit_move(context: TacticalActionContext, actor_id: StringName, target_cell: Vector2i, movement_budget: int = -1):
	var intent: Dictionary = {
		"intent_id": "move",
		"actor_id": String(actor_id),
		"target_cell": target_cell
	}
	if movement_budget > 0:
		intent["movement_budget"] = movement_budget
	return _command_bridge.execute_intent(context, intent)


# Submit an ATTACK tap through the TWO-STEP commit flow: the first tap ARMS attack_preview; a second tap on the
# SAME target/weapon/actor CONFIRMS (executes through the bridge). The EXISTING Epic-2 contract — NOT a parallel path.
func tap_attack(context: TacticalActionContext, actor_id: StringName, target_cell: Vector2i, weapon, attacker_support = null, defender_support = null):
	var flow_result = _commit_flow.tap_attack_target(context, actor_id, target_cell, weapon, attacker_support, defender_support, _command_bridge)
	render()
	return flow_result


# Cancel the pending attack (zero mutation).
func cancel_attack():
	var result = _commit_flow.cancel()
	render()
	return result


# Submit an INSPECT intent (metadata-only through the bridge — no mutation).
func inspect_cell(context: TacticalActionContext, target_cell: Vector2i):
	return _command_bridge.build_command(context, {
		"intent_id": "inspect",
		"target_cell": target_cell
	})


# Project a passive-reward modal from the run's pending offer at `index` (the EXISTING Epic-6 contract). The scene
# renders the pinned MODAL_KEYS; the two-step consume/destroy is PassiveRewardCommitFlow. icon is an id STRING.
func passive_reward_modal(index: int) -> Dictionary:
	if _run == null:
		return PassiveRewardModalViewModel.new().project_offer(null, index)
	return PassiveRewardModalViewModel.new().project_offer(_run.pending_reward_offer, index)


# --- Story 12.1: the LIVE interactive tap seam (route each tap into the step-driven session) --------------------

# Bind the LIVE interactive-fight session hosted by the shell. When bound, the board renders the session's live
# (mutated-in-place) board + turn state and routes each tap into the session (which owns the SAME command bridge +
# two-step commit flow the non-live tap methods use — NOT a parallel path). `on_action_committed` is the shell
# callback invoked after each COMMITTED action (a move / a confirmed attack) so the shell re-renders + routes on a
# terminal outcome. Binds the render inputs (the live board/turn/run + affinity + fairness) from the session in one call.
func bind_interactive_session(
	session: InteractiveCombatSession,
	run: RunState,
	on_action_committed: Callable = Callable(),
	affinity_id: StringName = AffinityDefinition.AFFINITY_NONE,
	affinity_fairness: Dictionary = {}
) -> void:
	_session = session
	_on_action_committed = on_action_committed
	# Story 13.2 (Task 5) — a new fight clears any stale inspect feedback from the previous node.
	_last_inspect = {}
	# Story 14.2 (AC2/F3) — a new fight clears any stale rejection cue from the previous node.
	_last_reject_cue = {}
	# Story 14.3 (AC2/F8) — reset the animation high-water to the session log's CURRENT max (0 when empty) so a fresh
	# bind animates only events emitted AFTER bind, never replaying the fight's already-shown history.
	_last_animated_sequence_id = _max_event_sequence_id(session.event_log()) if session != null else 0
	# The LIVE board + turn state (mutated-in-place by the session) drive the render — NOT a throwaway PLAYER_PLANNING
	# stub, so the HUD's turn slot + action_availability reflect the real turn (preview/commit/inspect gate correctly).
	if session != null:
		bind_live_state(session.board(), session.turn_state(), run, _text_scale, affinity_id, affinity_fairness)


# The current live interactive session (or null when the board is not hosting a live fight). A pure read.
func interactive_session() -> InteractiveCombatSession:
	return _session


# Route a MOVE tap into the live session (the human's move action). The session drives ONE MoveCommand through the
# command bridge + runs the enemy phase on a committed move. Re-renders the live board + notifies the shell (the
# terminal check + route). Returns the session's ActionResult. A no-op ok when no session is bound.
func interactive_submit_move(target_cell: Vector2i, movement_budget: int = -1):
	if _session == null:
		return null
	var result_value = _session.submit_move(target_cell, movement_budget)
	# Story 14.2 (AC2/F3) — surface a non-color cue for a REJECTED move (into a wall, onto a blocker, off-board,
	# too far, not your turn); a successful move returns no cue (clearing any stale reject message).
	_last_reject_cue = TacticalRejectionFeedback.from_action_result(result_value, target_cell)
	render()
	_notify_action_committed()
	return result_value


# Route an ATTACK tap into the live session (the two-step commit — first tap PREVIEWS/arms, second COMMITS). The
# session runs the enemy phase on a committed attack. Re-renders + notifies the shell. Returns the commit-flow result.
func interactive_tap_attack(target_cell: Vector2i, attacker_support = null, defender_support = null):
	if _session == null:
		return null
	var flow_result = _session.tap_attack(target_cell, attacker_support, defender_support)
	# Story 14.2 (AC2/F3) — a REJECTED attack tap (no target / out of range / not in line / line blocked, incl. the
	# corpse missing_target case) surfaces a non-color cue; an ARM (preview_ready — shows the armed panel), a CANCEL,
	# and a committed attack are benign (the seam returns no cue, clearing any stale reject message).
	_last_reject_cue = TacticalRejectionFeedback.from_flow_result(flow_result, target_cell)
	render()
	_notify_action_committed()
	return flow_result


# Story 14.2 (AC1/F2) — cancel the LIVE armed attack (zero mutation): un-arm the session's commit flow + re-render.
# A cancel commits NOTHING, so it does NOT notify the shell (mirrors the reward two-step cancel back-out). The cancel
# result feeds the rejection seam, which returns NO cue for a cancel — clearing any stale reject message. No-op if
# no session is bound (the Cancel affordance is meaningful only during a live fight).
func interactive_cancel_attack():
	if _session == null:
		return null
	var result_value = _session.cancel_attack()
	_last_reject_cue = TacticalRejectionFeedback.from_flow_result(result_value, null)
	render()
	return result_value


# Route an INSPECT tap into the live session (metadata-only — no mutation, no turn advance). Returns the
# CommandBridgeResult. Does NOT notify the shell (inspect commits nothing).
# Story 13.2 (Task 5 — closing the carried 13-1 inspect-feedback defer): the inspect result is no longer discarded.
# The returned cell facts are stored + the board re-rendered, so the inspect region surfaces the tapped cell (coords,
# visibility, occupant + HP) instead of the static "Inspect: tap a cell". Still a pure read — no mutation, no turn.
func interactive_inspect(target_cell: Vector2i):
	if _session == null:
		return null
	var inspect_result = _session.inspect(target_cell)
	_last_inspect = _inspect_facts_from(inspect_result)
	render()
	return inspect_result


# Distill the interactive inspect CommandBridgeResult into the flat facts the inspect region renders (Task 5). An
# unavailable inspect (out-of-bounds / a disabled result) records the reason; a visible cell records its coords,
# visibility, and — when occupied — the occupant id / type / current HP (the visible_facts_for_cell fact surface).
func _inspect_facts_from(inspect_result) -> Dictionary:
	if inspect_result == null:
		return {}
	if not inspect_result.succeeded:
		return {"unavailable": true, "reason": String(inspect_result.reason)}
	var metadata: Dictionary = inspect_result.metadata
	var target: Dictionary = metadata.get("target_cell", {})
	var cell: Dictionary = metadata.get("cell", {})
	var facts: Dictionary = {
		"unavailable": false,
		"x": int(target.get("x", 0)),
		"y": int(target.get("y", 0)),
		"visibility_state": String(cell.get("visibility_state", ""))
	}
	if cell.has("occupant_id"):
		facts["occupant_id"] = String(cell.get("occupant_id", ""))
		facts["entity_type"] = String(cell.get("entity_type", ""))
		facts["current_hp"] = int(cell.get("current_hp", 0))
	return facts


# Notify the shell that a session action resolved (the shell re-renders the HUD + routes on a terminal outcome). Guards
# a null/invalid callback (a dead callback silently no-ops — but this is bound by the shell by construction, not probed).
func _notify_action_committed() -> void:
	if _on_action_committed.is_valid():
		_on_action_committed.call()


# Story 14.1 (AC2) — route a WAIT tap into the live session (the always-available pass / End-Turn — the F1
# turn-advance backstop). The session commits a WaitCommand and runs the enemy phase; re-render + notify the shell
# (terminal check + route). A no-op when no session is bound (the control is meaningful only during a live fight).
func interactive_wait():
	if _session == null:
		return null
	var result_value = _session.submit_wait()
	# Story 14.2 (AC2/F3) — a rejected wait (session terminal / not your turn / dead hero) surfaces a cue; a
	# committed wait returns no cue (clearing any stale reject message).
	_last_reject_cue = TacticalRejectionFeedback.from_action_result(result_value, null)
	render()
	_notify_action_committed()
	return result_value


# The Wait / End-Turn button handler (routes to the live session's wait seam).
func _on_wait_pressed() -> void:
	interactive_wait()


# Story 14.1 (AC2/F1) — build the always-present Wait / End-Turn control in the confirm/cancel region. Carries a
# text label (a non-color channel, NFR9) and honors the >=44px touch target. Hidden until a live fight binds a
# session (toggled in render()).
func _build_wait_control() -> void:
	var confirm_label: Label = _region_panels.get("confirm_cancel", null)
	var host: Node = confirm_label.get_parent() if confirm_label != null else self
	if host == null:
		host = self
	_wait_button = Button.new()
	_wait_button.name = "wait_button"
	_wait_button.text = "Wait / End Turn"
	_wait_button.custom_minimum_size = Vector2(44.0, 44.0)
	_wait_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_wait_button.pressed.connect(_on_wait_pressed)
	host.add_child(_wait_button)
	_wait_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_wait_button.visible = false


# Story 14.2 (AC1/F2) — the Confirm affordance: re-tap the armed cell (the tap router treats a re-tap on the armed
# cell as the confirming commit — `_armed_attack_cell` + interactive_tap_attack). A no-op if nothing is armed.
func _on_confirm_attack_pressed() -> void:
	var armed_cell: Variant = _armed_attack_cell()
	if armed_cell is Vector2i:
		interactive_tap_attack(armed_cell)


# Story 14.2 (AC1/F2) — the Cancel affordance: un-arm with zero mutation (interactive_cancel_attack).
func _on_cancel_attack_pressed() -> void:
	interactive_cancel_attack()


# Story 14.2 (AC1/F2) — build the explicit Confirm / Cancel attack affordances in the confirm/cancel region. Each
# carries a text label (a non-color channel, NFR9) and honors the >=44px touch target (mirrors the 14.1 Wait control
# + the 13.2 reward buttons). Hosted in a top-anchored row (the Wait control sits bottom-anchored); shown ONLY while
# a live attack is armed (toggled in render()).
func _build_confirm_cancel_controls() -> void:
	var confirm_label: Label = _region_panels.get("confirm_cancel", null)
	var host: Node = confirm_label.get_parent() if confirm_label != null else self
	if host == null:
		host = self
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "attack_commit_row"
	row.add_theme_constant_override("separation", 8)
	host.add_child(row)
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_confirm_button = Button.new()
	_confirm_button.name = "confirm_attack_button"
	_confirm_button.text = "Confirm Attack"
	_confirm_button.custom_minimum_size = Vector2(44.0, 44.0)
	_confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_button.pressed.connect(_on_confirm_attack_pressed)
	row.add_child(_confirm_button)
	_cancel_button = Button.new()
	_cancel_button.name = "cancel_attack_button"
	_cancel_button.text = "Cancel Attack"
	_cancel_button.custom_minimum_size = Vector2(44.0, 44.0)
	_cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_cancel_button.pressed.connect(_on_cancel_attack_pressed)
	row.add_child(_cancel_button)
	_confirm_button.visible = false
	_cancel_button.visible = false

# --- Story 14.3: the in-combat move/hit/death/telegraph feedback animation (AC2/F8) ----------------------------

# Play the feedback tweens for the events NEWER than _last_animated_sequence_id, then advance the high-water mark so
# each event animates EXACTLY once. Live session only + the grid must be in the tree (a fight-ending tap can detach
# the grid mid-flow — the 13.1 out-of-tree guard). The plan (a pure seam) decides WHAT animates; this presenter plays
# the bounded, self-terminating tweens. A render with no new events (arm / inspect / cancel / rejected tap) yields an
# empty plan -> no tween, and _last_animated_sequence_id is NOT advanced (nothing new to consume).
func _play_new_combat_feedback(vm: Dictionary) -> void:
	if _session == null or _board_grid == null or not _board_grid.is_inside_tree():
		return
	var plan: Dictionary = TacticalCombatFeedback.plan(
		vm.get("event_log_summary", []) as Array,
		_last_animated_sequence_id,
		vm.get("occupants", []) as Array
	)
	if not TacticalCombatFeedback.has_feedback(plan):
		return
	for move_value: Variant in plan.get("moves", []) as Array:
		if move_value is Dictionary:
			_animate_slide((move_value as Dictionary).get("from"), (move_value as Dictionary).get("to"))
	for hit_value: Variant in plan.get("hits", []) as Array:
		if hit_value is Dictionary:
			_animate_hit((hit_value as Dictionary).get("cell"), int((hit_value as Dictionary).get("amount", 0)))
	for death_value: Variant in plan.get("deaths", []) as Array:
		if death_value is Dictionary:
			_animate_death((death_value as Dictionary).get("cell"))
	for telegraph_value: Variant in plan.get("telegraphs", []) as Array:
		if telegraph_value is Dictionary:
			_animate_telegraph((telegraph_value as Dictionary).get("cell"))
	_last_animated_sequence_id = int(plan.get("last_sequence_id", _last_animated_sequence_id))


# The max event sequence_id currently on the session log (0 when empty) — the bind-time animation high-water reset so
# a fresh bind never replays the fight's already-shown history.
func _max_event_sequence_id(events: Array) -> int:
	var maximum: int = 0
	for event: Variant in events:
		if event != null:
			maximum = maxi(maximum, int(event.sequence_id))
	return maximum


# A move slide: a transient marker tweened from the origin cell to the destination cell (the MOTION channel — the unit
# is already drawn statically at the destination; this overlay reads the "slid, not teleported" transition). Both
# cells must resolve (a fog/edge no-resolve is a safe no-op). Deterministic (zero RNG); self-freeing.
func _animate_slide(from_cell: Variant, to_cell: Variant) -> void:
	if _board_grid == null:
		return
	var from_rect: Rect2 = _cell_rect(from_cell)
	var to_rect: Rect2 = _cell_rect(to_cell)
	if from_rect.size.x <= 0.0 or to_rect.size.x <= 0.0:
		return
	var inset: float = from_rect.size.x * 0.22
	var marker: ColorRect = ColorRect.new()
	marker.color = SLIDE_MARKER_COLOR
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = from_rect.size - Vector2(inset, inset) * 2.0
	marker.position = from_rect.position + Vector2(inset, inset)
	_board_grid.add_child(marker)
	var tween: Tween = marker.create_tween()
	tween.tween_property(marker, "position", to_rect.position + Vector2(inset, inset), SLIDE_DURATION)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, SLIDE_DURATION)
	tween.tween_callback(marker.queue_free)


# A hit: a cell flash (a temporal MOTION channel) + a floating damage number (TEXT). Deterministic; self-freeing.
func _animate_hit(cell: Variant, amount: int) -> void:
	var flash: ColorRect = _transient_cell_rect(cell, HIT_FLASH_COLOR)
	if flash != null:
		var tween: Tween = flash.create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, HIT_FLASH_DURATION)
		tween.tween_callback(flash.queue_free)
	_animate_damage_number(cell, amount)


# A floating damage number: a transient Label that rises + fades (TEXT + MOTION channels, NFR9). A non-positive amount
# (e.g. a fully-blocked hit) draws no number (the flash still fires). Deterministic; self-freeing.
func _animate_damage_number(cell: Variant, amount: int) -> void:
	if _board_grid == null or amount <= 0:
		return
	var rect: Rect2 = _cell_rect(cell)
	if rect.size.x <= 0.0:
		return
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = DAMAGE_NUMBER_COLOR
	label.z_index = 1
	label.position = rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.08)
	_board_grid.add_child(label)
	var start_y: float = label.position.y
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", start_y - DAMAGE_NUMBER_RISE, DAMAGE_NUMBER_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_DURATION)
	tween.tween_callback(label.queue_free)


# A death: a transient cell overlay that fades out ON TOP of the persistent corpse decal (14.1 draws the is_dead decal
# in the SAME render), animating the transition INTO the decal. Deterministic; self-freeing. NOTE (known basic-tier
# limit): a fight-ENDING death routes synchronously to run-end and can detach the grid before this completes — the
# corpse decal + the 14.5 run-end beat carry that moment; the tween tolerates the node being freed (bound to it).
func _animate_death(cell: Variant) -> void:
	var fade: ColorRect = _transient_cell_rect(cell, DEATH_FADE_COLOR)
	if fade == null:
		return
	var tween: Tween = fade.create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(fade.queue_free)


# A telegraph: a transient cell overlay that fades IN then OUT on the marked cell (a MOTION channel for the Ash Seer
# mark — a full countdown VFX is out of scope, basic tier). Deterministic; self-freeing.
func _animate_telegraph(cell: Variant) -> void:
	var pulse: ColorRect = _transient_cell_rect(cell, TELEGRAPH_PULSE_COLOR)
	if pulse == null:
		return
	# Start invisible (full modulate assignment — avoid the sub-property no-op footgun), pulse up then down.
	pulse.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = pulse.create_tween()
	tween.tween_property(pulse, "modulate:a", 1.0, TELEGRAPH_PULSE_DURATION * 0.4)
	tween.tween_property(pulse, "modulate:a", 0.0, TELEGRAPH_PULSE_DURATION * 0.6)
	tween.tween_callback(pulse.queue_free)


# A transient cell-sized ColorRect parented to the board grid (drawn over the one-pass op list), non-interactive
# (mouse IGNORE so it never eats a tap), at the given cell's rect. Returns null for an unresolved cell (fog / no
# geometry) — a safe no-op, never a fabricated cell.
func _transient_cell_rect(cell: Variant, color: Color) -> ColorRect:
	if _board_grid == null:
		return null
	var rect: Rect2 = _cell_rect(cell)
	if rect.size.x <= 0.0:
		return null
	var overlay: ColorRect = ColorRect.new()
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.position = rect.position
	overlay.size = rect.size
	_board_grid.add_child(overlay)
	return overlay

# --- Story 13.1: the live tile-grid render + tap hit-test ------------------------------------------------------

# Draw the board region as a real tile grid — a PURE projection of the VM (cells + occupants) + the level's
# affinity floor variant. Builds ONE shared TacticalBoardZoomState (via the RefCounted fit seam) sized to the
# board Panel and uses it for BOTH the tile draw and the tap hit-test. A null / empty board (the between-levels
# zero-cell VM) draws NOTHING (the correct-by-design empty state) — never a crash, never a divide-by-zero.
func _render_board_grid(vm: Dictionary, layout: Dictionary, panel: Dictionary = {}) -> void:
	_last_board_vm = vm
	_board_geometry = null
	_set_region_text("board", "")
	if _board_grid == null:
		return

	var region_size: Vector2 = _board_region_size(layout)
	_board_grid.position = Vector2.ZERO
	_board_grid.size = region_size

	var width: int = int(vm.get("width", 0))
	var height: int = int(vm.get("height", 0))
	var cells: Array = vm.get("cells", []) as Array
	if width <= 0 or height <= 0 or cells.is_empty():
		_board_grid.clear_ops()
		return

	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(width, height, {
		"x": 0.0,
		"y": 0.0,
		"width": region_size.x,
		"height": region_size.y
	})
	if not fit.available():
		_board_grid.clear_ops()
		return
	_board_geometry = fit.to_zoom_state(region_size)
	if _board_geometry == null:
		_board_grid.clear_ops()
		return
	_board_grid.set_ops(_build_board_draw_ops(vm, panel))


# The board region rect comes from the semantic layout profile (never hardcoded geometry). The board Panel is
# the actual on-screen surface, so its size is the source of truth for the draw; fall back to the layout region
# only if the panel is unsized.
func _board_region_size(layout: Dictionary) -> Vector2:
	if _board_panel != null and _board_panel.size.x > 0.0 and _board_panel.size.y > 0.0:
		return _board_panel.size
	var regions: Dictionary = layout.get("regions", {})
	var region: Dictionary = regions.get("board", {})
	return Vector2(float(region.get("width", 0.0)), float(region.get("height", 0.0)))


# Compose the ordered draw-op list the grid replays: fog/terrain tiles first (each with a grid line + a hazard
# outline), then occupants (sprite + a friend/foe marker + an HP bar) on top. Draws ONLY what the VM gives —
# hidden cells expose NO terrain (the FR7 fog contract), occupants are already filtered to visible cells.
func _build_board_draw_ops(vm: Dictionary, panel: Dictionary = {}) -> Array:
	var ops: Array = []
	if _board_geometry == null:
		return ops

	for cell_value: Variant in vm.get("cells", []) as Array:
		if not cell_value is Dictionary:
			continue
		var cell: Dictionary = cell_value
		var rect: Rect2 = _cell_rect(cell.get("position", {}))
		if rect.size.x <= 0.0:
			continue
		var visibility: String = String(cell.get("visibility_state", "hidden"))
		if visibility == "hidden":
			# Fog: a featureless dark fill — NO terrain leak (a hidden cell exposes no terrain in the VM).
			ops.append(_fill_op(rect, FOG_FILL_COLOR))
			ops.append(_outline_op(rect, GRID_LINE_COLOR, 1.0))
			continue
		var terrain: int = int(cell.get("terrain", BoardCell.Terrain.FLOOR))
		var texture: Texture2D = _terrain_texture(terrain)
		if texture != null:
			var modulate: Color = MEMORY_MODULATE if visibility == "memory" else Color.WHITE
			ops.append(_texture_op(rect, texture, modulate))
		else:
			ops.append(_fill_op(rect, _terrain_fallback_color(terrain, visibility)))
		ops.append(_outline_op(rect, GRID_LINE_COLOR, 1.0))
		if terrain == BoardCell.Terrain.HAZARD:
			# Non-color hazard channel: a bright pattern outline on top of the silhouette-distinct hazard art.
			ops.append(_outline_op(rect.grow(-2.0), HAZARD_OUTLINE_COLOR, 3.0))

	for occupant_value: Variant in vm.get("occupants", []) as Array:
		if not occupant_value is Dictionary:
			continue
		var occupant: Dictionary = occupant_value
		var cell_rect: Rect2 = _cell_rect(occupant.get("position", {}))
		if cell_rect.size.x <= 0.0:
			continue
		# Story 14.1 (F8): a dead occupant (a 14.1 corpse surfaced by the board VM) draws a distinct persistent
		# corpse/loot-marker decal instead of a live sprite + HP bar, so it never reads as alive.
		if bool(occupant.get("is_dead", false)):
			for corpse_op: Dictionary in _corpse_decal_ops(cell_rect, occupant):
				ops.append(corpse_op)
			continue
		var is_hero: bool = String(occupant.get("entity_type", "")) == "player"
		var sprite: Texture2D = _hero_texture() if is_hero else _enemy_texture(String(occupant.get("definition_id", "")))
		if sprite != null:
			ops.append(_texture_op(_sprite_rect(cell_rect, sprite), sprite, Color.WHITE))
		else:
			var fallback_color: Color = HERO_FALLBACK_COLOR if is_hero else ENEMY_FALLBACK_COLOR
			ops.append(_fill_op(cell_rect.grow(-cell_rect.size.x * 0.18), fallback_color))
		# Non-color friend/foe channel: the hero carries a distinct bright full border (the enemy a thin dark one).
		var marker_color: Color = HERO_MARKER_COLOR if is_hero else ENEMY_MARKER_COLOR
		var marker_width: float = 3.0 if is_hero else 2.0
		ops.append(_outline_op(cell_rect.grow(-1.0), marker_color, marker_width))
		# HP bar: a length/shape channel (grayscale-safe) so damage reads without color.
		for hp_op: Dictionary in _hp_bar_ops(cell_rect, occupant):
			ops.append(hp_op)

	# Story 14.2 (AC1/F2) — the ARMED-attack target highlight: a distinct DOUBLE inset outline (a SHAPE channel,
	# NFR9 — not hue-only) on the armed target cell. The cell comes from the panel projection (which reads the
	# pinned VM preview.target_cell), NEVER a re-derived query. Guarded against a null / off-board / missing cell
	# (a safe no-op — _cell_rect returns a zero-size Rect2 for an unavailable/geometry-less cell; never fabricated).
	if bool(panel.get("is_armed", false)) and panel.get("target_cell") is Dictionary:
		var armed_rect: Rect2 = _cell_rect(panel.get("target_cell"))
		if armed_rect.size.x > 0.0:
			ops.append(_outline_op(armed_rect.grow(-2.0), ARMED_TARGET_OUTLINE_COLOR, 4.0))
			ops.append(_outline_op(armed_rect.grow(-6.0), ARMED_TARGET_OUTLINE_COLOR, 2.0))

	# Story 14.2 (AC2/F3, optional additive) — the rejected-cell nudge marker on the cell the last rejected command
	# targeted (a SHAPE/POSITION channel). ADDITIVE only — the REQUIRED accessible cue is the preview-region message
	# line; this marker is cleared together with the cue on the next successful action. Same _cell_rect guards.
	if bool(_last_reject_cue.get("has_cue", false)) and bool(_last_reject_cue.get("shake", false)) and _last_reject_cue.get("cell") is Dictionary:
		var reject_rect: Rect2 = _cell_rect(_last_reject_cue.get("cell"))
		if reject_rect.size.x > 0.0:
			ops.append(_outline_op(reject_rect.grow(-4.0), REJECT_MARKER_COLOR, 3.0))

	return ops


# Route a tap PIXEL (local to the grid Control) into the EXISTING interactive_* seams. Reuses the tested
# TacticalBoardZoomState.screen_to_cell hit-test (never a second pixel->cell formula) and the RefCounted
# tap-routing DECISION seam. An unavailable mapping (out-of-bounds / invalid-geometry / NaN) is a safe no-op —
# never a fabricated cell. No session bound (or no geometry) -> ignore.
func _on_board_grid_tapped(local_position: Vector2) -> void:
	if _session == null or _board_geometry == null:
		return
	var mapping: Dictionary = _board_geometry.screen_to_cell(local_position)
	var decision: Dictionary = TacticalBoardTapRouter.decide(mapping, _last_board_vm, _armed_attack_cell())
	var cell: Vector2i = _cell_vector(decision.get("cell", {}))
	match String(decision.get("intent", TacticalBoardTapRouter.INTENT_NONE)):
		TacticalBoardTapRouter.INTENT_MOVE:
			interactive_submit_move(cell)
		TacticalBoardTapRouter.INTENT_ATTACK:
			interactive_tap_attack(cell)
		TacticalBoardTapRouter.INTENT_INSPECT:
			interactive_inspect(cell)
		_:
			# A safe no-op (out-of-bounds / invalid tap). Log via Diagnostics if present; fabricate nothing.
			if is_inside_tree() and has_node("/root/Diagnostics"):
				Diagnostics.info(&"ui", &"tactical_board_tap_ignored", {"reason": String(decision.get("reason", ""))})


# The currently-armed attack target (the session's two-step commit-flow preview) as a Vector2i, or null when no
# attack is armed — so a re-tap on the SAME enemy is recognized as the confirming commit by the router.
func _armed_attack_cell() -> Variant:
	if _session == null:
		return null
	var flow: Dictionary = _session.commit_flow_state()
	if String(flow.get("mode", "")) != "attack_preview":
		return null
	var target: Variant = flow.get("target_cell")
	if target is Dictionary:
		var data: Dictionary = target
		if (data.has("x") or data.has(&"x")) and (data.has("y") or data.has(&"y")):
			return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	return null


func _cell_rect(position: Variant) -> Rect2:
	if _board_geometry == null:
		return Rect2()
	var cell: Vector2i = _cell_vector(position)
	var rect_data: Dictionary = _board_geometry.cell_rect(cell)
	if not bool(rect_data.get("available", false)):
		return Rect2()
	var rect_position: Dictionary = rect_data.get("position", {})
	var rect_size: Dictionary = rect_data.get("size", {})
	return Rect2(
		float(rect_position.get("x", 0.0)),
		float(rect_position.get("y", 0.0)),
		float(rect_size.get("x", 0.0)),
		float(rect_size.get("y", 0.0))
	)


func _cell_vector(position: Variant) -> Vector2i:
	if position is Dictionary:
		var data: Dictionary = position
		return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	if position is Vector2i:
		return position
	return Vector2i.ZERO


# Fit a portrait occupant sprite into its cell, aspect-preserved + centered with a small inset (never stretched
# into a square). A null texture yields the plain inset rect (the fallback marker draws there).
func _sprite_rect(cell_rect: Rect2, texture: Texture2D) -> Rect2:
	var inset: Rect2 = cell_rect.grow(-cell_rect.size.x * 0.06)
	if texture == null:
		return inset
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return inset
	var scale: float = minf(inset.size.x / texture_size.x, inset.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale
	var draw_position: Vector2 = inset.position + (inset.size - draw_size) * 0.5
	return Rect2(draw_position, draw_size)


func _hp_bar_ops(cell_rect: Rect2, occupant: Dictionary) -> Array:
	var max_hp: int = int(occupant.get("max_hp", 0))
	if max_hp <= 0:
		return []
	var current_hp: int = clampi(int(occupant.get("current_hp", 0)), 0, max_hp)
	var bar_height: float = maxf(3.0, cell_rect.size.y * 0.09)
	var bar_margin: float = cell_rect.size.x * 0.1
	var bar_width: float = cell_rect.size.x - bar_margin * 2.0
	if bar_width <= 0.0:
		return []
	var bar_top: float = cell_rect.position.y + cell_rect.size.y - bar_height - 2.0
	var background: Rect2 = Rect2(cell_rect.position.x + bar_margin, bar_top, bar_width, bar_height)
	var fill_width: float = bar_width * (float(current_hp) / float(max_hp))
	var fill: Rect2 = Rect2(background.position, Vector2(fill_width, bar_height))
	return [
		_fill_op(background, HP_BAR_BG_COLOR),
		_fill_op(fill, HP_BAR_FILL_COLOR)
	]


# Story 14.1 (F8) — the corpse/loot-marker decal for a DEAD occupant. It draws the fallen unit as a DESATURATED,
# FLATTENED footprint (short + wide, hugging the cell floor — a distinct SHAPE vs. the tall living portrait) plus a
# dark marker outline, and deliberately NO HP bar and NO bright friend/foe border. The shape + desaturation are the
# non-color channel (NFR9) so a corpse never reads as a live unit. Uses the enemy art (grayed) when available, else a
# flat fill.
func _corpse_decal_ops(cell_rect: Rect2, occupant: Dictionary) -> Array:
	var ops: Array = []
	var footprint: Rect2 = Rect2(
		cell_rect.position.x + cell_rect.size.x * 0.12,
		cell_rect.position.y + cell_rect.size.y * 0.52,
		cell_rect.size.x * 0.76,
		cell_rect.size.y * 0.36
	)
	if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
		return ops
	var sprite: Texture2D = _enemy_texture(String(occupant.get("definition_id", "")))
	if sprite != null:
		ops.append(_texture_op(footprint, sprite, CORPSE_MODULATE))
	else:
		ops.append(_fill_op(footprint, CORPSE_FILL_COLOR))
	# The loot-marker channel: a dark outline around the fallen footprint (distinct from the live hero/enemy borders).
	ops.append(_outline_op(footprint, CORPSE_OUTLINE_COLOR, 2.0))
	return ops


func _terrain_texture(terrain: int) -> Texture2D:
	match terrain:
		BoardCell.Terrain.WALL:
			return _texture(TILE_TEXTURE_PATHS["wall"])
		BoardCell.Terrain.HAZARD:
			return _texture(TILE_TEXTURE_PATHS["hazard"])
		BoardCell.Terrain.ENTRANCE:
			return _texture(TILE_TEXTURE_PATHS["entrance"])
		BoardCell.Terrain.EXIT:
			return _texture(TILE_TEXTURE_PATHS["exit"])
		_:
			return _floor_texture()


# The floor tile IS the affinity treatment on an affinity level (a full-tile floor variant, not an overlay —
# the manifest v0 posture); a neutral / unknown affinity uses the plain floor. The affinity id is the SEPARATE
# LiveAffinityReadModel surface (_affinity_id), never a board-VM key.
func _floor_texture() -> Texture2D:
	var affinity_key: String = String(_affinity_id)
	if AFFINITY_TEXTURE_PATHS.has(affinity_key):
		var affinity_texture: Texture2D = _texture(AFFINITY_TEXTURE_PATHS[affinity_key])
		if affinity_texture != null:
			return affinity_texture
	return _texture(TILE_TEXTURE_PATHS["floor"])


func _hero_texture() -> Texture2D:
	var class_id: String = "" if _run == null else String(_run.selected_class_id)
	if CLASS_TEXTURE_PATHS.has(class_id):
		return _texture(CLASS_TEXTURE_PATHS[class_id])
	# An unknown / kit-less class still reads as the hero (the marker + HP bar carry the non-color channel).
	return _texture(CLASS_TEXTURE_PATHS["warrior"])


func _enemy_texture(definition_id: String) -> Texture2D:
	if ENEMY_TEXTURE_PATHS.has(definition_id):
		return _texture(ENEMY_TEXTURE_PATHS[definition_id])
	return null


func _terrain_fallback_color(terrain: int, visibility: String) -> Color:
	var color: Color = TERRAIN_FALLBACK_COLORS.get(terrain, TERRAIN_FALLBACK_COLORS[BoardCell.Terrain.FLOOR])
	if visibility == "memory":
		color = color * MEMORY_MODULATE
		color.a = 1.0
	return color


# Resolve an approved-art texture DEFENSIVELY: cached, guarded by ResourceLoader.exists so an un-imported dev
# checkout returns null (the caller draws a fallback) instead of erroring. Never called during the headless
# compile guardrail (render() needs a SceneTree), so it never touches the machine-local import cache in tests.
func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache.get(path)
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			texture = loaded
	_texture_cache[path] = texture
	return texture


func _fill_op(rect: Rect2, color: Color) -> Dictionary:
	return {
		"kind": "fill",
		"rect": rect,
		"color": color
	}


func _texture_op(rect: Rect2, texture: Texture2D, modulate: Color) -> Dictionary:
	return {
		"kind": "texture",
		"rect": rect,
		"texture": texture,
		"modulate": modulate
	}


func _outline_op(rect: Rect2, color: Color, width: float) -> Dictionary:
	return {
		"kind": "outline",
		"rect": rect,
		"color": color,
		"width": width
	}


# --- Story 13.2: the post-victory reward HUD (an ADDITIVE overlay; the resolving click routes to the shell) -------

# Enter reward mode: bind the run (whose pending_reward_offer this renders) + the shell's resolution callback, reset
# the two-step commit flow, build the overlay if needed, and render the offer. Called by the hosting shell after a
# live VICTORY generates a reward offer.
func show_reward_offer(run: RunState, on_reward_resolution: Callable = Callable()) -> void:
	_run = run
	_on_reward_resolution = on_reward_resolution
	_passive_commit_flow = PassiveRewardCommitFlow.new()
	_reward_active = true
	_ensure_reward_overlay()
	render_reward()


# Leave reward mode: hide the overlay (the offer resolved; the shell advances to the route map).
func hide_reward_offer() -> void:
	_reward_active = false
	if _reward_overlay != null:
		_reward_overlay.visible = false


# Render the pending offer into the overlay (a pure projection of run.pending_reward_offer via RewardHudViewModel). A
# null/absent/resolved offer renders the empty state (the overlay hides) — never a crash. Rebuilds the clickable
# controls on each explicit render (no per-frame work). Reused by the shell to re-render on an inventory_full reject.
func render_reward() -> void:
	if not _reward_active or _reward_overlay == null:
		return
	var offer: RewardOffer = _run.pending_reward_offer if _run != null else null
	var projection: Dictionary = RewardHudViewModel.new().project(offer)
	_clear_reward_box()
	if not bool(projection.get("has_offer", false)):
		# No pending offer -> nothing to render (the shell owns the advance).
		_reward_overlay.visible = false
		return
	_reward_overlay.visible = true
	_add_reward_label(String(projection.get("prompt", "")), true)
	if bool(projection.get("is_passive", false)):
		_build_passive_reward_ui(projection)
	else:
		_build_generic_reward_ui(projection)


# Build the overlay lazily: a full-rect Panel (mouse-filter STOP so it captures the tap + blocks board input while the
# reward is up) hosting a centered VBox. Added last so it draws ON TOP of the board grid.
func _ensure_reward_overlay() -> void:
	if _reward_overlay != null:
		return
	_reward_overlay = Panel.new()
	_reward_overlay.name = "reward_overlay"
	_reward_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_reward_overlay)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_reward_overlay.add_child(margin)
	_reward_box = VBoxContainer.new()
	_reward_box.name = "reward_box"
	_reward_box.add_theme_constant_override("separation", 8)
	margin.add_child(_reward_box)
	_reward_overlay.visible = false


# A GENERIC single-pick offer: show the reward + a single Accept button (drives ResolveRewardCommand on the shell).
func _build_generic_reward_ui(projection: Dictionary) -> void:
	var choices: Array = projection.get("choices", [])
	if choices.is_empty():
		return
	var choice: Dictionary = choices[0]
	_add_reward_label("Reward: %s" % String(choice.get("label", "")), false)
	var accept: Button = _reward_button("Accept reward")
	var category: String = String(choice.get("category", ""))
	var content_id: String = String(choice.get("content_id", ""))
	accept.pressed.connect(func() -> void:
		_emit_reward_resolution({
			"action": "resolve_generic",
			"category": category,
			"content_id": content_id
		}))
	_reward_box.add_child(accept)


# A PASSIVE 3-choice offer: when nothing is armed, list each passive's modal text with Consume/Destroy buttons (the
# FIRST tap ARMS); when a choice is armed, show a Confirm (the SECOND, committing tap) + Cancel (zero-mutation back-out).
func _build_passive_reward_ui(projection: Dictionary) -> void:
	var flow_state: Dictionary = _passive_commit_flow.to_dictionary()
	if String(flow_state.get("pending_choice", PassiveRewardCommitFlow.CHOICE_NONE)) != PassiveRewardCommitFlow.CHOICE_NONE:
		_build_passive_confirm_ui(flow_state)
		return
	var table_id: String = String(projection.get("table_id", ""))
	for choice_value: Variant in projection.get("choices", []):
		var choice: Dictionary = choice_value
		var content_id: String = String(choice.get("content_id", ""))
		_add_reward_label(_passive_choice_text(choice), false)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var consume_btn: Button = _reward_button("Consume")
		consume_btn.pressed.connect(_on_passive_arm.bind(PassiveRewardCommitFlow.CHOICE_CONSUME, content_id, table_id))
		var destroy_btn: Button = _reward_button("Destroy")
		destroy_btn.pressed.connect(_on_passive_arm.bind(PassiveRewardCommitFlow.CHOICE_DESTROY, content_id, table_id))
		row.add_child(consume_btn)
		row.add_child(destroy_btn)
		_reward_box.add_child(row)


# The armed-choice confirm step (the two-step second tap). The armed-vs-unarmed state carries a NON-COLOR channel:
# the button labels differ ("Consume"/"Destroy" -> "Confirm Consume/Destroy") and a distinct Cancel appears.
func _build_passive_confirm_ui(flow_state: Dictionary) -> void:
	var choice: String = String(flow_state.get("pending_choice", ""))
	var content_id: String = String(flow_state.get("passive_content_id", ""))
	_add_reward_label("Confirm %s of %s?" % [choice.capitalize(), content_id], false)
	var confirm_btn: Button = _reward_button("Confirm %s" % choice.capitalize())
	confirm_btn.pressed.connect(_on_passive_confirm)
	_reward_box.add_child(confirm_btn)
	var cancel_btn: Button = _reward_button("Cancel")
	cancel_btn.pressed.connect(_on_passive_cancel)
	_reward_box.add_child(cancel_btn)


# First tap: ARM the Consume/Destroy choice + re-render into the confirm step (mutates NOTHING — the arm is transient
# view state on PassiveRewardCommitFlow; no command runs until the confirming tap).
func _on_passive_arm(choice: String, content_id: String, table_id: String) -> void:
	if choice == PassiveRewardCommitFlow.CHOICE_CONSUME:
		_passive_commit_flow.arm_consume(StringName(content_id), StringName(table_id))
	else:
		_passive_commit_flow.arm_destroy(StringName(content_id), StringName(table_id))
	render_reward()


# Second (confirming) tap: COMMIT the two-step -> the intent routes to the shell (EXACTLY ONE of Consume/Destroy).
func _on_passive_confirm() -> void:
	var intent: Dictionary = _passive_commit_flow.confirm()
	if not bool(intent.get("committed", false)):
		render_reward()
		return
	_emit_reward_resolution({
		"action": "commit_passive",
		"committed": true,
		"choice": String(intent.get("choice", "")),
		"passive_content_id": String(intent.get("passive_content_id", "")),
		"table_id": String(intent.get("table_id", ""))
	})


# Cancel/back-out (AC2): un-arm with ZERO mutation (no command runs, the RunState is byte-identical) + re-render back
# to the choice list. Never notifies the shell.
func _on_passive_cancel() -> void:
	_passive_commit_flow.cancel()
	render_reward()


# The per-choice modal text (FR47/§8): the evocative name, the flavor, the EXACT mechanical effects, the Consume text,
# the Destroy text, and the honest-unknown downside — every field from the pinned MODAL_KEYS (text satisfies the ACs;
# icon art is optional). The honest-unknown flag carries a NON-COLOR channel (the "[unknown downside]" text marker).
func _passive_choice_text(choice: Dictionary) -> String:
	var modal: Dictionary = choice.get("modal", {})
	if not bool(modal.get("has_passive", false)):
		return String(choice.get("label", ""))
	var lines: Array[String] = [
		String(modal.get("display_name", "")),
		String(modal.get("flavor", "")),
		"Effect: %s" % String(modal.get("exact_mechanical_effects", "")),
		"Consume: %s" % String(modal.get("consume_text", "")),
		"Destroy: %s" % String(modal.get("destroy_text", ""))
	]
	if bool(modal.get("has_unknown_consequences", false)):
		lines.append("[unknown downside] %s" % String(modal.get("consequences_text", "")))
	return "\n".join(lines)


func _emit_reward_resolution(resolution: Dictionary) -> void:
	if _on_reward_resolution.is_valid():
		_on_reward_resolution.call(resolution)


# A reward button honoring the >=44x44 touch target (§14.1) on every layout profile.
func _reward_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44.0, 44.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


func _add_reward_label(text: String, is_header: bool) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_header:
		label.add_theme_font_size_override("font_size", 22)
	_reward_box.add_child(label)


# Detach + free the dynamic reward controls before a rebuild (remove_child detaches immediately so no duplicate
# accumulates; queue_free defers deletion safely past a button's own pressed-signal emission).
func _clear_reward_box() -> void:
	if _reward_box == null:
		return
	for child: Node in _reward_box.get_children():
		_reward_box.remove_child(child)
		child.queue_free()
