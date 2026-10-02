// Shared instance varyings and helpers for the diorama materials. Every batch
// is a MultiMesh: COLOR is the per-instance linear albedo, INSTANCE_CUSTOM.x a
// random seed and .y/.z material-specific parameters.
varying vec3 v_local;      // vertex position in metres, block space
varying vec3 v_local_n;    // object-space normal
varying vec3 v_scale;      // instance scale
varying vec3 v_world;
varying vec4 v_custom;

uniform sampler2D noise_fine : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_coarse : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

// Varyings may only be written in vertex(), so this is a macro.
#define COMMON_VERTEX v_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)); v_local = VERTEX * v_scale; v_local_n = NORMAL; v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; v_custom = INSTANCE_CUSTOM;

float tri_sample(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.yz * scale).r * w.x + texture(tex, p.xz * scale).r * w.y + texture(tex, p.xy * scale).r * w.z;
}

// Mikkelsen surface-gradient bump: height in metres, view-space normal.
vec3 bump_normal(vec3 n, vec3 view_pos, float h, float strength) {
	vec3 sigma_s = dFdx(view_pos);
	vec3 sigma_t = dFdy(view_pos);
	vec3 r1 = cross(sigma_t, n);
	vec3 r2 = cross(n, sigma_s);
	float det = dot(sigma_s, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - grad * strength);
}

// 0 inside a face, 1 on an instance-box edge (distance in metres).
float edge_factor(vec3 local, vec3 scale, float width) {
	vec3 d = max(scale * 0.5 - abs(local), vec3(0.0));
	float a = min(d.x, min(d.y, d.z));
	float b = max(min(d.x, d.y), min(max(d.x, d.y), d.z));
	return 1.0 - smoothstep(0.0, width, b);
}
