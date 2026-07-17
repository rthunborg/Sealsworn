# Agent Playtest — 2026-07-16 (desktop, agent-driven)

> **Protocol:** modeled on `_bmad-output/planning-artifacts/mvp-playtest-comprehension-checklist.md`
> (§4 session record, §3 comprehension items), driven by an AI agent via OS-level mouse/keyboard on
> the real Windows build. An agent session **cannot** score the human-felt OSG dimensions (fun,
> memorability, replay desire) and does not count toward the ≥5 observed human sessions (OSG-1).
> What it CAN do — and did — is exercise every reachable surface and record concrete defects.
> **Two runs were played; neither could be completed.** Run 1 ended in an unexplained death;
> run 2 ended in a permanent mid-fight soft-lock.

## Session records

### Session A (run 1)

| Field | Value |
|---|---|
| Tester id / alias | claude-agent (observer = same) |
| Date | 2026-07-16 |
| Device / form factor | Windows desktop, windowed 1080×1006 → 958×1006 (window resized mid-run externally) |
| Build id | `main` @ `259c32b` (post-Epic-13) |
| Seed | unknown — not surfaced anywhere in the UI; observed to be IDENTICAL across all runs |
| Class | Warrior (selected; no visual confirmation of selection) |
| Session length | ~10 min |
| Run outcome | death (node 1, the depth-0 opener combat) |
| Nodes cleared | 0 of 12 |
| Notable confusion | see findings F2, F3, F6, F7, F9 |
| Memorable moment | none — no moment is staged; the death itself went entirely unmarked (F5) |
| Desire for another descent | n/a (agent) |
| Blocked action | attacking a dead-but-alive-looking enemy (F8); moving into walls (silent, F3) |

### Session B (run 2)

| Field | Value |
|---|---|
| Tester id / alias | claude-agent |
| Date | 2026-07-16 |
| Device / form factor | Windows desktop, windowed 958×1006 |
| Build id | `main` @ `259c32b` |
| Seed | unknown — board/enemy layout identical to run 1 (third identical board incl. a mid-run relaunch) |
| Class | none — "Descend Again" skipped hero select and started a 60/60-HP driver-default loadout (F4) |
| Session length | ~10 min |
| Run outcome | **permanent soft-lock** (node 1): hero boxed in by 2 corpses + 2 walls, no wait action, last enemy unreachable (F1) |
| Nodes cleared | 0 of 12 |
| Notable confusion | single-tap attacks appear dead — only blind double-taps act (F2); diagonal moves silently rejected (F3) |
| Memorable moment | none |
| Desire for another descent | n/a |
| Blocked action | every orthogonal move (corpse/wall-blocked) AND no pass-turn affordance → nothing left to do (F1) |

## Comprehension items (checklist §3) — as scored by the agent

| # | Item | Read |
|---|---|---|
| 1 | Movement | PARTIAL — single-tap move works when legal, but there is no range highlight, no legality feedback, and orthogonal-only + corpse-blocking are communicated nowhere |
| 2 | Attack preview clarity | **FAIL** — no preview ever renders ("Preview: none" throughout both runs); damage/target/legality never shown before commit |
| 3 | Preview/commit distinction | **FAIL (hard)** — the preview state has NO visual representation at all; single taps look dead, only tap-pairs act. FR11's load-bearing non-color cue does not exist on screen |
| 4 | Damage/death explanation | **FAIL** — no damage numbers, no hit/miss feedback, "Log: 0 events" forever; run-1 death was a hard cut to the Outpost with zero acknowledgment |
| 5 | Consume/Destroy clarity | NOT REACHABLE — both runs ended before any reward offer (blocked by F1/F5) |
| 6 | Positioning importance | PARTIAL — enemy approach/AI works and darkness LoS works underneath, but with no telegraphs/marks rendered, positioning reads as guesswork |
| 7 | Quit/resume | NOT TESTED (runs never got far enough to make it meaningful) |

## Findings

### Blockers (game-breaking; a player cannot finish the first fight)

- **F1 — Permanent mid-fight soft-lock: corpse-blocking + no wait/pass action.** Dead enemies
  block movement, there is no wait/pass-turn affordance, and enemy turns only advance on a
  *successful* player action. Killing the two melee enemies at the map's chokepoint (the natural
  place they engage) leaves the hero boxed in by 2 corpses + 2 walls with the last (ranged) enemy
  idle out of reach: every available input is rejected → turns never advance → the run is dead with
  no message, forever. Reproduced live in session B. Verified via inspect: both blocking cells
  report `enemy … HP 0`.
- **F2 — Attack preview state renders nothing.** The two-step tap-commit (first tap = preview,
  second = commit; UX appendix §2.3, FR11) exists in the domain but has zero visual presence:
  no mode change, no highlight, no preview panel ("Preview: none" / "Confirm:false Cancel:false
  (mode none)" at all times). Players experience single taps as ignored and can only act by
  accidental/blind double-taps. This alone makes combat feel broken.
- **F3 — Every rejected command is silent.** Move into wall, diagonal move, move onto corpse,
  attack on a corpse — all produce no shake, no toast, no sound, no log line, nothing.
  Indistinguishable from a frozen game; directly produced both "the game is stuck" episodes.
- **F4 — "Descend Again" starts a class-less run.** It skips hero select and starts with the
  fail-open driver-default loadout (observed HP 60/60 vs class baseline 18) — no class kit, no
  class choice. The most common post-death path (die → descend again) silently abandons the
  class system.
- **F5 — Death is a hard cut.** On hero death the screen jumps straight to the Outpost: no death
  moment, no cause, no run summary, and the Epic-8 first-death narrative beat never renders.
  A first-time player does not even learn that they died.

### Major comprehension / feedback gaps

- **F6 — The event log surface is dead.** "Log: 0 events" through two full runs of moves, attacks,
  kills, and a death. The explainability contract (every DomainEvent player-explainable) has no
  live outlet.
- **F7 — No combat feedback channel at all.** No damage numbers, no hit/miss indication, no
  animations (sprites teleport), no death animation, no telegraphs/marks — outcomes are readable
  only by diffing tiny HP bars between screenshots. With audio also absent (descoped), the game
  currently has zero feedback channels.
- **F8 — Dead enemies look alive.** Corpses keep their standing sprite; in run 1 a dead seer kept
  a stale ~40% HP bar while inspect reported `HP 0` (run 2's corpse lost its bar — inconsistent).
  Attacking the "alive-looking" corpse is silently rejected (F3).
- **F9 — The HUD is a debug readout.** Raw internals shown to the player: "Confirm:false
  Cancel:false (mode none)", snake_case cue ids (`affinity_darkness_reduced_visibility`),
  pipe-separated stat dump, "Inspect: (1,5) visible | player hero HP 10". Tiny font, hard-left
  anchored at x=0, huge dead vertical gaps.
- **F10 — No affordances or rules surfacing.** No reachable-tile/range highlights, no turn/phase
  indicator (beyond the debug string), no action-economy display, no end-turn/wait button, and
  movement rules (orthogonal-only, 1 tile, corpse-blocking) are never communicated.
- **F11 — Fixed seed / zero variety.** Board, enemy set, and positions were identical across three
  boots/runs. Every "new descent" is the same room.
- **F12 — No route map ever appears.** Hero select drops straight into combat; node position is
  only visible as "Node 0/12" in the debug line. The route-choice loop step has no surface in the
  live flow.

### Presentation-quality findings (the "high-school project" gap)

- **F13 — Hero select:** five thin gray text bars + ~85% empty void; no title screen; the approved
  character portraits (`char.warrior.png` etc., already imported in-repo) are not used; no kit/
  class info for playable classes; **zero selection feedback** (the screen is pixel-identical
  after clicking a class).
- **F14 — Outpost:** literal `[#]` and `[!]` marker prefixes rendered to the player, four
  "(coming soon)" rows, "Oath Shards earned this run: not yet tallied" placeholder copy, same
  bar-plus-void layout, no art.
- **F15 — Layout/scaling:** the board doesn't scale to use available space; tall windows show a
  huge gray dead zone; HUD labels sit at fixed offsets unrelated to the board; window resize
  reflows mid-run without re-rendering scale sensibly.
- **F16 — No theme.** Default Godot Control styling everywhere outside the board: unstyled
  buttons/bars, no StyleBoxes, no fonts, no spacing system — despite the generated Recraft UI
  frame kit (button_plate/panel_frame/modal_frame.svg) sitting unused in the repo.

### What already works (credit where due)

- Board/tile/character art reads well; darkness/fog rendering is atmospheric.
- Tap hit-testing is pixel-accurate (every tap landed on the intended cell across two window sizes).
- Inspect metadata is rich and correct (coords, visibility, occupant id/type/HP, danger, cues).
- The domain underneath behaves: turn engine, enemy AI approach, LoS/darkness, HP model, and
  fail-closed command validation all function; no crashes, no script errors in the Godot log.

## Disposition

These findings are input to a **playability-and-presentation epic** (sprint-change flow), in two
bands: (1) make the loop *finishable and readable* — F1–F5 blockers plus the feedback layer
F6–F12; (2) make it *look intentional* — F13–F16 theme/layout/screen passes. The known ledger
items (reward-overlay geometry, full-backpack escape hatch, passive-confirm display_name, run
summary/event store) fold into the same bands. Observed human playtests (OSG-1..4) should wait
until band 1 lands — today they would only measure the F1/F2 walls.
