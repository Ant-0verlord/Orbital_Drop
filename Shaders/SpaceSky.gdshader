shader_type sky;

// =============================================================
// SpaceSky.gdshader
//
// Wraps the whole Command Centre deck in space: a twinkling starfield,
// a soft nebula tint, and one large planet fixed in a chosen direction
// (Kerath-IV, the world the campaign is fought over — makes sense to
// see it hanging in the sky from an orbital platform). Fully procedural
// so it costs no texture import and looks correct from any angle as the
// player walks around the open deck, matching the same amber/dark
// palette and star-twinkle technique used on the main-menu backdrop.
// =============================================================

uniform vec3 sky_color_top : source_color = vec3(0.01, 0.015, 0.03);
uniform vec3 sky_color_horizon : source_color = vec3(0.03, 0.035, 0.05);

uniform vec3 nebula_color_a : source_color = vec3(0.30, 0.18, 0.11);
uniform vec3 nebula_color_b : source_color = vec3(0.14, 0.13, 0.28);
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.35;

uniform float star_density : hint_range(0.0, 1.0) = 0.35;   // higher = more stars
uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.55;
uniform float twinkle_speed : hint_range(0.1, 5.0) = 1.6;

// Computed from the actual .tscn transforms instead of a guess: Logistics
// Terminal sits at root-space (4.351, 0.496, 0.473), Player spawns at
// (-2.268, 2.567, 0.218). Player -> Logistics gives roughly (1.0, -0.31,
// 0.04) normalized — mostly +X (the direction you'd be facing/looking
// toward the terminal), noticeably downward, only a touch of +Z. Pushed
// the downward component a bit further (-0.55 instead of -0.31) so the
// planet reads as low and "under/behind" the Logistics console the way it
// was described, rather than sitting at the same eye-level height as the
// terminal itself. If it's still not lined up, this is the one value to
// nudge (see the note in CommandCentre.gd about using the Remote scene
// tree to tweak it live while the game runs, instead of round-tripping
// screenshots).
uniform vec3 planet_dir = vec3(1.0, -0.55, 0.04);   // direction the planet sits in (need not be unit length)
uniform float planet_angular_radius : hint_range(0.05, 0.95) = 0.85;
uniform vec3 planet_color : source_color = vec3(0.58, 0.42, 0.28);      // dusty highland
uniform vec3 planet_lowland_color : source_color = vec3(0.30, 0.22, 0.15); // darker basin/lowland
uniform vec3 planet_shadow_color : source_color = vec3(0.04, 0.035, 0.05);
uniform vec3 planet_rim_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 planet_cloud_color : source_color = vec3(0.92, 0.88, 0.8);
uniform float planet_cloud_speed : hint_range(0.0, 0.1) = 0.012;
uniform vec3 planet_light_dir = vec3(-0.6, 0.35, -0.4);  // where the "sun" lighting the planet comes from
uniform float city_light_amount : hint_range(0.0, 1.0) = 0.5; // scattered lights on the night side

// Sine-based hashes (fract(sin(dot(...)) * big_const)) are the textbook
// example everywhere online, but on real GPU sin() implementations they
// lose precision hard once the dot() input gets into the hundreds/thousands
// range that a *260.0 star grid or a *26.0 city-light grid produces — the
// result is banding that snaps to a visible grid instead of the smooth
// pseudo-random blur you get from a double-precision CPU preview of the
// exact same formula. That mismatch (smooth in a Python/numpy offline
// preview, blocky grid squares in-engine) is exactly what was happening
// here. These replacements ("hash without sine", Dave Hoskins-style) only
// use fract/dot/multiply, which stay accurate at these input magnitudes on
// every GPU.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise — used for the planet's continents/lowlands and
// drifting cloud layer, distinct from the starfield's per-cell hash
// (which is deliberately blocky/sparse, not smooth).
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise2(p);
		p *= 2.02;
		amp *= 0.55;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// --- Base gradient, slightly lighter toward the horizon so the deck
	// itself doesn't read as sitting in a pure black void.
	float horizon_t = clamp(1.0 - abs(dir.y), 0.0, 1.0);
	vec3 col = mix(sky_color_top, sky_color_horizon, horizon_t * horizon_t);

	// --- Soft nebula bands, low frequency so it reads as colour drift
	// rather than a pattern.
	float neb = sin(dir.x * 1.6 + dir.z * 1.1) * 0.5 + 0.5;
	float neb2 = sin(dir.y * 1.3 - dir.x * 0.7) * 0.5 + 0.5;
	vec3 nebula = mix(nebula_color_a, nebula_color_b, neb) * neb2;
	col += nebula * nebula_strength;

	// --- Starfield — stable per-cell hash so each star has a fixed
	// position and its own twinkle phase, sparse enough to read as
	// individual points rather than noise.
	vec3 cell = floor(dir * 260.0);
	float n = hash13(cell);
	float star_threshold = mix(0.9985, 0.997, star_density);
	if (n > star_threshold) {
		float tw = 0.5 + 0.5 * sin(TIME * (twinkle_speed * (0.5 + n)) + n * 6.2831853);
		float b = 0.55 + 0.45 * tw;
		col += vec3(b) * twinkle_amount + vec3(b) * (1.0 - twinkle_amount) * 0.6;
	}

	// --- The planet — a flat shaded disc at a fixed sky direction. Not a
	// real sphere (this is a sky shader, there's no depth), but the
	// tangent-plane shading below reads convincingly as one from a
	// stationary viewpoint on the deck. Margins scale with the radius so
	// the disc edge/glow stay proportionate now that it's much bigger.
	vec3 pd = normalize(planet_dir);
	float d = distance(dir, pd);
	float edge_margin = planet_angular_radius * 0.10;
	float glow_margin = planet_angular_radius * 0.08;
	if (d < planet_angular_radius + glow_margin) {
		vec3 offset = (dir - pd) / max(planet_angular_radius, 0.001);
		float nz = sqrt(max(0.0, 1.0 - dot(offset, offset)));
		vec3 ld = normalize(planet_light_dir);
		float ndotl = offset.x * ld.x + offset.y * ld.y + nz * 0.4;
		ndotl = clamp((ndotl + 0.2) / 1.2, 0.0, 1.0);

		// --- Terrain: three fbm passes at different scales — big
		// continent/lowland shapes, a mid pass to break up their edges,
		// and a fine high-frequency pass weighted more heavily toward
		// the limb (edge_weight, using the same nz falloff as the rim
		// light below) so the coastline/terminator near the disc's edge
		// reads as finely detailed rather than smooth/soft like the
		// centre of the disc.
		vec2 surf = offset.xy * 3.6;
		float continents = fbm(surf);
		float detail = fbm(surf * 3.3 + 11.0);
		float fine_edge = fbm(surf * 9.0 + 47.0);
		float edge_weight = clamp(1.0 - nz, 0.0, 1.0);
		float terrain = clamp(continents * 0.6 + detail * 0.25 + fine_edge * 0.15 * (0.4 + 0.6 * edge_weight), 0.0, 1.0);
		vec3 surface = mix(planet_lowland_color, planet_color, smoothstep(0.38, 0.62, terrain));

		// --- Drifting cloud layer, sampled with a slow time-based offset
		// so the planet visibly turns/breathes rather than sitting static.
		vec2 cloud_uv = offset.xy * 2.1 + vec2(TIME * planet_cloud_speed, TIME * planet_cloud_speed * 0.3);
		float clouds = fbm(cloud_uv);
		float cloud_mask = smoothstep(0.55, 0.78, clouds) * 0.7;
		surface = mix(surface, planet_cloud_color, cloud_mask);

		// --- Day/night shading over the textured surface.
		vec3 shaded = mix(planet_shadow_color, surface, ndotl);

		// --- Scattered city lights on the dark side — a small dot placed
		// at a pseudo-random point within each triggered grid cell, not
		// the whole cell lit (that read as blocky squares, not points).
		float night = 1.0 - smoothstep(0.05, 0.35, ndotl);
		vec2 city_uv = offset.xy * 26.0;
		vec2 city_cell = floor(city_uv);
		vec2 city_local = fract(city_uv);
		float city_n = hash12(city_cell + 7.0);
		float has_light = step(0.985, city_n);
		vec2 dot_pos = vec2(hash12(city_cell + 3.1), hash12(city_cell + 9.7));
		float dot_mask = smoothstep(0.22, 0.0, distance(city_local, dot_pos));
		float city_spark = has_light * dot_mask * night * city_light_amount;
		shaded += vec3(1.0, 0.85, 0.55) * city_spark;

		// Was gated by smoothstep(0.55, 1.0, ndotl), which covers roughly
		// the whole lit hemisphere's edge — that's what made the amber
		// rim read as a thick solid ring around half the planet instead
		// of a thin glint. Narrowed to only the near-peak of ndotl (a
		// "sunrise" crescent) and toned down.
		float rim = clamp(1.0 - nz, 0.0, 1.0);
		float rim_amount = smoothstep(0.85, 1.0, ndotl) * rim;
		shaded = mix(shaded, planet_rim_color, rim_amount * 0.3);

		float planet_mask = smoothstep(planet_angular_radius, planet_angular_radius - edge_margin, d);
		col = mix(col, shaded, planet_mask);

		// Faint atmosphere glow just outside the disc edge. This used to
		// stack with the inner rim bug above into one thick amber ring
		// (visible as a solid gold "portal frame" around the planet) —
		// narrowed and dimmed now that the inner rim is fixed.
		float glow = smoothstep(planet_angular_radius + glow_margin, planet_angular_radius, d) - planet_mask;
		col += planet_rim_color * clamp(glow, 0.0, 1.0) * 0.2;
	}

	COLOR = col;
}
