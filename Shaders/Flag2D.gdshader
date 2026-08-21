shader_type canvas_item;
// =============================================================
// Flag2D.gdshader
// =============================================================
// 2D counterpart of Flag.gdshader, for the epilogue's flat, layered
// finale scene (see Epilogue.gd's _build_flag_2d()).
//
// The source texture (orbital_drop_flag.png) is a fully opaque logo card
// — solid black background, gold border/logo, no alpha channel at all
// (confirmed: 0 transparent pixels) — so sampled as-is it's a solid
// black rectangle. Rather than keying black out everywhere (which also
// erases the flag's own solid cloth colour, leaving nothing but a bare
// outline), this instead cuts an actual wavy SILHOUETTE out of the
// rectangle: a band across the middle that ripples up and down at the
// top/bottom edges, same "pinned at the pole, rippling free at the
// other edge" idea as the old 3D vertex shader, just done here as an
// alpha cutout instead of a vertex displacement (a flat CanvasItem quad
// has no vertices to bend). Anything INSIDE that rippling band renders
// the texture completely solid — black cloth, gold border, logo, all of
// it — exactly like the source art. Only the sliver of rectangle ABOVE
// and BELOW the band (which the wave should have cut away, but the
// image itself can't since it has no alpha) is made transparent.
// =============================================================

uniform float wave_speed : hint_range(0.0, 5.0) = 1.6;
uniform float wave_amplitude : hint_range(0.0, 0.15) = 0.05;
uniform float wave_frequency : hint_range(0.0, 20.0) = 8.0;

// How far in from the texture's own top/bottom edges the silhouette
// band sits at rest (in UV space), so a sliver of the flag's own margin
// stays put even at zero wave — keeps the border from ever looking
// clipped flush against the cut.
uniform float edge_margin : hint_range(0.0, 0.2) = 0.02;
// How soft the cut edge is (UV space) — small values read as a crisp
// cloth edge, larger values feather it.
uniform float edge_softness : hint_range(0.001, 0.05) = 0.012;

// The texture's own gold border is baked in at a fixed straight position,
// so it doesn't track the animated top/bottom wave and visually detaches
// from the true (moving) cloth edge. To fix that, a matching gold rim is
// drawn procedurally right along the same top_edge/bottom_edge boundary
// used for the alpha cutout below, so the border always sits exactly on
// the moving silhouette edge instead of the static one baked into the art.
uniform vec4 edge_color : source_color = vec4(1.0, 0.851, 0.2, 1.0);
// How wide the procedural border band is (UV space, distance from the
// wavy top/bottom edge).
uniform float border_width : hint_range(0.0, 0.1) = 0.02;
// How soft the inner edge of the procedural border is (UV space).
uniform float border_feather : hint_range(0.001, 0.05) = 0.006;

void fragment() {
	// Ramps from ~0 at the pole edge (UV.x = 0) up to full strength
	// toward the free edge — same "pinned down one side" idea as the 3D
	// version: the silhouette barely moves near the pole and ripples
	// more freely further from it.
	float amp = wave_amplitude * smoothstep(0.0, 0.3, UV.x);
	float phase = UV.x * wave_frequency - TIME * wave_speed;
	float wave = sin(phase) * amp;

	vec4 tex = texture(TEXTURE, UV);

	// The band's top/bottom boundaries move together with `wave`, so
	// the whole silhouette ripples up and down as one cloth-like shape
	// rather than the top and bottom edges moving independently.
	float top_edge = edge_margin + wave;
	float bottom_edge = 1.0 - edge_margin - wave;
	float inside = smoothstep(top_edge - edge_softness, top_edge, UV.y)
			* (1.0 - smoothstep(bottom_edge, bottom_edge + edge_softness, UV.y));

	// Distance (UV space) from this fragment to whichever of the two wavy
	// edges is closer. Fragments right on the moving boundary get a small
	// value here regardless of which edge they're near, so the same border
	// band traces both the top and bottom of the rippling silhouette.
	float dist_to_edge = min(UV.y - top_edge, bottom_edge - UV.y);
	float border_factor = 1.0 - smoothstep(border_width - border_feather, border_width, dist_to_edge);
	vec3 rgb = mix(tex.rgb, edge_color.rgb, border_factor);

	COLOR = vec4(rgb, tex.a * inside);
}
