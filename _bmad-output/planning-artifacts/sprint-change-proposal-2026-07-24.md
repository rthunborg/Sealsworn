# Sprint Change Proposal — 2026-07-24: Epic 15 "Playtest Response" + Epic 16 "Dungeon Generation, Scale & Awareness"

## 1. Issue Summary

Two change triggers, ratified together by Rasmus on 2026-07-24, are folded into one proposal because they share a
build target and a sequencing decision (Epic 15 first, Epic 16 after).

**Trigger A — the post-Epic-14 agent playtest.** An agent-driven desktop playtest of the built game (2026-07-20,
`main` @ `a78653c`, post-Epic-14; full record `playtest-sessions/agent-playtest-2026-07-20.md`; triage
`playtest-sessions/agent-playtest-2026-07-20-triage.md`) confirmed Epic 14 worked — **the loop is now completable
end-to-end for the first time** (one run won a combat node, consumed a passive at a real reward modal, chose a route
branch, passed an event node, and died in a depth-2 elite fight), and **all five 2026-07-16 Blockers are fixed or
substantially addressed**. But three runs (one per class) surfaced **20 new findings**, concentrated in one place: a
**layout-clip bug (F1/F2)** renders the entire HUD label column off-canvas at every window size and clips the event
log — hiding most of the UI Epic 14 shipped. Beneath it sit a band of **correctness bugs** (attack-preview damage
excludes bonuses, no quit/resume surface, seer marks have no telegraph, event nodes render nothing, the shard economy
pays 0, HP resets between nodes) and a **presentation gap** (hard cuts everywhere, no movement/idle animation, reward
modal text renders through its frame). This is the same class of trigger as the 2026-07-13 and 2026-07-16 playtests
that created Epics 13 and 14 respectively — a hands-on session exercised every reachable surface and recorded concrete
defects the readiness gate under-weights.

**Trigger B — a directed dungeon-scale vision.** Reviewing the playtest, Rasmus directed a scope expansion the current
build cannot express: boards are tiny and fixed (Small `8×8`, Medium `~14×12`), each a **single open interior room**
(border wall ring + scattered blocker walls + 1–2 wrinkles), with the whole interior reachable. The vision is
**Shattered-Pixel-Dungeon-sized floors** — larger grids, **multiple rooms + corridors + dead-ends**, cells that are
**not all reachable destinations** (structural filler), a **camera that defaults further out**, and **enemies that
aggro on their own sight** rather than all activating at once. This is a generation overhaul, not a tuning of the
existing generator, and it is the most architecture-sensitive change the project has taken on.

**What already works (credit; why both epics are additive, not a rebuild).** The tactical domain underneath is strong:
pathfound movement, line-of-fire blocking, hazard/darkness LoS, per-enemy AI approach, the risk/reward flow, seed
variety across runs, and the reward/passive modal all function with no crashes and a clean Godot log. The generation
kernel is deterministic and well-tested (fixed RNG draw order, per-seed fingerprint regression, a reference-combat
winnability catalog). Epic 15 is presentation/feedback/correctness over that working base; Epic 16 extends the working
generation kernel to a richer algorithm within its existing determinism discipline.

## 2. Impact Analysis

### 2.1 Epic 15 — Playtest Response

- **Epic impact.** Adds **Epic 15 "Playtest Response"** to the canonical epics list, executing after Epic 14 as the
  **third pre-ship playtest-response epic** (the Epic-13/14 pattern). No existing epic is re-scoped or renumbered.
- **Story impact.** 12 new stories (15.1–15.12) in three bands; no existing story changes. They are the human-facing
  delivery / correctness-hardening of already-shipped systems: FR68 UI flows (HUD, reward modal, hero-select copy),
  FR9/FR10 preview accuracy, FR22/FR69 combat feedback, FR1/FR28 quit-resume, FR32/FR60–FR62 run-end economy.
- **Artifact conflicts. None structural.** No GDD change (every fix serves an already-specified FR/NFR). No architecture
  change (additive presentation + small contract-compliant domain/correctness fixes over pinned view-models/bridges).
  No narrative change (15.9 renders the shipped Epic-8 first-death beat). Two findings map onto **existing backlog**
  rather than new work (F20 settings → AG-3 settings-scene owner; audio → AG-2, descoped) and are recorded as fold-ins,
  not re-deferrals.
- **Technical impact.** Mostly presentation over pinned contracts. The few **domain/correctness** touches are small and
  contract-bounded: 15-2 (preview damage computation — a read-model fix, no mutation), 15-4 (quit/resume flow reusing
  the Epic-2 `SaveManager.resume_route_position` seam), 15-5 (run-summary economy wiring — may add an append-only event
  for consumed/destroyed passives), 15-7 (mis-tap safety — a flow/interaction guard). **No generator/route/finale/combat
  fingerprint moves in Epic 15**; the 7 named RNG streams, the 23-key `RunSnapshot` gate, the 16-key
  `TacticalBoardViewModel` gate, and `SCHEMA_VERSION == 1` all hold. Four design decisions (D1–D4, §3.2) need
  resolution but none breaks a contract.

### 2.2 Epic 16 — Dungeon Generation, Scale & Awareness

- **Epic impact.** Adds **Epic 16 "Dungeon Generation, Scale & Awareness"**, executing **after Epic 15** (ratified fork
  3). This is a **capability epic**, not a fix epic — it extends "Procedural Level Generation v0" (Epic 3) toward a v1
  multi-room generator and adds an enemy-awareness layer.
- **Story impact.** 5 new stories (16.1–16.5). No existing story changes, but the generation stories **supersede the
  behavior** of the Epic-3 generators (open-interior → room/corridor) — an intentional evolution, re-pinned in-PR.
- **Artifact conflicts — this epic DOES touch design + architecture (honest scope signal).**
  - **GDD: Action-needed.** Board scale, the new Large size class, multi-room/corridor dungeon structure, and
    enemy sight-based aggro are **design-level** changes. The GDD's level-structure and enemy-behavior sections should
    be updated to reflect them (recommended as a pre-Epic-16 GDD touch — see handoff §5).
  - **Architecture: Action-needed.** The room-placement + corridor-carve algorithm, the new "unreachable cell" domain
    invariant (rippling into movement/path/fog/tap-router), and the aggro/activation state on enemies are architecture
    decisions that warrant a short design/architecture note before story-by-story dev (see handoff §5).
  - **UX: Action-needed.** The default camera zoom-out + grid-fit for large floors and readability at Large scale touch
    the UX layout appendix (§14 layout / §16 settings-adjacent).
  - **FR map:** Epic 16 extends the generation FRs (Epic 3) and likely adds an **enemy-awareness FR** (sight-based
    aggro) — a coverage-map touch, not a conflict.
- **Technical impact — the heaviest in the project so far.** (1) **Two deliberate fixture re-pins:** 16-1 (dimension
  change) and 16-2 (algorithm change), each independently verifiable via the dump/regeneration tools, justification
  recorded in-PR — never a silent edit to pass a drifting test. (2) **The reference-combat winnability catalog must be
  re-proven** with fresh seeds for the new geometry at each size class (a genuine balance assertion: an unwinnable
  seed FAILS LOUD). (3) **Unreachable cells** are a new domain invariant — a structurally unreachable cell is never a
  move target, never a spawn, never a reward site. (4) **Mobile performance is the hard gate** on the Large `~26×28`
  class (the `device-tiers-and-performance-budgets.md` budget). The determinism discipline itself is **unchanged** —
  every layout-affecting draw still routes through `STREAM_LEVEL` in a fixed order; the generator gains rooms, not RNG
  sources.

## 3. Recommended Approach

**Direct Adjustment (two additive epics, sequenced).** Add **Epic 15** and **Epic 16** to `epics.md` and register both
in `sprint-status.yaml` as `backlog` (file order = execution order; no renumbering). Epic 15 ships first so the game
becomes **readable and correct** (and human playtests become worth running); Epic 16 follows as the **dungeon-scale
capability** once the loop is solid and movement is already animated.

**Why not fold into one epic (fork 3, ratified):** coupling the urgent readability fix (15-1, ~2 presenter files) to
the slow, re-pin-heavy generation overhaul would delay the thing that unblocks human playtests. Separate epics let
Epic 15 ship fast and isolate Epic 16's architecture risk.

### 3.1 Epic 15 bands (finishable/readable before pretty)

- **Band 1 — Readability hotfix (15-1):** the HUD/log layout clip. Lands **first and alone**; it un-hides most of what
  Epic 14 shipped and is the single highest-leverage fix.
- **Band 2 — Correctness & unwired surfaces (15-2…15-7):** preview damage, threat telegraphs, quit/resume, event-node &
  run-summary wiring, reward-modal fix, mis-tap safety.
- **Band 3 — Presentation/feel (15-8…15-12):** combat feel **incl. movement animation** (the "units teleport" fix
  lives here), scene transitions & death moment, theme/layout polish, player-facing copy, weapon/kit display.

### 3.2 Epic 15 Design Decisions — RATIFIED by Rasmus 2026-07-24

All four resolved. Recorded here as the decision of record; each is carried in-line on its owning story in
`epics.md`.

| # | Decision (story) | **RATIFIED ANSWER** | Consequence |
|---|---|---|---|
| **D1** | **HP persistence across nodes (15-5)** | **HP PERSISTS — no refill when advancing between nodes.** Backed by the GDD: "resource attrition" is a named MVP difficulty source (gdd.md:402), "Healing: scarce, valuable, and sometimes competing with greed" (gdd.md:450), and "lose max HP" is a risk-currency example (gdd.md:466) — none of which hold under an implicit full heal. | **F-Q1 confirmed as a real bug.** HP restored only by defined sources; persisted HP must survive quit/resume (15-4). |
| **D2** | **Mis-tap safety (15-7)** | **Move-confirm step (option a), extended.** The tapped cell renders a highlighted **check-mark**; pressing that check-mark again commits. **The same pattern applies to attacking a creature**, so move and attack share one commit vocabulary. **A settings toggle lets the player turn the confirm step off.** | **New dependency:** the toggle needs a settings surface, which is the **parked AG-3 settings-scene** item. 15-7 delivers the minimal surface to host it (coordinating with AG-3, not duplicating it) + an additive `SettingsSnapshot` preference key. |
| **D3** | **Reward pool class-relevance (15-6)** | **POSITIVE weights only.** Class-relevant passives/loot get a raised weight so relevant offers are more likely. **No negative weights and no exclusions** — a "bad" cross-class offer (Hunter's Quiver to a Pyromancer) stays possible, just less frequent. | Preserves cross-class build variety while cutting dead-weight frequency. Test must assert **both** that relevance raises frequency **and** that no entry becomes unreachable. |
| **D4** | **Shard income on death (15-5)** | **Meta currency and unlocks ARE awarded on death.** | **Reverses a shipped Story-8.3 design decision.** `MetaAwardRules.oath_shard_award_for()` currently returns 0 for `PHASE_FAILED` by explicit recorded decision; the award formula (`min(1 + 1×nodes_cleared, 5)`) otherwise already exists and works. The rule **and its existing tests** (`test_award_meta_progress_command.gd`, `test_meta_summary_save_load.gd`) change together. Also better matches the GDD, which says shards are awarded "after **run end**" (gdd.md:452) — not after victory. |

> **Playtest-report correction (recorded 2026-07-24).** Finding **F10's "shard economy pays 0 always"** was a
> **mis-report**, not a defect: all three playtest runs ended in death, and death-awards-nothing was correct,
> designed behavior at the time. The economy was wired and working. D4 now *changes that design* deliberately.
> The genuinely unwired parts of F10 — "Notable loot: — none —" and "Passives spent/destroyed: — none recorded
> yet —" — remain the known deferred **run-level event store** (ledger F-2), not new defects.

### 3.3 Epic 16 Ratified Forks + Internal Design Calls

**Ratified by Rasmus (2026-07-24):**
- **F-1 Combat model.** Keep the core loop + route/node model — a node is still **one fight you clear**. Boards become
  **multi-room dungeons** (rooms + corridors + dead-ends + unreachable filler). Enemies **aggro independently on their
  own sight/range** (dormant until they see/sense the hero), not all at once.
- **F-2 Scale.** Small `8×8 → ~12×12`, Medium `~14×12 → ~18×16`, add a new **Large `~26×28`** size class. Default
  camera zoom further out + grid-fit. A mobile device-tier perf pass gates the biggest boards.
- **F-3 Packaging.** Separate Epic 16, run after Epic 15.

**Internal design calls (recommended defaults; refine in the Epic-16 architecture note):**
- **Two-phase re-pin (16-1 then 16-2).** Do the dimension bump first with the current open-interior algorithm (one
  clean fixture re-pin), then replace the algorithm (second clean re-pin). Two small verifiable re-pins beat one
  entangled one under the strict determinism regime.
- **Reachability invariants (16-2).** The reachable set is fully connected; entrance↔exit reachable; every enemy/reward
  on a reachable cell; a minimum-combat-space guarantee so no node is unwinnable by cramped geometry. Unreachable
  filler cells are never move targets/spawns/reward sites.
- **Aggro model (16-3).** Enemies start dormant; activate on line-of-sight within a per-enemy sight range (reuse the
  existing `tactical_visibility_query` / darkness layer); dormant enemies take no turn; activated enemies use current
  AI. AI-decision explanation tests required (the AGENTS.md rule).

## 4. Detailed Change Proposals

### 4.1 Epic 15 — the 12 stories (finding → story map)

**Band 1 — Readability hotfix:**

| Story | Findings | One-line scope | Determinism posture |
|---|---|---|---|
| **15-1 HUD & Log Layout Clip Fix** | F1, F2 | The label column renders off-canvas at every size; the log clips its overflow. One `tactical_board_presenter` layout root cause. Land first + alone. | Presentation only; fingerprints byte-identical |

**Band 2 — Correctness & unwired surfaces:**

| Story | Findings | One-line scope | Determinism posture |
|---|---|---|---|
| **15-2 Attack-Preview Damage Correctness** | F4 | Fold support-item + consumed-passive bonuses into the preview so shown N == resolved N (range-conditional note for steady-aim). | Read-model fix; no mutation/RNG; fingerprints byte-identical |
| **15-3 Threat Telegraphs** | F5 | Persistent marked-tile overlay (glyph + NFR9 non-color channel) from mark→detonation; verify the detonation-flash cell anchor. | Presentation over existing telegraph events; no domain change |
| **15-4 Quit / Pause / Resume** | F3 | Boot "Continue" + in-game pause/quit, reusing the Epic-2 `SaveManager.resume_route_position` seam. | Flow over the existing save seam; no new save key |
| **15-5 Event-Node & Run-Summary Wiring** | F9, F10, F-Q1 | Event nodes render an outcome; wire shard income (D4) + loot + consumed/destroyed-passive recording; resolve HP persistence (D1). | May add +1 append-only event; zero RNG; 23-key gate held |
| **15-6 Reward-Modal Fix** | F13 | Frame becomes the actual container; label the confirm buttons; class-relevance the pool (D3). | Presentation over `RewardHudViewModel`; no domain change |
| **15-7 Mis-Tap Safety** | F14 | Move-confirm step or pre-enemy undo (D2) so a single stray tap can't burn a turn. | Interaction/flow guard; no fingerprint change |

**Band 3 — Presentation / feel:**

| Story | Findings | One-line scope | Determinism posture |
|---|---|---|---|
| **15-8 Combat Feel & Movement Animation** | F7, F8, F16 | Wait-ack + sequence/animate the enemy phase + **tween movement so units don't teleport** + fade deaths + count HP. Movement animation is delivered here. | Cosmetic presentation over existing events; cosmetic-stream-only RNG if any; fingerprints byte-identical |
| **15-9 Transitions & Death Moment** | F15 | Fades/slides at scene seams + stage the death beat (renders the shipped Epic-8 `FirstDeathNarrativeBeat`). | Presentation; no domain change |
| **15-10 Theme & Layout Polish** | F17, F19, F11 | Collapse empty gray slabs; un-clip hero-select names / scale portraits; disambiguate hazard-vs-corpse art. | Presentation/theme; no domain change |
| **15-11 Player-Facing Copy Pass** | F6, F18 | Kill `enemy_3`/`iron_cultist_melee`/`hero_waited` leaks + the `[!]`/`◆`/"Coming later" markers; speak in names/directions. | Presentation strings; no domain change |
| **15-12 Weapon / Kit Display** | F12 | Persistent weapon reach/damage line in the HUD + on hero-select rows. May ride 15-10. | Presentation over the pinned VMs; no domain change |

**Pulled out of Epic 15 (map to existing backlog / ledger):** F20 settings/accessibility → the **AG-3 settings-scene
owner**; F20 placeholder app icon → an **asset-pipeline / `deferred-work.md`** item; audio absence → **AG-2**
(descoped). No `deferred-work.md` edit required — the items stay logged with owners named here.

### 4.2 Epic 16 — the 5 stories

| Story | Scope | Risk |
|---|---|---|
| **16-1 Board Scale-Up + Large Class** | Bump Small→~12, Medium→~18, add validated Large ~26×28 to `GenerationRequest` + `LevelRecipeDefinition` + the size-class validator; keep the open-interior algorithm (just bigger) for one clean dimension re-pin; re-prove winnability at new sizes. | Medium — one clean fixture re-pin |
| **16-2 Room / Corridor / Dead-End Generation** | Replace open-interior gen with room-placement + corridor-carve (multiple rooms, corridors, dead-ends, unreachable filler); new reachability/connectivity/min-combat-space validators; ripple the unreachable-cell invariant through movement/path/fog/tap-router; second clean fixture re-pin + fresh winnability seeds. | **High** — the heavy story |
| **16-3 Enemy Aggro / Sight-Based Activation** | Enemies dormant until they see/sense the hero (LoS + sight range via the existing visibility layer); dormant enemies don't act; AI-decision explanation tests. | Medium — combat-AI + turn-resolver change |
| **16-4 Camera Default Zoom-Out + Grid-Fit** | Lower default zoom / grid-fit so a Large floor reads at a glance on mobile, with pan/zoom to inspect. Depends on 15-8 movement tween (Epic 15 ships first). | Low — presentation seam |
| **16-5 Mobile Performance Pass at Large Scale** | Verify the biggest boards render within the device-tier budget; tile batching/culling if needed. Gates the Large class. | Medium — the perf gate |

**Sequencing:** 16-1 → 16-2 → 16-3, with 16-4 after 16-1 and 16-5 as the closing gate.

### 4.3 `epics.md` changes

1. **Epic List:** add `### Epic 15: Playtest Response` and `### Epic 16: Dungeon Generation, Scale & Awareness` after
   the `### Epic 14: Playable & Presentable` entry (each with goal, FR note, and a sequencing note referencing this
   proposal).
2. **Body:** append `## Epic 15: Playtest Response` (Stories 15.1–15.12) and `## Epic 16: Dungeon Generation, Scale &
   Awareness` (Stories 16.1–16.5) after the Epic 14 body, each with full Given/When/Then ACs, band/sequence demarcation,
   the D1–D4 decisions in-line on the owning Epic-15 stories, and the two-phase re-pin + reachability + aggro notes
   in-line on the Epic-16 stories.

### 4.4 `sprint-status.yaml` changes

Append, after `epic-14-retrospective: done`, a **SPRINT CHANGE 2026-07-24** comment block referencing this proposal
plus: `epic-15: backlog`, story keys `15-1-…` through `15-12-…` all `backlog`, `epic-15-retrospective: optional`; then
`epic-16: backlog`, story keys `16-1-…` through `16-5-…` all `backlog`, `epic-16-retrospective: optional` (matching the
Epic-13/14-at-creation registration). Proposed keys:

```
15-1-hud-and-log-layout-clip-fix · 15-2-attack-preview-damage-correctness · 15-3-threat-telegraphs
15-4-quit-pause-resume · 15-5-event-node-and-run-summary-wiring · 15-6-reward-modal-fix
15-7-mis-tap-safety · 15-8-combat-feel-and-movement-animation · 15-9-transitions-and-death-moment
15-10-theme-and-layout-polish · 15-11-player-facing-copy-pass · 15-12-weapon-kit-display
16-1-board-scale-up-and-large-class · 16-2-room-corridor-generation · 16-3-enemy-aggro-sight-activation
16-4-camera-default-zoom-and-grid-fit · 16-5-mobile-performance-pass
```

## 5. Implementation Handoff

- **Epic 15 — Scope: Moderate** (backlog addition, additive over pinned contracts). Handoff: the auto-gds pipeline
  picks up `15-1-hud-and-log-layout-clip-fix` next (`backlog → create-story`). File order = execution order; Band 1
  before Band 2 before Band 3. Resolve D1–D4 at story-creation (or Rasmus picks now).
- **Epic 16 — Scope: Moderate-to-Major** (generation/architecture change + GDD/UX touch + two fixture re-pins +
  winnability re-prove). **Recommended pre-story handoff:** a short **GDD update** (level structure, Large size class,
  enemy sight-aggro) and a **generation/architecture design note** (room/corridor algorithm, unreachable-cell
  invariant, aggro state) BEFORE 16-1 goes to auto-gds — so the heaviest story (16-2) implements against a ratified
  design, not an improvised one. This is the one place a PM/Architect (Game Designer / Game Architect) pass adds value
  before dev.
- **Standing constraints every story inherits** (from `project-context.md`, non-negotiable): domain owns tactical
  truth, UI mirrors it (scenes own no state; UI submits commands through the bridge); commands validate-before-mutate
  and return `ActionResult` with zero partial state on reject; gameplay randomness uses the 7 named RNG streams
  (cosmetic-only randomness may use `cosmetic` and cannot affect outcomes); events are append-only at the enum tail;
  the 23-key `RunSnapshot` gate, the 16-key `TacticalBoardViewModel` gate, and `SCHEMA_VERSION == 1` hold; **difficulty
  is a hard non-goal** (no story adds a knob that scales enemy stats/HP/damage/rewards/RNG/run length); assertable logic
  lives in scene-free `RefCounted` seams; no new autoload; the headless suite stays green (205 PASS baseline; the
  false-PASS grep guard stays clean beyond the 6 documented negatives). **Epic 15 moves NO fingerprint. Epic 16 re-pins
  generation/combat fingerprints ONLY in 16-1 (dims) and 16-2 (algorithm), each justified + re-pinned in the same PR
  via the dump tools, with winnability re-proven.**
- **Success criteria (Epic 15).** A human launches the desktop build and can **read the whole HUD** at any window size;
  the attack preview number matches the damage dealt; **quit and resume** restores the run; threat marks are **visible
  before they detonate**; event nodes and the run summary **show real outcomes and shard income**; movement, deaths,
  and transitions **animate** rather than teleport/hard-cut; and no internal ids or marker syntax leak to the player —
  with the suite still 205+ PASS and every pinned fingerprint byte-identical.
- **Success criteria (Epic 16).** Floors are **large multi-room dungeons** (rooms, corridors, dead-ends, unreachable
  filler) across Small/Medium/**Large**, readable at a **default zoomed-out** camera; **enemies wake on their own
  sight** rather than dogpiling; the core loop + route/node model are **unchanged**; the biggest boards render **within
  the mobile device-tier budget**; and **winnability is re-proven for every class at every size** with the fixture
  re-pins justified in-PR.

**Routing.** Epic 15 → Product Owner / Developer (auto-gds orchestrator) for backlog pickup; no PM/Architect replan.
Epic 16 → a brief **Game Designer / Game Architect** design pass (GDD + generation-architecture note) first, then the
auto-gds orchestrator per story. The four Epic-15 decisions (§3.2) and the Epic-16 internal calls (§3.3) are surfaced
explicitly so Rasmus can veto or refine any single call at review without re-opening the plan.

---

**Git posture:** this proposal is written as a review artifact only. Per Rasmus's instruction, `epics.md` and
`sprint-status.yaml` are **NOT yet edited** and nothing is committed — those mutations (checklist 6.4) are held for
explicit approval, then applied by `gds-sprint-planning` / the next session before auto-gds picks up 15-1.
