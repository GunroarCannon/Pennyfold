// A floating health bar: a rounded pill with an ink outline, a coloured fill
// that shifts from green to red, a pale trail that drains behind it, and a
// glossy highlight.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform vec2 size_m = vec2(0.86, 0.15);
uniform float value = 1.0;
uniform float trail = 1.0;
uniform vec4 back : source_color = vec4(0.25, 0.12, 0.08, 1.0);
uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.07, 1.0);
uniform float fade = 1.0;
uniform float hot = 0.0;

void vertex() {
	MODELVIEW_MATRIX = fx_billboard(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * size_m;
	float line = 0.016;
	float r = size_m.y * 0.5;
	float d = fx_sd_round_box(p, size_m * 0.5, r);
	float aa = fwidth(d) * 1.2 + 0.001;
	float outline = smoothstep(line + aa, line - aa, abs(d + line * 0.5));
	float inside = smoothstep(aa, -aa, d + line);
	float x = UV.x;
	float fillm = smoothstep(value + 0.004, value - 0.004, x);
	float trailm = smoothstep(trail + 0.004, trail - 0.004, x) * (1.0 - fillm);
	vec3 low = vec3(0.90, 0.25, 0.22);
	vec3 mid = vec3(0.96, 0.78, 0.25);
	vec3 high = vec3(0.45, 0.80, 0.34);
	vec3 fc = value > 0.5 ? mix(mid, high, (value - 0.5) * 2.0) : mix(low, mid, value * 2.0);
	fc = mix(fc, vec3(1.0), hot * 0.6);
	float gloss = smoothstep(0.0, 0.5, 0.5 - abs(UV.y - 0.28) * 1.6) * 0.35;
	vec3 c = back.rgb;
	c = mix(c, vec3(0.98, 0.9, 0.7), trailm * 0.85);
	c = mix(c, fc + gloss, fillm);
	c = mix(c, ink.rgb, outline);
	float a = max(inside, outline) * fade;
	if (a < 0.01) discard;
	ALBEDO = c;
	ALPHA = a;
}
