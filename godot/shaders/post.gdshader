// Final pass over the rendered frame (display sRGB): vignette, then the
// optional 3D LUT grade fitted by tools/fit_lut.py.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler3D lut : filter_linear, repeat_disable;
uniform bool use_lut = false;
uniform float lut_size = 33.0;
uniform float vignette = 0.25;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.9);
	c *= 1.0 - vignette * smoothstep(0.2, 0.75, length(d) * 1.4);
	if (use_lut) {
		vec3 uvw = clamp(c, 0.0, 1.0) * ((lut_size - 1.0) / lut_size) + 0.5 / lut_size;
		c = texture(lut, uvw).rgb;
	}
	COLOR = vec4(c, 1.0);
}
