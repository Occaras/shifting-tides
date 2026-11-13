class_name HUD
extends CanvasLayer
## The band's corner text: the level name and the actions taken top-left, shells taken out of
## total top-right; and in the hint bar along the bottom, the level's hint with its tokens drawn as
## keycaps, or the Controls legend (each action's keycap and label) on a level without one. A view
## only: setup and show_state are its seams, and the theme owns the look.

## The hint bar's rect on the 640x360 frame, under the board. hud.tscn's %HintBar is a copy,
## guarded by tests/test_hud.gd; tests/test_content.gd keeps every board clear of it.
const HINT_BAR := Rect2i(0, 345, 640, 15)
## hud_theme.tres's styles for a hint's words and for the dimmer Controls legend's; Keycap has the
## caps' two.
const HINT_STYLE := &"HudCount"
const LEGEND_STYLE := &"HudLegend"
## hud_theme.tres's light styles for the lines on the sky, the name's and the counts', and the ink
## style each takes while its part of the band is light.
const NAME_STYLE := &"HudName"
const COUNT_STYLE := &"HudCount"
const INK_STYLE := &"HudInk"
## The first day stage at which each row of the sky's text turns light; before it the row is ink.
## Each band is two colours with a dithered seam over rows 12 to 17: the top row (the name and the
## shell count) sits on the upper colour and the second (the actions) below the seam on the lower,
## so on band 1 the top row is on purple and the second still on peach. tests/test_hud.gd checks
## each row's colour against the band art at every stage. (The notice brings its own ink plate.)
const TOP_ROW_LIGHT_FROM := 1
const SECOND_ROW_LIGHT_FROM := 2
## A token in a hint: a ControlsNaming label in lower case, in brackets, such as [wait].
const TOKEN_PATTERN := "\\[([a-z]+)\\]"
## The gap between one word run or token and the next in a hint.
const WORD_GAP := Keycap.WORD_GAP
## The gap between the keycaps of one token, such as [move]'s four arrows.
const KEY_GAP := 1
## The gap between one action and the next in the legend.
const LEGEND_GAP := 12

@onready var name_label: Label = %Name
@onready var actions_label: Label = %Actions
@onready var shells_label: Label = %Shells
@onready var hint_bar: TextureRect = %HintBar
## A child of hint_bar spanning it, which shows from the first setup on and centres what it holds:
## the level's hint, word runs as Labels and each token as a row of keycaps, or the Controls legend
## on a level without one.
@onready var hint_row: HBoxContainer = %Hint

## The Level whose state this shows. Unset, the view sits idle and only its seams drive it.
@export var level: Level

var _shell_total: int = 0
## The shown level's wave tick, which sets the day stage a tick falls in.
var _wave_tick: int = 1


## Follows level: setup on every level it starts, show_state on every state, and show_tide on
## every tide change, as the sky does, so the lines keep up with the debug scrub too.
func _ready() -> void:
	if level != null:
		level.level_started.connect(setup)
		level.state_changed.connect(show_state)
		level.tide_changed.connect(show_tide)


## Shows level_data's name and shell total, with no actions taken and no shells taken, and its
## hint in the hint bar; a level without a hint shows the Controls legend there.
func setup(level_data: LevelData) -> void:
	name_label.text = level_data.name.to_upper()
	for child in hint_row.get_children():
		hint_row.remove_child(child)
		child.queue_free()
	var parts := hint_parts(level_data)
	if parts.is_empty():
		_show_legend()
	else:
		_show_hint(parts)
	hint_bar.show()
	_shell_total = level_data.shells.size()
	_wave_tick = level_data.wave_tick()
	_show_counts(0, 0)
	show_tide(Rules.tide(0), 0)


## level_data's hint split at its tokens, in order: each run of words between tokens as a String in
## capitals (the HUD is set in capitals), with its edges trimmed, and each token, such as
## [wait], as the StringName inside its brackets. Empty for a level with no hint.
static func hint_parts(level_data: LevelData) -> Array:
	var parts := []
	var at := 0
	for token in RegEx.create_from_string(TOKEN_PATTERN).search_all(level_data.hint):
		_add_words(parts, level_data.hint.substr(at, token.get_start() - at))
		parts.append(StringName(token.get_string(1)))
		at = token.get_end()
	_add_words(parts, level_data.hint.substr(at))
	return parts


static func _add_words(parts: Array, text: String) -> void:
	if not text.strip_edges().is_empty():
		parts.append(text.strip_edges().to_upper())


## Each word run as a Label, each token as a row of its keys' caps.
func _show_hint(parts: Array) -> void:
	hint_row.add_theme_constant_override("separation", WORD_GAP)
	for part: Variant in parts:
		if part is StringName:
			var caps := _group(KEY_GAP)
			for key in ControlsNaming.token_keys(part):
				caps.add_child(Keycap.create(key))
			hint_row.add_child(caps)
		else:
			hint_row.add_child(Keycap.word(part))


## Each legend action as its first key's dim cap, then its label.
func _show_legend() -> void:
	hint_row.add_theme_constant_override("separation", LEGEND_GAP)
	for action in ControlsNaming.LEGEND_ACTIONS:
		hint_row.add_child(Keycap.named(ControlsNaming.first_key(action), ControlsNaming.LABELS[action], true))


## A row that takes no input, its children gap apart.
static func _group(gap: int) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", gap)
	return group


## Shows state's tick as the actions taken and its shells taken against the total from setup.
func show_state(state: Rules.State) -> void:
	_show_counts(state.tick, state.shells_taken.size())


## The style a line on the sky takes at day stage stage: light_style from its row's light_from on,
## ink before it.
static func sky_style(light_style: StringName, light_from: int, stage: int) -> StringName:
	return light_style if stage >= light_from else INK_STYLE


## Shaped like Level.tide_changed: colours each line on the sky for tick's day stage, the stage the
## sky band shows.
func show_tide(_tide: int, tick: int) -> void:
	var stage := DayStage.at(tick, _wave_tick)
	name_label.theme_type_variation = sky_style(NAME_STYLE, TOP_ROW_LIGHT_FROM, stage)
	shells_label.theme_type_variation = sky_style(COUNT_STYLE, TOP_ROW_LIGHT_FROM, stage)
	actions_label.theme_type_variation = sky_style(COUNT_STYLE, SECOND_ROW_LIGHT_FROM, stage)


func _show_counts(actions: int, shells_taken: int) -> void:
	actions_label.text = "ACTIONS %d" % actions
	shells_label.text = "SHELLS %d/%d" % [shells_taken, _shell_total]
