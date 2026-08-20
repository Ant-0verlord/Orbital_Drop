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

uniform vec3 planet_dir = vec3(0.15, -0.35, 0.92);   // direction the planet sits in (need not be unit length)
uniform float planet_angular_radius : hint_range(0.05, 0.9) = 0.30;
uniform vec3 planet_color : source_color = vec3(0.55, 0.4, 0.3);
uniform vec3 planet_shadow_color : source_color = vec3(0.04, 0.035, 0.05);
uniform vec3 planet_rim_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 planet_light_dir = vec3(-0.6, 0.35, -0.4);  // where the "sun" lighting the planet comes from

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453123);
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
	// stationary viewpoint on the deck.
	vec3 pd = normalize(planet_dir);
	float d = distance(dir, pd);
	if (d < planet_angular_radius + 0.04) {
		vec3 offset = (dir - pd) / max(planet_angular_radius, 0.001);
		float nz = sqrt(max(0.0, 1.0 - dot(offset, offset)));
		vec3 ld = normalize(planet_light_dir);
		float ndotl = offset.x * ld.x + offset.y * ld.y + nz * 0.4;
		ndotl = clamp((ndotl + 0.2) / 1.2, 0.0, 1.0);

		vec3 shaded = mix(planet_shadow_color, planet_color, ndotl);
		float rim = clamp(1.0 - nz, 0.0, 1.0);
		float rim_amount = smoothstep(0.55, 1.0, ndotl) * rim;
		shaded = mix(shaded, planet_rim_color, rim_amount * 0.6);

		float planet_mask = smoothstep(planet_angular_radius, planet_angular_radius - 0.03, d);
		col = mix(col, shaded, planet_mask);

		// faint atmosphere glow just outside the disc edge
		float glow = smoothstep(planet_angular_radius + 0.04, planet_angular_radius, d) - planet_mask;
		col += planet_rim_color * clamp(glow, 0.0, 1.0) * 0.35;
	}

	COLOR = col;
}
