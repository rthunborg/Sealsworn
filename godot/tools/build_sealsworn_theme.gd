extends SceneTree

# Story 14.11 — one-shot dev tool: assemble the shared Sealsworn UI `Theme` (.tres) from the
# imported Recraft frame kit (`button_plate`/`panel_frame`/`modal_frame`). NOT a test (lives under
# tools/, never auto-discovered by the runner). Regenerate after re-importing the kit via:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/build_sealsworn_theme.gd
#
# WHAT IT BUILDS (presentation-only — no domain/RNG/save/scene touch):
#   - Button / Panel / PanelContainer nine-patch StyleBoxTextures from the plate SVGs (BORDER frames,
#     transparent center, so the existing dark app background + light font stay readable — no white fill).
#   - A distinct opaque `RewardOverlay` (Panel variation) modal StyleBox from the dark modal_frame plate.
#   - A `default_font_size` + the two prominent 22px label variations (HudTurnLabel / HudTurnLabelActive /
#     RewardHeader) and the spacing/height constants (HudBox / RewardBox separation, HudHpBar bar_height) —
#     folding the Story-14.10 fixed-pixel HUD/reward cosmetics into the Theme (deferred-work.md:1512).
#   - GRACEFUL DEGRADATION: an unresolved kit texture yields a null-texture StyleBox (draws nothing, no
#     crash); the Theme still saves + loads and the compile guardrail stays green.

const OUTPUT := "res://assets/ui/sealsworn_theme.tres"
const BUTTON_PLATE := "res://assets/ui/button_plate.svg"
const PANEL_FRAME := "res://assets/ui/panel_frame.svg"
const MODAL_FRAME := "res://assets/ui/modal_frame.svg"

# Nine-patch border insets (in 2048² texture pixels). Modest so short control bands + >=44px buttons do
# not overflow their borders; the modal is content-area sized so it carries a heavier frame. Tunable in the
# deferred on-device visual pass — exact fidelity is not gated by the (verify-by-construction) suite.
const BUTTON_MARGIN := 20.0
const PANEL_MARGIN := 24.0
const MODAL_MARGIN := 96.0

# Folded 14.10/13.2 cosmetics (fonts / spacing / bar height) — the Theme now owns these, not the presenter.
const BASE_FONT_SIZE := 16
const PROMINENT_FONT_SIZE := 22
const HUD_SEPARATION := 2
const REWARD_SEPARATION := 8
const HP_BAR_HEIGHT := 10


func _init() -> void:
	var theme := Theme.new()
	theme.default_font_size = BASE_FONT_SIZE

	var button_texture := _load_texture(BUTTON_PLATE)
	var panel_texture := _load_texture(PANEL_FRAME)
	var modal_texture := _load_texture(MODAL_FRAME)

	# Buttons: a bordered plate on every state (nine-patch border, transparent center). >=44px targets keep
	# their own custom_minimum_size in the presenter; the Theme adds the frame skin.
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "Button", _frame_box(button_texture, BUTTON_MARGIN, false))

	# Panels: the shared panel frame on Panel + PanelContainer (border only — the region bands + status
	# panel get an intentional frame without a heavy fill that would fight the light font).
	theme.set_stylebox("panel", "Panel", _frame_box(panel_texture, PANEL_MARGIN, false))
	theme.set_stylebox("panel", "PanelContainer", _frame_box(panel_texture, PANEL_MARGIN, false))

	# Prominent label variations (fold the 14.10 turn-label font 22 + the reward header font 22). The active
	# player-turn variation carries a themed emphasis background so `turn_is_player` reads as more than a word.
	theme.set_type_variation("HudTurnLabel", "Label")
	theme.set_font_size("font_size", "HudTurnLabel", PROMINENT_FONT_SIZE)
	theme.set_type_variation("HudTurnLabelActive", "Label")
	theme.set_font_size("font_size", "HudTurnLabelActive", PROMINENT_FONT_SIZE)
	theme.set_stylebox("normal", "HudTurnLabelActive", _turn_emphasis_box())
	theme.set_type_variation("RewardHeader", "Label")
	theme.set_font_size("font_size", "RewardHeader", PROMINENT_FONT_SIZE)

	# Spacing variations (fold the HUD VBox separation 2 + the reward box separation 8).
	theme.set_type_variation("HudBox", "VBoxContainer")
	theme.set_constant("separation", "HudBox", HUD_SEPARATION)
	theme.set_type_variation("RewardBox", "VBoxContainer")
	theme.set_constant("separation", "RewardBox", REWARD_SEPARATION)

	# HP bar (fold the 10.0 height into a Theme constant the presenter reads).
	theme.set_type_variation("HudHpBar", "ProgressBar")
	theme.set_constant("bar_height", "HudHpBar", HP_BAR_HEIGHT)

	# The reward/passive modal panel: a distinct OPAQUE dark frame (the dark modal_frame plate) so the modal
	# covers the board behind it. draw_center on = the dark fill is drawn.
	theme.set_type_variation("RewardOverlay", "Panel")
	theme.set_stylebox("panel", "RewardOverlay", _frame_box(modal_texture, MODAL_MARGIN, true))

	var error: int = ResourceSaver.save(theme, OUTPUT)
	if error != OK:
		push_error("build_sealsworn_theme: save failed (%d)" % error)
	else:
		print("build_sealsworn_theme: saved %s" % OUTPUT)
	quit()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			return resource
	push_warning("build_sealsworn_theme: texture unresolved (null-texture StyleBox) %s" % path)
	return null


func _frame_box(texture: Texture2D, margin: float, draw_center: bool) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.draw_center = draw_center
	return box


# A subtle themed emphasis for the ACTIVE (player) turn indicator. It is ADDITIVE over the word label
# ("Your Turn"/"Enemy Turn" stays the non-color NFR9 channel); this box is not the sole signal.
func _turn_emphasis_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.34, 0.5, 0.55)
	box.set_corner_radius_all(4)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box
