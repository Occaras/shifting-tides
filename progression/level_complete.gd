class_name LevelComplete
extends CanvasLayer
## The card shown between a win and the next level: the level name, the actions taken against
## par, and a verdict line. Main owns when it shows and for how long.

const PAR_VERDICT := "Par!"
const NEW_BEST_VERDICT := "New best!"

@onready var name_label: Label = %Name
@onready var count_label: Label = %Count
@onready var verdict_label: Label = %Verdict


## The verdict for a win in actions on a level of par: Par! at par (and below it, which the
## solver says cannot happen), New best! above par when the win stored a new best, else nothing.
static func verdict_for(actions: int, par: int, is_new_best: bool) -> String:
	if actions <= par:
		return PAR_VERDICT
	return NEW_BEST_VERDICT if is_new_best else ""


## Fills the card for a win on level in actions and shows it. A count below par warns naming the
## level, since the solver and the game then disagree.
func show_result(level: LevelData, actions: int, is_new_best: bool) -> void:
	if actions < level.par:
		push_warning("LevelComplete: %s won in %d actions, below its par of %d" % [level.name, actions, level.par])
	name_label.text = level.name
	count_label.text = "%d actions / par %d" % [actions, level.par]
	verdict_label.text = verdict_for(actions, level.par, is_new_best)
	show()
