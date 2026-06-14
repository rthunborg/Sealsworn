class_name TacticalLayoutProfile
extends RefCounted

## Scene-free adaptive layout profile for the tactical HUD.
##
## Story 2.5: this helper classifies an injected viewport (plus optional safe area,
## content scale, and platform hint) into a stable profile id and produces a semantic,
## value-only HUD layout plan. It is a presentation contract only: it never owns tactical
## truth, never executes commands, never consumes gameplay RNG, and never reaches into
## DisplayServer/Window/Viewport. Presenters or platform glue inject real viewport/safe-area
## values; headless tests inject fixtures.

const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")

# Stable profile ids.
const PROFILE_PHONE_PORTRAIT := "phone_portrait"
const PROFILE_PHONE_LANDSCAPE := "phone_landscape"
const PROFILE_TABLET := "tablet"
const PROFILE_DESKTOP := "desktop"

# Stable orientation ids.
const ORIENTATION_PORTRAIT := "portrait"
const ORIENTATION_LANDSCAPE := "landscape"
const ORIENTATION_SQUARE := "square"

# v0 classification thresholds kept as named constants so later device-tier work can tune
# them without rewriting tests.
const PHONE_MAX_DIMENSION: float = 700.0
const DESKTOP_MIN_WIDTH: float = 1280.0

# Conservative reachability constants. These are NOT final accessibility settings; Story 2.6
# owns the broader readable-text and colorblind audit.
const DEFAULT_MINIMUM_TOUCH_TARGET: Vector2 = Vector2(44.0, 44.0)
const COMPACT_SPACING: float = 8.0
const COMFORTABLE_SPACING: float = 12.0

const DEFAULT_CONTENT_SCALE: float = 1.0
const MIN_CONTENT_SCALE: float = 0.5
const MAX_CONTENT_SCALE: float = 4.0

const REASON_VALID := "valid"
const REASON_FALLBACK_INVALID_VIEWPORT := "fallback_invalid_viewport"

const _REGION_NAMES: Array[String] = [
	"board",
	"preview",
	"confirm_cancel",
	"inspect",
	"status",
	"log_or_outcome"
]

var _profile_id: String = PROFILE_PHONE_PORTRAIT
var _orientation: String = ORIENTATION_PORTRAIT
var _viewport_size: Vector2 = Vector2.ZERO
var _safe_area: Rect2 = Rect2()
var _content_area: Rect2 = Rect2()
var _content_scale: float = DEFAULT_CONTENT_SCALE
var _board_priority: String = "primary"
var _density: String = "compact"
var _spacing: float = COMPACT_SPACING
var _minimum_touch_target: Vector2 = DEFAULT_MINIMUM_TOUCH_TARGET
var _regions: Dictionary = {}
var _control_slots: Dictionary = {}
var _reason: String = REASON_VALID
var _available: bool = true
var _cue_ids: Array[String] = []

func to_dictionary() -> Dictionary:
	return {
		"kind": "layout_profile",
		"profile_id": _profile_id,
		"orientation": _orientation,
		"viewport_size": _point(_viewport_size),
		"safe_area": _rect(_safe_area),
		"content_area": _rect(_content_area),
		"content_scale": _content_scale,
		"board_priority": _board_priority,
		"density": _density,
		"spacing": _spacing,
		"minimum_touch_target": _point(_minimum_touch_target),
		"regions": _regions.duplicate(true),
		"control_slots": _control_slots.duplicate(true),
		"reason": _reason,
		"available": _available,
		"cue_ids": _cue_ids.duplicate()
	}


static func from_viewport(options: Dictionary = {}) -> TacticalLayoutProfile:
	var profile: TacticalLayoutProfile = load("res://scripts/ui/view_models/tactical_layout_profile.gd").new()
	var viewport_size: Vector2 = _viewport_size_from_options(options)
	profile._content_scale = _content_scale_from_options(options)

	if not _is_valid_viewport(viewport_size):
		profile._build_fallback()
		return profile

	profile._viewport_size = viewport_size
	profile._orientation = _orientation_for(viewport_size)
	profile._profile_id = _profile_id_for(viewport_size)
	profile._density = _density_for(profile._profile_id)
	profile._spacing = _spacing_for(profile._profile_id)
	profile._board_priority = "primary"

	var safe_area_result: Dictionary = _safe_area_from_options(options, viewport_size)
	profile._safe_area = safe_area_result.get("rect")
	profile._content_area = profile._safe_area
	profile._build_layout()

	profile._cue_ids = profile._build_cue_ids(bool(safe_area_result.get("applied", false)), false)
	profile._reason = REASON_VALID
	profile._available = true
	return profile


# --- classification --------------------------------------------------------

static func _profile_id_for(viewport_size: Vector2) -> String:
	var width: float = viewport_size.x
	var height: float = viewport_size.y
	if width < PHONE_MAX_DIMENSION and height >= width:
		return PROFILE_PHONE_PORTRAIT
	if height < PHONE_MAX_DIMENSION and width > height:
		return PROFILE_PHONE_LANDSCAPE
	if width >= DESKTOP_MIN_WIDTH and width >= height:
		return PROFILE_DESKTOP
	return PROFILE_TABLET


static func _orientation_for(viewport_size: Vector2) -> String:
	if is_equal_approx(viewport_size.x, viewport_size.y):
		return ORIENTATION_SQUARE
	if viewport_size.x > viewport_size.y:
		return ORIENTATION_LANDSCAPE
	return ORIENTATION_PORTRAIT


static func _density_for(profile_id: String) -> String:
	match profile_id:
		PROFILE_DESKTOP, PROFILE_TABLET:
			return "comfortable"
		_:
			return "compact"


static func _spacing_for(profile_id: String) -> float:
	match profile_id:
		PROFILE_DESKTOP, PROFILE_TABLET:
			return COMFORTABLE_SPACING
		_:
			return COMPACT_SPACING


# --- layout planning -------------------------------------------------------

func _build_layout() -> void:
	match _profile_id:
		PROFILE_PHONE_LANDSCAPE:
			_build_side_rail_layout()
		_:
			_build_stacked_layout()
	_build_control_slots()


## Portrait phone / tablet / desktop: board on top as the dominant region, with stacked
## reachable control bands beneath it along the lower edge.
func _build_stacked_layout() -> void:
	var area: Rect2 = _content_area
	var control_height: float = maxf(_minimum_touch_target.y, area.size.y * 0.07)
	# Four stacked control bands: preview, confirm/cancel, inspect, status.
	var bands: int = 4
	var controls_total: float = control_height * float(bands)
	# Reserve room for an optional log/outcome strip on wider, taller profiles.
	var log_height: float = 0.0
	if _profile_id == PROFILE_DESKTOP or _profile_id == PROFILE_TABLET:
		log_height = maxf(_minimum_touch_target.y, area.size.y * 0.06)
	var board_height: float = area.size.y - controls_total - log_height
	# Guarantee the board stays the largest region even on short content areas.
	var min_board_height: float = controls_total + log_height + 1.0
	if board_height < min_board_height:
		board_height = maxf(area.size.y * 0.5, board_height)
		var remaining: float = area.size.y - board_height
		control_height = maxf(1.0, (remaining - log_height) / float(bands))
		if log_height > remaining - control_height * float(bands):
			log_height = maxf(0.0, remaining - control_height * float(bands))

	var cursor_y: float = area.position.y
	_regions["board"] = _make_rect(area.position.x, cursor_y, area.size.x, board_height)
	cursor_y += board_height
	_regions["preview"] = _make_rect(area.position.x, cursor_y, area.size.x, control_height)
	cursor_y += control_height
	_regions["confirm_cancel"] = _make_rect(area.position.x, cursor_y, area.size.x, control_height)
	cursor_y += control_height
	_regions["inspect"] = _make_rect(area.position.x, cursor_y, area.size.x, control_height)
	cursor_y += control_height
	_regions["status"] = _make_rect(area.position.x, cursor_y, area.size.x, control_height)
	cursor_y += control_height
	if log_height > 0.0:
		_regions["log_or_outcome"] = _make_rect(area.position.x, cursor_y, area.size.x, log_height)
	else:
		_regions["log_or_outcome"] = _empty_rect()


## Landscape phone: board prioritized on the left, controls relocated to a right-side rail
## so the board stays central/left and panels do not consume the full width.
func _build_side_rail_layout() -> void:
	var area: Rect2 = _content_area
	var rail_width: float = clampf(area.size.x * 0.32, _minimum_touch_target.x, area.size.x - _minimum_touch_target.x)
	var board_width: float = area.size.x - rail_width
	var rail_x: float = area.position.x + board_width
	_regions["board"] = _make_rect(area.position.x, area.position.y, board_width, area.size.y)

	# Stack the four primary controls vertically inside the right rail.
	var bands: int = 4
	var band_height: float = maxf(_minimum_touch_target.y, area.size.y / float(bands))
	# Avoid overflow if the rail is too short for four full bands.
	if band_height * float(bands) > area.size.y:
		band_height = area.size.y / float(bands)
	var cursor_y: float = area.position.y
	_regions["preview"] = _make_rect(rail_x, cursor_y, rail_width, band_height)
	cursor_y += band_height
	_regions["confirm_cancel"] = _make_rect(rail_x, cursor_y, rail_width, band_height)
	cursor_y += band_height
	_regions["inspect"] = _make_rect(rail_x, cursor_y, rail_width, band_height)
	cursor_y += band_height
	_regions["status"] = _make_rect(rail_x, cursor_y, rail_width, band_height)
	_regions["log_or_outcome"] = _empty_rect()


func _build_control_slots() -> void:
	_control_slots = {
		"preview": _control_slot("preview"),
		"confirm": _control_slot("confirm_cancel"),
		"cancel": _control_slot("confirm_cancel"),
		"inspect": _control_slot("inspect"),
		"status": _control_slot("status")
	}


func _control_slot(region_name: String) -> Dictionary:
	var region: Dictionary = _regions.get(region_name, {})
	var reachable: bool = _region_is_reachable(region)
	return {
		"region": region_name,
		"reachable": reachable
	}


func _region_is_reachable(region: Dictionary) -> bool:
	if region.is_empty():
		return false
	var width: float = float(region.get("width", 0.0))
	var height: float = float(region.get("height", 0.0))
	if width < _minimum_touch_target.x or height < _minimum_touch_target.y:
		return false
	return _rect_inside_content(region)


func _rect_inside_content(region: Dictionary) -> bool:
	var x: float = float(region.get("x", 0.0))
	var y: float = float(region.get("y", 0.0))
	var right: float = x + float(region.get("width", 0.0))
	var bottom: float = y + float(region.get("height", 0.0))
	return (
		x >= _content_area.position.x - 0.01
		and y >= _content_area.position.y - 0.01
		and right <= _content_area.position.x + _content_area.size.x + 0.01
		and bottom <= _content_area.position.y + _content_area.size.y + 0.01
	)


func _build_cue_ids(safe_area_applied: bool, is_fallback: bool) -> Array[String]:
	var cue_ids: Array[String] = []
	cue_ids.append("layout_profile_%s" % _profile_id)
	cue_ids.append("layout_orientation_%s" % _orientation)
	if safe_area_applied:
		cue_ids.append("layout_safe_area_applied")
	if is_fallback:
		cue_ids.append("layout_fallback")
	return cue_ids


# --- fallback --------------------------------------------------------------

func _build_fallback() -> void:
	_profile_id = PROFILE_PHONE_PORTRAIT
	_orientation = ORIENTATION_PORTRAIT
	_viewport_size = Vector2.ZERO
	_safe_area = Rect2()
	_content_area = Rect2()
	_board_priority = "primary"
	_density = "compact"
	_spacing = COMPACT_SPACING
	_minimum_touch_target = DEFAULT_MINIMUM_TOUCH_TARGET
	_regions = _empty_region_set()
	_build_control_slots()
	_reason = REASON_FALLBACK_INVALID_VIEWPORT
	_available = false
	_cue_ids = _build_cue_ids(false, true)


static func _empty_region_set() -> Dictionary:
	var regions: Dictionary = {}
	for region_name: String in _REGION_NAMES:
		regions[region_name] = {
			"x": 0.0,
			"y": 0.0,
			"width": 0.0,
			"height": 0.0
		}
	return regions


# --- option parsing --------------------------------------------------------

static func _viewport_size_from_options(options: Dictionary) -> Vector2:
	var value: Variant = TacticalPreviewView.field(options, &"viewport_size", null)
	if value is Vector2:
		return value
	if value is Vector2i:
		var vector_i: Vector2i = value
		return Vector2(float(vector_i.x), float(vector_i.y))
	if value is Dictionary:
		var data: Dictionary = value
		var x_value: Variant = TacticalPreviewView.field(data, &"x", null)
		var y_value: Variant = TacticalPreviewView.field(data, &"y", null)
		if _is_numeric(x_value) and _is_numeric(y_value):
			return Vector2(float(x_value), float(y_value))
	return Vector2(-1.0, -1.0)


static func _content_scale_from_options(options: Dictionary) -> float:
	var value: Variant = TacticalPreviewView.field(options, &"content_scale", DEFAULT_CONTENT_SCALE)
	if not _is_numeric(value):
		return DEFAULT_CONTENT_SCALE
	var numeric_value: float = float(value)
	if not _is_finite(numeric_value) or numeric_value <= 0.0:
		return DEFAULT_CONTENT_SCALE
	return clampf(numeric_value, MIN_CONTENT_SCALE, MAX_CONTENT_SCALE)


static func _safe_area_from_options(options: Dictionary, viewport_size: Vector2) -> Dictionary:
	var full_area: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	if not TacticalPreviewView.has_field(options, &"safe_area"):
		return {
			"rect": full_area,
			"applied": false
		}
	var parsed: Variant = _rect_from_value(TacticalPreviewView.field(options, &"safe_area", null))
	if not parsed is Rect2:
		return {
			"rect": full_area,
			"applied": false
		}

	var safe_rect: Rect2 = parsed
	# Clamp the injected safe area to the viewport bounds; a safe area that exceeds the
	# viewport or has non-positive size falls back to the full viewport.
	var clamped: Rect2 = full_area.intersection(safe_rect)
	if clamped.size.x <= 0.0 or clamped.size.y <= 0.0:
		return {
			"rect": full_area,
			"applied": false
		}
	var applied: bool = not clamped.is_equal_approx(full_area)
	return {
		"rect": clamped,
		"applied": applied
	}


static func _rect_from_value(value: Variant) -> Variant:
	if value is Rect2:
		var rect2: Rect2 = value
		if _rect_is_finite(rect2):
			return rect2
		return null
	if value is Rect2i:
		var rect2i: Rect2i = value
		return Rect2(float(rect2i.position.x), float(rect2i.position.y), float(rect2i.size.x), float(rect2i.size.y))
	if value is Dictionary:
		var data: Dictionary = value
		var x_value: Variant = TacticalPreviewView.field(data, &"x", null)
		var y_value: Variant = TacticalPreviewView.field(data, &"y", null)
		var width_value: Variant = TacticalPreviewView.field(data, &"width", null)
		var height_value: Variant = TacticalPreviewView.field(data, &"height", null)
		if not (_is_numeric(x_value) and _is_numeric(y_value) and _is_numeric(width_value) and _is_numeric(height_value)):
			return null
		var rect: Rect2 = Rect2(float(x_value), float(y_value), float(width_value), float(height_value))
		if _rect_is_finite(rect):
			return rect
		return null
	return null


# --- numeric guards --------------------------------------------------------

static func _is_valid_viewport(viewport_size: Vector2) -> bool:
	if not _is_finite(viewport_size.x) or not _is_finite(viewport_size.y):
		return false
	return viewport_size.x > 0.0 and viewport_size.y > 0.0


static func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _rect_is_finite(rect: Rect2) -> bool:
	return (
		_is_finite(rect.position.x)
		and _is_finite(rect.position.y)
		and _is_finite(rect.size.x)
		and _is_finite(rect.size.y)
	)


# --- geometry serialization ------------------------------------------------

func _make_rect(x: float, y: float, width: float, height: float) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"width": maxf(0.0, width),
		"height": maxf(0.0, height)
	}


func _empty_rect() -> Dictionary:
	return {
		"x": 0.0,
		"y": 0.0,
		"width": 0.0,
		"height": 0.0
	}


static func _point(point: Vector2) -> Dictionary:
	return {
		"x": point.x,
		"y": point.y
	}


static func _rect(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y
	}
