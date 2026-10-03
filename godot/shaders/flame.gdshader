// Candle and fire flames: additive, unshaded teardrop.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.85, 0.5);
uniform vec3 outer : source_color = vec3(1.0, 0.38, 0.06);
uniform float energy = 3.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float y = 1.0 - UV.y;                 // 0 bottom .. 1 tip
	float width = sin(clamp(y, 0.0, 1.0) * 3.14159) * (1.0 - y * 0.55) + 0.05;
	float d = abs(p.x) / max(width, 0.01);
	float a = smoothstep(1.0, 0.2, d) * smoothstep(0.0, 0.12, y) * smoothstep(1.0, 0.75, y);
	float hot = smoothstep(0.6, 0.0, d) * smoothstep(0.75, 0.15, y);
	vec3 c = mix(outer, core, hot) * energy * COLOR.rgb;
	ALBEDO = c * a;
}
