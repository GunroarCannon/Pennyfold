// A camera-facing effect sprite drawn from a distance field: glow, streak,
// sparkle, ring or light pillar. No textures, so edges are always smooth.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

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
	ALBEDO = mix(col.rgb, vec3(1.0), clamp(a - 0.6, 0.0, 1.0) * 0.8);
	ALPHA = clamp(a, 0.0, 1.0);
}
