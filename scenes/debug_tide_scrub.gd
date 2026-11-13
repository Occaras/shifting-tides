class_name DebugTideScrub
extends Node
## Debug builds only: the mouse wheel moves tide_clock one tick up or down, clamped to
## [0, wave tick], so a level can be watched flooding and draining without playing it.
## Place one wherever a TideClock lives and point the export at it. Deliberately not an Input Map
## action (Core spec #26): it is a developer tool, never a player binding.

@export var tide_clock: TideClock


func _ready() -> void:
	set_process_unhandled_input(OS.is_debug_build())


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	var step := 0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 1
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -1
	else:
		return
	tide_clock.tick = clampi(tide_clock.tick + step, 0, tide_clock.wave_tick)
	get_viewport().set_input_as_handled()
