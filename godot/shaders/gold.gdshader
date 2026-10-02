shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

void vertex() {
	COMMON_VERTEX
}

void fragment() {
	// Mounds read as heaps of coins: cellular bumps on the large shapes.
	float fine = tri_sample(noise_fine, v_world, v_local_n, 3.5);
	NORMAL = bump_normal(NORMAL, VERTEX, fine * 0.02, 1.0);
	ALBEDO = COLOR.rgb * (0.85 + fine * 0.3);
	METALLIC = 0.95;
	ROUGHNESS = 0.22 + fine * 0.15;
	// Tiny glints so gold reads in dim rooms.
	EMISSION = COLOR.rgb * smoothstep(0.82, 0.95, fine) * 0.6;
}
