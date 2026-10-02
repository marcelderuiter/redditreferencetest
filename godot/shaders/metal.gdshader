shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

// custom.y: 0 brass, 1 blackened iron.
void vertex() {
	COMMON_VERTEX
}

void fragment() {
	vec3 p = v_local + v_custom.x * 7.0;
	float fine = tri_sample(noise_fine, p, v_local_n, 1.6);
	float coarse = tri_sample(noise_coarse, p, v_local_n, 0.4);
	float iron = step(0.5, v_custom.y);
	float edge = edge_factor(v_local, v_scale, 0.02);
	float tarnish = smoothstep(0.35, 0.75, coarse) * (1.0 - edge);
	vec3 albedo = COLOR.rgb;
	albedo = mix(albedo, albedo * vec3(0.55, 0.5, 0.42), tarnish * mix(0.6, 0.4, iron));
	albedo *= 1.0 + edge * 0.4;
	NORMAL = bump_normal(NORMAL, VERTEX, fine * 0.002 + coarse * 0.002, 1.0);
	albedo *= mix(0.2, 1.0, smoothstep(-22.0, 0.0, v_world.y));
	ALBEDO = albedo;
	METALLIC = mix(0.9, 0.6, iron);
	ROUGHNESS = mix(mix(0.28, 0.5, tarnish), mix(0.55, 0.75, tarnish), iron) - edge * 0.1;
}
