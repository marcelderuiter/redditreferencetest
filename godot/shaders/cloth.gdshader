// Carpet runners and banners: red field, gold border, woven pattern.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 field : source_color = vec3(0.30, 0.17, 0.10);
uniform vec3 trim : source_color = vec3(0.55, 0.40, 0.20);

varying vec3 lpos;
varying vec3 wpos;

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 sz = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	vec2 p = lpos.xz * sz;               // metres from centre
	vec2 e = sz * 0.5 - abs(p);          // distance to edges
	float border = 1.0 - step(0.16, min(e.x, e.y));
	float inner = step(0.24, min(e.x, e.y)) * (1.0 - step(0.3, min(e.x, e.y)));
	// diamond medallions along the length
	vec2 q = vec2(p.x, mod(p.y + 0.9, 1.8) - 0.9);
	float diamond = 1.0 - step(0.38, abs(q.x) + abs(q.y) * 0.7);
	float ring = diamond * step(0.26, abs(q.x) + abs(q.y) * 0.7);
	float weave = 0.85 + 0.15 * vnoise(wpos * 60.0);
	vec3 c = field;
	c = mix(c, trim, max(border, max(inner, ring)));
	c *= weave * (0.8 + 0.3 * vnoise(wpos * 2.0));
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = 0.95;
}
