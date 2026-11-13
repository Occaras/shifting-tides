class_name Board
extends Node2D
## The board a parent drops in: Tiles painted from a LevelData and centred in the play area,
## with Water over it. A view of the level; LevelData stays the source of truth.
## Keep Board at its parent's origin and before every entity in tree order (draw order).

## The 640x360 frame minus the 56 px sky band and its 1 px ink line.
const PLAY_AREA := Rect2i(0, 57, 640, 303)
## Board paints height h with atlas tile (h - 1, cliff_variant) of this source; see
## tools/gen_board_tiles.gd and tools/art/board.px.js.
const TILE_SOURCE_ID := 0
## The TileSet's int custom data layer holding each tile's height.
const HEIGHT_LAYER := "height"
## Heights texture red per height step, so the shader's round(r * 5.0) is exact at every height.
const HEIGHT_TEXEL_STEP := 51

## A cell's shaded edges, its atlas row. Bit 0: the neighbour below is lower; bit 1: the neighbour
## to the right is lower. Light comes from the top left, so top and left edges never shade.
enum Cliff { NONE = 0, BOTTOM = 1, RIGHT = 2, BOTH = 3 }

## One texel per cell, FORMAT_R8, red = height * HEIGHT_TEXEL_STEP. Rebuilt by setup.
var heights_image: Image
## heights_image as a texture, for the water shader.
var heights: ImageTexture

@onready var tiles: TileMapLayer = %Tiles
@onready var water: Water = %Water


## Repaints the board for `level`; nothing is kept from an earlier call.
func setup(level: LevelData) -> void:
	var size_px := level.size * tiles.tile_set.tile_size
	if size_px.x > PLAY_AREA.size.x or size_px.y > PLAY_AREA.size.y:
		push_warning("%s is %s px, larger than the play area %s" % [level.name, size_px, PLAY_AREA.size])
	@warning_ignore("integer_division")  # whole-pixel placement; an odd remainder goes right/down
	tiles.position = Vector2(PLAY_AREA.position + (PLAY_AREA.size - size_px) / 2)
	tiles.clear()
	heights_image = Image.create(level.size.x, level.size.y, false, Image.FORMAT_R8)
	for y in level.size.y:
		for x in level.size.x:
			var cell := Vector2i(x, y)
			var height := level.height_at(cell)
			heights_image.set_pixelv(cell, Color8(height * HEIGHT_TEXEL_STEP, 0, 0))
			if height > 0:
				tiles.set_cell(cell, TILE_SOURCE_ID, Vector2i(height - 1, cliff_variant(level, cell)))
	heights = ImageTexture.create_from_image(heights_image)
	water.setup(self, level.wave_tick())


## Which edges of `cell` are cliffs: a neighbour below or to the right strictly lower than the
## cell. Off-board neighbours count as height 0 (LevelData.height_at).
static func cliff_variant(level: LevelData, cell: Vector2i) -> int:
	var height := level.height_at(cell)
	var variant: int = Cliff.NONE
	if level.height_at(cell + Vector2i.DOWN) < height:
		variant |= Cliff.BOTTOM
	if level.height_at(cell + Vector2i.RIGHT) < height:
		variant |= Cliff.RIGHT
	return variant


## The seam a parent connects TideClock.tide_changed to; Board itself knows no clock.
func on_tide_changed(tide: int, tick: int) -> void:
	water.on_tide_changed(tide, tick)


## The painted tile's height, 0 where there is no tile (sea).
func height_at(cell: Vector2i) -> int:
	var data := tiles.get_cell_tile_data(cell)
	if data == null:
		return 0
	return data.get_custom_data(HEIGHT_LAYER)


## The centre of `cell` in the parent's space.
func cell_to_position(cell: Vector2i) -> Vector2:
	return position + tiles.position + tiles.map_to_local(cell)
