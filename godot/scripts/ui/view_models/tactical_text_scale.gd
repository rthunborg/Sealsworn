class_name TacticalTextScale
extends RefCounted

## Scene-free scalable-text bounds contract for the tactical HUD.
##
## Story 2.6: this helper takes an injected requested text scale and clamps it to named
## bounds, falling back to 1.0 for malformed input (NaN/inf/zero/negative/non-numeric). It
## emits value-only presenter hints (label sizing and spacing) so a presenter can keep
## essential labels readable and non-overlapping without this helper constructing fonts,
## themes, or final layout.
##
## Text scale is presentation/preferences only. It is NOT save truth, NOT domain state, NOT
## tactical legality, and NOT a settings store. Changing the scale never alters board, RNG,
## turn state, preview legality, action availability, telegraphs, outcome, or event log
## (AC2: "no gameplay rule changes with text scale"). Persistence belongs to Story 2.9.

const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# Named bounds; default is 1.0 (no scaling).
const MIN_TEXT_SCALE: float = 0.85
const MAX_TEXT_SCALE: float = 2.0
const DEFAULT_TEXT_SCALE: float = 1.0

# Stable reason ids.
const REASON_VALID := "valid"
const REASON_CLAMPED_MIN := "clamped_min"
const REASON_CLAMPED_MAX := "clamped_max"
const REASON_INVALID := "invalid_scale"

# Conservative presenter sizing baseline. These are value-only hints for a presenter; the
# minimum touch target / spacing geometry stays owned by TacticalLayoutProfile.
const BASE_LABEL_HEIGHT: float = 14.0

var _requested: float = DEFAULT_TEXT_SCALE
var _scale: float = DEFAULT_TEXT_SCALE
var _clamped: bool = false
var _reason: String = REASON_VALID

func to_dictionary() -> Dictionary:
	var spacing_base: float = TacticalLayoutProfile.COMPACT_SPACING
	var label_baseline: float = maxf(BASE_LABEL_HEIGHT, TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET.y * 0.3)
	return {
		"requested": _requested,
		"scale": _scale,
		"clamped": _clamped,
		"reason": _reason,
		"label_scale_hint": label_baseline * _scale,
		"spacing_hint": spacing_base * _scale,
		"minimum_label_height": label_baseline * _scale
	}


static func from_request(requested_scale: float) -> TacticalTextScale:
	return from_value(requested_scale)


static func from_value(value: Variant) -> TacticalTextScale:
	var text_scale: TacticalTextScale = load("res://scripts/ui/view_models/tactical_text_scale.gd").new()
	if not _is_numeric(value):
		text_scale._requested = DEFAULT_TEXT_SCALE
		text_scale._scale = DEFAULT_TEXT_SCALE
		text_scale._clamped = true
		text_scale._reason = REASON_INVALID
		return text_scale

	var requested: float = float(value)
	text_scale._requested = requested
	if not _is_finite(requested) or requested <= 0.0:
		text_scale._scale = DEFAULT_TEXT_SCALE
		text_scale._clamped = true
		text_scale._reason = REASON_INVALID
		return text_scale

	if requested < MIN_TEXT_SCALE:
		text_scale._scale = MIN_TEXT_SCALE
		text_scale._clamped = true
		text_scale._reason = REASON_CLAMPED_MIN
		return text_scale
	if requested > MAX_TEXT_SCALE:
		text_scale._scale = MAX_TEXT_SCALE
		text_scale._clamped = true
		text_scale._reason = REASON_CLAMPED_MAX
		return text_scale

	text_scale._scale = requested
	text_scale._clamped = false
	text_scale._reason = REASON_VALID
	return text_scale


static func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
