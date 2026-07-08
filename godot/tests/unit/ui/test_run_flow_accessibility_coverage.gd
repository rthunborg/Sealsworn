extends "res://tests/unit/test_case.gd"

# Story 10.5 (Accessibility & Readability Audit — AC1 / AC-support) — the RUN-FLOW-ROSTER extension of the Story 2.6
# tactical-HUD accessibility audit (test_tactical_accessibility_cues.gd). The 2.6 test proves the color-independence +
# scalable-text + audio-off contract on the tactical-HUD / preview / inspect / telegraph surface; it does NOT reach the
# RUN-FLOW affinity/Darkness on-screen reads. This test closes that gap: it drives the REAL LiveAffinityReadModel +
# DarknessReadView projections for a Scorched + a Darkness affinity and asserts that EVERY non-color cue id those
# run-flow read models emit is registered in the LIVE TacticalAccessibilityModel catalog WITH a non-color channel.
#
# It asserts a READINESS FACT, not new gameplay behavior — it executes no command, draws no RNG, mutates nothing (the
# read models are pure). It reads the LIVE catalog via TacticalAccessibilityModel.channels_for_cue() /
# has_non_color_channel() — NEVER a hand-copied cue list — so the roster-coverage assertion self-updates when the catalog
# changes (the DELIBERATE-UPDATE tripwire discipline: a future story that adds a run-flow cue id WITHOUT a non-color
# channel, or drops the channel from an emitted cue, makes this FAIL LOUD, which is intended). It does NOT duplicate the
# 16 tactical-HUD assertions the 2.6 test already owns.

const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DarknessReadView = preload("res://scripts/ui/view_models/darkness_read_view.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const LiveAffinityReadModel = preload("res://scripts/ui/view_models/live_affinity_read_model.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

# The known non-color channel vocabulary (mirrors TacticalAccessibilityModel.CHANNEL_* + test_tactical_accessibility_cues
# .gd). "color" is deliberately absent — a cue that registered "color" as a critical channel would fail the "non-color"
# assertion (NFR9).
const NON_COLOR_CHANNELS: Array[String] = ["shape", "icon", "label", "pattern", "text"]

func run() -> Dictionary:
	_live_affinity_scorched_cue_ids_all_resolve_with_a_non_color_channel()
	_darkness_read_cue_ids_all_resolve_with_a_non_color_channel()
	_live_affinity_darkness_aggregated_cue_ids_all_resolve_with_a_non_color_channel()
	_neutral_read_emits_no_cue_ids_and_stays_valid()
	_every_registered_affinity_and_darkness_catalog_cue_is_non_color()
	_run_flow_text_scale_clamp_holds_across_the_bounds()
	return result()


# AC1 / AC-support (a): the Scorched IN-RUN affinity read (LiveAffinityReadModel.project(&"scorched", board)) surfaces the
# color-independent hazard cue id — and it (and every other id it emits) resolves in the LIVE catalog with a non-color
# channel. This is the run-flow coverage the tactical-HUD 2.6 test does not reach (it audits the tactical previews, not
# the composed on-screen affinity read).
func _live_affinity_scorched_cue_ids_all_resolve_with_a_non_color_channel() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var scorched: Dictionary = model.project(&"scorched", _combat_board())

	var cue_ids: Array = scorched.get("cue_ids", [])
	assert_true(cue_ids.has("affinity_scorched_hazard"), "The Scorched in-run read must surface the color-independent hazard cue id (the run-flow danger read).")
	assert_false(cue_ids.is_empty(), "The Scorched in-run read must surface at least one non-color cue id on a live board.")
	_assert_emitted_cue_ids_are_registered_non_color(cue_ids, "the Scorched LiveAffinityReadModel read")


# AC1 / AC-support (a): the Darkness read (DarknessReadView.project_darkness) surfaces its two FINAL non-color cue ids —
# and each resolves in the LIVE catalog with a non-color channel (the reduced-visibility icon/label/text + the
# memory-uncertain pattern/label/text — so the Darkness pressure reads with color stripped).
func _darkness_read_cue_ids_all_resolve_with_a_non_color_channel() -> void:
	var read_view: DarknessReadView = DarknessReadView.new(AffinityRepository.create_baseline_repository())
	var darkness: Dictionary = read_view.project_darkness(&"darkness")

	var cue_ids: Array = darkness.get("cue_ids", [])
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_REDUCED_VISIBILITY), "The Darkness read must surface the reduced-visibility cue id.")
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN), "The Darkness read must surface the memory-uncertain cue id.")
	assert_equal(cue_ids.size(), 2, "The Darkness read surfaces exactly its two FINAL cue ids.")
	_assert_emitted_cue_ids_are_registered_non_color(cue_ids, "the DarknessReadView read")


# AC1 / AC-support (b): the AGGREGATED LiveAffinityReadModel cue set for a Darkness level (which unions the Darkness read
# cues into `cue_ids`) also resolves entirely in the live catalog — proving the composed on-screen surface the HUD/inspect
# binds carries only registered non-color cue ids.
func _live_affinity_darkness_aggregated_cue_ids_all_resolve_with_a_non_color_channel() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var darkness: Dictionary = model.project(&"darkness", _combat_board())

	var cue_ids: Array = darkness.get("cue_ids", [])
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_REDUCED_VISIBILITY), "The aggregated Darkness in-run read must surface the reduced-visibility cue id.")
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN), "The aggregated Darkness in-run read must surface the memory-uncertain cue id.")
	_assert_emitted_cue_ids_are_registered_non_color(cue_ids, "the aggregated Darkness LiveAffinityReadModel read")


# AC-support: a neutral `none` level is the fail-closed empty read — it emits NO cue id (nothing to audit), and that is a
# valid readable answer, not a gap. (The audit records "no affinity pressure to show" as a legal state, per §15.3.)
func _neutral_read_emits_no_cue_ids_and_stays_valid() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var neutral: Dictionary = model.project(AffinityDefinition.AFFINITY_NONE, _combat_board())
	assert_equal((neutral.get("cue_ids", []) as Array).size(), 0, "A neutral level surfaces no cue ids (nothing to audit — the legal empty read).")


# AC1 (no color-only meaning): a consolidated assertion over the LIVE catalog that EVERY registered affinity + Darkness
# critical cue carries a non-color channel and NEVER a "color" channel. This is the roster-completeness backstop for the
# affinity/Darkness danger vocabulary the run-flow reads bind (the tracked Flooded conductive-danger PLACEHOLDER included:
# even as a placeholder it must carry its non-color `shape` channel). Reads the live catalog through channels_for_cue()
# so it self-updates when the catalog changes.
func _every_registered_affinity_and_darkness_catalog_cue_is_non_color() -> void:
	var cues: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary().get("cues", {})
	var audited: int = 0
	for cue_id_value: Variant in cues.keys():
		var cue_id: String = String(cue_id_value)
		if not cue_id.begins_with("affinity_"):
			continue
		audited += 1
		var channels: Array[String] = TacticalAccessibilityModel.channels_for_cue(cue_id)
		assert_false(channels.has("color"), "Affinity cue '%s' must not register a 'color' channel as a critical meaning channel." % cue_id)
		assert_true(TacticalAccessibilityModel.has_non_color_channel(cue_id), "Affinity cue '%s' must carry at least one non-color channel so its danger reads with color stripped." % cue_id)
		for channel: String in channels:
			assert_true(NON_COLOR_CHANNELS.has(channel), "Affinity cue '%s' channel '%s' must be a known non-color channel." % [cue_id, channel])
	# The tracked Flooded conductive-danger PLACEHOLDER is a registered affinity cue that MUST still carry a non-color
	# channel even as a placeholder (its full treatment is 10.7-owned; the audit records it as a tracked-placeholder
	# finding, not a fix).
	assert_true(TacticalAccessibilityModel.has_non_color_channel("affinity_conductive_danger_placeholder"), "The tracked Flooded conductive-danger placeholder cue must still carry a non-color channel (it reads with color stripped even as a placeholder).")
	assert_true(audited >= 5, "The audit should cover the affinity + Darkness danger cue family (Scorched hazard, Flooded conductive-placeholder + pathing, the 2 Darkness cues).")


# AC-support: the scalable-text clamp `[0.85, 2.0]` (default 1.0) holds for the run-flow roster too (every screen inherits
# it per appendix §14.2). A below-bound request clamps to MIN, an above-bound request clamps to MAX, an in-bounds request
# passes through, and a malformed request falls back to 1.0 with a stable reason — asserted against the LIVE clamp.
func _run_flow_text_scale_clamp_holds_across_the_bounds() -> void:
	var below: Dictionary = TacticalTextScale.from_value(TacticalTextScale.MIN_TEXT_SCALE - 0.5).to_dictionary()
	var above: Dictionary = TacticalTextScale.from_value(TacticalTextScale.MAX_TEXT_SCALE + 0.5).to_dictionary()
	var inside: Dictionary = TacticalTextScale.from_value(1.25).to_dictionary()
	var malformed: Dictionary = TacticalTextScale.from_value("huge").to_dictionary()

	assert_equal(below.get("scale"), TacticalTextScale.MIN_TEXT_SCALE, "A below-bound run-flow text scale clamps to MIN_TEXT_SCALE (non-overlap backing).")
	assert_equal(above.get("scale"), TacticalTextScale.MAX_TEXT_SCALE, "An above-bound run-flow text scale clamps to MAX_TEXT_SCALE.")
	assert_equal(inside.get("scale"), 1.25, "An in-bounds run-flow text scale passes through unchanged.")
	assert_equal(malformed.get("scale"), TacticalTextScale.DEFAULT_TEXT_SCALE, "A malformed run-flow text scale falls back to the 1.0 default.")
	assert_equal(malformed.get("reason"), "invalid_scale", "A malformed run-flow text scale preserves a stable invalid reason.")


# --- helpers ---------------------------------------------------------------

# Every cue id in the emitted set must be registered in the LIVE catalog WITH a non-color channel. Availability/flow
# markers that are not critical-meaning cues (none are emitted by these read models today, but guard defensively) are not
# in scope — the affinity/Darkness reads emit only critical danger/visibility cue ids.
func _assert_emitted_cue_ids_are_registered_non_color(cue_ids: Variant, context_label: String) -> void:
	assert_true(cue_ids is Array, "%s must expose a cue_ids Array." % context_label)
	for cue_id_value: Variant in (cue_ids as Array):
		var cue_id: String = String(cue_id_value)
		assert_true(TacticalAccessibilityModel.has_non_color_channel(cue_id), "Cue '%s' emitted by %s must resolve in the live TacticalAccessibilityModel catalog with a non-color channel." % [cue_id, context_label])
		# Positive belt-and-braces: the resolved channel set is non-empty and every channel is a known non-color id.
		var channels: Array[String] = TacticalAccessibilityModel.channels_for_cue(cue_id)
		assert_false(channels.is_empty(), "Cue '%s' emitted by %s must have at least one registered channel." % [cue_id, context_label])
		for channel: String in channels:
			assert_true(NON_COLOR_CHANNELS.has(channel), "Cue '%s' (from %s) channel '%s' must be a known non-color channel." % [cue_id, context_label, channel])


# A small all-FLOOR board (through CreateBoardCommand so the shape is the real BoardState) so the Scorched preview surfaces
# its affected hazard cells + the hazard cue id (the LiveAffinityReadModel._combat_board helper pattern).
func _combat_board() -> BoardState:
	var board: BoardState = BoardState.new()
	var create: Variant = CreateBoardCommand.new(6, 6).execute(board)
	assert_true(create.succeeded, "Setup: the preview board should build.")
	return board
