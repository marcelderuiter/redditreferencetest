// Tall tower faces seen far below: procedural block courses on big boxes.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.36, 0.33, 0.29);
uniform vec2 block = vec2(0.7, 0.4);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnorm);
	float u = an.x > an.z ? wpos.z : wpos.x;
	float row = floor(wpos.y / block.y);
	float uu = u / block.x + 0.5 * mod(row, 2.0);
	vec2 f = vec2(fract(uu), fract(wpos.y / block.y));
	float id = hash13(vec3(floor(uu), row, an.x > an.z ? 1.0 : 0.0));
	float mortar = min(min(f.x, 1.0 - f.x) * block.x, min(f.y, 1.0 - f.y) * block.y);
	float m = smoothstep(0.015, 0.045, mortar);
	float n = fbm3(wpos * 4.0);
	vec3 c = albedo * COLOR.rgb * (0.75 + 0.4 * id) * (0.75 + 0.4 * n);
	c *= mix(0.35, 1.0, m);
	// Fade into the abyss.
	c *= clamp(1.0 + (wpos.y + 1.0) / 24.0, 0.06, 1.0);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	vec3 g = vec3(0.0);
	NORMAL = bump_normal(NORMAL, wpos, wnorm, VIEW_MATRIX, 7.0, 0.6);
}
