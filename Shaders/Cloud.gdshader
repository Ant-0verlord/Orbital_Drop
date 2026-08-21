shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always, shadows_disabled;
// =============================================================
// Cloud.gdshader
// =============================================================
// A soft, edge-faded look for the epilogue's "dive cloud" — a cluster of
// overlapping spheres (see Epilogue.gd's _build_dive_cloud()) uses this
// on every sphere so the cluster reads as one puffy mass instead of a
// handful of obviously-solid balls. The fade is a simple fresnel: full
// opacity dead-on to the camera, fading out toward each sphere's own
// silhouette edge.
// unshaded — no need for real lighting here, this only exists to be
// flown into and cut away from.
// blend_mix + depth_draw_always — lets the soft alpha edges actually
// blend against whatever's behind them (the starfield) instead of being
// treated as fully opaque.
// =============================================================

uniform vec3 cloud_color : source_color = vec3(0.92, 0.93, 0.95);
uniform float edge_softness : hint_range(0.1, 3.0) = 0.9;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = pow(facing, edge_softness);
	ALBEDO = cloud_color;
	ALPHA = a;
}
