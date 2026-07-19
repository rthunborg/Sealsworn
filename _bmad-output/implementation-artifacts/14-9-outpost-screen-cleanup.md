---
baseline_commit: 5c2bf1c51fbc013d19a362fd3db5d9f206307edc
---

# Story 14.9: Outpost Screen Cleanup

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the outpost to show real information cleanly — no debug-marker prefixes, no dead "(coming soon)" copy, honest tallies,
so that returning from a run feels finished, not like a debug dump.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and **does not look intentional** (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.9 is the **SECOND story of Band 2** ("looks intentional" — presentation), landing after 14.8's hero-select rebuild.

It closes finding **F14** (`sprint-change-proposal-2026-07-16.md` line 26-27, scope row line 144):

> **F14 — the Outpost renders literal `[#]`/`[!]` markers, four "(coming soon)" dead-text rows, and "not yet tallied" placeholder copy.** Scope row: "No raw `[#]`/`[!]` markers, honest **deferred** rows (not dead "(coming soon)" text), **real tallies** incl. oath-shards-earned-this-run | Presentation over the existing `OutpostViewModel`/`OutpostRenderView`; the pinned `RunSummary` contract is unchanged (earned count a separate deterministic `MetaAwardRules` read); no domain change."

**This story is PRESENTATION-ONLY over shipped, pinned view-model contracts — it makes NO domain / command / event / RNG / save change and re-pins NOTHING.** It is the same ratified Band-2 shape as 14.8 / 14.5 / 14.3 / 14.2: additive presentation reading pinned VMs, the assertable render decisions in the scene-free `RefCounted` `OutpostRenderView` seam, the outpost scene verified by construction + the compile guardrail. There is **no vetoable D-decision unique to 14.9** (D1/D2 are 14.1, D3/D6 are 14.5, D4 is 14.4, D5 is 14.7).

### ⭐ THE CRUX — 14.9 INHERITS 14.5's summary tallies; it does NOT re-implement them (read before Task 1)

**Story 14.5 already delivered the honest run-summary tallies on the same outpost-embedded surface.** 14.5 rewrote `outpost_presenter._render_run_summary()` and added four render-decision methods to `OutpostRenderView`:

- `summary_outcome_label()` — Victory/Fallen keyed off the summary `phase` (D6) — **DONE by 14.5.**
- `summary_nodes_cleared()` — the nodes-cleared tally — **DONE by 14.5.**
- `summary_seed()` — the run seed — **DONE by 14.5.**
- `run_oath_shards_earned()` — the **oath-shards-earned-this-run count** via the deterministic `MetaAwardRules` const read (0 for a death / manual-seed run) — **DONE by 14.5**, replacing the "not yet tallied" placeholder.

The 14.5 story file recorded this overlap explicitly (`14-5-run-end-beat-and-run-summary-screen.md` line 117): *"14-5 (Band 1) delivers the honest earned count NOW (replacing 'not yet tallied'), and 14-9 (Band 2) INHERITS it — 14-9's outpost-cleanup scope is then the raw `[#]`/`[!]` marker removal, the named-space 'coming later' affordances, and the notable-loot tally, NOT re-doing the earned count."* This matches the epic-14 retro note (`retro-notes/epic-14.md`, §14-5): *"14-9 (Band 2) INHERITS it — confirm at the epic retro that 14-9 does not re-implement it."*

**So AC1's phrase "the tallies are real — nodes cleared, notable loot, and the oath-shards-earned-this-run count ... replacing 'not yet tallied'" is 90% already shipped.** The dev agent's job is to **VERIFY those tallies still render** (they do — `_render_run_summary` at `outpost_presenter.gd:160-198`, `outpost_render_view.gd:190-230`) and **NOT re-implement them.** The "not yet tallied" literal is already gone from the render. **Do NOT re-derive the earned count, re-add a formula, or touch `MetaAwardRules`.** The 14.5 `[Review][Decision]` ratified keeping the earned-count computation in the render seam referencing the `MetaAwardRules` public consts — that ratification stands; do not reopen it.

### The genuinely NEW 14.9 work (the delta over 14.5)

1. **Remove the raw ASCII debug-marker prefixes** the presenter still emits (F14's `[#]`/`[!]` — and the sibling `[?]`/`[V]`/`[X]`/`[x]`), replacing each with an honest human-readable label/affordance that KEEPS a non-color channel (NFR9 — never fall back to color-only).
2. **The four "(coming soon)" dead-text named-space rows → honest labeled "coming later" affordances** (driven by the seam's existing `is_deferred`/`display_name`).
3. **The notable-loot tally** — render `run_summary.run_scoped.notable_loot` as its own honest row (it is legitimately **empty in v0** — the run-level event store is deferred; render it honestly empty, never fabricated, never a placeholder).

### The load-bearing architecture reality (read before Task 1)

The outpost surface is **`godot/scripts/ui/presenters/outpost_presenter.gd`** (a `Control` whose layout is **code-built** in `_ready → _build_layout → _render_outpost`) reading the **`godot/scripts/ui/view_models/outpost_render_view.gd`** render-decision seam (a pure-read `RefCounted` projection of `OutpostViewModel.to_dictionary()`). This is the **same surface 14.5 touched** (the "wrong files to touch" precision from the 14.1 retro applied to the outpost: it is `outpost_presenter.gd` + `outpost_render_view.gd`, NOT `run_end_presenter.gd` — which is a non-terminal dead-end since 11.5). There is **no separate `.tscn` node tree to edit** — the outpost `.tscn` is a thin `Control`+script (like hero-select); the cleanup lives almost entirely in the presenter script + a couple of seam label constants.

**14.5 also rerouted "Descend Again" through hero-select and DELETED the outpost's dead start/seed logic** (`RunSeedSource`/`_new_run_entropy`/`controller.start`). So the outpost's Descend button is now a **pure navigation action** (`_on_descend_pressed` → `clear_run_flow()` + `SceneManager.go_to_stage("hero_select")`, `outpost_presenter.gd:318-332`). **14.9 must NOT touch `_on_descend_pressed`** — it is the single-live-seed-source reroute; leave it byte-identical.

## Acceptance Criteria

**AC1 — No debug markers, honest deferred rows, real tallies (F14; FR68)**
Given the outpost renders after a run
When it draws its panels
Then **no raw `[#]`/`[!]` marker prefixes** are shown to the player (nor the sibling `[?]`/`[V]`/`[X]`/`[x]` ASCII glyphs the presenter emits) — each is replaced by an honest human-readable label/affordance that still carries a **non-color channel** (NFR9); the **deferred named spaces** render as honest labeled **"coming later" affordances** (the `OutpostViewModel.NAMED_SPACES` deferred markers, via the seam's `is_deferred`/`display_name`) rather than the dead "(coming soon)" text; and the tallies are real — **nodes cleared** (`summary_nodes_cleared()` — INHERITED from 14.5), **notable loot** (rendered honestly from `run_scoped.notable_loot` — empty in v0, never fabricated), and the **oath-shards-earned-this-run count** (`run_oath_shards_earned()` — INHERITED from 14.5, the deterministic `MetaAwardRules` read) replacing "not yet tallied"
And the pinned `RunSummary` / 8.2 contract is **unchanged** (the earned count is a separate deterministic read, not a summary-key change; the notable-loot read is `run_scoped.notable_loot` verbatim, no new field, no event store).

**AC2 — Meta surfaces read the seam, all state non-color, recovery renders honestly (NFR9)**
Given the outpost meta surfaces
When they render
Then the **awarded oath-shard total** and any **spend/unlock affordances** read the existing `OutpostRenderView` render-decision seam (`awarded_oath_shards()` / `class_unlock_options()` / `can_spend_unlock()` / `has_affordable_unlock()` — already shipped by 11.5/11.6), with all state communicated by **text/label**, not color alone (NFR9)
And a **profile-load / profile-write recovery state renders honestly without a crash** (the existing `for_recovery` modes — load-failure fresh-fallback vs write-failure real-totals-behind-retry, each with its distinct non-color text note and the write-failure retry affordance).

**AC3 — Pinned-contract posture: no domain change, decisions on the seam, verified by construction**
Given the pinned contracts
When this story lands
Then **no domain / save / RNG contract changes**, the outpost render **decisions stay on the pinned-key `RefCounted` seam** (`OutpostRenderView`, unit-tested — **no SceneTree test**; the scene is verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail), and **every pinned fingerprint stays byte-identical** (the 23-key `RunSnapshot` gate stays 23, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams unchanged, no new event/enum value, no new autoload, no new RNG draw site)
And **14.9 re-pins NOTHING.**

## Tasks / Subtasks

- [x] **Task 1 — Strip the raw ASCII debug markers from the outpost presenter (AC1, AC2)**
  - [x] Grep `godot/scripts/ui/presenters/outpost_presenter.gd` for the literal marker strings and replace EVERY one with an honest label/affordance that keeps a non-color channel (NFR9 — text/label, never color-only). The exact sites today:
    - `_render_recovery_banner()` (line 132) — `"[!]"` (write-failure) / `"[?]"` (load-failure) icon prefix on the recovery note. The two `recovery_note()` texts already differ per mode (a non-color channel), so drop the ASCII glyph and render the note as a clean labeled banner (keep a short word-marker like `"Recovery:"`/`"Could not save:"` if a leading cue is wanted — a WORD, not `[!]`).
    - `_render_warning_banner()` (line 156) — `"[!] %s"` on the manual-seed line. The `manual_seed_warning_line()` text ("Manual seed — no meta progression earned.") already carries it; drop `[!]` (keep a word cue like `"Note:"` if desired).
    - `_render_run_summary()` (line 171) — the `"[V]"`/`"[X]"` outcome glyph. The label already reads `"Outcome: Victory"`/`"Outcome: Fallen"` (a non-color word channel — INHERITED from 14.5); drop the ASCII glyph. **Do NOT touch the earned-count / nodes-cleared / seed lines below it (14.5 shipped them).**
    - `_render_named_spaces()` (lines 232-233) — the `"[#] %s"` prefix AND the `"  (coming soon)"` suffix (Task 2 owns the "coming later" affordance).
    - `_render_spend_menu()` (lines 278, 280, 293) — `"[x] %s — Unlocked"`, `"[#] %s — Cost: %d Oath Shards"`, `"[!] %s"` (insufficient). The words "Unlocked" / "Cost: N Oath Shards" / the insufficient note already carry the state (non-color); drop the ASCII prefixes.
  - [x] After the sweep, re-grep the presenter to confirm **zero** remaining `[#]` / `[!]` / `[?]` / `[V]` / `[X]` / `[x]` render strings (comments may reference them historically — only the rendered `Label.text` / `Button.text` matter).
  - [x] **Every state that today reads via an ASCII glyph MUST retain a non-color channel** — the descriptive text label IS that channel (project-context §14 / NFR9). Never delete a marker and leave color as the only differentiator. Use `str(...)`, never eager `String(nullable)`, in any assert/log message (14.1 retro).

- [x] **Task 2 — Honest "coming later" named-space affordances (AC1)**
  - [x] Rewrite `outpost_presenter._render_named_spaces()` (lines 227-234) so each of the four `NAMED_SPACES` tiles renders its `display_name` + an honest **"Coming later"** status affordance (a legible labeled row that reads as intentional — e.g. a disabled-looking `Label`/row with a "Coming later" text badge), NOT the `[#] Name  (coming soon)` string. Drive it off the seam's existing `named_space_markers()` entries (`display_name`, `status`, `is_deferred`).
  - [x] Recommended: add a seam label const so the decision is testable + centralized (mirroring `SUMMARY_OUTCOME_VICTORY` / `INSUFFICIENT_SHARDS_NOTE`): e.g. `OutpostRenderView.NAMED_SPACE_DEFERRED_LABEL := "Coming later"`. The presenter maps `is_deferred == true` → that label. (A non-deferred space, none exist in v0, would render no "coming later" affordance.)
  - [x] **Preserve the existing 11.6 semantics — do NOT try to "resolve" the apparent duplication.** All four spaces are `status: "deferred"` DATA (`outpost_view_model.gd:135-160`), even though `seal_table` ALSO has a live spend section (`_render_spend_menu`) and `descent_stair` maps to the live "Descend Again" button. The named-space TILES are the **deferred OVERVIEW registry** (the 11.6 ratified `[Decision]`, `outpost_presenter.gd:116-119`); the realized surfaces (spend menu, Descend button) are **separate sections** and stay as-is. Do NOT re-model which spaces are deferred (that is a data/domain question, out of scope), and do NOT merge/hide the overview tiles. Render each tile's honest affordance from its existing `is_deferred` status.

- [x] **Task 3 — The notable-loot honest tally (AC1)**
  - [x] Split the notable-loot tally out of 14.5's combined pending line (`outpost_presenter.gd:196-198`: `"Passives spent/destroyed & notable loot: — none recorded yet —"`). Render **notable loot** as its own honest row reading the REAL summary field `run_summary.run_scoped.notable_loot` (`RunSummary.RUN_SCOPED_KEYS` includes `notable_loot`, `run_summary.gd:104`). In v0 the live bridge builds `RunSummary.build(run, [])` with an **empty events list**, so `notable_loot` is legitimately **empty** — render it honestly (e.g. `"Notable loot: — none —"` when empty; the entry names when present). Keep the passives-consumed/destroyed lists shown honestly empty/pending too (they share the deferred run-level event store).
  - [x] Recommended: add a pure-read seam accessor `OutpostRenderView.summary_notable_loot() -> Array` (reads `run_summary.run_scoped.notable_loot`, `[]` when the summary is absent — fail-closed) so the decision is on the seam + testable (the 14.3 "seams expose only what the presenter consumes" posture — surface only what `_render_run_summary` draws). The presenter renders the count/names honestly.
  - [x] **Do NOT build the run-level event store** (the deferred save-shape story that would populate `notable_loot` / `passives_consumed` / `passives_destroyed` / `outcome_or_cause`). Do NOT read a presentation/combat log as summary source truth (8.2 AC2 forbids it). Notable loot stays honest-empty until that store lands. This is the same posture 14.5 took for the pending lists.

- [x] **Task 4 — Verify/harden the meta-readout + spend + recovery surfaces (AC2) — do NOT rebuild them**
  - [x] Confirm the awarded oath-shard total (`_render_meta_readout`, `awarded_oath_shards()` → `profile.oath_shards`) and the spend menu (`_render_spend_menu`, `class_unlock_options()` / `can_spend_unlock()`) render from the seam, each state carried by a non-color text channel after the Task-1 marker sweep. Also fix the now-stale comment at `outpost_presenter.gd:147` ("shown as an honest 'not yet tallied' note in the summary") — the summary no longer renders "not yet tallied" (14.5 replaced it with the real earned count); update or drop the comment so it does not mislead.
  - [x] Confirm the recovery banner (`_render_recovery_banner`, `recovery_mode()` / `recovery_note()` / `has_retry_affordance()`) still renders both modes honestly without a crash after the marker sweep: load-failure fresh-fallback (has_profile false, no retry) vs write-failure real-totals-behind-retry (has_profile true, real oath_shards, a ≥44px retry affordance). This is already unit-tested (`test_outpost_render_view.gd:96-137`); Task 1 only changes the icon prefix, not the branch.
  - [x] Keep the reveal-beat render (`_render_reveal_beat`, lines 205-224 — no ASCII marker; the Dismiss is a pure `card.queue_free` no-op) and the Descend affordance (`_render_descend_affordance` + `_on_descend_pressed`, the 14.5 hero-select reroute) **byte-identical** — they are out of 14.9's marker scope. Do NOT touch `_on_descend_pressed` (the single live seed/class start reroute since 14.5's D3).

- [x] **Task 5 — Render-decision test + determinism/save gates held + suite green (AC1, AC2, AC3)**
  - [x] Extend `godot/tests/unit/ui/test_outpost_render_view.gd` (the existing scene-free render-decision test — no SceneTree; the presenter is verified by construction + the compile guardrail) for any NEW seam decisions:
    - if `summary_notable_loot()` is added: a summary with no loot events → `[]` (honest-empty); an absent summary → `[]` (fail-closed); (optionally) a summary built with an `item_gained`/`reward_resolved` event → the deduped `notable_loot` entries, proving the read is the real field, not a placeholder.
    - if `NAMED_SPACE_DEFERRED_LABEL` is added: assert the const exists / the four `named_space_markers()` entries still carry `is_deferred == true` + a non-empty `display_name` (the existing `_deferred_named_spaces_carry_an_explicit_marker` test at lines 203-214 already pins this — extend if you add the label const).
  - [x] The marker-removal itself is a presenter-string change (no SceneTree test) — it is verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail (which loads `outpost.tscn`) + the on-device playtest. Do NOT add a SceneTree presenter test (the ratified Epic-11/14 stance).
  - [x] Use `str(...)` never eager `String(nullable)` in assert messages (14.1 retro test-honesty note).
  - [x] Confirm **no domain/RNG/save change**: the ONLY production files touched are `outpost_render_view.gd` (new label const + optional `summary_notable_loot()` accessor) + `outpost_presenter.gd` (the marker sweep + the "coming later" affordance + the notable-loot row + the stale-comment fix) (+ the test). `RunSummary` (23-key gate / `not_yet_supported` / `RUN_SCOPED_KEYS` UNCHANGED), `RunSnapshot` (23 keys, `SCHEMA_VERSION == 1`), `ProfileSnapshot` (`SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent` (no new enum value), `MetaAwardRules` (NOT touched — the earned count is inherited), `OutpostViewModel` (`DICTIONARY_KEYS` / `NAMED_SPACES` UNCHANGED — do not add/remove a space or a key), and every generation/route/finale/combat file are untouched. No new autoload; no new event; no new draw site. If you extend `OutpostRenderView` in-place (recommended) there is **no new `.gd` file** → **no new `.gd.uid` sidecar**; only add one if you deliberately create a new seam file (then generate + commit its `.gd.uid` via `--headless --import` — the 13.1/14.8 discipline).
  - [x] Run the FULL headless suite (mandatory command below). Grep the RAW output for `SCRIPT ERROR|Parse Error|^FAIL` (the false-PASS guard): exactly the **6 documented stderr negatives** (int64-overflow ×2 in `test_manual_seed_loader.gd:153` + `test_domain_event.gd:146` — the 14-4 attribution correction; malformed-JSON ×3; `invalid_node_type` ×1), **ZERO new**. Baseline is **203 PASS files** (post-14.8); this story rides the existing `test_outpost_render_view.gd` (asserts added to an existing file do NOT raise the file count → expect **≥203 PASS**; a new discrete test method may add assertions, not files). `git diff --check` is the orchestrator's job (delegate git policy).

## Dev Notes

### The exact files — the 14.1 "wrong files to touch" precision applied to 14.9

The outpost surface is **`godot/scenes/ui/outpost.tscn`** (a thin `Control`+script scene root) + **`godot/scripts/ui/presenters/outpost_presenter.gd`** (the script that builds the whole layout in `_ready → _build_layout → _render_outpost`, lines 44-124) reading **`godot/scripts/ui/view_models/outpost_render_view.gd`** (the pure-read render-decision seam). The layout is **code-built**, so the cleanup lives in the presenter script + the seam. **This is the SAME surface 14.5 touched** — you are refining `_render_run_summary` / `_render_named_spaces` / `_render_recovery_banner` / `_render_warning_banner` / `_render_spend_menu`, NOT `run_end_presenter.gd` (a non-terminal dead-end since 11.5). The `.tscn` need not change.

### What is ALREADY DONE by 14.5 (verify, do NOT rebuild)

`outpost_presenter._render_run_summary()` (`outpost_presenter.gd:160-198`) already renders, from the just-ended `RunSummary` via the seam:
- the **outcome label** (`summary_outcome_label()` — "Victory"/"Fallen" off `phase`, `outpost_render_view.gd:190-196`) — today prefixed with a `[V]`/`[X]` glyph you REMOVE (Task 1), keeping the word label;
- **nodes cleared** (`summary_nodes_cleared()`, line 201-203);
- the **seed** (`summary_seed()`, line 210-214);
- the **oath-shards earned this run** (`run_oath_shards_earned()`, line 223-230 — the deterministic `MetaAwardRules` const read, 0 for death/manual-seed) — this REPLACED "not yet tallied".

**These are correct and shipped. Task 1 only strips the `[V]`/`[X]` glyph; Tasks 2/3 add the "coming later" affordance + the notable-loot row.** Do NOT re-derive the earned count, do NOT edit `MetaAwardRules`, do NOT touch `summary_outcome_label`/`summary_nodes_cleared`/`summary_seed`/`run_oath_shards_earned`. The 14.5 `[Review][Decision]` (render-seam earned-count computation referencing `MetaAwardRules` consts) is human-RATIFIED — do not reopen it.

### The marker inventory (the F14 sweep) + the NFR9 rule

The presenter emits these raw ASCII debug-marker strings today; each MUST go, and each MUST retain a non-color channel via its descriptive text:

| Site | Line | Marker today | Non-color channel that stays |
|---|---|---|---|
| `_render_recovery_banner` | 132 | `[!]` / `[?]` | the mode-distinct `recovery_note()` text |
| `_render_warning_banner` | 156 | `[!]` | "Manual seed — no meta progression earned." |
| `_render_run_summary` (outcome) | 171 | `[V]` / `[X]` | "Outcome: Victory" / "Outcome: Fallen" |
| `_render_named_spaces` | 233 | `[#]` + `(coming soon)` | display_name + "Coming later" (Task 2) |
| `_render_spend_menu` | 278/280/293 | `[x]` / `[#]` / `[!]` | "Unlocked" / "Cost: N Oath Shards" / the insufficient note |

**NFR9 is the trap:** the ASCII glyphs are the CURRENT non-color channel. You cannot delete them and rely on color — you must ensure the descriptive TEXT label carries the state (it already does in every case above). Text is a valid non-color channel (project-context §14). **Prefer plain human-readable words** (the meaning is already in the labels). If you want a leading cue, use a WORD ("Note:", "Recovery:", "Locked", "Coming later"), never a bracketed ASCII glyph.

### The 14.9 ↔ 14.11 boundary — 14.9 does the CONTENT cleanup, NOT the visual Theme

**Do NOT import art or build a Godot `Theme` in 14.9.** Story **14.11 (UI Theme and Semantic Layout)** owns the visual theme: the Recraft UI frame kit (`asset_sources/icons/ui/button_plate.svg`, `panel_frame.svg`, `modal_frame.svg`), StyleBoxes/fonts/spacing, and the semantic `TacticalLayoutProfile` region plan across ALL screens (including the outpost). 14.9's cleanup is **content/semantic** — remove debug markers, honest deferred rows, honest tallies — using **text labels + built-in `Control`/`Label`/`Button`/`Panel` affordances**, not new textures and not a Theme. If a status "icon" is ever wanted it is 14.11's icon-kit job; 14.9 uses text. This keeps 14.9 additive (no `*.import` sidecar, no `.gd.uid` unless a new seam file) and prevents a 14.9/14.11 overlap. (14.11 will additionally replace the outpost's default-Godot unstyled surfaces with the themed StyleBoxes — that is NOT 14.9.)

### The notable-loot tally — honest-empty in v0 (the deferred event store stays deferred)

`RunSummary.run_scoped.notable_loot` is aggregated from `item_gained` + `reward_resolved` events (`run_summary.gd:212-317`; deferred-work.md line 850 "aggregated from BOTH `item_gained` ... AND `reward_resolved`", single-sourced/deduped per the 8.2 review). In the LIVE flow the run-end bridge builds `RunSummary.build(run, [])` with an **empty events list** (there is **no run-level event store** in v0 — the orchestrator returns events per `ActionResult` but does not accumulate a run-wide log), so `notable_loot` is **legitimately empty**. 14.9 renders it **honestly empty** (never fabricated, never a placeholder), reading the real field. The run-level event store that would populate it (plus `passives_consumed`/`passives_destroyed`/`outcome_or_cause`) is a **deferred save-shape story** — do NOT build it here.

### Recovery + spend surfaces are shipped (AC2 = verify/harden after the sweep)

The `for_recovery` modes (`OutpostViewModel.for_recovery`, `outpost_view_model.gd:272-295`; `OutpostRenderView.recovery_mode`/`recovery_note`/`has_retry_affordance`, `outpost_render_view.gd:96-134`) and the shallow meta menu (`class_unlock_options`/`can_spend_unlock`/`has_affordable_unlock`, lines 293-338) are all shipped (11.5/11.6) and unit-tested (`test_outpost_render_view.gd:96-137, 306-368`). AC2 is a **verify/harden** — confirm they still render honestly (both recovery modes, no crash) and non-color after Task 1's marker sweep. Do NOT rebuild them; do NOT change the recovery/spend seam logic.

### Anti-patterns to avoid (this story specifically)

- **Do NOT re-implement the summary tallies** (outcome label / nodes cleared / seed / oath-shards-earned) — 14.5 shipped them; 14.9 INHERITS them (the orchestrator's explicit ruling). Verify present; strip only the `[V]`/`[X]` glyph.
- **Do NOT touch `MetaAwardRules`** — the earned count is a render-seam read of its consts; the 14.5 ratification stands.
- **Do NOT build the run-level event store** — notable loot + passives lists stay honest-empty (deferred).
- **Do NOT import art or build a Godot `Theme`** — that is 14.11. Use text labels + built-in `Control` affordances.
- **Do NOT touch `_on_descend_pressed`** — it is the single live seed/class reroute to hero-select (14.5's D3); byte-identical.
- **Do NOT change `OutpostViewModel.NAMED_SPACES` / `DICTIONARY_KEYS`** — do not add/remove a named space or a projection key; render the four existing deferred tiles honestly.
- **Do NOT change `RunSummary`, `RunEndProfileBridge`, or any domain/command/event/RNG/save file** — 14.9 is presentation-only. The 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; the 7 named streams unchanged; `RunSummary.DICTIONARY_KEYS`/`RUN_SCOPED_KEYS`/`not_yet_supported` UNCHANGED.
- **Do NOT remove the kept-as-contract-pin seam methods** `summary_oath_shards_earned()` / `summary_oath_shards_not_yet_tallied()` (`outpost_render_view.gd:162-176`). 14.5 stopped rendering them but explicitly KEPT them as the `RunSummary.profile_meta.oath_shards_earned` STAYS-0 / `not_yet_supported` contract pin (a live guard, read by `test_outpost_render_view._g3_...`). Do NOT re-litigate/trim them (the 14.5 `[Review][Defer]` recorded this).
- **Do NOT rely on color alone** for any state after the marker sweep (NFR9) — the descriptive text label is the non-color channel.
- **Do NOT use eager `String(nullable)` in assert messages** (14.1 retro — it crashes on a null read and masks the real failure). Use `str(...)`.
- **Keep the false-PASS grep guard standing** — grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; never trust the summary PASS line alone. Exactly the 6 documented stderr negatives; ZERO new.

## Project Structure Notes

- **Files touched (production):** `godot/scripts/ui/presenters/outpost_presenter.gd` (the marker sweep in `_render_recovery_banner`/`_render_warning_banner`/`_render_run_summary`/`_render_named_spaces`/`_render_spend_menu`; the "coming later" named-space affordance; the split-out notable-loot row; the stale `_render_meta_readout` comment fix) and `godot/scripts/ui/view_models/outpost_render_view.gd` (a `NAMED_SPACE_DEFERRED_LABEL` const + an optional `summary_notable_loot()` accessor — extend the existing seam in-place; do NOT create a new file). The outpost `.tscn` need not change (code-built layout).
- **Test:** extend `godot/tests/unit/ui/test_outpost_render_view.gd` (the existing render-decision unit test). No new SceneTree test — the outpost scene stays verified by construction + `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (which already loads `outpost.tscn`).
- **Assertable render decisions live in the scene-free `RefCounted` `OutpostRenderView` seam** (unit-tested); the presenter is thin glue verified by construction (the 14.2/14.3/14.5/14.8 posture). Extending the seam in-place needs **no new `.gd.uid`**; a new seam file would need its `.gd.uid` generated + committed via `--headless --import` (the 13.1/14.8 discipline) — not recommended. **14.9 adds no art.**
- `scripts/rules/{conditions,operations}`, generation/route/finale/combat/save files — all untouched. No domain/command/event/save/RNG change.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (NFR14/NFR15).** The outpost cleanup is a pure read over the session-bound `OutpostViewModel` (via `finalize_run_end()`) through the `OutpostRenderView` seam; the UI owns no run/profile truth and mutates nothing (the `RunEndProfileBridge` / `OutpostSpendBridge` own the profile mutation; 14.9 renders the result). The Descend button navigates (14.5's reroute); 14.9 does not change it.
- **Save truth = versioned domain snapshots (NFR15).** No save change: the 23-key `RunSnapshot` gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; `RunSummary.DICTIONARY_KEYS`/`RUN_SCOPED_KEYS` unchanged; notable loot is a render read of an existing field, not a new key.
- **Named RNG only; deterministic under seed (NFR13).** 14.9 draws ZERO RNG (the render seam is a pure read; `MetaAwardRules` is deterministic and untouched). The 7 named streams (`map, level, combat, loot, rewards, events, cosmetic`) are unchanged, unreordered.
- **Assertable logic lives in scene-free `RefCounted` seams** (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload. Seams expose only what the presenter consumes (the 14.3 rule) — the notable-loot accessor surfaces only what `_render_run_summary` draws.
- **Difficulty is a hard non-goal.** 14.9 changes no enemy/HP/damage/reward/run-length number.
- **Manual seed grants no meta (FR28).** Unchanged — the earned-count render (inherited) already shows 0 for a manual-seed run; 14.9 does not touch the eligibility model.
- **Color-independence (NFR9).** After the marker sweep, every state (outcome, recovery mode, manual-seed warning, spend state, named-space deferral, tallies) carries a text/label channel, not color alone — the ASCII glyph is REPLACED by descriptive text, never by color-only.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.9 touches only `scripts/ui/`; no fingerprint can move — including the 14.1-re-pinned combat replay at seed 24680). **14.9 re-pins NOTHING.**
- **Headless suite stays green** (203 PASS baseline post-14.8; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Deferred-work overlaps folded in (only those that touch 14.9's area)

- **F-2 — the outpost run-summary outcome label (`deferred-work.md` line 146) — ADOPTED by 14.5, NOT 14.9.** 14.5 rendered the outcome label off `phase`. 14.9 only strips the `[V]`/`[X]` glyph on top of it; do not re-implement the label.
- **`OutpostRenderView.class_unlock_options()` rebuilds a baseline `ClassRepository` on every call (`deferred-work.md` lines 291-292); `has_affordable_unlock()` calls it just to check a boolean.** This is a minor, non-correctness inefficiency **directly in 14.9's AC2 area** (the spend/unlock render). It is **NON-BLOCKING and NOT required by any AC.** If (and only if) you are already editing that seam region, you MAY opportunistically cache/inject the repository — but do NOT expand scope to chase it, and do NOT change the spend RENDER decisions. Leave it deferred if in doubt.
- **The dead-output `summary_oath_shards_not_yet_tallied()` / `summary_oath_shards_earned()` (`14-5` `[Review][Defer]`) — KEEP, do NOT re-litigate.** After 14.5 replaced the "not yet tallied" note, these seam methods are no longer presenter-consumed but are KEPT as the `RunSummary.profile_meta.oath_shards_earned` STAYS-0 / `not_yet_supported` contract pin (read by `test_outpost_render_view._g3_...`). Do not trim them (they guard a live contract).
- **The run-level event STORE for a full `RunSummary` (`deferred-work.md` lines 295, 332; the 12-2 T4 re-record 138-142) — stays DEFERRED.** It would populate `notable_loot` / `passives_consumed` / `passives_destroyed` / `outcome_or_cause`. 14.9 renders those lists honestly empty; do NOT reopen or build it.
- **The Band-1/2 on-device human-playtest defer (`14-5` `[Review][Defer]`) — EXTENDED by 14.9.** 14.9's marker cleanup, honest "coming later" rows, and notable-loot tally are automated-green (seam) but the on-screen legibility is human-unverified (no SceneTree test). Add to the on-device playtest checklist: no `[#]`/`[!]` markers visible; the four named spaces read "Coming later"; the outcome/nodes/seed/earned tallies + notable-loot row are legible without overflowing the outpost `ScrollContainer` on a small viewport; both recovery modes render honestly.

### Epic-14 constraints inherited (retro-notes/epic-14.md + the sprint change)

- **EXACT files (14.1 "wrong files" precision):** the run-end/outpost surface is `outpost_presenter.gd` + `outpost_render_view.gd` (+ `outpost.tscn`, code-built) — NOT `run_end_presenter.gd` (a non-terminal dead-end since 11.5).
- **Render from the bound session, not empty presenter state (14.3 systemic):** the summary/beat/tallies read the session-bound `OutpostViewModel` via `finalize_run_end()` (`_build_render_view`, lines 71-79) — already correct; 14.9 does not change the source.
- **Seams expose only what the presenter consumes (14.3):** the new `summary_notable_loot()` / `NAMED_SPACE_DEFERRED_LABEL` surface only what `_render_run_summary` / `_render_named_spaces` draw — no forward-looking dead output.
- **`str(...)` not eager `String(nullable)` in assert messages (14.1).** The false-PASS grep guard stays standing; exactly the 6 documented stderr negatives (int64-overflow ×1 `test_manual_seed_loader.gd:153` + ×1 `test_domain_event.gd:146` — the 14-4 attribution correction; malformed-JSON ×3; `invalid_node_type` ×1).
- **14.5 SUPERSEDED the outpost's Descend Again start/seed logic — the outpost's Descend button is a pure navigation action** (`SceneManager.go_to_stage("hero_select")`); hero-select is the single live seed/class source. 14.9 leaves `_on_descend_pressed` byte-identical.
- **`.gd.uid` discipline (14.8):** the `--scene` test run does NOT emit `.gd.uid` sidecars for new `.gd` files — run `--headless --import` separately IF you add a new `.gd` (recommended: extend the existing seam, so no new file/uid).
- **EPIC-LEVEL RISK (14.4/14.5/14.8 retro):** Band-2 presentation stories defer their user-facing verification to the pending on-device playtest — 14.9's outpost cleanup is automated-green but human-unverified. Confirm the on-device playtest happens before Band 2 closes.
- **Difficulty stays a hard non-goal; 14.9 re-pins nothing; no new autoload; the scene is verified by construction + the compile guardrail.**

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **203 PASS files** (post-14.8); expect **≥203 PASS**, ZERO new stderr negatives beyond the 6 documented.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` — Story 14.9 ACs (body lines 3163-3183); the Band-2 demarcation (3138); the Epic List entry (521-527); FR68 (line 158); the 14.5 overlap note (body lines 3069-3090).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` — **F14** the `[#]`/`[!]`/`(coming soon)`/`not yet tallied` finding (lines 26-27); the **14.9 scope row** (line 144); the Band-2 list (line 84).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — the **14.5↔14.9 overlap ruling** (§14-5: 14-9 INHERITS the earned count, does not re-implement); the 14.1 "wrong files to touch" precision; the `str(...)`-not-`String(nullable)` note + false-PASS grep; the 14.3 render-from-session systemic + seams-expose-only-consumed; the 14.4 stderr-negative attribution correction; the 14.8 `.gd.uid`-via-`--import` discipline; the Band-1/2 human-verification-deferred epic risk.
- `_bmad-output/implementation-artifacts/14-5-run-end-beat-and-run-summary-screen.md` — the SHIPPED summary tallies 14.9 inherits (`_render_run_summary` + the 4 seam methods); the "14-9 INHERITS the earned count" note (line 117); the kept-as-contract-pin `summary_oath_shards_not_yet_tallied` defer; the Descend→hero-select reroute (14.9 leaves it alone).
- `_bmad-output/implementation-artifacts/14-8-hero-select-rebuild.md` — the ratified Band-2 presentation-only story shape, the `RefCounted`-render-seam pattern, the compile-guardrail posture, the `.gd.uid`-via-`--import` discipline, and the "outpost cleanup (F14 → Story 14.9)" hand-off (line 172).
- `_bmad-output/implementation-artifacts/deferred-work.md` — the F-2 outcome-label (146, adopted by 14.5); the `class_unlock_options` `ClassRepository`-per-call inefficiency (291-292, optional/non-blocking); the run-level event STORE non-adoption (295, 332); the notable-loot event source (850).
- Source files (read before implementing):
  - `godot/scripts/ui/presenters/outpost_presenter.gd` — `_render_outpost` (85-124); `_render_recovery_banner` (130-142, `[!]`/`[?]` at 132); `_render_meta_readout` (145-150, the stale "not yet tallied" comment at 147); `_render_warning_banner` (153-157, `[!]` at 156); `_render_run_summary` (160-198, the SHIPPED 14.5 tallies + the `[V]`/`[X]` glyph at 171 + the combined pending line at 196-198); `_render_reveal_beat` (205-224, no marker — leave); `_render_named_spaces` (227-234, `[#]` + `(coming soon)` at 232-233); `_render_descend_affordance` (241-247) + `_on_descend_pressed` (318-332, the 14.5 reroute — DO NOT TOUCH); `_render_spend_menu` (256-296, `[x]`/`[#]`/`[!]` at 278/280/293).
  - `godot/scripts/ui/view_models/outpost_render_view.gd` — the label consts (`SUMMARY_OUTCOME_VICTORY`/`DEATH` 74-75, `INSUFFICIENT_SHARDS_NOTE` 69, `RECOVERY_NOTE_*` 56-57, `MANUAL_SEED_WARNING_LINE` 52 — the pattern to mirror for `NAMED_SPACE_DEFERRED_LABEL`); the SHIPPED 14.5 summary methods (`summary_outcome_label` 190, `summary_nodes_cleared` 201, `summary_seed` 210, `run_oath_shards_earned` 223 — INHERITED, do not touch); the kept-as-pin `summary_oath_shards_earned`/`_not_yet_tallied` (162-176); `named_space_markers` (271-283, `is_deferred`/`display_name`); `class_unlock_options` (293-317) / `has_affordable_unlock` (334-338, the deferred `ClassRepository`-per-call inefficiency); `recovery_mode`/`recovery_note`/`has_retry_affordance` (96-134).
  - `godot/scripts/ui/view_models/outpost_view_model.gd` — `NAMED_SPACES` (135-160, the four `status:"deferred"` spaces — UNCHANGED); `DICTIONARY_KEYS` (88-103, UNCHANGED); `run_summary()` (334-335 → `RunSummary.to_dictionary()`, the `run_scoped.notable_loot` source); `for_recovery` (272-295).
  - `godot/scripts/run/run_summary.gd` — `RUN_SCOPED_KEYS` incl. `notable_loot` (98-104); `to_dictionary` (359-373); the `notable_loot` aggregation from events (212-317, empty when the bridge passes `[]`); `not_yet_supported` (130-132, UNCHANGED).
  - Tests: `godot/tests/unit/ui/test_outpost_render_view.gd` (extend — the render-decision pattern; existing coverage of recovery modes, spend, reveal beats, deferred spaces, and the 14.5 summary decisions); `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the compile guardrail, loads `outpost.tscn`).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story).

### Debug Log References

- Baseline suite (pre-change, HEAD `5c2bf1c`): 203 PASS files; false-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = 0 matches; exactly the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1).
- Post-change suite: 203 PASS files (unchanged — assertions added to the existing `test_outpost_render_view.gd`, no new file); guard = 0 matches; the SAME 6 documented negatives, ZERO new. `test_outpost_render_view.gd` PASS.
- Presenter marker re-grep after the sweep: the only `[#]`/`[!]`/`[?]`/`[V]`/`[X]`/`[x]` occurrences remaining are in code COMMENTS (historical references); zero in any rendered `Label.text` / `Button.text`.

### Completion Notes List

- **Presentation-only, as scoped.** No domain / command / event / RNG / save file touched; `RunSummary` / `RunSnapshot` (23-key gate, `SCHEMA_VERSION == 1`) / `ProfileSnapshot` / `RngStreamSet` (7 streams) / `DomainEvent` / `MetaAwardRules` / `OutpostViewModel` (`DICTIONARY_KEYS` / `NAMED_SPACES`) all byte-identical. **14.9 re-pins NOTHING.** No new `.gd` file (seam extended in-place) → no new `.gd.uid`; no `.tscn` change; no art / Theme (that is 14.11).
- **Task 1 (marker sweep):** removed every rendered ASCII debug glyph — `[!]`/`[?]` (recovery banner), `[!]` (manual-seed warning), `[V]`/`[X]` (run-summary outcome), `[#]`+`(coming soon)` (named spaces), `[x]`/`[#]`/`[!]` (spend menu). Each state keeps a non-color TEXT channel (NFR9): recovery uses a mode-distinct word cue ("Could not save:" / "Could not load:") plus the already-distinct `recovery_note()`; the warning uses a "Note:" cue; outcome/spend states read by their existing words ("Outcome: Victory/Fallen", "Unlocked", "Cost: N Oath Shards", the insufficient note).
- **Task 2 (named spaces):** `_render_named_spaces()` now renders `"<display_name> — Coming later"` for each deferred tile, driven off the new seam const `OutpostRenderView.NAMED_SPACE_DEFERRED_LABEL := "Coming later"`. The 11.6 deferred-overview-registry semantics are preserved (tiles unchanged; the realized spend menu / Descend button stay separate sections).
- **Task 3 (notable loot):** split 14.5's combined pending line into a dedicated "Notable loot:" row reading the REAL field `run_scoped.notable_loot` via a new pure-read seam accessor `OutpostRenderView.summary_notable_loot() -> Array` (fresh deep copy; `[]` when absent/empty — fail-closed). Honestly empty in the v0 live flow (the bridge builds `RunSummary.build(run, [])`); renders the gained item ids when present. The passives-consumed/destroyed line stays honestly pending. The run-level event store was NOT built (stays deferred).
- **Task 4 (verify/harden):** meta readout, spend menu, and both recovery modes render from the seam and are non-color after the sweep (covered by the existing recovery/spend tests, still green). Fixed the stale `_render_meta_readout` comment (no longer claims a "not yet tallied" note — 14.5 replaced it with the real earned count). `_on_descend_pressed`, `_render_descend_affordance`, and `_render_reveal_beat` left byte-identical.
- **14.5 inheritance verified, not re-implemented:** `summary_outcome_label` / `summary_nodes_cleared` / `summary_seed` / `run_oath_shards_earned` untouched; `MetaAwardRules` untouched; the kept-as-contract-pin `summary_oath_shards_earned` / `summary_oath_shards_not_yet_tallied` seam methods retained.
- **Deferred (unchanged):** the run-level event store (populating notable_loot / passives / outcome_or_cause) stays deferred; the optional `class_unlock_options()` `ClassRepository`-per-call inefficiency was left as-is (non-blocking, not in AC scope). On-device human legibility verification remains deferred to the pending Band-2 playtest (no SceneTree presenter test — verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail).

### File List

- `godot/scripts/ui/presenters/outpost_presenter.gd` — modified (marker sweep across `_render_recovery_banner` / `_render_warning_banner` / `_render_run_summary` / `_render_named_spaces` / `_render_spend_menu`; the "Coming later" affordance; the split-out notable-loot row + `_notable_loot_summary` helper; the stale `_render_meta_readout` comment fix)
- `godot/scripts/ui/view_models/outpost_render_view.gd` — modified (new `NAMED_SPACE_DEFERRED_LABEL` const + new `summary_notable_loot()` pure-read accessor)
- `godot/tests/unit/ui/test_outpost_render_view.gd` — modified (new `_notable_loot_reads_the_real_summary_field()` test; extended `_deferred_named_spaces_carry_an_explicit_marker` to pin the const)
- `_bmad-output/implementation-artifacts/14-9-outpost-screen-cleanup.md` — modified (baseline_commit frontmatter, task checkboxes, Dev Agent Record, Status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — modified (14-9 status in-progress → review; last_updated)

### Change Log

- 2026-07-19 — Implemented Story 14.9 (Outpost Screen Cleanup): stripped raw ASCII debug markers, honest "Coming later" named-space affordances, split-out notable-loot honest tally, stale-comment fix. Presentation-only; suite green (203 PASS, 0 new stderr negatives). Status → review.

### Review Findings

**Round 1 of 3**

**Code review — 2026-07-19 (Round 1 of 3, gds-code-review; base branch `story/14-8-hero-select-rebuild`)**

**Verdict: Approve.** Critical 0 / High 0 / Med 0 / Low 2. Presentation-only story executed exactly as scoped. The full
headless suite was independently re-run green: **203 PASS files** (baseline held — assertions added to the existing
`test_outpost_render_view.gd`, no new file), the false-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = **0 matches**, and
exactly the **6 documented stderr negatives** (int64-overflow ×2 `test_manual_seed_loader.gd:153` + `test_domain_event.gd:146`,
malformed-JSON ×3, `invalid_node_type` ×1) with **ZERO new**. `test_outpost_render_view.gd` PASS. Diff touches only
`outpost_presenter.gd` + `outpost_render_view.gd` (+ the test); git status clean.

**Verification (all six scrutiny checks confirmed):**
- **14.5-inherited summary work is byte-identical except the in-scope outcome-glyph strip.** `summary_nodes_cleared` /
  `summary_seed` / `run_oath_shards_earned` seam methods and their presenter render lines (`outpost_presenter.gd:182-196`)
  are unchanged in the diff; only the `[V]`/`[X]` outcome glyph was removed (the "Outcome: Victory/Fallen" word label is
  kept). `summary_outcome_label` and `MetaAwardRules` untouched. The earned count is NOT re-derived.
- **The Descend button is byte-identical (pure navigation since 14.5).** `_on_descend_pressed` (`outpost_presenter.gd:355-369`)
  and `_render_descend_affordance` (276-282) are not in the diff.
- **The marker sweep is complete.** Zero rendered `[#]`/`[!]`/`[?]`/`[V]`/`[X]`/`[x]`/`(coming soon)` remain in any
  `Label.text`/`Button.text` (grep-confirmed; the only remaining occurrences are historical code comments).
- **Every replacement keeps a non-color channel (NFR9).** Mode-distinct "Could not save:"/"Could not load:" cue + the
  already-distinct `recovery_note()`; a "Note:" cue on the manual-seed line; the "Outcome: …" word; "<name> — Coming later";
  "Unlocked"/"Cost: N Oath Shards"/the insufficient note. No state relies on color alone.
- **`summary_notable_loot()` is pure / fresh-copy / fail-closed.** Pure read of `run_scoped.notable_loot` (same
  `(_projection.get("run_summary", {}) as Dictionary)` pattern already shipped/tested in `summary_nodes_cleared`), returns
  `loot.duplicate(true)` (fresh deep copy), `[]` when the summary/run_scoped is absent; draws no RNG, mutates nothing. The
  real-field read is proven end-to-end by the new test (an `item_gained` event rides through the `OutpostViewModel`
  projection to a single deduped entry; the live bridge builds `RunSummary.build(run, [])` — `run_end_profile_bridge.gd:179`
  — so the row is legitimately empty in v0, never fabricated).
- **No domain/RNG/save/scene/schema file touched.** Only `scripts/ui/` presenter + seam changed; no `.tscn`, `.import`, or
  `.gd.uid`; `RunSummary`/`RunSnapshot`/`ProfileSnapshot`/`RngStreamSet`/`DomainEvent`/`OutpostViewModel` byte-identical.
  14.9 re-pins nothing.

**Findings:**
- [x] **[Review][Decision] LOW — label-centralization asymmetry (ratify keep-as-is or centralize later).** The deferred-space
  affordance label is centralized as a seam const (`OutpostRenderView.NAMED_SPACE_DEFERRED_LABEL := "Coming later"`, testable
  without a SceneTree), but the empty-notable-loot display string `"— none —"` is a presenter literal inside
  `_notable_loot_summary()` (`outpost_presenter.gd:219-226`), so only the underlying `Array` decision is unit-asserted, not
  the empty-state string. This is consistent with the existing presenter literal `"Passives spent/destroyed: — none recorded
  yet —"` and matches the ratified "presenter is thin glue verified by construction" posture, so it is acceptable as-is; a
  human may optionally centralize the empty-loot label into the seam for symmetry/testability in a future polish pass.
  Non-blocking; no AC requires it.
  **Resolution (human decision, 2026-07-19) — RATIFY KEEP-AS-IS.** The empty-notable-loot display string `"— none —"` stays
  a presenter literal inside `_notable_loot_summary()` (`outpost_presenter.gd:219-226`) exactly as implemented; it is NOT
  centralized into the `OutpostRenderView` seam. The human ratifies the thin-glue-presenter posture — the empty-state display
  copy is presentation text, not an assertable render decision, and stays consistent with the sibling passives-pending
  presenter literal. The underlying `summary_notable_loot() -> Array` seam accessor remains the unit-tested contract. This
  requires no production-code change; the resolution is documentation-only. Finding resolved.
- [ ] **[Review][Defer] LOW — `class_unlock_options()` rebuilds a baseline `ClassRepository` per call** (and
  `has_affordable_unlock()` calls it just to check a boolean; `outpost_render_view.gd:313-337`). This sits in 14.9's AC2
  spend/unlock area and was correctly left deferred (the marker sweep changed only `label.text`/`note.text`, not this seam
  region; non-blocking, not required by any AC). Same pre-existing item first logged under "code review of 11-6"
  (deferred-work.md lines 291-295); re-confirmed here that it remains unaddressed and non-blocking. Copied to
  deferred-work.md under "Deferred from: code review of 14-9-outpost-screen-cleanup (2026-07-19)".
