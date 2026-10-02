shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

uniform float bump_strength = 1.0;
uniform float edge_light = 0.65;
uniform float grime = 0.55;
// Ambient occlusion of the abyss: stone darkens with depth below the platforms.
uniform float abyss_top = 0.0;
uniform float abyss_bottom = -22.0;
uniform float abyss_floor = 0.4;

void vertex() {
	COMMON_VERTEX
}

void fragment() {
	vec3 p = v_local + v_custom.xyz * 31.0;
	float fine = tri_sample(noise_fine, p, v_local_n, 1.5);
	float coarse = tri_sample(noise_coarse, p, v_local_n, 0.22);
	// Pitted surface: coarse undulation plus fine grain and sparse pits.
	float pits = smoothstep(0.62, 0.8, fine) * smoothstep(0.45, 0.7, coarse);
	float h = coarse * 0.03 + fine * 0.008 - pits * 0.012;
	NORMAL = bump_normal(NORMAL, VERTEX, h, bump_strength);
	float edge = edge_factor(v_local, v_scale, 0.07);
	vec3 albedo = COLOR.rgb;
	albedo *= mix(1.0 - grime * 0.5, 1.0 + grime * 0.25, coarse);
	albedo *= 0.74 + fine * 0.52;
	albedo *= 1.0 - pits * 0.35;
	// Worn edges catch light; lower faces gather dirt.
	albedo *= 1.0 + edge * edge_light;
	float down = clamp(-v_local_n.y, 0.0, 1.0);
	albedo *= 1.0 - down * 0.25;
	// Warm grime in hollows.
	albedo = mix(albedo, albedo * vec3(0.92, 0.86, 0.78), (1.0 - coarse) * 0.4);
	albedo *= mix(abyss_floor, 1.0, smoothstep(abyss_bottom, abyss_top, v_world.y));
	ALBEDO = albedo;
	ROUGHNESS = mix(0.92, 0.7, edge) - fine * 0.08;
	SPECULAR = 0.35;
}
