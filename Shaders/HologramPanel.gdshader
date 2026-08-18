shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// =============================================================
// HologramPanel.gdshader
//
// Recreates the "wireframe edge glow on a translucent/metallic panel"
// look from the Blender material — Blender's Wireframe node + mixed
// Translucent/Emission BSDFs have no glTF equivalent, so that part of
// the shader graph can't survive an export no matter how it's rebuilt
// in Blender. This gets the same visual result natively in Godot
// instead, layered on top of whatever base color the mesh actually
// imports with (vertex-painted hex tiles, in this case).
//
// HOW TO APPLY, once the simplified glTF import is in the project:
//   1. Select the mesh's surface material slot in the Inspector
//      (MeshInstance3D > Surface Material Override, or edit the
//      imported material directly).
//   2. New Shader Material > Shader > Load > this file.
//   3. Tweak the uniforms below in the Inspector to taste — defaults
//      are a cyan hologram glow, adjust edge_color/emission_color to
//      match the original render.
// =============================================================

// Base surface — COLOR is the mesh's own vertex-painted color (from the
// Blender Color Attribute), so the hand-painted hex tiles still show.
// albedo_texture is optional, for pieces using an image texture instead.
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;

uniform float metallic : hint_range(0.0, 1.0) = 0.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.4;

// Steady base glow (e.g. a soft panel backlight) — separate from the
// edge glow below so the two can be tuned independently.
uniform vec4 emission_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 0.5;

// Hologram edge glow — a fresnel (view-angle) rim light standing in for
// Blender's Wireframe-driven edge highlight. Brightens surfaces that
// are facing away from the camera at a grazing angle, which reads as a
// glowing outline on curved/faceted geometry like the hex tiles.
uniform vec4 edge_color : source_color = vec4(0.3, 1.0, 1.0, 1.0);
uniform float edge_power : hint_range(0.5, 8.0) = 2.5;
uniform float edge_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec3 base = COLOR.rgb * albedo_tint.rgb;
	if (use_texture) {
		base = texture(albedo_texture, UV).rgb * albedo_tint.rgb;
	}
	ALBEDO = base;
	METALLIC = metallic;
	ROUGHNESS = roughness;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_power);
	EMISSION = emission_color.rgb * emission_strength + edge_color.rgb * fresnel * edge_strength;
}
