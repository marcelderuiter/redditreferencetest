// Full-screen colour grade: samples the finished frame and looks it up in a 3D LUT.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler3D lut : filter_linear;
uniform float lut_size = 33.0;
uniform float strength = 1.0;

void fragment() {
	vec3 c = clamp(texture(screen_tex, SCREEN_UV).rgb, 0.0, 1.0);
	vec3 uvw = c * ((lut_size - 1.0) / lut_size) + 0.5 / lut_size;
	vec3 g = texture(lut, uvw).rgb;
	COLOR = vec4(mix(c, g, strength), 1.0);
}
