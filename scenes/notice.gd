class_name Notice
extends CanvasLayer
## A one-line message that confirms a press, such as MUSIC OFF: it shows in the HUD font under the
## shell count, over every screen, then fades on its own. A view only: show_text is its one seam.
## It draws light on its own ink plate (hud_theme.tres's Notice style), so it reads on whatever is
## behind it, the sky at any day stage included, with no shadow (ADR 0002).
## The spot is clear on each screen: the sky band's top-right corner in play and on the title,
## above the sun arc; the backdrop's corner on the select; and beside the card.

## Seconds a notice shows whole, then takes to fade: about a second in all.
const HOLD_SECONDS := 0.7
const FADE_SECONDS := 0.3

## The running (or last) hold and fade; public so tests can custom_step it.
var fade: Tween

@onready var label: Label = %Text


## Shows text now, in place of any notice still showing, and starts its hold and fade over.
func show_text(text: String) -> void:
	if fade:
		fade.kill()
	label.text = text
	label.modulate.a = 1.0
	label.show()
	fade = create_tween()
	fade.tween_interval(HOLD_SECONDS)
	fade.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(label.hide)

