shader_type spatial;
render_mode unshaded, cull_disabled;
// =============================================================
// Flag.gdshader
// =============================================================
// CURRENTLY UNUSED — kept for reference. The epilogue's finale was
// rebuilt as a flat 2D scene, so the banner is drawn by Flag2D.gdshader
// now instead (a canvas_item shader, since a flat quad has no subdivided
// vertices for the technique below to bend). Nothing in the project
// loads this file any more, so it's safe to delete if you'd rather not
// carry it.
//
// A simple cloth-wave vertex shader for the Orbital Drop banner shown
// at the end of the campaign epilogue. Cheap and reliable: no cloth
// physics or SoftBody needed, just a couple of sine waves displacing a
// subdivided PlaneMesh, with the wave strength ramped from "pinned"
// at one edge to "free" at the other so it reads as flying from a pole
// down one side rather than flapping uniformly everywhere.
// unshaded — the banner is meant to be clearly readable regardless of
// how it happens to be lit, so it draws its own texture directly
// rather than depending on a scene light being aimed at it correctly.
// cull_disabled — visible from both sides.
// =============================================================

uniform sampler2D logo_texture : source_color;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.6;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.14;
uniform float wave_frequency : hint_range(0.0, 10.0) = 3.2;

void vertex() {
	// UV.x runs 0..1 across the plane regardless of its actual world
	// size, so remapping it to -1..1 gives a size-independent coordinate
	// for shaping the wave without needing to know the mesh's real
	// dimensions here.
	float u = UV.x * 2.0 - 1.0;
	float phase = u * wave_frequency - TIME * wave_speed;
	// Amplitude ramps from ~0 at the "pole" edge (u = -1) up to full
	// strength toward the free edge, so it reads as pinned down one
	// side instead of rippling uniformly like a loose sheet.
	float amp = wave_amplitude * smoothstep(-1.0, 0.2, u);
	VERTEX.z += sin(phase) * amp;
	VERTEX.y += sin(phase * 1.3 + 1.4) * amp * 0.4;
}

void fragment() {
	vec4 tex = texture(logo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
