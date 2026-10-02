shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float energy = 5.0;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float t = TIME * 9.0 + o.x * 13.1 + o.z * 7.7;
	float k = VERTEX.y + 0.5;
	VERTEX.x += sin(t) * 0.12 * k;
	VERTEX.z += cos(t * 1.37) * 0.12 * k;
	VERTEX.y *= 1.0 + 0.12 * sin(t * 0.7);
}

void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
