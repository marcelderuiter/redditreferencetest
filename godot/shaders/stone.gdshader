// Masonry blocks, flagstones and cobbles. Instance COLOR tints each block;
// world-space noise adds pitting and grime; chamfers read darker as grout.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.41, 0.38, 0.34);
uniform float bump_strength = 1.1;
uniform float bump_freq = 9.0;
uniform float grime = 0.8;
uniform float roughness_base = 0.86;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lpos;
varying vec3 lnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	float n = fbm3(wpos * 3.0);
	float fine = vnoise(wpos * 23.0);
	// Chamfer faces have diagonal local normals: treat them as worn edges / grout.
	float flat_face = max(max(abs(lnorm.x), abs(lnorm.y)), abs(lnorm.z));
	float edge = smoothstep(0.98, 0.7, flat_face);
	vec3 c = albedo * COLOR.rgb * (0.62 + 0.7 * n) * (0.8 + 0.4 * fine);
	// Grime collects low on vertical faces and in the chamfers.
	float down = clamp(-wnorm.y, 0.0, 1.0);
	c *= 1.0 - grime * (0.35 * edge + 0.25 * down);
	
	ALBEDO = c;
	ROUGHNESS = roughness_base - 0.1 * fine;
	NORMAL = bump_normal(NORMAL, wpos, wnorm, VIEW_MATRIX, bump_freq, bump_strength);
}
