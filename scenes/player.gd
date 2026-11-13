class_name Player
extends CellView
## The crab. Glides like every CellView; its effects (bump, sink) play on the sprite, so they
## never fight the glide on the node's position.

## Seconds a bump takes, out and back.
const BUMP_SECONDS := 0.1
## How far a bump leans toward the attempted direction.
const BUMP_PIXELS := 4.0
## Seconds the crab takes to sink on a drown.
const SINK_SECONDS := 0.4

## The running (or last) bump or sink; public so tests can custom_step it.
var effect_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


## Leans toward `direction` and back, for an action Rules ignored.
func bump(direction: Vector2i) -> void:
	_restart_effect()
	var out := Vector2(direction) * BUMP_PIXELS
	effect_tween.tween_property(sprite, "position", out, BUMP_SECONDS / 2.0)
	effect_tween.tween_property(sprite, "position", Vector2.ZERO, BUMP_SECONDS / 2.0)


## Shrinks and fades the crab into the water.
func sink() -> void:
	_restart_effect()
	effect_tween.set_parallel(true).set_ease(Tween.EASE_IN)
	effect_tween.tween_property(sprite, "scale", Vector2.ZERO, SINK_SECONDS)
	effect_tween.tween_property(sprite, "modulate:a", 0.0, SINK_SECONDS)


## Stops any effect and shows the crab as it stands.
func reset_effects() -> void:
	if effect_tween:
		effect_tween.kill()
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE


func _restart_effect() -> void:
	reset_effects()
	effect_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
