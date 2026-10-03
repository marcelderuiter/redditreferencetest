// Deep recesses (mortar joints, unlit window and arch openings): light
// never reaches far into them, so they read as near-black.
shader_type spatial;
render_mode unshaded;

uniform vec3 color : source_color = vec3(0.012, 0.01, 0.01);

void fragment() {
	ALBEDO = color * COLOR.rgb;
}
