# Epic 10 — Auto-GDS retro notes

## Story 10-1-device-tiers-and-performance-budgets
- [Phase 5 — dev-story] Dev Notes assumed `export_presets.cfg` had only Windows + Android scaffolding; on disk it already carries an iOS preset (`preset.2`) scaffold (`runnable=false`, empty signing/icons). AC5 held regardless — all three presets share the identical `exclude_filter` (excludes `tools/**` + `**/test_*.gd`). iOS packaging remains availability gap G7 for the 10.6 gate.
