---
baseline_commit: 3cb80b3
---

# Story 13.2: Live Reward and Passive-Choice HUD

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the post-fight reward and passive Consume/Destroy choices presented as clickable UI,
so that I can complete the loop steps a fight earns me without a test harness.

## Context and Scope Authority

This is the SECOND (and final) story of **Epic 13 (Human-Playable Board)**, added 2026-07-13 by
`_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-13.md` after the first human desktop playtest
found the hands-on loop was not human-playable. **Story 13.1 (DONE, merged 2026-07-14, PR #69, suite 193 PASS)**
made the FIGHT human-drivable — the board draws as a real tile grid and taps route into the interactive combat
seams. **This story makes the REWARD a fight earns human-collectable** — it renders the post-fight reward offer and
the passive Consume/Destroy choice as clickable on-screen UI and drives the EXISTING Epic-6/7 resolution commands.
Together 13.1 + 13.2 close the last two "later HUD story" gaps the MVP-readiness gate recorded.

**This is a PURE presentation + flow-wiring story over pinned domain contracts.** Every piece it needs already
exists and is unit-tested (Epic 6/7, suite green):
- the reward-offer GENERATE (`RunOrchestrator.generate_reward_offer` / `generate_passive_reward_offer`),
- the pending-offer store (`RunState.pending_reward_offer`, a `RewardOffer`),
- the passive modal DATA contract (`PassiveRewardModalViewModel`, pinned `MODAL_KEYS`),
- the two-step Consume/Destroy commit flow (`PassiveRewardCommitFlow`, arm → confirm),
- the three resolution commands (`ResolveRewardCommand` / `ConsumePassiveCommand` / `DestroyPassiveCommand`).

13.2 wires them into the live gameplay shell: after an interactive combat/elite VICTORY (and, where applicable, on
a non-combat node), it GENERATES the offer at the shell boundary, RENDERS it, and RESOLVES it from clicks — then
advances. **It adds no domain command, no new event, no new RNG stream, no schema/save-key change, no new autoload,
and moves no pinned fingerprint.**

**This story closes:**
- The **10-6 MVP-readiness gate §3.3 qualifier** — loop steps 6 (collect rewards) + 7 (make passive choices) are
  today "PRESENT + integration-proven only" (`test_loot_passive_build_smoke_run.gd`), caller-driven /
  live-HUD-wiring-deferred. This story makes them live-HUD-proven end to end by a human on desktop.
- The **13-1 `[Review][Defer]` (inspect-tap on-screen feedback)** whose recorded owner is "Story 13.2 reward/
  passive-HUD story, or a later board-polish pass" — see Task 5 (decide: pick it up cheaply or knowingly carry it
  forward; do not silently drop it).

**Authoritative scope inputs (already folded into this file — do not re-derive):**
- `epics.md` Epic 13 / Story 13.2 (canonical ACs; Epic List lines 513–519, body lines 2934–2955).
- The sprint change proposal (the playability gap; 13.2 = the reward/passive HUD half).
- `project-context.md` — the Epic-6 loot/reward/consume-destroy rules (lines 183–199), the critical don't-miss
  reward rules (lines 441–449), the Epic-11 run-flow-scene-hud rules (256–270), the Epic-12 interactive rules
  (272–281), and the Epic-2 presentation/view-model rules (300–306).
- The 13-1 story file (`13-1-live-board-render-and-tap-input.md`) — the presenter/shell seam map, the scene-free
  testing discipline, the `.gd.uid` sidecar convention, the false-PASS grep + PowerShell `-File` test-run gate.
- The deferred-work ledger's **13-1 inspect-feedback `[Review][Defer]`** (owner: this story or a later polish pass).

**The one-sentence essence:** the reward GENERATE, the pending-offer store, the passive modal projection, the
two-step commit flow, AND all three resolution commands already exist and are unit-tested — this story wires the
GENERATE into the interactive-shell post-victory boundary, renders `run.pending_reward_offer` (generic offer +
passive 3-choice modal) as clickable UI, and routes clicks into the EXISTING run-domain commands, so a human
collects on screen the reward the tests already prove resolves.

## Acceptance Criteria

**AC1 — a pending reward offer renders on screen and a click resolves it (generic reward path).**
**Given** a resolved combat/elite node (or a non-combat node) yields a reward offer on `RunState.pending_reward_offer`
**When** the shell returns from the board (the interactive victory boundary) or resolves a non-combat node
**Then** the pending offer renders on screen from the EXISTING Epic-6 contracts — the generic offer from the
`RewardOffer` on the run (`offered_entries`, a `{category, content_id}` list produced by `RewardOfferBuilder` at
GENERATE), and a passive offer via `PassiveRewardModalViewModel.project_offer(offer, index)` (its pinned
`MODAL_KEYS`) — no new board-VM key, a null/absent offer renders the empty state without crashing
**And** the player can accept/resolve a NON-passive offer with a click that drives the EXISTING `ResolveRewardCommand`
path (executed against `RunState` with a `sequence_id` from `RunOrchestrator.next_sequence_id()`) — validate-before-
mutate, no fabricated selection, then the flow advances (to the route map).

**AC2 — a passive reward drives the two-step Consume/Destroy choice; back-out mutates nothing.**
**Given** a passive reward requires the Consume/Destroy choice (a `passive_reward_choice` 3-choice offer)
**When** the modal is shown
**Then** the two-step `PassiveRewardCommitFlow` drives the choice (a first tap ARMS `arm_consume` / `arm_destroy`,
a second confirming tap `confirm()`s; ≥44px targets), and the committed intent submits the EXISTING
`ConsumePassiveCommand` (Consume → adopt into the run's `RulesResolver`) or `DestroyPassiveCommand` (Destroy → roll
70/20/10 via the run-level `streams` on `STREAM_REWARDS` + the baseline `DestroyOutcomeTableDefinition`) — the SAME
offer is resolved by EXACTLY ONE command (never also `ResolveRewardCommand`, never two — no double-record)
**And** cancel / dismiss / back-out leaves the run state UNMUTATED (byte-identical `RunState`; the commit flow's
`cancel()`/`dismiss()` produce no intent and no command runs).

**AC3 — live-HUD-proven end to end; every pinned invariant byte-identical; no domain contract change.**
**Given** the 10-6 MVP readiness gate's §3.3 qualifier (loop steps 6/7 integration-proven only)
**When** this story lands
**Then** collect-rewards and make-passive-choices are live-HUD-proven end to end by a human on desktop (the flow
generates → renders → resolves → advances with clicks; the human-eyes render/click confirmation is the on-device
pass this story unblocks, logged against the physical-device owner per the honesty posture)
**And** the headless suite stays green with every pinned fingerprint byte-identical — NO domain command/contract
change, NO new `DomainEvent.Type` member, NO new RNG stream (`required_streams()` == 7), the 23-key `RunSnapshot`
gate stays 23, `TacticalBoardViewModel.to_dictionary()` keeps its 16-key contract, `PassiveRewardModalViewModel`'s
`MODAL_KEYS` and `RewardOffer`'s `DICTIONARY_KEYS` are unchanged, NO new autoload, and the hands-off auto-resolve
driver (`LiveCombatResolver.resolve` / `run_to_completion` / `auto_play_boss_fight`) + every generator/route/finale
seed-regression fingerprint stay byte-identical (the reward GENERATE is wired into the INTERACTIVE shell path ONLY,
never into `run_to_completion`/`_resolve_combat`).

## Tasks / Subtasks

- [x] **Task 1 — Wire the reward-offer GENERATE at the interactive-shell node-completion boundary.** (AC1)
  - [x] In `gameplay_shell_presenter.gd`, at the interactive-combat VICTORY boundary (`_on_interactive_action_committed`,
    the `run.is_terminal() == false` branch that today calls `_advance_to_route_map()` at `:197`), GENERATE the reward
    offer BEFORE advancing: call the EXISTING `orchestrator.generate_reward_offer(table_id)` (single-pick) or
    `orchestrator.generate_passive_reward_offer(table_id)` (3-choice) — do NOT hand-roll a draw, do NOT call
    `RewardOfferBuilder` directly (the orchestrator method injects the run-level `streams`, stores the offer as
    `pending`, emits `reward_offered`, and advances the sequence — the single sanctioned path). Then render the reward
    HUD (Task 2) and AWAIT the resolve click instead of immediately advancing.
  - [x] Choose the v0 **node → table policy** (a presentation-flow decision this story owns — the "later HUD/orchestrator
    story owns the auto-wire + the board-reward-marker → offer link once it owns a resolution policy" that
    `project-context.md:191` forecasts). Recommended minimal, deterministic mapping using the THREE existing baseline
    tables (`RewardTableRepository.BASELINE_REWARD_TABLE_IDS`): `combat` → `standard_combat_reward`, `elite_combat` →
    `elite_combat_reward`, and present the `passive_reward_choice` 3-choice moment on a deterministic trigger so a normal
    desktop playtest exercises BOTH a generic reward AND a passive Consume/Destroy (e.g. elite → passive, or a fixed
    node cadence). Keep it deterministic; document the chosen policy in Completion Notes. A node yields ONE offer at a
    time (the `reward_offer_pending` guard rejects a second generate). See "The key scope decision" below.
  - [x] **DO NOT auto-wire the generate into `run_to_completion` / `_resolve_combat` / `auto_play_boss_fight`** (the
    hands-off auto-resolve proof paths — `project-context.md:442`). Auto-generating there would advance the run-level
    `rewards` stream mid-run with no auto-resolve policy, trip the `reward_offer_pending` guard, and perturb the
    interrupted==uninterrupted determinism the seed-regression fixtures pin. The boss victory path routes to run-end →
    outpost (no combat-node reward HUD); the boss stays auto-play (13.1 non-goal, unchanged).
- [x] **Task 2 — Render the pending reward offer on screen (generic offer + passive 3-choice modal).** (AC1, AC2)
  - [x] Render `run.pending_reward_offer` as clickable UI. For a NON-passive offer, read its `offered_entries` (each a
    plain `{category, content_id}` dict) directly from the `RewardOffer` (there is NO dedicated generic-offer VM — the
    offer is itself the serializable read surface; do NOT invent a board-VM key). For a PASSIVE offer, project each of
    the (up to 3) entries via `PassiveRewardModalViewModel.project_offer(offer, index)` and render the pinned
    `MODAL_KEYS` fields (`display_name` / `flavor` / `exact_mechanical_effects` / `consume_text` / `destroy_text` +
    `has_unknown_consequences` / `consequences_text`). The board presenter already exposes the read seam
    `passive_reward_modal(index)` (`tactical_board_presenter.gd:359`) — reuse/extend it; it is currently a read-only
    projection with no render + no input.
  - [x] Host the reward surface as an ADDITIVE presentation surface (a reward panel/overlay). It is a SEPARATE read
    surface, NOT a `TacticalBoardViewModel` key (exactly like the affinity read `LiveAffinityReadModel` and the G1
    `RunHudViewModel` are composed alongside the board VM, not baked into its 16-key set). Keep any render/routing
    DECISION logic in a `RefCounted` seam (Task 6); the `Control`/scene wiring is verified by construction + the compile
    guardrail (the scene-free harness rule, `project-context.md:260`).
  - [x] `icon` in `MODAL_KEYS` is a placeholder id STRING sentinel, not art (`project-context.md:199`). Rendering the
    text fields satisfies the ACs. IF you choose to render the 28 generated passive-glyph icons
    (`asset_sources` `icon.passive.001`–`028`, generated/approval-pending) you MUST follow the 13.1 art discipline:
    headless `--import` to generate the `.png.import` sidecars, commit them, and load defensively (guarded `load()`,
    never `preload`) so the compile guardrail stays green on a fresh checkout. Icon art is OPTIONAL polish, not required.
  - [x] Color-independence (NFR9 / §14.2): every reward-choice meaning (which choice is armed vs confirmed, Consume vs
    Destroy, the honest-unknown-downside flag) carries a non-color channel (label/pattern/text), never color alone.
- [x] **Task 3 — Resolve a generic (non-passive) offer from a click via `ResolveRewardCommand`.** (AC1)
  - [x] On the accept/resolve click for a non-passive offer, construct + execute the EXISTING run-domain command
    directly (the 4.3 run-command idiom — these commands have NO orchestrator convenience method, `project-context.md:191`):
    `ResolveRewardCommand.new(category, content_id, orchestrator.next_sequence_id()).execute(run)`. This is NOT a
    `TacticalCommandBridge` intent — that bridge only handles `move`/`attack`/`inspect` against a
    `TacticalActionContext`; the reward/passive commands execute against `RunState`. If you add a thin reward "bridge"
    seam, mirror `RunEndProfileBridge` (construct + execute a run command with a monotonic `sequence_id`); do NOT extend
    `TacticalCommandBridge`.
  - [x] Honor the command's contract: a backpack-category reward composes `PickupItemCommand` (a FULL backpack surfaces
    `inventory_full` and leaves the offer `pending` — surface it honestly, do not silently advance); gold credits the
    wallet; a passive category recorded via `ResolveRewardCommand` is outcome-only (NOT the Consume/Destroy path — see
    Task 4). Resolving draws ZERO new RNG (the offer was rolled at GENERATE). After a successful resolve, advance the flow.
- [x] **Task 4 — Wire the passive Consume/Destroy two-step; back-out mutates nothing.** (AC2)
  - [x] Instantiate a `PassiveRewardCommitFlow` in the presenter/shell (it is imported in `tactical_board_presenter.gd:28`
    but NOT yet instantiated). The player selects one of the 3 passive choices + Consume or Destroy: the first tap ARMS
    (`arm_consume(content_id, table_id)` / `arm_destroy(content_id, table_id)`), a second confirming tap `confirm()`s and
    returns the commit-intent `{committed, choice, passive_content_id, table_id}`.
  - [x] Route the commit-intent to EXACTLY ONE command (`project-context.md:195/446` — a pending passive offer is resolved
    by exactly one of {`ResolveRewardCommand` | `ConsumePassiveCommand` | `DestroyPassiveCommand`}; never compose two):
    Consume → `ConsumePassiveCommand.new(passive_content_id, table_id, orchestrator.next_sequence_id())` (adopts into
    `run.rules_resolver`); Destroy → `DestroyPassiveCommand.new(passive_content_id, table_id, orchestrator.next_sequence_id(),
    orchestrator.streams, DestroyOutcomeTableDefinition.create_baseline_table())` — Destroy DRAWS ONE RNG on
    `STREAM_REWARDS`, so it MUST use the run-level `streams` (never a fresh `RandomNumberGenerator`); rolls the exact-
    integer 70/20/10 outcome.
  - [x] Cancel / dismiss / back-out (AC2): `PassiveRewardCommitFlow.cancel()` / `dismiss()` produce no intent and run no
    command → the `RunState` is byte-identical. Prove a cancelled choice mutates nothing.
- [x] **Task 5 — DECIDE the carried 13-1 inspect-feedback defer (do not silently drop it).** (AC-adjacent)
  - [x] The 13-1 `[Review][Defer]` (inspect taps produce no on-screen feedback — `interactive_inspect(cell)` routes into
    `_session.inspect(cell)` but neither re-renders nor surfaces the result; the inspect region stays "Inspect: tap a
    cell") has recorded owner "Story 13.2 reward/passive-HUD story, or a later board-polish pass." Since 13.2 touches the
    same presenter HUD regions, EITHER (a) surface the `interactive_inspect` returned `CommandBridgeResult` metadata in
    the inspect region (cheap: re-render + set the inspect region text from the returned cell facts), OR (b) knowingly
    carry it forward to a later board-polish pass. If (b), leave the ledger entry open and record the conscious decision
    in Completion Notes — do NOT let it fall off the ledger.
- [x] **Task 6 — Tests: RefCounted seam coverage + the compile guardrail; prove the invariants byte-identical.** (AC1, AC2, AC3)
  - [x] Any NEW render/routing DECISION seam (e.g. a reward-offer render projection, or a resolve-routing decision:
    passive-Consume/Destroy vs generic-resolve) is a `RefCounted` with a pinned contract under
    `godot/scripts/ui/view_models/`, unit-tested under `godot/tests/unit/ui/` (auto-discovered — the runner recursively
    walks `res://tests/unit` + `res://tests/integration`; NO manifest edit). Do NOT write a SceneTree test for the
    presenter (`project-context.md:260`); put assertable logic in `RefCounted` seams and test THOSE.
  - [x] REUSE the existing green tests (do NOT duplicate them): `test_reward_offer_generate.gd`,
    `test_resolve_reward_command.gd`, `test_consume_passive_command.gd`, `test_destroy_passive_command.gd`,
    `test_passive_reward_modal_view_model.gd` (the `MODAL_KEYS` pin — must stay green), `test_passive_reward_commit_flow.gd`,
    `test_reward_offer.gd`, `test_loot_passive_build_smoke_run.gd`. Confirm `test_run_flow_scenes_load.gd` still covers the
    modified `gameplay_shell_presenter.gd` + `tactical_board_presenter.gd` (+ any new reward-surface `Control`/`.tscn`).
  - [x] Prove the AC3 invariants hold via the EXISTING invariant tests (reuse, don't add redundant ones): the 16-key
    board VM (`test_tactical_board_view_model.gd`), `MODAL_KEYS`, `RewardOffer.DICTIONARY_KEYS` (`test_reward_offer.gd`),
    `required_streams()` == 7, no new `DomainEvent.Type` member (enum tail `oath_shards_spent`), the 23-key `RunSnapshot`
    gate (`test_run_route_position_save.gd` — the pending offer rides ONLY the full `RunState.to_dictionary()`, NOT the
    route-position snapshot), and the seed-regression fingerprints (`test_seed_regression_suite.gd` — the hands-off
    driver is untouched).
- [x] **Task 7 — Run the full headless suite + the false-PASS grep guard + `git diff --check`.** (AC3)
  - [x] Run: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`
    via a PowerShell `.ps1` + `-File` (NOT inline `-Command` through Bash — Git Bash expands `$LASTEXITCODE` before
    PowerShell parses it → silent parse failure; Epic-10 retro §8 P3). Expect **≥193 PASS / 0 `^FAIL`** (baseline 193 +
    any new seam tests), exit 0. Runner output is UTF-16LE — decode (`tr -d '\000'`) before grepping.
  - [x] Grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL` — no matches; exactly the 6 documented stderr
    negatives (int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1) and ZERO new documented negative.
    `git diff --check` clean.
  - [x] Commit any NEW script file's `.gd.uid` sidecar (Godot 4.6 generates one per script; the ratified 13-1 VC
    convention COMMITS `*.gd.uid`, never gitignores them — a re-import is a git-clean no-op). Do NOT add `*.gd.uid` to
    any `.gitignore`.

## Dev Notes

### The exact seam map (READ THESE FILES — they are the whole story)

| File | What it is today | What 13.2 does |
|---|---|---|
| `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` | The gameplay-shell presenter. Drives the live node the run is parked on, then advances. On an interactive combat/elite VICTORY, `_on_interactive_action_committed` (`:172`) re-renders and, when the run is NOT terminal, calls `_advance_to_route_map()` (`:197`) — **it generates NO reward offer**. A non-combat node resolves (`resolve_current_node_live`) then `_render_between_levels` + `_advance_to_route_map()` (`:158-164`). The boss auto-plays then routes to run-end. | Insert the reward step at the victory boundary (and the non-combat path where applicable): GENERATE the offer (`orchestrator.generate_reward_offer` / `generate_passive_reward_offer`), RENDER the reward HUD, AWAIT the resolve click, THEN advance. Do NOT touch the boss auto-play or the hands-off driver. |
| `godot/scripts/ui/presenters/tactical_board_presenter.gd` | The board presenter. Six region panels (`board`/`preview`/`confirm_cancel`/`inspect`/`status`/`log_or_outcome`, `:95-102`). ALREADY exposes `passive_reward_modal(index)` (`:359`) — a READ-ONLY projection of `run.pending_reward_offer` via `PassiveRewardModalViewModel`, NOT rendered + NOT wired to input. Imports `PassiveRewardCommitFlow` (`:28`) but never instantiates it. `interactive_inspect(cell)` (`:417`) routes to `_session.inspect` but does not surface the result (the carried 13-1 defer). | Render the reward offer as clickable UI (reuse/extend `passive_reward_modal`); instantiate + wire `PassiveRewardCommitFlow`; optionally surface inspect feedback (Task 5). Do NOT add a board-VM key. |
| `godot/scripts/run/run_orchestrator.gd` | `generate_reward_offer(table_id, stream_name=STREAM_REWARDS)` (`:404`) — single-pick, injects the run-level `streams`, stores the offer `pending` on `run.pending_reward_offer`, emits `reward_offered`, rejects a second while pending (`reward_offer_pending`), fail-closes `unknown_reward_table`. `generate_passive_reward_offer(...)` (`:447`) — the 3-choice draw-without-replacement. `next_sequence_id()` (`:894`) — the monotonic id the caller threads into the resolution commands. `streams` — the run-level `RngStreamSet`. | CALL these (the sanctioned generate + sequence-id source). Never hand-roll a draw; never mint a `RandomNumberGenerator`. Wire the generate into the INTERACTIVE shell path ONLY. |
| `godot/scripts/run/reward_offer.gd` (`RewardOffer`) | The pending offer on `RunState.pending_reward_offer`: `table_id`, `status` (`pending`/`resolved`), `offered_entries` (plain `Array` of `{category, content_id}`), `selected_entry`, draw provenance, `gold_amount`. `has_offered_entry(category, content_id)`. Pinned `DICTIONARY_KEYS`. Rides ONLY the full `RunState.to_dictionary()` — NOT the route-position `RunSnapshot`. | The generic-offer READ surface — render `offered_entries` directly (no dedicated VM exists). Do NOT widen its key set; do NOT persist it into the route-position snapshot. |
| `godot/scripts/ui/view_models/passive_reward_modal_view_model.gd` | The scene-free passive modal projection. `project_offer(offer, index)` (`:91`) → a flat dict keyed by the pinned `MODAL_KEYS` (`:45-56`): `has_passive`/`passive_id`/`icon`/`display_name`/`flavor`/`exact_mechanical_effects`/`consume_text`/`destroy_text`/`has_unknown_consequences`/`consequences_text`. Fail-closed (a null/absent/out-of-range/non-passive input → identity-absent, same keys, `has_passive == false`). | Render a passive offer from `MODAL_KEYS` (branch on `has_passive`). Add NO key. `icon` is an id string, not art. |
| `godot/scripts/ui/view_models/passive_reward_commit_flow.gd` (`PassiveRewardCommitFlow`) | The two-step Consume/Destroy commit-INTENT (arm → confirm), mirroring `TacticalAttackCommitFlow`. `arm_consume(content_id, table_id)` / `arm_destroy(...)` ARM; `confirm()` → `{committed, choice, passive_content_id, table_id, reason}` + clears; `cancel()` / `dismiss()` → no intent, ZERO mutation. Holds no `RunState`/`RewardOffer` — transient view state; executes NO command. | Instantiate + wire it. The confirm-intent's `{choice, passive_content_id, table_id}` feeds `ConsumePassiveCommand` / `DestroyPassiveCommand`. `cancel`/`dismiss` = AC2 no-mutation. |
| `godot/scripts/core/commands/resolve_reward_command.gd` | `ResolveRewardCommand.new(category, content_id, sequence_id)` (`:58`). Applies the selected entry by category (backpack → composes `PickupItemCommand`, fail-closes `inventory_full` + leaves offer `pending`; gold → credits wallet; passive → outcome-record only), flips the offer `resolved`, emits `reward_resolved`. ZERO new RNG. Rejects `sequence_id <= 0` first; no-mutation on any reject. | The generic (non-passive) resolve path. Execute against `RunState` directly (NOT `TacticalCommandBridge`). Thread `next_sequence_id()`. |
| `godot/scripts/core/commands/consume_passive_command.gd` | `ConsumePassiveCommand.new(passive_content_id, table_id, sequence_id, passive_repository=null)` (`:69`). ADOPTS the passive into `run.rules_resolver` (`register_passive`), flips the offer, emits `passive_consumed`. ZERO RNG. | The Consume branch of the passive modal. |
| `godot/scripts/core/commands/destroy_passive_command.gd` | `DestroyPassiveCommand.new(passive_content_id, table_id, sequence_id, streams, outcome_table, passive_repository=null)` (`:99`). Does NOT register (leaves `rules_resolver` untouched); ROLLS the exact-integer 70/20/10 outcome via `rand_int(STREAM_REWARDS, ...)` — ONE draw on the run-level `streams` — flips the offer, emits `passive_destroyed` (with draw provenance). | The Destroy branch. MUST pass `orchestrator.streams` + `DestroyOutcomeTableDefinition.create_baseline_table()`. |
| `godot/scripts/content/repositories/reward_table_repository.gd` | `BASELINE_REWARD_TABLE_IDS` (`:20`): `standard_combat_reward` (single-pick — weapon/armor/support/consumable/pickup/gold), `elite_combat_reward` (single-pick), `passive_reward_choice` (`choice_count = 3` — the six Story-5.4 baseline passives). All validated on the baseline repo. | The node → table policy source (Task 1). The orchestrator resolves the id through `_reward_table_repository` (validated tables only). |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | `TacticalCommandBridge` — handles ONLY `move`/`attack`/`inspect` intents against a `TacticalActionContext`. It has NO reward/passive path. | **Do NOT extend it for rewards.** Reward/passive commands are run-domain commands executed against `RunState`. The AC's "through the command bridge" is loose language — use the run-command idiom. |

### The key scope decision — WIRE the reward GENERATE, don't just render a pre-existing offer

Today **nothing in the live flow generates a reward offer** (the interactive victory branch advances straight to the
route map; `generate_reward_offer`/`generate_passive_reward_offer` are caller-driven and deliberately NOT auto-wired
into the hands-off driver). So AC1's "a resolved node yields a reward offer" can only be satisfied — and AC3's "live-
HUD-proven end to end by a human" is only non-vacuous — if **this story wires the generate at the interactive-shell
node-completion boundary.** `project-context.md:191` explicitly forecasts this owner: *"A later HUD/orchestrator story
owns the auto-wire + the board-reward-marker → offer link once it owns a resolution policy."* **13.2 IS that story.**

The boundary that keeps every invariant byte-identical:
- **DO** wire generate into the INTERACTIVE shell path (`gameplay_shell_presenter._on_interactive_action_committed`
  victory branch + the non-combat resolve path). This is the human-driven flow; NO seed-regression fixture drives it,
  so wiring a real `rewards`-stream draw here moves NO pinned fingerprint.
- **DO NOT** wire generate into `run_to_completion` / `_resolve_combat` / `auto_play_boss_fight` (the hands-off proof
  paths the fixtures pin). That is `project-context.md:442` verbatim; violating it perturbs interrupted==uninterrupted
  determinism and trips the `reward_offer_pending` guard.
- The **node → table policy** (which table a node generates from, and when the passive 3-choice appears) is a v0
  presentation-flow decision THIS story owns. Pick a deterministic mapping over the 3 baseline tables, exercise BOTH a
  generic reward and a passive Consume/Destroy in a normal desktop playtest, and document it. This is the one genuine
  design latitude — resolve it with the sensible default above and note it in Completion Notes; flag it for review if a
  stronger reward-policy intent is read into the AC.

### Architecture rules this story MUST obey (project-context.md — the load-bearing seam rules)

- **Presentation observes domain state and submits through commands; scenes own NO tactical/run truth** (lines 300–302,
  183–199). The reward HUD is a READ of `run.pending_reward_offer` (+ `PassiveRewardModalViewModel`); clicks execute the
  EXISTING run-domain commands. No scene node is authoritative for the offer/run state.
- **A pending passive offer is resolved by EXACTLY ONE command** (lines 195/446) — one of `ResolveRewardCommand` /
  `ConsumePassiveCommand` / `DestroyPassiveCommand`; none composes another (double-record). The passive modal routes to
  Consume or Destroy; do NOT also `ResolveRewardCommand` the same passive offer.
- **Reward draws route through the orchestrator generate + the builder on `rewards`/`loot` ONLY** (lines 190–191, 441).
  Hand the builder the run-level `RngStreamSet` (via the orchestrator method) so a route-position save round-trips the
  advanced stream; never `randi()`/`randf()`/a fresh `RandomNumberGenerator`, never a second stream.
- **Destroy's 70/20/10 is exact-integer + roll ONE `STREAM_REWARDS` draw** (lines 196, 446–447). Do not alter the
  distribution or the three fixed outcome categories; pass the baseline `DestroyOutcomeTableDefinition`.
- **The scene-free harness verifies `.tscn`/`Control` BY CONSTRUCTION, not by SceneTree tests** (line 260). Put
  assertable render/routing DECISIONS in `RefCounted` seams (test those); the presenter wiring is covered by
  `test_run_flow_scenes_load.gd`. Do NOT trust a prose "it's wired" claim about a guarded accessor without grepping the
  probed method against source (the 11.3 M2 dead-probe lesson).
- **Keep autoloads thin; add NO new autoload** (lines 258/274/89). Acceptable: `GameSession`, `SceneManager`,
  `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. This story adds none.
- **No per-frame work; render on explicit refresh** (line 322). Draw the reward HUD on a render/`queue_redraw()`, not
  in `_process`. Cache node references.
- **Color-independent + audio-absent-equivalent** (lines 305–306, §14.2): the armed-vs-confirmed, Consume-vs-Destroy,
  and honest-unknown-downside cues each carry a non-color channel.
- **Runtime art under `godot/assets/`; the modal `icon` is a placeholder id sentinel** (lines 199, 337–338). Rendering
  the modal TEXT satisfies the ACs; icon art is optional (and, if used, follows the 13.1 import + sidecar + defensive-
  load discipline).

### The invariants that MUST stay byte-identical (AC3 — this is a presentation + flow-wiring story)

- **7 named RNG streams** (`required_streams()` == 7). The reward GENERATE + the Destroy roll draw the EXISTING
  `rewards` stream — NO new stream, NO new draw site outside the orchestrator generate / the `DestroyPassiveCommand`
  roll, NO `randi`/`randf`/fresh `RandomNumberGenerator`.
- **No new `DomainEvent.Type` member.** `reward_offered`/`reward_resolved`/`passive_consumed`/`passive_destroyed`/
  `item_gained`/`economy_changed` ALL already exist (Epic 6/7). Enum tail is `oath_shards_spent`. This story emits only
  existing events (via the existing commands).
- **The 23-key `RunSnapshot` gate stays 23.** The pending offer rides ONLY the full `RunState.to_dictionary()`, NOT the
  route-position `RunSnapshot` (`project-context.md:193`). Persist nothing new; the in-node fight stays ephemeral.
- **`TacticalBoardViewModel.to_dictionary()` keeps its 16-key contract** (line 303). The reward HUD is a SEPARATE read
  surface (like the affinity read / G1 HUD), never a board-VM key.
- **`PassiveRewardModalViewModel.MODAL_KEYS` and `RewardOffer.DICTIONARY_KEYS` are unchanged.** Render from them; add none.
- **The hands-off auto-resolve driver + every generator/route/finale seed-regression fingerprint stay byte-identical.**
  The reward GENERATE is wired into the interactive shell path only; `run_to_completion` never generates a reward.
- **No new autoload; `scripts/rules/conditions/` stays EMPTY; `scripts/rules/operations/` stays exactly one file.** This
  story wires no passive-combat-effect engine (Consume adopts a passive id into the resolver; it does not effect-wire it).

### UX appendix references (the interaction contract, already designed — Story 11.1)

- **Two-step commit (FR11, §2):** the Consume/Destroy choice arms on the first tap and commits on the confirming tap —
  ALREADY implemented in `PassiveRewardCommitFlow` (the mobile mis-tap protection). You wire the buttons to `arm_*` /
  `confirm()`; the two-step is inside.
- **≥44×44 targets (§14.1):** the reward-choice buttons (accept / Consume / Destroy / cancel) stay ≥44×44 and reachable
  on every layout profile; honor the semantic `TacticalLayoutProfile` region plan, never hardcoded geometry.
- **Passive modal content (FR47/§8):** the modal shows the evocative name, one flavor line, the EXACT mechanical
  effects, the Consume text, the Destroy text, and the honest-unknown downside — every field is already on `MODAL_KEYS`.

### The 13-1 → 13.2 carried defer (fold in, do not drop — Task 5)

Deferred-work ledger, "code review of 13-1 (2026-07-14)":
> **[Review][Defer]** (Low) — Inspect taps produce no on-screen feedback. `interactive_inspect(cell)`
> (`tactical_board_presenter.gd:417-420`) routes into `_session.inspect(cell)` (metadata-only) but neither re-renders
> nor surfaces the returned result … Owner: **Story 13.2 reward/passive-HUD story, or a later board-polish pass.**

Since 13.2 already modifies the presenter's HUD regions, surfacing the inspect result in the `inspect` region is cheap
(re-render + set the region text from the returned `CommandBridgeResult` cell facts). Decide in Task 5: pick it up, or
knowingly carry it forward (leave the ledger entry open + record the decision). The OTHER 13-1 defer (on-device human
playtest of the tap-to-fight loop, owner: the physical-device pass) is NOT this story's — but this story adds the
reward/passive HUD that the same on-device pass will exercise, so it likewise UNBLOCKS (does not itself close) the
human-eyes confirmation for loop steps 6/7.

### Test harness facts

- **Run command (project CLAUDE.md):** `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- **`godot` is NOT on the Bash/`where` PATH** — run via PowerShell as `C:\Users\Rasmus\bin\godot.cmd`, OR the binary
  directly (`C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe ...`). **Run via a
  PowerShell `.ps1` + `-File`, NOT inline `-Command` through Bash** (Git Bash expands `$LASTEXITCODE` first → silent
  parse failure; Epic-10 retro §8 P3). Runner output is UTF-16LE — decode (`tr -d '\000'`) before grepping.
- **Test discovery is automatic** — `test_runner.gd` recursively walks `res://tests/unit` + `res://tests/integration`;
  a new `test_*.gd` under those trees needs NO manifest edit.
- **False-PASS guard (standing gate, Epic-10 P3):** grep the RAW output for `SCRIPT ERROR|Parse Error|^FAIL`. Exactly 6
  documented stderr negatives are expected (int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1); this story
  adds ZERO new documented negative. Never "fix" the catalog by changing a test.
- **Baseline to preserve: 193 PASS / 0 `^FAIL`** (the post-13.1 baseline). This story ADDS tests (any new seam); new
  total ≥ 193, 0 `^FAIL`.
- **Reuse these green tests (do NOT duplicate):** `test_reward_offer_generate.gd`, `test_resolve_reward_command.gd`,
  `test_consume_passive_command.gd`, `test_destroy_passive_command.gd`, `test_passive_reward_modal_view_model.gd`,
  `test_passive_reward_commit_flow.gd`, `test_reward_offer.gd`, `test_reward_table_repository.gd`,
  `test_loot_passive_build_smoke_run.gd` (the 10-6-gate integration reference this story promotes to live-HUD),
  `test_run_flow_scenes_load.gd` (the compile guardrail — must still cover the two modified presenters + any new
  reward `.tscn`), `test_tactical_board_view_model.gd` (16-key pin), `test_run_route_position_save.gd` (23-key gate).

### Explicit Non-Goals (out of scope — do NOT do here)

- **No domain / command / contract change.** No new command, no new `DomainEvent.Type`, no new RNG stream/draw site
  (outside the existing orchestrator generate + `DestroyPassiveCommand` roll), no new board-VM key, no new autoload, no
  save-key change. This is additive presentation + flow wiring over pinned contracts.
- **No auto-wire into the hands-off driver.** Do NOT generate rewards inside `run_to_completion` / `_resolve_combat` /
  `auto_play_boss_fight` (they stay byte-identical). The boss stays auto-play → run-end → outpost (no combat-node reward
  HUD on the boss).
- **No passive-combat-effect engine.** Consume ADOPTS a passive id into the resolver (the existing command); it does not
  effect-wire the passive into combat. `scripts/rules/conditions/` stays EMPTY; `scripts/rules/operations/` stays one file.
- **No new reward CONTENT.** Use the three existing baseline tables + the six baseline passives. Author no `.tres`/JSON.
- **No event-node (7.3) rework.** The `event` node's own offer/choose pair (`generate_event_offer` /
  `ChooseEventOptionCommand`) is a SEPARATE surface — out of scope. The primary path is the combat/elite victory →
  reward offer.
- **No route-position persistence of the offer / no in-node save.** The pending offer rides only the full
  `RunState.to_dictionary()`; the 23-key gate stays 23; the fight stays ephemeral.
- **No new art required.** The modal `icon` is a placeholder id string; rendering the text fields satisfies the ACs.
  (Icon-glyph art is optional polish and, if used, follows the 13.1 import + `.import` sidecar + defensive-`load()`
  discipline.)

### Regression traps (things that will silently break if you are not careful)

- **Extending `TacticalCommandBridge` for rewards is the wrong approach.** It handles only tactical `move`/`attack`/
  `inspect` against a `TacticalActionContext`. Reward/passive commands execute against `RunState` — use the run-command
  idiom (construct + `execute(run)` with `next_sequence_id()`), like `RunEndProfileBridge` does for the run-end commands.
- **Auto-generating rewards in the hands-off driver breaks the seed-regression fixtures.** Wire generate into the
  INTERACTIVE shell path only. `run_to_completion` must never generate a reward (`project-context.md:442`).
- **Double-resolving a passive offer double-records.** A passive offer goes to EXACTLY ONE of the three commands. The
  modal routes to Consume or Destroy — do NOT also call `ResolveRewardCommand` on it.
- **`DestroyPassiveCommand` with a fresh RNG breaks determinism.** It MUST receive the run-level `orchestrator.streams`
  (the ONE `STREAM_REWARDS` draw); a fresh `RandomNumberGenerator` would desync the run's stream state and break a
  route-position resume round-trip.
- **A full backpack on a backpack-reward resolve leaves the offer `pending`** (fail-closed `inventory_full`, no silent
  delete). Surface it honestly in the HUD; do NOT advance the flow as if resolved.
- **Adding a board-VM key or a `MODAL_KEYS`/`DICTIONARY_KEYS` key to carry render data breaks the pinned-contract tests.**
  Render from the existing keys; the reward HUD is a separate composed surface (the affinity-read / G1-HUD precedent).
- **Persisting the offer into the route-position `RunSnapshot` breaks the 23-key gate.** The offer rides only the full
  `RunState.to_dictionary()` — do not touch `to_run_snapshot_fields()`.
- **A cancelled Consume/Destroy that runs a command violates AC2.** `cancel()`/`dismiss()` must run NO command and leave
  the `RunState` byte-identical — prove it.

### Project Structure Notes

- The reward-HUD render + resolve wiring lives in the EXISTING `gameplay_shell_presenter.gd` +
  `tactical_board_presenter.gd` (`godot/scripts/ui/presenters/`). Any NEW pure seam (a reward-render projection or a
  resolve-routing decision) goes under `godot/scripts/ui/view_models/` as a `RefCounted`, headlessly testable; tests
  mirror under `godot/tests/unit/ui/`. A new reward overlay `.tscn`, if added, goes under `godot/scenes/game/` or
  `godot/scenes/ui/` and is covered by `test_run_flow_scenes_load.gd`. No new content, no new art required.
- Naming: `snake_case` files/folders, `PascalCase` classes, `snake_case` funcs/vars/signals, `UPPER_SNAKE_CASE` consts.
- Commit the `.gd.uid` sidecar for any NEW script file (the ratified 13-1 VC convention — commit, never gitignore).

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — read it before implementing; when in doubt choose the
more restrictive interpretation):

- **Presentation observes domain state/events and submits commands.** Godot scenes / `Control` nodes are presentation —
  they own NO run/tactical truth. The reward HUD reads `run.pending_reward_offer`; clicks execute the existing commands.
- **Reward GENERATE is an explicit caller-driven orchestrator method — never auto-wired into the hands-off driver**
  (lines 191/442). Reward/loot commands (resolve/consume/destroy/use) are ALL pure caller-driven commands with NO
  orchestrator convenience method — construct + execute them directly with a `next_sequence_id()`.
- **A pending passive offer is resolved by exactly one command; Consume adopts into the `RulesResolver`, Destroy rolls
  the exact-integer 70/20/10 on `STREAM_REWARDS` (one draw, run-level streams)** (lines 194–196/446–447).
- **Headless simulation is a first-class target** — assertable logic lives in `RefCounted` seams; `.tscn`/`Control`
  wiring is verified by construction + the compile guardrail (no SceneTree test). Do NOT trust a prose "wired" claim
  without grepping the probed method against source (the 11.3 M2 dead-probe lesson).
- **Keep autoloads thin; add no new autoload.** Acceptable: `GameSession`, `SceneManager`, `SaveManager`,
  `AudioManager`, `SettingsManager`, `Diagnostics`.
- **Save versioned domain snapshots only; the offer rides the full `RunState` dict, not the route-position snapshot.**
  The 23-key `RunSnapshot` gate stays 23; the in-node fight stays ephemeral. This story persists nothing new.
- **Difficulty is a hard non-goal** — no difficulty selector/knob anywhere. This story renders + wires reward clicks;
  it changes no balance number.
- **AI tooling (Godot MCP / Context7) is dev-time only** — the game never calls AI for runtime content. This story
  authors no content; it wires the existing loot/reward layer to live clicks over approved static content.
- **Honesty posture (Epic-10 retro §5/§7):** the human-eyes render/click confirmation for loop steps 6/7 (real
  legibility + click accuracy on a physical display) is the on-device pass this story UNBLOCKS; record it against the
  physical-device observed-playtest owner — do NOT claim a human-eyes pass a headless run cannot produce.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Epic 13: Human-Playable Board` (Epic List lines 513–519; Story 13.2 lines 2934–2955)]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-13.md` — the playability gap; 13.2 = the reward/passive HUD half of the fix]
- [Source: `_bmad-output/implementation-artifacts/13-1-live-board-render-and-tap-input.md` — the presenter/shell seam map, the scene-free testing discipline, the `.gd.uid` sidecar VC convention, the false-PASS grep + PowerShell `-File` gate, the Explicit Non-Goal "reward-offer render + passive Consume/Destroy modal — that is Story 13.2"]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of 13-1 (2026-07-14)` — the inspect-tap on-screen-feedback `[Review][Defer]`, owner "Story 13.2 … or a later board-polish pass"]
- [Source: `_bmad-output/auto-gds/retro-notes/epic-13.md` — 13-1 lessons: reuse-existing-seams job pattern; the `*.gd.uid` sidecar commit convention; art must be imported + sidecars committed if art is consumed]
- [Source: `_bmad-output/planning-artifacts/mvp-readiness-gate.md` §3.3 — loop steps 6/7 "PRESENT + integration-proven only, live-HUD-wiring-deferred" (the qualifier this story discharges)]
- [Source: `project-context.md` lines 183–199 (Epic-6 loot/reward/inventory/consume-destroy rules), 441–449 (critical don't-miss reward rules), 256–270 (Epic-11 run-flow-scene-hud), 272–281 (Epic-12 interactive), 300–306 (Epic-2 presentation/view-model incl. the 16-key board-VM pin + "later HUD story"), 322/337–338 (perf + asset placement)]
- [Source: `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — the victory boundary `_on_interactive_action_committed:172` → `_advance_to_route_map:197`; the non-combat resolve path `:158-164`; boss auto-play `:74`]
- [Source: `godot/scripts/ui/presenters/tactical_board_presenter.gd` — the six regions `:95-102`; `passive_reward_modal(index):359`; `PassiveRewardCommitFlow` import `:28` (un-instantiated); `interactive_inspect:417`]
- [Source: `godot/scripts/run/run_orchestrator.gd` — `generate_reward_offer:404`, `generate_passive_reward_offer:447`, `next_sequence_id:894`, `streams`]
- [Source: `godot/scripts/run/reward_offer.gd` — the `RewardOffer` shape / `DICTIONARY_KEYS` / `has_offered_entry`; rides only the full `RunState.to_dictionary()`]
- [Source: `godot/scripts/ui/view_models/passive_reward_modal_view_model.gd` — `MODAL_KEYS:45-56`, `project_offer:91`, fail-closed identity-absent]
- [Source: `godot/scripts/ui/view_models/passive_reward_commit_flow.gd` — `arm_consume`/`arm_destroy`/`confirm`/`cancel`/`dismiss` (two-step, zero-mutation back-out)]
- [Source: `godot/scripts/core/commands/resolve_reward_command.gd:58` / `consume_passive_command.gd:69` / `destroy_passive_command.gd:99` — the three resolution-command constructors + apply-by-category / adopt / roll-70-20-10]
- [Source: `godot/scripts/content/repositories/reward_table_repository.gd:20,100-140` — the 3 baseline tables `standard_combat_reward`/`elite_combat_reward`/`passive_reward_choice`]
- [Source: `godot/scripts/content/definitions/destroy_outcome_table_definition.gd:155` — `create_baseline_table()` (the 70/20/10 outcome table `DestroyPassiveCommand` needs)]
- [Source: `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` — move/attack/inspect ONLY (NOT a reward path)]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (claude-opus-4-8[1m]) — auto-gds dev-story delegate.

### Debug Log References

- Full headless suite (post-implementation + post-import): **195 PASS / 0 `^FAIL`**, exit 0, "Headless tests passed."
  (baseline 193 + the 2 new seam tests). False-PASS grep (`SCRIPT ERROR|Parse Error|^FAIL`) = 0. Exactly the 6
  documented stderr negatives (int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1); ZERO new negative.
- AC3 invariant pins all green: `test_seed_regression_suite.gd` (fingerprints byte-identical — the hands-off driver
  is untouched), `test_run_route_position_save.gd` (23-key gate), `test_run_flow_scenes_load.gd` (compile guardrail —
  both modified presenters still compile), `test_tactical_board_view_model.gd` (16-key board VM),
  `test_passive_reward_modal_view_model.gd` (MODAL_KEYS), `test_reward_offer.gd` (DICTIONARY_KEYS).

### Completion Notes List

- **Implemented (dev-story, 2026-07-16):** Wired the post-victory reward + passive Consume/Destroy HUD as pure
  presentation + flow-wiring over the pinned Epic-6/7 contracts. Added NO domain command, NO new `DomainEvent.Type`
  (tail stays `oath_shards_spent`), NO new RNG stream (`required_streams()` == 7), NO schema/save-key change, NO new
  autoload, NO board-VM/MODAL_KEYS/DICTIONARY_KEYS key. The reward GENERATE is wired into the INTERACTIVE shell path
  ONLY (`gameplay_shell_presenter._on_interactive_action_committed` victory branch) — never `run_to_completion` /
  `_resolve_combat` / `auto_play_boss_fight`, so every seed-regression fingerprint stays byte-identical.
- **Two new RefCounted seams (headlessly tested):**
  - `RewardHudViewModel` (`godot/scripts/ui/view_models/reward_hud_view_model.gd`) — the exact-key render projection
    (`REWARD_KEYS`/`CHOICE_KEYS`); reuses `PassiveRewardModalViewModel.project_offer` (its pinned `MODAL_KEYS`,
    identity-absent for a generic entry) so it adds no key; also owns the v0 node→table policy static.
  - `RewardResolutionBridge` (`godot/scripts/ui/flow/reward_resolution_bridge.gd`) — the caller-driven run-command
    seam that constructs + executes EXACTLY ONE of `ResolveRewardCommand` / `ConsumePassiveCommand` /
    `DestroyPassiveCommand` against `RunState` with `orchestrator.next_sequence_id()`, mirroring `RunEndProfileBridge`'s
    idiom (NOT a `TacticalCommandBridge` intent). Placed under `scripts/ui/flow/` alongside the other execute-capable
    run-command bridges (`RunEndProfileBridge`/`OutpostSpendBridge`) rather than `view_models/` — the story's Task 3
    "mirror `RunEndProfileBridge`" is the more specific instruction, and `flow/` is the established home for a seam that
    EXECUTES commands; the pure render projection stays in `view_models/` per Task 6.
- **[Decision — RESOLVED by human ratify, 2026-07-16] v0 node→table policy** (`RewardHudViewModel.table_for_node_type(node_type, node_depth)`):
  the guaranteed **depth-0 opener combat node** earns the passive Consume/Destroy 3-choice moment
  (`passive_reward_choice`); a **deeper `combat` node** earns a generic single-pick reward (`standard_combat_reward` →
  the accept-click `ResolveRewardCommand` path); an **`elite_combat` node** earns the richer generic single-pick reward
  (`elite_combat_reward`); every other node type earns no combat-node reward HUD (its own surface owns its offer — the
  event-node 7.3 pair is out of scope). This resolves the review's `[Review][Decision]` in the human-chosen direction
  (elite → `elite_combat_reward`, plus a DIFFERENT deterministic passive trigger). The passive trigger — the depth-0
  opener — is deterministic (the route generator ALWAYS seats depth 0 as `combat` with no type RNG; the run parks there
  at start) and ALWAYS reachable (the FIRST fight of every run), so a normal desktop playtest exercises the passive
  Consume/Destroy UI on the opening victory AND a generic reward on every deeper combat/elite victory. All THREE
  baseline tables are now used in the live flow (`elite_combat_reward` is no longer intentionally-unused). The policy
  stays isolated in the single tested seam; the seam unit test pins the new mapping, and the hands-off driver +
  seed-regression fingerprints stay byte-identical (the reward GENERATE is wired into the interactive shell path only).
- **[Decision] Task 5 — the carried 13-1 inspect-feedback defer is PICKED UP (closed), not carried forward.** Since
  13.2 already modifies the presenter HUD regions, `interactive_inspect` now stores the returned `CommandBridgeResult`
  cell facts + re-renders, so an inspect tap surfaces the tapped cell (coords, visibility, occupant id/type/HP) in the
  inspect region instead of the static "Inspect: tap a cell". Still a pure metadata-only read (no mutation, no turn
  advance). The deferred-work ledger entry for this `[Review][Defer]` is now resolved (the OTHER 13-1 defer — the
  on-device human playtest — remains the physical-device owner's; this story adds the reward/passive HUD that same pass
  will exercise, UNBLOCKING but not closing the human-eyes confirmation for loop steps 6/7).
- **[Honesty posture] AC3 human-eyes pass:** the headless run proves the flow generates → renders → resolves →
  advances and every invariant holds byte-identical. The real legibility + click-accuracy confirmation on a physical
  display is the on-device pass this story UNBLOCKS; it is logged against the physical-device observed-playtest owner,
  NOT claimed here (a headless run cannot produce it).
- **Known v0 edge (consistent with the existing domain decision):** a generic backpack-item reward resolved against a
  FULL backpack surfaces `inventory_full` VERBATIM and leaves the offer `pending` (the shell re-renders honestly and
  does NOT advance) — the "later replacement-choice UX owns the full-backpack disposition" residual
  (`resolve_reward_command.gd:25`). Not reachable in an early desktop playtest (the backpack starts empty).
- **Verified (create-story, 2026-07-16):** Ultimate context engine analysis completed — comprehensive developer guide
  created. Folds in: the Epic 13 / Story 13.2 canonical ACs; the 2026-07-13 sprint-change scope; the 10-6 gate §3.3
  loop-steps-6/7 qualifier this story discharges; the 13-1 carried inspect-feedback defer (owner: this story or a later
  polish pass); the epic-13 retro lessons (reuse-existing-seams job pattern, the committed `*.gd.uid` sidecar
  convention, art-import discipline if icon art is consumed). The key anti-reinvention find is pinned: the reward
  GENERATE, the pending-offer store, the passive modal projection (`MODAL_KEYS`), the two-step `PassiveRewardCommitFlow`,
  AND all three resolution commands already exist and are unit-tested — this story wires the generate into the
  interactive-shell post-victory boundary, renders the offer as clickable UI, and routes clicks into the existing
  run-domain commands, adding no domain/command/event/RNG/VM-key/autoload change. The one genuine design latitude — the
  v0 node→table policy + wiring the generate at the interactive-shell boundary (NOT the hands-off driver) — is scoped
  with the sensible default and flagged as the review decision point.

### File List

**New (production seams):**
- `godot/scripts/ui/view_models/reward_hud_view_model.gd` (+ `.uid`) — the reward-HUD render projection + v0 node→table policy
- `godot/scripts/ui/flow/reward_resolution_bridge.gd` (+ `.uid`) — the caller-driven run-command resolution bridge

**New (tests):**
- `godot/tests/unit/ui/test_reward_hud_view_model.gd` (+ `.uid`) — REWARD_KEYS/CHOICE_KEYS pins, empty state, generic/passive projection, detection, node→table policy
- `godot/tests/unit/ui/test_reward_resolution_bridge.gd` (+ `.uid`) — generic resolve, Consume, Destroy (stream advance + determinism), no-mutation back-out, exactly-one-command, fail-closed paths

**Modified (presenter wiring — verified by construction via `test_run_flow_scenes_load.gd`):**
- `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — the reward step at the interactive victory boundary (`_begin_reward_step` GENERATE + `_on_reward_resolution_requested` resolve/advance)
- `godot/scripts/ui/presenters/tactical_board_presenter.gd` — the reward overlay render + the two-step `PassiveRewardCommitFlow` wiring + the Task-5 inspect-feedback surface

**Modified (tracking):**
- `_bmad-output/implementation-artifacts/13-2-live-reward-and-passive-choice-hud.md` — this story file (frontmatter `baseline_commit`, tasks, Dev Agent Record, Status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `13-2` status `ready-for-dev` → `in-progress` → `review`

### Change Log

- 2026-07-16 — Implemented Story 13.2 (live reward + passive-choice HUD). Wired the post-victory reward GENERATE at
  the interactive-shell boundary, rendered `run.pending_reward_offer` (generic accept + passive 3-choice Consume/Destroy
  modal) as an additive clickable overlay, and routed clicks into the EXISTING run-domain commands via the new
  `RewardResolutionBridge`. Picked up the carried 13-1 inspect-feedback defer (Task 5). Added no domain/command/event/
  RNG/VM-key/autoload/save-key change. Suite 195 PASS / 0 FAIL; all AC3 invariants byte-identical. Status → review.
- 2026-07-16 — Review round 1 `[Review][Decision]` RESOLVED (human ratify). Re-pointed the v0 node→table policy:
  `elite_combat` → `elite_combat_reward` (the richer generic single-pick, previously unused), and the passive 3-choice
  moment now fires on a DIFFERENT deterministic trigger — the guaranteed depth-0 opener combat node (deterministic +
  always reachable, the first fight of every run). Extended the isolated policy seam to
  `RewardHudViewModel.table_for_node_type(node_type, node_depth)` and threaded `_active_node.depth` at the one presenter
  call site; updated the seam unit test to the new mapping. Hands-off driver + seed-regression fingerprints unchanged
  (reward GENERATE stays interactive-only). Suite re-run 195 PASS / 0 `^FAIL`, exit 0; false-PASS guard clean; the 6
  documented stderr negatives only, zero new. The 3 `[Review][Defer]` items remain deferred (unchanged).

### Review Findings

**Round 1 of 3**

Primary adversarial code review (`gds-code-review`, 2026-07-16; branch `story/13-2-live-reward-and-passive-choice-hud`
vs `main`). **Verdict: Approve.** Critical 0 / High 0 / Med 0 / Low 3; 1 open `[Review][Decision]` (a human call).
Suite INDEPENDENTLY re-run on the review head: **195 PASS / 0 `^FAIL`** (exit 0; false-PASS guard
`SCRIPT ERROR|Parse Error|^FAIL` clean; exactly the 6 documented stderr negatives — int64-overflow ×2 / malformed-JSON
×3 / `invalid_node_type` ×1, ZERO new; `git diff --check` clean). Both new seam tests
(`test_reward_hud_view_model.gd`, `test_reward_resolution_bridge.gd`) present + green.

AC1/AC2/AC3 verified against source, not prose:
- The reward GENERATE is wired into the interactive-shell victory boundary ONLY — `generate_reward_offer` /
  `generate_passive_reward_offer` grep-confirmed to have exactly ONE live caller (`gameplay_shell_presenter._begin_reward_step`),
  never `run_to_completion` / `_resolve_combat` / `auto_play_boss_fight`; `finish_interactive_combat_node` generates no
  offer, so the `reward_offer_pending` guard cannot trip at the victory boundary (AC3 fingerprints byte-identical).
- `RunFlowController.run()` returns `_orchestrator.run` (SAME object), so the offer the generate stores on
  `orchestrator.run.pending_reward_offer` IS the one the board presenter renders via `_run.pending_reward_offer`.
- The three resolution commands are constructed with the exact real signatures + the run-level `orchestrator.streams`
  + `orchestrator.next_sequence_id()`; Destroy draws exactly ONE `STREAM_REWARDS` draw through the run streams (test
  pins the +1 draw-index advance + same-seed determinism); exactly-one-command holds (a second resolve fails closed
  `reward_offer_already_resolved`).
- The node→table policy routes the UI deterministically with no category/UI mismatch: both baseline combat tables
  (`standard_combat_reward` / `elite_combat_reward`) draw ONLY non-passive categories, and only `passive_reward_choice`
  yields `passive` entries, so `RewardHudViewModel.is_passive_offer` (reads the offer's actual entries) always matches
  the intended surface. [Updated post-resolution, 2026-07-16] Under the ratified mapping the surfaces are: the depth-0
  opener combat → passive Consume/Destroy (`passive_reward_choice`); a deeper combat → generic Accept
  (`standard_combat_reward`); an elite → generic Accept (`elite_combat_reward`).
- Task 5 (inspect feedback) is NOT a dead probe: `_inspect_facts_from` reads `target_cell.{x,y}` +
  `cell.{visibility_state, occupant_id, entity_type, current_hp}`, which match `TacticalCommandBridge._build_inspect_result`
  (`target_cell` = `_cell_metadata` = `{x,y}`; `cell` = the `visible_facts_for_cell` fact) and
  `TacticalVisibilityQuery.visible_facts_for_cell` (occupant fields present only for a visible + occupied cell) exactly.
  The carried 13-1 inspect-feedback `[Review][Defer]` is legitimately CLOSED (ledger entry marked resolved).

- **[Review][Decision] — RESOLVED (human ratify, 2026-07-16)** — the v0 **node → reward-table policy**
  (`RewardHudViewModel.table_for_node_type`) is the story's one explicitly-flagged design latitude. The human chose the
  "stronger reward-policy intent" direction the finding flagged as the knob to revisit: **elite nodes now route to the
  richer generic `elite_combat_reward` table (previously the unused table), and the passive 3-choice moment fires on a
  DIFFERENT deterministic trigger — the guaranteed depth-0 opener combat node.** The seam was updated to
  `table_for_node_type(node_type, node_depth)` (still the single isolated policy static):
  - `combat` at **depth 0** → `passive_reward_choice` (the passive Consume/Destroy 3-choice moment). The route
    generator ALWAYS seats depth 0 as a `combat` node with NO type RNG (`route_generator.gd`: "the depth-0 start … is
    always `combat`"), and the run parks there at start (`RouteState.new(ordered_nodes, ordered_nodes[0].id, …)`), so
    this trigger is **deterministic** (fixed by the route STRUCTURE, not an RNG draw — independent of seed) and **always
    reachable** — it is the FIRST fight of every run, so a desktop playtester sees the passive UI immediately.
  - `combat` at **depth > 0** → `standard_combat_reward` (generic single-pick).
  - `elite_combat` (any depth) → `elite_combat_reward` (the richer generic single-pick; elites never appear at depth 0,
    so no depth branch is needed for them).
  - every OTHER node type → no reward HUD.
  Consequences preserved: (1) the reward step is still wired ONLY at the interactive-combat victory boundary — the
  non-combat resolve path (`gameplay_shell_presenter.gd`) does NOT call `_begin_reward_step`, so AC1's "or resolves a
  non-combat node" is discharged by the policy returning `has_reward=false` for non-combat, and a future policy that
  wants non-combat rewards must ALSO wire `_begin_reward_step` into that path. (2) The hands-off driver stays
  byte-identical — the reward GENERATE is wired into the INTERACTIVE shell path only (no seed-regression fixture drives
  it; `test_seed_regression_suite.gd` calls `generate_reward_offer`/`generate_passive_reward_offer` DIRECTLY, never
  through this policy), so changing the table mapping moves NO pinned fingerprint. (3) All three baseline tables are now
  exercised in the live flow (`standard_combat_reward` / `elite_combat_reward` generic; `passive_reward_choice` passive)
  — `elite_combat_reward` is no longer intentionally-unused. Both baseline combat tables draw ONLY non-passive
  categories and only `passive_reward_choice` yields `passive` entries, so `RewardHudViewModel.is_passive_offer` (reads
  the offer's actual entries) always matches the intended surface (opener → passive Consume/Destroy; deeper combat +
  elite → generic Accept). Isolated in the single tested seam; the seam unit test
  (`test_reward_hud_view_model.gd::_node_table_policy_maps_opener_combat_deep_combat_elite_and_defaults`) pins the new
  mapping (depth-0 opener passive; deeper-combat generic; elite `elite_combat_reward`; other none). Suite re-run green.
- **[Review][Defer]** (Low) — the GENERIC reward HUD has no skip/drop affordance. A backpack-category reward resolved
  against a FULL backpack returns `inventory_full` and (by the documented Epic-6 domain decision,
  `resolve_reward_command.gd:25`) leaves the offer `pending`; the shell re-renders and does NOT advance
  (`gameplay_shell_presenter._on_reward_resolution_requested:254-259`), but the generic overlay exposes ONLY an
  "Accept reward" button — clicking it re-triggers the same reject, a potential **soft-lock with no player escape**.
  The fail-closed domain behavior is CORRECT; the missing HUD escape hatch is the gap. Not reachable in an early
  desktop playtest (the backpack starts empty; `standard_combat_reward` yields gold ~⅓ of the time, which always
  resolves). Owner: the later replacement-choice / full-backpack disposition UX (the `resolve_reward_command.gd:25`
  residual). Since 13.2 is the story that made this a live human-playable path, it is logged here so the escape-hatch
  gap is tracked, not just the domain residual.
- **[Review][Defer]** (Low) — the reward overlay uses hardcoded geometry (a full-rect `Panel`, fixed 24px
  `MarginContainer` insets, fixed header `font_size` 22) and a plain `VBoxContainer` with NO `ScrollContainer`, instead
  of honoring the semantic `TacticalLayoutProfile` region plan (`tactical_board_presenter.gd:850-999`). On a small
  viewport, the passive 3-choice modal (name + flavor + effect + consume + destroy + optional unknown-downside ≈ 6
  lines × 3 choices, plus per-choice Consume/Destroy rows) can overflow vertically and push the ≥44×44 targets off
  the bottom edge, weakening §14.1 "targets reachable on every layout profile." Presentation-only, verified by
  construction (no SceneTree test); the ≥44px minimum size itself is set (`_reward_button`). Owner: the on-device
  layout / board-polish pass (the same physical-device human-eyes pass this story UNBLOCKS for loop steps 6/7).
- **[Review][Defer]** (Low) — `_inspect_facts_from` (Task 5, `tactical_board_presenter.gd:478-496`) is a pure
  `CommandBridgeResult` → facts-dict transform that lives in the presenter and is therefore untested. Its key reads are
  correct against source TODAY (verified this review), but per the story's own "assertable logic in `RefCounted` seams"
  rule + the 11.3 dead-probe lesson, extracting it into a tiny `RefCounted` seam with a unit test would guard those
  metadata keys against a future silent inspect-fact-shape drift. Optional hardening; non-blocking (no correctness
  defect). Owner: a later board-polish / test-hardening pass.

Deferrals copied to the cross-story ledger (`deferred-work.md`) under
`## Deferred from: code review of 13-2-live-reward-and-passive-choice-hud (2026-07-16)`.

**Round 2 of 3**

Secondary INDEPENDENT adversarial review (alternate-model diversity pass; `gds-code-review`, 2026-07-16; branch
`story/13-2-live-reward-and-passive-choice-hud` vs `main`). **Verdict: Approve.** Critical 0 / High 0 / Med 0 / Low 1
(one NEW Low `[Review][Defer]`, below). 0 open `[Review][Decision]`. This round re-reviewed the WHOLE story diff fresh
with particular attention to the post-round-1 fix — the human-ratified v0 node→table policy re-point (`elite_combat` →
`elite_combat_reward`, and the passive 3-choice moment moved onto the guaranteed depth-0 opener combat node): the
policy seam (`reward_hud_view_model.gd`), the presenter depth-threading (`gameplay_shell_presenter.gd`), and the
updated seam test.

Suite INDEPENDENTLY re-run on the review head: **195 PASS / 0 `^FAIL`** (exit 0; false-PASS guard
`SCRIPT ERROR|Parse Error|^FAIL` clean — 0 matches; exactly the 6 documented stderr negatives reproduced —
int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1, ZERO new; `git diff --check` clean). Both new seam
tests executed + green (`PASS res://tests/unit/ui/test_reward_hud_view_model.gd`, `PASS
res://tests/unit/ui/test_reward_resolution_bridge.gd`).

Post-round-1 fix VERIFIED correct + regression-free (against source, not prose):
- **Depth threading is correct.** `gameplay_shell_presenter._on_interactive_action_committed` captures
  `node_depth = _active_node.depth` (+ `node_type`) BEFORE `finish_interactive_combat_node` runs `NodeExitCommand`
  (which advances `current_node_id`), so the policy keys off the RESOLVED node's real depth, not the advanced node.
- **The depth-0 passive trigger is genuinely deterministic + reachable.** `route_generator.gd` seats depth 0 as an
  always-`combat` node with NO type-selector RNG (lines 33-34, 206) and `RouteState.new(ordered_nodes,
  ordered_nodes[0].id, …)` (line 283) parks the run there, so the opener victory is the FIRST interactive fight of
  every run and `table_for_node_type(&"combat", 0)` → `passive_reward_choice` fires on it. A fresh-run opener Consume
  works (the run's `rules_resolver` exists at start — pinned by `test_reward_resolution_bridge`).
- **The victory-boundary generate cannot trip the pending guard.** `finish_interactive_combat_node` emits NO offer on
  victory (only `NodeExitCommand`), so `_begin_reward_step`'s subsequent `generate_passive_reward_offer` /
  `generate_reward_offer` is the sole generate — the AC3 fingerprints stay byte-identical (the reward GENERATE remains
  interactive-only; the hands-off driver + `test_seed_regression_suite` are untouched, confirmed green).
- **The seam test pins the new mapping** (`_node_table_policy_maps_opener_combat_deep_combat_elite_and_defaults`):
  depth-0 combat → passive; deeper combat (1/2/5) → `standard_combat_reward`; elite (1/3/6) → `elite_combat_reward`;
  every other type → no reward. The policy `is_passive` flag and the projection's `is_passive_offer` recompute stay
  coherent (both baseline combat tables draw only non-passive entries; only `passive_reward_choice` yields passive).
- **AC2 back-out mutates nothing in the LIVE flow.** `_on_passive_cancel` → `commit_flow.cancel()` + re-render, never
  notifies the shell → no command runs. The re-entrant free of the just-pressed button is safe (`_clear_reward_box`
  uses `remove_child` + `queue_free`, deferring deletion past the `pressed` emission — verified on both the passive-arm
  and the generic inventory_full re-render paths).
- **Exactly-one-command holds.** A passive offer only ever reaches `_build_passive_reward_ui` (Consume/Destroy →
  Consume/DestroyPassiveCommand), never the generic Accept (`ResolveRewardCommand`); the bridge test pins the
  no-double-record + the fail-closed second-resolve (`reward_offer_already_resolved`).

- **[Review][Defer]** (Low) — the passive CONFIRM step (`tactical_board_presenter._build_passive_confirm_ui`,
  `:~880`) renders the raw snake_case `passive_content_id` (e.g. "Confirm Consume of `warrior_unbreakable_guard`?")
  instead of the evocative `display_name` the choice list showed a tap earlier, and drops the modal context (flavor /
  exact effects / Consume+Destroy text) the pre-arm choice list carried. `PassiveRewardCommitFlow.to_dictionary()`
  exposes only the raw id, so the confirm prompt would need to re-read the projected `display_name` (already available
  in the `RewardHudViewModel` projection) to match. Cosmetic legibility polish only — BELOW the AC bar (the full
  MODAL_KEYS text IS shown in the choice list before arming, and a Cancel returns to it with zero mutation); no
  correctness / determinism / AC impact. Owner: the on-device layout / board-polish pass (the same physical-device
  human-eyes pass this story UNBLOCKS — folds in with the Round-1 hardcoded-overlay-geometry defer).

The three Round-1 `[Review][Defer]` items (generic-HUD no-skip soft-lock; hardcoded-overlay-geometry / no
`ScrollContainer`; `_inspect_facts_from` untested presenter transform) remain valid + deferred (unchanged — each
re-verified still accurate this round). New deferral copied to the cross-story ledger (`deferred-work.md`) under
`## Deferred from: code review of 13-2-live-reward-and-passive-choice-hud round 2 (2026-07-16)`.
