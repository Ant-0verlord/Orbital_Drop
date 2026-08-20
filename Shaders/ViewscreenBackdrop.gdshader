shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// =============================================================
// ViewscreenBackdrop.gdshader
//
// Drives the big wall-mounted "bridge viewscreen" in the Command
// Centre — the room has no actual window, so this is a large emissive
// display showing UI/Viewscreen/viewscreen_bg.png, with the same
// per-pixel star twinkle used on the main-menu backdrop, plus a slow
// horizontal drift (a cheap sense of the ship holding position against
// a moving starfield) and an amber HUD-style bezel/frame drawn directly
// in the shader so no extra frame geometry is needed.
//
// unshaded + cull_disabled: stays clearly visible regardless of the
// room's lighting setup and is readable from both sides, in case the
// wall-mount placement (computed from the .tscn's collision data, not
// verified in-editor) ends up slightly rotated the "wrong" way.
// =============================================================

uniform sampler2D backdrop_tex : source_color;

uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.4;
uniform float twinkle_speed : hint_range(0.1, 5.0) = 1.6;
uniform float drift_speed : hint_range(0.0, 0.05) = 0.006; // slow starfield crawl

uniform vec3 frame_color : source_color = vec3(1.0, 0.85, 0.2);
uniform float frame_thickness : hint_range(0.0, 0.1) = 0.018;
uniform float frame_glow : hint_range(0.0, 1.0) = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	uv.x += TIME * drift_speed;
	uv.x = fract(uv.x);

	vec4 tex = texture(backdrop_tex, uv);
	vec3 col = tex.rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));

	// --- Star twinkle, same idea as the menu shader: only touches
	// already-bright pixels, each cell offset so they don't flicker
	// in lockstep.
	vec2 cell = floor(uv * vec2(300.0, 150.0));
	float n = hash(cell);
	float twinkle = 0.5 + 0.5 * sin(TIME * (twinkle_speed * (0.6 + n)) + n * 6.2831853);
	float star_mask = smoothstep(0.45, 0.9, lum);
	col += tex.rgb * star_mask * twinkle * twinkle_amount;

	// --- Amber bezel/frame around the edge, so this reads as a mounted
	// display rather than a floating image cut into the wall.
	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float edge = min(edge_x, edge_y);
	if (edge < frame_thickness) {
		float t = 1.0 - (edge / frame_thickness);
		col = mix(col, frame_color, clamp(t, 0.0, 1.0));
		col += frame_color * frame_glow * t * 0.4;
	}

	ALBEDO = col;
	EMISSION = col;
}
