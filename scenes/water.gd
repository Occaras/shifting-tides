class_name Water
extends Sprite2D
## The sea over the whole play area: water.gdshader looks up each pixel's cell in the board's
## heights texture. Board.setup wires it; Board.on_tide_changed moves its tide and darkens it by
## day stage.

## Seconds the tide uniform takes to reach a new tide.
const TIDE_TWEEN_SECONDS := 0.2
## water.gdshader's uniform names (spec #33).
const HEIGHTS_PARAM := "heights"
const NOISE_PARAM := "noise"
const SIZE_PX_PARAM := "size_px"
const BOARD_ORIGIN_PX_PARAM := "board_origin_px"
const BOARD_CELLS_PARAM := "board_cells"
const TIDE_PARAM := "tide"
const SEA_COLOR_PARAM := "sea_color"
const SHALLOW_COLOR_PARAM := "shallow_color"
const GLINT_COLOR_PARAM := "glint_color"
## The colour uniforms the day stage darkens. Their base values live only in water_material.tres
## (palette N, m at alpha 179/255 per spec #56, b; spec #33).
const COLOUR_PARAMS: Array[String] = [SEA_COLOR_PARAM, SHALLOW_COLOR_PARAM, GLINT_COLOR_PARAM]

## The running (or last) tide tween; public so tests can custom_step it.
var tween: Tween
## The tick the board's level's wave lands, which the day stage counts towards; set by setup.
var _wave_tick: int = 1

@onready var shader_material: ShaderMaterial = material
## The untinted colours, read from this board's own copy of water_material.tres (local to scene)
## before any tint, so the day stage never darkens an already darkened sea.
@onready var _base_colours := colours(shader_material)


## `water`'s colour uniforms as they are now, by name.
static func colours(water: ShaderMaterial) -> Dictionary[String, Color]:
	var by_name: Dictionary[String, Color] = {}
	for param in COLOUR_PARAMS:
		by_name[param] = water.get_shader_parameter(param)
	return by_name


## Covers Board.PLAY_AREA and points the shader at `board`'s heights texture and placement;
## `wave_tick` is the level's, for the day stage. The texture's size is board.tscn's copy of
## PLAY_AREA.size, guarded by test_water.gd.
func setup(board: Board, wave_tick: int) -> void:
	_wave_tick = wave_tick
	position = Vector2(Board.PLAY_AREA.position)
	shader_material.set_shader_parameter(SIZE_PX_PARAM, Vector2(Board.PLAY_AREA.size))
	shader_material.set_shader_parameter(HEIGHTS_PARAM, board.heights)
	shader_material.set_shader_parameter(BOARD_ORIGIN_PX_PARAM, board.tiles.position - position)
	shader_material.set_shader_parameter(BOARD_CELLS_PARAM, Vector2(board.heights_image.get_size()))


## Tweens the tide uniform from wherever it is to `tide`, replacing any running tween, and sets
## the colours to `tick`'s day stage at once.
func on_tide_changed(tide: int, tick: int) -> void:
	var stage := DayStage.at(tick, _wave_tick)
	for param in COLOUR_PARAMS:
		shader_material.set_shader_parameter(param, DayStage.tinted(_base_colours[param], stage))
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(shader_material, "shader_parameter/%s" % TIDE_PARAM, float(tide), TIDE_TWEEN_SECONDS)
