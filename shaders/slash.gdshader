// A weapon slash: a pointed crescent that sweeps along an arc, white-hot in
// the middle with a coloured rim and a fading tail. progress 0..1 sweeps
// the head along the arc, fade dims everything afterwards.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform vec4 col : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float span = 2.7;
uniform float center_ang = 0.6;
uniform float thick = 0.30;
uniform float flip = 1.0;
uniform float seed = 0.0;
uniform float radius = 0.66;

void vertex() {
	MODELVIEW_MATRIX = fx_billboard(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	p.x *= flip;
	float r = length(p);
	float a = atan(p.y, p.x);
	float da = a - center_ang;
	da = atan(sin(da), cos(da));
	float s = da / (span * 0.5);
	if (abs(s) >= 1.0) discard;
	float u = 0.5 - s * 0.5; // 0 where the swing starts, 1 where it ends
	float head = progress * 1.25;
	float age = head - u;
	if (age < 0.0) discard;
	float bright = clamp(1.0 - age * 1.7, 0.0, 1.0);
	float w = thick * pow(1.0 - s * s, 0.75) * (0.3 + 0.7 * bright);
	float R = radius + 0.10 * (u - 0.5);
	float d = (r - R) / max(w, 0.001);
	float ad = abs(d);
	float body = 1.0 - smoothstep(0.55, 1.0, ad);
	float core = 1.0 - smoothstep(0.0, 0.5, ad);
	float glow = exp(-ad * 1.5) * 0.35;
	float streak = 0.88 + 0.12 * sin(a * 46.0 + seed * 9.0);
	vec3 c = mix(rim_col.rgb, col.rgb, core);
	float alpha = clamp((body * streak + glow) * bright * fade, 0.0, 1.0);
	if (alpha < 0.02) discard;
	ALBEDO = c;
	ALPHA = alpha;
}
