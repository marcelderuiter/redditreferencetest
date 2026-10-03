// Weathered stone for blocks, flagstones and pillars.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.45, 0.41, 0.37);
uniform float roughness_v = 0.9;
uniform float bump = 1.0;
uniform float wear = 0.4;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 inst;
varying vec3 lp;
varying vec3 halfsize;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	inst = INSTANCE_CUSTOM;
	LOCAL_SETUP(lp, halfsize);
}

void fragment() {
	vec3 p = wpos + inst.xyz * 13.0;
	float big = fbm3(p * 1.6);
	float fine = vnoise(p * 8.0);
	float grain = vnoise(p * 27.0);
	vec3 col = base_color * COLOR.rgb;
	col *= 0.55 + 0.9 * big;
	col *= 0.72 + 0.56 * grain;
	// Hairline cracks.
	float crack = smoothstep(0.035, 0.0, abs(vnoise(p * 3.1) - 0.5)) * smoothstep(0.45, 0.7, vnoise(p * 1.3 + 7.0));
	col *= 1.0 - 0.6 * crack;
	float stain = smoothstep(0.55, 0.85, fbm3(p * 0.5 + 3.0));
	col = mix(col, col * vec3(0.55, 0.5, 0.46), stain * 0.65);
	float pit = smoothstep(0.30, 0.16, fine);
	col *= 1.0 - 0.5 * pit;
	// Distance to the block's nearest edge on this face: worn, lighter rims.
	vec3 e = halfsize - abs(lp);
	vec3 an = abs(normalize(lp / max(halfsize, vec3(0.001))));
	float edge_d = (an.x > an.y && an.x > an.z) ? min(e.y, e.z) : ((an.y > an.z) ? min(e.x, e.z) : min(e.x, e.y));
	float rim = 1.0 - smoothstep(0.0, 0.05, edge_d);
	col *= 1.0 + rim * 0.18 * (0.5 + big);
	float up = clamp(wnrm.y, 0.0, 1.0);
	col = mix(col, col * vec3(1.1, 1.05, 0.98), up * wear);
	col *= mix(0.8, 1.0, clamp(wnrm.y + 1.0, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = roughness_v - rim * 0.1;
	SPECULAR = 0.35;
	float h = big * 0.04 + fine * 0.016 - pit * 0.03 + grain * 0.009 - rim * 0.012 - crack * 0.02;
	NORMAL = bump_normal(VERTEX, NORMAL, h, bump);
}
