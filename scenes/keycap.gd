class_name Keycap
extends PanelContainer
## One key drawn as a cap (#115): hud_theme.tres's nine-slice of keycap.png, stretched to its key's
## name in the HUD font, or around an arrow icon for an arrow key. Every key the player is shown is
## one: a hint's tokens and the Controls legend in the HUD, every row of the Controls overlay, and the
## title's two lines. A view only, built from a key the caller read from ControlsNaming; it must sit
## under a Control that wears hud_theme.tres.

## hud_theme.tres's cap for a hint, the overlay and the title, and the legend's dimmer one.
const STYLE := &"Keycap"
const LEGEND_STYLE := &"KeycapLegend"
## hud_theme.tres's styles for the name on each cap: ink on the hint cap's light face, light on the
## legend cap's dark one, so each reads with no shadow (ADR 0002).
const NAME_STYLE := &"KeycapName"
const LEGEND_NAME_STYLE := &"KeycapLegendName"
## Every cap's height: a name or an arrow (8 px, one Monogram line) inside the theme's content
## margins. It fits HUD.HINT_BAR with a pixel to spare under the ledge and over the foot.
const HEIGHT := 12
## The gap between a cap and the word it names.
const WORD_GAP := 4
## Each arrow key's icon, drawn by tools/art/ui.px.js in place of a name, in the hint cap's ink.
const ARROWS: Dictionary[Key, Texture2D] = {
	KEY_LEFT: preload("res://assets/generated/hud/keycap_arrow_left.png"),
	KEY_UP: preload("res://assets/generated/hud/keycap_arrow_up.png"),
	KEY_DOWN: preload("res://assets/generated/hud/keycap_arrow_down.png"),
	KEY_RIGHT: preload("res://assets/generated/hud/keycap_arrow_right.png"),
}
## The same arrows in the legend cap's light name colour, for a dimmed cap.
const LEGEND_ARROWS: Dictionary[Key, Texture2D] = {
	KEY_LEFT: preload("res://assets/generated/hud/keycap_arrow_left_legend.png"),
	KEY_UP: preload("res://assets/generated/hud/keycap_arrow_up_legend.png"),
	KEY_DOWN: preload("res://assets/generated/hud/keycap_arrow_down_legend.png"),
	KEY_RIGHT: preload("res://assets/generated/hud/keycap_arrow_right_legend.png"),
}

## The key this cap shows.
var key: Key = KEY_NONE
## The key's name inside the cap, or null for an arrow key.
var label: Label
## The arrow inside the cap, or null for any other key.
var arrow: TextureRect


## A cap for key_to_show, in the legend's dimmer styles when dimmed. It takes no input.
static func create(key_to_show: Key, dimmed := false) -> Keycap:
	var cap := Keycap.new()
	cap.key = key_to_show
	cap.theme_type_variation = LEGEND_STYLE if dimmed else STYLE
	cap.mouse_filter = MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = SIZE_SHRINK_CENTER
	if ARROWS.has(key_to_show):
		cap.arrow = TextureRect.new()
		cap.arrow.texture = (LEGEND_ARROWS if dimmed else ARROWS)[key_to_show]
		cap.arrow.stretch_mode = TextureRect.STRETCH_KEEP
		cap.arrow.mouse_filter = MOUSE_FILTER_IGNORE
		cap.add_child(cap.arrow)
	else:
		cap.label = Label.new()
		cap.label.text = ControlsNaming.key_name(key_to_show)
		cap.label.theme_type_variation = LEGEND_NAME_STYLE if dimmed else NAME_STYLE
		cap.add_child(cap.label)
	return cap


## text beside keycaps: in the hint's words' style, or the legend's when dimmed, centred on a cap's
## height so its glyphs line up with the cap's name.
static func word(text: String, dimmed := false) -> Label:
	var shown := Label.new()
	shown.text = text
	shown.theme_type_variation = HUD.LEGEND_STYLE if dimmed else HUD.HINT_STYLE
	shown.size_flags_vertical = SIZE_SHRINK_CENTER
	return shown


## key's cap then text, WORD_GAP apart: the legend's UNDO, the title's PLAY. It takes no input.
static func named(key_to_show: Key, text: String, dimmed := false) -> HBoxContainer:
	var pair := HBoxContainer.new()
	pair.mouse_filter = MOUSE_FILTER_IGNORE
	pair.add_theme_constant_override("separation", WORD_GAP)
	pair.add_child(create(key_to_show, dimmed))
	pair.add_child(word(text, dimmed))
	return pair
