// Final display pass: vignette, then the display-sRGB 3D LUT (the grade).
// The screen texture already holds tonemapped display sRGB, so the LUT sees
// exactly what tools/match.py captured as the raw render.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler3D lut : filter_linear, repeat_disable;
uniform bool use_lut = false;
uniform float lut_size = 33.0;
uniform float vignette = 0.25;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(0.75, 0.2, length(d));
	c *= mix(1.0, v, vignette);
	if (use_lut) {
		vec3 uvw = clamp(c, 0.0, 1.0) * ((lut_size - 1.0) / lut_size) + 0.5 / lut_size;
		c = texture(lut, uvw).rgb;
	}
	COLOR = vec4(c, 1.0);
}
