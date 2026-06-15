class_name SettingsSnapshot
extends RefCounted

## Player-preferences DTO (Story 2.9). Data-layer only — NOT a Node, NOT an autoload, NO scene
## nodes. Holds SAFE user preferences only: text scale, audio volume/mute, an input preference,
## and two presentation-hint accessibility toggles. It mirrors the RunSnapshot DTO shape
## (schema/content version, typed fields, to_dictionary()/parse()/from_dictionary()/defaults())
## but persists to its OWN user://settings.json through SettingsRepository — it is never folded
## into the run autosave and never holds run/tactical/RNG/progression state.
##
## DIFFICULTY NON-GOAL (AC2/AC3): Sealsworn has NO player-selectable difficulty tiers. MVP
## difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards,
## resource attrition, and boss preparation. Post-MVP challenge content is explicit variant
## content / trials / oaths / special runs — never a generic difficulty ladder. This DTO therefore
## carries NO field that scales enemy stats, HP, damage, reward rates, RNG, or run length, and
## PREFERENCE_KEYS contains none. A regression test enforces the absence of difficulty keys.
## [Source: gdd.md#Difficulty Modifiers — "Difficulty and Challenge Systems Baseline v0", lines 397-405]

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

const SCHEMA_VERSION: int = 1
const DEFAULT_CONTENT_VERSION := "mvp-0"

# Audio: a named, bounded master-volume range. 0 dB is unity gain (default); -60 dB is the
# practical "near silent" floor. These are small bounded floats that round-trip exactly through
# JSON — no int64-string encoding is needed (unlike the run save's RNG state).
const MIN_VOLUME_DB: float = -60.0
const MAX_VOLUME_DB: float = 0.0
const DEFAULT_VOLUME_DB: float = 0.0

# Input preference: a small fixed allowlist. Unknown values fall back to "auto".
const INPUT_SCHEME_AUTO := "auto"
const INPUT_SCHEME_TOUCH := "touch"
const INPUT_SCHEME_MOUSE_KEYBOARD := "mouse_keyboard"
const INPUT_SCHEMES: Array[String] = [INPUT_SCHEME_AUTO, INPUT_SCHEME_TOUCH, INPUT_SCHEME_MOUSE_KEYBOARD]
const DEFAULT_INPUT_SCHEME := INPUT_SCHEME_AUTO

# The documented preference key surface. The difficulty non-goal regression test asserts this
# list (and to_dictionary()) contain NONE of the forbidden difficulty keys.
const PREFERENCE_KEYS: Array[String] = [
	"text_scale",
	"master_volume_db",
	"audio_muted",
	"input_scheme",
	"colorblind_safe",
	"high_contrast"
]

var schema_version: int = SCHEMA_VERSION
var content_version: String = DEFAULT_CONTENT_VERSION
var text_scale: float = TacticalTextScale.DEFAULT_TEXT_SCALE
var master_volume_db: float = DEFAULT_VOLUME_DB
var audio_muted: bool = false
var input_scheme: String = DEFAULT_INPUT_SCHEME
# Presentation HINTS only: these map to the Story 2.6 non-color cue / readability layer at the
# presenter boundary. Settings stores the boolean preference; it does NOT own or duplicate the
# accessibility cue catalog (TacticalAccessibilityModel: "NOT a settings store").
var colorblind_safe: bool = false
var high_contrast: bool = false

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_version": content_version,
		"text_scale": text_scale,
		"master_volume_db": master_volume_db,
		"audio_muted": audio_muted,
		"input_scheme": input_scheme,
		"colorblind_safe": colorblind_safe,
		"high_contrast": high_contrast
	}


static func defaults() -> SettingsSnapshot:
	return load("res://scripts/settings/settings_snapshot.gd").new()


# Strict-on-schema, lenient-on-fields parse. The ONLY hard failure is a schema-version mismatch
# (a settings file from an incompatible build). Every other field is sanitized deterministically:
# coerced, clamped to named bounds, or defaulted for missing/NaN/inf/out-of-range/wrong-type
# values. Preferences must degrade gracefully so a slightly stale/partial settings file still
# loads. Each field's sanitization lives in exactly ONE place (the helpers below).
static func parse(data: Dictionary) -> ActionResult:
	var schema_value: int = int(data.get("schema_version", -1))
	if schema_value != SCHEMA_VERSION:
		return ActionResult.error(&"unsupported_settings_schema", {
			"expected_schema_version": SCHEMA_VERSION,
			"actual_schema_version": schema_value
		})

	var snapshot: SettingsSnapshot = defaults()
	snapshot.schema_version = schema_value
	snapshot.content_version = str(data.get("content_version", DEFAULT_CONTENT_VERSION))
	snapshot.text_scale = _sanitize_text_scale(data.get("text_scale", TacticalTextScale.DEFAULT_TEXT_SCALE))
	snapshot.master_volume_db = _sanitize_volume_db(data.get("master_volume_db", DEFAULT_VOLUME_DB))
	snapshot.audio_muted = bool(data.get("audio_muted", false))
	snapshot.input_scheme = _sanitize_input_scheme(data.get("input_scheme", DEFAULT_INPUT_SCHEME))
	snapshot.colorblind_safe = bool(data.get("colorblind_safe", false))
	snapshot.high_contrast = bool(data.get("high_contrast", false))
	return ActionResult.ok([], {"snapshot": snapshot})


static func from_dictionary(data: Dictionary) -> SettingsSnapshot:
	var result: ActionResult = parse(data)
	if result.is_error():
		push_error("SettingsSnapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("snapshot")


# Reuse the canonical text-scale clamp (TacticalTextScale) rather than writing a second one.
# from_value() already handles NaN/inf/<=0/non-numeric -> DEFAULT and clamps to [MIN, MAX].
static func _sanitize_text_scale(value: Variant) -> float:
	return TacticalTextScale.from_value(value).to_dictionary().get("scale", TacticalTextScale.DEFAULT_TEXT_SCALE)


static func _sanitize_volume_db(value: Variant) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return DEFAULT_VOLUME_DB
	var numeric: float = float(value)
	if is_nan(numeric) or is_inf(numeric):
		return DEFAULT_VOLUME_DB
	return clampf(numeric, MIN_VOLUME_DB, MAX_VOLUME_DB)


static func _sanitize_input_scheme(value: Variant) -> String:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return DEFAULT_INPUT_SCHEME
	var text: String = String(value)
	if INPUT_SCHEMES.has(text):
		return text
	return DEFAULT_INPUT_SCHEME
