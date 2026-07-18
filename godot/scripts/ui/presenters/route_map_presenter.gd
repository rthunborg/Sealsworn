extends Control

# Story 11.3 (AC1/AC2) — the ROUTE-MAP presenter. It READS the RouteMapViewModel (the G2 projection — the
# reveal-gated eligible_choice_ids(), the current/cleared nodes, per-node type/reveal_state/depth/links/clues)
# and REPORTS the picked node to the flow: it submits the route-advance through the RunOrchestrator
# (RouteAdvanceCommand via advance_to) — the map owns NO route truth; the domain owns it. On picking a combat/
# elite node it navigates to the tactical-board stage (the live node plays there); a non-combat node resolves
# in place through the orchestrator's live resolver and re-renders the map. A run parked at the boss terminus
# navigates to the tactical board (the boss fight).
#
# Node TYPE is shown via an icon marker + label (not color-only); reveal state via a pattern/label prefix (the
# appendix §5.4 non-color channels) — the presenter MAPS the G2 fields to visuals, it invents no vocabulary.
# Verified BY CONSTRUCTION (it reads pinned G2 keys, submits through the orchestrator advance seam); the TESTABLE
# logic is in RouteMapViewModel + RunOrchestrator, both unit-tested.
#
# ⭐ Story 14.6 (F12; AC1/AC2) — ENRICH the render so the now-reachable map conveys real forward progression:
# the current position ("you are here"), the cleared/total progress, the pickable forward choices, and the
# terminal boss goal — all from the pinned RouteMapViewModel render-fact accessors (pure reads; the projection
# owns the facts), all via the non-color glyph/marker/HUMAN-display-label channels (never raw snake_case; NFR9).
# It also makes a REJECTED pick VISIBLE (the F3 "no silent rejection" close). It changes NO domain/command/event/
# RNG/save file and does NOT touch the load-bearing boss-terminus / terminal / current_node_needs_board()
# early-returns (the depth-0 opener still routes straight to the board — the resolve-then-advance invariant).

const RouteMapViewModel = preload("res://scripts/ui/view_models/route_map_view_model.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# The node types that play a LIVE tactical board (combat / elite) — picking one navigates to the board stage.
const LIVE_BOARD_NODE_TYPES: Array[String] = ["combat", "elite_combat", "boss"]

# Story 14.6 (AC1): the single MVP boss's descent-goal flavor name — the visible descent goal on the map. The
# projection carries the terminal node as type == "boss"; the presenter maps the name (display-only glue, the
# same flavor the boss-terminus status line uses — the presenter maps display vocabulary, it invents no truth).
const BOSS_DISPLAY_NAME := "The Larval Avatar"

var _choices_container: VBoxContainer = null
var _status_label: Label = null

func _ready() -> void:
	_build_layout()
	# Story 13.1 (AC3) — emit the "route map entered" diagnostics line BEFORE _render_map(). On a fresh run
	# _render_map() takes the resolve-then-advance branch and synchronously navigates away
	# (SceneManager.go_to_stage -> change_scene_to_file removes THIS scene from the tree mid-_ready), so probing
	# has_node("/root/Diagnostics") AFTER the render would run out-of-tree and print an engine ERROR. The
	# diagnostics intent ("route map entered") is already true here, before the render. The other in-tree
	# Diagnostics calls in this presenter (the _on_choice_picked handler) stay put — they run in-tree.
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"route_map_ready", {})
	_render_map()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	var title: Label = Label.new()
	title.text = "The Descent — Choose Your Path"
	root.add_child(title)

	_status_label = Label.new()
	root.add_child(_status_label)

	_choices_container = VBoxContainer.new()
	_choices_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_choices_container)


func _render_map() -> void:
	for child: Node in _choices_container.get_children():
		child.queue_free()

	var flow: RunFlowController = _flow()
	if flow == null or flow.run() == null:
		_status_label.text = "No active run."
		return
	var run: RunState = flow.run()

	# If the run parked at the boss terminus, navigate to the board for the boss fight.
	if flow.orchestrator().boss_encounter_pending():
		_status_label.text = "The Larval Avatar awaits."
		if has_node("/root/SceneManager"):
			SceneManager.go_to_stage("tactical_board")
		return

	# A terminal run routes to the run-end return.
	if run.is_terminal():
		_route_to_run_end(flow)
		return

	# ⭐ RESOLVE-THEN-ADVANCE (the H1 fix): if the run is parked on an UNRESOLVED live node (the depth-0 opening
	# combat node on a fresh run, or any current combat/elite node not yet cleared), it must be PLAYED on a
	# board BEFORE the map offers the next choices — mirroring run_to_completion_live's resolve-current-then-
	# advance order. Offering eligible_choice_ids() here would let RouteAdvanceCommand silently SEAL the
	# unplayed current node into cleared_node_ids. Route to the board first (the shell plays it, then returns
	# to this map with the node cleared + the successors revealed). The shared seam owns this decision.
	if flow.current_node_needs_board():
		_status_label.text = "A foe blocks the path — stand and fight."
		if has_node("/root/SceneManager"):
			SceneManager.go_to_stage("tactical_board")
		return

	# ⭐ Story 14.6 (AC1): the ENRICHED render — hold the VM OBJECT (not just its dict) so the new render-fact
	# accessors are callable. The map now conveys real forward progression: current position + cleared progress +
	# the pickable forward choices + the terminal boss goal, all non-color (glyph / reveal marker / human label).
	var view_model: RouteMapViewModel = RouteMapViewModel.from_route(run.route)
	var projection: Dictionary = view_model.to_dictionary()
	var eligible: Array = projection.get("eligible_choice_ids", [])

	# Cleared / total progress (the numerator / denominator, now behind the render-fact accessors).
	_status_label.text = "Cleared %d / %d" % [view_model.cleared_count(), view_model.node_count()]

	# "You are here" — the current position (a non-color glyph + human display label + depth).
	var current: Dictionary = view_model.current_node()
	if not current.is_empty():
		var here_label: Label = Label.new()
		here_label.text = "You are here: %s %s (depth %d)" % [
			_type_icon(String(current.get("type", ""))),
			_display_type(String(current.get("type", ""))),
			int(current.get("depth", 0))
		]
		_choices_container.add_child(here_label)

	# The pickable forward choices — one >=44px button per eligible id (glyph + reveal marker + human label +
	# depth + clue chips). Built from eligible_choice_ids() so a normal click is always selection-legal.
	var nodes_by_id: Dictionary = {}
	for node: Variant in projection.get("nodes", []):
		nodes_by_id[String((node as Dictionary).get("id", ""))] = node

	for choice_id_value: Variant in eligible:
		var choice_id: String = String(choice_id_value)
		var node: Dictionary = nodes_by_id.get(choice_id, {})
		var button: Button = Button.new()
		button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
		button.text = _node_label(node)
		button.pressed.connect(_on_choice_picked.bind(choice_id))
		_choices_container.add_child(button)

	# The terminal boss — the visible descent goal (shown whenever the projection carries a boss node).
	var boss: Dictionary = view_model.boss_node()
	if not boss.is_empty():
		var goal_label: Label = Label.new()
		goal_label.text = "Final: %s %s (depth %d)" % [
			_type_icon(String(boss.get("type", ""))),
			BOSS_DISPLAY_NAME,
			int(boss.get("depth", 0))
		]
		_choices_container.add_child(goal_label)


# Node label: a TYPE icon glyph + HUMAN display label + reveal marker + clue chips (non-color channels —
# icon/label/pattern). Story 14.6 (AC1/NFR9): the label is a human display label (_display_type), NEVER the raw
# snake_case node type — the epic-wide "human display text, not raw snake_case" readability posture.
func _node_label(node: Dictionary) -> String:
	var node_type: String = String(node.get("type", ""))
	var icon: String = _type_icon(node_type)
	var reveal_marker: String = _reveal_marker(String(node.get("reveal_state", "")))
	var clue_text: String = _clue_chips(node.get("clues", []))
	return "%s %s %s (depth %d)%s" % [icon, reveal_marker, _display_type(node_type), int(node.get("depth", 0)), clue_text]


# Story 14.6 (AC1/NFR9): convert a raw snake_case node type to a human display label (elite_combat -> "Elite
# Combat"; combat -> "Combat"). Display-only glue verified by construction, matching the _type_icon /
# _reveal_marker precedent. String.capitalize() replaces underscores with spaces + title-cases each word.
func _display_type(node_type: String) -> String:
	if node_type.is_empty():
		return "Unknown"
	return node_type.capitalize()


# Story 14.6 (AC1/NFR9): the clue tags as human display chips (Title Case — never raw snake_case). "" when none.
func _clue_chips(clues: Array) -> String:
	if clues.is_empty():
		return ""
	var labels: PackedStringArray = PackedStringArray()
	for clue: Variant in clues:
		labels.append(String(clue).capitalize())
	return "  [%s]" % ", ".join(labels)


func _type_icon(node_type: String) -> String:
	match node_type:
		"combat": return "[⚔]"
		"elite_combat": return "[⚔⚔]"
		"boss": return "[☠]"
		"shop": return "[$]"
		"reforge": return "[⚒]"
		"gambling": return "[?]"
		"event": return "[!]"
		"secret": return "[✦]"
		_: return "[•]"


func _reveal_marker(reveal_state: String) -> String:
	match reveal_state:
		"revealed": return "◆"
		"cleared": return "✓"
		_: return "◇"


func _on_choice_picked(choice_id: String) -> void:
	var flow: RunFlowController = _flow()
	if flow == null or flow.run() == null:
		return
	var orchestrator: RunOrchestrator = flow.orchestrator()
	var advance = orchestrator.advance_to(choice_id)
	if advance.is_error():
		# ⭐ Story 14.6 (AC2): a rejected pick FAILS CLOSED with a VISIBLE on-screen cue (the F3 "no silent
		# rejection" close) IN ADDITION to the diagnostics line. The domain guard (RouteAdvanceCommand) already
		# returns ineligible_route_choice with ZERO mutation on a hidden/cleared/not-linked/wrong-phase pick;
		# 14.6 only makes the refusal visible. Keep the early return — no navigation, no mutation.
		_status_label.text = _advance_reject_cue(String(advance.error_code))
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"route_map_advance_rejected", {
				"choice_id": choice_id,
				"error_code": String(advance.error_code)
			})
		return

	# Determine the picked node type: a live-board node -> the tactical board stage; else resolve in place.
	var picked: RouteNode = orchestrator.run.route.node_by_id(choice_id)
	var picked_type: String = String(picked.type) if picked != null else ""
	if LIVE_BOARD_NODE_TYPES.has(picked_type):
		if has_node("/root/SceneManager"):
			SceneManager.go_to_stage("tactical_board")
		return

	# A non-combat node resolves live in place (placeholder round-trip), then re-render the map.
	var resolved = orchestrator.resolve_current_node_live()
	if resolved.is_error():
		# ⭐ Story 14.6 (AC2): fail LOUD-VISIBLE here too. This placeholder round-trip should not fail, but the
		# epic posture is a visible cue over a silent stall.
		_status_label.text = "The path could not be resolved. Choose another."
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"route_map_resolve_rejected", {"error_code": String(resolved.error_code)})
		return
	_render_map()


# Story 14.6 (AC2/NFR9): map a route-advance rejection code to a HUMAN, non-color cue line — never the raw
# snake_case code as the primary message. The choice buttons are built from eligible_choice_ids() so a normal
# click is always selection-legal; this cue is the defensive readability guarantee for a stale/raced pick (never
# a silent dead click). The default covers ineligible_route_choice (the expected reject) + any unmapped code.
func _advance_reject_cue(error_code: String) -> String:
	match error_code:
		"no_current_node": return "There is no path to take from here."
		"wrong_run_phase": return "You cannot choose a path right now."
		"no_active_run": return "There is no active run."
		_: return "That path is not open."


func _route_to_run_end(flow: RunFlowController) -> void:
	var destination: String = String(flow.run_end_outcome().get("next_destination", ""))
	if has_node("/root/SceneManager"):
		SceneManager.route_after_run_end(StringName(destination))


func _flow() -> RunFlowController:
	if not has_node("/root/GameSession"):
		return null
	return GameSession.run_flow() as RunFlowController
