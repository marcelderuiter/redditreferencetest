shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

// Painted miniature: custom.y metallic. Drybrushed edges via fresnel rim.
void vertex() {
	COMMON_VERTEX
}

void fragment() {
	float fine = tri_sample(noise_fine, v_world, v_local_n, 4.0);
	float metal = v_custom.y;
	vec3 albedo = COLOR.rgb * (0.9 + fine * 0.2);
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = mix(0.62, 0.32, metal);
	RIM = 0.35;
	RIM_TINT = 0.6;
}
