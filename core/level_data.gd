class_name LevelData
extends RefCounted
## One level as read from its text file: header values, cell heights and what stands where.
## Built by LevelLoader. When errors is non-empty the rest is best effort and must not be played.

## The level file's stem, for example "01_sandbar", which Progress keys bests by, so renaming the
## file forgets its best. Set by LevelLoader.load_file; "" for a level parsed from text alone.
var id: String = ""
var name: String = ""
## The level's optional one-line guidance, in sentence case; "" when the file has no hint line.
var hint: String = ""
var high_tides: int = 0
var par: int = 0
## Columns by rows.
var size: Vector2i = Vector2i.ZERO
var start: Vector2i = Vector2i.ZERO
var goal: Vector2i = Vector2i.ZERO
## In reading order (row by row, left to right); boat i keeps index i in Rules.State.
var boats: Array[Vector2i] = []
## In reading order.
var shells: Array[Vector2i] = []
## One message per problem with the file; empty for a playable level.
var errors: PackedStringArray = PackedStringArray()
## Row-major heights, size.x * size.y long. Written by LevelLoader.
var heights: PackedInt32Array = PackedInt32Array()


func is_valid() -> bool:
	return errors.is_empty()


## The tick this level's wave lands; see Rules.wave_tick.
func wave_tick() -> int:
	return Rules.wave_tick(high_tides)


func is_on_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Height 0 to 4. Cells off the board read as sea (0).
func height_at(cell: Vector2i) -> int:
	if not is_on_board(cell):
		return 0
	return heights[cell.y * size.x + cell.x]
