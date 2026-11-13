class_name LevelSlot
extends Button
## One level on the level select: its number in the theme's large size, then best / par under it
## once beaten, with the sun beside it at par.
## A locked slot is disabled and out of focus. Hovering a slot focuses it, so hover and focus are
## one highlight.

## Along the slot's foot once beaten: best / par in the select theme's small slot style, and right
## of it, when the best matches par, the sky's sun outlined in ink (par_sun.png).
@onready var best_row: HBoxContainer = %BestRow
@onready var best_label: Label = %Best
@onready var par_sun: TextureRect = %Sun


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)


## Shows the level numbered number (from 1) with its best (Progress.UNBEATEN when unbeaten) and par.
func setup(number: int, best: int, par: int, unlocked: bool) -> void:
	text = str(number)
	best_row.visible = best != Progress.UNBEATEN
	best_label.text = "%d / %d" % [best, par]
	par_sun.visible = best == par
	disabled = not unlocked
	focus_mode = FOCUS_ALL if unlocked else FOCUS_NONE


func _on_mouse_entered() -> void:
	if not disabled:
		grab_focus()
