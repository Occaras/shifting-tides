class_name Rules
extends RefCounted
## Every rule of one action, shared by the game and the solver. Node-free and static.
## step() is the only place rules live; it reports what happened as data.

## The tide at each tick of one day; the tide clock repeats it forever.
const CYCLE: Array[int] = [0, 1, 2, 3, 2, 1]
const HIGH_TIDE: int = 3

## The solver expands actions in this order, which picks which shortest solution it finds.
enum Action { WAIT, UP, DOWN, LEFT, RIGHT }
enum Outcome { MOVED, IGNORED, DROWNED, WON, WAVE }

## Indexed by Action.
const ACTION_DELTAS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]


## What undo restores and the solver searches over. The tide is never stored, only the tick.
class State extends RefCounted:
	var tick: int = 0
	var player: Vector2i = Vector2i.ZERO
	## Boat i keeps index i for its whole life.
	var boats: Array[Vector2i] = []
	## Kept sorted so key() is canonical.
	var shells_taken: Array[Vector2i] = []

	func duplicate() -> State:
		var copy := State.new()
		copy.tick = tick
		copy.player = player
		copy.boats = boats.duplicate()
		copy.shells_taken = shells_taken.duplicate()
		return copy

	## Visited-set key. Includes the full tick, not tick mod 6, because the wave depends on it.
	func key() -> String:
		return "%d|%s|%s|%s" % [tick, player, boats, shells_taken]


## What one action did.
class Result extends RefCounted:
	var outcome: Outcome = Outcome.MOVED
	## The new state; the input state itself on IGNORED.
	var state: State
	## Index of the boat that drifted, or -1.
	var drifted_boat: int = -1
	var took_shell: bool = false

	func _init(result_outcome: Outcome, result_state: State) -> void:
		outcome = result_outcome
		state = result_state


static func tide(tick: int) -> int:
	return CYCLE[tick % CYCLE.size()]


static func is_high_tide(tick: int) -> bool:
	return tide(tick) == HIGH_TIDE


## The tick of the Nth high tide, when the wave lands. High tides fall on ticks 3, 9, 15, ...
static func wave_tick(high_tides: int) -> int:
	return CYCLE.find(HIGH_TIDE) + CYCLE.size() * (high_tides - 1)


## A cell is wet when its height is at or below the tide.
static func is_wet(level: LevelData, cell: Vector2i, at_tide: int) -> bool:
	return level.height_at(cell) <= at_tide


static func initial_state(level: LevelData) -> State:
	var state := State.new()
	state.player = level.start
	state.boats = level.boats.duplicate()
	return state


## One action, in the fixed order spec #26 writes down. Changing the order changes pars.
static func step(level: LevelData, state: State, action: Action) -> Result:
	# 1. Off the board: nothing happens, not even a tick.
	var target := state.player + ACTION_DELTAS[action]
	if not level.is_on_board(target):
		return Result.new(Outcome.IGNORED, state)

	var next := state.duplicate()
	var result := Result.new(Outcome.MOVED, next)

	# 2. Drift, judged at the tide before the tick.
	var now := tide(state.tick)
	var boat := state.boats.find(state.player)
	if (
		action != Action.WAIT
		and boat != -1
		and is_wet(level, state.player, now)
		and is_wet(level, target, now)
		and not state.boats.has(target)
	):
		next.boats[boat] = target
		result.drifted_boat = boat

	# 3. Move, 4. tick.
	next.player = target
	next.tick += 1

	# 5. Drown, judged at the tide after the tick. A boat is always a safe square.
	if not next.boats.has(target) and is_wet(level, target, tide(next.tick)):
		result.outcome = Outcome.DROWNED
		return result

	# 6. Take a shell, on foot or by boat (a scoop).
	if level.shells.has(target) and not next.shells_taken.has(target):
		next.shells_taken.append(target)
		next.shells_taken.sort()
		result.took_shell = true

	# 7. Win beats wave.
	if target == level.goal and next.shells_taken.size() == level.shells.size():
		result.outcome = Outcome.WON
	# 8. The wave.
	elif next.tick == level.wave_tick():
		result.outcome = Outcome.WAVE
	return result


static func action_from_name(action_text: String) -> Action:
	var index := Action.values().map(action_name).find(action_text)
	assert(index != -1, "unknown action name '%s'" % action_text)
	return index as Action


## The Action's enum key in lower case, for example "wait".
static func action_name(action: Action) -> String:
	var key: String = Action.keys()[action]
	return key.to_lower()
