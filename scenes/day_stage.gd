class_name DayStage
extends RefCounted
## The day stage: one of five sky and sea darkness steps, from tick over wave tick (spec #44).
## Sky, Wave and the water shader's colour uniforms all read it, so the screen darkens together.

const COUNT := 5
## Multiplies the water colours' rgb per stage; a first guess, tuned at the playtest checkpoint.
const SEA_TINT: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6]


## mini(tick * COUNT / wave_tick, COUNT - 1) in integer maths: the prototype's
## floor(tick / wave_tick * 5) clamped to the last stage.
static func at(tick: int, wave_tick: int) -> int:
	@warning_ignore("integer_division")
	return mini(tick * COUNT / wave_tick, COUNT - 1)


## `colour` darkened to `stage`: rgb times the stage's tint, alpha untouched.
static func tinted(colour: Color, stage: int) -> Color:
	var tint := SEA_TINT[stage]
	return Color(colour.r * tint, colour.g * tint, colour.b * tint, colour.a)
