# Sprint Change Proposal — Epic 12 Insertion (Interactive Tactical Combat)

- **Date:** 2026-07-07
- **Facilitator:** Developer (correct-course workflow, `gds-correct-course`)
- **Requested by:** Rasmus (Project Lead)
- **Trigger artifact:** `_bmad-output/implementation-artifacts/epic-11-retro-2026-07-06.md` §9/§10
- **Mode:** Incremental (each edit proposal reviewed and approved individually)
- **Precedent:** `sprint-change-proposal-2026-07-04.md` (Epic 11 insertion — same structural pattern)

---

## 1. Issue Summary

### Problem statement

Epic 10's Story 10.4 (Gameplay Comprehension and Playtest Checklist) and Story 10.6
(MVP Readiness Gate) assume a human can play — and WIN — moment-to-moment tactical
combat by hand. The as-built system cannot support that: Epic 11 deliberately shipped
combat input as an **auto-resolve stand-in** (the ratified L3 deferral), the live board
is not rendered during play on a combat node (`resolve_combat_node_live` returns
terminal-only metadata with no `"board"` key — the L4 gap), and the hero has no
winnable hands-on path (the scripted live hero is deterministic but not
universally-winning; `StartingKit.baseline_hp` (warrior 18) is a balance number, not a
viable live HP; the live driver uses `LiveCombatResolver.DEFAULT_HERO_HP` 60 with no
class-kit → combat-loadout wiring). **No story in the backlog owns building any of
this.**

### What is actually missing (per the Epic-11 retro T1/T2)

1. **The interactive combat tap-loop (T1, HIGH).** The tap seam (`submit_move` /
   tap-attack / `inspect_cell`) so a human drives the live board across taps, per the
   run-flow UX appendix §14 contract (first tap PREVIEWS, second tap COMMITS, ≥44px
   targets — already designed in Story 11.1's appendix).
2. **The live-board render on a combat node (T1/L4).** Surfacing the live board so it
   renders during play, not only as terminal metadata.
3. **A winnable hands-on hero path (T2, MED-HIGH).** Class-kit → combat-loadout wiring
   (and/or a strengthened reference driver as the proof harness) so a human can win an
   arbitrary generated fight and classes are tactically distinct — also the direct
   input to 10.4's class-comparison AC.

### Evidence

- Epic-11 retro §10, structured drift line: *"The interactive-combat tap-loop … is an
  implicit prerequisite for Epic 10's hands-on playtest + loop-gate, and is NOT in the
  epic list — STRUCTURAL (sequencing)."* Recommends exactly this re-sync decision.
- Epic-11 retro §9 readiness table: ⚠️ *"Remaining 'felt hands-on' residual … a human
  cannot yet WIN an arbitrary generated fight by hand. An effective input to 10-4/10-6,
  not in the Epic-10 list."*
- Epic-11 retro §8 Action Items T1 (HIGH) and T2 (MED-HIGH), both flagged as gating
  10-4/10-6.
- `deferred-work.md` (11.4 recorded `[Decision]`): *"The full L3 auto-resolve→tap-loop
  handoff STAYS deferred."*
- `epics.md` Story 10.4 ACs (movement comprehension, attack preview clarity,
  preview/commit distinction — unobservable without human-driven combat) and Story
  10.6 loop gate ("fight … die or win").
- `sprint-status.yaml`: `epic-11: done` (all six stories `done`), `epic-10: backlog`
  (all seven stories `backlog`) — the change lands exactly at the Epic-10 kickoff
  boundary.

### Issue category

Sequencing/allocation gap discovered at epic transition (a planning-drift flavor of
"technical limitation discovered during implementation"). Not a defect: the L3/L4/T2
deferrals were deliberate, ratified, and recorded; what was missing was a backlog home
for the deferred body ahead of the stories that implicitly depend on it.

---

## 2. Impact Analysis

### Epic impact

- **Epic 10** cannot pass as written: 10.4's comprehension checklist and observed
  sessions, and 10.6's "die or win" loop-gate step, presuppose hands-on combat.
  10.1–10.3 are unaffected and can start immediately. 10.5 is not blocked, but its
  audit gains real subject matter (tap targets, preview/commit surfaces) once the
  tap-loop lands. 10.7 is unaffected beyond already-tracked items (Flooded D2).
- **No other epics remain** (Epics 1–9 and 11 are `done`). Nothing is invalidated;
  the change is purely additive allocation.
- **Ordering:** unchanged for 10.1–10.3. Epic 12 executes between 10.3 and 10.4.

### Story impact

- **New:** Story 12.1 (interactive tap-loop + live board render), Story 12.2 (class
  loadout + winnable hands-on fights).
- **Annotated:** 10.4 and 10.6 gain an Epic-12 prerequisite line; the Epic 10 intro
  gains a dated sequencing note (10.5 covered by a soft audit mention there).
- **Unchanged:** all other stories.

### Artifact conflicts

| Artifact | Conflict | Resolution |
|---|---|---|
| `epics.md` (canonical) | Epic 10's 10.4/10.6 assume an unallocated capability. | Edits in §4 (Epic List entry, Epic 10 notes, new Epic 12 section, traceability note). |
| `sprint-status.yaml` | Missing epic block. | Edit in §4.5 (post-approval, checklist 6.4). |
| GDD | None if we build. (The alternative — annotating the limitation away — would strain the "game loop first" pillar and "MVP scope must prove the complete rough roguelite loop".) | No edit. |
| `game-architecture.md` | None — the tap seam fits the existing command-bridge/presenter pattern; resolve-then-advance and the scene-free harness constraints already govern it. | No edit. |
| `ux-appendix-run-flow.md` | None — §14 already specifies the tap interaction contract (11.1 designed it ahead of implementation). | No edit; Epic 12 references it. |
| `project-context.md` | Story 12.2 deliberately revises the load-bearing 11.2 "class-kit → combat-loadout is a later story" boundary. | Updated by Story 12.2 in the same change (AC-pinned), not by this proposal. |
| `deferred-work.md` | T1/T2 entries resolve per-story later (the established per-story resolution pattern). | No edit now. |

### Technical impact

- All new logic must live in `RefCounted` seams (scene-free headless harness); scene
  wiring verified by construction + the scene-load compile guardrail.
- The default hands-off auto-resolve driver must remain available and byte-identical
  (seed-batch/AC proofs, every pinned fingerprint). Any intentionally changed
  live-combat fixture is re-pinned in the same change.
- Resolve-then-advance sequencing (the 11.3 H1 lesson) must be preserved by the
  tap-loop. No new autoload, no new RNG stream/draw site, 23-key `RunSnapshot` gate
  stays 23, in-node fight state stays ephemeral.

---

## 3. Recommended Approach

**Option 1 — Direct Adjustment (SELECTED, via new-epic insertion): insert Epic 12
"Interactive Tactical Combat" (Stories 12.1–12.2), executed between 10.3 and 10.4.**
Mirrors the proven 2026-07-04 Epic-11 insertion pattern: no renumbering, dated
sequencing notes, prerequisite annotations on dependent stories. Keeps Epic 10 a pure
tuning/readiness epic. Effort: Medium (two implementation stories + docs-only planning
edits). Risk: Low — the UX contract already exists (§14), the domain commands/preview
view-models already exist (Epics 1–2), and the work is additive behind opt-in seams.

Rejected alternatives:

- **Option 2 — Rollback: NOT VIABLE.** Nothing to revert; Epic 11 is correct,
  additive, and complete. The gap is unallocated future work, not a wrong turn.
- **Option 3 — MVP Review (annotate the limitation, don't build): VIABLE BUT
  REJECTED.** Annotating 10.4/10.6 to accept the auto-resolve stand-in would gut
  10.4's comprehension ACs (movement/attack/preview-commit comprehension cannot be
  observed if a human cannot drive combat) and strain the GDD "game loop first" MVP
  pillar. High risk to MVP validity for a Low effort saving.
- **Add stories inside Epic 10 (Direct Adjustment variant): REJECTED on shape.**
  Mixing implementation stories into a tuning/readiness epic muddies Epic 10's
  identity; the new-epic pattern is established and the auto-gds pipeline consumes
  either shape equally well.

### Execution order after this change

`10-1 → 10-2 → 10-3 → 12-1 → 12-2 → 10-4 → 10-5 → 10-6 → 10-7`
(10-1..10-3 may also run before/parallel to the planning edits landing, as they are
independent.)

### Effort / timeline impact

Two implementation stories added to the MVP critical path ahead of 10-4. This is work
the MVP always required to be validatable — the change converts an implicit,
unallocated prerequisite into explicit backlog items. No scope is added beyond what
10.4/10.6 already assumed.

---

## 4. Detailed Change Proposals

All four proposals were reviewed and **APPROVED** individually (Incremental mode,
2026-07-07).

### 4.1 `epics.md` — Epic List: add Epic 12 entry (after the Epic 11 entry, ~line 495)

```markdown
### Epic 12: Interactive Tactical Combat

Players drive moment-to-moment combat by hand on the live tactical board — tap to
move, preview and confirm attacks, inspect tiles — with a class loadout that makes
generated fights winnable and classes tactically distinct.

**FRs covered:** live/on-screen tap delivery of FR3, FR4, FR8, FR9, FR10, FR11, FR12
(movement/attack previews, two-step commit, inspect — domain and view-model layers
shipped in Epics 1-2; this epic wires the live input seam), plus the class-kit →
combat-loadout wiring that revises the Story 11.2 deferred boundary. Primary
FR-to-epic assignments in the FR Coverage Map are unchanged.

**Implementation notes:** Added 2026-07-07 via sprint change proposal (see
`sprint-change-proposal-2026-07-07.md`) to allocate the Epic-11 retro's T1/T2
residual (the interactive tap-loop + a winnable hero path — the last piece of
hands-on play). **Sequencing: executes between Epic 10's Stories 10.3 and 10.4.**
The tap-loop follows the run-flow UX appendix §14 contract (first tap PREVIEWS,
second tap COMMITS, ≥44px targets); all decision logic lives in RefCounted seams
(scene-free harness); the default hands-off auto-resolve driver stays available and
byte-identical for seed-batch proofs; resolve-then-advance is preserved; no new
autoload; every pinned fingerprint holds unless intentionally re-pinned in the same
change.
```

### 4.2 `epics.md` — Epic 10 section intro: add sequencing note (below the 2026-07-04 note, ~line 2353)

```markdown
> **Sequencing note (2026-07-07, sprint change):** Stories 10.4 and 10.6 additionally
> require **Epic 12 (Interactive Tactical Combat)** — their observed hands-on sessions
> and "die or win" loop gate assume a human can drive and win moment-to-moment combat,
> which Epic 11 deliberately shipped as an auto-resolve stand-in. Story 10.5 is not
> blocked but should audit the tap/preview/commit surfaces Epic 12 adds. Stories
> 10.1-10.3 remain independent.
```

### 4.3 `epics.md` — prerequisite lines under dependent story headers

Under the Story 10.4 header (below the existing 2026-07-04 prerequisite):

```markdown
**Prerequisite (2026-07-07):** Epic 12 — observed sessions require a human driving
moment-to-moment combat with a winnable class loadout; the auto-resolve stand-in
cannot exercise the comprehension checklist.
```

Under the Story 10.6 header (below the existing 2026-07-04 prerequisite):

```markdown
**Prerequisite (2026-07-07):** Epic 12 — the loop gate's "fight … die or win" steps
must be playable by hand, not auto-resolved.
```

### 4.4 `epics.md` — dated traceability note (after the 2026-07-04 traceability note, ~line 405)

```markdown
### 2026-07-07 Sprint Change Traceability (Epic 12 insertion)

- Trigger: Epic 11 retrospective §10 — STRUCTURAL sequencing drift: the interactive
  tap-loop (T1) + winnable hero path (T2) are implicit prerequisites of 10.4/10.6
  but were allocated to no story.
- Change: Epic 12 (Interactive Tactical Combat, Stories 12.1-12.2) inserted,
  executing between Stories 10.3 and 10.4. No renumbering. Prerequisite annotations
  added to 10.4/10.6; audit note for 10.5 in the Epic 10 sequencing note.
- See `sprint-change-proposal-2026-07-07.md`.
```

### 4.5 `epics.md` — new Epic 12 section (appended after Story 11.6, end of file)

```markdown
## Epic 12: Interactive Tactical Combat

Players drive moment-to-moment combat by hand on the live tactical board — tap to
move, preview and confirm attacks, inspect tiles — with a class loadout that makes
generated fights winnable and classes tactically distinct.

> **Sequencing:** inserted 2026-07-07 via sprint change proposal; executes between
> Epic 10's Stories 10.3 and 10.4. See the Epic List entry for FR coverage and
> implementation notes.

### Story 12.1: Interactive Combat Tap-Loop and Live Board Render

As a player,
I want to move, attack, and inspect on the live tactical board with my own taps,
So that I make the tactical decisions instead of watching an auto-resolved fight.

**Acceptance Criteria:**

**Given** a run is parked on a combat or elite_combat node in the gameplay shell
**When** the node begins
**Then** the live board renders on-screen with hero, enemies, terrain, fog, and
affinity treatments (closing the L4 no-"board"-key gap in live metadata)
**And** the rendered board is a projection of the domain board — no scene node owns
tactical truth.

**Given** the live board is rendered and it is the player's turn
**When** the player taps a reachable tile, taps a valid attack target, or inspects
**Then** movement previews (FR8), attack previews (FR9/FR10), and inspect (FR12)
surface through the existing view-model and command-bridge contracts
**And** a first tap PREVIEWS and a second confirming tap COMMITS (FR11), with ≥44px
targets, per the run-flow UX appendix §14
**And** committed actions submit the existing commands through the command bridge —
no parallel combat path.

**Given** a committed player action resolves
**When** enemy and boss turns respond
**Then** the existing turn resolvers drive responses unchanged in ownership
**And** the resolve-then-advance sequencing seam is preserved (the node resolves
before any route advance — the 11.3 H1 lesson).

**Given** the headless suite and seed regressions run
**When** the tap-loop lands
**Then** all tap-loop decision logic lives in RefCounted seams testable without a
SceneTree (scene wiring verified by construction + the scene-load compile guardrail)
**And** the default hands-off auto-resolve driver remains available and
byte-identical (every pinned fingerprint unchanged; no new autoload; no new RNG
draw site).

### Story 12.2: Class Loadout and Winnable Hands-On Fights

As a player,
I want my chosen class's kit to arm me for a fight I can actually win,
So that hands-on combat is fair and classes feel tactically distinct.

**Acceptance Criteria:**

**Given** a run starts with a selectable class
**When** a live combat node begins under the tap-loop
**Then** the hero's live loadout (HP, weapon, support, passives) derives from the
class starting kit rather than the flat scripted default
**And** the Story 11.2 "class-kit → combat-loadout is a later story" boundary is
formally revised by this story, with `project-context.md` updated in the same
change.

**Given** the approved live-combat seed batch
**When** a strengthened reference driver (retro T2, e.g. LoS-aware targeting) plays
each playable class
**Then** every approved seed is winnable by at least one legal line of play per
class
**And** unwinnable seeds fail loud with seed + class + reason and are triaged before
Story 10.4.

**Given** the three playable classes on the same seed
**When** live loadouts are compared
**Then** each class changes at least one combat decision through equipment, passive,
or preview behavior (the direct input to 10.4's class-comparison AC).

**Given** determinism and save gates
**When** the loadout wiring lands
**Then** no new RNG stream or unnamed draw site is added, the 23-key RunSnapshot
gate stays 23, and the in-node fight state remains ephemeral
**And** any intentionally changed live-combat fixture/fingerprint is re-pinned in
the same change, with the hands-off default path otherwise byte-identical.
```

### 4.6 `sprint-status.yaml` — insert epic-12 block (post-approval; checklist item 6.4)

Inserted BETWEEN the `10-3` and `10-4` entries in `development_status` — the file
follows a file-order-is-execution-order principle (the epic-11 block sits before
epic-10 for the same reason), so this placement encodes the execution position
directly. `epic-12-retrospective: optional` added after `epic-10-retrospective`;
`scope` extended to `epics-1-12-tracked (...; epic-12 inserted 2026-07-07, executes
between 10-3 and 10-4)`; `last_updated` refreshed:

```yaml
  10-3-generator-soft-lock-and-fairness-batch-checks: backlog
  # SPRINT CHANGE 2026-07-07 (sprint-change-proposal-2026-07-07.md):
  # epic-12 executes BETWEEN epic-10's 10-3 and 10-4 (file order = execution order) —
  # the interactive tap-loop + winnable class loadout are prerequisites for 10-4's
  # hands-on sessions and 10-6's "die or win" loop gate. Epic numbering intentionally
  # NOT reshuffled.
  epic-12: backlog
  12-1-interactive-combat-tap-loop-and-live-board-render: backlog
  12-2-class-loadout-and-winnable-hands-on-fights: backlog
  10-4-gameplay-comprehension-and-playtest-checklist: backlog
```

---

## 5. Implementation Handoff

**Scope classification: MODERATE** — backlog reorganization (a new epic + two stories
inserted into the execution order), docs-only planning edits now, implementation via
the normal story pipeline afterwards. No fundamental replan: GDD, architecture, and UX
artifacts are untouched.

| Role | Responsibility |
|---|---|
| **Developer (this session, on approval)** | Apply §4 edits to `epics.md` + `sprint-status.yaml`; commit planning artifacts to `main` (docs-only change, per the project's tracking-file cadence). |
| **Scrum Master / auto-gds pipeline** | Execute the revised order: `10-1 → 10-2 → 10-3 → 12-1 → 12-2 → 10-4 → …`. Drive 12-1/12-2 through the standard create-story → dev-story → code-review pipeline. `gds-create-story` for 12.1/12.2 must pull the run-flow UX appendix §14, the Epic-11 retro T1/T2 text, and the 11.2/11.3 boundary rules into the story context. |
| **Rasmus (Project Lead)** | Approves this proposal; later ratifies any 12.2 balance decisions (loadout HP source, re-pinned fixtures) surfaced during implementation. |

**Success criteria:**

1. `epics.md` contains the Epic 12 List entry, the Epic 10 sequencing note + two
   prerequisite lines, the 2026-07-07 traceability note, and the Epic 12 section
   (Stories 12.1–12.2).
2. `sprint-status.yaml` shows the epic-12 block (all `backlog`) with the sequencing
   comment and a refreshed `last_updated`.
3. The next story consumed by the pipeline after 10-3 is 12-1, and 10-4 is not
   started before 12-2 is `done`.
4. When 12.1/12.2 land: headless suite green, every untouched fingerprint
   byte-identical, the auto-resolve default path preserved, and the Epic-11 retro
   T1/T2 entries resolvable in `deferred-work.md`.

---

## 6. Change-Navigation Checklist Record

| Item | Status | Note |
|---|---|---|
| 1.1 Triggering story | [x] | Not a story — Epic-11 retrospective §9/§10 (2026-07-06) + the recorded 11.4 L3 `[Decision]`. |
| 1.2 Problem definition | [x] | Sequencing/allocation gap; statement in §1. |
| 1.3 Evidence | [x] | Retro §8 T1/T2, §9 ⚠️ residual, §10 structured drift line; deferred-work ledger; 10.4/10.6 AC text; sprint-status. |
| 2.1 Current epic viability | [x] | Epic 10 blocked at 10.4/10.6 as written; 10.1–10.3 unaffected. |
| 2.2 Epic-level changes | [x] | Insert Epic 12 (two stories) between 10.3 and 10.4. |
| 2.3 Future epics review | [x] | None remain beyond Epic 10. |
| 2.4 Invalidation check | [x] | Nothing invalidated; additive allocation. |
| 2.5 Order/priority | [x] | New execution order recorded in §3. |
| 3.1 GDD conflict | [x] | None (building aligns with "game loop first"; the annotate-away option would have conflicted). |
| 3.2 Architecture conflict | [x] | None — existing command-bridge/presenter pattern covers the tap seam. |
| 3.3 UI/UX conflict | [x] | None — UX appendix §14 already specifies the tap contract. |
| 3.4 Other artifacts | [x] | sprint-status.yaml edit; project-context.md revised by Story 12.2 itself; deferred-work resolves per-story. |
| 4.1 Direct adjustment | [x] Viable | SELECTED (new-epic shape). Effort Medium / Risk Low. |
| 4.2 Rollback | [x] Not viable | Nothing to revert. |
| 4.3 MVP review | [x] Viable, rejected | High MVP-validity risk (guts 10.4 comprehension ACs). |
| 4.4 Path selected | [x] | Option 1 via Epic 12 insertion; rationale in §3. |
| 5.1–5.5 Proposal components | [x] | This document §§1–5. |
| 6.1 Checklist review | [x] | All sections addressed. |
| 6.2 Proposal accuracy | [x] | Cross-checked against retro, deferred-work ledger, epics.md, sprint-status, ux-appendix, project-context. |
| 6.3 User approval | [x] | Path + all four edit proposals approved incrementally 2026-07-07; final approval recorded below. |
| 6.4 sprint-status update | [x] | Applied 2026-07-07 per §4.6 (epic-12 block between 10-3 and 10-4; scope + last_updated refreshed). |
| 6.5 Handoff confirmed | [x] | §5 table. |

**Approval:** Approved by Rasmus, 2026-07-07 (path decision + Proposals 1–4 approved individually in Incremental mode; final proposal approval recorded in-session).
