class_name Progress
extends RefCounted
## The player's progress: the best action count per level, kept in one ConfigFile in user://.
## Unlocked is derived from the bests, never stored.

const PATH := "user://progress.cfg"
const VERSION := 1
const META_SECTION := "meta"
const BEST_SECTION := "best"
const VERSION_KEY := "version"
## What best_for returns for a level with no best.
const UNBEATEN := -1

var _bests: Dictionary[String, int] = {}


## The progress saved at path, or an empty one when the file is missing, unreadable or of another
## version (with a warning for the latter two).
static func load_file(path: String = PATH) -> Progress:
	var progress := Progress.new()
	if not FileAccess.file_exists(path):
		return progress
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		push_warning("Progress: cannot read %s (%s), starting with no bests" % [path, error_string(error)])
		return progress
	var version: Variant = config.get_value(META_SECTION, VERSION_KEY, 0)
	# The type first: GDScript cannot compare a String or an Array with an int.
	if not (version is int and version == VERSION):
		push_warning("Progress: %s has version %s, not %d, starting with no bests" % [path, version, VERSION])
		return progress
	if config.has_section(BEST_SECTION):
		for id in config.get_section_keys(BEST_SECTION):
			var best: Variant = config.get_value(BEST_SECTION, id)
			if best is int:
				progress._bests[id] = best
	return progress


## Writes every best to path; returns whether it succeeded, with a warning when it did not.
func save(path: String = PATH) -> bool:
	var config := ConfigFile.new()
	config.set_value(META_SECTION, VERSION_KEY, VERSION)
	for id in _bests:
		config.set_value(BEST_SECTION, id, _bests[id])
	var error := config.save(path)
	if error != OK:
		push_warning("Progress: cannot write %s (%s)" % [path, error_string(error)])
		return false
	return true


## The fewest actions the level was beaten in, or UNBEATEN (-1) when it is unbeaten.
func best_for(id: String) -> int:
	return _bests.get(id, UNBEATEN)


## Stores actions as the level's best when it is unbeaten or actions is lower; returns whether it
## stored. Does not save.
func record(id: String, actions: int) -> bool:
	var best := best_for(id)
	if best != UNBEATEN and actions >= best:
		return false
	_bests[id] = actions
	return true


## Whether the level at index in levels can be played: the first always, any other once the level
## before it has a best.
func is_unlocked(index: int, levels: Array[LevelData]) -> bool:
	return index == 0 or best_for(levels[index - 1].id) != UNBEATEN


## The index in levels of the first level with no best, where the select opens; the last when every
## level is beaten.
func first_unbeaten(levels: Array[LevelData]) -> int:
	for i in levels.size():
		if best_for(levels[i].id) == UNBEATEN:
			return i
	return levels.size() - 1
