# Epic 1 Micro-Combat Notes

## 2026-06-07 Scripted Headless Check

- Tester: Codex scripted headless runner.
- Build/commit baseline: working tree after `44c2ba9` (`feat: implement prototype enemy turn resolution`), Story 1.11 implementation in progress.
- Scenario seed: `11101`.
- Scenario ids: `epic_1_micro_combat_win`, `epic_1_micro_combat_loss`.
- Board: one 18 HP hero, Iron Cultist, Ash Seer, entrance/exit tiles, one wall obstacle, fog reveal from the hero.
- Weapons used: sword and staff on the victory path; dagger on the defeat path.
- Victory outcome: understood from `level_victory_reached` plus explanation entries after both prototype enemies reached 0 HP.
- Defeat outcome: understood from `level_defeat_reached`; cause metadata points back to the latest `damage_applied` event against `hero`.
- Notable positioning/LoS decision: the hero moves from the entrance to a visible staging tile, causing Iron Cultist to approach while Ash Seer marks the hero's tile through line of sight.
- Notable confusion: no human UI readability notes yet; this check verifies the domain event log and explanation text only.
- Timing instrumentation: disabled by default; when enabled locally, records board query, line-of-sight update, command execution, enemy turn resolution, and outcome evaluation labels without emitting domain events or changing event order.
