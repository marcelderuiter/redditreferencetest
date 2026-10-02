shader_type spatial;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

// Distant gothic masonry: stylised cool moonlight with a vertical falloff so
// silhouettes read through the haze without competing with the lit diorama.
uniform vec3 light_dir = vec3(-0.5, 0.6, 0.45);
uniform vec3 lit = vec3(0.026, 0.042, 0.095);
uniform vec3 shade_color = vec3(0.004, 0.006, 0.014);

void vertex() {
	COMMON_VERTEX
}

void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float fine = tri_sample(noise_fine, v_world * 0.5, world_n, 0.6);
	float coarse = tri_sample(noise_coarse, v_world * 0.5, world_n, 0.15);
	float diffuse = clamp(dot(world_n, normalize(light_dir)), 0.0, 1.0);
	float height = smoothstep(-60.0, 10.0, v_world.y);
	vec3 c = mix(shade_color, lit, diffuse * (0.5 + 0.5 * height));
	c *= (0.75 + 0.5 * fine) * (0.8 + 0.4 * coarse) * COLOR.rgb / 0.04;
	ALBEDO = c;
}
