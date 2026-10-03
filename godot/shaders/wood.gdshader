// Planks and beams: grain runs along each instance's longest axis.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.30, 0.19, 0.11);
uniform float roughness_v = 0.8;
uniform float bump = 1.0;

varying vec3 gp;
varying vec4 inst;
varying float wy;

void vertex() {
	vec3 l;
	vec3 hs;
	LOCAL_SETUP(l, hs);
	if (hs.y >= hs.x && hs.y >= hs.z) {
		l = l.yxz;
	} else if (hs.z >= hs.x && hs.z >= hs.y) {
		l = l.zyx;
	}
	inst = INSTANCE_CUSTOM;
	gp = l + inst.xyz * 10.0;
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float streak = vnoise(vec3(gp.x * 1.5, gp.y * 38.0, gp.z * 38.0));
	float fine = vnoise(vec3(gp.x * 4.0, gp.y * 120.0, gp.z * 120.0));
	float ring = fract(vnoise(vec3(gp.x * 0.6, gp.y * 5.0, gp.z * 5.0)) * 5.0);
	float knot = smoothstep(0.78, 0.9, vnoise(gp * vec3(3.0, 9.0, 9.0)));
	vec3 col = base_color * COLOR.rgb;
	col *= 0.62 + 0.55 * streak;
	col *= 0.85 + 0.3 * smoothstep(0.1, 0.9, ring);
	col *= 0.9 + 0.2 * fine;
	col *= 1.0 - knot * 0.5;
	col *= mix(1.0, 0.3, smoothstep(-1.6, -8.0, wy));
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.3;
	float h = streak * 0.012 + fine * 0.004 - knot * 0.01;
	NORMAL = bump_normal(VERTEX, NORMAL, h, bump);
}
