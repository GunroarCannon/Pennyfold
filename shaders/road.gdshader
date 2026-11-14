// Town roads drawn as ONE union of rounded strips and discs: ends are round,
// junction corners get smooth fillets, and no road's curb shows across
// another. A paper-cut curb runs along the edge. Surface styles: cobble,
// asphalt (lanes and pavements), sand, boards, trodden snow.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/fx_common.gdshaderinc"
#include "res://shaders/bend.gdshaderinc"

uniform vec4 rects[12];      // centre x, centre z, half width, half depth (metres)
uniform int rect_n = 0;
uniform vec4 discs[4];       // centre x, centre z, radius, unused
uniform int disc_n = 0;
uniform int mode = 0;        // 0 cobble, 1 asphalt, 2 sand, 3 boards, 4 snow
uniform float fillet = 0.5;
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 base_col : source_color = vec4(0.80, 0.76, 0.70, 1.0);
uniform vec4 curb_col : source_color = vec4(0.78, 0.62, 0.40, 1.0);
uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.07, 1.0);
uniform vec4 mark_col : source_color = vec4(0.95, 0.85, 0.40, 1.0);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX = bend_vertex(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec2 p = v_world.xz;
	float d = 1000.0;
	float lane = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= rect_n) break;
		vec4 r = rects[i];
		vec2 h = r.zw;
		float rd = fx_sd_round_box(p - r.xy, h, min(h.x, h.y));
		d = (d > 500.0) ? rd : fx_smin(d, rd, fillet);
		if (mode == 1 && rd < -0.3) {
			vec2 q = p - r.xy;
			float along = h.x > h.y ? q.x : q.y;
			float across = h.x > h.y ? q.y : q.x;
			lane = max(lane, step(abs(across), 0.035) * step(fract(along / 1.0), 0.55));
		}
	}
	for (int i = 0; i < 4; i++) {
		if (i >= disc_n) break;
		vec4 c = discs[i];
		float dd = length(p - c.xy) - c.z;
		d = (d > 500.0) ? dd : fx_smin(d, dd, fillet);
	}
	d += (fx_noise(p * 5.0) - 0.5) * 0.045;
	if (d > 0.0) discard;
	vec3 surf;
	float g = texture(grain, p * 0.5).r;
	if (mode == 0) {
		surf = texture(tex, p / 1.5).rgb * base_col.rgb;
	} else if (mode == 1) {
		surf = base_col.rgb * mix(0.85, 1.1, g);
		surf = mix(surf, mark_col.rgb, lane);
		if (d > -0.42 && d < -0.16) surf = base_col.rgb * 1.55;
	} else if (mode == 3) {
		float plank = fract(p.x * 1.4);
		surf = base_col.rgb * mix(0.8, 1.05, g) * (0.86 + 0.14 * smoothstep(0.0, 0.06, plank) * smoothstep(1.0, 0.94, plank));
	} else {
		surf = base_col.rgb * mix(0.86, 1.08, g);
		if (mode == 4) surf = mix(surf, vec3(0.95, 0.97, 1.0), 0.35 * fx_noise(p * 3.0));
	}
	// paper-cut curb: a darker lip, then an ink line right at the edge
	float lip = smoothstep(-0.2, -0.1, d);
	surf = mix(surf, curb_col.rgb, lip * 0.85);
	surf = mix(surf, ink.rgb, smoothstep(-0.05, -0.012, d));
	ALBEDO = surf;
	ROUGHNESS = 1.0;
}
