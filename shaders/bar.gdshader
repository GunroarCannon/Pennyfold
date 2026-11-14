// A cardboard health tag: a torn kraft strip with a hand-inked outline. The
// fill is a marker stripe (green -> ochre -> red) with a ragged cut end, and a
// paler scrap drains behind it when you are hit.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform vec2 size_m = vec2(0.86, 0.15);
uniform float value = 1.0;
uniform float trail = 1.0;
uniform vec4 back : source_color = vec4(0.62, 0.45, 0.28, 1.0);
uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.07, 1.0);
uniform float fade = 1.0;
uniform float hot = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	MODELVIEW_MATRIX = fx_billboard(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * size_m;
	vec2 hs = size_m * 0.5;
	// torn, slightly wobbly rectangle
	float wob = (vn(UV * vec2(18.0, 5.0)) - 0.5) * 0.03 + (vn(UV * vec2(60.0, 14.0)) - 0.5) * 0.012;
	vec2 q = abs(p) - hs + vec2(0.012);
	float d = max(q.x, q.y) + wob;
	float aa = fwidth(d) * 1.2 + 0.0006;
	float inside = smoothstep(aa, -aa, d);
	float edge = smoothstep(0.020 + aa, 0.020 - aa, -d) * inside;
	float x = UV.x;
	// ragged cut at the end of the fill
	float cut = (vn(vec2(UV.y * 9.0, value * 7.0)) - 0.5) * 0.05;
	float fillm = smoothstep(value + cut + 0.004, value + cut - 0.004, x);
	float trailm = smoothstep(trail + 0.004, trail - 0.004, x) * (1.0 - fillm);
	vec3 low = vec3(0.80, 0.22, 0.18);
	vec3 mid = vec3(0.90, 0.62, 0.20);
	vec3 high = vec3(0.42, 0.66, 0.30);
	vec3 fc = value > 0.5 ? mix(mid, high, (value - 0.5) * 2.0) : mix(low, mid, value * 2.0);
	fc = mix(fc, vec3(1.0), hot * 0.6);
	// marker streaks and paper grain
	float streak = vn(vec2(UV.x * 40.0, UV.y * 3.0)) * 0.12;
	float grain = vn(UV * vec2(90.0, 30.0)) * 0.10;
	vec3 c = back.rgb * (0.9 + grain);
	// inner well, inset from the edge
	float well = smoothstep(0.0, -0.01, d + 0.03);
	c = mix(c, vec3(0.30, 0.20, 0.12), well * 0.9);
	c = mix(c, vec3(0.93, 0.82, 0.60), trailm * well);
	c = mix(c, (fc - streak) , fillm * well);
	c = mix(c, ink.rgb, edge);
	float a = inside * fade;
	if (a < 0.01) discard;
	ALBEDO = c;
	ALPHA = a;
}
