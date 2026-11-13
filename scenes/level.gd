class_name Level
extends Node2D
## The composition root of one playable level: the only script that touches input, the history,
## undo or restart. Calls Rules, keeps the history of states, advances the TideClock and tells the
## views where to be; the views hold no rules. Signals go up: level_started, tide_changed and
## state_changed are all a view binds to, never Level's children; action_resolved tells whoever
## owns the Level how each action ended, a win included.

## On every setup, a new level or a restart, once the board and the entities are placed and
## before the clock's tick 0 and state_changed: views set themselves up for `level_data` here.
signal level_started(level_data: LevelData)
## After setup, every push, every undo and every restart, with the new current state.
signal state_changed(state: Rules.State)
## After every perform that reached Rules.step, including IGNORED. A WON outcome is the win:
## whoever owns the Level decides what it leads to.
signal action_resolved(result: Rules.Result)
## TideClock's tide_changed, relayed after Board and the shells have followed it: on setup, every
## tick, undo and the debug scrub. Views follow the clock through this, never TideClock itself.
signal tide_changed(tide: int, tick: int)

## The Input Map actions perform maps to a Rules.Action.
const ACTION_INPUTS: Dictionary[StringName, Rules.Action] = {
	&"step_up": Rules.Action.UP, &"step_down": Rules.Action.DOWN,
	&"step_left": Rules.Action.LEFT, &"step_right": Rules.Action.RIGHT,
	&"wait": Rules.Action.WAIT,
}
const UNDO_INPUT := &"undo"
const RESTART_INPUT := &"restart"

## Seconds between a drown and the restart it leads to; the sink plays inside it.
const DROWN_HOLD_SECONDS := 0.7
## Seconds between the wave landing and the restart it leads to. The Clock & presentation wave
## sweep plays inside it; its own beats (Wave.SWEEP + Wave.HOLD + Wave.BLACK) sum to this, which
## tests/test_clock_integration.gd checks.
const WAVE_HOLD_SECONDS := 1.4

const SHELL_SCENE: PackedScene = preload("res://scenes/shell.tscn")
const BOAT_SCENE: PackedScene = preload("res://scenes/boat.tscn")

## The level being played, null until one is set up. Public: later groups bind to it.
var level: LevelData
## Every state since the level started; the top is the current state. There is no other copy.
var history: Array[Rules.State] = []
## True from a failure or a win until the next setup: perform and undo do nothing. The restart
## key is blocked only while is_holding().
var input_locked := false
## The running (or last) failure hold, which ends in restart(); public so tests can custom_step it.
var hold: Tween

@onready var tide_clock: TideClock = %TideClock
@onready var board: Board = %Board
@onready var goal: Node2D = %Goal
@onready var shells: Node2D = %Shells
@onready var boats: Node2D = %Boats
@onready var player: Player = %Player


## One press, one action: a held key steps once, since is_action_pressed skips echoes. UI added
## later sees each event first; whatever reaches here is marked handled.
func _unhandled_input(event: InputEvent) -> void:
	for input in ACTION_INPUTS:
		if event.is_action_pressed(input):
			perform(ACTION_INPUTS[input])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(UNDO_INPUT):
		undo()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(RESTART_INPUT):
		if not is_holding():
			restart()
		get_viewport().set_input_as_handled()


## Parses the level file at `path` and sets it up. An invalid file pushes an error and changes
## nothing.
func load_level(path: String) -> void:
	var loaded := LevelLoader.load_playable(path)
	if loaded != null:
		setup(loaded)


## The one way a level starts, restarts or changes: fresh entities, a one-state history,
## level_started, and the clock at tick 0. Views snap.
func setup(new_level: LevelData) -> void:
	level = new_level
	if hold:
		hold.kill()
	input_locked = false
	board.setup(level)
	_respawn(shells, SHELL_SCENE, level.shells)
	_respawn(boats, BOAT_SCENE, level.boats)
	goal.position = cell_position(level.goal)
	player.reset_effects()
	player.place(level.start, cell_position(level.start), false)
	history.assign([Rules.initial_state(level)])
	level_started.emit(level)
	tide_clock.setup(level)
	state_changed.emit(history.back())


## Resolves one action against the current state; does nothing while input is locked. An
## ignored action bumps the crab and costs nothing; anything else is pushed and the views follow
## it: a drifted boat glides with the crab and a taken shell plays its take. A win locks input.
## A drown sinks the crab, locks input and holds, then restarts; the wave locks
## input and holds longer, then restarts.
func perform(action: Rules.Action) -> void:
	if input_locked:
		return
	var result := Rules.step(level, history.back(), action)
	if result.outcome == Rules.Outcome.IGNORED:
		player.bump(Rules.ACTION_DELTAS[action])
		action_resolved.emit(result)
		return
	history.push_back(result.state)
	_show(result.state)
	if result.took_shell:
		var shell := shells.get_child(level.shells.find(result.state.player)) as Shell
		shell.set_taken(true, true)
	match result.outcome:
		Rules.Outcome.WON:
			input_locked = true
		Rules.Outcome.DROWNED:
			player.sink()
			_hold_then_restart(DROWN_HOLD_SECONDS)
		Rules.Outcome.WAVE:
			_hold_then_restart(WAVE_HOLD_SECONDS)
	action_resolved.emit(result)


## Takes back the last action: pops the history and glides every view back to the new top. At
## tick 0, or while input is locked, it does nothing and emits nothing.
func undo() -> void:
	if input_locked or history.size() <= 1:
		return
	history.pop_back()
	var state: Rules.State = history.back()
	# Popping only ever un-takes, so every shell the state has not taken is shown.
	for i in level.shells.size():
		if not state.shells_taken.has(level.shells[i]):
			(shells.get_child(i) as Shell).set_taken(false, false)
	_show(state)


## True while a failure hold (drown or wave) runs; a finished or killed hold is invalid.
func is_holding() -> bool:
	return hold != null and hold.is_valid()


## Starts the level over: setup on the same level, so every connection to Level and TideClock
## survives.
func restart() -> void:
	setup(level)


## The centre of `cell` in Level space; every placement goes through here.
func cell_position(cell: Vector2i) -> Vector2:
	return board.cell_to_position(cell)


## Moves the clock to `state`'s tick and glides the crab and every boat that moved (a drift, or
## one undone) to their cells in `state`, then emits state_changed. A view that stays on its cell
## keeps its running glide, so a wait mid-drift leaves the crab and boat moving as one. A boat
## that drifts carries the crab: a crab still boarding it finishes at once, so the two glide from
## the same place.
func _show(state: Rules.State) -> void:
	tide_clock.tick = state.tick
	for i in state.boats.size():
		var boat := boats.get_child(i) as CellView
		if boat.cell != state.boats[i]:
			if state.boats[i] == state.player:
				player.position = boat.position
			boat.place(state.boats[i], cell_position(state.boats[i]), true)
	if player.cell != state.player:
		player.place(state.player, cell_position(state.player), true)
	state_changed.emit(state)


## Connected to tide_clock.tide_changed in level.tscn: on every tick, undo and scrub, alongside
## Board's tide, each shell on a wet cell ghosts; then tide_changed relays it.
func _on_tide_changed(tide: int, tick: int) -> void:
	for i in level.shells.size():
		(shells.get_child(i) as Shell).set_wet(Rules.is_wet(level, level.shells[i], tide))
	tide_changed.emit(tide, tick)


func _hold_then_restart(seconds: float) -> void:
	input_locked = true
	hold = create_tween()
	hold.tween_interval(seconds)
	hold.tween_callback(restart)


## Frees `container`'s views and spawns one per cell, view i on cells[i], snapped.
func _respawn(container: Node2D, scene: PackedScene, cells: Array[Vector2i]) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for cell in cells:
		var view := scene.instantiate() as CellView
		container.add_child(view)
		view.place(cell, cell_position(cell), false)
