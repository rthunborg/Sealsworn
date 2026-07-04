# Sprint Change Proposal — Epic 11 Insertion (Live Run Flow, HUD, and Outpost)

- **Date:** 2026-07-04
- **Project:** Sealsworn
- **Prepared by:** Correct-Course workflow (Developer role), for Rasmus
- **Mode:** Batch (autonomous run; all edit proposals presented together for one review)
- **Status:** DRAFT — awaiting explicit approval before any artifact is modified
- **Trigger artifact:** `_bmad-output/implementation-artifacts/epic-9-retro-2026-07-04.md` (§7 "Preparation / risks", §10 "Significant Discovery / Epic-Update Recommendation")

---

## 1. Issue Summary

### Problem statement

Epic 10 ("Playtest Tuning and MVP Readiness") validates a hands-off-playable MVP loop, but the project plan never allocates a story or epic to build the live layer that makes the loop playable. Every piece of that layer was **deliberately and correctly deferred** during Epics 7–9 (each deferral recorded, several explicitly human-accepted), always to "a later run-flow/HUD story" — and that story does not exist in the plan. Epic 10's 10-4 (at least five observed play sessions to death/victory), 10-5 (accessibility audit across outpost/run-summary/HUD screens), 10-6 (the "launch → start run → choose class → generate/enter levels → fight → collect rewards → make passive choices → die or win → view summary → start another descent" loop gate), and 10-7 (UX/asset readiness gate) all depend on it.

### What is actually missing (the deferred body, per the Epic 9 retro and the deferred-work ledger)

1. **Live combat in the run flow.** Run combat nodes currently auto-resolve to success; the live tactical loop exists (Epic 1/2 slice, Epic 9 boss encounter) but is not what resolves nodes in a real run.
2. **The live hero-death source (FR32's loss half).** A combat loop detecting the hero at 0 HP and auto-firing `CompleteRunCommand` → `PHASE_FAILED` does not exist; the death path is proven only with driven/test-supplied resolution.
3. **Boss auto-play + victory call site.** `detect_boss_defeat`, `RecordFirstVictoryCommand`, and `RunOrchestrator.resolve_boss_victory()` are invoked only from tests; `run_to_completion` stops at boss setup.
4. **The outpost SCENE.** Only `OutpostViewModel` (data contract) exists — no `.tscn`, no `SceneManager` transition, no `RunEndOutcome.next_destination` navigation, no start-another-descent button wiring.
5. **The reveal renders.** First-death ("Good. You remembered how to die.") and first-victory ("It did not die. It learned the way back.") exist as DTOs/flags/events; nothing renders them, with skip/dismiss, on any screen.
6. **Meta-SPEND / meta-power APPLICATION.** Profile state (Oath Shards, Echoes, Seal Fragments, unlock progress) round-trips, but nothing spends it or applies it (profile → class selectability).
7. **Live affinity call sites + HUD/VFX.** Epic 7's affinity effects (Darkness, Scorched DoT, Cursed rule-source, Flooded placeholder) have no live call site and no HUD/VFX treatment in play.
8. **The lightweight UX appendix.** Required by the epics.md readiness patch note (and gated by 10.7 AC5) before UI-heavy scene work — not yet written, and the outpost/HUD work is exactly that scene work.

### Evidence

- Epic 9 retro §7 risk 1: "The run-flow/HUD + outpost-scene story is an effective PREREQUISITE for the meaningful parts of Epic 10 (10-4 playtest, 10-6 loop gate) and is not itself in the Epic-10 story list."
- Epic 9 retro §10: "**Recommend a re-sync: add or sequence the run-flow/HUD + outpost-scene story ahead of Epic 10's playtest/loop-gate stories.**"
- `deferred-work.md` re-carried entries from 9-5, 9-4, 9-1, 8-7, 8-6, 8-5 all pointing at "a later run-flow/HUD story" / "a later HUD/boot-flow story" that has no home.
- Scene inventory: `godot/scenes/` contains only `boot.tscn`, `main.tscn`, `gameplay_shell.tscn`, `tactical_board.tscn` — no outpost, hero-select, or route-map scene.
- `project-context.md` (refreshed after Epic 9): "no live boot-flow wiring exists yet"; boss victory resolution "still NOT auto-wired into `run_to_completion`".

### Issue category

Planning omission / sequencing gap (not a technical failure, not a requirement change). Every deferral was individually correct; collectively they were never given a scheduled landing zone.

### Two detail-level drifts bundled into this change (annotation only)

- **FR63 numbering collision:** canonical `epics.md` FR63 = the Larval Avatar boss (Epic 9); the design-time GDD's FR63 = named outpost/meta spaces (→ Story 8.6, already in the 2026-06-04 traceability map). Future citations can mis-scope without an annotation at the FR definition.
- **FR32 loss half is driven-only:** the requirement reads as if hero death is a live trigger; as-built it is a proven path with no live source. The coverage map should say where the live trigger lands.

---

## 2. Impact Analysis

### Epic impact

| Epic | Impact |
|---|---|
| Epics 1–9 | None. All done; no rework, no rollback. Epic 9's deliverables are complete and stable per its retro. |
| **Epic 10** | Scope and ACs unchanged. Gains explicit prerequisite annotations: 10-4, 10-5, 10-6, 10-7 depend on the new Epic 11; 10-1, 10-2, 10-3 are independent of it. Without the change, 10-4/10-6 could only pass by documenting a large "cannot-yet-observe" readiness limitation — hollowing out the epic's purpose. |
| **NEW Epic 11** | Added: "Live Run Flow, HUD, and Outpost" — 6 stories consolidating the entire deferred body. Executes **between Epic 9 and Epic 10's 10-4..10-7** despite its number (numbering rationale below). |

### Story impact

- No existing story's content changes. New stories 11-1 … 11-6 are added (drafted in §4).
- Epic 11 absorbs, at their natural homes, these carried retro action items: Epic-9 T1 (the whole body), T2 (live death call site → 11-2), T3 (forcing tests for newly reachable branches → 11-2), T4 / Epic-8 T5 (summary↔profile "Oath Shards earned" coupling → 11-5), Epic-8 T4 (`OutpostViewModel` write-failure recovery combination test → 11-5). Epic-9 D3 (human-felt play pass) stays AFTER Epic 11, feeding 10-4.

### Artifact conflicts

| Artifact | Conflict? | Action |
|---|---|---|
| GDD / design intent | None. FR1 and FR68 always required the playable loop; MVP scope is unchanged. | No GDD edit. |
| `epics.md` (canonical) | Missing epic; two FR annotations warranted. | Edits in §4 (Epic List entry, new Epic 11 section, Epic 10 prerequisite notes, FR32/FR63 annotations, dated traceability note). |
| Architecture (`game-architecture.md`) | None — Epic 11 implements the already-designed presentation layer (view models → scenes, command bridge, `SceneManager`, UI-scene-last). | No edit. |
| UX specifications | Gap becomes blocking: the lightweight UX appendix required before UI-heavy scene work does not exist. | Story 11-1 delivers it (also satisfies 10.7 AC5). |
| `sprint-status.yaml` | Missing epic block. | Edit in §4 (post-approval, per checklist 6.4). |
| `deferred-work.md` | No edit now. Entries stay; Epic 11 stories resolve them on the normal per-story cadence. | None. |
| Tests / CI | No code change in this proposal. Headless suite (166 PASS) untouched. | None. |

### Technical impact

Planning-artifact edits only. No production code, no test, no save-schema, no RNG, no content change. All hard architecture rules (domain-first, snapshot purity, determinism, autoload discipline) are constraints ON the new epic, recorded in its implementation notes.

---

## 3. Recommended Approach

**Selected: Option 1 — Direct Adjustment** (add a new epic + annotations within the existing plan).

| Option | Verdict | Effort | Risk | Notes |
|---|---|---|---|---|
| 1. Direct Adjustment — insert Epic 11, annotate Epic 10 | **SELECTED** | Low (planning edits; the epic itself is already-known work) | Low | Matches the retro's own recommendation; keeps Epic 10 a pure validation epic. |
| 2. Rollback | Not viable | — | — | Nothing to revert; the deferrals were deliberate, human-accepted, and the deferred work is additive. |
| 3. MVP scope review | Not needed | — | — | MVP is achievable as defined; alternative of letting 10-4/10-6 document "cannot-yet-observe" limitations was considered and rejected — it would produce an MVP readiness verdict that never observed a playable loop. |

### Numbering decision: new epic is **Epic 11, executed before Epic 10's 10-4..10-7** (not a renumber)

Renumbering (inserting a new "Epic 10" and shifting the current one to 11) was considered and **rejected**: live forward pointers to "Epic 10" / "10-4" / "10-6" / "10-7" exist throughout `deferred-work.md` (e.g. D1 "consumable-frequency tuning pass (Epic 10, 10-4)", D2 "Epic-10 readiness gate (10-7)"), five epic retrospectives, the implementation-readiness report, and `sprint-status.yaml`. A renumber would silently mis-point every one of them or force edits to historical artifacts. Keeping the existing numbers stable and adding Epic 11 with an explicit execution-order note (in both `epics.md` and `sprint-status.yaml`) is the lower-risk adjustment. Precedent: sprint-status file order already drives next-story selection; the epic-11 block is inserted **before** the epic-10 block with a comment.

### Execution order after this change

Epic 9 (done) → **Epic 11 (all six stories)** → Epic 10 (10-1 … 10-7 in order). 10-1/10-2/10-3 do not strictly depend on Epic 11, but running Epic 11 first keeps the one-epic-at-a-time auto-gds cadence simple; the orchestrator may interleave 10-1..10-3 earlier if ever useful.

### Effort / timeline impact

- Planning change: trivial (this proposal + ~6 edits).
- Delivery impact: Epic 11 is net-new implementation work before Epic 10 can meaningfully start its playtest/gate stories — roughly one epic of effort (6 stories, comparable to Epic 8/9 size). This is not added scope; it is scope that was always implied (FR1, FR68) finally being scheduled.

---

## 4. Detailed Change Proposals

All edits below are **proposed**; none are applied until approval. OLD text is quoted verbatim from the current artifacts.

### 4.1 `epics.md` — Epic List: add Epic 11 entry (after the Epic 10 entry, line ~483)

**NEW (appended to the Epic List):**

```markdown
### Epic 11: Live Run Flow, HUD, and Outpost

Players can play the full descent hands-on — launch, choose a class, fight generated levels and the Larval Avatar on the live tactical board, win or die for real, see the reveal lines and run summary, spend meta progress at the outpost, and start another descent.

**FRs covered:** live/on-screen delivery of FR1, FR31, FR32 (live loss trigger), FR54-FR58 (felt affinity/risk pressure), FR59 (meta spend/application), FR60, FR61, FR62 (summary and reveal renders), FR64, FR65, and the FR68 flow expansion (run map, outpost/meta menu, run summary). Domain logic for these shipped in Epics 1-9; this epic wires live call sites, scenes, and HUD. Primary FR-to-epic assignments in the FR Coverage Map are unchanged.

**Implementation notes:** Added 2026-07-04 via sprint change proposal (see `sprint-change-proposal-2026-07-04.md`) to consolidate the deliberately deferred live layer from Epics 7-9. **Sequencing: executes between Epic 9 and Epic 10's Stories 10.4-10.7** (10.1-10.3 are independent). UI observes view models through the command bridge and owns no tactical truth; scenes live under `godot/scenes/ui/` and `godot/scenes/game/`. The live wiring must preserve interrupted==uninterrupted determinism, the 23-key `RunSnapshot` gate, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams, and every pinned fingerprint. Consumes (does not rebuild): the Epic-2 tactical presentation contracts, 7.4/7.5 affinity effects, 8.5/9.4 narrative beat DTOs, 8.6 `OutpostViewModel`, 9.3 `BossTurnResolver` live loop, 9.5 `resolve_boss_victory()`.
```

### 4.2 `epics.md` — Epic 10 section intro: add sequencing note

**OLD (lines 2337–2339):**

```markdown
## Epic 10: Playtest Tuning and MVP Readiness

Players receive a stable MVP experience validated against performance, readability, save/resume reliability, generator safety, run length, comprehension, and replay-intent signals.
```

**NEW:**

```markdown
## Epic 10: Playtest Tuning and MVP Readiness

Players receive a stable MVP experience validated against performance, readability, save/resume reliability, generator safety, run length, comprehension, and replay-intent signals.

> **Sequencing note (2026-07-04, sprint change):** Stories 10.4, 10.5, 10.6, and 10.7 require **Epic 11 (Live Run Flow, HUD, and Outpost)** to land first — their playtest sessions, screen audits, loop gate, and UX gate assume a hands-off-playable loop that Epic 11 wires. Stories 10.1-10.3 are independent of Epic 11.
```

### 4.3 `epics.md` — prerequisite line under each dependent Epic 10 story header

Add directly under the story title lines of 10.4, 10.5, 10.6, 10.7 (so the note flows into their future story files):

- Story 10.4: `**Prerequisite (2026-07-04):** Epic 11 — observed sessions require the live playable loop (fight, die or win, reveal, outpost, another descent).`
- Story 10.5: `**Prerequisite (2026-07-04):** Epic 11 — the audited surfaces (tactical HUD in-run, route map, outpost, run summary, reveal beats) must exist as screens first.`
- Story 10.6: `**Prerequisite (2026-07-04):** Epic 11 — the loop gate's steps (fight, die or win, view summary, start another descent) must be live, not driven/test-resolved.`
- Story 10.7: `**Prerequisite (2026-07-04):** Epic 11 — the UX appendix (Story 11.1) and the screen surfaces (11.3/11.5) are inputs to this gate.`

### 4.4 `epics.md` — FR annotations (detail drift)

**FR63 inventory line — OLD (line 148):**

```markdown
FR63: The Larval Avatar must be implemented as the only required MVP boss.
```

**NEW:**

```markdown
FR63: The Larval Avatar must be implemented as the only required MVP boss. (Numbering note, 2026-07-04: this is the canonical implementation FR63. The design-time GDD separately uses "FR63" for named outpost/meta spaces, which traces to Story 8.6 — see the 2026-06-04 traceability map. Cite the canonical numbering.)
```

**FR32 coverage-map line — OLD (line 307):**

```markdown
FR32: Epic 8 - Death returning to the outpost belongs to the roguelite return loop.
```

**NEW:**

```markdown
FR32: Epic 8 - Death returning to the outpost belongs to the roguelite return loop. (As-built note, 2026-07-04: Epic 8/9 prove the death RESOLUTION path with driven deaths; the LIVE hero-death trigger — combat loop detecting hero 0 HP — lands in Epic 11, Story 11.2.)
```

### 4.5 `epics.md` — dated traceability note (after the 2026-06-04 traceability section, line ~402)

**NEW:**

```markdown
### 2026-07-04 Sprint Change Traceability (Epic 11 insertion)

Per `sprint-change-proposal-2026-07-04.md` (trigger: `epic-9-retro-2026-07-04.md` §10): Epic 11 (Live Run Flow, HUD, and Outpost) added and sequenced between Epic 9 and Epic 10's Stories 10.4-10.7. It consolidates the deferred live layer recorded across Epics 7-9: live run combat + hero-death source (FR32 loss half) -> Story 11.2; run-flow scenes/HUD -> Story 11.3; live affinity call sites + HUD/VFX -> Story 11.4; outpost scene + reveal renders (FR61/FR62) + summary coupling -> Story 11.5; meta spend/application (FR59) -> Story 11.6; the pre-scene-work UX appendix (also 10.7 AC5's input) -> Story 11.1. Epic numbering of existing epics is unchanged by design (live cross-references preserved).
```

### 4.6 `epics.md` — new Epic 11 section (appended after Story 10.7, end of file)

**NEW:**

```markdown
## Epic 11: Live Run Flow, HUD, and Outpost

Players can play the full descent hands-on — launch, choose a class, fight generated levels and the Larval Avatar on the live tactical board, win or die for real, see the reveal lines and run summary, spend meta progress at the outpost, and start another descent.

> **Sequencing:** inserted 2026-07-04 via sprint change proposal; executes between Epic 9 and Epic 10's Stories 10.4-10.7. See the Epic List entry for FR coverage and implementation notes.

### Story 11.1: Run-Flow UX Appendix and Screen Contracts

As a player,
I want the MVP's screens to follow deliberate, readable designs,
So that the run flow communicates tactical and meta information clearly on phone and desktop.

**Prerequisite discharge:** this story delivers the "lightweight UX appendix" required by the UX Design Requirements readiness patch note before UI-heavy scene implementation, and consumed by Story 10.7's UX prerequisite check.

**Acceptance Criteria:**

**Given** UI-heavy scene implementation is about to begin
**When** the lightweight UX appendix is authored under planning artifacts
**Then** it covers tactical HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta menu, run summary, settings, and save/resume recovery states
**And** it additionally covers the first-death and first-victory reveal moments with their skip/dismiss affordances and the manual-seed no-progression warning surface.

**Given** the appendix is authored
**When** each screen section is reviewed
**Then** it maps to the existing view-model/command-bridge contracts (tactical view models, reward/passive modal contract, `HeroSelectViewModel`, `OutpostViewModel`, `RunSummary`, narrative beat DTOs) without inventing new domain surfaces
**And** any contract gap it identifies is recorded as an explicit note for the owning story rather than silently expanded scope.

**Given** the appendix exists
**When** layout coverage is reviewed
**Then** phone portrait, phone landscape, tablet, and desktop-style layouts are addressed for each screen (FR66)
**And** critical information avoids color-only meaning and supports scalable text (NFR8, NFR9).

### Story 11.2: Live Combat Loop and Hero Death Source

As a player,
I want fights to be played out for real and death to actually end a run,
So that a descent can be won or lost by what happens on the board.

**Acceptance Criteria:**

**Given** a run enters a combat, elite combat, or boss node
**When** the node resolves in the live run flow
**Then** resolution comes from live tactical play on the board state — player commands through the command bridge, enemy and boss turns through the existing turn resolvers
**And** the v0 auto-resolve-to-success placeholder no longer decides live combat outcomes (it may remain for explicitly non-live simulation paths).

**Given** the hero reaches 0 HP during any live encounter (level or boss)
**When** the combat loop detects hero death
**Then** it auto-fires the run-end resolution (`CompleteRunCommand` with the appropriate failure cause from `RUN_FAILED_CAUSES`) driving `PHASE_FAILED` and `next_destination == outpost`
**And** FR32's loss condition is triggerable live, with the first-death latch recordable off the real terminal state.

**Given** the Larval Avatar reaches 0 HP in the live flow
**When** the boss victory resolves
**Then** `RunOrchestrator.resolve_boss_victory()` gains its production call site (boss route node cleared, `resolve_run_end(victory)` driven, first-victory latch recorded via `RecordFirstVictoryCommand`)
**And** `run_to_completion` can auto-play the full boss fight headlessly (both sides simulated) for seed-batch and simulation use.

**Given** the live wiring lands
**When** the headless suite and seed regressions run
**Then** interrupted==uninterrupted determinism, the 23-key `RunSnapshot` gate, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams, and every pinned fingerprint hold
**And** forcing tests are added for defensive branches the live path makes reachable (the `_resolve_completed` step-2 restore; the `NodeResolvePlaceholderCommand._resolve_boss` atomicity twin if its branch is driven).

### Story 11.3: Run Flow Scene Navigation and In-Run HUD

As a player,
I want to move through a whole descent on screen — from launch to class select to levels to the run's end,
So that the roguelite loop is something I play rather than something tests prove.

**Acceptance Criteria:**

**Given** the game launches
**When** I start a run
**Then** `SceneManager` drives launch -> hero select -> route map -> tactical board per node -> run-end return
**And** navigation follows `RunEndOutcome.next_destination` and the existing view-model contracts, with no scene owning tactical truth.

**Given** I play a combat node
**When** the tactical board hosts a generated level in-run
**Then** movement/attack previews, two-step commit, inspect, the passive reward modal, and reward pickup flows work through the existing Epic 2/6 presentation contracts
**And** the in-run HUD presents run context (HP, node progress, gold, inventory/passives access) per the 11.1 appendix.

**Given** I quit and resume mid-run
**When** the resume flow runs at a between-level boundary
**Then** the run continues from the persisted snapshot with save/resume recovery states reachable through real screens
**And** resumed outcomes match uninterrupted play (NFR13).

**Given** phone portrait and desktop layouts
**When** the full flow is exercised on both
**Then** primary actions remain reachable and readable (FR66, NFR7)
**And** layout changes never alter tactical rules.

### Story 11.4: Live Affinity Pressure On Screen

As a player,
I want affinity levels to feel different and dangerous in real play,
So that Scorched, Flooded, Cursed, and Darkness change my tactical choices, not just visuals.

**Acceptance Criteria:**

**Given** a run level carries an affinity
**When** the level is played live
**Then** the Epic-7 affinity effects receive their first live call sites (Darkness visibility/memory pressure, Scorched damage-over-time, Cursed rule-source, Flooded per its ratified MVP placeholder posture)
**And** live effects match the headless-proven deterministic behavior (FR57).

**Given** an affinity is active
**When** the board and HUD present it
**Then** the approved affinity treatments and readability cues make the affinity and its rule visible before and during play (FR55)
**And** telegraphed danger remains inspectable through the existing inspect flow (FR12, FR58).

**Given** Darkness is active in live play
**When** fairness invariants are exercised on the live path
**Then** the 7.6 fairness guardrails hold (no unavoidable damage from unseen space)
**And** the darkness fairness queries remain the single authority the HUD reflects.

### Story 11.5: Outpost Scene, Reveal Renders, and Another Descent

As a player,
I want to return to a real outpost after a run — see what happened, read the line, and descend again,
So that the return loop and its story beats are experienced, not implied.

**Acceptance Criteria:**

**Given** a run ends in death or victory
**When** I return to the outpost
**Then** an outpost scene renders the `OutpostViewModel` contract (currency totals, named spaces, run summary, unlock progress)
**And** starting another descent works through the `start_run_request`/`is_startable` seam (FR1 loop closure).

**Given** the profile's first death or first victory has just been recorded
**When** the outpost presents the narrative beat
**Then** "Good. You remembered how to die." / "It did not die. It learned the way back." render as optional, skippable/dismissible beats (FR61, FR62, FR64, FR65)
**And** skipping or dismissing is a pure presentation no-op that never blocks the outpost surface or a new descent.

**Given** a profile load or write failure occurred
**When** the outpost renders recovery
**Then** the write-failure path uses the loaded-profile `_init` representation (real totals behind a retry banner) and the load-failure path uses the fresh-profile fallback
**And** the previously untested loaded-profile + recovery combination gains its scene-level test (carried Epic-8 T4).

**Given** the run summary displays
**When** "Oath Shards earned" is shown
**Then** the summary-to-profile coupling decision (carried Epic-8 T5 / Epic-9 T4) is made and implemented — display the awarded total on the summary or surface it via the outpost
**And** manual-seed runs show their no-progression warning (FR28 surface).

### Story 11.6: Meta Spend and Unlock Application

As a player,
I want to spend what I earn and feel meta progress apply,
So that descents feed a shallow but real progression loop.

**Acceptance Criteria:**

**Given** the profile holds Oath Shards and unlock progress
**When** I spend at the outpost's shallow meta menu (FR59)
**Then** spend operations run as validated commands that emit deterministic domain events and persist through `ProfileRepository`
**And** manual-seed-earned progress remains excluded end-to-end (FR28).

**Given** an unlock's requirements are met and its effect applied
**When** hero select next renders
**Then** the applied unlock is reflected (locked-class hint -> actual selectability path per FR43), with meta power staying capped and sparse per the ratified GDD FR95 posture
**And** the application flows profile -> class selectability through repositories/view models, never through scene-owned state.

**Given** spends and applications exist
**When** save/load and migration tests run
**Then** profile round-trips cover the new spend state additively (no schema bump unless justified against the 8.7 migration matrix)
**And** idempotency and caller-ordering safety match the run-end command family's standards.
```

### 4.7 `sprint-status.yaml` — insert epic-11 block (post-approval; checklist item 6.4)

Insert **between** `epic-9-retrospective: done` and `epic-10: backlog`, preserving file-order-driven next-story selection:

```yaml
  # SPRINT CHANGE 2026-07-04 (sprint-change-proposal-2026-07-04.md):
  # epic-11 executes BEFORE epic-10 — the live run flow / HUD / outpost layer is a
  # prerequisite for 10-4/10-5/10-6/10-7. Epic numbering intentionally NOT reshuffled.
  epic-11: backlog
  11-1-run-flow-ux-appendix-and-screen-contracts: backlog
  11-2-live-combat-loop-and-hero-death-source: backlog
  11-3-run-flow-scene-navigation-and-in-run-hud: backlog
  11-4-live-affinity-pressure-on-screen: backlog
  11-5-outpost-scene-reveal-renders-and-another-descent: backlog
  11-6-meta-spend-and-unlock-application: backlog
  epic-11-retrospective: optional
```

Also update `last_updated` and extend the `scope` line to `epics-1-11-tracked (epic-11 inserted 2026-07-04, executes before epic-10)`.

---

## 5. Implementation Handoff

**Change scope classification: MODERATE** — backlog reorganization (new epic + sequencing), no fundamental replan (MVP goals, architecture, and all existing epic scopes unchanged).

| Who | Responsibility |
|---|---|
| **Rasmus (PO/Lead)** | Approve/revise this proposal. Decision points embedded: (a) Epic-11-as-11-before-10 numbering, (b) 6-story split (11.5/11.6 may be merged at create-story time if sizing warrants), (c) whether 10-1..10-3 stay after Epic 11 or may interleave. |
| **Developer (this session, on approval)** | Apply §4 edits to `epics.md` + `sprint-status.yaml`; commit planning artifacts to `main` (docs-only change, per the project's tracking-file cadence). |
| **SM / auto-gds pipeline** | Next story becomes `11-1` via `gds-create-story` / the auto-gds epic loop, with the standing per-story merge cadence and the atomic finalize step (Epic-9 retro P2) in force from 11-1 onward. |
| **QA discipline (standing)** | Headless suite + false-PASS grep guard unchanged as the gate; Epic 11 stories add scene-level coverage without violating NFR14 (headless tests stay scene-free; scene smoke lives with the UI layer). |

**Success criteria for the handoff:**

1. `epics.md` contains the Epic List entry, the Epic 11 section (6 stories), the Epic 10 sequencing note + 4 prerequisite lines, the FR32/FR63 annotations, and the 2026-07-04 traceability note.
2. `sprint-status.yaml` shows the epic-11 block (all `backlog`) positioned before epic-10, with the sequencing comment and refreshed `last_updated`.
3. `git status --short` clean after a single docs-only commit to `main`.
4. The next `create story` invocation resolves to Story 11-1 without manual steering.

**Timeline note:** Epic 10's meaningful start (10-4 onward) moves behind Epic 11 (~6 stories). This defers the MVP readiness verdict by one epic but makes it a verdict about an actually playable game.

---

## 6. Change-Navigation Checklist Record

| Item | Status | Note |
|---|---|---|
| 1.1 Triggering story | [x] | Not one story: Epic 9 retro (§7, §10) synthesizing deferrals from 7-5/7-6, 8-1/8-5/8-6/8-7, 9-1/9-3/9-4/9-5. |
| 1.2 Problem definition | [x] | Planning omission / sequencing gap (category: original plan never allocated the deferral landing zone). |
| 1.3 Evidence | [x] | Retro §7/§10; deferred-work ledger re-carries; scene inventory; project-context as-built notes. |
| 2.1 Current epic viability | [x] | Epic 9 complete; nothing to modify. |
| 2.2 Epic-level changes | [x] | Add Epic 11 (new); Epic 10 annotated only. |
| 2.3 Future epics reviewed | [x] | Only Epic 10 remains; dependency mapped per story (10-4/5/6/7 gated; 10-1/2/3 free). |
| 2.4 Invalidated/new epics | [x] | None invalidated; one added. |
| 2.5 Order/priority | [x] | Epic 11 executes before 10-4..10-7; numbering deliberately not reshuffled. |
| 3.1 PRD/GDD conflicts | [x] | None; MVP intact; no GDD edit. |
| 3.2 Architecture conflicts | [x] | None; Epic 11 implements the designed presentation layer. |
| 3.3 UI/UX conflicts | [!] | UX appendix missing and now blocking → Story 11.1 (also feeds 10.7 AC5). |
| 3.4 Other artifacts | [x] | sprint-status.yaml edit; deferred-work.md untouched (resolved per-story later). |
| 4.1 Direct adjustment | [x] Viable — **SELECTED** | Effort Low (planning) / epic-sized delivery; Risk Low. |
| 4.2 Rollback | [x] Not viable | Nothing to revert. |
| 4.3 MVP review | [x] Not needed | Scope unchanged; "document the limitation" alternative rejected. |
| 4.4 Path selected | [x] | Option 1 with Epic-11-before-10 sequencing. |
| 5.1–5.5 Proposal components | [x] | This document. |
| 6.1 Checklist complete | [x] | All sections addressed. |
| 6.2 Proposal accuracy | [x] | Cross-checked against retro, ledger, epics.md, sprint-status, scene inventory, project-context. |
| 6.3 User approval | [!] | **PENDING — this is the gate.** |
| 6.4 sprint-status update | [!] | Post-approval (edit drafted in §4.7). |
| 6.5 Handoff confirmation | [!] | Post-approval (§5). |
