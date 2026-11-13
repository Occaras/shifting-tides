class_name TitleScreen
extends CanvasLayer
## The start screen before the level select: the sky band and sun, a two-island board under the
## title with the crab on one island and the goal on the other, a blinking prompt and, under it,
## the line that names the key for the controls overlay. The sun stands at the top of the arc, over
## the title, where it reads against the orange sky. Confirm or Start sends the giant wave across
## the board, then the screen closes and emits left; Main owns what comes next. The board is
## title_level.txt, kept out of levels/ so neither the select nor the solver lists it.

signal left

const LEVEL_PATH := "res://progression/title_level.txt"
## Either leaves the title: Enter, Space or A, or Start (and Esc, menu's key).
const START_INPUTS: Array[StringName] = [&"ui_accept", &"menu"]
## The wave's whole sweep, hold and black, after which the title closes.
const LEAVE_SECONDS := Wave.SWEEP + Wave.HOLD + Wave.BLACK
## Seconds the prompt shows, then hides, in turn.
const BLINK_SECONDS := 0.5
## The prompt's and the controls line's word after their keycap.
const PLAY := "PLAY"
const CONTROLS := "CONTROLS"
## Printed to stdout (the browser console on web) the first time a title opens in a run, so a
## smoke outside the engine can tell the game booted; tools/web_smoke.sh waits for it.
const READY_LINE := "TITLE READY"

## Whether this run has printed READY_LINE: static, so every TitleScreen in the run shares it.
static var _announced_ready := false

## The running (or last) wave wait and the prompt's blink; public so tests can custom_step them.
var leave: Tween
var blink: Tween

@onready var sky: SkyView = %Sky
@onready var board: Board = %Board
@onready var player: Player = %Player
@onready var goal: Node2D = %Goal
@onready var prompt: HBoxContainer = %Prompt
@onready var controls_prompt: HBoxContainer = %ControlsPrompt
@onready var wave: Wave = %Wave


func _ready() -> void:
	prompt.add_child(Keycap.named(ControlsNaming.first_key(&"ui_accept"), PLAY))
	controls_prompt.add_child(Keycap.named(ControlsNaming.first_key(&"show_controls"), CONTROLS))
	sky.show_sun(0.5)
	var level := LevelLoader.load_playable(LEVEL_PATH)
	if level == null:
		return
	board.setup(level)
	player.place(level.start, board.cell_to_position(level.start), false)
	goal.position = board.cell_to_position(level.goal)


## Shows the title at rest with the prompt blinking, ready for a start press.
func open() -> void:
	close()
	show()
	prompt.show()
	blink = create_tween().set_loops()
	blink.tween_interval(BLINK_SECONDS)
	blink.tween_callback(prompt.hide)
	blink.tween_interval(BLINK_SECONDS)
	blink.tween_callback(prompt.show)
	if not _announced_ready:
		_announced_ready = true
		print(READY_LINE)


## Hides the title and stops its blink, its wave and any wait on the wave.
func close() -> void:
	if leave:
		leave.kill()
	if blink:
		blink.kill()
	wave.reset()
	hide()


## True from a start press until the wave is done.
func is_leaving() -> bool:
	return leave != null and leave.is_running()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_leaving():
		return
	for input in START_INPUTS:
		if event.is_action_pressed(input):
			_leave()
			get_viewport().set_input_as_handled()
			return


## Hides the prompt and plays the wave; once it has swept, held and gone black, closes and emits left.
func _leave() -> void:
	blink.kill()
	prompt.hide()
	wave.play()
	leave = create_tween()
	leave.tween_interval(LEAVE_SECONDS)
	leave.tween_callback(_finish_leaving)


func _finish_leaving() -> void:
	close()
	left.emit()
