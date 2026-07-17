# Story 14.2: Attack Preview and Rejected-Command Feedback

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to see my armed attack (target, damage, confirm/cancel) and get a cue whenever an action is rejected,
so that combat never feels frozen or broken.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and looks unfinished (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.2 is the **second story of Band 1** (finishable + readable), landing right after 14.1's soft-lock fix. It closes two Band-1 comprehension blockers:

- **F2 — the attack preview renders nothing.** The two-step tap-commit (first tap PREVIEWS/arms, second COMMITS — FR11, UX appendix §2.3) works in the domain but has **zero on-screen presence**: no target highlight, no damage panel, no confirm/cancel affordance. The board shows the literal debug strings `"Preview: none"` and `"Confirm:false Cancel:false (mode none)"` at all times. Players experience single taps as dead and can only act by blind double-taps. This alone makes combat feel broken.
- **F3 — every rejected command is silent.** Move-into-wall, diagonal/illegal move, move-onto-corpse, attack-a-corpse — all produce no shake, no toast, no message, nothing. Indistinguishable from a frozen game; directly produced both "the game is stuck" episodes in the playtest.

**This story is PURE PRESENTATION.** No domain command, no domain event, no RNG, no save, and no `TacticalBoardViewModel` key changes. Every one of the data sources it needs already exists and is pinned: the two-step commit flow (`TacticalAttackCommitFlow`), the attack preview view model (`TacticalAttackPreview`, with weapon reach/line, expected damage, blockers, warnings), the reject reasons on `ActionResult`/`CommandBridgeResult`, and the 16-key board VM. The work is to (a) actually route the LIVE armed-attack state into the render, (b) draw it visibly, and (c) surface a non-color cue for every rejected command — all with the assertable decision logic in scene-free `RefCounted` seams. **Every pinned fingerprint stays byte-identical.**

**Root cause of F2 (load-bearing — read this before Task 1).** `tactical_board_presenter.gd::render()` (line 241) builds the board VM from the presenter's **OWN** `_commit_flow` field (line 118), which is **always empty during a live fight** — the live armed-attack state lives in the bound **session's** commit flow (`_session.commit_flow_state()`), not the presenter's. `render()` also passes **no `preview` option at all**, so the VM's `preview` slot is permanently `{}`. That is why `_preview_text` shows `"Preview: none"` and `action_availability.confirm/cancel` are permanently false. F2 is not merely "missing chrome" — the armed state never reaches the render. Fixing the source is Task 1.

## Acceptance Criteria

**AC1 — Visible armed attack preview (F2)**
Given the two-step attack commit is armed (first tap previews, second commits — FR11)
When the preview state is active
Then the board shows a visible armed-preview state — the target cell highlighted, a target + expected-damage panel (weapon reach/line, expected damage, blockers, adjacent-ranged warnings per FR10), and explicit confirm/cancel affordances (≥44px)
And the preview reads the existing attack-preview view models (**no new domain query**), a cancel leaves the run state **unmutated**, and the armed state is communicated by **shape/label/text, not color alone** (NFR9).

**AC2 — Non-color cue for every rejected command (F3)**
Given any command the domain rejects (move into a wall, diagonal/illegal move, move onto a blocker, attack an empty/illegal target)
When the rejection returns from the command bridge
Then every rejected command surfaces a visible **non-color cue** — a message line/toast naming the reason (from the `CommandBridgeResult`/`ActionResult` reject reason) plus an optional cell shake — so a rejected action is **never silent**
And the cue holds with **audio off and color removed** (NFR9), and the rejection **mutates nothing** (validate-before-mutate is unchanged).

**AC3 — Testable seams; contracts held**
Given the headless suite and pinned contracts
When this story lands
Then the preview/cue **decision logic lives in `RefCounted` seams** testable without a SceneTree, the **16-key `TacticalBoardViewModel` gate holds**, and **no domain command/RNG/save contract changes**
And every pinned fingerprint stays byte-identical.

## Tasks / Subtasks

- [ ] **Task 1 — Route the LIVE armed-attack + preview into the render (AC1; the F2 root fix)**
  - [ ] In `tactical_board_presenter.gd::render()` (line 241), when a live session is bound (`_session != null`), source the commit-flow dict from `_session.commit_flow_state()` (line 260 of `interactive_combat_session.gd`) instead of the presenter's own empty `_commit_flow.to_dictionary()`. Keep the non-session path (the presenter's own `_commit_flow`) for the non-live tap methods.
  - [ ] Pass a `preview` option to `TacticalBoardViewModel.from_domain(...)` derived from that commit flow: the commit-flow state embeds the full attack preview as its `preview` sub-dict (see `TacticalAttackCommitFlow._state_from_preview`, `tactical_attack_commit_flow.gd:157` — `"preview": preview_copy`). So `preview = commit_flow.get("preview", {})` when `mode == "attack_preview"`, else `{}`. This makes the VM's `preview`, `commit_flow`, and (derived) `action_availability` slots reflect the LIVE armed attack — the 16 top-level keys are unchanged (only their CONTENTS now populate during a live armed attack).
  - [ ] Confirm (in the seam test, Task 2) that with a live armed attack the VM's `preview.kind == "attack"`, `preview.commit_available == true`, and `action_availability.confirm.enabled == true` / `cancel.enabled == true` (`TacticalActionAvailability.from_preview`, `tactical_action_availability.gd:14`). This is the data the panel + confirm/cancel affordances read — **no new domain query** (the preview was already computed when the attack armed).

- [ ] **Task 2 — Visible armed-preview: highlight + damage panel + confirm/cancel affordances (AC1)**
  - [ ] Create the RefCounted projection seam `godot/scripts/ui/view_models/tactical_attack_preview_panel.gd` (recommended `class_name TacticalAttackPreviewPanel`). A static `from_board_vm(board_vm: Dictionary) -> Dictionary` that reads ONLY the pinned VM slots `preview` + `commit_flow` + `action_availability` and returns a pinned-key projection, e.g.: `{ is_armed: bool, target_cell: {x,y} (or null), lines: Array[String], expected_damage: int, weapon_reach: int, targeting_shape: String, blocker_state: String, warnings: Array[String], confirm_enabled: bool, cancel_enabled: bool, armed_label: String }`. It invents no new domain read, mutates nothing, draws ZERO RNG. The panel lines are built from `preview.metadata` (`tactical_attack_preview.gd:39` — `weapon_reach`, `targeting_shape`, `distance`, `line_cells`, `blocker_cells`, `blocker_state`, `blocker_ignored`, `expected_damage`/`expected_base_damage`, `effects`, `warnings`, `explanation`) and the adjacent-ranged warning (`warnings[].id == "adjacent_ranged_penalty"`, surfaced as cue `attack_preview_adjacent_warning`). `is_armed`/`armed_label` are the **non-color** channel (a text label like `"ARMED: attack <enemy> — <dmg> dmg"`, NFR9) — never color alone.
  - [ ] In the presenter, replace `_preview_text` (line 309) for the live path: render the panel projection into the `preview` region as multi-line text (target, expected damage, weapon reach/line, blocker state, adjacent-ranged warning). Keep the non-armed state honest (`"No attack armed — tap an enemy to preview"`), not the raw `"Preview: none"` debug string.
  - [ ] Draw a **target-cell highlight** on the board grid. In `_build_board_draw_ops` (line 610), after the occupant loop, when the panel reports `is_armed` append a highlight draw op at `target_cell` (reuse `_outline_op` line 878 / `_fill_op` line 861 — a distinct outline thickness/inset is a SHAPE channel, NFR9; do not rely on hue). The armed cell comes from the panel projection (which reads the VM `preview.target_cell`), NOT a re-derived query. Guard `_board_geometry == null` and an off-board/`missing` cell (safe no-op, never a fabricated cell — mirror `_cell_rect` guards line 710).
  - [ ] Add explicit **Confirm / Cancel** buttons (≥44px, text labels — mirror `_reward_button` line 1066 and the 14.1 Wait button `_build_wait_control` line 541) in the `confirm_cancel` region, shown only while an attack is armed (`is_armed`), hidden otherwise. Confirm routes to `interactive_tap_attack(_armed_attack_cell())` (re-tapping the armed cell IS the confirming commit — `_armed_attack_cell` line 696; the tap router already treats a re-tap on the armed cell as `is_commit`). Cancel routes to a NEW `interactive_cancel_attack()` seam (mirror `interactive_wait` line 524) that calls `_session.cancel_attack()` (`interactive_combat_session.gd:358` — zero mutation) + `render()`, and does **NOT** notify the shell (a cancel commits nothing). Replace the raw `_confirm_cancel_text` debug string (line 315) surfacing on the live path — the buttons are the affordance, not `"Confirm:false Cancel:false (mode none)"` (that raw dump is an F9 symptom owned by Story 14.10; here just stop emitting it while a session is bound).
  - [ ] Add `godot/tests/unit/ui/test_tactical_attack_preview_panel.gd`: an armed attack projects `is_armed: true` with the target cell, expected damage, weapon reach, blocker state, the adjacent-ranged warning when present, and `confirm_enabled/cancel_enabled: true`; an un-armed VM projects `is_armed: false`; the pinned key set is asserted (fail-loud if a slot appears/vanishes); zero mutation of the input dict; reads only pinned VM keys. Use `str()` (never eager `String(nullable)`) in assert messages (14.1 retro test-honesty note).

- [ ] **Task 3 — Non-color rejection cue for every rejected command (AC2)**
  - [ ] Create the RefCounted seam `godot/scripts/ui/view_models/tactical_rejection_feedback.gd` (recommended `class_name TacticalRejectionFeedback`). It maps a reject into a pinned-key cue, e.g.: `{ has_cue: bool, message: String, reason_id: String, source_error_code: String, cell: {x,y} (or null), shake: bool }`. Provide statics that cover the three live tap outcomes: `from_action_result(result: ActionResult, cell)` (move + wait — a rejected result carries `metadata.reason` + `error_code`; a success → `has_cue: false`) and `from_flow_result(flow_result, cell)` (attack — a `TacticalAttackCommitFlowResult`, `tactical_attack_commit_flow_result.gd`: `submitted`/`reason`/`command_result` + `flow.mode`). **Decision that MUST live in this seam:** distinguish a genuine rejection (show a cue) from a benign non-commit (no cue) — a first tap that ARMS (`reason == "preview_ready"`, `flow.mode == "attack_preview"`), a user `cancel` (`reason == "cancelled"`), and a committed action (`submitted && command_result.succeeded`) are **NOT** rejections; a cleared flow with an error reason (`flow.mode == "none"` + reason not in {preview_ready, cancelled, committed, attack}) IS.
  - [ ] Map every reject reason to a short human-readable, color-independent message via a stable table (with a **fail-safe default** so no reason is ever un-messaged — e.g. `"Action not allowed (<reason>)"`). Cover at minimum the reason vocabulary these seams emit:
    - **Move** (`move_command.gd` → `invalid_movement` + `metadata.reason`): `invalid_context`, `invalid_actor`, `dead_actor`, `wrong_phase`, and the movement-validation reasons (Story 1.6 set: blocked, occupied, out_of_bounds, beyond_budget, unseen/unreachable — read the live reasons in the move validation path and cover them). Example messages: "Blocked by a wall", "That cell is occupied", "Off the board", "Too far to move", "Not your turn".
    - **Attack** (`attack_preview_query.gd` → `invalid_attack_preview` + `metadata.reason`, lines 26–76): `same_cell`, `out_of_bounds`, `not_visible`, `missing_target`, `dead_target`, `friendly_target`, `not_aligned`, `out_of_range`, `blocked_line`, `invalid_weapon`, `dead_actor`. Example messages: "No target there", "Not in line", "Out of range", "Line of fire is blocked".
    - **Bridge/session**: `action_unavailable`, `invalid_ui_intent`, `invalid_command_context`, `unsupported_intent`, `session_not_begun`, `session_terminal`.
    - **F3-specific:** attacking a damage-killed corpse now returns `missing_target` (NOT `dead_target`) after 14.1's corpse-clear (a corpse's `occupant_id` is cleared, so `AttackPreviewQuery.preview_target_cell` reads `missing_target`). Ensure `missing_target` maps to a clear "no target" message — this is the exact F3 "attack on a corpse is silent" case.
  - [ ] Wire the cue into the three live tap seams in the presenter: `interactive_submit_move` (line 456), `interactive_tap_attack` (line 467), and `interactive_wait` (line 524) each capture their result, pass it (+ the tapped cell) to `TacticalRejectionFeedback`, store the cue as presenter state (e.g. `_last_reject_cue`), and re-render it. `_on_board_grid_tapped` (line 675) already routes move/attack/inspect through these seams — the cue is produced wherever a reject returns. The Confirm/Cancel buttons (Task 2) also feed their results through the seam (a failed confirm shows a cue; a cancel does not).
  - [ ] Surface the cue on a **distinct** read surface — do NOT clobber the `inspect` region (13.2's inspect-feedback lives there, `_inspect_base_text` line 345) or the `log_or_outcome` region (Story 14.3 owns the event log). Recommended: a transient message line composed into the `preview` region when no attack is armed, or a small toast label overlaid on the board (mirror the additive `_reward_overlay` pattern, line 931, minus the input-blocking full-rect Panel — a rejection toast must not block input). Clear the cue when the next action succeeds (so a stale reject message never lingers as truth).
  - [ ] Optional cell shake (AC2 "plus an optional cell shake"): a minimal transient nudge of the rejected cell's draw is acceptable but is ADDITIVE — the **message line is the required accessible channel** (NFR9: the cue must hold with color removed AND audio off). Do NOT make the shake the only cue. Do NOT build the move/hit/death tween-flash animation system — that is Story 14.3.
  - [ ] Add `godot/tests/unit/ui/test_tactical_rejection_feedback.gd`: a rejected move (`invalid_movement`/`blocked`) → `has_cue: true` with a non-empty message + the cell; a successful move → `has_cue: false`; a first-tap arm (`preview_ready`) and a `cancel` → `has_cue: false`; a cleared-with-error attack flow (e.g. `out_of_range`, `missing_target`) → `has_cue: true`; the corpse `missing_target` case → a "no target" message; an unmapped reason → the fail-safe default (never empty); the pinned key set asserted; zero mutation. Use `str()` in assert messages, not eager `String(nullable)`.

- [ ] **Task 4 — Contracts held + suite green (AC3)**
  - [ ] Confirm the **16-key `TacticalBoardViewModel` gate** holds (`test_tactical_board_view_model.gd:322`, `_sorted_keys(data).size() == 16`) — the armed-preview panel and rejection cue are SEPARATE read surfaces composed by the presenter (like the 14.1 Wait control, the 11.4 affinity read, and the 13.2 reward overlay), **not** new board-VM keys. `preview`/`commit_flow`/`action_availability` are EXISTING keys; only their contents populate during a live armed attack.
  - [ ] Confirm **no domain/RNG/save change**: no new command, no new `DomainEvent` (enum stays 43, `HERO_WAITED` at 42), `RngStreamSet.required_streams()` stays 7, this story draws ZERO RNG, the 23-key `RunSnapshot` gate stays 23, `SCHEMA_VERSION == 1`, the in-node fight stays ephemeral. Scene wiring verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail — **no SceneTree presenter test**.
  - [ ] Run the FULL headless suite (mandatory command below). Grep the raw output for `SCRIPT ERROR|Parse Error|^FAIL` (the false-PASS guard): exactly the **6 documented stderr negatives** (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1), ZERO new. Baseline is **196 PASS** (195 + 14.1's `test_wait_command.gd`); this story adds two seam tests → expect 198 PASS. Confirm every generator/route/finale/combat seed-regression fingerprint is byte-identical (this story touches only `scripts/ui/` presentation — no fingerprint can move). `git diff --check` clean.

## Dev Notes

### The exact data flow (what already exists — DO NOT rebuild)

The two-step attack UX and its preview are fully implemented and pinned; 14.2 only makes them **visible** and adds a reject cue. The chain during a live fight:

1. First tap on an enemy → `_on_board_grid_tapped` (presenter:675) → tap router returns `INTENT_ATTACK` `arm` → `interactive_tap_attack(cell)` (presenter:467) → `_session.tap_attack(cell)` (`interactive_combat_session.gd:326`) → `_commit_flow.tap_attack_target(...)` (`tactical_attack_commit_flow.gd:23`) → `_start_attack_preview` computes `TacticalAttackPreview.from_query(...)` (`tactical_attack_preview.gd:20`, which wraps `AttackPreviewQuery.preview_target_cell` — the "no new domain query" source) and stores the armed state (mode `attack_preview`, the full preview dict with metadata).
2. `render()` re-runs. **Today it ignores the session's commit flow** — Task 1 fixes that so the VM's `preview`/`commit_flow`/`action_availability` slots reflect the armed attack.
3. Second tap on the SAME enemy (or the new Confirm button) → `_matches_pending_attack` true → `confirm_attack` executes the `AttackCommand` through the bridge → the session runs the enemy phase.

The armed preview carries EVERYTHING AC1's panel needs, already computed: `preview.metadata.weapon_reach`, `.targeting_shape`, `.line_cells`, `.blocker_cells`, `.blocker_state`, `.blocker_ignored`, `.expected_damage`/`.expected_base_damage`, `.warnings` (incl. `adjacent_ranged_penalty`), `.explanation`; and `preview.target_cell`, `.target_entity_id`, `.commit_available`. The reject reasons for AC2 are already on `ActionResult.metadata.reason` / `CommandBridgeResult.reason` — the seam maps them to player text.

### Where the two RefCounted seams sit (AC3)

Both are scene-free `RefCounted` view models under `godot/scripts/ui/view_models/`, mirroring the established 13.x pattern (`TacticalBoardTapRouter`, `RewardHudViewModel`, `TacticalActionAvailability`): a static projector, a pinned-key output dict, zero mutation, zero RNG, reads-only. The presenter is a thin `Control` that calls the seam and draws its output; the DECISION (what to draw, what message, armed-vs-not, reject-vs-benign) lives in the seam and is unit-tested. This is the ratified "assertable logic in `RefCounted` seams; scenes verified by construction + the compile guardrail" stance — **no SceneTree presenter test**.

### Files to touch (current state → change)

| File | Current state | Change |
|---|---|---|
| `godot/scripts/ui/presenters/tactical_board_presenter.gd` | `render()` builds the VM from the presenter's OWN empty `_commit_flow`, passes no `preview`; `_preview_text`/`_confirm_cancel_text` emit raw debug strings; live tap seams discard rejects | Source commit-flow + preview from the bound session; project + draw the armed preview (highlight + panel + Confirm/Cancel buttons); add `interactive_cancel_attack()`; capture + surface the rejection cue |
| `godot/scripts/ui/view_models/tactical_attack_preview_panel.gd` | does not exist | NEW RefCounted seam: board-VM `preview`+`commit_flow`+`action_availability` → armed-preview panel projection (pinned keys) |
| `godot/scripts/ui/view_models/tactical_rejection_feedback.gd` | does not exist | NEW RefCounted seam: an ActionResult / flow-result reject → non-color cue (pinned keys, reason→message table, reject-vs-benign decision) |

Add/extend tests: `test_tactical_attack_preview_panel.gd` (NEW), `test_tactical_rejection_feedback.gd` (NEW), and confirm `test_tactical_board_view_model.gd` (16-key gate) + `test_run_flow_scenes_load.gd` (compile guardrail) stay green. Tests live under `res://tests/unit/ui`.

### THE CORRECT PRESENTER FILE (Epic-14 retro precision point — do not repeat 14.1's mislabel)

The live tactical board surface is **`godot/scripts/ui/presenters/tactical_board_presenter.gd`** — the scene-root script of `godot/scenes/game/tactical_board.tscn`, which `gameplay_shell_presenter.gd` instances and drives via `bind_interactive_session(...)` + `render()`. The 14.1 story's "Files to touch" table named the WRONG files (`gameplay_shell_presenter.gd` / `tactical_board_grid.gd` / `gameplay_shell.tscn`); the 14.1 dev correctly landed the Wait control + corpse decal in `tactical_board_presenter.gd`. **14.2's armed-preview highlight, damage panel, Confirm/Cancel buttons, and rejection cue all belong in `tactical_board_presenter.gd`** — the same file the 14.1 Wait control and 13.2 reward overlay live in. Do not add a parallel presenter.

### Anti-patterns to avoid (this story specifically)

- **Do NOT read the armed state from the presenter's own `_commit_flow`** during a live fight — it is always empty; the live state is `_session.commit_flow_state()`. This is the F2 root; sourcing the wrong flow reproduces the invisible-preview bug.
- **Do NOT add a new domain query** for the panel (AC1: "no new domain query"). The preview was already computed at arm time and is in `commit_flow.preview.metadata`. Do not call `AttackPreviewQuery`/`TacticalAttackPreview` again from the presenter.
- **Do NOT add a 17th top-level `TacticalBoardViewModel` key** for the panel or the cue. They are SEPARATE presenter-composed read surfaces (like the Wait control / affinity read / reward overlay). The 16-key gate must stay 16.
- **Do NOT change any command/event/RNG/save contract.** No new command, no new event (enum stays 43), zero RNG, 23-key `RunSnapshot` gate stays 23, `SCHEMA_VERSION == 1`. A cancel is `_session.cancel_attack()` — zero mutation.
- **Do NOT clobber the inspect region** (13.2's tapped-cell facts, `_inspect_base_text`) **or the log_or_outcome region** (Story 14.3's event log). The rejection cue needs its own transient surface; a cue toast must NOT block board input (unlike the reward overlay's input-capturing full-rect Panel).
- **Do NOT build the event log or the move/hit/death tween-flash animation** — that is Story 14.3. The optional cell shake here is a minimal reject nudge only, and the message line (not the shake) is the required NFR9 channel.
- **Do NOT try to fix the whole debug HUD** (the `_status_text` pipe-dump, snake_case cue ids), add **range highlights**, or a **turn indicator** — those are F9/F10, owned by Story 14.10. 14.2's scope is exactly: visible ARMED-attack preview (highlight + damage panel + confirm/cancel) and a reject cue. Stopping the raw `Preview:`/`Confirm:false...` strings from surfacing on the live path is in-scope (they are the F2 symptom); the broader HUD restyle is not.
- **Do NOT use eager `String(nullable)` in assert messages** (14.1 retro: it crashes on a null read and silently masks the real failure). Use `str(...)`.
- **Do NOT add a difficulty knob** — difficulty is a hard non-goal; this story changes no enemy stat / HP / damage / reward / RNG / run-length number.

### Epic-14 constraints inherited (from the epic-14 retro notes + the sprint change)

- **This story re-pins NOTHING.** 14.1 is the only Epic-14 story that may intentionally re-pin a fingerprint (its justified combat-replay re-pin). 14.2 is presentation-only over `scripts/ui/` — every generator/route/finale/combat seed-regression fingerprint is byte-identical, and no VM/RNG/save gate moves. A moved fingerprint here is a bug.
- **Corpse targeting is `missing_target`, not `dead_target`** (14.1 as-built): a damage-killed corpse has its `occupant_id` cleared, so `AttackPreviewQuery.preview_target_cell` returns `missing_target`. The reject-cue table must give `missing_target` a clear "no target" message — this is the exact F3 "attacking a corpse is silent" defect. (A setup-PLACED dead entity still returns `dead_target`; cover both.)
- **Keep the false-PASS grep guard standing** (Epic-13 retro P3): grep the raw runner output for `SCRIPT ERROR|Parse Error|^FAIL`; never trust the summary PASS line alone. Exactly six documented stderr negatives are expected; ZERO new.
- **Art-import discipline** (13.1): 14.2 adds no new art (the highlight/toast/shake are drawn from shapes/labels). If any texture is introduced, import it and commit its `*.png.import` sidecar in the same change, and load it via a guarded `load()` (never `preload`). Retain committed `*.gd.uid` sidecars.

### Deferred-work ledger overlaps (checked — none re-opened)

- The **inspect-tap no-feedback** defer was RESOLVED by Story 13.2 (`interactive_inspect` surfaces the tapped cell's facts in the inspect region). This is why the rejection cue must use a DIFFERENT surface — the inspect region is occupied. Informational, not re-opened.
- The four Epic-14-adopted ledger items (reward-overlay geometry → 14.11; passive-confirm `display_name` → 14.11; full-backpack escape hatch → 14.7; run-summary outcome label/F-2 → 14.5) do **not** overlap 14.2 — leave them for their owners.
- The `_inspect_facts_from` untested-transform defer (13.2 R2) is explicitly NOT adopted by Epic 14 and is out of scope here.

## Project Structure Notes

- Both new seams → `godot/scripts/ui/view_models/` (with `tactical_board_tap_router.gd`, `tactical_attack_preview.gd`, `tactical_action_availability.gd`). Presenter change → `godot/scripts/ui/presenters/tactical_board_presenter.gd`. Tests → `godot/tests/unit/ui/`.
- Assertable decision logic (the panel projection, the reject-vs-benign + reason→message mapping) stays in the scene-free `RefCounted` seams. Scene wiring (the highlight draw op, the Confirm/Cancel + toast controls) is verified by construction + `test_run_flow_scenes_load.gd` — no SceneTree presenter test.
- No new autoload. `scripts/rules/conditions/` stays empty; `scripts/rules/operations/` stays one file.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook; Epic-13 as-built rollup + 14.1):

- **Domain owns tactical truth; presentation mirrors it.** Scenes/`Control`/audio/VFX own no authoritative state. Presentation observes domain and submits commands through the command bridge; the board VM projects domain state (never owns it). 14.2 is pure presentation over pinned reads.
- **Command idiom (unchanged here):** gameplay actions validate-before-mutate and return `ActionResult` with zero partial state on reject. 14.2 adds NO command; it only READS the reject reasons the existing commands already return, and a cancel is zero-mutation.
- **Named RNG only:** `RngStreamSet.required_streams()` == 7. This story draws ZERO RNG (no new stream, no new draw). Any optional cosmetic shake must not draw gameplay RNG (cosmetic-only, cannot affect outcomes).
- **Save gates:** the 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; the in-node fight is ephemeral. No save change.
- **`TacticalBoardViewModel.to_dictionary()` has an EXACT 16-key contract** pinned by `test_tactical_board_view_model.gd:322`. 14.2 adds NO key — the armed-preview panel + rejection cue are separate presenter-composed surfaces; `preview`/`commit_flow`/`action_availability` are existing keys.
- **Difficulty is a hard non-goal** — no knob that scales enemy stats/HP/damage/rewards/RNG/run length.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.2 touches only `scripts/ui/`; no fingerprint can move).
- **Assertable logic lives in scene-free `RefCounted` seams** (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload. Headless suite stays green (196 PASS baseline after 14.1; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).
- **NFR9 (accessibility):** every cue is color-independent and audio-absent-equivalent (shape/label/text). The armed-preview state carries a text label (not just a hue); the rejection cue's message line is the required accessible channel (the shake is additive only).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (it resolves as `C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard on the raw output. The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` (Story 14.2 ACs, body lines 3000–3021; Epic List entry lines 521–527; Band-1 demarcation line 2971).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` §1 (F2/F3), §4.1 (14.2 finding→scope: "Visible armed-preview state ... + every rejected command gets a non-color cue"; "Presentation over the existing two-step commit + `CommandBridgeResult` reject reasons; no domain/VM/RNG change; fingerprints byte-identical"), §5 (standing constraints).
- `playtest-sessions/agent-playtest-2026-07-16.md` F2 (lines 72–76, "Preview state renders nothing"), F3 (lines 77–79, "every rejected command is silent"), F8/F9 boundary (lines 97–103 — F9 debug HUD is Story 14.10).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — the "live board surface is `tactical_board_presenter.gd`, not `gameplay_shell_presenter.gd`/`tactical_board_grid.gd`" precision point; the corpse `missing_target` consequence; the `String(nullable)`-in-assert masking risk.
- `_bmad-output/implementation-artifacts/14-1-corpse-clearing-and-wait-turn.md` — the ratified Epic-14 story shape; the Wait control (`_build_wait_control`) + `interactive_wait` seam pattern to mirror for the Cancel button/seam; corpse-clear → `missing_target`.
- `_bmad-output/implementation-artifacts/deferred-work.md` — inspect-tap feedback RESOLVED-by-13.2 (why the reject cue needs a separate surface); the four Epic-14-adopted items are other stories' scope.
- Source files (read before implementing): `tactical_board_presenter.gd` (`render()` 241, `_preview_text` 309, `_confirm_cancel_text` 315, `_build_board_draw_ops` 610, `_on_board_grid_tapped` 675, `_armed_attack_cell` 696, `interactive_submit_move` 456, `interactive_tap_attack` 467, `interactive_wait` 524, `_build_wait_control` 541, `_reward_button` 1066, `_fill_op`/`_outline_op` 861/878); `tactical_board_view_model.gd` (16-key `to_dictionary` 33, `_preview_from_options` 126, `_action_availability_from_options` 165); `tactical_attack_commit_flow.gd` (`to_dictionary` 19, `_state_from_preview` 157, `cancel` 76); `tactical_attack_preview.gd` (`from_query` metadata 39, `cue_ids` 79); `tactical_action_availability.gd` (`from_preview` 14); `tactical_command_bridge.gd` (`execute_intent` 38, `_action_unavailable` 318); `command_bridge_result.gd` (reason/error_code/metadata); `interactive_combat_session.gd` (`commit_flow_state` 260, `submit_move` 270, `tap_attack` 326, `submit_wait` 302, `cancel_attack` 358); `tactical_attack_commit_flow_result.gd` (submitted/reason/command_result/flow); `move_command.gd` (reject reasons); `attack_preview_query.gd` (reject reasons 26–76); `tactical_board_tap_router.gd` (the RefCounted seam pattern to mirror); `test_tactical_board_view_model.gd:322` (16-key gate); `test_run_flow_scenes_load.gd` (compile guardrail).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
