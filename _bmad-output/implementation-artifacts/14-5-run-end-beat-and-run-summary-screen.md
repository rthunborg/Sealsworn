# Story 14.5: Run-End Beat and Run-Summary Screen

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a death/victory moment and a run summary before returning to the outpost, and Descend Again to let me pick a class,
so that the run has closure and re-descending is never a class-less default.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and looks unfinished (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.5 is the **fifth story of Band 1** (finishable + readable), landing after 14.1's soft-lock fix, 14.2's visible preview / reject cue, 14.3's event-log + hit feedback, and 14.4's per-run seed variety. It closes **three** related run-end gaps the playtest surfaced (`sprint-change-proposal-2026-07-16.md` lines 19-21, 105, 135):

- **F5 — the death/victory is a hard cut.** No death moment, no cause, no run summary; the **shipped Epic-8 first-death line never renders** on screen. The player dies and is dumped back with no closure.
- **F4 — class-less "Descend Again" (the 60-HP fail-open).** The most common post-death path (the outpost's one-tap "Descend Again") **skips hero select and starts the fail-open 60-HP driver default** — not a real class's 18-HP kit (FR6). Re-descending is a broken class-less run.
- **F-2 — the run-summary panel has no outcome label.** The outpost's embedded run-summary renders only a "not yet tallied" note; the **victory-vs-death outcome is invisible** on the summary (deferred-work.md line 109; the standing 10-5/11-5 code-review Low).

**This story is PRESENTATION + FLOW-NAV ONLY over shipped DTOs — it makes NO domain/command/event/RNG/save change.** Everything it renders already exists: the `RunSummary` (8.2/8.4), the `FirstDeathNarrativeBeat` (8.5) / `FirstVictoryRevealBeat` (9.4) DTOs, the `RunEndProfileBridge` (11.5), the `OutpostViewModel` (8.6/11.5), and the `OutpostRenderView` render-decision seam (11.5). 14.5 wires the honest render + fixes the descend routing. **The two ratified design calls it implements:**
- **D3 (`sprint-change-proposal-2026-07-16.md` line 105):** route the outpost descend affordance **through the hero-select stage** so the player picks a class (a real 18-HP kit) — **never** the class-less 60-HP driver default. The authoritative `RunStartCommand` class gate is **unchanged**. (The rejected alternative — "carry the prior run's class for a one-tap quick-descend" — is a later enhancement, NOT this story.)
- **D6 (the 14.5 scope row, line 135):** the run-summary **outcome label is keyed off `run.phase`** (`PHASE_COMPLETED`/`PHASE_FAILED`), **NOT** the blank `outcome_or_cause`.

**The load-bearing architecture reality (read before Task 1).** After Story 11.5, the live run-end return routes **straight to the real outpost scene** (`RunFlowRouter._DESTINATION_STAGES["outpost"] -> "outpost" -> res://scenes/ui/outpost.tscn`, `run_flow_router.gd:44-63`). `run_end.tscn` / `run_end_presenter.gd` survives ONLY as the gameplay shell's minimal fail-loud NON-terminal dead-end — it is **NOT** the terminal-run surface. So the death/victory **beat** and the run **summary** render **on the outpost scene** (`outpost_presenter.gd` + `outpost_render_view.gd`), which the terminal run lands on. "Between run-end and the outpost" in AC2 describes the LOGICAL position (the run-end readout you see when you land on the outpost, before you Descend Again) — there is **no separate run-summary scene**, and 14.5 does **not** build one (UI-scene-last; additive over the pinned outpost surface). **This is the "wrong files to touch" precision point from the 14.1 retro applied to 14.5: the run-end surface is `outpost_presenter.gd` / `outpost_render_view.gd` / `outpost.tscn`, NOT `run_end_presenter.gd`.**

**What is ALREADY done (do NOT rebuild it).** Story 11.5 already renders **both reveal beats** on the outpost with a Dismiss control (`outpost_presenter._render_reveal_beat`, lines 108-111, 178-197) gated on `OutpostRenderView.shows_first_death_beat()` / `shows_first_victory_beat()` (`outpost_render_view.gd:176-192`), and the `RunEndProfileBridge` already records the first-death/first-victory latch off the REAL terminal phase and embeds the populated beat in the `OutpostViewModel` (`run_end_profile_bridge.gd:125-172`). **AC1 is largely a VERIFY/HARDEN of that shipped path — not a rebuild.** The real new work is **AC2** (the honest summary render — outcome label off `phase`, nodes cleared, seed, earned count, replacing the threadbare "not yet tallied"-only panel at `outpost_presenter.gd:160-172`) and **AC3** (reroute Descend Again through hero-select, `outpost_presenter._on_descend_pressed` lines 292-334).

## Acceptance Criteria

**AC1 — The death/victory run-end beat renders on screen, skippable, non-blocking (F5; FR61/FR62/FR65)**
Given a run ends in death or victory
When the run-end flow resolves (the terminal run lands on the outpost, via `RunFlowController.finalize_run_end()` → `RunEndProfileBridge.build_outpost`)
Then a death/victory beat renders the **shipped narrative DTO** on screen — the first-death line **"Good. You remembered how to die."** (`FirstDeathNarrativeBeat`, FR61) on a `PHASE_FAILED` run, or the first-victory reveal **"It did not die. It learned the way back."** (`FirstVictoryRevealBeat`, FR62) on a `PHASE_COMPLETED` run — and the beat is **skippable** (a Dismiss control, ≥44px) and **never blocks** understanding the summary or starting another descent (FR65, FR64)
And the beat DTOs are **read-only**: the latch mutation stays in its record command (`RecordFirstDeath/VictoryCommand`, driven by the bridge), and a skip/dismiss is a **pure presentation no-op** (frees the beat card; submits NO command; mutates NO flag). The beat is once-per-profile (a repeat death shows no beat — the fail-closed empty-beat gate — and the SUMMARY outcome label carries the closure instead).

**AC2 — The run-summary panel renders the honest facts, outcome off `phase` (F-2, D6; FR60)**
Given a run has ended and the summary is shown on the outpost landing (between run-end and Descend Again)
When the run-summary panel renders
Then it renders the honest facts from the **existing `RunSummary`** (FR60): the **victory/death outcome LABEL keyed off `run.phase`** (`PHASE_COMPLETED` → a victory label, `PHASE_FAILED` → a death label) + the reveal beat — **NOT** the blank `outcome_or_cause` (which is `""` in the live flow because the bridge builds `RunSummary.build(run, [])` with an empty events list); **nodes cleared** (`run_summary.run_scoped.nodes_cleared`); the **seed** (`run_summary.seed`); and the **oath-shards-earned-this-run count** (a SEPARATE deterministic read — see Dev Notes — 0 for a death or an ineligible/manual-seed run), replacing the dishonest "not yet tallied" placeholder
And summary lists with **no live source in v0** (passives consumed/destroyed, notable loot — from the **deferred** run-level event store) are shown **honestly as empty/pending, never fabricated**, and the pinned `RunSummary` / 8.2 contract is **unchanged** (the outcome label + earned count are separate render-side reads, NOT new summary keys). Every meaning carries a **non-color channel** (text/icon/label — NFR9).

**AC3 — Descend Again routes through hero-select for a real class (F4, D3; FR6/FR32)**
Given the player chooses Descend Again from the outpost
When the descend affordance is invoked
Then it **routes through the hero-select stage** (`SceneManager.go_to_stage("hero_select")` after clearing the terminal run-flow handle) so a **real class (with its 18-HP kit)** is chosen — **never** the class-less fail-open driver default (`LiveCombatResolver.DEFAULT_HERO_HP == 60`, `live_combat_resolver.gd:68`); the authoritative `RunStartCommand` class gate is **unchanged**
And the run-end/summary/beat render logic lives in **`RefCounted` render-decision seams** (verified without a SceneTree — the `OutpostRenderView` posture; the scenes are verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail), and **no domain command / RNG / save contract changes**; every pinned fingerprint is **byte-identical** (the 23-key `RunSnapshot` gate stays 23, `SCHEMA_VERSION == 1`, the 7 named streams unchanged, no new event/enum value, no new autoload).

## Tasks / Subtasks

- [ ] **Task 1 — Run-summary render decisions in the `OutpostRenderView` seam (AC2)**
  - [ ] Extend the existing `godot/scripts/ui/view_models/outpost_render_view.gd` (the pinned RefCounted render-decision seam the outpost presenter reads — the 14-9 AC2 target too, so co-locating here keeps the outpost render decisions in one unit-tested seam). Add pure-read methods over the already-present `_projection["run_summary"]` sub-dict (which carries `phase`, `seed`, `meta_progression_eligible`, and `run_scoped.nodes_cleared`):
    - `summary_outcome_label() -> String` — keyed off the summary's `phase` (**D6**): `"completed"` → a victory label (e.g. `"Victory"`), `"failed"` → a death label (e.g. `"Fallen"`), `""`/absent → `""`. **Do NOT read `outcome_or_cause`** (it is `""` in the live flow — the empty-events build). Reuse `run_end_presenter.gd:58`'s vocabulary (`"Victory"` / `"Fallen"`) for consistency.
    - `summary_nodes_cleared() -> int` — `run_summary.run_scoped.nodes_cleared` (0 if absent).
    - `summary_seed() -> String` — `run_summary.seed` (already the decimal-string int64; the epic-wide root_seed rule). `""` if absent.
    - `run_oath_shards_earned() -> int` — the **deterministic earned-this-run count** (see Dev Notes "The oath-shards-earned count"): `0` unless `phase == "completed"` AND `meta_progression_eligible == true`; otherwise `clampi(MetaAwardRules.BASE_AWARD + MetaAwardRules.PER_NODE_AWARD * nodes_cleared, 0, MetaAwardRules.MAX_AWARD)` (preload `meta_award_rules.gd`; reference its public consts so the NUMBERS are single-sourced — do NOT hardcode 1/1/5). A death or manual-seed run honestly earns 0.
  - [ ] These new methods must expose ONLY what `_render_run_summary` consumes (the 14.3 retro "seams expose only what the presenter consumes — no forward-looking dead output"). Keep the existing `summary_oath_shards_earned()` / `summary_oath_shards_not_yet_tallied()` methods present (other tests read them) but note the presenter no longer renders the "not yet tallied" note (Task 2 replaces it with the real earned count).
  - [ ] No new pinned KEY-SET const is required (these are computed accessors, not a new projection dict). If you prefer a dedicated seam instead of extending `OutpostRenderView`, a new `RunSummaryRenderView extends RefCounted` (built from the summary dict) is acceptable — but extending `OutpostRenderView` is recommended (14-9 AC2 reads "the existing `OutpostRenderView` seam"; one seam, one test file).

- [ ] **Task 2 — Render the honest summary on the outpost (AC2)**
  - [ ] Rewrite `outpost_presenter._render_run_summary()` (`outpost_presenter.gd:160-172`): keep the `shows_run_summary()` gate ("No just-ended run." when absent — a fresh/direct-boot outpost, NOT a zeroed sheet). When present, render, each as a `Label` with a non-color channel (text/icon):
    - the **outcome label** (`summary_outcome_label()`) — e.g. `"Outcome: Victory"` / `"Outcome: Fallen"`, with a distinct glyph per outcome (e.g. `[V]` / `[X]`, not color-only — NFR9);
    - **nodes cleared** (`summary_nodes_cleared()`) — e.g. `"Nodes cleared: %d"`;
    - the **seed** (`summary_seed()`) — e.g. `"Seed: %s"` (the decimal string; useful for FR27 replay/sharing);
    - the **oath-shards earned this run** (`run_oath_shards_earned()`) — e.g. `"Oath Shards earned this run: %d"` — **replacing** the old "not yet tallied" note.
  - [ ] Show the **v0-empty lists honestly**: passives consumed/destroyed and notable loot have no live source (the deferred run-level event store — see Dev Notes). Render them as an explicit **"— none recorded —"** / pending affordance (the visible-exception discipline — never silently omit, never fabricate). Do NOT read a presentation/combat log as source truth (8.2 AC2 forbids it), and do NOT build the run-level event store (out of scope — it stays deferred).
  - [ ] Use human display text, not raw snake_case, for the labels (the epic-wide readability posture). Keep `str(...)` (never eager `String(nullable)`) in any assert/log messages (14.1 retro).

- [ ] **Task 3 — Verify/harden the run-end beat render (AC1) — do NOT rebuild it**
  - [ ] Confirm the first-death/first-victory beat renders on the outpost landing for the live terminal run: `outpost_presenter._render_reveal_beat` (lines 108-111, 178-197) is gated on `OutpostRenderView.shows_first_death_beat()` / `shows_first_victory_beat()`, and the `RunEndProfileBridge` embeds the populated beat off the REAL terminal phase (`run_end_profile_bridge.gd:132-148`). Ensure the render reads the **session-bound** `OutpostViewModel` (via `flow.finalize_run_end()`, `outpost_presenter._build_render_view` lines 71-79) — **NOT** empty presenter-owned state (the 14.3 systemic "render() from the bound session, not empty state" lesson).
  - [ ] Confirm the Dismiss is a **pure no-op** (`dismiss_button.pressed.connect(card.queue_free)`, line 194 — no command, no mutation) and that dismissing/absent beats never disable the summary or the Descend affordance (FR64/FR65 — `can_start_descent()` is independent of the beats). If the beat headings ("Remembrance" / "Ascension", lines 109-111) read better as an explicit run-end moment, a light heading polish is fine; do NOT change the beat DTOs, the record commands, or the latch behavior.
  - [ ] Do NOT add a "skip command"; do NOT gate the beat on `meta_progression_eligible` (a manual-seed first death/victory STILL shows the line — the ratified Option-A eligibility-independence, 8.5/9.4; the bridge already records it eligibility-independently).

- [ ] **Task 4 — Reroute "Descend Again" through hero-select (AC3, D3)**
  - [ ] Rewrite `outpost_presenter._on_descend_pressed()` (`outpost_presenter.gd:292-334`) to **navigate to the hero-select stage** instead of starting a class-less run directly: clear the terminal run-flow handle (`GameSession.clear_run_flow()` if `/root/GameSession`), then `SceneManager.go_to_stage("hero_select")` (if `/root/SceneManager`). Hero-select's confirm then starts the run with a **real selected class** (its 18-HP kit) via the 14.4 seed seam (`hero_select_presenter._on_confirm_pressed`, lines 99-128) — the authoritative `RunStartCommand` class gate is unchanged.
  - [ ] **Remove the now-dead outpost start logic**: delete the inline `request` dict, the `RunSeedSource.resolve(...)` call, the `RunFlowController.new().start(...)` direct start, and the `_new_run_entropy()` helper (lines 353-362) — they are unreachable once Descend Again reroutes to hero-select (grep-confirm: `_new_run_entropy` / the descend `controller.start` are referenced only inside `_on_descend_pressed`). Remove the now-unused `const RunSeedSource` preload (line 27) **only if** grep confirms no other outpost path uses it (the spend path does not). **Keep** the `RunFlowController` preload — `_flow()` / `_build_render_view()` still use it for `finalize_run_end()`.
  - [ ] Do **NOT** remove `LiveCombatResolver.DEFAULT_HERO_HP` / the driver fail-open (it is the sanctioned hands-off/test driver default; only the LIVE Descend-Again path must route through a class). Do **NOT** touch `OutpostViewModel.start_run_request` / its pinned `START_REQUEST_KEYS` (unchanged; the outpost no longer builds an inline start request at all). Preserve the spend menu, the reveal beats, the summary render, and the recovery/retry paths.
  - [ ] Known accepted limitation (do NOT try to "fix" — scope creep): the standalone `hero_select_presenter` builds a **profile-unaware** `HeroSelectViewModel.new()` (line 32), so a spend-UNLOCKED class shows as locked when reached via Descend Again. That is the deferred Necromancer/Shadeblade profile-threading concern (`deferred-work.md`, "dev of 11-6"; the 14.4 profile-threading defer) — **do not reopen it here.** The three baseline classes (warrior/pyromancer/ranger) are always selectable, so the class-ful descend works.

- [ ] **Task 5 — Render-decision test + determinism/save gates held + suite green (AC1, AC2, AC3)**
  - [ ] Extend `godot/tests/unit/ui/test_outpost_render_view.gd` (the existing render-decision test — the scene-free harness has NO SceneTree; presenters are verified by construction + the compile guardrail) with cases pinning the new AC2 decisions on a synthetic `OutpostViewModel` built from a terminal `RunState` + a `RunSummary`:
    - a `PHASE_COMPLETED` summary → `summary_outcome_label()` is the victory label; `summary_nodes_cleared()` / `summary_seed()` echo the summary; `run_oath_shards_earned()` == `clampi(1 + nodes_cleared, 0, 5)` (matching `MetaAwardRules.oath_shard_award_for` for the same run);
    - a `PHASE_FAILED` summary → the death label AND `run_oath_shards_earned() == 0` (a death earns nothing);
    - a manual-seed (`meta_progression_eligible == false`) COMPLETED summary → `run_oath_shards_earned() == 0` (honest — a manual-seed run earns no meta);
    - an absent summary (`has_summary == false`) → outcome label `""`, earned 0 (fail-closed, no crash);
    - the beat gates (`shows_first_death_beat` / `shows_first_victory_beat`) already have coverage (`_reveal_beats_render_on_their_has_beat_gate`) — extend if needed for AC1.
  - [ ] Use `str(...)` (never eager `String(nullable)`) in assert messages (14.1 retro test-honesty note).
  - [ ] Confirm **no domain/RNG/save change**: the ONLY production files touched are `outpost_render_view.gd` + `outpost_presenter.gd` (+ the test). `RunSummary` (23-key gate untouched; its `not_yet_supported`/`oath_shards_earned` DTO contract UNCHANGED — the earned count is a render-side read, not a summary key), `RunSnapshot` (23 keys, `SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent` (no new enum value), `MetaAwardRules` (read-only const reference — recommended default is NO edit; see the Decision in Dev Notes), and every generation/route/finale/combat file are untouched. No new autoload; no new event; no new draw site; **14.5 re-pins NOTHING**.
  - [ ] Run the FULL headless suite (mandatory command below). Grep the raw output for `SCRIPT ERROR|Parse Error|^FAIL` (the false-PASS guard): exactly the **6 documented stderr negatives** (int64-overflow ×2 in `test_manual_seed_loader`/`test_domain_event` — see the 14-4 retro attribution note; malformed-JSON ×3; `invalid_node_type` ×1), **ZERO new**. Baseline is **201 PASS** (post-14.4); this story adds render-decision cases → expect **≥201 PASS** (a few new assertions in the existing test file may not raise the file count; if you add discrete test methods the PASS count ticks up). `git diff --check` clean.

## Dev Notes

### The run-end surface is the OUTPOST scene (not run_end.tscn) — the exact files

Story 11.5 re-pointed the run-end return to the real outpost scene. The live terminal run flows:

`RunFlowController.finalize_run_end()` (`run_flow_controller.gd:243-245`) → `RunEndProfileBridge.build_outpost(_orchestrator.run, _orchestrator)` (`run_end_profile_bridge.gd:96-172`: load profile → record first-death/victory latch off the REAL terminal phase → persist → build `OutpostViewModel` + `RunSummary.build(run, [])` + the reveal beats) → `outpost_presenter._build_render_view()` reads it via `OutpostRenderView.from_view_model(outpost)` → `_render_outpost()` draws the beats + summary + Descend affordance.

- **The nav target is `res://scenes/ui/outpost.tscn`** (`run_flow_router.gd:52,61-63`: the pinned `outpost` destination → `outpost` stage → `outpost.tscn`). `run_end.tscn` / `run_end_presenter.gd` is the minimal fail-loud NON-terminal dead-end only (`run_flow_router.gd:30-31,49`) — **not** the terminal surface. **The 14.1-retro "wrong files to touch" precision point applied to 14.5: touch `outpost_presenter.gd` + `outpost_render_view.gd`, NOT `run_end_presenter.gd`.** (You MAY optionally tidy `run_end_presenter._render_outcome`'s blank-`cause` append at `run_end_presenter.gd:56-63` to key off `phase` only, but it is off the live terminal path — do not spend scope there.)
- **The summary + beats render on the outpost landing** — that IS the "run-end moment before Descend Again." 14.5 does **not** add a separate run-summary scene (UI-scene-last; additive over the pinned outpost).

### AC1 is 90% shipped by 11.5 — verify, don't rebuild

`RunEndProfileBridge` already records the latch off `run.phase` (`PHASE_FAILED` → `RecordFirstDeathCommand`, `PHASE_COMPLETED` → `RecordFirstVictoryCommand`; `run_end_profile_bridge.gd:132-148`) and embeds the **populated** beat in the `OutpostViewModel` (`first_death_beat` / `first_victory_beat`, keys pinned at `outpost_view_model.gd:100-101`). `outpost_presenter._render_reveal_beat` (lines 178-197) renders the beat card + a Dismiss that is a pure `card.queue_free` no-op. `OutpostRenderView.shows_first_death_beat()` / `first_death_line()` / the victory twin (`outpost_render_view.gd:176-192`) are the gates. **The beat DTOs, the record commands, and the latch behavior are all shipped and correct — Task 3 is verification + a light render polish, NOT a rebuild.** The once-per-profile nature is by design (a repeat death shows no beat; the SUMMARY outcome label — Task 2 — carries the closure for every run-end).

### AC2 — the F-2 fix: outcome label off `phase`, NOT `outcome_or_cause` (D6)

The live-flow blank-`outcome_or_cause` is a KNOWN, ratified v0 limitation, not a bug. `RunEndProfileBridge._summary_for(run)` builds `RunSummary.build(run, [])` with an **empty events list** (`run_end_profile_bridge.gd:178-179`) because v0 has **no run-level event store** (the orchestrator threads sequence ids + returns events per `ActionResult` but does not accumulate a run-wide log). `RunSummary._derive_outcome_or_cause` scans the events for the terminal `RUN_COMPLETED`/`RUN_FAILED` event; with `[]` it returns `&""` (`run_summary.gd:384-402`). So **`outcome_or_cause == ""` in the live flow**, but `phase` is always the honest terminal fact (`RunState.PHASE_COMPLETED := &"completed"` / `PHASE_FAILED := &"failed"`, `run_state.gd:34-35`; carried into `RunSummary.to_dictionary()["phase"]` via `run.phase` at `run_summary.gd:342`). **AC2's outcome label MUST key off `phase`** (D6; the standing deferred-work F-2 owner instruction, line 314: "a summary-render MUST key victory/death off `phase`, not `outcome_or_cause`").

- **The run-level event STORE stays DEFERRED (do NOT build it).** Threading the run's ordered events into the bridge so `passives_consumed`/`passives_destroyed`/`notable_loot`/`echoes_discovered`/`unlock_progress` + `outcome_or_cause` populate is a **later save-shape story** (deferred-work.md lines 295, 306-315, 332; the 12-2 T4 re-record, lines 138-142). 14.5 renders those lists **honestly empty/pending** (AC2's explicit "shown honestly as empty/pending rather than fabricated"). When that store lands, `outcome_or_cause` + the lists populate; until then the label keys off `phase`.

### The oath-shards-earned count — a SEPARATE deterministic read (not a summary-key change)

`RunSummary.profile_meta.oath_shards_earned` STAYS **0 / not_yet_supported** — the summary reads NO profile, and changing that DTO field would break the pinned 8.2/8.4 `not_yet_supported` contract (`run_summary.gd:130-132, 326-328`). The honest earned-this-run count is a **separate deterministic render-side read** via `MetaAwardRules.oath_shard_award_for(run)` (`meta_award_rules.gd:55-64`): a `PHASE_COMPLETED` run yields `min(BASE_AWARD + PER_NODE_AWARD * nodes_cleared, MAX_AWARD)` (consts 1/1/5, `meta_award_rules.gd:43-48`); a `PHASE_FAILED` (death) run yields 0. This is **exactly** what 14-9 AC1 later names ("the oath-shards-earned-this-run count (computed via the deterministic `MetaAwardRules` read) ... the earned count is a separate deterministic read, not a summary-key change").

- **[Review][Decision] — where to compute it (recommended default: the render seam, referencing MetaAwardRules consts).** The `OutpostRenderView` seam reads the summary DICT (it has no live `RunState`), and the earned amount is a pure function of `(phase, nodes_cleared)` gated on `meta_progression_eligible`, all present in `run_summary`. Recommended default: `run_oath_shards_earned()` computes it in the seam by referencing `MetaAwardRules.BASE_AWARD/PER_NODE_AWARD/MAX_AWARD` (so the NUMBERS are single-sourced) — **zero domain/save file touched, strictly presentation.** Alternative (only if you want the whole FORMULA single-sourced): add a pure additive `MetaAwardRules.oath_shard_award_for_facts(phase, nodes_cleared) -> int` helper that the existing `oath_shard_award_for(run)` delegates to and the seam calls — additive (no behavior/fingerprint change; `test_meta_award_rules.gd` stays green), but it touches a `scripts/save/` file (a slight scope expansion beyond "presentation + flow-nav"). **Recommended: keep it in the render seam (no MetaAwardRules edit).** A death or manual-seed run must render **0** (honest — a manual-seed run earns no meta; FR28).
- **Cross-story overlap flagged (14-5 ↔ 14-9):** both 14-5 AC2 and 14-9 AC1 name the earned count + nodes-cleared on the same (embedded-in-outpost) summary surface. **14-5 (Band 1) delivers the honest earned count NOW** (replacing "not yet tallied"), and **14-9 (Band 2) INHERITS it** — 14-9's outpost-cleanup scope is then the raw `[#]`/`[!]` marker removal, the named-space "coming later" affordances, and the notable-loot tally, NOT re-doing the earned count. Recorded so 14-9 does not double-implement.

### AC3 — Descend Again reroute (D3) + the 14.4 interaction

Today `outpost_presenter._on_descend_pressed()` (lines 292-334) builds an inline start request with an **empty `class_id`** (`String(&"")`, line 310) and calls `RunFlowController.new().start(seed, is_manual, "")` — the "legacy no-class start" that `OutpostViewModel.start_run_request` reports startable for an empty class (`outpost_view_model.gd:367-369`). A class-less live run then hits the `LiveCombatResolver` fail-open **`DEFAULT_HERO_HP = 60`** (`live_combat_resolver.gd:68,163`) instead of a class kit's 18 HP (FR6). **That is F4.** 14.5 replaces the direct start with a nav to hero-select (D3) so a real class is picked; the run is started at `hero_select_presenter._on_confirm_pressed` (which gates on a selected class and already routes the seed through the 14.4 `RunSeedSource` seam).

- **The 14.4 interaction (important — read before Task 4).** Story 14.4 wired `RunSeedSource` into BOTH live start sites, INCLUDING the outpost's `_on_descend_pressed` (the seed + `is_manual_seed` from the seam, plus the impure `_new_run_entropy()` line). **14.5 supersedes the outpost half of that**: once Descend Again reroutes to hero-select, the outpost no longer starts a run, so its seed logic (`RunSeedSource.resolve` + `_new_run_entropy` + the `controller.start` call) is **dead — remove it.** The F11 per-run variety for a re-descend is **preserved** because it now flows through hero-select's own `_new_run_entropy()` + `RunSeedSource` (unchanged by 14.5). This is not a regression of 14.4 — it is the natural convergence (one live seed source, at hero-select, for BOTH the initial descent and the re-descend). No 14.4 test pins `_on_descend_pressed` or the outpost seed (14.4 Task 5 confirmed "no test references `_on_descend_pressed`"), so the removal is safe.
- **The 14.4 outpost-variety `[Review][Defer]` is reconciled, not closed.** The standing 14-4 defer (F11 re-descend variety has no automated guard; owner: Band-1 on-device playtest) still holds — re-descend variety now rides hero-select's entropy path, and the on-device confirmation (boot ≥2× / re-descend ≥2× → different rooms) stays the Band-1 playtest's job.

### Anti-patterns to avoid (this story specifically)

- **Do NOT change `RunSummary`, `RunEndProfileBridge`, or any domain/command/event/RNG/save file.** 14.5 is presentation + flow-nav. The 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; the 7 named streams unchanged; `RunSummary.DICTIONARY_KEYS` / `not_yet_supported` UNCHANGED (the outcome label + earned count are render-side reads, not summary keys).
- **Do NOT build the run-level event store** (to populate passives/loot/`outcome_or_cause`). Show those lists honestly empty; it stays a deferred save-shape story.
- **Do NOT read `outcome_or_cause` for the outcome label** — it is `""` in the live flow. Key off `phase` (D6).
- **Do NOT read a presentation/combat log as summary source truth** (8.2 AC2 forbids it).
- **Do NOT rebuild the beats / the record commands / the latch.** They are shipped (8.5/9.4/11.5). Do NOT add a "skip command"; the dismiss is a pure no-op. Do NOT gate the beat on `meta_progression_eligible` (Option-A eligibility-independence).
- **Do NOT remove `DEFAULT_HERO_HP` / the driver fail-open** — it is the sanctioned hands-off/test driver default; only the LIVE Descend-Again path must route through a class.
- **Do NOT thread the profile into the standalone hero-select** to "fix" locked spend-unlocks reached via Descend Again — that is the deferred Necromancer/Shadeblade profile-threading concern (11.6/14.4). Out of scope.
- **Do NOT touch `OutpostViewModel.start_run_request` / `START_REQUEST_KEYS`** — the outpost no longer builds a start request (it navigates to hero-select).
- **Do NOT use eager `String(nullable)` in assert messages** (14.1 retro — it crashes on a null read and masks the real failure). Use `str(...)`.
- **Keep the false-PASS grep guard standing** — grep the raw runner output for `SCRIPT ERROR|Parse Error|^FAIL`; never trust the summary PASS line alone. Exactly the 6 documented stderr negatives; ZERO new.

## Project Structure Notes

- **Files touched (production):** `godot/scripts/ui/view_models/outpost_render_view.gd` (new render-decision methods — the summary outcome label / nodes-cleared / seed / earned count) and `godot/scripts/ui/presenters/outpost_presenter.gd` (the honest `_render_run_summary` + the Descend-Again reroute + removal of the dead outpost start/seed logic). Optionally a light heading polish on the reveal-beat render (same file).
- **Test:** extend `godot/tests/unit/ui/test_outpost_render_view.gd` (the existing render-decision unit test; beside the pattern for `OutpostRenderView`). No new SceneTree test — the outpost scene stays verified by construction + `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (which already loads `outpost.tscn`, line 42).
- **Assertable render decisions live in the scene-free `RefCounted` `OutpostRenderView` seam** (unit-tested); the presenter is thin glue verified by construction. No new autoload. No new `.gd` global class is strictly required (methods on an existing class) → no new `.gd.uid` sidecar unless you add a new seam file (then generate + commit its `.gd.uid`, the 13.1 discipline). 14.5 adds **no art**.
- `scripts/rules/{conditions,operations}` unchanged. No domain/command/event/save/RNG/generation/route/finale file is touched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (NFR14/NFR15).** The summary/beat render is a pure read over the session-bound `OutpostViewModel` (via `finalize_run_end()`); the descend affordance SUBMITS through the existing hero-select → `RunStartCommand` path. The UI owns no run truth and mutates no domain/profile state (the `RunEndProfileBridge` owns the run-end profile mutation; 14.5 renders the result + navigates).
- **Save truth = versioned domain snapshots (NFR15).** No save change: the 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; `ProfileSnapshot` unchanged; the earned count is a deterministic render read, not a persisted/summary field.
- **Named RNG only; deterministic under seed (NFR13).** 14.5 draws ZERO RNG (`MetaAwardRules` is deterministic and RNG-free; the render seams are pure reads). The 7 named streams (`map, level, combat, loot, rewards, events, cosmetic`) are unchanged, unreordered.
- **Assertable logic lives in scene-free `RefCounted` seams** (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload.
- **Difficulty is a hard non-goal.** 14.5 changes no enemy stat/HP/damage/reward/run-length number. (The 60→18 HP difference is a class-KIT correctness fix — routing to a real class — not a difficulty knob; `DEFAULT_HERO_HP` stays for the driver.)
- **Manual seed grants no meta (FR28).** The earned-count render shows 0 for a manual-seed run; the beat still shows (Option-A eligibility-independence). 14.5 does not change the FR28 eligibility model.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.5 touches only `scripts/ui/`; no fingerprint can move — including the 14.1-re-pinned combat replay at seed 24680). **14.5 re-pins NOTHING.**
- **Color-independence (NFR9).** The outcome label, tallies, seed, earned count, and beat all carry a text/icon channel, not color alone.
- **Headless suite stays green** (201 PASS baseline post-14.4; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Deferred-work overlaps folded in (only those that touch 14.5's area)

- **F-2 — the outpost run-summary outcome label (ADOPTED by 14.5).** `deferred-work.md` line 109 + 316-321: "`outpost_presenter._render_run_summary` renders only the 'not yet tallied' note ... a summary-render MUST key the label off `phase`, not `outcome_or_cause`." Owner named as "the run-level event-store / summary-render story." **14.5 is that summary-render story for the LABEL** (D6) — it renders the outcome label off `phase`. It does NOT build the event store.
- **The live-flow `outcome_or_cause` is BLANK (Med, deferred-work lines 306-315; 12-2 T4, lines 138-142) — RECONCILED, not resolved.** 14.5 keys the label off `phase` (the instructed workaround); the store that populates `outcome_or_cause` + the passives/loot/discovery lists stays deferred. 14.5 shows those lists honestly empty.
- **The run-level event STORE for a full RunSummary (deferred-work lines 295, 332) — stays DEFERRED (NOT 14.5's).** Explicitly out of scope; do not reopen.
- **The 14.4 outpost re-descend variety `[Review][Defer]` (deferred-work.md line 5) — RECONCILED.** Re-descend variety now flows through hero-select's seed source after the D3 reroute; the on-device confirmation stays the Band-1 playtest's job.
- **The full-backpack reward escape hatch (deferred-work.md line 59; 13-2) is NOT 14.5 — it is Story 14.7.** The reward-overlay geometry + passive `display_name` (13-2, lines 60/69) are NOT 14.5 — they are Story 14.11. Do not pull them in.

### Epic-14 constraints inherited (retro-notes/epic-14.md + the sprint change)

- **EXACT files (14.1 "wrong files" precision):** the run-end surface is `outpost_presenter.gd` + `outpost_render_view.gd` + `outpost.tscn` — NOT `run_end_presenter.gd` (a non-terminal dead-end since 11.5).
- **Render from the bound session, not empty presenter state (14.3 systemic):** the summary/beat read the session-bound `OutpostViewModel` via `finalize_run_end()`.
- **Seams expose only what the presenter consumes (14.3):** the new render-decision methods surface only the summary facts the presenter renders — no forward-looking dead output.
- **`str(...)` not eager `String(nullable)` in assert messages (14.1).** The false-PASS grep guard stays standing; exactly 6 documented stderr negatives (the 14-4 retro corrects the attribution: int64-overflow ×1 in `test_manual_seed_loader.gd:153` + ×1 in `test_domain_event.gd:146`, not ×2 in the loader).
- **EPIC-LEVEL RISK (14.4 retro):** Band-1 stories defer their user-facing verification to the pending on-device playtest — 14.5's death/victory MOMENT feel, the summary readability, and the Descend→hero-select→18-HP flow are **automated-green but human-unverified**; add them to the Band-1 on-device playtest checklist (confirm the death line renders, the outcome label + tallies are legible, and Descend Again lands on hero-select and starts an 18-HP class run).
- **Difficulty stays a hard non-goal; 14.5 re-pins nothing; no new autoload; scenes verified by construction + the compile guardrail.**

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **201 PASS** (post-14.4); expect **≥201 PASS**, ZERO new stderr negatives beyond the 6 documented.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` — Story 14.5 ACs (body lines 3069-3090); Epic List entry (521-527); Band-1 demarcation (2971); FR60/FR61/FR62/FR65 (142-152); the 14-9 outpost-cleanup overlap (3163-3183).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` — F5 hard-cut death + F4 class-less Descend Again (lines 19-21); **D3 Descend→hero-select routing** (line 105); **D6 outcome off `phase`** + the 14.5 scope row (line 135); the F-2→14.5 mapping (line 166).
- `_bmad-output/implementation-artifacts/deferred-work.md` — the F-2 outcome-label item (line 109); the Med "outcome_or_cause blank → key off `phase`" (306-315); the run-level event STORE non-adoption (295, 332); the 12-2 T4 re-record (138-142); the 14.4 re-descend variety defer (line 5).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — the 14.1 "wrong files to touch" SM precision; the `str(...)`-not-`String(nullable)` note; the 14.3 render-from-session systemic + seams-expose-only-consumed; the 14.4 stderr-negative attribution correction.
- `_bmad-output/implementation-artifacts/14-4-per-run-seed-variation.md` — the ratified Epic-14 presentation-only story shape, the RefCounted-seam pattern, the false-PASS grep discipline, the 201 PASS baseline, and the `RunSeedSource` seam 14.5 leaves in hero-select.
- Source files (read before implementing):
  - `godot/scripts/ui/presenters/outpost_presenter.gd` — `_render_run_summary` (160-172, the thin F-2 panel); `_render_reveal_beat` (178-197) + the beat render (108-111); `_on_descend_pressed` (292-334, the class-less direct start); `_new_run_entropy` (353-362) + the `RunSeedSource` preload (27) to remove; `_build_render_view` (71-79, session-sourced).
  - `godot/scripts/ui/view_models/outpost_render_view.gd` — `shows_run_summary` (170-171); the beat gates (176-192); `awarded_oath_shards` (144-145); `summary_oath_shards_earned`/`summary_oath_shards_not_yet_tallied` (151-165); where the new summary render-decision methods land.
  - `godot/scripts/run/run_summary.gd` — `DICTIONARY_KEYS` (84-95, UNCHANGED); `phase`/`seed`/`meta_progression_eligible` fields; `not_yet_supported` (130-132, UNCHANGED); `to_dictionary` (359-373); the blank-`outcome_or_cause` derivation (384-402).
  - `godot/scripts/run/run_state.gd` — `PHASE_COMPLETED := &"completed"` / `PHASE_FAILED := &"failed"` (34-35); `is_terminal` (215-216).
  - `godot/scripts/save/meta_award_rules.gd` — `oath_shard_award_for(run)` (55-64); the public consts `BASE_AWARD`/`PER_NODE_AWARD`/`MAX_AWARD` (43-48).
  - `godot/scripts/ui/flow/run_end_profile_bridge.gd` — `build_outpost` (96-172, load→record latch→persist→build); `_summary_for` = `RunSummary.build(run, [])` (178-179, the empty-events build → blank `outcome_or_cause`).
  - `godot/scripts/ui/flow/run_flow_controller.gd` — `finalize_run_end` (243-245) → `bridge.build_outpost(_orchestrator.run, _orchestrator)`; `start` (106).
  - `godot/scripts/ui/flow/run_flow_router.gd` — the stage table + the `outpost` destination → `outpost.tscn` (44-63); `run_end` as the non-terminal dead-end (30-31,49).
  - `godot/scripts/ui/view_models/outpost_view_model.gd` — `DICTIONARY_KEYS` (88-103, 14 keys, UNCHANGED); `first_death_beat`/`first_victory_beat`/`run_summary` accessors (334-347); `start_run_request` + `START_REQUEST_KEYS` (162-173, 366-376, DO NOT TOUCH).
  - `godot/scripts/ui/presenters/hero_select_presenter.gd` — `_on_confirm_pressed` (99-128, the class-ful start via the 14.4 seed seam); the profile-unaware `HeroSelectViewModel.new()` (32, the accepted Descend-Again-locked-unlock limitation).
  - `godot/scripts/run/live_combat_resolver.gd` — `DEFAULT_HERO_HP := 60` (68) + its default param (163) — the class-less fail-open (F4); KEEP it (driver default).
  - `godot/scripts/run/first_death_narrative_beat.gd` / `first_victory_reveal_beat.gd` — `FIRST_DEATH_LINE` (60) / `FIRST_VICTORY_LINE` (63); the read-only `for_first_death`/`for_first_victory` + `to_dictionary`.
  - Tests: `godot/tests/unit/ui/test_outpost_render_view.gd` (extend — the render-decision pattern); `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the compile guardrail, loads `outpost.tscn` at line 42).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story)

### Debug Log References

### Completion Notes List

### File List

### Review Findings

## Change Log

| Date | Version | Description | Author |
|---|---|---|---|
| 2026-07-18 | 0.1 | Story context created (gds-create-story). Presentation + flow-nav over shipped DTOs: (AC1) verify/harden the shipped first-death/first-victory reveal beat render on the outpost landing (skippable no-op, non-blocking — 11.5 shipped it); (AC2, F-2/D6) render the honest run-summary — the victory/death outcome LABEL keyed off `run.phase` (NOT the live-blank `outcome_or_cause`), nodes cleared, seed, and the oath-shards-earned-this-run count (a separate deterministic `MetaAwardRules` render read, 0 for death/manual-seed) — replacing the "not yet tallied" panel, with the deferred passives/loot lists shown honestly empty; (AC3, F-4/D3) reroute the outpost "Descend Again" through the hero-select stage so a real 18-HP class is chosen (never the class-less 60-HP driver default), removing the now-dead outpost start/seed logic 14.4 wired. NO domain/command/event/RNG/save change — the 23-key `RunSnapshot` gate stays 23, `SCHEMA_VERSION == 1`, 7 named streams, `RunSummary`/8.2 contract UNCHANGED; every fingerprint byte-identical; 14.5 re-pins nothing. 14-5↔14-9 earned-count overlap + the run-level event-store non-adoption flagged. Status → ready-for-dev. | Claude Opus 4.8 (gds-create-story) |
