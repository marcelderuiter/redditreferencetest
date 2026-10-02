shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// custom.x seed, custom.y intensity. Additive emissive teardrop.
varying float v_height;
varying float v_seed;
varying float v_intensity;

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
	v_intensity = INSTANCE_CUSTOM.y;
	v_height = VERTEX.y + 0.5;
	float t = TIME * (7.0 + v_seed * 5.0) + v_seed * 40.0;
	float sway = (sin(t) * 0.5 + sin(t * 1.7 + 1.3) * 0.3) * v_height * v_height;
	VERTEX.x += sway * 0.25;
	VERTEX.z += cos(t * 1.3) * 0.12 * v_height * v_height;
	VERTEX.y *= 1.0 + 0.12 * sin(t * 2.3);
}

void fragment() {
	float core = 1.0 - smoothstep(0.0, 0.75, v_height);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 hot = vec3(1.0, 0.85, 0.55);
	vec3 col = mix(COLOR.rgb, hot, core * 0.8);
	float flicker = 0.85 + 0.15 * sin(TIME * 13.0 + v_seed * 60.0);
	ALBEDO = col * (1.2 + 5.0 * core) * facing * v_intensity * flicker;
}
