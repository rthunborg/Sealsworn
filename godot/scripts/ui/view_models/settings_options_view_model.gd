class_name SettingsOptionsViewModel
extends RefCounted

# Story 15.4 (Review D1) — the scene-free MINIMAL OPTIONS projection + PURE MUTATION helpers, built over the EXISTING
# Story-2.9 settings domain ONLY (SettingsSnapshot's six safe preference keys + SettingsRepository/SettingsApplyService
# via the SettingsManager autoload). It is the testable authority behind the Options panel the shared pause menu opens:
# rows(snapshot) projects the current preferences into editable display rows; apply(snapshot, option_id) returns a NEW
# SettingsSnapshot with exactly ONE preference advanced (a bool toggled, an enumerated/stepped value cycled). The
# presenter renders the rows + on interaction calls apply() then SettingsManager.save_settings (which persists + applies).
#
# ⭐ ADDS NO SETTINGS KEY, NO DOMAIN/SETTINGS SYSTEM, and does NOT touch the difficulty non-goal. It edits ONLY the six
# existing SettingsSnapshot.PREFERENCE_KEYS (text_scale, master_volume_db, audio_muted, input_scheme, colorblind_safe,
# high_contrast). The mutation round-trips through SettingsSnapshot.to_dictionary() -> from_dictionary() so every new
# value is re-sanitized/clamped by the EXISTING parse gate (no second clamp copy). SettingsSnapshot keeps carrying ZERO
# difficulty keys — this view model introduces none. A pure read/build: no RNG, no scene node, no autoload reach.
#
# ⭐ EXACT-KEY (the ratified seam discipline): each row has the pinned ROW_KEYS; OPTION_IDS is the pinned editable set.

const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")

# The editable options, in stable render order. Each id maps 1:1 to a SettingsSnapshot preference key.
const OPTION_IDS: Array[String] = [
	"text_scale",
	"master_volume_db",
	"audio_muted",
	"input_scheme",
	"colorblind_safe",
	"high_contrast"
]

# The stable key set of each row dict (pinned by test).
const ROW_KEYS: Array[String] = ["id", "label", "value_display"]

# The cycle steps for the stepped (non-bool, non-enum) preferences. All values sit INSIDE the SettingsSnapshot /
# TacticalTextScale bounds so the re-sanitizing round-trip preserves them exactly. Index-based cycling (wrap at the
# end) so any stored value maps to the nearest step, then advances.
const TEXT_SCALE_STEPS: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]
const VOLUME_DB_STEPS: Array[float] = [0.0, -10.0, -20.0, -40.0, -60.0]

# The human display label per option id.
const _LABELS: Dictionary = {
	"text_scale": "Text Size",
	"master_volume_db": "Master Volume",
	"audio_muted": "Mute Audio",
	"input_scheme": "Input Scheme",
	"colorblind_safe": "Colorblind-Safe Cues",
	"high_contrast": "High Contrast"
}

# Project the snapshot into editable rows (id + label + current value_display). A null snapshot falls back to
# defaults so the panel always renders. Each row is exact-key (ROW_KEYS).
static func rows(snapshot: SettingsSnapshot) -> Array[Dictionary]:
	var resolved: SettingsSnapshot = snapshot if snapshot != null else SettingsSnapshot.defaults()
	var result: Array[Dictionary] = []
	for option_id: String in OPTION_IDS:
		result.append({
			"id": option_id,
			"label": String(_LABELS.get(option_id, option_id)),
			"value_display": _value_display(resolved, option_id)
		})
	return result


# Return a NEW SettingsSnapshot with exactly ONE preference advanced (a bool toggled, a stepped/enumerated value
# cycled with wrap). An unknown option id returns the snapshot unchanged. The mutation round-trips through the
# existing parse gate so the new value is re-sanitized/clamped (no new key can appear). Never returns null.
static func apply(snapshot: SettingsSnapshot, option_id: String) -> SettingsSnapshot:
	var resolved: SettingsSnapshot = snapshot if snapshot != null else SettingsSnapshot.defaults()
	if not OPTION_IDS.has(option_id):
		return resolved
	var data: Dictionary = resolved.to_dictionary()
	match option_id:
		"text_scale":
			data["text_scale"] = _cycle_float(TEXT_SCALE_STEPS, resolved.text_scale)
		"master_volume_db":
			data["master_volume_db"] = _cycle_float(VOLUME_DB_STEPS, resolved.master_volume_db)
		"audio_muted":
			data["audio_muted"] = not resolved.audio_muted
		"input_scheme":
			data["input_scheme"] = _cycle_string(SettingsSnapshot.INPUT_SCHEMES, resolved.input_scheme)
		"colorblind_safe":
			data["colorblind_safe"] = not resolved.colorblind_safe
		"high_contrast":
			data["high_contrast"] = not resolved.high_contrast
	var mutated: SettingsSnapshot = SettingsSnapshot.from_dictionary(data)
	return mutated if mutated != null else resolved


# The display string for a preference's current value (a bool as On/Off, a scale as a percentage, a volume as dB, an
# input scheme prettified). Display-only glue — the value_display is derived, never a raw snake_case id.
static func _value_display(snapshot: SettingsSnapshot, option_id: String) -> String:
	match option_id:
		"text_scale":
			return "%d%%" % int(round(snapshot.text_scale * 100.0))
		"master_volume_db":
			return "%d dB" % int(round(snapshot.master_volume_db))
		"audio_muted":
			return _on_off(snapshot.audio_muted)
		"input_scheme":
			return String(snapshot.input_scheme).capitalize()
		"colorblind_safe":
			return _on_off(snapshot.colorblind_safe)
		"high_contrast":
			return _on_off(snapshot.high_contrast)
		_:
			return ""


static func _on_off(value: bool) -> String:
	return "On" if value else "Off"


# Advance a float preference to the next step (wrapping): find the step nearest the current value, return the next.
static func _cycle_float(steps: Array[float], current: float) -> float:
	if steps.is_empty():
		return current
	var nearest_index: int = 0
	var nearest_distance: float = absf(steps[0] - current)
	for index: int in range(1, steps.size()):
		var distance: float = absf(steps[index] - current)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return steps[(nearest_index + 1) % steps.size()]


# Advance a string enum preference to the next value (wrapping). An unknown current value starts the cycle at index 0.
static func _cycle_string(values: Array[String], current: String) -> String:
	if values.is_empty():
		return current
	var index: int = values.find(current)
	if index < 0:
		index = 0
		return values[index]
	return values[(index + 1) % values.size()]
