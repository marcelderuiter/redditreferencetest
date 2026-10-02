shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

void vertex() {
	COMMON_VERTEX
}

void fragment() {
	// Grain runs along the longest axis (or vertical for staves: custom.y = 1).
	vec3 p = v_local + v_custom.x * 13.0;
	vec3 s = v_scale;
	vec2 g;
	if (v_custom.y > 0.5 || (s.y >= s.x && s.y >= s.z)) {
		g = vec2(p.y * 0.35, (p.x + p.z) * 9.0 + atan(v_local.z, v_local.x) * 2.0);
	} else if (s.x >= s.z) {
		g = vec2(p.x * 0.35, (p.y + p.z) * 9.0);
	} else {
		g = vec2(p.z * 0.35, (p.y + p.x) * 9.0);
	}
	float grain = texture(noise_fine, g * vec2(0.6, 0.12)).r;
	float rings = sin(grain * 40.0) * 0.5 + 0.5;
	float coarse = texture(noise_coarse, g * 0.05).r;
	float h = rings * 0.004 + coarse * 0.006;
	NORMAL = bump_normal(NORMAL, VERTEX, h, 1.0);
	float edge = edge_factor(v_local, v_scale, 0.025);
	vec3 albedo = COLOR.rgb * (0.7 + 0.35 * rings) * (0.8 + 0.4 * coarse);
	albedo *= 1.0 + edge * 0.3;
	albedo *= mix(0.2, 1.0, smoothstep(-22.0, 0.0, v_world.y));
	ALBEDO = albedo;
	ROUGHNESS = 0.78 - edge * 0.15;
	SPECULAR = 0.4;
}
