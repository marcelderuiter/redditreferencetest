// Planks and beams: grain along the local x axis of each instance.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.30, 0.23, 0.15);

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lpos;
varying float seed;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	seed = INSTANCE_CUSTOM.x;
	lpos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}

void fragment() {
	float grain = vnoise(vec3(lpos.x * 1.5, lpos.y * 40.0, lpos.z * 40.0) + seed * 17.0);
	float streak = vnoise(vec3(lpos.x * 0.6, lpos.y * 9.0, lpos.z * 9.0) + seed * 5.0);
	vec3 c = albedo * COLOR.rgb * (0.65 + 0.45 * grain) * (0.8 + 0.35 * streak);
	ALBEDO = c;
	ROUGHNESS = 0.75;
	NORMAL = bump_normal(NORMAL, wpos, wnorm, VIEW_MATRIX, 14.0, 0.5);
}
