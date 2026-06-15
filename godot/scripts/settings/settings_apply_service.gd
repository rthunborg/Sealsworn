class_name SettingsApplyService
extends RefCounted

## Thin immediate-apply path for player preferences (Story 2.9, AC4). Given a SettingsSnapshot it
## drives the audio Master bus through AudioManager and surfaces the clamped text-scale presenter
## hint (via TacticalTextScale) for a HUD/inspect presenter to consume. It is presentation/
## preferences ONLY: it executes no commands, draws no RNG, mutates no tactical truth, rewards, or
## progression. Applying any preference therefore leaves board/RNG snapshots byte-identical
## (AC1's "without mutating tactical truth, RNG state, rewards, or progression"; Story 2.6's
## "no gameplay rule changes with text scale").
##
## The input_scheme preference is round-tripped/stored here as metadata only; wiring it to live
## input handling (InputMap, touch vs mouse_keyboard routing) is a later input/presenter layer.
## colorblind_safe/high_contrast are echoed as presentation hints a presenter passes to the
## Story 2.6 non-color cue layer; this service does not own that catalog.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

# Apply the given snapshot. Audio is driven through the injected audio target (defaults to the
# AudioManager autoload when present in the scene tree); when no target is available (e.g. a bare
# headless test instance), the audio drive is skipped and the snapshot values are still echoed in
# metadata. AudioManager already guards a missing Master bus, so this never crashes headlessly.
func apply(snapshot: SettingsSnapshot, audio_target: Object = null) -> ActionResult:
	if snapshot == null:
		return ActionResult.error(&"missing_settings_snapshot", {"field": "snapshot"})

	var target: Object = audio_target
	if target == null:
		target = _resolve_audio_manager()
	if target != null and target.has_method("set_master_volume_db"):
		target.set_master_volume_db(snapshot.master_volume_db)
	if target != null and target.has_method("mute_master"):
		target.mute_master(snapshot.audio_muted)

	# Re-clamp through the canonical text-scale helper so the presenter hint always reflects the
	# bounded value even if a stored snapshot field were somehow out of range.
	var text_scale_hint: Dictionary = TacticalTextScale.from_value(snapshot.text_scale).to_dictionary()

	return ActionResult.ok([], {
		"master_volume_db": snapshot.master_volume_db,
		"audio_muted": snapshot.audio_muted,
		"text_scale_hint": text_scale_hint,
		"input_scheme": snapshot.input_scheme,
		"colorblind_safe": snapshot.colorblind_safe,
		"high_contrast": snapshot.high_contrast,
		"audio_applied": target != null
	})


# Resolve the AudioManager autoload from the main loop when running inside a full tree. Returns
# null in a bare RefCounted test context (no scene tree / autoload), in which case the audio drive
# is simply skipped (the no-mutation and metadata contracts still hold).
func _resolve_audio_manager() -> Object:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var root: Window = (loop as SceneTree).root
		if root != null and root.has_node("AudioManager"):
			return root.get_node("AudioManager")
	return null
