# Story 12.1: Interactive Combat Tap-Loop and Live Board Render

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to move, attack, and inspect on the live tactical board with my own taps,
so that I make the tactical decisions instead of watching an auto-resolved fight.

## Context and Scope Authority

This story was created by the 2026-07-07 sprint change proposal (`_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-07.md`, commit `3a8f3e3`) that inserted **Epic 12 (Interactive Tactical Combat)** between Epic 10's Stories 10.3 and 10.4. It closes the **Epic-11 retro T1 (interactive-combat tap-loop, HIGH) + the L4 live-board-render gap** — the "last piece of felt hands-on play" that Epic 10's 10.4 hands-on playtest and 10.6 "die or win" loop-gate implicitly depend on but which no story owned.

**Authoritative scope inputs (already folded into this file — do not re-derive):**
- `epics.md` Epic 12 / Story 12.1 (canonical ACs, lines 505-511 and 2831-2864).
- The run-flow UX appendix **§14** (layout + accessibility pass) and **§1/§2/§3** (`_bmad-output/planning-artifacts/ux-appendix-run-flow.md`) — the tap-interaction contract (first tap PREVIEWS, second tap COMMITS, ≥44px targets) already designed in Story 11.1.
- The Epic-11 retro T1/T2 + the 11.2/11.3 boundary rules (`_bmad-output/implementation-artifacts/epic-11-retro-2026-07-06.md` §8, §10, §7 items 1/4).
- `project-context.md` run-flow-scene-hud-rules (lines 450-456) — the load-bearing seam rules for this exact work.

**The one-sentence essence:** the tap seam ALREADY EXISTS and is correctly wired (`tactical_board_presenter.gd` exposes `submit_move` / `tap_attack` / `cancel_attack` / `inspect_cell` through the command bridge + `TacticalAttackCommitFlow`), but the gameplay shell AUTO-RESOLVES each live combat node in one atomic call (`resolve_combat_node_live` → the scripted focus-fire `LiveCombatResolver.resolve(...)`) and only ever renders the empty-board VM. **This story surfaces the live board on a combat node and drives it from the player's taps — a human replaces the scripted focus-fire driver — while the default hands-off auto-resolve driver stays available and byte-identical for the seed-batch/AC proofs.**

**NOT in this story (12.2's scope — do not do it here):** the class-kit → combat-loadout wiring, the "winnable by every class" reference driver, and the `project-context.md` revision of the 11.2 "class-kit → combat-loadout is a later story" boundary. This story keeps the driver-supplied loadout (`LiveCombatResolver.DEFAULT_HERO_HP` 60 / `DEFAULT_HERO_WEAPON` sword) exactly as 11.2/11.3 use it. See the "Explicit Non-Goals" section.

## Acceptance Criteria

**AC1 — the live board renders on a combat/elite node (closes the L4 gap).**
**Given** a run is parked on a `combat` or `elite_combat` node in the gameplay shell
**When** the node begins
**Then** the live board renders on-screen with hero, enemies, terrain, fog, and affinity treatments (closing the L4 no-`"board"`-key gap in live metadata — today `resolve_combat_node_live` returns terminal-only metadata whose `board` is the FINISHED board, so the in-run combat surface only ever renders the empty-board VM)
**And** the rendered board is a projection of the domain board — no scene node owns tactical truth.

**AC2 — the player drives move/attack/inspect via taps through the existing contracts.**
**Given** the live board is rendered and it is the player's turn
**When** the player taps a reachable tile, taps a valid attack target, or inspects
**Then** movement previews (FR8), attack previews (FR9/FR10), and inspect (FR12) surface through the EXISTING view-model and command-bridge contracts
**And** a first tap PREVIEWS and a second confirming tap COMMITS (FR11), with ≥44px targets, per the run-flow UX appendix §14
**And** committed actions submit the EXISTING commands through the command bridge — no parallel combat path.

**AC3 — resolve-then-advance is preserved; enemy/boss turns respond unchanged.**
**Given** a committed player action resolves
**When** enemy and boss turns respond
**Then** the EXISTING turn resolvers drive responses unchanged in ownership (`EnemyTurnResolver.resolve_after_player_action`; the boss path unchanged)
**And** the resolve-then-advance sequencing seam is preserved (the node resolves before any route advance — the 11.3 H1 lesson; the shared `RunFlowController.current_node_needs_board()` seam stays the single source of the "host on a board first" decision).

**AC4 — testable in RefCounted seams; the default auto-resolve path stays byte-identical.**
**Given** the headless suite and seed regressions run
**When** the tap-loop lands
**Then** all tap-loop decision logic lives in `RefCounted` seams testable without a `SceneTree` (scene wiring verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail)
**And** the default hands-off auto-resolve driver remains available and byte-identical (every pinned fingerprint unchanged; no new autoload; no new RNG draw site).

## Tasks / Subtasks

- [ ] **Task 1 — Author the scene-free interactive-fight seam (the step-driven live-combat session).** (AC1, AC2, AC3, AC4)
  - [ ] Add a thin `RefCounted` interactive-fight session/driver (e.g. `godot/scripts/run/interactive_combat_session.gd` or `godot/scripts/ui/flow/interactive_combat_controller.gd`) that holds a LIVE fight in progress across taps. It must REUSE the SAME building blocks `LiveCombatResolver` composes — restore the board via the strict `BoardState.try_from_snapshot`, apply the affinity board effect (`AffinityEffectResolver.apply_board_effects`) BEFORE hero placement, place the hero at the generated entrance, drive ONE player action per tap through `TacticalCommandBridge`, run `EnemyTurnResolver.resolve_after_player_action` for the enemy phase, tick the Scorched DoT (`AffinityHazardDamageCommand` — the 11.4 discipline, gated on a Scorched plan), and re-evaluate `CombatOutcomeState` via `CombatOutcomeEvaluator` after each action. It is a STEP-DRIVEN session, not a one-shot resolve.
  - [ ] The session owns NO gameplay decision a command/orchestrator does not: it sequences the existing commands + resolvers and reads outcomes; it draws gameplay RNG ONLY through the run-level `streams` on the `combat` stream (via `AttackCommand`'s existing draws — the default sword hero draws ZERO combat RNG). No new RNG stream, no `randi()`/`randf()`, no fresh `RandomNumberGenerator`.
  - [ ] Fail-closed: an invalid/rejected player intent surfaces the command's own `disabled_result`/`ActionResult` reason (never a crash, never a fabricated outcome); a terminal `CombatOutcomeState` (VICTORY/DEFEAT) is the session's stop signal.
- [ ] **Task 2 — Wire the interactive loop into the orchestrator/flow WITHOUT replacing the auto-resolve path.** (AC1, AC3, AC4)
  - [ ] Provide the seam so the shell can (a) SET UP a live combat node (enter node + generate level + assign affinity once + darkness-fairness gate + seat Cursed rule source — the pre-fight steps `resolve_combat_node_live` already does) and (b) hand the live board + affinity id + fairness verdict to the interactive session, THEN (c) on a terminal outcome apply the SAME post-fight resolution `resolve_combat_node_live` applies: VICTORY → `NodeExitCommand` (clear + exit → advance), DEFEAT → the live hero-death source `resolve_run_end(&"hero_death")`. Reuse the existing orchestrator methods; do NOT fork a parallel node-resolution or a parallel death path.
  - [ ] Keep `resolve_combat_node_live` / `run_to_completion_live` / `auto_play_boss_fight` / `auto_play_full_run` / `LiveCombatResolver.resolve(...)` UNCHANGED and reachable — they are the headless hands-off/auto-play seam the seed-batch/AC proofs and `test_live_run_flow.gd` / `test_live_affinity_flow.gd` drive. The interactive path is the ON-SCREEN path; the auto-resolve driver is the test/proof driver. Do NOT touch the DEFAULT `run_to_completion` (the fingerprint-preserving v0 auto-resolve).
- [ ] **Task 3 — Drive the interactive loop from the gameplay shell + board presenter.** (AC1, AC2, AC3)
  - [ ] `gameplay_shell_presenter.gd` (`_drive_current_stage`): for a `combat`/`elite_combat` node, SET UP the node, RENDER the live board via `_render_live_board(...)` (already present), then AWAIT the player's taps instead of calling the atomic `resolve_combat_node_live`. The board presenter's `submit_move` / `tap_attack` / `inspect_cell` route each tap into the interactive session; after each committed action the shell re-renders and, on a terminal outcome, routes: VICTORY → `_advance_to_route_map()`; DEFEAT → `_route_to_run_end(flow)`.
  - [ ] The `_render_live_board` bind must carry the LIVE turn state (whose turn / turn number) and the live board mutated in place, not a throwaway `PLAYER_PLANNING` stub — the HUD's turn slot + `action_availability` must reflect the real turn so preview/commit/inspect gate correctly.
  - [ ] Preserve the boss path (`boss_encounter_pending()` → `auto_play_boss_fight`) and the non-combat placeholder path unchanged. Preserve `current_node_needs_board()` as the single "host on a board first" decision (route-map + shell both read it) — the resolve-then-advance seam (AC3, the 11.3 H1 fix).
  - [ ] The board presenter already reads the VM's pinned keys ONLY and submits through the bridge; do NOT add a board-VM key or a parallel presentation path. The two-step commit is `TacticalAttackCommitFlow` (arm → confirm) exactly as `tap_attack` already uses it; move commits via a `move` bridge intent (a symmetric move-confirm is a presentation-flow CHOICE, not a required new VM — appendix §2.2 note / §16.1).
- [ ] **Task 4 — Tests: RefCounted seam coverage + the scene compile guardrail.** (AC1, AC2, AC3, AC4)
  - [ ] Add a headless unit test for the interactive-fight session under `godot/tests/unit/run/` or `godot/tests/unit/ui/` (auto-discovered — the runner recursively walks `res://tests/unit` + `res://tests/integration` for `test_*.gd`; NO manifest edit needed). Prove: a scripted sequence of tap intents drives a generated combat board to VICTORY (node cleared + exited + run advanced) and to DEFEAT (live hero-death source fires → `PHASE_FAILED` + cause `hero_death` + `next_destination == outpost`); an invalid tap is a fail-closed no-mutation reject; the enemy phase runs via `EnemyTurnResolver` after each committed action; the terminal outcome is read from `CombatOutcomeState`.
  - [ ] Prove the resolve-then-advance seam: the interactive path resolves the depth-0 opening combat node before any route advance (mirroring `test_live_run_flow.gd`'s domain-driver assertions but through the interactive seam — test the SHARED sequencing seam, not just the domain driver; the 11.3 H1 lesson).
  - [ ] Prove the AUTO-RESOLVE default path is byte-identical / unperturbed: `resolve_combat_node_live` / `run_to_completion_live` still resolve `live_combat_victory` and the DEFAULT `run_to_completion` save-stream is byte-identical to a second run (extend / mirror `test_live_run_flow.gd::_default_run_to_completion_is_unperturbed_by_the_live_loop`). Prove no new RNG stream (`RngStreamSet.required_streams()` == 7) and no new `DomainEvent.Type` member (the enum tail is unchanged — the tap-loop reuses the existing move/attack/damage/outcome/run-end events).
  - [ ] Register the interactive session's scene/presenter wiring in the `test_run_flow_scenes_load.gd` compile guardrail if any NEW `.tscn`/presenter is added; otherwise confirm the existing guardrail still covers `gameplay_shell.tscn` + `tactical_board.tscn`.
- [ ] **Task 5 — Run the full headless suite + the false-PASS grep guard + `git diff --check`.** (AC4)
  - [ ] `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` (see "How to run tests" for the machine-specific invocation). Suite must be green (baseline **185 PASS / 0 FAIL, ~49s** as of Story 10.8 / PR #61) — this story ADDS tests; the new count must be ≥ 185 with 0 `^FAIL`.
  - [ ] Grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL` (never trust the summary PASS line alone); confirm exactly the 6 documented stderr negatives (int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1) and NO new documented negative. `git diff --check` clean.

## Dev Notes

### The exact seam map (READ THESE FILES — they are the whole story)

| File | What it is today | What 12.1 does |
|---|---|---|
| `godot/scripts/ui/presenters/tactical_board_presenter.gd` | ALREADY exposes the tap seam: `submit_move(context, actor_id, target_cell, movement_budget)`, `tap_attack(context, actor_id, target_cell, weapon, ...)` (two-step via `TacticalAttackCommitFlow`), `cancel_attack()`, `inspect_cell(context, target_cell)`. Renders the `TacticalBoardViewModel` pinned keys into the region→slot map (appendix §1.2); reads the G1 `RunHudViewModel` + `LiveAffinityReadModel`. `bind_live_state(board, turn_state, run, text_scale, affinity_id, fairness)` sets the live inputs. | Drive these EXISTING methods from real player taps (the human replaces the scripted focus-fire driver). Bind the LIVE (mutated-in-place) turn state, not a throwaway `PLAYER_PLANNING` stub. Do NOT add a board-VM key or a parallel path. |
| `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` | `_drive_current_stage()`: for a combat/elite node calls the ATOMIC `resolve_combat_node_live(current, flow.hero_hp())`, then `_render_live_board(...)` on the FINISHED board, then routes. `_render_live_board` already renders when `resolved.metadata.get("board") is BoardState`. `_render_between_levels` renders the empty VM (`board == null`). | Split the combat-node branch: SET UP the node → RENDER the live board → AWAIT taps (drive the interactive session) → on terminal outcome route (VICTORY→route_map, DEFEAT→run_end). Keep the boss + placeholder branches unchanged. |
| `godot/scripts/run/run_orchestrator.gd` (`resolve_combat_node_live`, ~967-1095) | The ATOMIC auto-resolve: enter node → generate level → assign affinity ONCE (assign-if-absent guard) → darkness-fairness gate (`_check_darkness_fairness_live`) → seat Cursed rule source → `LiveCombatResolver.new(...).resolve(...)` to a TERMINAL outcome → VICTORY: `NodeExitCommand` (clear+exit); DEFEAT: `resolve_run_end(&"hero_death")`. Returns terminal-only metadata (`board` = FINISHED board). | Provide a seam so the shell can run the PRE-fight steps (enter/generate/assign/fairness/seat), hand the live board to the interactive session, and apply the SAME POST-fight resolution on a terminal outcome. Keep `resolve_combat_node_live` UNCHANGED + reachable (the auto-resolve/proof path). |
| `godot/scripts/run/live_combat_resolver.gd` | The scene-free SCRIPTED-hero one-shot driver: places hero at entrance, applies affinity, runs the focus-fire loop (`_drive_hero_turn` → `EnemyTurnResolver.resolve_after_player_action` → Scorched DoT → `CombatOutcomeEvaluator._evaluate`) to a terminal `CombatOutcomeState`. `DEFAULT_HERO_HP = 60`, `DEFAULT_HERO_WEAPON = sword`, `HERO_MOVE_BUDGET = 3`, `MAX_ROUNDS = 64`. Exposes `drive_hero_step_against(...)` (single-step, reused by boss auto-play) + `hero_weapon(weapon_id)`. | This is your BLUEPRINT for the interactive session — reuse the SAME building blocks (board restore, affinity apply, hero placement, per-action enemy phase, Scorched DoT, outcome eval) but STEP-DRIVEN by taps instead of the scripted loop. Keep `LiveCombatResolver` UNCHANGED (the auto-play seam still uses it). |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | `build_command(context, intent)` / `execute_intent(context, intent)`. Intents: `move` `{intent_id, actor_id, target_cell, movement_budget?}`, `attack` `{intent_id, actor_id, target_cell, weapon, attacker_support?, defender_support?}`, `inspect` `{intent_id, target_cell}`. Validates before mutation, returns `CommandBridgeResult` (`command_ready`/`disabled_result`/`metadata_only`). | The ONE submission seam. All committed player actions go through it (AC2 "no parallel combat path"). The board presenter's tap methods already call it. |
| `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` | The two-step attack commit: `tap_attack_target(...)` arms `attack_preview`; a second tap on the SAME target/weapon/actor calls `confirm_attack(...)` which builds the intent through the bridge and executes it. `cancel()` = zero mutation. | Already wired via `tactical_board_presenter.tap_attack`. First tap PREVIEWS, second COMMITS (AC2/FR11). |
| `godot/scripts/ui/flow/run_flow_controller.gd` | The scene-free run-flow sequencer. `current_node_needs_board()` = the SHARED resolve-then-advance seam (AC3). `hero_hp()` returns `LiveCombatResolver.DEFAULT_HERO_HP` (60) — the driver-supplied loadout, DELIBERATELY distinct from the class `baseline_hp`. `orchestrator()` exposes the orchestrator for per-node live resolution. | Sequence the interactive path here or keep the shell driving the orchestrator directly — either is fine as long as `current_node_needs_board()` stays the single resolve-then-advance decision. Keep `hero_hp()` as-is (loadout wiring is 12.2). |
| `godot/scripts/autoloads/scene_manager.gd` + `godot/scripts/ui/flow/run_flow_router.gd` | Stage routing: `go_to_stage("route_map"|"run_end"|...)`, `route_after_run_end(destination)`. `tactical_board` stage → `gameplay_shell.tscn`. Fail-closed on unknown stage/destination. | Reuse — no new stage needed. The interactive combat runs INSIDE the `tactical_board` (gameplay shell) stage. |

### Architecture rules this story MUST obey (project-context.md lines 450-456 — the run-flow-scene-hud-rules)

- **No SceneTree test for a presenter/`.tscn`** — the headless harness runs `script.new().run()` with NO SceneTree. Put all assertable tap-loop logic in a `RefCounted` seam with an exact contract and test THAT; the `.tscn`/`Control` wiring is verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail. Do NOT trust a prose "guarded accessor is wired" claim without grepping the probed method name against source (the 11.3 M2 dead-`has_method`-probe lesson).
- **No gameplay/run/combat decision logic in a presenter or flow seam** — presenters `Control`s + thin `RefCounted` seams OBSERVE domain outcomes and DELEGATE to the unchanged `RunOrchestrator`/`LiveCombatResolver`/commands. No scene node is authoritative for tactical/run truth. **Epic 12 adds NO autoload** (AC4).
- **Resolve-then-advance, in ONE place** — a combat node MUST be resolved before the route advances, or a depth-1 pick makes `RouteAdvanceCommand` SEAL the guaranteed depth-0 opening combat node unplayed (the 11.3 H1 divergence). Keep the ordering in `current_node_needs_board()`; when a presenter re-implements a sequence the domain already encodes, test the SHARED sequencing seam, not just the domain driver.
- **Hero HP is TWO concerns (do not conflate)** — the live driver uses `LiveCombatResolver.DEFAULT_HERO_HP` (60); `RunHudViewModel` displays the class `baseline_hp` between levels and the live board entity's `current_hp` during a fight. There is NO run-level HP field, NO in-node fight save (the 23-key `RunSnapshot` gate stays 23; the in-node fight stays EPHEMERAL). Do NOT arm the interactive driver with `StartingKit.baseline_hp` (warrior 18 — the hero dies on a full live walk); that loadout wiring is 12.2.
- **The additive opt-in affinity signature stays byte-identical** — `LiveCombatResolver.resolve(...)`'s `affinity_id`/`affinity_repository` default to neutral `none`/null; the affinity is applied POST-generation on a BUILT board (the generator stays affinity-blind, `WRINKLE_AFFINITY_PLACEHOLDER` INERT — fingerprints byte-identical). If the interactive session applies affinity effects, use the SAME `AffinityEffectResolver.apply_board_effects` call the resolver uses, on the built board, BEFORE hero placement. `resolve_combat_node_live` assigns the node's affinity ONCE (assign-if-absent guard — a re-drive never re-rolls the `map` stream); `LiveAffinityReadModel` REFLECTS the `DarknessFairnessQuery` verdict, never re-derives one. The boss arena carries NO affinity (by decision).
- **Do not silently close (nor pre-empt) the Epic-11 deferrals** — this story does NOT wire the class-kit → combat-loadout (12.2), the live `content_discovered` discovery source, the live in-node board/pending-fight SAVE, the run-level event STORE (so a summary render still keys victory/death off `phase`, NOT `outcome_or_cause`), the G4 settings view model, the Flooded electric-interaction `_placeholder`, or the affinity-driven GENERATION modifier.

### UX appendix §14 + §1/§2/§3 — the interaction contract (already designed, Story 11.1)

- **Two-step commit (FR11):** first tap PREVIEWS, second confirming tap COMMITS. Preview must read distinct from a committed action WITH color stripped — the non-color channels are `feedback_preview` (`[shape, label]`) vs `feedback_committed` (`[pattern, label, text]`) in `TacticalAccessibilityModel` (appendix §2.3). The `confirm_cancel` region binds `commit_flow.confirm_available`/`.cancel_available`; a confirm button cannot enable without an armed preview (flow-gated `action_availability.confirm`/`cancel`).
- **≥44×44 touch targets** on every profile (`DEFAULT_MINIMUM_TOUCH_TARGET = Vector2(44, 44)`); the board stays the dominant region; the four control bands (`preview`, `confirm_cancel`, `inspect`, `status`) stay reachable. Scenes honor the semantic `TacticalLayoutProfile` region plan (the testable source of truth) — never hardcoded geometry.
- **Preview data (read surfaces):** `TacticalMovementPreview.from_query(...)` (move, FR8) + `TacticalAttackPreview.from_query(...)` (attack, FR9/FR10) land in the board VM's `preview` slot. **Inspect (FR12):** `TacticalInspectView.from_context(...)` + the bridge `inspect` intent (metadata-only) across the three visibility tiers (`visible`/`memory`/`hidden`). The board presenter already composes all of these — you are wiring the LIVE turn to drive them, not authoring new surfaces.
- **Move commit note (§2.2 / §16.1 non-gap):** the two-step commit-flow VM is attack-specific; a move commits via a `move` bridge intent. A symmetric two-step move-confirm is a presentation-flow CHOICE for this story if desired — the appendix records it as a NON-gap, NOT a required new VM. Do not invent a move commit-flow VM.

### Test harness facts

- **Run command (project CLAUDE.md):** `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- **`godot` is NOT on the Bash/`where` PATH on this machine** — it resolves via PowerShell as `C:\Users\Rasmus\bin\godot.cmd`, OR run the binary directly: `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`. Run via PowerShell (`powershell.exe -NoProfile -Command ...`), not the Bash PATH lookup.
- **Test discovery is automatic** — `test_runner.gd` recursively walks `res://tests/unit` + `res://tests/integration` and runs every `test_*.gd` (except `test_case.gd`). A new test file under those trees needs NO manifest/registration edit.
- **False-PASS guard (standing gate):** grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL` — a reserved-name collision / compile failure can still print `PASS` on the summary line. Exactly 6 documented stderr negatives are expected (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1); this story must add ZERO new documented negative.
- **Baseline to preserve:** **185 PASS / 0 FAIL, ~49s** (after Story 10.8 / the moving-LoS `DarknessFairnessQuery`, merged PR #61 — the live fairness hard-gate no longer false-positives on Medium Darkness boards, so live Medium/Small combat nodes resolve cleanly through the interactive path too). This story ADDS tests; new total ≥ 185, 0 `^FAIL`.
- **Test patterns to extend/mirror:** `godot/tests/unit/run/test_live_run_flow.gd` (the live-combat-node + hero-death + auto-resolve-unperturbed patterns; seed `4242` clears its depth-0 combat node with the default loadout), `godot/tests/unit/run/test_live_combat_resolver.gd` (the resolver contract), `godot/tests/unit/run/test_live_affinity_flow.gd` (the live affinity-on-board path), `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the by-construction compile guardrail).

### Explicit Non-Goals (12.2's scope or later — do NOT do here)

- **Class-kit → combat-loadout wiring / winnable-by-every-class reference driver / the 11.2 boundary revision.** 12.1 keeps the driver-supplied loadout (`DEFAULT_HERO_HP` 60 / sword). The Epic-11 retro **T2** (a stronger LoS-aware hero driver OR class-kit→loadout so a human wins an arbitrary generated fight, and classes are tactically distinct) is **Story 12.2's** deliverable, and 12.2 — not 12.1 — is the story that "deliberately revises the 11.2 'class-kit → combat-loadout is a later story' boundary" and updates `project-context.md` in the same change. Deferred-work ledger: the 11.2 loadout boundary and the Necromancer/Shadeblade class-kit content are NOT 12.1's.
- **No in-node fight SAVE / mid-encounter resume.** The in-node fight state stays EPHEMERAL; the 23-key `RunSnapshot` gate stays 23 (a mid-encounter save is a later in-node-save story). NFR13 resume holds at the between-level boundary today; do not add an in-node save key.
- **No run-level event store / `outcome_or_cause` population.** The live-flow `RunSummary` is partial (`RunEndProfileBridge` builds `RunSummary.build(run, [])` — passives/loot/discovery lists + `outcome_or_cause` are EMPTY). Any surface this story touches must key victory/death off `phase` (`PHASE_COMPLETED`/`PHASE_FAILED`), NOT `outcome_or_cause` (deferred-work T4, originating 11.5). This story does not build the event store.
- **No boss-arena tap-loop.** The boss fight stays `auto_play_boss_fight` (the boss arena is a fixed finale stage, no affinity). This story's tap-loop is the pre-boss combat/elite nodes. (A boss tap-loop would be a later story if ever scoped — not implied by these ACs.)

### Regression traps (things that will silently break if you are not careful)

- **The empty-board VM is correct-by-design** — `TacticalBoardViewModel.from_domain(null)` yields a zero-cell VM (no crash). Between levels the board is legitimately null (`_render_between_levels`). Do not "fix" the empty VM path; the L4 gap is that a COMBAT NODE never held a LIVE board mid-fight, not that the empty VM crashes.
- **Turn-state stub** — `_render_live_board` currently binds a fresh `TacticalTurnState.new(1, PLAYER_PLANNING, &"hero")`. For a real tap-loop the bound turn state must be the LIVE one that advances as actions resolve, or `action_availability` (`move`/`attack`/`inspect`/`confirm`/`cancel`) and the "whose turn" HUD slot will be wrong.
- **`resolve_combat_node_live` is atomic on purpose** — if you make the interactive path call it, the fight auto-resolves in one call and you never get a tap loop. You must split its PRE-fight setup from the fight-drive. Keep the atomic method intact for the proof drivers (AC4).
- **RNG stream count + event enum are pinned** — the tap-loop draws ONLY the `combat` stream (via `AttackCommand`), reuses the existing move/attack/damage/outcome/run-end events, and adds NO event. `RngStreamSet.required_streams()` must stay 7; the `DomainEvent.Type` enum tail must be unchanged. Every generator/route/finale fingerprint + the DEFAULT `run_to_completion` must be byte-identical (AC4).
- **Scorched DoT gate** — if the interactive session applies affinity effects, keep the Scorched DoT gated on the affinity PLAN (`resolve_board_plan(...).scorched_hazard_cells` non-empty), NOT the apply's stamped-diff (the 11.4 L1 lesson), and tick each entity once per round at the end of its own action.

### Project Structure Notes

- New production code goes under `godot/scripts/` by domain. The interactive-fight session is a scene-free `RefCounted` domain/flow seam: `godot/scripts/run/` (alongside `live_combat_resolver.gd` / `run_orchestrator.gd`) or `godot/scripts/ui/flow/` (alongside `run_flow_controller.gd`) — pick the home that keeps gameplay decisions in the domain layer and the shell as thin observer. Presenters stay under `godot/scripts/ui/presenters/`; scenes under `godot/scenes/game/` (the gameplay shell + board already exist). Tests mirror the domain under `godot/tests/unit/run/` or `godot/tests/unit/ui/`.
- Naming: `snake_case` files/folders, `PascalCase` classes, `snake_case` funcs/vars/signals, `UPPER_SNAKE_CASE` consts. Commands are `*Command`; domain events past-tense `*Event`; results `*Result`.

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — read it before implementing; when in doubt choose the more restrictive interpretation):

- **Presentation observes domain state/events and submits commands through a command bridge.** Godot scenes, `Control` nodes, audio, VFX, animation are presentation — they must NOT own authoritative tactical state. The scene-independent domain model owns tactical truth (board, entities, turns, RNG, rules, saves, run progression). Use Godot signals for presentation feedback, not hidden domain control flow.
- **Commands validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense `DomainEvent` records.** Gameplay-affecting randomness uses its assigned named RNG stream (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`). The tap-loop's only gameplay RNG is the `combat` stream via `AttackCommand`.
- **Headless simulation is a first-class target** — it must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state. Assertable logic lives in `RefCounted` seams; `.tscn`/`Control` wiring is verified by construction + the compile guardrail (no SceneTree test).
- **Keep autoloads thin; add no new autoload.** Acceptable autoloads: `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. The run-flow seams (`RunFlowController`, `RunFlowRouter`, bridges) are thin `RefCounted` that own no decision a command/orchestrator does not.
- **Do not serialize scene nodes as save truth; save versioned domain snapshots only.** The 23-key `RunSnapshot` gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; the in-node fight state stays EPHEMERAL.
- **Difficulty is a hard non-goal** — no difficulty selector/ladder/knob anywhere. MVP difficulty comes from depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, boss preparation.
- **AI tooling (Godot MCP / Context7) is dev-time only** — the game must never call AI to generate runtime content. This story authors no content; it wires the existing tactical layer to live input.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Epic 12: Interactive Tactical Combat` (Epic List lines 505-511; Story 12.1 lines 2837-2864)]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-07.md#1 Issue Summary / #4.5 Story 12.1` (T1/T2 residual; L4 gap; §14 tap contract; resolve-then-advance; byte-identical auto-resolve default)]
- [Source: `_bmad-output/planning-artifacts/ux-appendix-run-flow.md#14 Layout + accessibility coverage pass` and `#1 Tactical HUD` / `#2 Preview / confirm states` / `#3 Inspect panel` / `#16.1 Non-gaps`]
- [Source: `_bmad-output/implementation-artifacts/epic-11-retro-2026-07-06.md#8 Action Items (T1/T2)` and `#10 Significant Discovery` (the STRUCTURAL tap-loop sequencing drift) and `#7 items 1 & 4`]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — the 11.3 L3/L4 tap-loop entries; the 11.2 loadout boundary (12.2's, not 12.1's); the run-level event store / `outcome_or_cause` blank → key off `phase` (T4)]
- [Source: `project-context.md#run_flow_scene_hud_rules` (lines 450-456) — resolve-then-advance, no-SceneTree-test, hero-HP-two-concerns, additive-opt-in-affinity, no-new-autoload, do-not-close-the-Epic-11-deferrals]
- [Source: `godot/scripts/ui/presenters/tactical_board_presenter.gd` — the existing tap seam]
- [Source: `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — `_drive_current_stage` / `_render_live_board` (the L4 wiring point)]
- [Source: `godot/scripts/run/run_orchestrator.gd#resolve_combat_node_live` (~967-1095) — the atomic auto-resolve to split]
- [Source: `godot/scripts/run/live_combat_resolver.gd` — the scripted-hero one-shot driver (the blueprint for the step-driven session); `DEFAULT_HERO_HP`/`DEFAULT_HERO_WEAPON`]
- [Source: `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` — `build_command`/`execute_intent`; move/attack/inspect intents]
- [Source: `godot/scripts/ui/flow/run_flow_controller.gd#current_node_needs_board` — the shared resolve-then-advance seam; `hero_hp()`]
- [Source: `godot/tests/unit/run/test_live_run_flow.gd`, `test_live_combat_resolver.gd`, `test_live_affinity_flow.gd`, `godot/tests/unit/ui/test_run_flow_scenes_load.gd` — the test patterns to extend]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed — comprehensive developer guide created (create-story, 2026-07-07). Folds in: the sprint-change Epic-12 scope; the UX appendix §14/§1-3 tap contract; the Epic-11 retro T1/T2 and the 11.2/11.3 boundary rules; and the overlapping deferred-work items (T4 RunSummary keyed off `phase`; the 11.2 loadout boundary as 12.2's not 12.1's). The exact seam map (tap seam already exists; L4 gap in the atomic `resolve_combat_node_live`) is pinned to source lines.

### File List
