class_name CellView
extends Node2D
## A thing on the board that stands on one cell. Level places it; it holds no rules and never
## asks where it is. place() kills any running glide and starts from wherever it is drawn, so
## a fast player never waits and nothing snaps.

## Seconds a step glide takes; shorter than Water.TIDE_TWEEN_SECONDS so the crab lands first.
const STEP_SECONDS := 0.15

var cell: Vector2i = Vector2i.ZERO
## The running (or last) glide; public so tests can custom_step it.
var tween: Tween


## Moves to `to_cell`, drawn at `to_position`: a glide when `animate`, otherwise a snap.
func place(to_cell: Vector2i, to_position: Vector2, animate: bool) -> void:
	cell = to_cell
	if tween:
		tween.kill()
	if not animate:
		position = to_position
		return
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", to_position, STEP_SECONDS)
