shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common.gdshaderinc"

void vertex() {
	COMMON_VERTEX
}

void fragment() {
	// Candle bodies glow just below the flame.
	float top = smoothstep(v_scale.y * 0.15, v_scale.y * 0.5, v_local.y);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.45;
	SSS_STRENGTH = 0.6;
	EMISSION = vec3(1.0, 0.55, 0.2) * top * 0.9;
}
