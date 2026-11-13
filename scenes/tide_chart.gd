class_name TideChart
extends Node2D
## The tide chart under the sun arc (ticket #72): one bar per tick from 0 to the wave tick, each
## straight under its tick's point on the arc. The bars stand on an ink ruler with a nub under each,
## lifted off the horizon so a strip of sky shows beneath and the row reads as a gauge, not a
## skyline. A past tick is a hollow glint outline, the current and future ticks are ink-edged sea
## with a foam top, the wave tick is a taller orange bar, and a gold caret over the current tick is
## the only "now" mark.
## A dumb view: Sky drives it through setup and show_tide. Keep it at Sky's origin, after Marks.
## Stamps PNG strips in _draw (as RippleHint does): a bar is the top `height` rows of its strip.
## Stamping beats one Sprite2D per bar because the bar count changes per level, so setup would
## free and rebuild nodes, while a tick or an undo is only a redraw.

enum Style { PAST, NOW, FUTURE, WAVE }

## A bar's height is 1 px at tide 0 plus this per tide step.
const PX_PER_TIDE := 3
## The wave tick's bar is the height of a tide one step above high.
const WAVE_HEIGHT := 1 + PX_PER_TIDE * (Rules.HIGH_TIDE + 1)
const BAR_WIDTH := 16
## The ruler's row: four rows above the band's ink line, so sky shows under the chart.
const RULER_Y := Board.PLAY_AREA.position.y - 5
const RULER: Texture2D = preload("res://assets/generated/sky/chart_ruler.png")
const NUB: Texture2D = preload("res://assets/generated/sky/chart_nub.png")
## The ruler starts this far left of the first bar's edge.
const RULER_OVERHANG := 2
const PAST_STRIP: Texture2D = preload("res://assets/generated/sky/chart_past.png")
const FUTURE_STRIP: Texture2D = preload("res://assets/generated/sky/chart_future.png")
const WAVE_STRIP: Texture2D = preload("res://assets/generated/sky/chart_wave.png")
const CARET: Texture2D = preload("res://assets/generated/sky/chart_now.png")
## From the caret's tip to the ink edge on top of the bar under it.
const CARET_GAP := 3


## One tick's bar.
class Bar extends RefCounted:
	## The bar's centre x, on the arc's x for its tick.
	var x: int
	## Rows the bar stands above the ruler, edge excluded.
	var height: int
	var style: Style


## How a style is stamped.
class Look extends RefCounted:
	var strip: Texture2D
	## The strip has a 1 px ink edge on its top and sides.
	var edged: bool

	func _init(look_strip: Texture2D, look_edged: bool) -> void:
		strip = look_strip
		edged = look_edged


static var LOOKS: Dictionary[Style, Look] = {
	Style.PAST: Look.new(PAST_STRIP, false),
	Style.NOW: Look.new(FUTURE_STRIP, true),
	Style.FUTURE: Look.new(FUTURE_STRIP, true),
	Style.WAVE: Look.new(WAVE_STRIP, true),
}

## The bars the chart shows; setup and show_tide set them.
var bars: Array[Bar] = []

var _wave_tick := 1
var _tick := 0


## Shows `level_data`'s ticks up to its wave tick, at tick 0.
func setup(level_data: LevelData) -> void:
	_wave_tick = level_data.wave_tick()
	show_tide(Rules.tide(0), 0)


## Matches TideClock.tide_changed. Restyles every bar from `tick`, so an undo or a scrub
## backwards shows what that tick says.
func show_tide(_tide: int, tick: int) -> void:
	_tick = tick
	bars = bars_at(tick, _wave_tick)
	queue_redraw()


func _draw() -> void:
	if bars.is_empty():  # not set up yet
		return
	@warning_ignore("integer_division")
	draw_texture(RULER, Vector2(SkyView.ARC_X_START - BAR_WIDTH / 2 - RULER_OVERHANG, RULER_Y))
	for bar in bars:
		draw_bar(self, bar, RULER_Y)
	draw_caret(self, bars[mini(_tick, bars.size() - 1)], RULER_Y)


## Stamps `bar` on `canvas` standing on a ruler at row `ruler_y`, with its nub under its centre.
## The ruler itself is the caller's. The tide guide stamps its bars with this too.
static func draw_bar(canvas: CanvasItem, bar: Bar, ruler_y: int) -> void:
	# The bar's bottom row sits on the ruler.
	var bottom := ruler_y - 1
	canvas.draw_texture(NUB, Vector2(bar.x, ruler_y + 1))
	var look := LOOKS[bar.style]
	var edge := 1 if look.edged else 0
	var top := bottom - bar.height + 1
	@warning_ignore("integer_division")
	var rect := Rect2(bar.x - BAR_WIDTH / 2 - edge, top - edge, BAR_WIDTH + 2 * edge, bar.height + edge)
	canvas.draw_texture_rect_region(look.strip, rect, Rect2(Vector2.ZERO, rect.size))


## Stamps the "now" caret over `bar` on `canvas`, its bar standing on a ruler at row `ruler_y`.
static func draw_caret(canvas: CanvasItem, bar: Bar, ruler_y: int) -> void:
	# The caret's bar is NOW or WAVE, both ink-edged: the gap is from that edge.
	var tip_y := ruler_y - 1 - bar.height - CARET_GAP
	var caret_size := Vector2i(CARET.get_size())
	@warning_ignore("integer_division")
	canvas.draw_texture(CARET, Vector2(bar.x - caret_size.x / 2, tip_y - caret_size.y + 1))


## The rows a bar stands at `tide`.
static func tide_bar_height(tide: int) -> int:
	return 1 + PX_PER_TIDE * tide


## Each tick's bar from 0 to `wave_tick`, styled for the current `tick`. The wave tick's bar
## is always the wave, whatever the current tick.
static func bars_at(tick: int, wave_tick: int) -> Array[Bar]:
	var result: Array[Bar] = []
	for i in wave_tick + 1:
		var bar := Bar.new()
		bar.x = SkyView.arc_point(float(i) / wave_tick).x
		bar.height = WAVE_HEIGHT if i == wave_tick else tide_bar_height(Rules.tide(i))
		if i == wave_tick:
			bar.style = Style.WAVE
		elif i < tick:
			bar.style = Style.PAST
		elif i == tick:
			bar.style = Style.NOW
		else:
			bar.style = Style.FUTURE
		result.append(bar)
	return result
