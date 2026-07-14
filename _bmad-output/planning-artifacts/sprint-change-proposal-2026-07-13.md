# Sprint Change Proposal — 2026-07-13: Epic 13 "Human-Playable Board" (post-MVP-close playability gap)

## 1. Issue Summary

The first human desktop playtest after the Epic 10 close (2026-07-13, investigation:
`_bmad-output/implementation-artifacts/investigations/desktop-playtest-black-board-investigation.md`) found that
the hands-on combat loop is **not human-playable**: the tactical board presenter renders the entire board region
as one summary text label (`tactical_board_presenter.gd:139` — no tiles, units, grid, fog, or affinity visuals),
and **no input path exists** (zero `_gui_input`/`Button` handlers in the board or shell presenters; every tap
method takes an already-resolved `Vector2i` cell only tests can supply). A cosmetic engine error also fires on
every fresh run (`route_map_presenter.gd:32` — a diagnostics probe after a synchronous mid-`_ready` scene change).

The domain layer is complete and green: `InteractiveCombatSession`, the command bridge, the two-step commit flow,
and the class-loadout winnability proofs all shipped in Epic 12 and are regression-enforced (suite 191 PASS).
The missing piece is purely presentation/input.

## 2. Impact Analysis

- **Story 12.1 AC tension.** 12.1's AC1 reads "the live board renders on-screen with hero, enemies, terrain, fog,
  and affinity treatments" and its AC2 has "the player taps a reachable tile". As shipped (Approved, merged), the
  render is a text projection of the view model and the pixel→cell hit-test was explicitly deferred by the 12-1
  review (`[Review][Defer]` Low: "a later on-device input story owns the pixel→cell hit-test"). The ACs were
  satisfied at the metadata/projection + programmatic-seam level, not the visual/human-input level.
- **10-6 MVP readiness gate.** "10/10 loop steps present" holds at the level the gate measured (domain seams +
  integration tests, rows 6/7 explicitly qualified integration-proven). The practical consequence — a human cannot
  drive a fight — was under-weighted; the gate verdict `READY_WITH_GATES` is unchanged but the human-playtest
  backlog is harder-blocked than the gap ledger implied.
- **Epic 10 retro §7 backlog.** OSG-1..4 (≥5 observed human sessions) and ASG-1/2 (human-eyes accessibility) are
  **blocked** until this lands. AG-1 (physical-display readability) is likewise not meaningfully testable.
- **Adjacent ledgered gap (same wall, one screen later).** Loop steps 6/7 (collect rewards / make passive choices)
  also have no live HUD wiring ("a later HUD story" per the 10-6 gate §3.3 + AG ledger) — a human who could play a
  fight would hit the same wall at the first reward. In-scope for the same epic.
- **No GDD / narrative / architecture change.** The architecture already prescribes exactly this layering
  (presentation observes domain); the work is additive presentation. FR coverage map unchanged (FR3/4/8-12 live
  delivery remains Epic 12's assignment; Epic 13 completes their *human-facing* surface).

## 3. Recommended Approach

**Direct Adjustment** — add a new **Epic 13: Human-Playable Board** to `epics.md` with two stories, and register
it in `sprint-status.yaml` per the 2026-07-04/07 sprint-change precedents (file order = execution order; no
renumbering):

- **Story 13.1 — Live board visual render and pixel→cell tap input.** Draw the board region as a real tile grid
  from `TacticalBoardViewModel` (cells/occupants/visibility/affinity treatments — the approved board art +
  affinity treatments already exist under `godot/assets/`), hit-test clicks/taps to `Vector2i`, route them into
  the existing `interactive_submit_move`/`interactive_tap_attack`/`interactive_inspect` seams (≥44px targets,
  two-step commit per UX appendix §14). Fold in the one-line `route_map_presenter.gd:32` out-of-tree diagnostics
  guard. Resolves the 12-1 `[Review][Defer]` hit-test item.
- **Story 13.2 — Live reward and passive-choice HUD wiring.** Wire the existing reward-offer/passive-modal view
  models (`PassiveRewardModalViewModel`, `PassiveRewardCommitFlow`, reward offer contracts — all Epic-6 domain
  contracts, integration-proven) into human-clickable UI in the shell, closing the 10-6 gate §3.3 rows-6/7
  qualifier and the "later HUD story" AG item.

Effort: 2 stories, standard auto-gds pipeline. Risk: low — additive presentation over pinned contracts; the
byte-identical hands-off driver and all fingerprints must hold (standard Epic-12 invariants). Timeline: unblocks
the retro §7 human-playtest track immediately after 13.1.

## 4. Detailed Change Proposals

1. **`epics.md` — Epic List:** add `### Epic 13: Human-Playable Board` entry after Epic 12 (goal, FR note,
   implementation/sequencing note referencing this proposal).
2. **`epics.md` — body:** append `## Epic 13` section with Stories 13.1 and 13.2 (full ACs in the document).
3. **`sprint-status.yaml`:** append, after `epic-12-retrospective: done`, a SPRINT CHANGE comment block referencing
   this proposal plus:
   `epic-13: backlog`, `13-1-live-board-render-and-tap-input: backlog`,
   `13-2-live-reward-and-passive-choice-hud: backlog`, `epic-13-retrospective: optional`.
4. **No change** to GDD, narrative, architecture, UX appendix (already specifies §14 tap contract), or FR map.

## 5. Implementation Handoff

- **Scope: Moderate** (backlog addition, no replan). Handoff: the auto-gds pipeline picks up
  `13-1-live-board-render-and-tap-input` as the next actionable story (`backlog → create-story`).
- **Success criteria:** a human can launch the desktop build, fight the opening combat node with mouse/taps to a
  win or death, collect the reward, and make a passive choice — with the headless suite still 191+ PASS and every
  pinned fingerprint byte-identical.
