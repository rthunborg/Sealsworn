extends "res://tests/unit/test_case.gd"

# Story 12.1 (AC1/AC3/AC4) — the INTERACTIVE combat-node seam on RunOrchestrator (begin_interactive_combat_node /
# finish_interactive_combat_node): the ON-SCREEN, tap-driven counterpart of the atomic resolve_combat_node_live, layered
# ADDITIVELY on top of the UNCHANGED auto-resolve driver.
#
# Covers:
#   - AC1/AC3 — a live combat node, SET UP through the interactive seam (begin_interactive_combat_node) and driven to
#           VICTORY by a scripted tap sequence through the InteractiveCombatSession, then FINISHED
#           (finish_interactive_combat_node) with the SAME post-fight resolution the auto-resolve path applies: the node
#           is CLEARED + EXITED (the run advances forward) and reports resolution == live_combat_victory.
#   - AC1/AC3 — the LIVE hero-death SOURCE through the interactive seam: a weak hero driven to a board DEFEAT, FINISHED,
#           auto-fires the run-end resolution (resolve_run_end(&"hero_death") -> PHASE_FAILED + run_failed cause
#           hero_death + next_destination == outpost); the run terminal, the node NOT cleared.
#   - AC3 — the resolve-then-advance seam: the interactive path resolves the depth-0 opening combat node BEFORE any route
#           advance (the depth-0 node is cleared by the interactive finish, never sealed unplayed by an advance).
#   - AC4 — the AUTO-RESOLVE default is byte-identical / unperturbed: resolve_combat_node_live still resolves
#           live_combat_victory, and the DEFAULT run_to_completion save-stream is byte-identical to a second run.
#   - AC4 — the invariants hold: RngStreamSet.required_streams() == 7 (no new RNG stream), and the DomainEvent.Type enum
#           tail is unchanged (the tap-loop reuses the existing move/attack/damage/outcome/run-end events, adds none).
#   - a non-terminal session is rejected by finish_interactive_combat_node (the caller must only finish a decided fight).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InteractiveCombatSession = preload("res://scripts/run/interactive_combat_session.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalPathQuery = preload("res://scripts/tactical/movement/tactical_path_query.gd")

const HERO_ID := &"hero"
# The 11.2 verified seed whose depth-0 combat start node a strong sword hero clears (the run advances past it).
const LIVE_SEED: int = 4242
const MAX_TAP_STEPS: int = 64

func run() -> Dictionary:
	_interactive_node_is_set_up_driven_to_victory_and_finished_clears_the_node()
	_interactive_defeat_finish_auto_fires_the_hero_death_source()
	_interactive_path_resolves_depth_0_before_any_route_advance()
	_finish_rejects_a_non_terminal_session()
	_begin_fails_closed_on_a_setup_error_and_leaves_the_run_recoverable()
	_auto_resolve_default_is_unperturbed_by_the_interactive_seam()
	_default_run_to_completion_is_byte_identical_to_a_second_run()
	_invariants_hold_no_new_stream_no_new_event()
	# Story 12.2 — the class-kit loadout (HP/weapon/support) threads through begin_interactive_combat_node.
	_begin_interactive_combat_node_threads_the_class_kit_loadout()
	return result()


# ---- AC1/AC3: set up -> tap-drive to victory -> finish clears + exits + advances ------------------

func _interactive_node_is_set_up_driven_to_victory_and_finished_clears_the_node() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "Setup: a fresh run is parked in ACTIVE_ROUTE on the start node.")
	var start_node_id: String = orchestrator.run.route.current_node_id
	var start_node: RouteNode = orchestrator.run.route.node_by_id(start_node_id)

	# SET UP the node for interactive play (the PRE-fight steps; the fight is NOT resolved yet).
	var setup: ActionResult = orchestrator.begin_interactive_combat_node(start_node)
	assert_true(setup.succeeded, "The interactive setup should succeed: %s" % setup.metadata)
	assert_equal(String(setup.metadata.get("resolution")), "interactive_combat_setup", "begin reports interactive_combat_setup (the setup, not a resolution).")
	var session: InteractiveCombatSession = setup.metadata.get("session")
	assert_true(session != null, "The setup hands back the live InteractiveCombatSession.")
	assert_true(setup.metadata.get("board") is BoardState, "The setup surfaces the live board for the render.")
	assert_true(setup.metadata.get("turn_state") != null, "The setup surfaces the live turn state for the render.")
	# The node is NOT yet cleared (the setup did not resolve it) and the run is still in NODE_RESOLUTION (entered, mid-fight).
	assert_false(orchestrator.run.route.cleared_node_ids.has(start_node_id), "The setup does NOT clear the node (the fight is not resolved).")
	assert_false(orchestrator.run.is_terminal(), "The setup leaves the run non-terminal (mid-fight).")

	# DRIVE the fight to VICTORY via a scripted tap sequence through the session's tap API.
	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_terminal() and session.is_victory(), "The scripted taps drive the fight to a real board VICTORY.")

	# FINISH the node with the SAME post-fight resolution the auto-resolve path applies (clear + exit -> advance).
	var finish: ActionResult = orchestrator.finish_interactive_combat_node(start_node, session)
	assert_true(finish.succeeded, "The interactive finish should succeed: %s" % finish.metadata)
	assert_equal(String(finish.metadata.get("resolution")), "live_combat_victory", "A finished interactive victory reports live_combat_victory (the SAME resolution the auto-resolve path reports).")
	# The node was CLEARED + EXITED: the run advanced back to ACTIVE_ROUTE, the start node is in the cleared set, non-terminal.
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "A finished victory clears + exits the node (back to ACTIVE_ROUTE).")
	assert_true(orchestrator.run.route.cleared_node_ids.has(start_node_id), "A finished victory clears the node (it joins cleared_node_ids).")
	assert_false(orchestrator.run.is_terminal(), "A finished interactive victory does NOT end the run (it advances forward).")
	assert_true(orchestrator.run.validate().succeeded, "The run stays structurally valid after a finished interactive victory.")


# ---- AC1/AC3: the LIVE hero-death SOURCE through the interactive finish ---------------------------

func _interactive_defeat_finish_auto_fires_the_hero_death_source() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var start_node_id: String = orchestrator.run.route.current_node_id
	var start_node: RouteNode = orchestrator.run.route.node_by_id(start_node_id)

	# SET UP with a weak (1 HP) dagger hero — the real enemy turns fell it on the board.
	var setup: ActionResult = orchestrator.begin_interactive_combat_node(start_node, 1, &"dagger")
	assert_true(setup.succeeded, "The weak-hero interactive setup should succeed: %s" % setup.metadata)
	var session: InteractiveCombatSession = setup.metadata.get("session")

	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_terminal() and session.is_defeat(), "The weak hero is DEFEATED on the board (a real board DEFEAT).")

	# FINISH -> the live hero-death SOURCE auto-fires the run-end resolution.
	var finish: ActionResult = orchestrator.finish_interactive_combat_node(start_node, session)
	assert_true(finish.succeeded, "A finished interactive defeat should resolve (auto-firing the run-end): %s" % finish.metadata)
	assert_equal(String(finish.metadata.get("resolution")), "live_combat_defeat", "A finished interactive defeat reports live_combat_defeat.")
	assert_true(bool(finish.metadata.get("run_failed")), "A finished defeat flags run_failed (the auto-fired hero-death source).")

	# The run is terminal in PHASE_FAILED with the hero_death cause + the outpost destination.
	assert_equal(orchestrator.run.phase, RunState.PHASE_FAILED, "A live hero death drives the run to PHASE_FAILED.")
	assert_true(orchestrator.run.is_terminal(), "The live-death run is terminal.")
	var run_failed: DomainEvent = orchestrator.run_failed_event()
	assert_true(run_failed != null, "The live death emits a run_failed event.")
	assert_equal(String(run_failed.payload.get("cause")), "hero_death", "The run_failed cause is hero_death (the auto-fired live source).")
	assert_equal(String(run_failed.payload.get("next_destination")), "outpost", "The run_failed routes to the outpost (FR32).")
	assert_equal(orchestrator.run_failed_cause(), "hero_death", "The orchestrator surfaces the hero_death cause.")
	assert_equal(orchestrator.run_end_destination(), "outpost", "The orchestrator surfaces the outpost destination.")
	# The node is NOT cleared (a dead hero ends the run).
	assert_false(orchestrator.run.route.cleared_node_ids.has(start_node_id), "A live DEFEAT does NOT clear the node (the death ends the run).")


# ---- AC3: resolve-then-advance (the depth-0 node is resolved before any route advance) ------------

func _interactive_path_resolves_depth_0_before_any_route_advance() -> void:
	# The 11.3 H1 lesson through the interactive seam: the guaranteed depth-0 opening combat node is RESOLVED (cleared)
	# by the interactive finish BEFORE the route advances — it is never sealed unplayed by a depth-1 pick. Prove the
	# depth-0 node starts unresolved (parked, cleared_node_ids empty) and ends CLEARED by the interactive finish, with the
	# run parked back on the SAME (now-cleared) depth-0 node (RouteAdvanceCommand has not moved off it).
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var depth_0_node_id: String = orchestrator.run.route.current_node_id
	assert_true(orchestrator.run.route.cleared_node_ids.is_empty(), "Setup: the depth-0 node starts UNRESOLVED (cleared_node_ids empty).")
	var depth_0_node: RouteNode = orchestrator.run.route.node_by_id(depth_0_node_id)
	assert_true(RouteNode.TYPE_COMBAT == depth_0_node.type or RouteNode.TYPE_ELITE_COMBAT == depth_0_node.type, "Setup: the depth-0 node is a live combat node (RouteGenerator guarantees depth-0 is combat).")

	var setup: ActionResult = orchestrator.begin_interactive_combat_node(depth_0_node)
	assert_true(setup.succeeded, "The depth-0 interactive setup should succeed.")
	var session: InteractiveCombatSession = setup.metadata.get("session")
	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_victory(), "The depth-0 fight resolves to a victory.")
	assert_true(orchestrator.finish_interactive_combat_node(depth_0_node, session).succeeded, "The depth-0 finish should succeed.")

	# The depth-0 node is CLEARED (resolved) and the run pointer is STILL on it (the advance has not sealed it unplayed).
	assert_true(orchestrator.run.route.cleared_node_ids.has(depth_0_node_id), "The interactive path CLEARS the depth-0 node (it is resolved before any advance).")
	assert_equal(orchestrator.run.route.current_node_id, depth_0_node_id, "The run pointer stays on the just-cleared depth-0 node (resolve-then-advance — the advance has not moved off it).")


func _finish_rejects_a_non_terminal_session() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var start_node: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
	var setup: ActionResult = orchestrator.begin_interactive_combat_node(start_node)
	assert_true(setup.succeeded, "Setup: the interactive setup should succeed.")
	var session: InteractiveCombatSession = setup.metadata.get("session")
	assert_false(session.is_terminal(), "Setup: the fresh session is not terminal (mid-fight).")

	# Finishing a NON-TERMINAL session is rejected (the caller must only finish a decided fight) — no node clear, no death.
	var finish: ActionResult = orchestrator.finish_interactive_combat_node(start_node, session)
	assert_true(finish.is_error(), "Finishing a non-terminal session is rejected.")
	assert_equal(finish.error_code, &"interactive_combat_not_terminal", "The reject uses the stable interactive_combat_not_terminal code.")
	assert_false(orchestrator.run.route.cleared_node_ids.has(orchestrator.run.route.current_node_id), "A rejected finish does NOT clear the node.")
	assert_false(orchestrator.run.is_terminal(), "A rejected finish does NOT end the run.")


# ---- Story 12.1 review: the SETUP-error contract the shell recovery routes off (M1-symmetric) -----

func _begin_fails_closed_on_a_setup_error_and_leaves_the_run_recoverable() -> void:
	# Story 12.1 review (M1-symmetric fix): begin_interactive_combat_node fail-CLOSES on a setup error, returning a
	# genuine ActionResult.is_error() (a stable error_code) and leaving the run NON-TERMINAL with the node NOT cleared —
	# the EXACT precondition under which the gameplay shell now mirrors the boss branch's _route_to_dead_end recovery
	# (a non-terminal run with no fight to drive would otherwise STRAND the player on the shell). This proves the seam the
	# shell keys its recovery off (setup.is_error()) behaves symmetrically to auto_play_boss_fight's error contract: a
	# structural error surfaces + STOPS with zero partial progression, so the shell's recovery routing is well-founded.
	# (Presenter routing itself is verified by construction + the compile guardrail — no SceneTree test per project rules;
	# this test pins the orchestrator-seam half the recovery depends on.)
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var start_node: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
	assert_false(orchestrator.run.is_terminal(), "Setup: the fresh run is non-terminal on the parked node.")
	assert_true(orchestrator.run.route.cleared_node_ids.is_empty(), "Setup: the parked node starts uncleared.")

	# A null node is a fail-closed setup error (the general invalid-input case the shell's setup.is_error() branch covers).
	var null_setup: ActionResult = orchestrator.begin_interactive_combat_node(null)
	assert_true(null_setup.is_error(), "A null combat node fails the interactive setup closed (the shell routes this to the dead-end).")
	assert_equal(null_setup.error_code, &"invalid_combat_node", "The null-node setup uses the stable invalid_combat_node code.")
	# Zero partial progression — the run is left exactly recoverable (non-terminal, node uncleared, still structurally valid):
	# this is why the shell mirrors the boss branch (_route_to_dead_end) instead of stranding — the run can be booted back
	# to the recovery landing, it did not silently advance or clear.
	assert_false(orchestrator.run.is_terminal(), "A failed setup leaves the run NON-TERMINAL (the recoverable-strand precondition the shell routes off).")
	assert_true(orchestrator.run.route.cleared_node_ids.is_empty(), "A failed setup clears NO node (zero partial progression).")
	assert_true(orchestrator.run.validate().succeeded, "A failed setup leaves the run structurally valid (recoverable).")

	# An unseated orchestrator (no active run) is likewise a fail-closed setup error (the no_active_run guard) — the shell's
	# setup.is_error() branch covers the same non-terminal strand class regardless of the specific upstream cause.
	var unseated: RunOrchestrator = RunOrchestrator.new()
	var unseated_setup: ActionResult = unseated.begin_interactive_combat_node(start_node)
	assert_true(unseated_setup.is_error(), "An unseated interactive setup fails closed (no active run).")
	assert_equal(unseated_setup.error_code, &"no_active_run", "The unseated setup uses the stable no_active_run code.")


# ---- AC4: the auto-resolve default is unperturbed by the interactive seam -------------------------

func _auto_resolve_default_is_unperturbed_by_the_interactive_seam() -> void:
	# The atomic resolve_combat_node_live (the auto-resolve/proof path) is UNCHANGED + still reachable: it resolves the
	# depth-0 combat node to live_combat_victory exactly as before the interactive seam existed.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var start_node: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
	var resolved: ActionResult = orchestrator.resolve_combat_node_live(start_node)
	assert_true(resolved.succeeded, "The atomic auto-resolve should still succeed: %s" % resolved.metadata)
	assert_equal(String(resolved.metadata.get("resolution")), "live_combat_victory", "resolve_combat_node_live still auto-resolves to live_combat_victory (the auto-resolve/proof path is unchanged).")


func _default_run_to_completion_is_byte_identical_to_a_second_run() -> void:
	# The DEFAULT run_to_completion save-stream is byte-identical across two independent runs of the same seed — the
	# interactive seam (a separate additive path) does NOT perturb the non-live stream advancement.
	var first_snaps: Array = _default_save_stream(LIVE_SEED)
	var second_snaps: Array = _default_save_stream(LIVE_SEED)
	assert_true(first_snaps.size() >= 1, "Setup: the default run composes at least one route-position save.")
	assert_equal(JSON.stringify(first_snaps), JSON.stringify(second_snaps), "The DEFAULT run_to_completion save-stream is byte-identical (the interactive seam does not perturb it).")


func _invariants_hold_no_new_stream_no_new_event() -> void:
	# AC4: the 12.1 tap-loop opens NO new RNG stream (the 7 named streams are invariant) and added no DomainEvent.Type
	# member. Story 14.1 later APPENDED exactly one event at the enum tail — HERO_WAITED (the F1 Wait/pass-turn backstop)
	# — so the enum is now 43 with HERO_WAITED at index 42; OATH_SHARDS_SPENT stays the Epic-11 tail at index 41 (the
	# append is tail-only, never renumbered).
	assert_equal(RngStreamSet.required_streams().size(), 7, "The 7 named RNG streams are invariant (14.1 draws ZERO RNG — no new stream).")
	assert_equal(int(DomainEvent.Type.size()), 43, "The DomainEvent.Type enum has 43 members (Story 14.1 appended HERO_WAITED at the tail).")
	assert_equal(int(DomainEvent.Type.OATH_SHARDS_SPENT), 41, "OATH_SHARDS_SPENT stays the Epic-11 tail at index 41 (14.1 appended AFTER it, not renumbering).")
	assert_equal(int(DomainEvent.Type.HERO_WAITED), 42, "HERO_WAITED is the 14.1 tail at index 42 (appended after OATH_SHARDS_SPENT).")


# ---- Story 12.2: the class-kit loadout threads through the interactive seam -----------------------

func _begin_interactive_combat_node_threads_the_class_kit_loadout() -> void:
	# begin_interactive_combat_node additively accepts the class-kit loadout (HP / weapon / support) and threads it into
	# the InteractiveCombatSession: the kit weapon becomes the session hero_weapon, and the kit support is SEATED on the
	# session (the on-screen taps inherit it). Proven with the warrior kit (sword + shield) on the canonical live seed.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false, &"warrior").succeeded, "Setup: start a warrior run should succeed.")
	var start_node: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
	var shield: SupportDefinition = SupportRepository.create_baseline_repository().get_support(&"shield")

	var setup: ActionResult = orchestrator.begin_interactive_combat_node(start_node, 18, &"sword", shield)
	assert_true(setup.succeeded, "The kit-loadout interactive setup should succeed: %s" % setup.metadata)
	var session: InteractiveCombatSession = setup.metadata.get("session")
	assert_true(session != null, "The setup hands back the session.")
	assert_equal(String(session.hero_weapon().weapon_id), "sword", "The session hero weapon is the kit weapon (sword).")
	assert_equal(String(session.loadout_support().support_id), String(SupportDefinition.SUPPORT_SHIELD), "The session SEATS the class-kit shield support (the taps inherit it).")


# ---- helpers -------------------------------------------------------------------------------------

func _default_save_stream(seed_value: int) -> Array:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	orchestrator.start(seed_value, false)
	var snaps: Array = []
	orchestrator.run_to_completion(func(snapshot): snaps.append(snapshot.to_dictionary()))
	return snaps


# Drive the session to a terminal outcome with a scripted tap sequence through its TAP API (submit_move / tap_attack) —
# the same scripted-hero discipline the auto-resolver uses, but routed through the interactive tap seam.
func _drive_scripted_taps_to_terminal(session: InteractiveCombatSession) -> void:
	var steps: int = 0
	while not session.is_terminal() and steps < MAX_TAP_STEPS:
		steps += 1
		var board: BoardState = session.board()
		var attack_target: TacticalEntityState = _first_attackable_enemy(board, session.hero_weapon())
		if attack_target != null:
			session.tap_attack(attack_target.position)
			session.tap_attack(attack_target.position)
			continue
		var step: Vector2i = _next_approach_step(board)
		if step == Vector2i(-1, -1):
			step = _any_legal_step(board)
		if step == Vector2i(-1, -1):
			break
		session.submit_move(step)


func _first_attackable_enemy(board: BoardState, weapon) -> TacticalEntityState:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return null
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		if AttackPreviewQuery.new().preview_target_cell(board, HERO_ID, entity.position, weapon).succeeded:
			return entity
	return null


func _next_approach_step(board: BoardState) -> Vector2i:
	var target: TacticalEntityState = _nearest_living_enemy(board)
	if target == null:
		return Vector2i(-1, -1)
	var approach: ActionResult = TacticalPathQuery.new().approach_path_to_adjacent_target(board, HERO_ID, target.entity_id)
	if approach.is_error():
		return Vector2i(-1, -1)
	var next_step: Dictionary = approach.metadata.get("next_step", {})
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	var step_cell: Vector2i = Vector2i(int(next_step.get("x", hero.position.x)), int(next_step.get("y", hero.position.y)))
	if step_cell == hero.position:
		return Vector2i(-1, -1)
	return step_cell


func _any_legal_step(board: BoardState) -> Vector2i:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var destination: Vector2i = hero.position + direction
		if board.can_occupy(destination, HERO_ID).succeeded:
			return destination
	return Vector2i(-1, -1)


func _nearest_living_enemy(board: BoardState) -> TacticalEntityState:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null:
		return null
	var best: TacticalEntityState = null
	var best_distance: int = 1 << 30
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		var distance: int = maxi(absi(entity.position.x - hero.position.x), absi(entity.position.y - hero.position.y))
		if distance < best_distance:
			best_distance = distance
			best = entity
	return best
