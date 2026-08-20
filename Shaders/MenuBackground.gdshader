shader_type canvas_item;

// =============================================================
// MenuBackground.gdshader
//
// Animates the static UI/MainMenu/menu_bg.png without needing any
// extra art: a per-pixel star twinkle (masked to only the bright
// star pixels baked into the image), a pulsing glow on the drop-pod
// at the end of its descent trail, a pair of smaller pulsing glows
// on the two extra background drop-pod trails, and a slow energy
// wave sweeping through the amber hex-grid band along the planet's
// horizon.
// =============================================================

uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.45;
uniform float twinkle_speed : hint_range(0.1, 5.0) = 1.8;
uniform float star_band_bottom : hint_range(0.0, 1.0) = 0.66; // stop above the hex band

uniform vec2 pod_uv = vec2(0.58, 0.60);
uniform vec3 pod_color : source_color = vec3(1.0, 0.85, 0.3);
uniform float pod_pulse_speed : hint_range(0.2, 5.0) = 2.0;
uniform float pod_glow_radius : hint_range(0.02, 0.3) = 0.11;

// The two smaller, dimmer drop-pod trails added to the background art
// (top-left, near the planet, and lower-right) — same idea as the main
// pod's pulsing glow but smaller and phase-offset from each other and
// from the main pod, so all three don't beat in lockstep.
uniform vec2 extra_pod_uv_1 = vec2(0.19010, 0.27778);
uniform vec2 extra_pod_uv_2 = vec2(0.90104, 0.59259);
uniform vec3 extra_pod_color : source_color = vec3(1.0, 0.85, 0.3);
uniform float extra_pod_pulse_speed : hint_range(0.2, 5.0) = 2.0;
uniform float extra_pod_glow_radius : hint_range(0.02, 0.3) = 0.05;

uniform float hex_band_top : hint_range(0.0, 1.0) = 0.70;
uniform float hex_band_bottom : hint_range(0.0, 1.0) = 1.0;
uniform vec3 hex_wave_color : source_color = vec3(1.0, 0.85, 0.2);
uniform float hex_wave_speed : hint_range(0.01, 0.5) = 0.09;
uniform float hex_wave_width : hint_range(0.02, 0.4) = 0.16;

// Stable per-cell pseudo-random value, used so each "star" twinkles
// at its own fixed rate instead of the whole sky flickering in sync.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = base.rgb;

	// --- Star twinkle — only touches already-bright pixels (the
	// stars baked into the image), each cell offset so they don't
	// all pulse in lockstep.
	if (UV.y < star_band_bottom) {
		vec2 cell = floor(UV * vec2(480.0, 270.0));
		float n = hash(cell);
		float twinkle = 0.5 + 0.5 * sin(TIME * (twinkle_speed * (0.6 + n)) + n * 6.2831853);
		float star_mask = smoothstep(0.45, 0.9, lum);
		col += base.rgb * star_mask * twinkle * twinkle_amount;
	}

	// --- Drop-pod pulsing glow, centred on the pod at the end of
	// the descent trail.
	float pod_dist = distance(UV, pod_uv);
	float pulse = 0.5 + 0.5 * sin(TIME * pod_pulse_speed);
	float glow = smoothstep(pod_glow_radius, 0.0, pod_dist) * (0.35 + 0.65 * pulse);
	col += pod_color * glow * 0.9;

	// --- The two extra background drop-pods pulse too, each on its own
	// phase offset (and one at a slightly different speed) so they read
	// as independent landings rather than a synchronised trio.
	float ep1_dist = distance(UV, extra_pod_uv_1);
	float ep1_pulse = 0.5 + 0.5 * sin(TIME * extra_pod_pulse_speed + 2.1);
	float ep1_glow = smoothstep(extra_pod_glow_radius, 0.0, ep1_dist) * (0.3 + 0.6 * ep1_pulse);
	col += extra_pod_color * ep1_glow * 0.6;

	float ep2_dist = distance(UV, extra_pod_uv_2);
	float ep2_pulse = 0.5 + 0.5 * sin(TIME * extra_pod_pulse_speed * 0.8 + 4.7);
	float ep2_glow = smoothstep(extra_pod_glow_radius, 0.0, ep2_dist) * (0.3 + 0.6 * ep2_pulse);
	col += extra_pod_color * ep2_glow * 0.6;

	// --- Hex-grid energy wave — a soft band that sweeps down through
	// the horizon's hex lattice on a loop, brightening whatever hex
	// linework it crosses.
	if (UV.y >= hex_band_top) {
		float band_t = clamp((UV.y - hex_band_top) / max(0.0001, hex_band_bottom - hex_band_top), 0.0, 1.0);
		float wave_pos = fract(TIME * hex_wave_speed);
		float wave = smoothstep(hex_wave_width, 0.0, abs(band_t - wave_pos));
		float hex_mask = smoothstep(0.04, 0.22, lum);
		col += hex_wave_color * wave * hex_mask * 1.1;
	}

	COLOR = vec4(col, base.a);
}
