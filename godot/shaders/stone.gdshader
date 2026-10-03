// Weathered stone for blocks, flagstones and pillars.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.46, 0.41, 0.385);
uniform float roughness_v = 0.9;
uniform float bump = 1.0;
uniform float wear = 0.4;
// Faces below the floors sit in the shadow of the rooms above: sky light
// can't reach them, so darken with depth (fog lightens them again further down).
uniform float under_top = -1.6;
uniform float under_bottom = -8.0;
uniform float under_min = 0.75;
// Fine grain and pitting (1 = full); distant masonry uses less so it
// doesn't sparkle with sub-pixel noise.
uniform float detail = 1.0;
// Direction the sun travels (World.SUN_DIR): lit rims only where it reaches.
uniform vec3 sun_dir = vec3(0.35, -0.92, 0.12);
// Below the floors the sun never reaches; World's pier key (this direction)
// lights the faces there instead, so rims follow it.
uniform vec3 under_key_dir = vec3(0.5, -0.45, -0.74);
// Metric chamfer (m) for bevelled boxes, rebuilt here so it keeps its size on
// any block (0 = take the mesh as it is). Each corner gets its own amount:
// most are worn, some knocked off deep, a few left sharp.
uniform float chamfer = 0.0;
uniform float chip = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 inst;
varying vec3 lp;
varying vec3 halfsize;

void vertex() {
	if (chamfer > 0.0) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		vec3 s = sign(VERTEX);
		vec3 inset = step(abs(VERTEX), vec3(0.475));
		float h1 = hash13(s * 5.31 + INSTANCE_CUSTOM.xyz * 97.0);
		float h2 = hash13(s * 3.17 + INSTANCE_CUSTOM.zxy * 61.0 + 4.0);
		float c = chamfer * (mix(1.0, mix(0.4, 1.2, h1) + step(0.82, h2) * 1.2, chip));
		c = min(c, 0.42 * min(sc.x, min(sc.y, sc.z)));
		VERTEX = s * (0.5 - inset * c / sc);
		// The multimesh normal matrix is the instance basis (scale included):
		// pre-divide so the bevel normals come out at their metric angles.
		NORMAL = NORMAL / sc;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	inst = INSTANCE_CUSTOM;
	LOCAL_SETUP(lp, halfsize);
}

void fragment() {
	vec3 p = wpos + inst.xyz * 13.0;
	float big = fbm3(p * 1.6);
	float fine = mix(0.5, vnoise(p * 8.0), detail);
	float grain = mix(0.5, vnoise(p * 27.0), detail);
	vec3 col = base_color * COLOR.rgb;
	col *= 0.7 + 0.6 * big;
	col *= 0.8 + 0.4 * grain;
	// Hairline cracks.
	float crack = smoothstep(0.035, 0.0, abs(vnoise(p * 3.1) - 0.5)) * smoothstep(0.45, 0.7, vnoise(p * 1.3 + 7.0));
	col *= 1.0 - 0.6 * crack;
	float stain = smoothstep(0.55, 0.85, fbm3(p * 0.5 + 3.0));
	col = mix(col, col * vec3(0.55, 0.5, 0.46), stain * 0.65);
	float pit = smoothstep(0.30, 0.16, fine);
	col *= 1.0 - 0.3 * pit;
	// Distance to the block's nearest edge on this face: worn, lighter rims.
	vec3 e = halfsize - abs(lp);
	vec3 an = abs(normalize(lp / max(halfsize, vec3(0.001))));
	float edge_d = (an.x > an.y && an.x > an.z) ? min(e.y, e.z) : ((an.y > an.z) ? min(e.x, e.z) : min(e.x, e.y));
	float rim = 1.0 - smoothstep(0.0, 0.05, edge_d);
	// Rims catch the light where the sun reaches them (worn flagstone edges a
	// little less than block arrises): faces turned to it, above the floors
	// (below them the rooms shade everything), so shadowed masonry gets no
	// bright outlines.
	// On side faces the joints sink into shadow, so each block reads as a
	// lit top over a dark drop.
	float block = mix(0.6, 1.0, smoothstep(0.06, 0.12, halfsize.y));
	float top_face = smoothstep(0.6, 0.9, wnrm.y);
	float side = 1.0 - smoothstep(0.3, 0.7, abs(wnrm.y));
	float under = smoothstep(under_top, under_bottom, wpos.y);
	float sunlit = mix(clamp(dot(wnrm, -normalize(sun_dir)) * 2.0, 0.0, 1.0),
		clamp(dot(wnrm, -normalize(under_key_dir)) * 2.0, 0.0, 1.0), under);
	col *= 1.0 + rim * (0.06 + (0.12 + 0.3 * top_face * block) * sunlit) * (0.5 + big);
	col *= 1.0 - 0.38 * (1.0 - smoothstep(0.0, 0.08, edge_d)) * side;
	float up = clamp(wnrm.y, 0.0, 1.0);
	col = mix(col, col * vec3(1.1, 1.05, 0.98), up * wear);
	col *= mix(0.8, 1.0, clamp(wnrm.y + 1.0, 0.0, 1.0));
	col *= mix(1.0, under_min, under);
	ALBEDO = col;
	ROUGHNESS = roughness_v - rim * 0.1;
	SPECULAR = 0.35;
	float h = big * 0.04 + fine * 0.016 - pit * 0.03 + grain * 0.009 - rim * 0.012 - crack * 0.02;
	NORMAL = bump_normal(VERTEX, NORMAL, h, bump);
}
