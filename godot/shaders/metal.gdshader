// Brass, iron, gold, statue bronze and the orrery's bronze and gilding.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.78, 0.52, 0.24);
uniform float roughness_v = 0.35;
uniform float metal = 0.9;
uniform float bump = 0.6;
uniform float self_lit = 0.0;  // fakes bounce light inside gold heaps
// Bevelled boxes only (Kit sets these on a per-mesh copy): metric chamfer (m)
// and rubbed edges, brighter and smoother, that catch the light.
uniform float chamfer = 0.0;
uniform float chip = 0.35;
uniform float edge_wear = 0.0;

varying vec3 wpos;
varying vec4 inst;
varying vec3 lp;
varying vec3 halfsize;

void vertex() {
	if (chamfer > 0.0) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		metric_bevel(VERTEX, NORMAL, sc, INSTANCE_CUSTOM.xyz, chamfer, chip);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst = INSTANCE_CUSTOM;
	LOCAL_SETUP(lp, halfsize);
}

void fragment() {
	vec3 p = wpos * 6.0 + inst.xyz * 7.0;
	float grime = fbm3(p);
	float fine = vnoise(p * 6.0);
	vec3 col = base_color * COLOR.rgb;
	col *= 0.65 + 0.5 * grime;
	float rub = 0.0;
	if (edge_wear > 0.0) {
		vec3 e = halfsize - abs(lp);
		vec3 an = abs(normalize(lp / max(halfsize, vec3(0.001))));
		float edge_d = (an.x > an.y && an.x > an.z) ? min(e.y, e.z) : ((an.y > an.z) ? min(e.x, e.z) : min(e.x, e.y));
		rub = edge_wear * (1.0 - smoothstep(0.0, 0.035, edge_d));
		col = mix(col, vec3(0.88, 0.72, 0.48), rub * 0.7);
	}
	ALBEDO = col;
	EMISSION = col * self_lit * (0.6 + 0.8 * fine);
	METALLIC = metal;
	ROUGHNESS = clamp(roughness_v + (0.5 - grime) * 0.3 + fine * 0.1 - rub * 0.2, 0.05, 1.0);
	float h = grime * 0.01 + fine * 0.003;
	NORMAL = bump_normal(VERTEX, NORMAL, h, bump);
}
