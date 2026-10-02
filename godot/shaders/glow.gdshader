shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/common.gdshaderinc"

// Embers: dark crust with pulsing hot cracks.
void vertex() {
	COMMON_VERTEX
}

void fragment() {
	float n = tri_sample(noise_fine, v_local * 6.0 + v_custom.x * 9.0, v_local_n, 1.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + v_custom.x * 30.0);
	float crack = smoothstep(0.45, 0.7, n);
	ALBEDO = vec3(0.05, 0.03, 0.02);
	ROUGHNESS = 0.9;
	EMISSION = COLOR.rgb * crack * pulse * 6.0;
}
