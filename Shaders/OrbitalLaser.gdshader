shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// =============================================================
// OrbitalLaser.gdshader
// =============================================================
// The beam fired from the command deck when an orbital strike resolves
// (see CommandCentre._fire_orbital_laser()). Two nested cylinders share
// this shader — a thin near-white core inside a wider orange sheath — for
// the "searing white centre, orange sides" look.
//
// The white-inside/orange-outside gradient is done with a FRESNEL term
// rather than a texture or a UV ramp, which is what makes it hold up from
// every angle. On a cylinder, the surface facing the camera has its normal
// pointing at the viewer (dot ~ 1) and the silhouette edges have theirs
// perpendicular to it (dot ~ 0) — so 1 - |dot(NORMAL, VIEW)| is 0 down the
// visible middle of the beam and 1 at its outline, whichever side you walk
// around to. A horizontal UV ramp would only be correct from one viewpoint.
//
// abs() on that dot matters because cull_disabled draws the far wall of
// the cylinder too, whose normals point away from the camera and would
// otherwise come out negative and clamp to the core colour, making the
// beam read as solid white from the inside out.
//
// blend_add + depth_draw_never is the usual beam setup: it adds light to
// whatever is behind it and doesn't write depth, so the two cylinders
// don't z-fight with each other. Depth TESTING is deliberately left on, so
// the deck and consoles still occlude the beam properly rather than it
// being painted over the whole scene.
// =============================================================

uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.06, 1.0);

// Overall brightness. Tweened from 0 up on fire and back down on fade —
// that's what makes the beam appear and die away (see the tween in
// CommandCentre._fire_orbital_laser()), so leave it animated rather than
// setting it once.
uniform float energy : hint_range(0.0, 12.0) = 3.0;

// Where the colour turns over from core to edge. LOWER values push the
// orange further in toward the middle; higher values keep more of the beam
// white and squeeze the orange into a thin rim.
// Values BELOW 1 are the useful range for the outer sheath: the fresnel
// term only reaches 1 exactly at the silhouette, so an exponent above 1
// crushes it and the sheath comes out pale cream instead of orange. 0.5
// puts it about half-way to orange by mid-radius.
uniform float edge_power : hint_range(0.15, 12.0) = 2.4;

// Fast overall brightness jitter — the beam is meant to look like it's
// straining, not like a clean neon tube.
uniform float flicker_speed : hint_range(0.0, 80.0) = 26.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.16;

// Bands of extra brightness running along the beam, away from the deck,
// which read as energy being pumped down it.
uniform float travel_speed : hint_range(0.0, 30.0) = 7.0;
uniform float travel_density : hint_range(0.0, 120.0) = 38.0;
uniform float travel_amount : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	// 0 down the middle of the beam as seen from here, 1 at its outline.
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	rim = pow(clamp(rim, 0.0, 1.0), edge_power);

	vec3 col = mix(core_color.rgb, edge_color.rgb, rim);

	// UV.y runs along a CylinderMesh's length, so this travels outward.
	float travel = sin(UV.y * travel_density - TIME * travel_speed) * 0.5 + 0.5;
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed));
	float pulse = (1.0 + travel_amount * travel) * flicker;

	// unshaded means ALBEDO is written out directly, and blend_add then
	// adds it to the frame — so values above 1 blow out into the glow pass
	// instead of clipping flat, which is what gives the core its hot look.
	ALBEDO = col * energy * pulse;
	// Softens the outline so the cylinder doesn't end on a hard edge.
	ALPHA = clamp((1.0 - rim * 0.55) * min(energy, 1.0), 0.0, 1.0);
}
