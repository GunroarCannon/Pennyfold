// Ground effects: danger strips, area warnings, shockwave rings, cracks and
// scorch marks. All shapes are distance fields, so ends are round and edges
// soft. The mesh is built along the terrain (see fx.gd) and bent like it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"
#include "res://shaders/bend.gdshaderinc"

uniform int mode = 0;            // 0 strip, 1 ring, 2 area, 3 crack, 4 scorch
uniform vec4 col : source_color = vec4(1.0, 0.4, 0.2, 1.0);
uniform vec2 size_m = vec2(1.0, 1.0);
uniform float progress = 0.0;    // charge 0..1 (strip, area) or ring radius 0..1
uniform float fade = 1.0;
uniform float thick = 0.12;
uniform float seed = 0.0;

void vertex() {
	VERTEX = bend_vertex(VERTEX, MODEL_MATRIX);
}

void fragment() {
	float alpha = 0.0;
	vec3 c = col.rgb;
	if (mode == 0) {
		vec2 p = (UV - 0.5) * size_m;
		float hl = size_m.y * 0.5;
		float hw = size_m.x * 0.5;
		vec2 q = vec2(p.x, p.y - clamp(p.y, -(hl - hw), hl - hw));
		float d = length(q) - hw;
		float inside = smoothstep(0.02, -0.04, d);
		float edge = smoothstep(-0.16, -0.04, d) * inside;
		float chev = fract((UV.y * size_m.y - abs(p.x) * 1.3) * 0.9 - TIME * 1.6);
		float stripes = smoothstep(0.25, 0.45, chev) * smoothstep(0.85, 0.65, chev);
		float filled = smoothstep(progress + 0.02, progress - 0.02, UV.y);
		float pulse = 0.82 + 0.18 * sin(TIME * 14.0);
		alpha = inside * (0.16 + 0.2 * stripes) + inside * filled * 0.34 * pulse + edge * 0.5;
		alpha += exp(-max(d, 0.0) * 14.0) * 0.28 * (1.0 - inside);
		c = mix(col.rgb, vec3(1.0, 0.95, 0.8), filled * 0.35 + edge * 0.25);
	} else if (mode == 1) {
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		float a = atan(p.y, p.x);
		float wob = fx_noise(vec2(a * 3.0 + seed, seed)) * 0.05;
		float rr = progress;
		float d = abs(r - rr - wob);
		float w = thick * (1.0 - 0.6 * progress) + 0.015;
		float ring = smoothstep(w, w * 0.2, d);
		float inner = smoothstep(rr, rr * 0.4, r) * (1.0 - progress) * 0.35;
		alpha = (ring + inner) * step(r, 1.0);
		c = mix(col.rgb, vec3(1.0), ring * 0.45);
	} else if (mode == 2) {
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		float rim = smoothstep(0.06, 0.0, abs(r - 0.97));
		float fillr = smoothstep(progress + 0.02, progress - 0.02, r);
		float hazard = smoothstep(0.35, 0.5, fract((p.x + p.y) * 4.0 - TIME * 0.8));
		float base = step(r, 0.97) * (0.12 + 0.1 * hazard);
		float pulse = 0.85 + 0.15 * sin(TIME * 16.0);
		alpha = base + step(r, 0.97) * fillr * 0.38 * pulse + rim * 0.7;
		c = mix(col.rgb, vec3(1.0, 0.92, 0.75), fillr * 0.3 + rim * 0.3);
	} else if (mode == 3) {
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		float a = atan(p.y, p.x);
		float n = 9.0;
		float seg = floor((a + 3.14159) / 6.28318 * n);
		float f = fract((a + 3.14159) / 6.28318 * n) - 0.5;
		float len = 0.45 + 0.55 * fx_hash(vec2(seg, seed));
		float jag = (fx_noise(vec2(r * 14.0, seg + seed)) - 0.5) * 0.35;
		float line = smoothstep(0.07 * (1.1 - r), 0.0, abs(f + jag * (1.0 - r))) ;
		alpha = line * step(r, len) * step(0.08, r) * smoothstep(1.0, 0.7, r / len + 0.0);
		alpha += smoothstep(0.16, 0.0, r) * 0.6;
		c = col.rgb;
	} else {
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p) + (fx_noise(p * 4.0 + seed) - 0.5) * 0.3;
		alpha = smoothstep(1.0, 0.3, r) * 0.7;
		c = col.rgb;
	}
	alpha *= fade * col.a;
	if (alpha < 0.01) discard;
	ALBEDO = c;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
