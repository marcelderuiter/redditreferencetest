shader_type canvas_item;
render_mode unshaded;

// Final presentation pass over the tonemapped, display-encoded 3D image.
// Optional .cube colour-grade LUT (color_lut.gd strip texture, display sRGB in
// and out), a mild vignette, and a reference comparison overlay.
uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D lut : filter_linear, repeat_disable;
uniform int lut_size = 0;
uniform float lut_strength = 0.0;
uniform float vignette = 0.0;
uniform sampler2D reference : filter_linear_mipmap, repeat_disable;
// 0 off, 1 split (reference right of the divider), 2 reference only.
uniform int compare_mode = 0;
uniform float divider = 0.5;

vec3 apply_lut(vec3 encoded) {
	float n = float(lut_size);
	vec3 cell = clamp(encoded, 0.0, 1.0) * (n - 1.0);
	float slice = min(floor(cell.b), n - 2.0);
	vec2 inside = (cell.rg + 0.5) / vec2(n * n, n);
	vec3 low = textureLod(lut, inside + vec2(slice / n, 0.0), 0.0).rgb;
	vec3 high = textureLod(lut, inside + vec2((slice + 1.0) / n, 0.0), 0.0).rgb;
	return mix(low, high, cell.b - slice);
}

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 0.0).rgb;
	// Vignette belongs to the scene image; the LUT grades the result, so
	// raw captures (LUT off) are exactly what the fitted LUT receives.
	vec2 q = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, length(q * vec2(1.1, 1.0)));
	if (lut_size >= 2 && lut_strength > 0.0) {
		c = mix(c, apply_lut(c), lut_strength);
	}
	if (compare_mode == 2 || (compare_mode == 1 && SCREEN_UV.x > divider)) {
		c = texture(reference, SCREEN_UV).rgb;
	}
	if (compare_mode == 1 && abs(SCREEN_UV.x - divider) < 0.0012) {
		c = vec3(1.0);
	}
	COLOR = vec4(c, 1.0);
}
