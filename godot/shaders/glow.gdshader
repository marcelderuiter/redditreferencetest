// Emissive panels: lit windows, forge embers, gold glints.
shader_type spatial;
render_mode unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.45, 0.12);
uniform float energy = 1.6;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float n = 0.6 + 0.6 * fbm3(wpos * 5.0);
	ALBEDO = tint * COLOR.rgb * energy * n;
}
