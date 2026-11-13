class_name Wave
extends Node2D
## The giant wave that ends a day: Sweep (the open sea trailing the foam Front) crosses the play
## area left to right, holds on the drowned board, then Blackout cuts to black (spec #44). The
## beats fill exactly Level's wave hold. A dumb view: play and reset are its seams; it restarts
## nothing and emits nothing. Keep it Level's last child so it covers the board and the entities.

## Seconds the sweep takes to cross the play area.
const SWEEP := 0.8
## Seconds the drowned board holds after the sweep.
const HOLD := 0.4
## Seconds of black before Level's hold ends and it restarts.
const BLACK := 0.2
## Sweep's x before and after the crossing: the front just off the left edge, then the front
## just off the right edge with the flood behind it covering the whole play area.
const SWEEP_START_X := -48.0
const SWEEP_END_X := 688.0

## The Level whose wave this plays. Unset, the view sits idle and only play and reset drive it.
@export var level: Level

## The running (or last) sweep; public so tests can custom_step it.
var tween: Tween

@onready var sweep: Node2D = %Sweep
@onready var front: AnimatedSprite2D = %Front
@onready var blackout: ColorRect = %Blackout
@onready var flood: ColorRect = %Flood


## Covers Board.PLAY_AREA: the black fills it and the flood spans its height. Then plays on
## level's WAVE outcome and resets on its next state, which Level's hold sends when it restarts,
## so the black lifts exactly as the level is back at tick 0.
func _ready() -> void:
	position = Vector2(Board.PLAY_AREA.position)
	blackout.size = Vector2(Board.PLAY_AREA.size)
	flood.size.y = Board.PLAY_AREA.size.y
	if level == null:
		return
	level.action_resolved.connect(_on_action_resolved)
	level.state_changed.connect(reset.unbind(1))


## Starts the sweep from the left edge, killing any sweep already running.
func play() -> void:
	reset()
	var tint := DayStage.SEA_TINT[DayStage.COUNT - 1]  # the wave tick is always the last stage
	sweep.modulate = Color(tint, tint, tint)
	sweep.position.x = SWEEP_START_X
	sweep.show()
	front.play()
	tween = create_tween()
	tween.tween_property(sweep, "position:x", SWEEP_END_X, SWEEP)
	tween.tween_interval(HOLD)
	tween.tween_callback(blackout.show)
	tween.tween_interval(BLACK)


## Stops any sweep and hides the wave and the black.
func reset() -> void:
	if tween:
		tween.kill()
	sweep.hide()
	front.stop()
	blackout.hide()


func _on_action_resolved(result: Rules.Result) -> void:
	if result.outcome == Rules.Outcome.WAVE:
		play()
