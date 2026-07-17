# Sprint Change Proposal — 2026-07-16: Epic 14 "Playable & Presentable" (post-Epic-13 agent-playtest gap)

## 1. Issue Summary

An agent-driven desktop playtest of the built game (2026-07-16, `main` @ `259c32b`, post-Epic-13; full record
`playtest-sessions/agent-playtest-2026-07-16.md`) found the MVP is **not honestly playable and looks unfinished**.
Two runs were played on the real Windows build via OS-level mouse/keyboard; **neither could be completed** — run 1
ended in an unexplained death, run 2 ended in a **permanent mid-fight soft-lock**. This is the same class of trigger
as the 2026-07-13 desktop playtest that created Epic 13 (`sprint-change-proposal-2026-07-13.md`): a hands-on session
exercised every reachable surface and recorded concrete defects the readiness gate under-weighted.

The findings (F1–F16 in the playtest file) split cleanly into two bands the playtest's own Disposition names:

- **Band 1 — the loop is not finishable or readable.** A guaranteed mid-fight **soft-lock** (F1: dead enemies block
  movement, there is no wait/pass affordance, and enemy turns only advance on a *successful* player action — so a hero
  boxed in by corpses + walls with the last enemy out of reach can never act again); an **invisible attack preview**
  (F2: the two-step commit's armed state has zero on-screen presence — single taps read as dead); **silent rejected
  commands** (F3: move-into-wall / diagonal / move-onto-corpse / attack-a-corpse all produce no cue — indistinguishable
  from a frozen game); a **class-less "Descend Again"** (F4: the most common post-death path skips hero select and
  starts the fail-open 60-HP driver default); a **death that is a hard cut** (F5: no death moment, no cause, no run
  summary, the shipped Epic-8 first-death line never renders); a **dead event-log/feedback layer** (F6/F7: "Log: 0
  events" through two runs, no damage numbers, no hit/miss, no animation); **corpses that look alive** (F8); a **fixed
  seed** (F11: identical board across three boots — every "new descent" is the same room); and **no route map** in the
  live flow (F12).
- **Band 2 — it does not look intentional.** A hero-select that is five gray text bars + empty void with zero
  selection feedback despite the approved portraits sitting in-repo (F13); an Outpost rendering literal `[#]`/`[!]`
  markers, four "(coming soon)" dead-text rows, and "not yet tallied" placeholder copy (F14); a board that does not
  scale to the window (F15); and a **debug HUD** (F9: raw `Confirm:false Cancel:false (mode none)`, snake_case cue ids,
  pipe-separated stat dumps) with **no affordances** (F10: no range highlights, no turn indicator, no end-turn button)
  and **no UI theme** (F16: default Godot Control styling everywhere, the generated Recraft frame kit unused).

Four already-ledgered items (`deferred-work.md` + Epic-13 retro §7–§8) overlap these bands exactly and fold in:
the **reward-overlay hardcoded geometry** (13.2 R1 defer), the **passive-confirm raw-id vs `display_name`** (13.2 R2
defer), the **full-backpack reward escape hatch** (13.2 R1 defer — a soft-lock class of issue), and the **run-summary
outcome label / F-2** (10-5 defer, origin 11.5 — the summary must key the outcome off `phase`, not the blank
`outcome_or_cause`).

What already works (credit, and why this is additive not a rebuild): board/tile/character art reads well, tap
hit-testing is pixel-accurate, inspect metadata is rich and correct, and the domain underneath behaves — turn engine,
enemy AI approach, LoS/darkness, HP model, and fail-closed command validation all function with no crashes. The gap is
almost entirely **presentation, feedback, and flow-navigation over a working domain** — with exactly two small,
carefully-scoped **domain** changes required (the F1 corpse/pass-turn fix and the full-backpack escape hatch), both of
which follow the pinned command/event/RNG/save contracts.

## 2. Impact Analysis

- **Epic impact.** Adds **one new epic — Epic 14 "Playable & Presentable"** — to the canonical epics list, executing
  after Epic 13 as the **second pre-ship backlog epic**. No existing epic is re-scoped or renumbered. Epic 14 is the
  re-sync that closes the playability + presentation gap the 2026-07-16 playtest found, the same way Epic 13 closed the
  render/input gap the 2026-07-13 playtest found.
- **Story impact.** 11 new stories (14.1–14.11) in two bands. No existing story changes. The stories are the
  human-facing / finishability delivery of already-shipped domain: FR1 loop completion, FR22/FR69 combat feedback,
  FR26/FR27 seeded/manual-seed runs, FR32/FR60–FR62 run-end + summary + narrative beats, and the FR68 UI flows (hero
  select, tactical HUD, tile/attack preview, passive modal, run map, outpost/meta menu, run summary).
- **Artifact conflicts.** **None structural.** The architecture already prescribes exactly this layering (domain owns
  truth; presentation observes domain and submits commands through the bridge; UI never mutates domain state) — Epic 14
  is additive presentation + two contract-compliant domain commands. **No GDD change** (the loop, feedback, seed, and
  summary requirements are already specified — FR1/FR22/FR26/FR27/FR60–FR62/FR68/FR69, NFR9). **No architecture change.**
  **No narrative change** (the first-death/first-victory lines are shipped DTOs — this epic renders them). **No FR
  coverage-map change** (primary FR-to-epic assignments are unchanged; Epic 14 completes the *human-facing* surface of
  FRs already assigned). Two **detail-level** `epics.md` AC observations the Epic-13 retro §10 already recorded (the
  12.1 AC over-claim, the 13.2 reward-policy under-spec) are historical and need no edit.
- **Technical impact.** Two contract-bounded **domain** additions (14.1 corpse-clearing + `WaitCommand`; 14.7 a reward
  decline/skip command) — each the ratified 4.3 run/tactical-command idiom (validate-before-mutate, `ActionResult`,
  append-only tail event, zero-RNG or named-stream-only, no new save key, 23-key gate held). One **flow-layer seed
  source** change (14.4). Everything else is presentation over pinned view-models/bridges. The **one** determinism
  consequence worth flagging is that **14.1's corpse-clearing may require a justified seed-regression re-pin** of the
  combat-replay composite fixtures — bounded and explicit (see §3.1 D1). Every other story holds all generator/route/
  finale/combat fingerprints byte-identical, the 7 named RNG streams, the 23-key `RunSnapshot` gate, the 16-key
  `TacticalBoardViewModel` gate, `SCHEMA_VERSION == 1`, `scripts/rules/{conditions,operations}` (empty / one file), and
  the no-new-autoload rule.

## 3. Recommended Approach

**Direct Adjustment** — add **Epic 14: Playable & Presentable** to `epics.md` (Epic List entry + full body with 11
stories) and register it in `sprint-status.yaml` as **`backlog`** (matching how Epic 13 was registered at creation;
file order = execution order; no renumbering). The epic is structured in two bands, ordered so the game becomes
**finishable before it becomes pretty**:

- **Band 1 — Finishable & Readable Loop (blockers first): stories 14.1–14.7.** The F1 soft-lock first (it is the only
  guaranteed-unfinishable defect), then the combat feedback/readability layer (F2/F3, F6/F7/F8), the seed variation
  (F11), the run-end moment + summary + descend routing (F5/F4/F-2), the live route map (F12), and the full-backpack
  escape hatch last (a soft-lock class of issue — argued into Band 1 below).
- **Band 2 — Looks Intentional (presentation): stories 14.8–14.11.** Hero-select rebuild (F13), Outpost cleanup (F14),
  the player HUD + range highlights + turn indicator (F9/F10), and the UI theme + semantic layout applied across
  screens (F15/F16, folding the two 13.2 overlay defers). The theme story is deliberately **last** so it themes the
  screens the earlier Band-2 stories rebuild.

**Effort:** 11 stories, standard auto-gds pipeline, each one PR the size of 13.1/13.2. **Risk:** low-to-moderate —
mostly additive presentation over pinned contracts; the two domain touches are small and contract-bounded; the single
elevated-risk item is 14.1's justified combat-fingerprint re-pin, which is explicitly scoped and re-verified.
**Timeline:** Band 1 (14.1–14.7) makes the observed-human-playtest pass (Epic-10 retro §7 OSG-1..4 / ASG-1/2 / AG-1,
UNBLOCKED but not yet meaningfully runnable — today a human hits the F1/F2 walls) genuinely worth running; Band 2 makes
it presentable enough that the human-felt OSG dimensions (fun, memorability, replay desire) can be honestly scored.

### 3.1 Design Decisions (deterministic + explicit; the human can veto any one at review)

These are the calls that shape the shipped experience. Each is the recommended default; the alternative is what a human
override would pick. Nothing here is started — this is the plan.

| # | Decision (story) | Recommended default | Alternative (human override) |
|---|---|---|---|
| **D1** | **Corpse handling on death (14.1)** — the F1 soft-lock core | On death, **remove the dead unit from board occupancy immediately** — the cell becomes **walkable and non-targetable**; the domain emits the existing death event; the **UI renders a persistent corpse/loot-marker decal** at the death cell as a pure presentation read (this also resolves F8's "corpses look alive"). Cleanest deterministic model (dead == off the board), maximally readable (you see where things died), and it cleanly separates domain (occupancy) from presentation (decal). | **Timed despawn** — keep the corpse decal blocking-free but auto-remove it N turns after death (needs a per-corpse turn counter; loses the "where things died" readability). |
| **D2** | **Turn-advance guarantee (14.1)** — the F1 soft-lock backstop | Add a **`WaitCommand`** (the 4.3 command idiom: validate-before-mutate, `ActionResult`, **append-only tail event**, **zero RNG**) so the player can always pass a turn even with no legal move/attack; the pass is a committed action and **advances enemies (FR3)**. Surface a visible **Wait / End-Turn affordance** in the HUD. Belt-and-suspenders with D1: D1 restores mobility, D2 guarantees turns advance when boxed in. | *(none — a pass-turn action is required for a turn-based game to be provably soft-lock-free; the only variable is the affordance's label/placement)* |
| **D3** | **"Descend Again" routing (14.5)** | Route the Outpost descend affordance **through the (rebuilt) hero-select stage** — the player picks a class, getting a real 18-HP kit; **never** the class-less driver default. The authoritative `RunStartCommand` class gate is unchanged. | **Carry the prior run's class** — a one-tap quick-descend that reuses the last class and skips hero select (faster loop; loses the class-switch moment). |
| **D4** | **Per-run seed source (14.4)** | At a **normal new-run start**, the flow caller (Descend / Descend Again) selects an **entropy-derived `root_seed`** (a one-time non-gameplay seed source, e.g. system time, chosen **before** any named stream exists — it is the seed *source*, not a gameplay draw, so it does not touch the named-RNG rule). The **manual-seed entry path (FR27) supplies an explicit seed and stays byte-deterministic**; `RunStartCommand` and generation are unchanged (a pure function of the given seed), so **every seed-regression test — which passes an explicit seed — stays byte-identical**. | *(none — variety is required; the only variable is the entropy source. Manual-seed determinism is non-negotiable.)* |
| **D5** | **Full-backpack escape hatch (14.7)** | Add a **decline/skip disposition** for a pending reward offer — a caller-driven run command in the 4.3 idiom that clears the offer **without applying it** (append-only tail event, zero RNG) — so a full-backpack generic reward can be dismissed and the run can advance. This is the **minimal soft-lock fix**; it **does not weaken** the fail-closed `inventory_full` domain guard (which stays correct). Placed in **Band 1** because it is a soft-lock (finishability), ordered **last** in the band because it is not reachable early (empty backpack; the opener/deeper tables yield gold ~⅓ of the time, which always resolves). | **Full drop/replace-choice UX** — the richer "drop an item to make room / replace" disposition the ledger names as the eventual owner (larger; defer the richer version and ship only the skip now). |
| **D6** | **Run-summary outcome label (14.5)** — folds ledger F-2 | Key the victory/death **outcome label off `run.phase`** (`PHASE_COMPLETED` / `PHASE_FAILED`) **+ the reveal beats** — **never** `outcome_or_cause` (which stays blank until the deferred run-level event store lands). The summary renders the facts it honestly has (outcome, nodes cleared, seed, oath-shards-earned); the **loot/passive lists stay honestly empty** until the run-level event store lands (re-recorded deferred, **not** Epic-14 scope). | *(none — the run-level event store is a separate save-shape story; pulling it into Epic 14 would over-scope 14.5)* |

**D1's seed-regression implication (the one flagged determinism consequence).** Corpse-clearing is a **combat-time
movement-legality** change, not a generation-time change. It therefore holds **all generator/route LAYOUT fingerprints
byte-identical** (terrain, route, arena — none touched). It **may move the COMBAT-REPLAY composite determinism pins**
(`test_reference_combat_driver.gd` winnability/byte-determinism, the auto-resolve `run_to_completion` fixtures, and —
less likely, single-entity arena — `test_finale_seed_regression.gd`) **iff** a pinned replay contains a move that a
corpse previously blocked (both hero and enemy AI gain mobility through vacated cells). Story 14.1 **must** (a) identify
exactly which pins move by running the same-seed re-derivation, (b) **re-verify the winnability proof still holds** for
every approved seed (more mobility can only help), and (c) **re-pin the moved fixtures in the SAME PR** via the
dump/regeneration path with the justification recorded — **never** a silent edit to make a drifting test pass. The
`WaitCommand` itself draws zero RNG and the hands-off/reference drivers never invoke Wait in the fixtures (they always
have a legal move/attack), so Wait moves no fingerprint. **14.1 is the only Epic-14 story that may intentionally
re-pin; every other story holds all fingerprints byte-identical.**

## 4. Detailed Change Proposals

### 4.1 The 11 stories (finding → story map; ordered, hard dependencies first)

**Band 1 — Finishable & Readable Loop (blockers first):**

| Story | Findings | One-line scope | Key FR / NFR | Determinism posture |
|---|---|---|---|---|
| **14.1 Corpse-Clearing and Wait/Pass-Turn** | F1 (+F8 corpse render) | Dead units leave board occupancy (D1) + `WaitCommand`/pass-turn (D2) + corpse decal + Wait affordance — the guaranteed soft-lock fix | FR1, FR2, FR3 | **DOMAIN.** Generation/route LAYOUT fingerprints byte-identical; **may re-pin combat-replay composite pins (justified, same PR)**; +1 append-only event; zero new RNG stream/draw; 23-key gate held |
| **14.2 Attack Preview + Rejected-Command Feedback** | F2, F3 | Visible **armed-preview** state (target + expected-damage panel, confirm/cancel) + **every** rejected command gets a **non-color cue** (message line/toast + optional cell shake) | FR9, FR10, FR11, **NFR9** | Presentation over the existing two-step commit + `CommandBridgeResult` reject reasons; no domain/VM/RNG change; fingerprints byte-identical |
| **14.3 Combat Event Log + Hit Feedback** | F6, F7 (+F8 death anim) | In-combat **event log + damage numbers** rendered from the already-emitted per-action domain events + **tween/flash** for move/hit/death | FR22, FR24, FR69 | Presentation reading existing `ActionResult`/`CommandBridgeResult` events; animation is **cosmetic** (cosmetic stream only if any RNG); no gameplay RNG; fingerprints byte-identical; does **not** build the deferred run-level event store |
| **14.4 Per-Run Seed Variation** | F11 | Entropy-derived `root_seed` at normal new-run start; manual-seed path preserved (D4) | FR26, FR27, FR29 | **Flow-layer seed source** only; `RunStartCommand`/generation unchanged; all seed-regression tests pass explicit seeds → byte-identical; no named-stream change |
| **14.5 Run-End Beat + Run-Summary Screen** | F5, F4 (+F-2) | Death/victory **beat render** (shipped `FirstDeathNarrativeBeat`/`FirstVictoryRevealBeat` DTOs) + **run-summary screen** (outcome off `phase`, D6) + descend→hero-select routing (D3) | FR32, FR60, FR61, FR62 | Presentation + flow-nav over the existing `RunSummary`/beat DTOs + `RunEndProfileBridge`; loot/passive lists honestly empty (deferred event store); no domain change |
| **14.6 Live Route Map + Node-Choice** | F12 | Render the Epic-4 route + the node-choice step live in the flow (the route-map stage exists in `RunFlowRouter` but never surfaces) | FR68 | Presentation over `RouteState`/`RouteMapViewModel` + the existing route-advance commands; reveal-on-arrival intact; no domain change; fingerprints byte-identical |
| **14.7 Full-Backpack Reward Escape Hatch** | ledger (13.2 full-backpack soft-lock) | Decline/skip reward disposition (D5) + a skip affordance on the generic reward overlay | FR52 | **DOMAIN** command (4.3 idiom); the fail-closed `inventory_full` guard is **unchanged**; +1 append-only event if needed; zero RNG; 23-key gate held |

**Band 2 — Looks Intentional (presentation):**

| Story | Findings | One-line scope | Key FR / NFR | Determinism posture |
|---|---|---|---|---|
| **14.8 Hero-Select Rebuild** | F13 | Rebuild hero select using the **existing approved portraits** (`godot/assets/characters/char.*.png`, already imported) + per-class kit summaries + **visible selection state** + a minimal title treatment | FR68 | Presentation scene over the existing pinned `HeroSelectViewModel`/`ClassStartSummaryViewModel`; no domain change |
| **14.9 Outpost Screen Cleanup** | F14 | No raw `[#]`/`[!]` markers, honest **deferred** rows (not dead "(coming soon)" text), **real tallies** incl. oath-shards-earned-this-run | FR68 | Presentation over the existing `OutpostViewModel`/`OutpostRenderView`; the pinned `RunSummary` contract is unchanged (earned count a separate deterministic `MetaAwardRules` read); no domain change |
| **14.10 Player HUD + Range Highlights** | F9, F10 | Replace the debug HUD with a styled **player HUD** (HP/gold/bag/turn; **display names, not snake_case ids**) + **move-range + attack-range highlights** + a turn indicator | FR68, FR12, **NFR9** | Presentation over `RunHudViewModel`/`TacticalBoardViewModel`; the 16-key board-VM gate held; range highlights read the existing move/attack-preview queries; no domain change |
| **14.11 UI Theme + Semantic Layout** | F15, F16 (+ reward-overlay geometry, passive-confirm `display_name`) | Import the **Recraft frame kit** SVGs + build & apply a **`Theme`** (StyleBoxes/fonts/spacing) + the semantic **`TacticalLayoutProfile`** region plan **across screens** — folds the two 13.2 overlay defers | FR68, **NFR9** | Presentation/theme; imports + commits the SVG sidecars (the 13.1 art-import discipline); ≥44px targets + honest `reachable:false`; no domain change |

### 4.2 `epics.md` changes

1. **Epic List:** add `### Epic 14: Playable & Presentable` after the Epic 13 entry (goal, FR note, implementation/
   sequencing note referencing this proposal).
2. **Body:** append `## Epic 14: Playable & Presentable` after the Epic 13 body (Stories 14.1–14.11 with full
   Given/When/Then ACs, band demarcation, and the D1 seed-regression note in-line on 14.1).

### 4.3 `sprint-status.yaml` changes

Append, after `epic-13-retrospective: done`, a **SPRINT CHANGE 2026-07-16** comment block referencing this proposal
plus: `epic-14: backlog`, the 11 story keys `14-1-…` through `14-11-…` all `backlog`, and
`epic-14-retrospective: optional` (matching the Epic-13-at-creation registration).

### 4.4 `deferred-work.md` fold-ins (recorded, not re-deferred)

Four open ledger items are **adopted into Epic 14** (owner reassigned from "a later pass" to a named story) — no edit
to `deferred-work.md` is required by this proposal (the items stay logged; the epic body + this proposal name the new
owners): the reward-overlay hardcoded geometry → **14.11**; the passive-confirm raw-id vs `display_name` → **14.11**;
the full-backpack reward escape hatch → **14.7**; the run-summary outcome label / F-2 → **14.5** (label-off-`phase`
only; the run-level event store that would populate the loot/passive lists remains a re-recorded deferred item **not**
in Epic-14 scope). The `_inspect_facts_from` untested-transform defer (13.2 R2) is **not** adopted — it is optional
test-hardening with no player-facing symptom; it stays on the ledger for a later board-polish pass.

## 5. Implementation Handoff

- **Scope: Moderate** (backlog addition, no replan). Handoff: the auto-gds pipeline picks up
  `14-1-corpse-clearing-and-wait-turn` as the next actionable story (`backlog → create-story`). File order = execution
  order; Band 1 lands before Band 2; within Band 1, 14.1 (the soft-lock) is first.
- **Standing constraints every story inherits** (from `project-context.md`, non-negotiable): the domain owns tactical
  truth and UI mirrors it (scenes own no state; UI never mutates domain — it submits commands through the bridge);
  commands validate-before-mutate and return `ActionResult` with zero partial state on reject; gameplay randomness uses
  the 7 named RNG streams (cosmetic-only randomness may use `cosmetic` and cannot affect outcomes); events are
  append-only at the enum tail, wired end-to-end; the 23-key `RunSnapshot` gate, the 16-key `TacticalBoardViewModel`
  gate, and `SCHEMA_VERSION == 1` hold; **difficulty is a hard non-goal** (no story adds a knob that scales enemy stats/
  HP/damage/rewards/RNG/run length); assertable logic lives in scene-free `RefCounted` seams (no SceneTree presenter
  tests — verify by construction + the compile guardrail); no new autoload; the headless suite stays green (195 PASS
  baseline; the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` stays clean beyond the 6 documented negatives);
  and **every generator/route/finale/combat seed-regression fingerprint stays byte-identical except the single
  justified 14.1 re-pin (D1), which is re-pinned via the dump tools in the same PR**.
- **Success criteria (the whole epic).** A human can launch the desktop build, pick a class on a hero-select screen
  that shows the portraits and kits, descend through a **route they can see and choose**, fight the opening combat with
  a **visible armed-preview / confirm-cancel** and **legible damage/hit feedback**, **never soft-lock** (corpses don't
  block; Wait always advances; a full backpack can be skipped), see a **death or victory moment + a run summary** with
  the shipped narrative line, return to a **clean Outpost with real tallies**, and **Descend Again into a different
  seed through hero select** — all on a **themed, styled** UI with a real player HUD, with the headless suite still 195+
  PASS and every pinned fingerprint byte-identical except 14.1's justified re-pin.
- **Success criteria (Band 1 gate).** After 14.1–14.7, the loop is provably **finishable and readable**: no reachable
  soft-lock, every rejected action has a non-color cue, combat outcomes are legible, runs vary by seed, and the run
  ends with a summary — enough that the Epic-10 retro §7 observed-human-playtest pass (OSG-1..4 / ASG-1/2 / AG-1) is
  meaningfully runnable (Epic 13 UNBLOCKED it; Band 1 makes it worth running).

**Routing.** Moderate scope → Product Owner / Developer (auto-gds orchestrator) for backlog pickup. No PM/Architect
replan is required: no PRD/architecture/GDD/FR-map artifact changes, and the epic is additive over the pinned
determinism/save/RNG base (fully intact at 195 PASS). The six design decisions (§3.1) are surfaced explicitly so the
Project Lead can veto any single call at review without re-opening the plan.
