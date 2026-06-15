# Resolved deferred work

Entries moved out of `deferred-work.md` once verified resolved. Archived during epic closeouts by auto-gds (and ad-hoc when an item is confirmed done). Newest archive batch on top.

## Archived during epic 2 closeout (2026-06-15)

### Originally deferred from: code review of 2-7-between-level-save-snapshot-foundation (2026-06-14)

- [Review][Defer][RESOLVED 2026-06-14 in Story 2.8] (Low) The Composition Contract requires run-level `RunSnapshot.rng_streams` and the embedded tactical `rng_streams` not to "silently disagree without a test." `from_between_level()` makes them equal (both are pure `streams.to_snapshot()` reads at the boundary), but no test asserted `snapshot.rng_streams == <embedded tactical>.rng_streams`; a future refactor snapshotting them at different points could diverge undetected. (Originating review: code review of 2-7, Round 1, 2026-06-14.) RESOLVED: equality assertion added in `test_run_snapshot.gd::_between_level_composes_tactical_snapshot_into_level_state` and in `test_run_resume_service.gd::_resume_run_level_streams_equal_embedded_tactical_streams`.
- [Review][Defer][RESOLVED 2026-06-14 in Story 2.8] (Low) The integration round-trip (`test_between_level_save.gd::_assemble_write_read_reparse_round_trip_preserves_fidelity`) restored the embedded tactical `rng_streams` and asserted only that the restore succeeds, not that the restored tactical streams reproduce the same next draw (the run-level streams got that stronger check; the embedded tactical ones did not). (Originating review: code review of 2-7, Round 1, 2026-06-14.) RESOLVED: `test_resume_flow.gd::_embedded_tactical_streams_reproduce_next_draw_after_resume` restores the embedded tactical streams and asserts the exact next-draw reproduction across all seven streams, symmetric with the run-level check.
