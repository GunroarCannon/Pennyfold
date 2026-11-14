// A speech bubble drawn as one distance field: ink outline, a pale offset
// highlight like a cut-paper sticker, a soft drop shadow and a tail that
// blends in with smooth fillets.
// style 0 = round, 1 = shout (spiky), 2 = puffy thought, 3 = cut paper
// (chamfered corners, like a hand-cut comic bubble).
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform vec2 body_m = vec2(1.2, 0.5);
uniform float margin_m = 0.14;
uniform float tail_m = 0.24;
uniform vec4 fill : source_color = vec4(0.99, 0.98, 0.94, 1.0);
uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.07, 1.0);
uniform float line_m = 0.03;
uniform int style = 3;
uniform float tail_x = 0.0;
uniform float fade = 1.0;

void vertex() {
	MODELVIEW_MATRIX = fx_billboard(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

float sd_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a; vec2 e1 = c - b; vec2 e2 = a - c;
	vec2 v0 = p - a; vec2 v1 = p - b; vec2 v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
		vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
		vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

// A box with its four corners snipped at slightly different sizes.
float sd_cut_box(vec2 q, vec2 h, float cut, float r) {
	vec2 sg = sign(q + vec2(0.0001));
	float k = 1.0;
	vec2 a = abs(q);
	float box = max(a.x - (h.x - r), a.y - (h.y - r));
	float diag = (a.x + a.y - (h.x + h.y - cut * k - r * 1.4142)) * 0.7071;
	return max(box, diag) - r;
}

float shape(vec2 p) {
	vec2 hs = body_m * 0.5;
	vec2 c = vec2(0.0, tail_m * 0.5);
	vec2 q = p - c;
	float body;
	if (style == 1) {
		vec2 e = q / (hs * vec2(1.12, 1.38));
		float ang = atan(e.y, e.x);
		float tri = abs(fract(ang * 9.0 / 6.28318) - 0.5) * 2.0;
		body = (length(e) - (0.9 + 0.2 * tri)) * min(hs.x, hs.y);
	} else if (style == 2) {
		body = fx_sd_round_box(q, hs, min(hs.y, 0.22)) - (sin(q.x * 18.0) * 0.012 + sin(q.y * 22.0) * 0.01);
	} else if (style == 3) {
		body = sd_cut_box(q, hs, min(hs.y * 0.7, 0.2), 0.04);
	} else {
		body = fx_sd_round_box(q, hs, min(hs.y, 0.2));
	}
	// The tail's wide top sits well inside the body, so the body's ink line is
	// never cut across the tail's neck and no seam shows.
	float edge = c.y - hs.y;
	float tx = clamp(tail_x, -hs.x * 0.6, hs.x * 0.6);
	float tail = sd_tri(p, vec2(tx - 0.2, edge + 0.16), vec2(tx + 0.2, edge + 0.16), vec2(tx, edge - tail_m + 0.02));
	tail -= 0.02;
	return fx_smin(body, tail, style == 3 ? 0.03 : 0.08);
}

void fragment() {
	vec2 size = vec2(body_m.x + margin_m * 2.0, body_m.y + tail_m + margin_m * 2.0);
	vec2 p = (UV - 0.5) * size;
	p.y = -p.y;
	float d = shape(p);
	float aa = fwidth(d) * 1.2 + 0.002;
	float d_hi = shape(p - vec2(0.04, 0.045));
	float d_sh = shape(p + vec2(-0.03, 0.045));
	float shadow = smoothstep(0.05, -0.02, d_sh) * 0.3;
	float hi_a = smoothstep(aa, -aa, d_hi + line_m * 0.4);
	float outline = smoothstep(line_m + aa, line_m - aa, abs(d + line_m * 0.5));
	float inside = smoothstep(aa, -aa, d + line_m);
	float solid = max(inside, outline);
	vec3 c = mix(fill.rgb, ink.rgb, outline);
	// a faint lighter wash on the upper left, like paper catching the light
	c = mix(c, c * 1.12 + 0.03, inside * smoothstep(0.4, -0.4, p.x + p.y) * 0.4 * (1.0 - outline));
	vec3 out_col = mix(vec3(0.13, 0.09, 0.05), vec3(0.99, 0.98, 0.95), hi_a);
	out_col = mix(out_col, c, solid);
	float a = max(solid, max(hi_a, shadow));
	a *= fade;
	if (a < 0.01) discard;
	ALBEDO = out_col;
	ALPHA = a;
}
