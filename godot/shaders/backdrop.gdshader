// Distant gothic towers in the void: dark blue stone, sparse lit slits.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.10, 0.11, 0.14);
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnorm);
	float u = an.x > an.z ? wpos.z : wpos.x;
	vec2 cell = floor(vec2(u / 2.2, wpos.y / 3.5));
	vec2 f = fract(vec2(u / 2.2, wpos.y / 3.5));
	float lit = step(0.96, hash13(vec3(cell, an.x))) * step(0.35, f.x) * step(f.x, 0.65) * step(0.2, f.y) * step(f.y, 0.8);
	float course = smoothstep(0.0, 0.06, fract(wpos.y / 0.9)) * 0.3 + 0.7;
	vec3 c = albedo * COLOR.rgb * (0.7 + 0.5 * fbm3(wpos * 0.5)) * course;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0, 0.45, 0.15) * lit * 0.5 * COLOR.a * step(0.0, -wpos.y - 10.0 + 40.0 * step(60.0, length(wpos.xz)));
}
