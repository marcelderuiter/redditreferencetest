// Brass, iron, gold and statue bronze.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.78, 0.52, 0.24);
uniform float roughness_v = 0.35;
uniform float metal = 0.9;
uniform float bump = 0.6;
uniform float self_lit = 0.0;  // fakes bounce light inside gold heaps

varying vec3 wpos;
varying vec4 inst;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 p = wpos * 6.0 + inst.xyz * 7.0;
	float grime = fbm3(p);
	float fine = vnoise(p * 6.0);
	vec3 col = base_color * COLOR.rgb;
	col *= 0.65 + 0.5 * grime;
	ALBEDO = col;
	EMISSION = col * self_lit * (0.6 + 0.8 * fine);
	METALLIC = metal;
	ROUGHNESS = clamp(roughness_v + (0.5 - grime) * 0.3 + fine * 0.1, 0.05, 1.0);
	float h = grime * 0.01 + fine * 0.003;
	NORMAL = bump_normal(VERTEX, NORMAL, h, bump);
}
