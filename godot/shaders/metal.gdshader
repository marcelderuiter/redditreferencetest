// Bronze / brass fittings, iron rails and armour: metallic with tarnish.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.55, 0.42, 0.22);
uniform float metallic_v = 0.85;
uniform float roughness_v = 0.42;
uniform float tarnish = 0.45;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fbm3(wpos * 6.0);
	vec3 c = albedo * COLOR.rgb;
	c = mix(c, c * vec3(0.35, 0.3, 0.25), tarnish * smoothstep(0.35, 0.75, n));
	ALBEDO = c;
	METALLIC = metallic_v;
	ROUGHNESS = roughness_v + 0.3 * n;
}
