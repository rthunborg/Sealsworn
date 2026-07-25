# Agent Playtest 2026-07-20 — Triage into Dev Items

> Input to `gds-correct-course`. Converts `agent-playtest-2026-07-20.md` (20 findings) plus a
> user-directed dungeon-scale vision into two epics. Build `a78653c`. Author: agent triage,
> ratified by user 2026-07-24 (three design forks answered below).

## Ratified design decisions (2026-07-24)

- **Combat model:** keep the current core loop + route/node model — a node is still ONE fight you
  clear. But boards become **multi-room dungeons** (rooms + corridors + dead-ends + unreachable
  filler), and enemies **aggro independently on their own sight/range** (dormant until they see or
  sense the hero) rather than all activating at once. "Structured arenas" loop + "explorable-floor"
  geometry and awareness.
- **Scale:** Small `8×8 → ~12×12`, Medium `~14×12 → ~18×16`, add a new **Large `~26×28`** size
  class. Default camera zoom further out + grid-fit. A mobile device-tier perf pass gates the
  biggest boards.
- **Packaging:** **Epic 15** = playtest-response (ships the readability fix + bug fixes fast,
  unblocks human playtests). **Epic 16** = Dungeon Generation, Scale & Awareness (runs after 15;
  isolates the architecture-heavy fixture/winnability re-pin from the urgent fixes).

---

## Epic 15 — Playtest Response (finding → story map)

Bins are a starting decomposition; correct-course may merge/split.

### Band 1 — Readability hotfix (fast-track; blocks human playtests)

| Story | Findings | What it fixes |
|---|---|---|
| **15-1 HUD & log layout clip fix** | F1, F2 | Label column renders off-canvas at every window size; log's clipped overflow window. One `tactical_board_presenter` layout root cause. Land first and alone. |

### Band 2 — Correctness & unwired surfaces

| Story | Findings | What it fixes | Decision gate |
|---|---|---|---|
| **15-2 Attack-preview damage correctness** | F4 | Preview excludes support/passive bonuses (says 2, deals 3–4). | — |
| **15-3 Threat telegraphs** | F5 | Seer-mark tile overlay + verify detonation-flash cell anchor. | — |
| **15-4 Quit / pause / resume** | F3 | Boot "Continue" + in-game pause/quit. Reuses Epic-2 `SaveManager.resume_route_position`. | — |
| **15-5 Event-node & run-summary wiring** | F9, F10, F-Q1 | Event nodes show an outcome; shards/loot/consumed-passives recorded. | **D4** shard-income rule; **D1** HP-persistence |
| **15-6 Reward-modal fix** | F13 | Text-over-frame, blank confirm buttons, class-blind pool. | **D3** filter reward pool by class? |
| **15-7 Mis-tap safety** | F14 | Single-tap moves are irreversible. | **D2** confirm step vs pre-enemy undo |

### Band 3 — Presentation / feel

| Story | Findings | What it fixes |
|---|---|---|
| **15-8 Combat feel** | F7, F8, F16 | Wait-ack + sequence/animate the enemy phase + **tween movement so units don't teleport** (the movement-animation ask lives here) + fade deaths + count HP. |
| **15-9 Transitions & death moment** | F15 | Fades at scene seams + stage the death beat (Epic-8 narrative content exists in-repo). |
| **15-10 Theme & layout polish** | F17, F19, F11 | Collapse empty gray slabs; un-clip hero-select names / scale portraits; disambiguate hazard-vs-corpse art. |
| **15-11 Player-facing copy pass** | F6, F18 | Kill `enemy_3`/`iron_cultist_melee`/`hero_waited` leaks and the `[!]`/`◆`/"Coming later" markers. |
| **15-12 Weapon/kit display** | F12 | Persistent weapon reach/damage line. Small — may ride 15-10. |

### Pulled out of the epic (map to existing backlog / ledger)

- **F20 app-shell:** settings/accessibility surface → merges with backlogged **AG-3 settings-scene**;
  placeholder app icon → asset-pipeline / `deferred-work.md` item.
- Audio absence → already **AG-2** (descoped). Do not re-file.

### Design decisions to resolve before/inside Epic 15

- **D1** — Does hero HP persist across nodes in a descent? (F-Q1: it currently resets to full.)
- **D2** — Mis-tap fix: move-confirm step (matches attack) vs pre-enemy-phase undo?
- **D3** — Should the reward pool filter by class? (F13 offered a Ranger passive to a Pyromancer.)
- **D4** — Intended shard-income rule? (F10: currently always 0 vs 3/5-shard unlock costs.)

---

## Epic 16 — Dungeon Generation, Scale & Awareness

**Intent:** floors become larger multi-room dungeons; enemies wake on their own sight; camera
defaults further out. Core loop + route/node model unchanged. **Heaviest architectural risk in the
project so far** — it re-pins every generation fixture and re-proves the reference-combat-driver
winnability catalog (the first deliberate generation break since Epic 3/5).

Current baseline (grounded): Small = fixed `8×8`, Medium = fixed `~14×12`, both a single open
interior room (border wall ring + scattered blocker walls + 1–2 wrinkles), whole interior reachable,
central row reserved blocker-free. Size-class validator rejects anything but Small/Medium. Strict
fixed-RNG-draw-order determinism with per-seed fingerprint regression tests. Zoom seam exists
(`TacticalBoardZoomState`, 64px cells, default zoom 1.0) plus a grid-fit seam.

| Story | Scope | Risk |
|---|---|---|
| **16-1 Board scale-up + Large class (plumbing)** | Bump Small→~12, Medium→~18, add validated Large ~26×28 to `GenerationRequest` + `LevelRecipeDefinition` + validator. KEEP the current open-interior algorithm (just bigger) so the dimension change re-pins fixtures ONCE, cleanly, before the algorithm changes. Re-prove winnability at new sizes. | Medium — one clean fixture re-pin |
| **16-2 Room/corridor/dead-end generation** | Replace open-interior gen with a room-placement + corridor-carve algorithm (multiple rooms, corridors, dead-ends, unreachable filler). New validators: reachable-set connectivity, entrance↔exit, every enemy/reward on a reachable cell, minimum-combat-space guarantee. Ripple the "unreachable cell" concept through movement/path/fog/tap-router (never a move target). Re-pin fixtures + re-prove winnability. | **High** — the heavy story; second fixture re-pin; new seed catalog |
| **16-3 Enemy aggro / sight-based activation** | Enemies start dormant, activate when they see/sense the hero (LoS + sight range) via the existing `tactical_visibility_query` / darkness layer; dormant enemies don't act, activated ones use current AI. AI-decision explanation tests. | Medium — combat-AI + turn-resolver change |
| **16-4 Camera default zoom-out + grid-fit** | Lower default zoom / grid-fit so a Large floor reads at a glance on mobile, with pan/zoom to inspect. Pure presentation seam. Depends on 15-8 movement tween for feel (Epic 15 ships first). | Low |
| **16-5 Mobile performance pass at Large scale** | Verify the biggest boards render within the device-tier budget (`device-tiers-and-performance-budgets.md`); tile batching/culling if needed. Gates the Large class. | Medium — the perf gate |

**Sequencing:** 16-1 → 16-2 → 16-3, with 16-4 after 16-1 and 16-5 as the closing gate. Movement
tween (Epic 15 / 15-8) lands before 16-4 so movement is already animated when Large floors arrive.

**Cross-cutting risks to call out in the proposal:** (1) two fixture re-pins (16-1 dims, 16-2
algorithm) — deliberate, each independently verifiable; (2) the winnability catalog needs fresh
seeds for the new geometry at each size; (3) unreachable cells are a new domain invariant touching
pathing/fog/tap; (4) mobile perf is the hard gate on the Large class.
