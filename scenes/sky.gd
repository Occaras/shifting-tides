class_name SkyView
extends Node2D
## The 56 px sky band: the sun walks the dotted arc from tick 0 to the wave tick, a crest marks
## each high tide still to come (a bigger one for the wave tick), a notch each one passed, and the
## band steps darker by day stage (spec #44), and the tide chart under the arc shows every tick's
## tide (ticket #72). A dumb view: setup, show_tide and show_sun are its seams.
## The node is named Sky; the class is SkyView because Godot already has a Sky class.
## Keep Sun before Marks so the sun draws behind the crests, and Chart last. Nothing here
## tweens: the sun hops.

## The arc is the upper half of an ellipse with this centre and these radii.
const ARC_CENTER := Vector2(320, 35)
const ARC_RADII := Vector2(272, 26)
## Where the day's first and last ticks stand on the arc.
const ARC_X_START := 60.0
const ARC_X_END := 580.0

## One band per day stage, indexed by DayStage.at.
const BANDS: Array[Texture2D] = [
	preload("res://assets/generated/sky/band_0.png"),
	preload("res://assets/generated/sky/band_1.png"),
	preload("res://assets/generated/sky/band_2.png"),
	preload("res://assets/generated/sky/band_3.png"),
	preload("res://assets/generated/sky/band_4.png"),
]
const CREST: Texture2D = preload("res://assets/generated/sky/crest.png")
const CREST_BIG: Texture2D = preload("res://assets/generated/sky/crest_big.png")
const NOTCH: Texture2D = preload("res://assets/generated/sky/notch.png")

## The Level whose clock this shows. Unset, the view sits idle and only its seams drive it.
@export var level: Level

## The tick the shown level's wave lands; set by setup.
var wave_tick: int = 1
## The high tide tick each child of Marks stands for, in the same order.
var _mark_ticks: Array[int] = []

@onready var band: Sprite2D = %Band
@onready var sun: Sprite2D = %Sun
@onready var marks: Node2D = %Marks
@onready var chart: TideChart = %Chart


## Follows level: setup on every level it starts, show_tide on every tide change.
func _ready() -> void:
	if level == null:
		return
	level.level_started.connect(setup)
	level.tide_changed.connect(show_tide)


## The arc's pixel at `t` in 0..1 along the day: x in even steps from ARC_X_START to ARC_X_END, so
## the sun and each mark stand straight over their tick's tide chart bar, and y on the ellipse
## at that x.
static func arc_point(t: float) -> Vector2i:
	var x := roundi(lerpf(ARC_X_START, ARC_X_END, t))
	var across := (x - ARC_CENTER.x) / ARC_RADII.x
	return Vector2i(x, roundi(ARC_CENTER.y - ARC_RADII.y * sqrt(maxf(0.0, 1.0 - across * across))))


## Replaces the marks with one per high tide of `level_data` up to its wave tick, and the chart's
## bars with one per tick, and shows tick 0.
func setup(level_data: LevelData) -> void:
	chart.setup(level_data)
	wave_tick = level_data.wave_tick()
	for mark in marks.get_children():
		mark.free()
	_mark_ticks.clear()
	for tick in range(1, wave_tick + 1):
		if not Rules.is_high_tide(tick):
			continue
		var mark := Sprite2D.new()
		mark.centered = false
		mark.position = Vector2(arc_point(float(tick) / wave_tick))
		marks.add_child(mark)
		_mark_ticks.append(tick)
	show_tide(Rules.tide(0), 0)


## Shaped like TideClock.tide_changed: places the sun, swaps each mark between crest and notch,
## swaps the band by day stage, and restyles the chart.
func show_tide(tide: int, tick: int) -> void:
	chart.show_tide(tide, tick)
	show_sun(float(tick) / wave_tick)
	for i in _mark_ticks.size():
		var high_tide := _mark_ticks[i]
		var mark := marks.get_child(i) as Sprite2D
		if tick >= high_tide:
			mark.texture = NOTCH
			mark.offset = Vector2.ZERO  # top-left on the arc
		else:
			mark.texture = CREST_BIG if high_tide == wave_tick else CREST
			# bottom-centre on the arc, as pxl's "bottom" pivot stamps it
			var size := Vector2i(mark.texture.get_size())
			@warning_ignore("integer_division")
			mark.offset = Vector2(-(size.x / 2), -size.y)
	band.texture = BANDS[DayStage.at(tick, wave_tick)]


## Stands the sun at `day` in 0..1 along the arc, clamped, as arc_point places it.
func show_sun(day: float) -> void:
	sun.position = Vector2(arc_point(clampf(day, 0.0, 1.0)))
