class_name TideClock
extends Node
## The tide clock the views subscribe to. Lives under Level, so restarting a level frees it.
## Holds the tick and derives everything else from Rules; it owns no rule.

## Emitted on every assignment of tick, including setup, undo and the debug scrub, so
## subscribers always resync from the signal.
signal tide_changed(tide: int, tick: int)

var tick: int = 0:
	set(value):
		tick = value
		tide_changed.emit(tide(), tick)

## The tick the level's wave lands on.
var wave_tick: int = 0


## Resets to tick 0 for this level.
func setup(level: LevelData) -> void:
	wave_tick = level.wave_tick()
	tick = 0


func tide() -> int:
	return Rules.tide(tick)


func is_wave_tick() -> bool:
	return tick == wave_tick


## High tides strictly after the current tick, up to and including the wave tick.
func high_tides_left() -> int:
	var count := 0
	for later in range(tick + 1, wave_tick + 1):
		if Rules.is_high_tide(later):
			count += 1
	return count
