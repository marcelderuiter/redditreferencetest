// Shared procedural material for every batch. Per-instance colour arrives in COLOR.
// mode: 0 carved block, 1 coursed masonry, 2 wood, 3 metal, 4 carpet, 5 plain, 6 glow
shader_type spatial;
render_mode cull_back;

uniform int mode = 0;
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform float edge_light = 0.5;
uniform float edge_width = 0.05;
uniform float grit = 0.3;
uniform float grit_scale = 5.0;
uniform float top_light = 0.1;
uniform vec2 brick = vec2(0.62, 0.32);
uniform float glow = 0.0;
uniform float bump = 0.25;

varying vec3 lp;
varying vec3 wp;
varying vec3 sc;
varying vec3 wn;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float n = fbm(wp * grit_scale);
	float fine = vnoise(wp * grit_scale * 5.0);
	// Distance to the nearest box edge in world units (meaningful for box meshes).
	vec3 d = (vec3(0.5) - abs(lp)) * sc;
	float e2 = d.x + d.y + d.z - max(d.x, max(d.y, d.z)) - min(d.x, min(d.y, d.z));
	float edge = 1.0 - smoothstep(0.0, edge_width, e2 + (n - 0.5) * edge_width * 0.9);
	float cav = 0.0;

	if (mode == 1) {
		vec3 an = abs(wn);
		vec2 uv;
		if (an.y > an.x && an.y > an.z) {
			uv = wp.xz;
		} else if (an.x > an.z) {
			uv = vec2(wp.z, wp.y);
		} else {
			uv = vec2(wp.x, wp.y);
		}
		vec2 bu = uv / brick;
		float row = floor(bu.y);
		bu.x += mod(row, 2.0) * 0.5 + hash(vec3(row, 3.0, 7.0)) * 0.35;
		vec2 id = floor(bu);
		vec2 f = fract(bu);
		vec2 fe = min(f, 1.0 - f) * brick;
		float m = min(fe.x, fe.y) + (n - 0.5) * 0.035;
		float mortar = 1.0 - smoothstep(0.012, 0.04, m);
		float h = hash(vec3(id, row * 1.7 + 11.0));
		base *= mix(0.72, 1.22, h);
		edge = max(edge, smoothstep(0.075, 0.035, m) * (1.0 - mortar));
		cav = mortar;
	} else if (mode == 2) {
		vec3 g;
		if (sc.x >= sc.y && sc.x >= sc.z) {
			g = vec3(lp.x * sc.x * 0.7, lp.y * sc.y * 16.0, lp.z * sc.z * 16.0);
		} else if (sc.y >= sc.z) {
			g = vec3(lp.x * sc.x * 16.0, lp.y * sc.y * 0.7, lp.z * sc.z * 16.0);
		} else {
			g = vec3(lp.x * sc.x * 16.0, lp.y * sc.y * 16.0, lp.z * sc.z * 0.7);
		}
		float grain = fbm(g + wp * 0.3);
		base *= 0.65 + 0.7 * grain;
	} else if (mode == 4) {
		vec2 q = lp.xz;
		vec2 s = sc.xz;
		vec2 dd = (vec2(0.5) - abs(q)) * s;
		float border = 1.0 - step(0.16, min(dd.x, dd.y));
		float line = 1.0 - smoothstep(0.0, 0.03, abs(min(dd.x, dd.y) - 0.24));
		vec2 c = q * s;
		float dia = abs(fract(c.x * 0.9) - 0.5) + abs(fract(c.y * 0.9) - 0.5);
		float motif = smoothstep(0.08, 0.02, abs(dia - 0.3));
		vec3 gold = vec3(0.55, 0.36, 0.16);
		base = mix(base, gold, max(border * 0.85, max(line, motif * 0.45)));
		base *= 0.8 + 0.35 * n;
		edge = 0.0;
	}

	float lit = (0.78 + 0.44 * n) * (0.8 + 0.4 * fine);
	vec3 col = base * lit;
	col *= 1.0 + edge * edge_light;
	col = mix(col, col * 0.22, cav);
	col += base * top_light * max(wn.y, 0.0);
	col *= 1.0 - grit * (1.0 - smoothstep(0.25, 0.45, n));
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = clamp(rough + (fine - 0.5) * 0.2, 0.05, 1.0);
	METALLIC = metal;
	// Small pitting bump from noise (view space).
	vec3 gx = vec3(vnoise(wp * grit_scale * 3.0 + vec3(0.05, 0, 0)), vnoise(wp * grit_scale * 3.0 + vec3(0, 0.05, 0)), vnoise(wp * grit_scale * 3.0 + vec3(0, 0, 0.05))) - vnoise(wp * grit_scale * 3.0);
	NORMAL = normalize(NORMAL - (VIEW_MATRIX * vec4(gx * bump * 8.0, 0.0)).xyz);
	if (mode == 6) {
		EMISSION = base * glow * (0.7 + 0.6 * n);
	}
}
