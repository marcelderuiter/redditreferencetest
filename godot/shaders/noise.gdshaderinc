// Shared procedural noise. Varyings are written in vertex() only; these
// helpers just compute values.

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float f2 = hash13(i + vec3(1.0, 0.0, 1.0));
	float g = hash13(i + vec3(0.0, 1.0, 1.0));
	float h = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, u.x), mix(c, d, u.x), u.y), mix(mix(e, f2, u.x), mix(g, h, u.x), u.y), u.z);
}

float fbm3(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec3(17.1, 3.3, 9.7);
		a *= 0.5;
	}
	return s / 0.875;
}

// Bump mapping from a scalar height without tangents (screen-space
// derivatives), in view space: pos = VERTEX, n = NORMAL.
vec3 bump_normal(vec3 pos, vec3 n, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - k * grad);
}

// Metric local position and half size of a scaled unit-cube instance.
#define LOCAL_SETUP(lp_out, half_out) \
	{ vec3 sc_ = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)); \
	  lp_out = VERTEX * sc_; half_out = sc_ * 0.5; }

// Rebuilds a vertex of a bevelled unit box (Kit.bevel_box) with a metric
// chamfer (m) that varies per corner by `chip` (0 = even; at 1 most corners
// worn, some knocked off deep, a few left sharp). v, n: VERTEX and NORMAL;
// sc: the instance scale; seed: per-instance random. The multimesh normal
// matrix is the instance basis (scale included), so n is pre-divided to come
// out at the bevel's metric angle.
void metric_bevel(inout vec3 v, inout vec3 n, vec3 sc, vec3 seed, float chamfer, float chip) {
	vec3 s = sign(v);
	vec3 inset = step(abs(v), vec3(0.475));
	float h1 = hash13(s * 5.31 + seed * 97.0);
	float h2 = hash13(s * 3.17 + seed.zxy * 61.0 + 4.0);
	float c = chamfer * (mix(1.0, mix(0.4, 1.2, h1) + step(0.82, h2) * 1.2, chip));
	c = min(c, 0.42 * min(sc.x, min(sc.y, sc.z)));
	v = s * (0.5 - inset * c / sc);
	n = n / sc;
}
