// Additive version of fx_sprite (sparks, glows, light).
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform int shape = 0;
uniform vec4 col : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float rot = 0.0;
uniform float aux = 0.12;

void vertex() {
	MODELVIEW_MATRIX = fx_billboard(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 p = fx_rot((UV - 0.5) * 2.0, rot);
	float a = fx_shape(shape, p, aux) * fade * col.a;
	if (a < 0.01) discard;
	ALBEDO = col.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
