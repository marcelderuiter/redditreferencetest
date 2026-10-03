// Candle wax: pale, a little translucent-looking (emission near the top).
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 albedo : source_color = vec3(0.85, 0.72, 0.5);
varying vec3 lpos;
void vertex() { lpos = VERTEX; }

void fragment() {
	ALBEDO = albedo * COLOR.rgb;
	ROUGHNESS = 0.6;
	EMISSION = vec3(1.0, 0.55, 0.2) * smoothstep(0.1, 0.5, lpos.y) * 0.6;
}
