# Epic 8 — Auto-GDS retro notes

Signal-only scratchpad for later Epic 8 stories and the epic retrospective. One terse bullet per
genuinely reusable signal; routine success recaps are omitted.

## Story 8-1-run-completion-and-return-to-outpost-flow
- [Phase 3 — create-story] 8-1 is the FIRST story to drive `RunState.PHASE_FAILED` (reachable in the transition table since Epic 4 but never triggered — combat auto-resolves to success) and adds the first run-level `run_failed` event; the new event WILL trip the Story-7.1 `expected_ids` exhaustiveness gate (`test_domain_event.gd`) by design — register it in the same change (the exact epic-transition heads-up from the Epic-7 retro's Action T3).
- [Phase 5 — dev-story, resume-verify] The first dev-story delegate died to a CC process exit mid-run; recovery worked (WIP-checkpoint 4861a11 → push → suite diagnostic → resume delegate). Lesson for future resume briefs: diagnose from the runner's actual per-file `FAIL` list, NOT stderr `ERROR:` lines — an `ERROR: Cannot represent … as 64-bit signed integer` (`String.to_int` saturation) in this suite is a benign negative-path `push_error` that still PASSes; my resume brief mis-cited it as a second regression. The real root cause was a single `run_completed` factory leak (`boss_node_id: ""` injected unconditionally) surfacing in two test files.
- [Phase 5 — dev-story] BREAKING (documented): `run_completed` payload no longer always carries `boss_node_id` — boss_placeholder-only now, absent for generic `completed`. Epic 9 boss consumers must guard on presence.

## Story 8-2-run-summary-snapshot
- [Phase 7 — code review] `RunSummary.notable_loot` is single-sourced from `item_gained` events ONLY — all `reward_resolved` events are excluded (REWARD_CATEGORIES = backpack ∪ {gold, passive}; gold/passive were already excluded, backpack now too). A reward→backpack pickup emits both `reward_resolved` and a paired `item_gained`, so 8.6 UI can render `notable_loot` directly WITHOUT further dedup, and 8.3 loot reads see each gained item once.
- [Phase 7 — code review] The review-round-guard counts rounds via standalone bold `**Round N of 3**` headers in the story file; round 3's header initially wrapped "of 3" inside a longer bold run, which would have defeated the counter and silently permitted a 4th automatic round. Keep the round header as its own bold token when appending review entries.

## Story 8-3-meta-profile-and-oath-shard-awards
- [Phase 3 — create-story] Cite `deferred-work.md` by durable grep-phrase anchors, NOT line numbers — the ledger grows/shifts between a delegate's read and write (8-2's finalize drifted the line numbers mid-phase here).

## Story 8-4-echoes-seal-fragments-and-unlock-progress
- [Phase 3 — create-story] Title/schema mismatch resolved by design: the story names "Seal Fragments" but 8.3's reserved `ProfileSnapshot` homes have no `seal_fragments` field — 8.4 folds them into `unlock_progress` to honor "merge without migration" (SCHEMA_VERSION stays 1). A dedicated top-level field would be a deliberate schema-v2 + migration decision (8.7 territory), not a silent add.
- [Phase 5 — dev-story] Award and merge use TWO INDEPENDENT per-run idempotency markers (`last_awarded_run_seed` for Oath-Shards; `unlock_progress["_last_merged_run_seed"]` for the discovery merge) — a deliberate divergence from the story's "prefer shared marker": a shared marker would make whichever run-end command runs first block the second in either order. 8.6/8.7 MUST treat them as independent.

## Story 8-5-first-death-line-and-optional-narrative-delivery
- [Phase 3 — create-story] Genuine design fork flagged for dev+review ratification: does the `first_death_recorded` latch fire on a MANUAL-SEED death (narrative flavor, recommended) or is it denied like award/merge (FR28 strictness)? Whatever ships becomes the FR28-boundary precedent for narrative-vs-meta state.
- [Phase 7 — code review] Human RATIFIED Option A: the first-death latch is eligibility-independent (manual-seed death still records + shows the line; provably progression-free). This IS the FR28 narrative-vs-meta boundary precedent — 8.6/8.7 build on it.

## Story 8-6-outpost-menu-and-start-another-descent
- [Phase 3 — create-story] FR-numbering trap: canonical epics.md FR63 = the Larval Avatar boss (Epic 9), but the 2026-06-04 readiness patch maps a design-time GDD "FR63: named outpost/meta spaces" to Story 8.6. The named-space obligation traces via the GDD + readiness patch, NOT canonical FR63 — citing "FR63" naively mis-scopes.
- [Phase 7 — code review] `OutpostViewModel.for_recovery(...)` fits the profile-LOAD-failure case only — a future WRITE-failure (`profile_save_*`) caller must use the `_init` path with the loaded profile, or the outpost shows a false 0-shard surface over intact-but-unsaved progress. The HUD/boot-flow wiring story must handle this (and the `_init`+recovery combination is currently untested).
- [Phase 7 — code review] Godot `--path` arg via the Bash tool: doubled backslashes get consumed (`C:\\Sealsworn\\godot` → `C:Sealsworngodot`, silent abort masked by tee exit 0). Use forward slashes (`--path C:/Sealsworn/godot`).

## Story 8-7-meta-and-summary-save-load-tests
- [Phase 3 — create-story] AC1 "class unlock states restore correctly" is a trap: v0 has NO profile→class-selectability wiring (static `ClassDefinition.lock_state`; `HeroSelectViewModel` reads no profile). Story redefines the AC as "profile `unlock_progress`/`class_mastery` STATE round-trips" — an AC-wording-vs-as-built divergence carried from 8.3/8.4; do not build the deferred meta-spend/apply system.
