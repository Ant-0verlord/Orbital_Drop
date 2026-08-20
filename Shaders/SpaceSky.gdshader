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
//
// PLANET PASS — rewritten for a lot more surface detail and a
// Helldivers-2-style "living world" read: real oceans with shallow
// coastal water, warped/organic continent shapes (not blobby fbm
// islands), biome variation (forest/desert/rock/snow), a couple of
// small alien accent biomes (bioluminescent teal, violet crystal) so
// it doesn't read as plain Earth, polar ice caps, cloud shadowing,
// an ocean sun-glint, a visible day/night terminator with a warm
// sunset band, a faint polar aurora on the night side, scattered city
// lights clustered like real light pollution rather than uniform
// noise, and a two-tone atmosphere halo. Still a flat shaded disc, not
// a real sphere (this is a sky shader with no depth) — the tangent-
// plane shading below is what sells it as one from the deck's fixed
// viewpoint.
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

// --- Land biomes -------------------------------------------------
uniform vec3 planet_color : source_color = vec3(0.30, 0.44, 0.22);        // vegetated highland (earthlike green)
uniform vec3 planet_lowland_color : source_color = vec3(0.46, 0.38, 0.22); // dry lowland / desert basin
uniform vec3 planet_rock_color : source_color = vec3(0.40, 0.34, 0.31);    // exposed mountain rock
uniform vec3 planet_snow_color : source_color = vec3(0.93, 0.96, 1.0);     // high-altitude snow caps

// --- Alien accent biomes — small patches so the planet reads as
// earthlike overall but unmistakably not Earth up close.
uniform vec3 planet_alien_accent_a : source_color = vec3(0.30, 0.86, 0.62); // bioluminescent teal bloom
uniform vec3 planet_alien_accent_b : source_color = vec3(0.58, 0.24, 0.72); // violet crystal field
uniform float planet_alien_amount : hint_range(0.0, 1.0) = 0.32;

// --- Oceans & ice -------------------------------------------------
uniform vec3 planet_ocean_deep_color : source_color = vec3(0.02, 0.10, 0.20);
uniform vec3 planet_ocean_shallow_color : source_color = vec3(0.07, 0.33, 0.38);
uniform float planet_ocean_amount : hint_range(0.0, 1.0) = 0.52; // how much of the surface is ocean
uniform vec3 planet_ice_color : source_color = vec3(0.80, 0.92, 0.98);
uniform float planet_ice_cap_amount : hint_range(0.0, 1.0) = 0.34; // how far the polar caps reach

uniform vec3 planet_shadow_color : source_color = vec3(0.03, 0.03, 0.05);
uniform vec3 planet_rim_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 planet_atmosphere_color : source_color = vec3(0.35, 0.55, 0.9); // outer halo tint
uniform vec3 planet_terminator_glow_color : source_color = vec3(1.0, 0.5, 0.22); // sunset band at day/night line

uniform vec3 planet_cloud_color : source_color = vec3(0.94, 0.93, 0.9);
uniform float planet_cloud_speed : hint_range(0.0, 0.1) = 0.012;
uniform float planet_cloud_warp : hint_range(0.0, 2.0) = 1.0; // how swirly the clouds look

uniform vec3 planet_light_dir = vec3(-0.6, 0.35, -0.4);  // where the "sun" lighting the planet comes from

// --- Night side -----------------------------------------------------
uniform float city_light_amount : hint_range(0.0, 1.0) = 0.55; // scattered settlement lights on the dark side
uniform vec3 planet_city_light_warm : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 planet_city_light_cool : source_color = vec3(0.55, 0.75, 1.0); // rarer blue-white clusters
uniform float planet_aurora_amount : hint_range(0.0, 1.0) = 0.4; // faint polar aurora on the night side

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
	for (int i = 0; i < 6; i++) {
		v += amp * noise2(p);
		p *= 2.02;
		amp *= 0.55;
	}
	return v;
}

// Domain warp — bends the sample coordinates by a second noise field
// before the main continent fbm is taken. Plain fbm alone reads as
// round, evenly-spaced "blob" islands no matter how many octaves are
// stacked; warping the input first is what gives coastlines their
// organic, stretched-and-pinched look (fjords, peninsulas, archipelagos)
// instead of a field of potatoes.
vec2 domain_warp(vec2 p) {
	float wx = fbm(p + vec2(11.5, 27.3));
	float wy = fbm(p + vec2(48.1, 5.7));
	return vec2(wx, wy) - 0.5;
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
	float glow_margin = planet_angular_radius * 0.14;
	if (d < planet_angular_radius + glow_margin) {
		vec3 offset = (dir - pd) / max(planet_angular_radius, 0.001);
		float nz = sqrt(max(0.0, 1.0 - dot(offset, offset)));
		vec3 ld = normalize(planet_light_dir);

		// Raw (unclamped) light term drives the sharp terminator line;
		// the clamped/remapped version drives the broad day/night mix so
		// the lit hemisphere doesn't go fully flat white at the sub-solar
		// point.
		float raw_ndotl = offset.x * ld.x + offset.y * ld.y + nz * 0.4;
		float ndotl = clamp((raw_ndotl + 0.2) / 1.2, 0.0, 1.0);

		// ---------------------------------------------------------------
		// TERRAIN — warped multi-octave fbm for organic continent shapes,
		// plus a separate ridge pass for sharp mountain-range/crater-rim
		// lines instead of only smooth rolling hills.
		// ---------------------------------------------------------------
		vec2 surf = offset.xy * 7.0;

		// Continent SHAPE comes from its own much lower-frequency warped
		// field, sampled separately from the fine surface-texture noise
		// below. Deriving the ocean/land boundary from the same
		// high-frequency combined field as the texture detail (the first
		// pass at this) made every small ripple in the fine noise flip the
		// coastline back and forth — a "swiss cheese" speckle of tiny
		// ocean holes punched through the middle of continents instead of
		// clean coastlines.
		vec2 shape_surf = offset.xy * 2.6;
		vec2 shape_warped = shape_surf + domain_warp(shape_surf * 0.6) * 1.7;
		float continents = fbm(shape_warped);

		float detail = fbm(surf * 2.6 + 11.0);
		float ridge_n = noise2(surf * 4.1 + 91.0);
		float ridge = 1.0 - abs(ridge_n * 2.0 - 1.0);
		ridge = ridge * ridge;

		// ---------------------------------------------------------------
		// OCEAN vs LAND — a coastline threshold driven by planet_ocean_amount
		// instead of a fixed 0.5, so the ocean/land ratio is actually tunable,
		// with a lighter shallow-water ring right at the coast.
		// ---------------------------------------------------------------
		float ocean_level = mix(0.28, 0.66, planet_ocean_amount);
		float land_mask = smoothstep(ocean_level - 0.045, ocean_level + 0.045, continents);
		float shallow_band = 1.0 - smoothstep(0.0, 0.06, abs(continents - ocean_level));
		vec3 ocean_col = mix(planet_ocean_deep_color, planet_ocean_shallow_color, shallow_band);

		// --- Land biomes: large-scale region noise picks forest vs. dry
		// lowland. Elevation (continents+detail only, NOT the ridge/fine
		// noise) then pushes exposed rock and snow on top as broad
		// highland massifs — using the thin winding ridge-noise lines
		// directly for this (the first pass at it) thresholded into a
		// maze/circuit-board pattern instead of mountain ranges. Ridge
		// still contributes as a relief-shading accent further down.
		float biome_n = fbm(surf * 0.55 + 501.0);
		vec3 land_col = mix(planet_lowland_color, planet_color, smoothstep(0.35, 0.65, biome_n));
		float elevation = continents * 0.62 + detail * 0.38;
		float mountains = smoothstep(0.57, 0.68, elevation);
		land_col = mix(land_col, planet_rock_color, mountains);
		float snow = smoothstep(0.669, 0.75, elevation);
		land_col = mix(land_col, planet_snow_color, snow);

		// --- Alien accent biomes — rare patches of bioluminescent teal or
		// violet crystal scattered across dry land only, so the planet
		// still reads as earthlike at a glance but rewards a closer look.
		float alien_n = fbm(surf * 1.35 + 809.0);
		float alien_mask = smoothstep(0.80, 0.90, alien_n) * land_mask * (1.0 - snow);
		vec3 alien_col = mix(planet_alien_accent_a, planet_alien_accent_b, step(0.5, hash12(floor(surf * 0.4) + 3.0)));
		land_col = mix(land_col, alien_col, alien_mask * planet_alien_amount);

		vec3 surface = mix(ocean_col, land_col, land_mask);

		// --- Polar ice caps — latitude approximated from the local disc
		// offset, edge roughened with noise so it's not a perfect circle.
		float lat = abs(offset.y) + (fbm(surf * 2.2 + 201.0) - 0.5) * 0.22;
		float ice_threshold = 1.0 - planet_ice_cap_amount * 0.9;
		float ice_edge = smoothstep(ice_threshold, ice_threshold + 0.10, lat);
		surface = mix(surface, planet_ice_color, ice_edge);

		// ---------------------------------------------------------------
		// CLOUDS — domain-warped so they swirl like weather systems
		// instead of sitting as flat noise blobs, drifting slowly over
		// time, with a soft self-shadow cast onto the surface below.
		// ---------------------------------------------------------------
		vec2 cloud_uv = offset.xy * 3.2 + vec2(TIME * planet_cloud_speed, TIME * planet_cloud_speed * 0.3);
		vec2 cloud_warp_uv = cloud_uv + domain_warp(cloud_uv * 0.6) * planet_cloud_warp;
		float clouds = fbm(cloud_warp_uv);
		float cloud_mask = smoothstep(0.62, 0.80, clouds) * 0.60;

		vec2 shadow_uv = cloud_warp_uv - ld.xy * 0.06;
		float cloud_shadow = smoothstep(0.60, 0.74, fbm(shadow_uv)) * (1.0 - cloud_mask);
		surface = mix(surface, surface * 0.78, cloud_shadow * 0.5);

		// --- Ocean sun-glint — a scatter of tiny bright points where the
		// light angle is near-direct over open water, the kind of glare
		// you get off real ocean from orbit.
		float glint_n = hash12(floor(offset.xy * 190.0));
		float glint = step(0.992, glint_n) * smoothstep(0.72, 1.0, ndotl) * (1.0 - land_mask);
		surface += vec3(1.0, 0.98, 0.9) * glint * 0.7;

		// --- Day/night shading. The ridge pattern doubles as a cheap
		// fake-relief term (small light/dark push based on "elevation")
		// so lit terrain shows texture instead of one flat-lit tone.
		float relief = (ridge - 0.5) * 0.10;
		vec3 shaded = mix(planet_shadow_color, surface, clamp(ndotl + relief * ndotl, 0.0, 1.0));

		// Clouds sit on top of the shading so their tops stay bright even
		// right at the terminator, like real cloud tops catching grazing
		// light after the ground below has gone dark.
		float cloud_lit = clamp(ndotl * 0.6 + 0.4, 0.0, 1.0);
		shaded = mix(shaded, planet_cloud_color * cloud_lit, cloud_mask);

		// ---------------------------------------------------------------
		// NIGHT SIDE — scattered settlement lights, clustered rather than
		// uniformly sprinkled: a coarse "civilisation" mask decides which
		// regions are settled at all (favouring coastlines and lowlands,
		// same as real light pollution maps), then a fine per-cell hash
		// places individual glowing points inside those regions with
		// varied brightness and a rare cool-white cluster instead of
		// every light being the same warm amber dot.
		// ---------------------------------------------------------------
		float night = 1.0 - smoothstep(0.02, 0.30, ndotl);
		float civ_n = fbm(surf * 0.85 + 1200.0);
		float coastal = 1.0 - smoothstep(0.0, 0.10, abs(continents - ocean_level));
		float civ_mask = smoothstep(0.48, 0.60, civ_n) * land_mask * (1.0 - snow) * (1.0 - ice_edge);
		civ_mask = clamp(civ_mask + coastal * land_mask * 0.5, 0.0, 1.0);

		vec2 city_uv = offset.xy * 42.0;
		vec2 city_cell = floor(city_uv);
		vec2 city_local = fract(city_uv);
		float city_n = hash12(city_cell + 7.0);
		float has_light = step(0.90, city_n) * civ_mask;
		vec2 dot_pos = vec2(hash12(city_cell + 3.1), hash12(city_cell + 9.7));
		float city_size_n = hash12(city_cell + 5.5);
		float dot_radius = 0.28 + city_size_n * 0.30;
		float dot_mask = smoothstep(dot_radius, 0.0, distance(city_local, dot_pos));
		float brightness = 0.55 + 0.65 * city_size_n;
		float city_spark = has_light * dot_mask * night * city_light_amount * brightness;
		float cool_pick = step(0.88, hash12(city_cell + 2.2));
		vec3 city_col = mix(planet_city_light_warm, planet_city_light_cool, cool_pick);
		shaded += city_col * city_spark;

		// --- Faint polar aurora on the night side — a slowly drifting
		// colour-shifting ribbon near the ice caps, the one unmistakably
		// alien flourish on an otherwise earthlike world.
		float polar = smoothstep(0.55, 0.92, lat);
		float aurora_n = fbm(vec2(offset.x * 1.6 + TIME * 0.025, offset.y * 5.0 - TIME * 0.015));
		float aurora_band = smoothstep(0.48, 0.56, aurora_n) * (1.0 - smoothstep(0.56, 0.66, aurora_n));
		float aurora = aurora_band * polar * night * planet_aurora_amount;
		shaded += mix(planet_alien_accent_a, planet_alien_accent_b, aurora_n) * aurora * 0.8;

		// --- Terminator glow — a warm sunset band right along the raw
		// day/night line, distinct from (and narrower than) the old rim
		// highlight below, so the transition itself reads as a visible
		// atmospheric-scatter line the way a real limb photo shows one.
		float terminator = 1.0 - smoothstep(0.0, 0.05, abs(raw_ndotl));
		shaded += planet_terminator_glow_color * terminator * 0.4;

		// --- Two-tone atmosphere: a coloured haze that thickens toward
		// the grazing limb (nz -> 0), dimmer on the night side than the
		// day side, giving the disc a believable air/scatter halo instead
		// of a hard-edged rock.
		float limb = clamp(1.0 - nz, 0.0, 1.0);
		float atmo_rim = pow(limb, 2.2);
		vec3 atmo_col = mix(planet_atmosphere_color * 0.35, planet_atmosphere_color * 1.3, ndotl);
		shaded = mix(shaded, atmo_col, atmo_rim * 0.35);

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

		// Faint outer atmosphere glow just outside the disc edge, tinted
		// with the atmosphere colour on the night side and warming toward
		// the rim colour on the lit side — the soft coloured halo effect
		// that sells "planet with air" from a distance.
		float glow = smoothstep(planet_angular_radius + glow_margin, planet_angular_radius, d) - planet_mask;
		vec3 outer_glow_col = mix(planet_atmosphere_color, planet_rim_color, smoothstep(0.25, 0.9, ndotl));
		col += outer_glow_col * clamp(glow, 0.0, 1.0) * 0.22;
	}

	COLOR = col;
}
