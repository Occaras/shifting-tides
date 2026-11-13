// The sea over the play area (spec #33). Maps each pixel to a board cell through the heights
// texture: opaque deep sea where height is 0 or outside the board, translucent shallow water
// over wet tidal rock, nothing over dry cells, and a broken 1 px foam line (spec #56) on the wet
// side of every dry-meets-wet edge. Uniform names and the wet rule are the contract
// Board, Water and the Clock & presentation group rely on.
//
// Zones by distance from the nearest dry cell, shore outward: foam that breathes 1-3 px, a pale
// lip and a mid shelf (stepped, dithered, wobbling), rings rolling in over the shelf, and past
// the shelf crest dashes and twinkles in open water. Every shade is a mix of sea_color and
// glint_color, so DayStage's tint darkens all of it. Every motion's period divides the 100 s
// TIME rollover (project.godot), so nothing jumps when TIME wraps.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D heights : filter_nearest, repeat_disable;  // R8, one texel per cell, red = height * 51
uniform sampler2D noise : filter_nearest, repeat_enable;     // seamless NoiseTexture2D, 32x32
uniform sampler2D noise_smooth : filter_linear, repeat_enable;  // the same texture, filtered, for soft wobble
uniform vec2 size_px = vec2(640.0, 303.0);                   // this sprite's size
uniform vec2 board_origin_px = vec2(0.0);                    // Tiles' top-left in this sprite's pixels
uniform vec2 board_cells = vec2(1.0);                        // columns, rows
uniform float tide = 0.0;                                    // tweened; an integer at rest
// The three colours DayStage tints have no defaults: water_material.tres is their one source.
uniform vec4 sea_color : source_color;      // N, opaque
uniform vec4 shallow_color : source_color;  // m over wet rock; alpha 0.7 so the tile's cracks read (spec #56)
uniform vec4 glint_color : source_color;    // b
uniform vec4 foam_color : source_color = vec4(1.0, 0.851, 0.690, 1.0);       // f  #ffd9b0
uniform float foam_break = 0.35;                                             // noise below this leaves a gap
const float TILE = 32.0;
// How far (in cells) shore_dist looks for a dry cell; the farthest zone edge is 40 px.
const int SHORE_REACH = 3;
// Zone edges, in pixels from the nearest dry cell.
const float LIP_PX = 7.0;
const float SHELF_PX = 24.0;
const float RINGS_FROM_PX = 40.0;
const float OPEN_SEA_PX = 30.0;
// Crest dash grid: one dash per cell, rows drifting opposite ways at DASH_DRIFT px/s.
const vec2 DASH_CELL = vec2(32.0, 12.0);
const float DASH_DRIFT = 8.0;  // 800 px per rollover, 25 cells
// The cells a row drifts per TIME rollover. Dashes are hashed from their cell's x wrapped to this,
// so after a rollover every dash is back where it started instead of popping to a new one.
const float DASH_WRAP_CELLS = 25.0;

// The height under a pixel of this sprite; 0 outside the board.
float height_at(vec2 px) {
	vec2 cell = (px - board_origin_px) / TILE;
	if (all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, board_cells))) {
		return round(texture(heights, cell / board_cells).r * 5.0);
	}
	return 0.0;
}

// At rest: 1.0 when h <= tide, 0.0 when h > tide.
float wet_for(float h) {
	return clamp(tide + 1.0 - h, 0.0, 1.0);
}

// The wet rule at a pixel of this sprite.
float wet_at(vec2 px) {
	return wet_for(height_at(px));
}

// Pixels from `px` to the nearest dry cell's edge within SHORE_REACH cells; 999 when none.
// A cell counts as dry by the wet rule at its centre (off the board is sea), so it flips at a
// tween's midpoint, as the foam's edge does.
float shore_dist(vec2 px) {
	vec2 local = px - board_origin_px;
	vec2 home = floor(local / TILE);
	float d = 999.0;
	for (int y = -SHORE_REACH; y <= SHORE_REACH; y++) {
		for (int x = -SHORE_REACH; x <= SHORE_REACH; x++) {
			vec2 centre = (home + vec2(float(x), float(y)) + 0.5) * TILE;
			if (wet_at(board_origin_px + centre) < 0.5) {
				vec2 outside = abs(local - centre) - vec2(TILE * 0.5);
				d = min(d, length(max(outside, vec2(0.0))));
			}
		}
	}
	return d;
}

// 4x4 ordered-dither threshold in (0, 1) for a pixel.
float bayer4(vec2 px) {
	ivec2 p = ivec2(mod(floor(px), 4.0));
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[p.x + p.y * 4] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Foam: wet here, dry on any of the four sides. The edge flips halfway through the tween
// while the alpha is still fading in, so the line arrives with the water.
float foam_line(vec2 px, float wet) {
	float dry_beside = max(max(1.0 - wet_at(px + vec2(1.0, 0.0)), 1.0 - wet_at(px - vec2(1.0, 0.0))),
	                       max(1.0 - wet_at(px + vec2(0.0, 1.0)), 1.0 - wet_at(px - vec2(0.0, 1.0))));
	// Strictly dry: at a tween midpoint wet and dry_beside are both 0.5 inside a cell.
	return step(0.5, wet) * float(dry_beside > 0.5) * step(foam_break, texture(noise, px / 32.0).r);
}

// A short crest (light dash over a dark trough row) that grows from its middle and shrinks back
// every 4 s. Returns (dash, trough) coverage.
vec2 crest(vec2 px) {
	float row = floor(px.y / DASH_CELL.y);
	vec2 p = px + vec2(TIME * DASH_DRIFT * (mod(row, 2.0) * 2.0 - 1.0) + row * 13.0, 0.0);
	vec2 cell = floor(p / DASH_CELL);
	vec2 local = p - cell * DASH_CELL;
	cell.x = mod(cell.x, DASH_WRAP_CELLS);
	float seed = hash(cell);
	float len = 5.0 + floor(seed * 8.0);
	float mid_x = floor(hash(cell + 17.0) * (DASH_CELL.x - len - 2.0)) + 1.0 + floor(len * 0.5);
	float y = floor(hash(cell + 41.0) * (DASH_CELL.y - 3.0)) + 1.0;
	float half_len = floor(len * 0.5 * max(0.0, sin(TIME * TAU / 4.0 + seed * TAU)));
	float dash = step(y, local.y) * step(local.y, y + 0.99) * step(abs(local.x - mid_x), half_len);
	float trough = step(y + 1.0, local.y) * step(local.y, y + 1.99) * step(abs(local.x - mid_x), max(half_len - 1.0, 0.0));
	return vec2(dash, trough);
}

// A 1 px foam-coloured star in about 1 of 250 3x3 blocks, lit a quarter of every 2 s.
float twinkle(vec2 px) {
	vec2 block = floor(px / 3.0);
	vec2 in_block = mod(px, 3.0);
	return step(hash(block + 7.0), 0.004) * step(fract(TIME / 2.0 + hash(block)), 0.25)
		* step(abs(in_block.x - 1.5), 0.5) * step(abs(in_block.y - 1.5), 0.5);
}

void fragment() {
	vec2 px = floor(UV * size_px) + 0.5;
	float h = height_at(px);
	float wet = wet_for(h);
	float shore = shore_dist(px);
	// Zone edges wobble by up to 7 px as slow noise drifts (periods 50 s and 100 s).
	float wobbly = shore + (texture(noise_smooth, px / 90.0 + vec2(TIME * 0.02, TIME * 0.01)).r - 0.5) * 14.0;
	vec3 mid = mix(sea_color.rgb, glint_color.rgb, 0.22);
	vec3 pale = mix(sea_color.rgb, glint_color.rgb, 0.45);
	vec3 bright = mix(sea_color.rgb, glint_color.rgb, 0.7);
	vec4 water;
	if (h < 0.5) {
		vec3 sea = sea_color.rgb;
		sea = mix(sea, mid, step(wobbly + bayer4(px) * 3.0, SHELF_PX));
		sea = mix(sea, pale, step(wobbly + bayer4(px) * 2.0, LIP_PX));
		water = vec4(sea, 1.0);
		// Rings 11 px apart rolling shoreward, one every 2 s, brightening as they land.
		float phase = fract(wobbly / 11.0 + TIME * 0.5);
		float ring = step(phase, 0.12) * step(0.18, texture(noise, px / 24.0).r)
			* step(6.0, wobbly) * step(wobbly, RINGS_FROM_PX - bayer4(px) * 12.0);
		water.rgb = mix(water.rgb, mix(bright, pale, clamp((wobbly - 6.0) / (RINGS_FROM_PX - 6.0), 0.0, 1.0)), ring);
		float open_sea = step(OPEN_SEA_PX, shore);
		vec2 dash_trough = crest(px) * open_sea;
		water.rgb = mix(water.rgb, sea_color.rgb * 0.8, dash_trough.y);
		water.rgb = mix(water.rgb, pale, dash_trough.x);
		water.rgb = mix(water.rgb, foam_color.rgb, twinkle(px) * open_sea);
	} else {
		// Drowned rock: the shallow tint with a pale dithered rim against dry neighbours.
		water = shallow_color;
		water.rgb = mix(water.rgb, pale, step(shore + bayer4(px) * 2.0, 4.0) * 0.7);
	}
	// Breathing foam: 1-3 px on the wet side, every 2 s, over the always-on 1 px line.
	float foam_width = 1.0 + 2.0 * (0.5 + 0.5 * sin(TIME * PI));
	float breath = step(shore, foam_width) * step(foam_break, texture(noise, px / 32.0 + vec2(0.0, TIME * 0.25)).r);
	water = mix(water, foam_color, max(breath * step(0.5, wet), foam_line(px, wet)));
	COLOR = vec4(water.rgb, water.a * wet);
}
