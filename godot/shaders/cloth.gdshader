// Woven runners and rugs: dull red-brown field, faded border and diamond
// motif (saturated colour comes from the candles, not the dye).
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 field : source_color = vec3(0.232, 0.172, 0.144);
uniform vec3 trim : source_color = vec3(0.326, 0.274, 0.222);

varying vec3 lp;
varying vec3 halfsize;
varying vec3 wpos;

void vertex() {
	LOCAL_SETUP(lp, halfsize);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = lp.xz;
	vec2 hs = halfsize.xz;
	float long_axis = hs.y > hs.x ? 1.0 : 0.0;
	vec2 a = long_axis > 0.5 ? q : q.yx;
	vec2 ha = long_axis > 0.5 ? hs : hs.yx;
	float d = min(ha.x - abs(a.x), ha.y - abs(a.y));
	float border = step(d, 0.14) * step(0.05, d);
	float line = step(abs(d - 0.2), 0.02);
	float cell = ha.x * 1.6;
	vec2 m = vec2(a.x, mod(a.y + cell * 0.5, cell) - cell * 0.5);
	float diamond = step(abs(abs(m.x) + abs(m.y) - ha.x * 0.45), 0.035);
	float dot_c = step(abs(m.x) + abs(m.y), ha.x * 0.14);
	float motif = max(diamond, dot_c) * step(0.25, d);
	vec3 col = field;
	col = mix(col, trim, max(max(border, line), motif));
	float weave = vnoise(wpos * 90.0);
	float fade = fbm3(wpos * 2.0);
	col *= (0.8 + 0.3 * weave) * (0.75 + 0.45 * fade);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	NORMAL = bump_normal(VERTEX, NORMAL, weave * 0.003, 1.0);
}
