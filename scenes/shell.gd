class_name Shell
extends CellView
## A shell to take. Glides like every CellView; the take effect plays on the sprite, then the
## shell hides. Level ghosts it while its cell is wet.

## Seconds the take effect lasts before the shell hides.
const TAKE_SECONDS := 0.2
## How large the shell swells as it fades on a take.
const TAKE_SCALE := 1.8
## The shell's sprite on a dry cell; shell.tscn starts on it (tests/test_entity_sprites.gd).
const DRY_TEXTURE: Texture2D = preload("res://assets/generated/entities/shell.png")
## The shell's sprite while its cell is wet: the same shell in drowned tones.
const WET_TEXTURE: Texture2D = preload("res://assets/generated/entities/shell_wet.png")

## The running (or last) take effect; public so tests can custom_step it.
var effect_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D


## Hides the shell when `taken`, swelling and fading first when `animate`; shows it otherwise.
func set_taken(taken: bool, animate: bool) -> void:
	if effect_tween:
		effect_tween.kill()
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	visible = not taken or animate
	if not taken or not animate:
		return
	# Taken with the effect: still shown while it swells and fades, hidden at the end.
	effect_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	effect_tween.tween_property(sprite, "scale", Vector2.ONE * TAKE_SCALE, TAKE_SECONDS)
	effect_tween.tween_property(sprite, "modulate:a", 0.0, TAKE_SECONDS)
	effect_tween.chain().tween_callback(hide)


## Draws the shell in its drowned tones when `wet`. Only the texture changes, so a taken shell
## stays hidden.
func set_wet(wet: bool) -> void:
	sprite.texture = WET_TEXTURE if wet else DRY_TEXTURE
