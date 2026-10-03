// Candle wax and paper: soft, slightly self-lit near the flame.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.86, 0.74, 0.52);
uniform float glow = 0.6;

varying float ly;
varying vec3 wpos;

void vertex() {
	ly = VERTEX.y + 0.5;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos * 40.0);
	vec3 col = base_color * COLOR.rgb * (0.85 + 0.25 * n);
	ALBEDO = col;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
	EMISSION = col * vec3(1.0, 0.6, 0.3) * glow * smoothstep(0.4, 1.0, ly);
}
