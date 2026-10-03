// Candle and fire flames: soft additive shells that flicker.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

global uniform float anim_time;
uniform vec3 core : source_color = vec3(1.0, 0.62, 0.22);
uniform float strength = 3.0;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float f = sin(anim_time * 11.0 + seed * 40.0) * 0.5 + sin(anim_time * 23.0 + seed * 13.0) * 0.5;
	VERTEX.y *= 1.0 + 0.12 * f;
	VERTEX.x += VERTEX.y * 0.15 * sin(anim_time * 7.0 + seed * 20.0);
}

void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float k = pow(facing, 1.6);
	vec3 col = mix(core * vec3(1.0, 0.55, 0.25), vec3(1.0, 0.9, 0.65), k);
	ALBEDO = col * strength * k * COLOR.rgb;   // instance colour dims halo shells
}
