// Shared hash / value noise helpers (world-space procedural detail).
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
	               mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
	               mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 + 3.7) * 0.2;
}

// Bump: perturbs a view-space normal with the gradient of a world-space height field.
vec3 bump_normal(vec3 n_view, vec3 wpos, vec3 wnorm, mat4 view, float freq, float strength) {
	float e = 0.5 / freq;
	float h0 = fbm3(wpos * freq);
	vec3 g = vec3(fbm3((wpos + vec3(e, 0, 0)) * freq) - h0,
	              fbm3((wpos + vec3(0, e, 0)) * freq) - h0,
	              fbm3((wpos + vec3(0, 0, e)) * freq) - h0) / e;
	g -= wnorm * dot(g, wnorm);
	vec3 gv = (view * vec4(g, 0.0)).xyz;
	return normalize(n_view - gv * strength / freq);
}
