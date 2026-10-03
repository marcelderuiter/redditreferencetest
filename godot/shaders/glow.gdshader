// Self-lit surfaces: embers, lit window panes, glowing coals.
shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://shaders/noise.gdshaderinc"

global uniform float anim_time;
uniform vec3 core : source_color = vec3(1.0, 0.55, 0.18);
uniform float strength = 2.5;

varying vec3 wpos;
varying float seed;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	float n = fbm3(wpos * 5.0 + vec3(0.0, anim_time * 0.7, 0.0) + seed * 9.0);
	ALBEDO = core * strength * (0.55 + 0.7 * n) * COLOR.rgb;
}
