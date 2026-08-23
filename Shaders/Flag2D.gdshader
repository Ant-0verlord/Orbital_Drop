shader_type canvas_item;
// =============================================================
// Flag2D.gdshader
// =============================================================
// 2D counterpart of Flag.gdshader, for the epilogue's flat finale
// scene (see Epilogue.gd's _build_flag_2d()).
//
// The source texture (orbital_drop_flag.png) is a fully opaque logo card
// — solid black cloth, a gold border inset from all four sides, no alpha
// channel at all (confirmed: 0 transparent pixels) — so sampled as-is it
// draws as a solid rectangle with a dead-straight gold frame. A flat
// CanvasItem quad also has no subdivided vertices to bend, so the 3D
// version's vertex displacement isn't available here either.
//
// So the wave is done entirely in UV space, in two halves that MUST stay
// in agreement or the border stops looking like the edge of the cloth:
//
//   1. A band across the quad — [top_edge, bottom_edge] — whose position
//      ripples per-column via a sine, pinned near the pole (UV.x = 0) and
//      free at the other end, same idea as the 3D shader. Everything
//      outside the band is made transparent, which is what actually cuts
//      a cloth silhouette out of a rectangle that has no alpha of its own.
//   2. The texture is then SAMPLED THROUGH that band — UV.y is remapped
//      so the full image spans top_edge..bottom_edge rather than 0..1.
//
// Step 2 is the important one. Without it the image stays pinned to the
// quad while only the cutout moves, so the texture's own gold border sits
// still at a fixed straight position while the real (moving) cloth edge
// travels away from it — they visibly come apart. With it, the border is
// carried along by the same wave that defines the silhouette, so the gold
// always lands exactly on the cloth's edge, and the logo and text ripple
// with the cloth instead of sitting flat behind a moving mask. No
// separate procedural border is needed — the art's own border IS the edge.
//
// Because both edges shift by the same `wave` (rather than one plus and
// one minus), the band translates as one shape instead of pinching and
// bulging — which also means a single edge_margin of at least
// wave_amplitude on each side is enough to guarantee the band never
// leaves the quad. That guarantee matters: if an edge ever ran off the
// top or bottom, the cutout there would do nothing, the cloth would
// square off flat against the quad boundary, and the straight baked
// border would be what showed. Keep edge_margin >= wave_amplitude.
// =============================================================

uniform float wave_speed : hint_range(0.0, 5.0) = 1.6;
// Keep edge_margin below at or above this — see the note above.
uniform float wave_amplitude : hint_range(0.0, 0.15) = 0.05;
uniform float wave_frequency : hint_range(0.0, 20.0) = 8.0;

// How far in from the quad's top/bottom the cloth sits at rest, in UV
// space. Doubles as the wave's headroom, so it must be >= wave_amplitude
// or the band clips against the quad (see header). The cloth ends up
// occupying (1 - 2 * edge_margin) of the quad's height, which is why
// Epilogue.gd sizes the flag's rect taller than the cloth is meant to
// look — see FLAG_TEX_HEIGHT_PX / FLAG_CLOTH_BAND there.
uniform float edge_margin : hint_range(0.0, 0.2) = 0.06;
// How soft the cut edge is (UV space) — small values read as a crisp
// cloth edge, larger values feather it.
uniform float edge_softness : hint_range(0.001, 0.05) = 0.012;

void fragment() {
	// Ramps from ~0 at the pole edge (UV.x = 0) up to full strength
	// toward the free edge — same "pinned down one side" idea as the 3D
	// version: the cloth barely moves near the pole and ripples more
	// freely further from it.
	float amp = wave_amplitude * smoothstep(0.0, 0.3, UV.x);
	float phase = UV.x * wave_frequency - TIME * wave_speed;
	float wave = sin(phase) * amp;

	// Both edges take the SAME sign of `wave`, so the band slides as one
	// piece. Since the phase varies across UV.x, neighbouring columns
	// slide by different amounts — which is what reads as a travelling
	// ripple rather than the whole banner bobbing up and down together.
	float top_edge = edge_margin + wave;
	float bottom_edge = 1.0 - edge_margin + wave;

	// Sample the texture through the band rather than through the quad,
	// so the art (border included) rides the wave instead of sitting
	// still behind it. Clamped because the fragments in the soft edge
	// just outside the band would otherwise sample past the image.
	float span = bottom_edge - top_edge;
	float src_y = clamp((UV.y - top_edge) / span, 0.0, 1.0);
	vec4 tex = texture(TEXTURE, vec2(UV.x, src_y));

	// Everything outside the band is cut away — this is the silhouette
	// the opaque source image can't provide on its own.
	float inside = smoothstep(top_edge - edge_softness, top_edge, UV.y)
			* (1.0 - smoothstep(bottom_edge, bottom_edge + edge_softness, UV.y));

	COLOR = vec4(tex.rgb, tex.a * inside);
}
