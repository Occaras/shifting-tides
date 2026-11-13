class_name LevelSelect
extends CanvasLayer
## The level select: one LevelSlot per level in a five-column grid over the sea-deep backdrop.
## Locked slots are disabled and unfocusable, so the grid's geometric focus skips them unwired.

signal level_chosen(index: int)

const SLOT_SCENE := preload("res://progression/level_slot.tscn")

@onready var _grid: GridContainer = %Grid


## Rebuilds the slots from levels and progress.
func setup(levels: Array[LevelData], progress: Progress) -> void:
	for slot in slots():
		_grid.remove_child(slot)
		slot.queue_free()
	for index in levels.size():
		var slot := SLOT_SCENE.instantiate() as LevelSlot
		_grid.add_child(slot)
		slot.setup(index + 1, progress.best_for(levels[index].id), levels[index].par, progress.is_unlocked(index, levels))
		slot.pressed.connect(level_chosen.emit.bind(index))


## The slots in level order.
func slots() -> Array[LevelSlot]:
	var result: Array[LevelSlot] = []
	for child in _grid.get_children():
		result.append(child as LevelSlot)
	return result


## Focuses the slot at index or, when it is locked, the highest unlocked slot.
func focus_level(index: int) -> void:
	var all := slots()
	for i in range(mini(index, all.size() - 1), -1, -1):
		if not all[i].disabled:
			all[i].grab_focus()
			return
