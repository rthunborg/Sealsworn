---
name: agent-playtest
description: Agent-driven desktop playtest of the built Sealsworn game — launches the real Godot build, plays it via OS-level input + screenshots, finds bugs AND critiques professional quality (missing animations, UI, juice, absent surfaces) against a six-lens rubric, then writes a findings report ready for correct-course/sprint planning. Use when the user says "playtest the game", "agent playtest", "run a playtest", "critique the game", or wants screenshots/feedback on how the game looks and feels.
---

# Agent Playtest

Play the real Windows build like a player, but evaluate like a game director. Two outputs every
run: a **findings report** (bugs + comprehension + quality critique + absence audit) at
`playtest-sessions/agent-playtest-<YYYY-MM-DD>.md`, and the **screenshot evidence** in the session
scratchpad. Findings feed `gds-correct-course` / sprint planning — this skill never fixes code.

Read `references/rubric.md` before evaluating — lenses 3–6 are what turn this from bug-hunting
into "what does a professional game have that this doesn't" critique. The rubric's absence
inventory is mandatory: missing things are only found by checklist, never by inspection.

## 1. Setup

1. Copy `assets/game-ctl.ps1` (this skill's folder) to the session scratchpad; create a
   `playtest-shots/` folder there too. All actions run through this script — it locates the Godot
   window by process, recomputes geometry every call, and provides:
   `info` · `move -X -Y -W -H` · `shot -Path p.png` · `burst -Path p.png [-Frames 6 -IntervalMs 120]`
   · `click -X -Y` · `dblclick -X -Y` · `key -Key "{ENTER}"` · `topmost` / `notopmost`.
   Click coords are CLIENT coords inside the game viewport (the same space as the screenshots).
2. Launch the game:
   `Start-Process -FilePath "C:\Users\Rasmus\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" -ArgumentList "--path","C:\Sealsworn\godot"` then wait ~6 s.
3. Immediately run `topmost` (pins the game above other windows so screenshots and clicks always
   hit it) and `move` it fully onto ONE monitor (a window straddling a smaller monitor captures a
   black band). Record `info`.
4. Note the build: `git -C C:\Sealsworn log --oneline -1` is the build id for the session record.

### Windows quirks (all learned the hard way)

- **The window drifts** when the user is active (snap/drag). The script recomputes origin per
  call, but YOUR cell coordinates are layout-relative: re-`shot` and re-derive coordinates
  whenever `info` reports a changed `client_size` — the UI reflows per size.
- Focus stealing is blocked by Windows; the script's Alt-tap trick handles it. If clicks ever
  stop registering, take a `shot` — if it shows another app, re-run `topmost`.
- Godot's UI is NOT accessibility-exposed: never try UIA/inspection tools; pixels are the truth.
- End every session: `notopmost`, then stop the Godot process. Never leave it pinned.

## 2. Play protocol

Cover every reachable surface, screenshotting each state change. Baseline route: hero select
(each class + selection-state check) → begin run → route/node surface → a full combat →
reward/passive offers → next node → deliberately also reach death, quit+resume, and the outpost.
Two runs minimum: one played to win, one exercising failure paths.

- **Derive the interaction rules by observation** — do not assume. As of 2026-07-16 (pre-Epic-14):
  move = single-tap commit (orthogonal only, corpses block); attack = two-step tap where the armed
  preview renders NOTHING (use `dblclick` on the target); rejected commands are silent; empty/
  corpse/hero cells route to the inspect line. Epic 14 changes all of this — re-verify each run
  and note deltas from this list (they're the fix landing, or regressing).
- The bottom debug lines (Preview / Confirm / Inspect / HP / Log) are currently the only state
  readout — transcribe them from screenshots into the session notes; the inspect line
  (tap a cell) is the only way to read exact HP/occupancy.
- `burst` around every action type at least once (move, attack, kill, death, screen transition,
  reward) — the frame-diff is the animation/juice evidence for rubric lens 3.
- When input seems dead: check the Godot log for script errors, then probe systematically
  (inspect the target cell, try a known-legal move) before concluding soft-lock vs silent
  rejection — and if it IS a soft-lock, document the exact boxed-in state; that's a Blocker.

## 3. Evaluate

Apply all six rubric lenses (`references/rubric.md`). Produce, per screen: defects, comprehension
reads, feel/juice verdicts from burst-diffs, UI-craft checklist, and the genre-benchmark gaps.
Then the full absence-audit table. Severity bands: **Blocker** (cannot finish / cannot understand)
→ **Major** (comprehension or feel failure) → **Polish** (craft gap vs professional bar).

## 4. Report & dispose

Write `C:\Sealsworn\playtest-sessions\agent-playtest-<date>.md` modeled on the 2026-07-16 report
(session-record tables per run, C1–C7 scores, F-numbered findings grouped by severity, a
"what already works" section, absence-audit table, disposition paragraph). An agent session does
NOT count toward the ≥5 observed human sessions (OSG-1) and cannot score felt fun/memorability —
say so in the header.

Disposition: hand the report to the user with a recommendation — new stories via
`gds-correct-course` (epic-scale gaps), additions to an existing epic's stories, or ledger entries
in `_bmad-output/implementation-artifacts/deferred-work.md` (small items). Do not start pipelines
unasked. If an auto-gds session is active in this checkout (branch `story/*` checked out), do NOT
commit or switch branches — write the report file and leave git to the user or use a worktree.
