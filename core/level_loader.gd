class_name LevelLoader
extends RefCounted
## Reads the plan's level text format into LevelData.
##
## Header lines are "key: value" (the HEADER_ keys); every other non-blank line is a grid row of
## whitespace-separated glyphs, listed with their heights in GLYPH_HEIGHTS.

const LEVELS_DIR := "res://levels"

const HEADER_NAME := "name"
const HEADER_HIGH_TIDES := "high_tides"
const HEADER_PAR := "par"
## Optional one-line guidance; may itself contain colons, since only the first one splits.
const HEADER_HINT := "hint"
const HEADER_KEYS: Array[String] = [HEADER_NAME, HEADER_HIGH_TIDES, HEADER_PAR, HEADER_HINT]

const GLYPH_SEA := "."
const GLYPH_START := "@"
const GLYPH_GOAL := "G"
const GLYPH_BOAT := "b"
const GLYPH_SHELL := "*"

## Rock glyphs "1" to "4" are their own height.
const GLYPH_HEIGHTS: Dictionary[String, int] = {
	GLYPH_SEA: 0, "1": 1, "2": 2, "3": 3, "4": 4,
	GLYPH_START: 4, GLYPH_GOAL: 4, GLYPH_BOAT: 2, GLYPH_SHELL: 1,
}


## Always returns a LevelData; a malformed text comes back with errors filled.
static func parse(text: String) -> LevelData:
	var level := LevelData.new()
	var header: Dictionary[String, String] = {}
	var rows: Array[PackedStringArray] = []
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		if ":" in line:
			var parts := line.split(":", true, 1)
			var key := parts[0].strip_edges()
			if key in HEADER_KEYS:
				header[key] = parts[1].strip_edges()
			else:
				level.errors.append("unknown header '%s'" % key)
		else:
			rows.append(line.replace("\t", " ").split(" ", false))

	level.name = header.get(HEADER_NAME, "")
	level.hint = header.get(HEADER_HINT, "")
	level.high_tides = _read_int(header, HEADER_HIGH_TIDES, level.errors)
	level.par = _read_int(header, HEADER_PAR, level.errors)
	if header.get(HEADER_HIGH_TIDES, "").is_valid_int() and level.high_tides < 1:
		level.errors.append("%s must be at least 1, got %d" % [HEADER_HIGH_TIDES, level.high_tides])

	if rows.is_empty():
		level.errors.append("no grid rows")
		return level

	level.size = Vector2i(rows[0].size(), rows.size())
	level.heights.resize(level.size.x * level.size.y)
	var starts := 0
	var goals := 0
	for y in rows.size():
		var row := rows[y]
		if row.size() != level.size.x:
			level.errors.append("row %d has %d cells, expected %d like row 1" % [y + 1, row.size(), level.size.x])
		for x in row.size():
			var glyph := row[x]
			var cell := Vector2i(x, y)
			var where := "at row %d, column %d" % [y + 1, x + 1]
			if not GLYPH_HEIGHTS.has(glyph):
				level.errors.append("unknown glyph '%s' %s" % [glyph, where])
				continue
			if x < level.size.x:
				level.heights[y * level.size.x + x] = GLYPH_HEIGHTS[glyph]
			match glyph:
				GLYPH_START:
					starts += 1
					if starts == 1:
						level.start = cell
					else:
						level.errors.append("extra start (%s) %s" % [GLYPH_START, where])
				GLYPH_GOAL:
					goals += 1
					if goals == 1:
						level.goal = cell
					else:
						level.errors.append("extra goal (%s) %s" % [GLYPH_GOAL, where])
				GLYPH_BOAT:
					level.boats.append(cell)
				GLYPH_SHELL:
					level.shells.append(cell)
	if starts == 0:
		level.errors.append("no start (%s)" % GLYPH_START)
	if goals == 0:
		level.errors.append("no goal (%s)" % GLYPH_GOAL)
	return level


## Reads and parses a level file, for example "res://levels/01_sandbar.txt", whose stem becomes
## the level's id.
static func load_file(path: String) -> LevelData:
	var level: LevelData
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		level = LevelData.new()
		level.errors.append("cannot open %s: %s" % [path, error_string(FileAccess.get_open_error())])
	else:
		level = parse(file.get_as_text())
	level.id = path.get_file().get_basename()
	return level


## The level file at path when it is playable; otherwise pushes one error naming the file and its
## problems and returns null.
static func load_playable(path: String) -> LevelData:
	var level := load_file(path)
	if not level.is_valid():
		push_error("cannot load %s: %s" % [path, "; ".join(level.errors)])
		return null
	return level


## Reads a required whole-number header value, appending an error and returning 0 when it is
## missing or not a number.
static func _read_int(header: Dictionary[String, String], key: String, errors: PackedStringArray) -> int:
	if not header.has(key):
		errors.append("missing %s" % key)
		return 0
	var value := header[key]
	if not value.is_valid_int():
		errors.append("%s is not a whole number: '%s'" % [key, value])
		return 0
	return value.to_int()


## Every level file under dir (res://levels unless a tool passes its own), sorted by file name,
## which is the level order.
static func level_paths(dir: String = LEVELS_DIR) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(dir):
		if file_name.get_extension() == "txt":
			paths.append(dir.path_join(file_name))
	paths.sort()
	return paths
