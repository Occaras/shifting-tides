class_name TideGuide
extends VBoxContainer
## The tide guide, the Controls overlay's Tides page: how a cell's height meets the tide chart.
## One row per tick of a rising tide, from low water to high, each that tick's tide chart bar
## with the "now" caret beside the real Board and RippleHint showing RAMP_HEIGHTS at that tick, so
## the water, foam and ripples are the game's own and cannot drift from it. Over the rows, the
## ripple hint's key and the bar column's label; under them, the wave bar's key. All of it but the
## title sits in a two-column grid, so each icon, the label and the bars share one column. Built in
## _ready; the scene is only the column.

const BOARD_SCENE: PackedScene = preload("res://scenes/board.tscn")
const RIPPLE_HINT_SCENE: PackedScene = preload("res://scenes/ripple_hint.tscn")
## Every tidal rock height, low to high, then sand: tide t covers the first t cells.
const RAMP_HEIGHTS: Array[int] = [1, 2, 3, 4]
## The ramp's high tides: enough that every row's tick stays in day stage 0, so no row's sea is
## darker than another's.
const RAMP_HIGH_TIDES := 4
## The words. A first draft for Jeff to rewrite; every character must be in the HUD font.
const TITLE_TEXT := "HIGHER TIDE, MORE ROCK UNDER"
const RIPPLE_TEXT := "UNDER WATER AFTER YOUR NEXT MOVE"
const WAVE_TEXT := "THE WAVE"
const TIDE_TEXT := "TIDE"
## hud_theme.tres's styles: the key's words and the column label, and the line over the rows.
const KEY_STYLE := &"HudLegend"
const TITLE_STYLE := &"HudName"
## The gap between the icon column and the boards' column, and between the grid's lines.
const COLUMN_GAP := 6
const LINE_GAP := 4
## The rows between the title and the ripple hint's key line under it; at least LINE_GAP.
const KEY_SPACE := 6
## The bar's box: the ruler runs its full width, RULER_OVERHANG past the bar's ink edge each side.
const GAUGE_SIZE := Vector2i(TideChart.BAR_WIDTH + 2 * TideChart.RULER_OVERHANG, 32)
## The ruler's row in the bar's box: the nub under it is the box's second-to-last row.
const GAUGE_RULER_Y := GAUGE_SIZE.y - 3


## One tick's bar on a short length of the chart's ruler, with the caret over it.
class Gauge extends Control:
	var bar := TideChart.Bar.new()

	func _init(tide: int) -> void:
		custom_minimum_size = GAUGE_SIZE
		@warning_ignore("integer_division")
		bar.x = GAUGE_SIZE.x / 2
		bar.height = TideChart.tide_bar_height(tide)
		bar.style = TideChart.Style.NOW

	## The grid can give the box more width than GAUGE_SIZE: the bar stays centred in it.
	func _draw() -> void:
		@warning_ignore("integer_division")
		bar.x = int(size.x) / 2
		@warning_ignore("integer_division")
		var ruler_x := bar.x - GAUGE_SIZE.x / 2
		draw_texture_rect_region(TideChart.RULER, Rect2(ruler_x, GAUGE_RULER_Y, GAUGE_SIZE.x, 1), Rect2(0, 0, GAUGE_SIZE.x, 1))
		TideChart.draw_bar(self, bar, GAUGE_RULER_Y)
		TideChart.draw_caret(self, bar, GAUGE_RULER_Y)


## One tick: its bar, and its board framed in a viewport of the board's own size.
class Row extends RefCounted:
	var tick: int
	var gauge: Gauge
	var viewport: SubViewport
	var board: Board
	var ripple: RippleHint
	var board_level: LevelData


## The rows, low water first.
var rows: Array[Row] = []
## The key's icons: a ripple hint's strip, and the wave tick's bar.
var ripple_icon: TextureRect
var wave_icon: TextureRect


func _ready() -> void:
	var ramp := ramp_level()
	add_child(_words(TITLE_TEXT, TITLE_STYLE))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", COLUMN_GAP)
	grid.add_theme_constant_override("v_separation", LINE_GAP)
	add_child(grid)
	var ripple_frame := AtlasTexture.new()
	ripple_frame.atlas = RippleHint.WAVELET_H
	ripple_frame.region = Rect2(Vector2.ZERO, RippleHint.WAVELET_H.get_size() / Vector2(RippleHint.FRAMES, 1))
	# A spacer line sets the key apart from the title and brings it down to the rows it explains.
	for column in 2:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = KEY_SPACE - LINE_GAP
		grid.add_child(spacer)
	ripple_icon = _icon(ripple_frame)
	grid.add_child(ripple_icon)
	grid.add_child(_words(RIPPLE_TEXT, KEY_STYLE))
	var tide_label := _words(TIDE_TEXT, KEY_STYLE)
	tide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(tide_label)
	grid.add_child(Control.new())
	for tick in Rules.HIGH_TIDE + 1:
		var row := _row(ramp, tick)
		rows.append(row)
		grid.add_child(row.gauge)
		var frame := SubViewportContainer.new()
		frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		frame.add_child(row.viewport)
		grid.add_child(frame)
		# Board and RippleHint need the tree before they can be set up.
		_show(row)
	wave_icon = _icon(TideChart.WAVE_STRIP)
	grid.add_child(wave_icon)
	grid.add_child(_words(WAVE_TEXT, KEY_STYLE))


## The ramp as a level: one row of RAMP_HEIGHTS, nothing standing on it.
static func ramp_level() -> LevelData:
	var level := LevelData.new()
	level.name = "Tide guide"
	level.high_tides = RAMP_HIGH_TIDES
	level.size = Vector2i(RAMP_HEIGHTS.size(), 1)
	level.heights = PackedInt32Array(RAMP_HEIGHTS)
	return level


static func _row(ramp: LevelData, tick: int) -> Row:
	var row := Row.new()
	row.tick = tick
	row.board_level = ramp
	row.gauge = Gauge.new(Rules.tide(tick))
	row.viewport = SubViewport.new()
	row.viewport.transparent_bg = true
	row.viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	row.board = BOARD_SCENE.instantiate() as Board
	row.ripple = RIPPLE_HINT_SCENE.instantiate() as RippleHint
	row.viewport.add_child(row.board)
	row.viewport.add_child(row.ripple)
	return row


## Paints row's board at its tick and frames the viewport on the board's tiles alone.
static func _show(row: Row) -> void:
	row.board.setup(row.board_level)
	row.board.on_tide_changed(Rules.tide(row.tick), row.tick)
	row.ripple.setup(row.board_level, row.board.cell_to_position)
	row.ripple.show_tide(Rules.tide(row.tick), row.tick)
	row.viewport.size = row.board_level.size * row.board.tiles.tile_set.tile_size
	row.viewport.canvas_transform = Transform2D(0.0, -row.board.tiles.position)


static func _icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return icon


static func _words(text: String, style: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	return label
