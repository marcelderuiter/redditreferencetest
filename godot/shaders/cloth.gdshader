shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

// custom.y pattern: 0 runner, 1 rug, 2 banner. custom.z length/width ratio.
uniform vec3 gold = vec3(0.62, 0.38, 0.1);
uniform vec3 ink = vec3(0.12, 0.03, 0.02);

void vertex() {
	COMMON_VERTEX
}

float diamond(vec2 q) {
	return abs(q.x) + abs(q.y);
}

void fragment() {
	vec2 uv = UV;
	float aspect = max(v_custom.z, 0.01);
	float pattern = v_custom.y;
	vec3 base = COLOR.rgb;
	vec3 albedo = base;
	// Carpet/banner top face only; edges stay plain.
	bool face = pattern > 2.5 ? false : (pattern > 1.5 ? abs(v_local_n.z) > 0.5 : v_local_n.y > 0.5);
	if (face) {
		vec2 q = uv - 0.5;
		vec2 border_d = 0.5 - abs(q);
		float bw = 0.07;
		float bwy = bw / aspect;
		float border = max(step(border_d.x, bw), step(border_d.y, bwy));
		float inner_line = max(step(abs(border_d.x - bw * 1.4), 0.008), step(abs(border_d.y - bwy * 1.4), 0.008 / aspect));
		albedo = mix(albedo, gold, border * 0.85);
		albedo = mix(albedo, gold * 0.8, inner_line * (1.0 - border));
		if (pattern < 0.5) {
			// Repeating diamonds along the runner.
			vec2 r = vec2(q.x, fract(uv.y * aspect * 0.7) - 0.5);
			float d = diamond(r * vec2(1.0, 1.0));
			albedo = mix(albedo, gold * 0.9, step(abs(d - 0.28), 0.03) * (1.0 - border));
			albedo = mix(albedo, ink, step(d, 0.1) * (1.0 - border));
		} else {
			// Central medallion with a star.
			vec2 r = q * vec2(1.0, aspect);
			float d = length(r);
			float ang = atan(r.y, r.x);
			float star = 0.16 + 0.07 * cos(ang * 8.0);
			albedo = mix(albedo, gold * 0.9, step(abs(d - 0.24), 0.02));
			albedo = mix(albedo, gold * 0.75, step(d, star) * step(0.04, d));
			albedo = mix(albedo, ink, step(abs(diamond(r) - 0.36), 0.015) * (1.0 - border));
		}
	}
	// Woven texture and wear.
	float weave = texture(noise_fine, v_world.xz * 6.0).r;
	float wear = tri_sample(noise_coarse, v_world, v_local_n, 0.3);
	albedo *= 0.78 + weave * 0.35;
	albedo = mix(albedo, albedo * 0.6, smoothstep(0.55, 0.85, wear) * 0.6);
	NORMAL = bump_normal(NORMAL, VERTEX, weave * 0.002, 1.0);
	ALBEDO = albedo;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	BACKLIGHT = albedo * 0.3;
}
