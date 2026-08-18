---
baseline_commit: cb1279c
---
# Story 15.5: Run Economy, HP Persistence and Event-Node Outcomes

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **⚠ THE SLUG UNDERSELLS THIS STORY.** The sprint-status key is `15-5-event-node-and-run-summary-wiring`, but the CANONICAL definition (`epics.md` §"Story 15.5: Run Economy, HP Persistence and Event-Node Outcomes", lines 3341–3369 — the file `sprint-status.yaml` declares as its `source_epics_file`) is BROADER. It carries **FOUR** acceptance criteria across two ratified design reversals plus two wiring gaps: **D1 (HP persists between nodes)**, **D4 (a death awards Oath Shards)**, the **event-node outcome surface**, and the **run-summary earned/nodes-cleared wiring**. D1 + D4 are IN SCOPE here (15.4's context fenced "HP-persistence (D1) + shards-on-death (D4) → 15.5" and 15.5's own AC1 says the persisted HP "survives a quit/resume (15.4)" — i.e. 15.5 *consumes* 15.4's resume seam). Do NOT silently drop them because the slug omits them.

## Story

As a player,
I want my wounds to carry between fights and my runs to actually pay out,
so that the risk economy means something and unlocks are reachable.

> Carries ratified decisions **D1** (HP persists) and **D4** (shards are awarded on death). Both are deliberate design **reversals** of current shipped behaviour, not defect fixes — each updates the RULE **and** its existing tests **in the same change**.

## Context & Why This Story Exists

Epic 15 ("Playtest Response") is the third pre-ship playtest-response epic (`sprint-change-proposal-2026-07-24.md`), added after the post-Epic-14 agent playtest confirmed the loop is completable but surfaced 20 findings. Band 2 (Correctness & unwired surfaces, 15.2–15.7) fixes the things that are *wrong* or *not wired*. 15.2 corrected the attack-preview number; 15.3 made threats telegraph; 15.4 wired quit/pause/resume over the shipped save seams. **15.5 makes the RUN ECONOMY real:** wounds now carry between fights, a death now pays out, an event node now shows the player what it did, and the run summary now reports the truth instead of zeros.

**The four findings, each grep-verified against source:**

1. **HP does not persist between nodes (D1).** There is **NO run-level current-HP field** anywhere. `RunState` has `selected_class_id` + `starting_kit` but no `current_hp` (grep-verified: `run_state.gd` has zero HP/health members). Every node's live fight arms the hero from `CombatLoadout.for_run(run).hp` — the kit baseline (18 for all three MVP classes) or the 60 HP driver default for a kit-less run (`combat_loadout.gd:70-73`). `LiveCombatResolver.resolve(...)` takes `hero_hp` as a **driver-supplied parameter** (`live_combat_resolver.gd:163`) and the hero's **ending HP is on the returned board (`combat.metadata.board`) but is DISCARDED** — the next node re-arms from the kit baseline. `RunFlowController.hero_hp()` itself documents the gap: *"there is still NO run-level HP field and the in-node fight stays EPHEMERAL"* (`run_flow_controller.gd:130-131`). Result: the hero is implicitly full-healed between every node, so attrition — a core GDD difficulty source — does not exist.

2. **A death awards nothing (D4).** `MetaAwardRules.oath_shard_award_for(run)` returns **0 for `PHASE_FAILED`** (`meta_award_rules.gd:58-60` — the explicit Story-8.3 `[Decision]`). A completed run awards `min(BASE(1) + PER_NODE(1) * nodes_cleared, MAX(5))`. D4 REVERSES the 8.3 death-awards-zero decision: a death now awards on the same bounded, capped, nodes-cleared basis.

3. **An event node resolves invisibly (AC3).** The full risk/reward event machinery exists (Epic 7: `EventOffer`, `EventViewModel`, `ChooseEventOptionCommand` — which applies the gold/healing/curse/corruption tradeoff, raises risk flags, and emits `event_resolved` + `economy_changed` [+ `curse_applied`] events) but is **NOT wired into the live flow**. When the player picks an event node, `route_map_presenter._on_choice_picked` (`route_map_presenter.gd:315-324`) calls `orchestrator.resolve_current_node_live()`, which for a non-combat node runs `NodeResolvePlaceholderCommand` — a **placeholder clear+exit round-trip** — then re-renders the map. The event never presents an offer, the player never chooses, and nothing changes: the node just becomes "cleared" (a counter increment). The orchestrator itself flags this: *"A later HUD/run-flow story owns the 'enter event node → [present offer, choose, apply]'"* (`run_orchestrator.gd:601-602`). **15.5 is that story.**

4. **The run summary reports zeros (AC4).** `RunSummary.build(run, [])` is built with an **empty events list** in the live flow (`run_end_profile_bridge.gd:178-179`), so `notable_loot` / `passives_consumed` / `passives_destroyed` come out empty — an honest v0 limitation *pending the deferred run-level event store*. And `RunSummary.profile_meta.oath_shards_earned` is **hardcoded 0 / `not_yet_supported`** (`run_summary.gd:130-132, 326-328`). `nodes_cleared` IS already real (`run_summary.gd:287`). Story 14.5 added a render-side earned-count read (`outpost_render_view.run_oath_shards_earned()`, `outpost_render_view.gd:230-237`) — but it is **gated on `is_completed`**, so a death honestly shows 0 there too, and it **re-derives the amount in a SECOND place** (see the CRUX desync warning).

### ⭐ THE CRUX — read before Task 1

**Five boundaries define this story. The first is the single most consequential judgement call in the epic to date.**

#### CRUX-1 — D1 REQUIRES A SAVE-SCHEMA CHANGE. Say it out loud; do NOT pretend the gate absorbs it silently.

AC1 states, verbatim: *"the persisted HP survives a quit/resume (15.4)."* **The word "persisted" is load-bearing.** HP that survives a quit/resume MUST live in the `RunSnapshot`. `RunState` has no current-HP field today, so **D1 adds new persisted run state.** That is unavoidable, and it means the save schema IS changing. Do NOT hand-wave it.

**Two mechanisms, both a genuine schema change; the dev must choose deliberately and test it:**

- **Mechanism A (RECOMMENDED — keeps the top-level 23-key gate at 23, satisfying AC4's "23-key gate holds"):** add `current_hp` to `RunState` and **NEST it inside `route_state`** in `to_run_snapshot_fields()` (`run_state.gd:356-393`) — the EXACT mechanism `run_phase`, `selected_class_id`, and `risk_economy` already use to ride the route-position save without a new top-level key. Read it back in `try_from_run_snapshot_fields` (and in the full-dict `to_dictionary`/`try_from_dictionary` path) with a **lenient default** (an absent `current_hp` → fall to the kit baseline = today's behaviour). The top-level `RunSnapshot` `to_dictionary()` STAYS 23 keys; `SCHEMA_VERSION` MAY stay 1. **BUT this is still a schema change to the persisted `route_state` sub-shape**, so a **migration / back-compat test is MANDATORY** (an old save whose `route_state` has no `current_hp` restores at full/baseline HP; a new save round-trips the persisted HP through `from_route_position` → `resume_route_position`).

- **Mechanism B (heavier — a NEW top-level `RunSnapshot` key):** gate goes 23 → 24, `SCHEMA_VERSION` 1 → 2, and — critically — `RunSnapshot.parse()` uses a **hard-equality gate** (`run_snapshot.gd:72-77`: `if schema_value != SCHEMA_VERSION: return unsupported_save_schema`), so a bump to 2 REJECTS every existing v1 save unless `parse()` gains a v1→v2 migration branch. This **contradicts AC4's "23-key `RunSnapshot` gate holds"** and is NOT recommended.

**Whichever mechanism: a `SCHEMA_VERSION`/migration decision is real, must be deliberate, and MUST ship a migration test** (project rule, `AGENTS.md` §Testing Expectations: *"Save snapshots need migration tests for schema changes"*). The default recommendation is **Mechanism A** (nest `current_hp` in `route_state`, keep the 23-key gate + `SCHEMA_VERSION == 1`, add a back-compat/migration test) — but the dev owns and documents the call.

#### CRUX-2 — HP persists at NODE BOUNDARIES over the between-node route-position seam; the in-node fight stays EPHEMERAL (the `deferred-work.md:418` constraint STANDS — do NOT reopen it).

The between-node route-position save is 15.4's seam (`compose_route_position_snapshot` → `autosave_route_position`; `resume_route_position` → `start_from`). HP rides THAT boundary, not a mid-fight save. Concretely: capture the hero's **ending HP when a combat node CLEARS** (`finish_interactive_combat_node` on victory, `run_orchestrator.gd:1273-1277`; and the hands-off-live `resolve_combat_node_live` victory branch, `:1094-1098`) into `run.current_hp`; feed `run.current_hp` (not the kit baseline) as `hero_hp` into the **next** node's fight; persist it at the route-position boundary. A **mid-fight quit → resume RE-ENTERS the un-cleared node at its ENTRY HP** (the ephemeral fight is discarded, exactly as 15.4 established) — HP does NOT persist mid-fight. This keeps the 23-key gate honest, does NOT add a mid-encounter save, and does NOT reopen `deferred-work.md:418`.

#### CRUX-3 — D4 changes the award amount in ONE authority, but the amount is CURRENTLY COMPUTED IN TWO PLACES. Collapse the desync (the 15-2 "damage computed in two places" lesson, applied here).

The award lives in `MetaAwardRules.oath_shard_award_for(run)` (the domain rule) **and is re-derived** in `outpost_render_view.run_oath_shards_earned()` (`outpost_render_view.gd:230-237`, `clampi(BASE + PER_NODE * nodes_cleared, 0, MAX)` gated on `is_completed`). If D4 changes only `MetaAwardRules` (death now awards) but leaves the render re-derivation gated on `is_completed`, **the summary will show 0 for a death while the rule says non-zero** — a live desync. Update BOTH in lockstep; PREFER making the render read single-source from `MetaAwardRules` (or the shared `BASE_AWARD/PER_NODE_AWARD/MAX_AWARD` consts + the same terminal-phase gate) so the number is authoritative in one place. Test-lock that the render earned-count == the rule's `oath_shard_award_for(run)` for both a completed AND a failed run.

#### CRUX-4 — EVERY change rides the LIVE path only; every pinned seed-regression fingerprint stays byte-identical (Epic-15 standing constraint: "Epic 15 moves NO fingerprint").

"No fingerprint" means the deterministic combat/generation/route/finale **seed-regression replay** artifacts — NOT the save schema (which CRUX-1 changes deliberately). All four parts are fingerprint-safe **because they touch only live/interactive paths, never the hands-off `run_to_completion` auto-resolve driver the fingerprints ride:**
- **D1 HP:** the hands-off smoke driver `play_hands_off_to_run_end` uses `DEFAULT_HERO_HP` (60), **decoupled** from the kit/HP (`run_flow_controller.gd:167-173`); `run_to_completion` (default auto-resolve) resolves combat WITHOUT a board/HP. No pinned artifact reads `run.current_hp`. Draw ZERO gameplay RNG for HP capture (it is a board read).
- **D4 award:** `MetaAwardRules` is **pure, zero-RNG** (`meta_award_rules.gd:5-8`), downstream of the run outcome; it feeds no replay. Changing the death-award VALUE changes `MetaAwardRules`/award tests, NOT a seed-regression replay hash. **VERIFY** no seed-regression / finale fixture asserts a death award of 0 as part of a pinned hash (if one does, it is an EXPECTED test update per D4, not a fingerprint move — but confirm it is an award assertion, not a combat/route replay hash).
- **AC3 event node:** `generate_event_offer` draws the `events` stream, but ONLY on the LIVE path you are wiring; the hands-off driver still resolves events via `NodeResolvePlaceholderCommand` (no `events` draw). Wire it live-only, exactly as 15.4 wired affinity/kit live-only.
- **AC4 summary:** pure reads.

#### CRUX-5 — Do NOT pull in the affinity-frequency rebalance, the run-level event store, or reopen the settled defers.

The depth-scaled affinity-frequency spec (20% → 40% ceiling, `deferred-work.md` §"Deferred from: story 15-4 scope decision (2026-08-17)") is **explicitly a FUTURE story — OUT OF SCOPE for 15.5.** The run-level event store (`deferred-work.md:447/458/1004`) STAYS deferred — AC4 says the loot/passive lists it feeds are "pending the deferred run-level event store" → **honestly label them, do NOT build the store.** Do NOT reopen `re_derive_kit` profile-awareness (`:396`) or the mid-encounter save (`:418`).

### The load-bearing architecture reality (grep-verified — read before Task 1)

**D1 — the HP seam:**
- `RunState` — NO current-HP member; `selected_class_id` (`run_state.gd:70`) + `starting_kit` (`:79`) are the only run-level hero fields. `to_run_snapshot_fields()` (`:356-393`) nests `run_phase`/`selected_class_id`/`risk_economy` inside `route_state` (the no-new-top-level-key mechanism to copy for `current_hp`). `try_from_run_snapshot_fields` (`:461-520`) reconstructs from those nested fields (`starting_kit` is re-derived, not persisted — `:515`).
- `CombatLoadout.for_run(run)` (`combat_loadout.gd:70-73`) → `run.starting_kit.baseline_hp` (18) or the 60/sword driver default. **The `hp` source the next node's fight should override with `run.current_hp`.**
- `RunFlowController.hero_hp()` (`run_flow_controller.gd:132-133`) → `CombatLoadout.for_run(run).hp` — the live/interactive loadout arming. **CHANGE this to prefer `run.current_hp` (falling back to the kit baseline when HP is unset — the first node / a legacy run).**
- `LiveCombatResolver.resolve(..., hero_hp, ...)` (`live_combat_resolver.gd:159-249`) — `hero_hp` is the driver-supplied starting HP; the hero's ending HP is `combat.metadata.board.get_entity("hero").hp`. **The capture source.**
- Capture loci: `finish_interactive_combat_node` victory (`run_orchestrator.gd:1273-1277`, the interactive/on-screen path) and `resolve_combat_node_live` victory (`:1094-1098`, the hands-off-LIVE path). The boss fight (`auto_play_boss_fight`, `:1412`) should ENTER at `run.current_hp` on the live path too.
- `play_hands_off_to_run_end` (`run_flow_controller.gd:166-173`) — the fingerprint-critical hands-off driver; uses `DEFAULT_HERO_HP`. **Do NOT thread `current_hp` here.**

**D4 — the award seam:**
- `MetaAwardRules.oath_shard_award_for(run)` (`meta_award_rules.gd:55-64`) — the `if run.phase != PHASE_COMPLETED: return 0` early-return (`:59-60`) is the death-awards-zero gate to REVERSE. Consts `BASE_AWARD=1` / `PER_NODE_AWARD=1` / `MAX_AWARD=5`.
- `AwardMetaProgressCommand` (`award_meta_progress_command.gd:125`) is the APPLICATION gate (eligibility + idempotency + zero-RNG); it calls `oath_shard_award_for`. **NOTE (awareness — see Open Questions): it is NEVER called in production `scripts/` — `RunEndProfileBridge` explicitly does not drive it (`run_end_profile_bridge.gd:55`).** So the profile never accrues shards in the live flow today. D4's literal scope is the RULE + its tests + the DISPLAY (AC4); wiring the APPLICATION is a scope decision flagged below.
- `outpost_render_view.run_oath_shards_earned()` (`outpost_render_view.gd:230-237`) — the CRUX-3 second place; single-source it from the rule.

**AC3 — the event seam:**
- `route_map_presenter._on_choice_picked` (`route_map_presenter.gd:288-324`) — non-combat pick → `resolve_current_node_live()` (placeholder). **The fix locus: detect an `event` node and route it through present-offer → choose → apply → outcome-surface instead of the silent placeholder.**
- `RunOrchestrator.generate_event_offer(...)` (`run_orchestrator.gd:606-665`) — the `events`-stream offer roll (caller-driven, live-only). Sets `run.pending_event_offer`.
- `EventViewModel.project_event(event_id)` (`event_view_model.gd:72`) — the BEFORE-choice modal projection (exact `MODAL_KEYS`/`CHOICE_KEYS`).
- `ChooseEventOptionCommand` (`choose_event_option_command.gd`) — applies both sides, emits `event_resolved` + `economy_changed` (+ `curse_applied`); its `ActionResult` metadata carries `gold_before/after`, `healing_before/after`, `curse_before/after`, `corruption_before/after`, `risk_flags`, `applies_curse` (`:271-285`). **This IS "the event node's existing resolution data" the AC3 outcome surface reads.**

**AC4 — the summary seam:**
- `RunSummary` (`run_summary.gd`) — `nodes_cleared` real (`:287`); `oath_shards_earned` hardcoded 0 + in `NOT_YET_SUPPORTED_FIELDS` (`:130-132`); `notable_loot`/`passives_*` derived from the (empty in live) events list. **Its pinned `DICTIONARY_KEYS`/`NOT_YET_SUPPORTED_FIELDS` are locked by `test_run_summary.gd` — changing the DTO field non-zero would break that pinned contract; the earned count is wired RENDER-SIDE (`outpost_render_view`), not by mutating the DTO field (the 8.4/14.5 posture).**
- `outpost_render_view` (`outpost_render_view.gd`) — `summary_nodes_cleared()` (real), `run_oath_shards_earned()` (CRUX-3), `summary_notable_loot()` (`:247-250`, honestly "— none —" today). The run summary renders at the OUTPOST via `RunEndProfileBridge.build_outpost → OutpostViewModel → outpost_presenter/outpost_render_view`.
- `DomainEvent` enum (`domain_event.gd:6`) — if AC4's "any new event" clause fires (likely NOT needed — the event node reuses `event_resolved`/`economy_changed`), it MUST **append at the enum tail, never renumber** (the 14.1 `hero_waited` / 14.7 `reward_declined` precedent, `domain_event.gd:95-99`).

## Acceptance Criteria

**AC1 — HP carries between nodes and survives quit/resume; no implicit full heal (ratified decision D1; GDD economy; FR-run-economy)**
Given a hero finishes a combat node below maximum HP
When the run advances to the next node
Then the hero's current HP **CARRIES OVER unchanged** — there is **no implicit full heal between nodes** — so resource attrition is a real difficulty source per the GDD economy section
And HP is restored **only by defined sources** (consumables and any explicitly defined rest/heal moment — no new heal source is invented here), and **the persisted HP survives a quit/resume** through the existing 15.4 route-position save/resume seam (`compose_route_position_snapshot` → `autosave_route_position`; `resume_route_position` → `start_from`); a mid-fight quit re-enters the un-cleared node at its ENTRY HP (the in-node fight stays ephemeral — `deferred-work.md:418` not reopened)
And the between-level/route-position save carries `current_hp` through the EXISTING restore seam, with a **migration/back-compat test** proving an old save (no persisted HP) restores at full/baseline HP.

**AC2 — A death awards Oath Shards on the same bounded, capped, deterministic basis as a completed run (ratified decision D4; FR28/FR59)**
Given a run ends in the hero's death
When the meta award is calculated
Then the run awards Oath Shards on the **same bounded, capped, deterministic basis** as a completed run — the award **scales with nodes cleared and remains capped** — REVERSING the Story-8.3 decision that a failed run awards nothing
And `MetaAwardRules` **and every test asserting the old death-awards-zero behaviour are updated together in the same change**, the award stays **pure/deterministic/zero-RNG**, **manual-seed runs remain ineligible**, and the award remains **idempotent** (no double-award); the render-side earned-count (`outpost_render_view.run_oath_shards_earned`) is updated in lockstep so the summary shows the death award (CRUX-3 single authority).

**AC3 — An event node shows what happened before returning to the route; it never resolves invisibly (FR54; NFR9)**
Given the player resolves an event node
When the node completes
Then the player is **shown what happened and what changed** (the gold/healing/curse/corruption deltas and any raised risk flags) **before returning to the route** — an event node **never resolves invisibly into a route-screen counter increment**
And the outcome surface **reads from the event node's existing resolution data** (the `ChooseEventOptionCommand` result metadata / `event_resolved` + `economy_changed` events — no new domain data invented), the event interaction rides the LIVE path only (the hands-off driver's placeholder resolution is untouched, so no fingerprint moves), and the surface is legible at the 2.0x text scale with ≥44px targets (on-screen legibility → OSG-1; the decision/projection logic is test-locked on a scene-free seam).

**AC4 — The run summary reports the real earned shards and nodes cleared; unpopulated lists are honestly labelled (FR60; FR28)**
Given a run ends and the summary renders
When the player reads it
Then the summary reports the **real Oath Shards earned this run** (the same amount `MetaAwardRules.oath_shard_award_for(run)` grants, honoring D4 for a death) and the **real nodes cleared**, and any list it cannot yet honestly populate (notable loot, passives spent/destroyed — **pending the deferred run-level event store**, which STAYS deferred) is **either populated or honestly labelled as not-yet-recorded rather than shown as an empty result**
And the **23-key `RunSnapshot` gate holds** (D1's `current_hp` rides inside the existing `route_state`, adding NO top-level key — CRUX-1 Mechanism A), **any new `DomainEvent` is append-only at the enum tail and wired end-to-end** (likely none needed — the event node reuses `event_resolved`/`economy_changed`), and **no pinned seed-regression fingerprint moves** (every change rides the live path; the hands-off auto-resolve driver is byte-identical).

## Tasks / Subtasks

- [x] **Task 1 — Confirm the four gaps and pin the fix loci; make the D1 schema decision explicitly (AC1, AC2, AC3, AC4)**
  - [x] Read the seams in "The load-bearing architecture reality" and confirm: no run-level current-HP field; ending HP is discarded; `MetaAwardRules` returns 0 for `PHASE_FAILED`; the event node resolves via `NodeResolvePlaceholderCommand`; `RunSummary.oath_shards_earned` is 0/`not_yet_supported`; the earned count is re-derived in `outpost_render_view`. (The retro P4 "grep/repro the live surface before scoping" habit.)
  - [x] **DECIDE D1's persistence mechanism (CRUX-1) and record it in the Dev Agent Record:** default = Mechanism A (nest `current_hp` in `route_state`, top-level gate stays 23, `SCHEMA_VERSION == 1`, lenient default + back-compat/migration test). If Mechanism B (new top-level key + `SCHEMA_VERSION` bump + `parse()` migration branch) is chosen, justify why AC4's "23-key gate holds" is being reinterpreted. Do NOT proceed to Task 2 without this decision written down.

- [x] **Task 2 — D1: persist and carry current HP between nodes (AC1)**
  - [x] Add `current_hp` to `RunState` (an int; an unset/sentinel value means "use the kit baseline" — the first-node / legacy-save default). Include it in `to_run_snapshot_fields()` (nested in `route_state`) and the full-dict `to_dictionary()`; read it back leniently in `try_from_run_snapshot_fields` **and** `try_from_dictionary` (absent → unset → kit baseline). NO new top-level `RunSnapshot` key (Mechanism A).
  - [x] Capture the hero's **ending HP** from the cleared node's board into `run.current_hp` at the victory boundary of `finish_interactive_combat_node` (interactive) and `resolve_combat_node_live` (hands-off-live). A pure board read — draw ZERO RNG.
  - [x] Change `RunFlowController.hero_hp()` to prefer `run.current_hp` when set, falling back to `CombatLoadout.for_run(run).hp` (kit baseline) when unset. Ensure the live boss fight (`auto_play_boss_fight`) enters at `run.current_hp` on the live/interactive path. **Do NOT touch `play_hands_off_to_run_end` / `run_to_completion` / `DEFAULT_HERO_HP`** (the fingerprint path).
  - [x] Confirm HP is restored ONLY by defined sources — do NOT add an implicit heal; a between-node advance carries HP unchanged. (Consumable/rest heal sources are existing/out-of-scope; this story must not full-heal.)

- [x] **Task 3 — D4: a death awards Oath Shards, updating the rule and its tests together (AC2)**
  - [x] In `MetaAwardRules.oath_shard_award_for`, REVERSE the `PHASE_FAILED → 0` gate so a death awards on the same `min(BASE + PER_NODE * nodes_cleared, MAX)` basis as a completion (the AC's "same bounded, capped, deterministic basis"). Keep it pure/zero-RNG. Update the class docstring `[Decision]` (`meta_award_rules.gd:24-26, 58`) to record the D4 reversal.
  - [x] **Grep for and update EVERY test asserting death-awards-zero in the same change** (candidates: `test_meta_award_rules.gd`, `test_award_meta_progress_command.gd`, and any finale/full-run/live-run test asserting a death award of 0 — `test_finale_full_run.gd`, `test_live_run_flow.gd`, `test_run_orchestrator.gd`). This is a deliberate contract inversion, not a weakened test — assert the NEW capped death award. (The 15-2 "update the rule AND its tests" + the 15-4 Phase-7 "a delegate can encode its own scope-cut into the test" lesson — assert the real new behaviour, no SKIP.)
  - [x] Update `outpost_render_view.run_oath_shards_earned()` in lockstep (CRUX-3): remove the completed-only gate so a death shows its award; single-source the amount from `MetaAwardRules.oath_shard_award_for(run)` (or the shared consts + the same terminal gate) so the number is authoritative in ONE place. Keep the manual-seed/eligibility gate (a manual-seed run still earns 0).

- [x] **Task 4 — AC3: wire the live event node to present, resolve, and SHOW its outcome**
  - [x] In the live flow (`route_map_presenter._on_choice_picked` for an `event`-type node, or an orchestrator live-event seam it drives), replace the silent `NodeResolvePlaceholderCommand` path with: `generate_event_offer` (the `events`-stream roll, live-only) → present the offer via `EventViewModel` → apply the picked choice via `ChooseEventOptionCommand` → **render an outcome surface** (the gold/healing/curse/corruption before/after deltas + raised risk flags, read from the choose command's result metadata / the `event_resolved`+`economy_changed` events) → then resolve/exit the node and return to the map. Keep the domain/RNG on the LIVE path only.
  - [x] Put the testable projection on a **scene-free `RefCounted` seam** (an event-outcome view model with an exact pinned key set — the deltas + flags), unit-tested; the modal/outcome scene render is verified by construction + `test_run_flow_scenes_load.gd` → OSG-1. (No SceneTree presenter test — the ratified posture.)
  - [x] Preserve the no-soft-lock partition: an event node still ALWAYS resolves (a decline/safe choice is a valid resolution); a rejected/failed choice fails closed with a visible cue, never a silent stall (the 14.6 posture).

- [x] **Task 5 — AC4: wire the run summary to the truth (earned shards, nodes cleared, honest labels)**
  - [x] Confirm `nodes_cleared` renders the real count (already true — `run_summary.gd:287` → `outpost_render_view.summary_nodes_cleared`). Confirm the earned-shard render now reflects D4 (Task 3) for BOTH a completed and a failed run.
  - [x] Make the unpopulated lists HONEST: `notable_loot` / `passives_consumed` / `passives_destroyed` come out empty in the live flow (empty events list, the still-deferred run-level event store). Ensure the presenter labels them **"not yet recorded"** (or equivalent) rather than an empty result that reads as "nothing happened / you looted nothing." Do NOT build the run-level event store (it STAYS deferred — `deferred-work.md:447/1004`).
  - [x] Do NOT mutate `RunSummary.DICTIONARY_KEYS` / `NOT_YET_SUPPORTED_FIELDS` / `profile_meta.oath_shards_earned` (pinned by `test_run_summary.gd`) — wire the earned count render-side (`outpost_render_view`), the 8.4/14.5 posture. If a new `DomainEvent` is genuinely needed, append at the enum tail + wire end-to-end (`to_dictionary`/`try_from_dictionary` round-trip + a test).

- [x] **Task 6 — Tests: test-lock every headlessly-provable correctness; leave scene render to OSG-1 (AC1, AC2, AC3, AC4)**
  - [x] **D1 round-trip + migration (highest-value):** (a) an old save whose `route_state` has NO `current_hp` restores at full/baseline HP (the back-compat/migration test — MANDATORY per the project rule); (b) a run with a persisted `current_hp` round-trips it through `from_route_position` → `resume_route_position` → `start_from` (extend `test_run_route_position_save.gd`); (c) a node cleared below max HP carries that HP into the next node's fight arming (`RunFlowController.hero_hp()` returns the carried HP, not the kit baseline); (d) a mid-fight quit → resume re-enters at ENTRY HP (the ephemeral-fight posture).
  - [x] **D4 rule + no-desync:** `MetaAwardRules.oath_shard_award_for` for a `PHASE_FAILED` run yields the capped nodes-cleared award (extend `test_meta_award_rules.gd`); a manual-seed death is still denied at the application gate (`test_award_meta_progress_command.gd`); idempotent (no double-award). Assert `outpost_render_view.run_oath_shards_earned()` == `oath_shard_award_for(run)` for BOTH a completed AND a failed eligible run (the CRUX-3 single-authority guard).
  - [x] **AC3 event outcome seam:** the outcome projection (exact-key) surfaces the gold/healing/curse/corruption deltas + risk flags from a resolved `ChooseEventOptionCommand` result; a safe/decline choice surfaces a zero-net honest outcome; fail-closed on an absent/invalid offer.
  - [x] **AC4 summary:** the earned count reflects D4; `nodes_cleared` is real; the unpopulated lists are honestly labelled (not shown as a bare empty result). `RunSummary` pinned key sets unchanged (`test_run_summary.gd` green).
  - [x] **Gate integrity:** confirm the top-level `RunSnapshot` gate is STILL 23 (Mechanism A) — extend/keep `test_run_snapshot.gd`; `rng_stream_set.gd` 7 streams untouched; `domain_event.gd` enum unchanged OR tail-appended (never renumbered); `project.godot` byte-untouched; every generator/route/finale/combat seed-regression fingerprint byte-identical (the changes ride live paths only — VERIFY the hands-off driver diff is empty). If `SCHEMA_VERSION` was bumped (Mechanism B), the `parse()` migration branch + its test exist.
  - [x] **`.gd.uid` discipline:** for any NEW `.gd` (seam/view-model/test/scene script), run `godot --headless --import` **separately** to emit the `*.gd.uid` sidecar and leave it for the orchestrator to commit (the `--scene` test run does not emit it). Commit any new `.tscn` + `.import` sidecars. Restore any `*.svg.import` the `--import` pass rewrites with only CRLF churn (15-4 Phase-5 retro).
  - [x] Run the FULL headless suite (command + hazard-avoidance below). Baseline **211 PASS files** (post-15.4 merge); expect **≥211** (each NEW `test_*.gd` FILE bumps the count by one — extending an existing file adds none; the runner reports PASS per test FILE, not per function — 15-3 Phase-7 retro). False-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW captured output = exactly the **6 documented** pre-existing stderr negatives, ZERO new, none referencing a 15.5 file. `git diff --check` clean.

## Dev Notes

### Mandatory test command (must pass before this story moves to review/done) — AND THE FALSE-PASS HAZARD

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`) or the standalone console binary `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`.

**⚠ THE 15-4 Phase-7 FALSE-PASS SELF-FALSIFICATION HAZARD — do NOT repeat it.** A prior delegate piped `godot ... --path C:\Sealsworn\godot` through `tee` under bash; bash STRIPPED the backslashes (`→ "C:Sealsworngodot"`), Godot aborted, and the pipeline **still exited 0 because `tee` succeeded** — faking a green run. A green exit code is NOT evidence the suite ran. Therefore, when running the gate:
- Use a **FORWARD-SLASH** path (`--path C:/Sealsworn/godot`).
- **Redirect stdout+stderr to a FILE** (`> out.txt 2>&1`) — do **NOT** pipe through `tee`.
- Read the **pass count** and the final **"Headless tests passed."** banner from the captured file (`grep -cE "^PASS " out.txt` should equal the expected count).
- Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW captured output = exactly the **6 documented pre-existing negatives** (int64-overflow ×2 [`test_domain_event.gd` + `test_manual_seed_loader.gd`], `invalid_node_type` ×1 [`test_route_node.gd`], malformed-JSON ×3 [`test_profile_repository.gd` + `test_run_resume_service.gd` + `test_settings_repository.gd`]); ZERO new, none referencing a 15.5 file. **Never trust the summary PASS line or the exit code alone.**

Current baseline on merged main (15.4): **211 PASS / 0 FAIL.** The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only.

### What is ALREADY SHIPPED (reuse / make honest — do NOT rebuild)

- **The 15.4 between-node route-position save/resume seam** (`compose_route_position_snapshot` → `SaveManager.autosave_route_position`; `SaveManager.resume_route_position` → `RunResumeService` → `RunOrchestrator.start_from`). D1's `current_hp` rides THIS seam (nested in `route_state`, the same mechanism 15.4 used to restore `assigned_affinities` from the `RunSnapshot.affinities` mirror). **Reuse; do NOT fork a new save path.**
- **The Epic-7 event machinery** — `EventOffer`, `RunOrchestrator.generate_event_offer` (the `events`-stream roll), `EventViewModel` (the before-choice modal), `ChooseEventOptionCommand` (applies both sides, emits `event_resolved` + `economy_changed` [+ `curse_applied`], carries the before/after deltas in its result metadata). AC3 WIRES this into the live flow + shows the outcome. **Reuse verbatim; do NOT re-author event resolution.**
- **`MetaAwardRules`** (the pure capped calculator) + **`AwardMetaProgressCommand`** (the eligibility+idempotency application gate). D4 changes the death branch of the calculator + updates its tests. **Reuse the gate discipline; change only the death-award value.**
- **`RunSummary`** (the pure read aggregator — `nodes_cleared` already real) + **`outpost_render_view`** (the render-side earned/nodes/loot reads). AC4 makes the earned count honour D4 + labels the empty lists honestly. **Reuse; do NOT persist a summary or add a run-log field (`deferred-work.md:997/628`).**

### Scope determinations (read — these prevent over-reach AND under-delivery)

- **D1 + D4 ARE in scope** (canonical epics.md AC1/AC2). The slug omits them; the ACs govern. 15.4's fence "HP-persistence (D1) + shards-on-death (D4) → 15.5" is DISCHARGED here, not re-deferred.
- **HP persists at node boundaries, not mid-fight.** The in-node fight stays ephemeral (`deferred-work.md:418` NOT reopened); a mid-fight quit re-enters at entry HP. No mid-encounter save, no new save shape beyond the `current_hp` field.
- **The award-APPLICATION gap is real but is a scope decision (see Open Questions).** `AwardMetaProgressCommand` is never called in production, so the profile never accrues shards today. D4's LITERAL scope is the RULE + tests + the DISPLAY (AC4). Whether 15.5 also WIRES the application (so "unlocks are reachable" — the user-story intent — is genuinely delivered) is flagged below; the safe default satisfying the four ACs literally is rule + display, but the dev/review should consciously resolve it rather than let it slip.
- **The event node interaction is wired live-only.** The hands-off `run_to_completion` auto-resolve keeps its placeholder event resolution (fingerprint-safe). The `events`-stream draw is added only on the on-screen path.
- **The run-level event store STAYS deferred.** AC4 says the loot/passive lists are "pending the deferred run-level event store" → label them honestly; do NOT build it (`deferred-work.md:447/458/1004`).
- **Difficulty stays a hard non-goal.** HP attrition is an economy/resource change, not a difficulty knob; no difficulty setting is read or added.

### Epic-15 constraints inherited (retro forward items + project-context + the sprint change)

- **"Epic 15 moves NO seed-regression fingerprint"** — but the SAVE SCHEMA is a separate concern, and D1 changes it DELIBERATELY (CRUX-1). Keep the two straight: every combat/generation/route/finale replay fingerprint stays byte-identical (live-path-only changes); the `route_state` sub-shape gains `current_hp` (a schema change with a migration test). Do NOT conflate "no fingerprint" with "no schema change."
- **The 15-2 "computed in two places" desync class** — DIRECTLY recurs here: the award amount lives in `MetaAwardRules` AND `outpost_render_view.run_oath_shards_earned`. Collapse to one authority (CRUX-3) and test-lock the equality.
- **The 15-1 vs 15-2 contrast — apply BOTH.** The HP-persistence round-trip, the D4 death-award rule, the event-outcome projection, and the summary earned-count ARE headlessly provable → **test-lock them.** Only the event modal / outcome surface / HP HUD on-screen legibility rides the presenter → verify-by-construction → OSG-1. Do NOT defer the correctness to OSG-1.
- **Assertable logic on scene-free `RefCounted` seams; scenes verified by construction + the compile guardrail (`test_run_flow_scenes_load.gd`); no SceneTree presenter test; no new autoload** (the 11.3/13.x/14.x/15.x ratified posture).
- **The runner reports PASS per test FILE, not per function** (15-3 Phase-7) — set the expected-count guard so each NEW `test_*.gd` file bumps it by one; extending a file adds none.
- **`.gd.uid` via `--headless --import` separately; keep the false-PASS grep guard standing; restore `*.svg.import` CRLF churn** (13-1/14-8/15-4 Phase-5/Phase-7).
- **Session-kill recovery discipline (15-4 Phase-5):** if this dev-story is resumed after an interruption, RUN THE SUITE FIRST as the correctness gate and scan whatever file the dead delegate was mid-editing for referenced-but-undefined symbols (a called-but-unwritten function body compiles-green in a WIP checkpoint but is one parse error from red).

### Deferred-work overlaps folded in (only those that touch 15.5's area)

- **`deferred-work.md:418` (the in-node fight stays EPHEMERAL; the mid-encounter save is out of scope; the 23-key gate stays 23).** 15.5 persists HP at the between-node ROUTE-POSITION boundary over 15.4's resume seam — it does NOT add a mid-encounter save and does NOT reopen this defer. A mid-fight quit re-enters at entry HP.
- **`deferred-work.md:447 / :458 / :1004 / :1080` (the run-level event STORE for a full `RunSummary`).** AC4 explicitly labels the loot/passive lists "pending the deferred run-level event store." 15.5 makes them HONEST (not-yet-recorded label) but does NOT build the store — it STAYS deferred.
- **`deferred-work.md:627 / :645 / :765 (the Oath-Shard EARNED-count summary wiring).** 14.5 already wired the render-side earned count for a COMPLETED run (`outpost_render_view.run_oath_shards_earned`); 15.5 EXTENDS it to a death (D4) and single-sources it (CRUX-3). This PARTIALLY closes the defer render-side; the summary DTO field `profile_meta.oath_shards_earned` intentionally STAYS 0/`not_yet_supported` (mutating it would break `test_run_summary.gd`'s pinned contract). Record the render-side closure; do NOT reopen the DTO-coupling half.
- **The depth-scaled affinity-frequency rebalance (`deferred-work.md` §"Deferred from: story 15-4 scope decision (2026-08-17)") — OUT OF SCOPE.** A FUTURE story owns it. Do NOT touch `assign_affinity`'s uniform 5-candidate `map` draw or `affinity_repository.gd`.

### OSG-1 on-device checklist additions (carry forward; not a blocker — the correctness is test-locked)

- After clearing a wounded fight, the next fight starts at the CARRIED HP (a between-level HUD read of `current_hp`, not the class baseline), and a quit → Continue resumes at that HP.
- Dying deep in a run shows a non-zero Oath-Shard earning on the run summary (D4); dying at depth 0 shows the honest small/zero award; a manual-seed death shows 0.
- Picking an event node opens an outcome/choice surface that shows what changed (gold/healing/curse/corruption + risk flags) before returning to the map — never a silent counter bump.
- The run summary's loot/passive lists read as "not yet recorded," never as a bare empty "nothing," and the earned-shards + nodes-cleared numbers are real.
- All event/summary affordances ≥44px and legible at the 2.0x text scale.

### Anti-patterns to avoid (this story specifically)

- **Do NOT pretend HP persistence is free** — it is new persisted state and a schema change; ship the migration/back-compat test (CRUX-1). Do NOT add a mid-encounter save (CRUX-2, `deferred-work.md:418`).
- **Do NOT thread `current_hp` into the hands-off `run_to_completion` / `play_hands_off_to_run_end` / `DEFAULT_HERO_HP`** — that owns the reward/route/finale/combat fingerprints. HP rides the live/interactive path only.
- **Do NOT change the death-award rule in one place** — update `MetaAwardRules` AND `outpost_render_view.run_oath_shards_earned` AND every death-awards-zero test in the same change (CRUX-3; the 15-2 lesson).
- **Do NOT leave the event node a silent placeholder** — wire present → choose → apply → outcome surface; read the outcome from the EXISTING `ChooseEventOptionCommand` resolution data (invent no new domain data).
- **Do NOT build the run-level event store** — honestly label the loot/passive lists as not-yet-recorded (AC4; the store STAYS deferred).
- **Do NOT mutate `RunSummary`'s pinned `DICTIONARY_KEYS` / `NOT_YET_SUPPORTED_FIELDS` / `profile_meta.oath_shards_earned`** — wire the earned count render-side.
- **Do NOT insert a `DomainEvent` mid-enum** — if one is needed, append at the tail (never renumber), and wire the `to_dictionary`/`try_from_dictionary` round-trip + a test.
- **Do NOT pull in the affinity-frequency rebalance, the reward modal (15.6), move-confirm (15.7), movement animation (15.8), or theme polish (15.10).**
- **Do NOT add a new autoload, a new RNG stream, a new draw site outside the existing `events`/`map`/`combat` order, or a `_process` poll.**
- **Do NOT run the gate through `tee` or trust a green exit code** — forward-slash path, redirect to a file, read the count + banner + false-PASS grep from the captured output.

## Project Structure Notes

- **Files likely touched (production):**
  - `godot/scripts/run/run_state.gd` — MODIFIED: add `current_hp`; serialize it (nested in `route_state` via `to_run_snapshot_fields` + in `to_dictionary`); read it back leniently in `try_from_run_snapshot_fields` + `try_from_dictionary` (absent → kit baseline).
  - `godot/scripts/save/snapshots/run_snapshot.gd` — MODIFIED **only if** Mechanism B (a new top-level key + `SCHEMA_VERSION` bump + `parse()` migration). Under Mechanism A (recommended) the `route_state` carries `current_hp` and this file is UNCHANGED (23-key gate holds).
  - `godot/scripts/run/run_orchestrator.gd` — MODIFIED: capture ending HP → `run.current_hp` at the `finish_interactive_combat_node` / `resolve_combat_node_live` victory boundaries; a live event-resolution seam (or drive it from the presenter). Do NOT touch the hands-off `run_to_completion` / `_resolve_combat` driver.
  - `godot/scripts/ui/flow/run_flow_controller.gd` — MODIFIED: `hero_hp()` prefers `run.current_hp` (falls back to the kit baseline); the live boss entry uses `current_hp`. `play_hands_off_to_run_end` UNCHANGED (`DEFAULT_HERO_HP`).
  - `godot/scripts/save/meta_award_rules.gd` — MODIFIED: reverse the `PHASE_FAILED → 0` gate (D4); update the `[Decision]` docstring.
  - `godot/scripts/ui/view_models/outpost_render_view.gd` — MODIFIED: `run_oath_shards_earned()` honours a death (D4) + single-sources from `MetaAwardRules` (CRUX-3); honest not-yet-recorded labelling for the empty loot/passive lists.
  - `godot/scripts/ui/presenters/route_map_presenter.gd` — MODIFIED: an `event`-type pick routes to present → choose → apply → outcome surface instead of the silent placeholder resolve.
  - `godot/scripts/ui/view_models/event_outcome_view_model.gd` (or similar) — NEW `RefCounted` seam: the exact-key event-outcome projection (gold/healing/curse/corruption deltas + risk flags) from a resolved `ChooseEventOptionCommand` result. (+ `.gd.uid`.)
  - `godot/scripts/ui/presenters/...` — a small event-node modal/outcome scene or overlay (verify-by-construction; the decision logic lives on the seam). (+ `.tscn`/`.import`/`.gd.uid` if a scene is added.)
  - (Possibly) `godot/scripts/ui/flow/run_end_profile_bridge.gd` — MODIFIED **only if** the award APPLICATION is wired (see Open Questions) — call `AwardMetaProgressCommand` behind its eligibility+idempotency gates at the live run-end. Draws zero RNG; do NOT touch the hands-off driver.
- **Tests:** EXTEND `test_run_route_position_save.gd` (HP round-trip + mid-node re-enter), `test_run_snapshot.gd` (23-key gate holds / Mechanism-B migration), `test_run_state.gd` (current_hp serialize/restore + back-compat default), `test_meta_award_rules.gd` + `test_award_meta_progress_command.gd` (D4 death award + manual-seed denial + idempotency), `test_run_summary.gd` (pinned keys unchanged); ADD a migration/back-compat test, an event-outcome seam test, and (render-side) an `outpost_render_view` earned-count-honours-death test asserting equality with `MetaAwardRules`. Grep-update every death-awards-zero assertion across the suite. `test_run_flow_scenes_load.gd` stays green (compile guardrail; add any new scene script).
- **Out of bounds:** `rng_stream_set.gd` (7 streams), `domain_event.gd` (no new event unless tail-appended + wired), the reference combat driver + every winnability/seed-regression fixture, the hands-off `run_to_completion` auto-resolve driver, `run_snapshot.gd` top-level key set (Mechanism A), `assign_affinity`/`affinity_repository.gd` (the affinity-frequency defer), the run-level event store, `RunSummary`'s pinned key sets, `project.godot`/input map, the reward modal (15.6), move-confirm (15.7), movement animation (15.8), theme polish (15.10). Every generator/route/finale/combat seed-regression fingerprint is byte-untouched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Save truth is versioned domain snapshots; schema changes need migration tests (hard rule; NFR15).** D1 adds `current_hp` to the persisted `RunState`/`RunSnapshot`; a migration/back-compat test is MANDATORY (an old save without HP restores at full/baseline). Serialize no scene node.
- **Domain owns truth; presentation observes + submits commands (hard rule; NFR14).** The event outcome surface and the HP HUD read the domain (`ChooseEventOptionCommand` result, `run.current_hp`); they own no run truth.
- **Gameplay actions are commands that validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense events (hard rule).** The event node resolves through `ChooseEventOptionCommand` (already this idiom); any new event appends at the enum tail.
- **Named RNG only; deterministic under seed (NFR13).** HP capture draws ZERO RNG (a board read); the event offer draws the existing `events` stream on the LIVE path only; Epic 15 moves NO seed-regression fingerprint. The award is pure/zero-RNG.
- **Meta-progression is bounded, capped, deterministic, and manual-seed-ineligible (FR28/FR59).** D4 keeps the award capped (`MAX_AWARD == 5`), deterministic, idempotent, and denied for a manual-seed run at the application gate.
- **Assertable logic on scene-free `RefCounted` seams with pinned key sets; scenes verified by construction + the compile guardrail; no SceneTree presenter tests; no new autoload.**
- **Phone-sized readability is first-order; color-independence (NFR9).** The event outcome surface + the HP HUD + the summary read legibly at 2.0x with ≥44px targets — deltas conveyed by text/number, not color alone (OSG-1 confirms on-device).
- **Difficulty is a hard non-goal.** HP attrition is an economy/resource change, not a difficulty knob.

## References

- `_bmad-output/planning-artifacts/epics.md#Epic 15: Playtest Response` — Story 15.5 ACs (lines 3341–3369); the Epic-15 entry + "Epic 15 moves NO fingerprint" + "difficulty is a hard non-goal" (535–541, 3251–3256); the Band-2 demarcation; the sibling fences (15.4 D1/D4 forward-pointer, 15.6 D3, 15.7 D2).
- `_bmad-output/implementation-artifacts/15-4-quit-pause-resume.md` — the between-node route-position save/resume seam this story consumes (`compose_route_position_snapshot` → `autosave_route_position`; `resume_route_position` → `start_from`); the affinity-mirror restore precedent (D2/D4) that HP restoration mirrors; the ephemeral-fight / 23-key-gate posture; the explicit "HP-persistence (D1) + shards-on-death (D4) fenced to 15.5."
- `_bmad-output/auto-gds/retro-notes/epic-15.md` — 15-2's "correctness IS headlessly provable → test-lock it" + the "computed in two places" desync class (CRUX-3); 15-3's "PASS per test FILE, not per function"; 15-4's false-PASS `tee` self-falsification hazard (the gate-run discipline above) + the session-kill recovery discipline + the "a delegate can encode its own scope-cut into the test" warning (assert the real D4 behaviour, no SKIP).
- `_bmad-output/implementation-artifacts/deferred-work.md` — `:418` (in-node fight ephemeral; mid-encounter save out of scope — not reopened); `:447/:458/:1004/:1080` (run-level event store — STAYS deferred; label honestly); `:627/:645/:765` (Oath-Shard earned-count summary wiring — extended render-side by D4); §"Deferred from: story 15-4 scope decision (2026-08-17)" (affinity-frequency rebalance — OUT of scope).
- Source files (read before implementing):
  - `godot/scripts/run/run_state.gd` — `to_run_snapshot_fields` (`356-393`, the nest-in-`route_state` mechanism for `current_hp`); `try_from_run_snapshot_fields` (`461-520`); `to_dictionary`/`try_from_dictionary` (`270`, `396`); `selected_class_id` (`70`) / `starting_kit` (`79`). **No current-HP field today.**
  - `godot/scripts/save/snapshots/run_snapshot.gd` — the 23-key `to_dictionary` (`43-68`), `from_route_position` (`217-284`), `SCHEMA_VERSION == 1` (`12`), the hard-equality `parse()` gate (`72-77`). **Mechanism-A: unchanged. Mechanism-B: bump + migration branch here.**
  - `godot/scripts/run/combat_loadout.gd` — `for_run` HP source (`70-73`, kit baseline / 60 default).
  - `godot/scripts/run/live_combat_resolver.gd` — `resolve(..., hero_hp, ...)` (`159-249`); the ending HP is on `metadata.board`'s hero entity (discarded today).
  - `godot/scripts/ui/flow/run_flow_controller.gd` — `hero_hp()` (`132-133`, change to prefer `current_hp`); the "NO run-level HP field" note (`130-131`); `play_hands_off_to_run_end` (`166-173`, fingerprint path — do NOT touch).
  - `godot/scripts/run/run_orchestrator.gd` — `resolve_combat_node_live` victory (`1094-1098`); `finish_interactive_combat_node` victory (`1273-1277`) — the HP-capture loci; `generate_event_offer` (`606-665`); the placeholder event-resolution note (`601-602`); `auto_play_boss_fight` (`1412`).
  - `godot/scripts/save/meta_award_rules.gd` — `oath_shard_award_for` + the `PHASE_FAILED → 0` gate (`55-64`); the `[Decision]` docstring (`24-26`).
  - `godot/scripts/core/commands/award_meta_progress_command.gd` — the application gate (`125`); NEVER called in production `scripts/` (awareness).
  - `godot/scripts/run/run_summary.gd` — `nodes_cleared` real (`287`); `oath_shards_earned` 0/`not_yet_supported` (`130-132, 326-328`); pinned `DICTIONARY_KEYS`/`NOT_YET_SUPPORTED_FIELDS` (`84-95, 130-132`).
  - `godot/scripts/ui/view_models/outpost_render_view.gd` — `run_oath_shards_earned` (`230-237`, CRUX-3); `summary_nodes_cleared` (`208-210`); `summary_notable_loot` (`247-250`, honest-empty).
  - `godot/scripts/ui/presenters/route_map_presenter.gd` — `_on_choice_picked` non-combat path (`288-324`, the placeholder resolve to replace for `event`).
  - `godot/scripts/core/commands/choose_event_option_command.gd` — the event resolution + result-metadata deltas (`271-285`) the AC3 outcome surface reads.
  - `godot/scripts/ui/view_models/event_view_model.gd` — the before-choice modal projection (`MODAL_KEYS`/`CHOICE_KEYS`).
  - `godot/scripts/ui/flow/run_end_profile_bridge.gd` — `build_outpost` (the run-end → summary/outpost path; `RunSummary.build(run, [])` empty-events, `55/178-179`).
  - `godot/scripts/core/events/domain_event.gd` — the enum + tail-append precedent (`6`, `95-99`); `event_resolved`/`economy_changed` (`38, 35`).
  - Tests to extend: `godot/tests/unit/save/test_run_route_position_save.gd`, `test_run_snapshot.gd`, `godot/tests/unit/run/test_run_state.gd`, `godot/tests/unit/save/test_meta_award_rules.gd`, `godot/tests/unit/core/test_award_meta_progress_command.gd`, `godot/tests/unit/run/test_run_summary.gd`, `godot/tests/unit/ui/test_run_flow_scenes_load.gd`.

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story) — completed across TWO delegate runs: an initial run implemented the production code (committed `a05c4f9` WIP + `82c6c7a` sidecars) then was killed mid-run by a monthly spend limit while updating the D4 tests; a second (continuation) delegate resumed from the on-disk state, finished the test lockstep, added the remaining coverage, and finalized.

### Debug Log References

- Full headless suite (forward-slash path, redirected to a file, never through `tee`): `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe --headless --path C:/Sealsworn/godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- Resume diagnostic: 208 PASS / 3 FAIL (9 stale death-awards-zero assertions across 3 test files — the half-done D4 lockstep). After the lockstep fix: 211 PASS / 0 FAIL. After the Priority-2 coverage: **212 PASS / 0 FAIL** ("Headless tests passed." banner). False-PASS grep guard (`SCRIPT ERROR|Parse Error|^FAIL`) = 0; the 6 documented pre-existing `ERROR:` negatives (int64 ×2, invalid_node_type ×1, malformed-JSON ×3) byte-identical to the clean baseline, none referencing a 15.5 file. `git diff --check` clean.

### Completion Notes List

- **D1 mechanism — Mechanism A (CRUX-1 decision, recorded).** `current_hp` is a new `RunState` int (sentinel `HP_UNSET == -1` = "no HP recorded → use the kit baseline"), NESTED inside the `route_state` payload via `CURRENT_HP_KEY` (`to_run_snapshot_fields`) — the SAME plumbing as `run_phase` / `selected_class_id` / `risk_economy`. The top-level `RunSnapshot` gate STAYS **23** and `SCHEMA_VERSION` STAYS **1** (no top-level key, no bump — AC4 honored). Lenient read-back in BOTH `try_from_run_snapshot_fields` and `try_from_dictionary` (absent → `HP_UNSET`). The MANDATORY migration/back-compat test proves a pre-15.5 save (no nested `current_hp`) restores at `HP_UNSET` → the live loadout fails OPEN to the kit/driver baseline (full HP), never 0/a crash.
- **D1 carry + capture.** `RunFlowController.hero_hp()` prefers `run.current_hp` when set, else the kit baseline. The orchestrator CAPTURES the hero's ending board HP into `run.current_hp` at BOTH victory boundaries (`finish_interactive_combat_node`, `resolve_combat_node_live`) via `_capture_hero_hp_from_board` — a pure board read, live-hero-only (`current_hp > 0`), ZERO RNG. The in-node fight stays EPHEMERAL: HP is captured only on a clear, so a mid-fight quit re-enters the un-cleared node at its last-persisted ENTRY HP (`deferred-work.md:418` NOT reopened). `auto_play_boss_fight` enters at the caller-supplied HP; the on-screen path passes `hero_hp()`, the hands-off smoke path passes `DEFAULT_HERO_HP` (decoupled — fingerprint-safe).
- **D4 death award + CRUX-3 single authority.** `MetaAwardRules.oath_shard_award_for` routes BOTH terminal phases (COMPLETED and FAILED) through the single-authority `award_amount_for_nodes_cleared(nodes_cleared) = min(BASE + PER_NODE * nodes_cleared, MAX)`; the `PHASE_FAILED → 0` gate is reversed; pure/zero-RNG. `outpost_render_view.run_oath_shards_earned()` single-sources the SAME helper, DROPS the completed-only gate (a death now shows its award) and KEEPS the terminal + manual-seed-eligibility gate (a manual-seed run still earns 0). Every death-awards-zero test updated in lockstep (see below) — no weakened assertions; each now genuinely pins the new capped-death contract.
- **D5 (Option B — human decision 2026-08-18) award APPLICATION wired.** `RunEndProfileBridge` now DRIVES `AwardMetaProgressCommand` at the live run-end (it was previously never called in production, so the profile never accrued), reusing the command's EXISTING gates verbatim — eligibility (manual-seed DENIED), terminal, and idempotency (`last_awarded_run_seed` blocks a double-award on a re-drive). A distinct `sequence_id + 1` keeps the award event id off the record-latch id. Mutates ONLY the profile; ZERO RNG. Integration-covered: a completion AND a death both accrue the correct bounded/capped amount; a manual-seed run accrues nothing; a re-driven run-end does not double-award; the summary's earned count == what the profile received.
- **AC3 event node wired live-only.** `route_map_presenter._on_choice_picked` routes an `event`-type pick to `EventNodeOverlay` (generate offer → `EventViewModel` present → `RunOrchestrator.resolve_event_node_live` apply+clear → `EventOutcomeViewModel` show → dismiss → re-render map), replacing the silent `NodeResolvePlaceholderCommand`. `resolve_event_node_live` is the new orchestrator seam; it applies `ChooseEventOptionCommand` and returns the before/after gold/healing/curse/corruption + risk-flags metadata (no new domain data). The testable projection lives on the scene-free `EventOutcomeViewModel` (exact `OUTCOME_KEYS`, signed deltas, fail-closed identity-absent, safe/decline honest outcome) — unit-tested; the overlay Control is verified by construction + the compile guardrail. No-soft-lock: a decline is always affordable + re-pickable; a rejected pick fails closed with a visible cue; an ungenerated offer falls OPEN to the placeholder resolve. The hands-off driver keeps its placeholder resolution (no `events` draw) → fingerprint-safe.
- **AC4 honest labels.** `outpost_render_view` gained `NOT_YET_RECORDED_LABEL` + `summary_notable_loot_not_yet_recorded()` / `summary_passives_not_yet_recorded()` (+ `summary_passives_consumed/destroyed()`): a real run whose loot/passive lists are empty ONLY because of the still-deferred run-level event store is flagged "Not yet recorded" (never a bare empty result that reads as "you got nothing"); an absent summary is not flagged (the "no just-ended run" gate owns it); a populated list renders its real entries. `RunSummary`'s pinned `DICTIONARY_KEYS` / `NOT_YET_SUPPORTED_FIELDS` / `profile_meta.oath_shards_earned` are UNCHANGED (render-side only — the 8.4/14.5 posture). The run-level event store STAYS deferred (not built).
- **Gate integrity + fingerprint safety (VERIFIED).** Top-level `RunSnapshot` gate STILL 23 (a route-position test asserts `current_hp` nests under `route_state`); `rng_stream_set.gd` 7 streams untouched; NO new `DomainEvent` (the event node reuses `event_resolved` / `economy_changed`); `project.godot` byte-untouched. Every pinned seed-regression/finale/reward/route/affinity fingerprint test (`test_finale_seed_regression`, `test_finale_full_run`, `test_seed_regression_suite`, `test_route_generation_seed_regression`, the small/medium layout regressions) passed UNMODIFIED → byte-identical. The affinity-frequency rebalance, `assign_affinity`'s uniform draw, and the `AFFINITY_SEED_SAMPLE` fixture were NOT touched (out of scope).
- **Continuation recovery note.** Ran the suite FIRST as the correctness gate (measured 208/3), root-caused all 3 failures to the single half-done D4 lockstep, and — crucially — the exhaustive assertion audit found a 9th stale assertion (`test_meta_summary_save_load.gd` `_three_run_end_markers_are_order_independent`, "A death awards 0 — the total is unchanged", Expected 4 got 7) that the orchestrator's 8-assertion diagnostic had omitted. Grep-verified no other death-awards-zero assertion remains; the manual-seed-death / absent-summary / non-terminal 0 cases are eligibility/fail-closed gates and correctly stay 0.

### File List

**Production (implemented by the initial dev-story delegate; committed `a05c4f9`/`82c6c7a`; part of this story's deliverable):**
- MODIFIED `godot/scripts/run/run_state.gd` — `current_hp` field + `HP_UNSET`/`CURRENT_HP_KEY`; serialized nested in `route_state` (`to_run_snapshot_fields`) + in `to_dictionary`; lenient read-back in `try_from_run_snapshot_fields` + `try_from_dictionary`; carried in `copy()`; `_current_hp_or_unset` helper.
- MODIFIED `godot/scripts/run/run_orchestrator.gd` — `_capture_hero_hp_from_board` at both victory boundaries; `resolve_event_node_live` (the live event seam).
- MODIFIED `godot/scripts/ui/flow/run_flow_controller.gd` — `hero_hp()` prefers `current_hp`.
- MODIFIED `godot/scripts/save/meta_award_rules.gd` — D4 reversal + `award_amount_for_nodes_cleared` single authority + `[Decision]` docstring.
- MODIFIED `godot/scripts/ui/view_models/outpost_render_view.gd` — `run_oath_shards_earned` single-source + death-aware; `NOT_YET_RECORDED_LABEL` + `summary_*_not_yet_recorded` / `summary_passives_*`.
- MODIFIED `godot/scripts/ui/presenters/route_map_presenter.gd` — `event`-type pick → `EventNodeOverlay`.
- MODIFIED `godot/scripts/ui/presenters/outpost_presenter.gd` — maps the AC4 not-yet-recorded labels.
- MODIFIED `godot/scripts/ui/flow/run_end_profile_bridge.gd` — D5 (Option B): drives `AwardMetaProgressCommand` at run-end.
- NEW `godot/scripts/ui/view_models/event_outcome_view_model.gd` (+ `.gd.uid`) — the AC3 scene-free outcome projection.
- NEW `godot/scripts/ui/presenters/event_node_overlay.gd` (+ `.gd.uid`) — the AC3 event choice/outcome overlay.

**Tests (this story):**
- MODIFIED `godot/tests/unit/save/test_meta_award_rules.gd` — D4 death award (initial delegate).
- MODIFIED `godot/tests/integration/save/test_meta_summary_save_load.gd` — D4 lockstep (eligible-death accrual + order-independence).
- MODIFIED `godot/tests/unit/core/test_award_meta_progress_command.gd` — D4 death-award-through-the-gate.
- MODIFIED `godot/tests/unit/ui/test_outpost_render_view.gd` — D4 death-earned render + AC4 not-yet-recorded labels.
- MODIFIED `godot/tests/unit/run/test_run_state.gd` — D1 `current_hp` serialize/restore/copy + back-compat default + snapshot-bridge nest.
- MODIFIED `godot/tests/unit/save/test_run_route_position_save.gd` — D1 route-position round-trip + MANDATORY migration + live-clear HP capture + `hero_hp()` carry.
- MODIFIED `godot/tests/unit/ui/test_run_end_profile_bridge.gd` — D5 award accrual (completion/death), manual-seed denial, no double-award, summary==profile delta.
- NEW `godot/tests/unit/ui/test_event_outcome_view_model.gd` (+ `.gd.uid`) — the AC3 outcome-projection seam.

### Change Log

- 2026-08-18 — Story 15.5 context created (gds-create-story). The CANONICAL epics.md scope ("Run Economy, HP Persistence and Event-Node Outcomes") is FOUR ACs, broader than the `event-node-and-run-summary-wiring` slug: **D1 (HP persists between nodes)**, **D4 (a death awards Oath Shards)**, the **event-node outcome surface**, and the **run-summary earned/nodes-cleared wiring**. Grep-verified the four gaps: no run-level current-HP field (ending HP discarded, hero implicitly full-healed); `MetaAwardRules` returns 0 for `PHASE_FAILED`; the event node resolves via `NodeResolvePlaceholderCommand` (a silent counter bump); `RunSummary.oath_shards_earned` is 0/`not_yet_supported`. **The single most important call: D1 REQUIRES a save-schema change** (a new persisted `current_hp`) — recommended Mechanism A nests it inside the existing `route_state` (top-level 23-key gate stays 23, `SCHEMA_VERSION == 1`) but STILL mandates a migration/back-compat test; Mechanism B (new top-level key + `SCHEMA_VERSION` bump + `parse()` migration) contradicts AC4's "23-key gate holds." HP persists at NODE BOUNDARIES over 15.4's route-position seam (the in-node fight stays ephemeral — `deferred-work.md:418` NOT reopened). The award amount is COMPUTED IN TWO PLACES (`MetaAwardRules` + `outpost_render_view.run_oath_shards_earned`) — D4 must collapse the desync (the 15-2 lesson). All four parts ride the LIVE path only, so every seed-regression fingerprint stays byte-identical (Epic 15 moves NO fingerprint). Flagged: `AwardMetaProgressCommand` is never applied in production, so the award-APPLICATION wiring is a scope decision (rule + display is the literal-AC default; wiring the application delivers the user-story "unlocks are reachable"). Out of scope: the affinity-frequency rebalance, the run-level event store (label lists honestly), the reward modal (15.6). Recorded the 15-4 false-PASS `tee` gate hazard + the session-kill recovery discipline. Baseline 211 PASS. Status → ready-for-dev.
- 2026-08-18 — Story 15.5 implemented (gds-dev-story, across two delegate runs — the first killed mid-run by a spend limit after committing the production code + updating `test_meta_award_rules.gd`; the second resumed from disk). **D1 (Mechanism A):** `current_hp` nested in `route_state` (23-key gate stays 23, `SCHEMA_VERSION` stays 1, `HP_UNSET` fail-open default) + captured at victory boundaries + carried via `hero_hp()`; MANDATORY migration/back-compat test proves a pre-15.5 save restores at the baseline (never 0). **D4:** the death-awards-zero gate reversed; `MetaAwardRules` + `outpost_render_view` single-sourced through `award_amount_for_nodes_cleared` (CRUX-3); the 9 stale death-awards-zero assertions across 3 test files updated in lockstep (a 9th the resume diagnostic had missed was caught by an exhaustive audit). **D5 (Option B, human decision):** `RunEndProfileBridge` now drives `AwardMetaProgressCommand` at the live run-end behind its existing eligibility/idempotency gates, so the profile actually accrues (completion + death); integration-covered incl. no-double-award + manual-seed denial + summary==profile delta. **AC3:** the event node is wired live-only (overlay → `generate_event_offer` → `resolve_event_node_live` → `EventOutcomeViewModel`), no longer a silent counter bump; the outcome projection is a new unit-tested scene-free seam. **AC4:** empty loot/passive lists are honestly labelled "Not yet recorded"; the `RunSummary` DTO pinned keys are unchanged and the run-level event store STAYS deferred. Gate integrity + fingerprint safety VERIFIED (all seed-regression/finale fixtures green UNMODIFIED → byte-identical; 7 RNG streams + `domain_event` enum + `project.godot` untouched). **212 PASS / 0 FAIL**, false-PASS guard clean, `git diff --check` clean, new `.gd.uid` emitted + CRLF `*.svg.import` churn restored. Status → review.
