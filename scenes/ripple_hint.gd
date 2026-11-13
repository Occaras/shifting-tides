class_name RippleHint
extends Node2D
## The ripple hint: a wavelet strip on every cell that is dry now and wet after the next tick, on
## each of its edges that faces water, the marks walking along the edge. A dumb view: setup gives
## it the level and the cell-centre function, show_tide the tick (spec #44). Keep it at its
## parent's origin, after Board and before the entities.

enum Side { TOP, BOTTOM, LEFT, RIGHT }

## Indexed by Side: the neighbour across that edge.
const SIDE_DELTAS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## Four 28x4 frames side by side, for the top and bottom edges.
const WAVELET_H: Texture2D = preload("res://assets/generated/sky/wavelet_h.png")
## Four 4x28 frames stacked, for the left and right edges.
const WAVELET_V: Texture2D = preload("res://assets/generated/sky/wavelet_v.png")
const FRAMES := 4
## From a cell's centre to its top-left corner.
const HALF_CELL := Vector2(16, 16)
## Indexed by Side: where the strip's top-left sits, from the cell's top-left.
const INSETS: Array[Vector2] = [Vector2(2, 2), Vector2(2, 27), Vector2(2, 2), Vector2(27, 2)]


## One wavelet frame stamped on one edge of one cell.
class Strip extends RefCounted:
	var texture: Texture2D
	## The current frame's region of texture.
	var source: Rect2
	## The strip's top-left in this node's space.
	var position: Vector2


## The Level whose clock this hints. Unset, the view sits idle and only its seams drive it.
@export var level: Level

## The frame every strip shows, 0 to FRAMES - 1; FrameTimer walks it.
var frame := 0

var _level_data: LevelData
var _cell_center: Callable
var _tick := 0
var _cells: Array[Vector2i] = []


## Follows level: setup with Level.cell_position on every level it starts (this node sits at
## Level's origin), show_tide on every tide change.
func _ready() -> void:
	if level == null:
		return
	level.level_started.connect(setup.bind(level.cell_position))
	level.tide_changed.connect(show_tide)


## Shows `level_data` at tick 0. `cell_center` maps a cell to its centre in this node's space
## (Level.cell_position); it is the only way this node learns pixel positions.
func setup(level_data: LevelData, cell_center: Callable) -> void:
	_level_data = level_data
	_cell_center = cell_center
	show_tide(Rules.tide(0), 0)


## Matches TideClock.tide_changed. Recomputes the hinted cells from `tick`, so an undo or a scrub
## backwards hints what that tick says.
func show_tide(_tide: int, tick: int) -> void:
	_tick = tick
	_cells = cells_flooding_next(_level_data, tick) if _level_data != null else ([] as Array[Vector2i])
	queue_redraw()


## What _draw stamps: the current frame on each wet edge of each hinted cell.
func strips() -> Array[Strip]:
	var result: Array[Strip] = []
	for cell in _cells:
		var top_left: Vector2 = _cell_center.call(cell) - HALF_CELL
		for side in wet_edges(_level_data, cell, Rules.tide(_tick)):
			var strip := Strip.new()
			# The direction the frames are laid out in the strip texture.
			var along := Vector2.RIGHT if side == Side.TOP or side == Side.BOTTOM else Vector2.DOWN
			strip.texture = WAVELET_H if along == Vector2.RIGHT else WAVELET_V
			var frame_size := strip.texture.get_size() / (Vector2.ONE + along * (FRAMES - 1))
			strip.source = Rect2(frame_size * along * frame, frame_size)
			strip.position = top_left + INSETS[side]
			result.append(strip)
	return result


func _draw() -> void:
	for strip in strips():
		draw_texture_rect_region(strip.texture, Rect2(strip.position, strip.source.size), strip.source)


func _on_frame_timer_timeout() -> void:
	frame = (frame + 1) % FRAMES
	queue_redraw()


## Every on-board cell dry at `tick` and wet at `tick + 1`, in row-major order.
static func cells_flooding_next(level_data: LevelData, tick: int) -> Array[Vector2i]:
	var now := Rules.tide(tick)
	var next := Rules.tide(tick + 1)
	var cells: Array[Vector2i] = []
	for y in level_data.size.y:
		for x in level_data.size.x:
			var height := level_data.height_at(Vector2i(x, y))
			if height > now and height <= next:
				cells.append(Vector2i(x, y))
	return cells


## The sides of `cell` whose neighbour is wet at `tide`, in Side order. Off the board is sea
## (LevelData.height_at reads it as 0), so a board edge always faces water.
static func wet_edges(level_data: LevelData, cell: Vector2i, tide: int) -> Array[Side]:
	var sides: Array[Side] = []
	for side: Side in Side.values():
		if Rules.is_wet(level_data, cell + SIDE_DELTAS[side], tide):
			sides.append(side)
	return sides
