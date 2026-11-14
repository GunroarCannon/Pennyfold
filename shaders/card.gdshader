// Building surfaces: a painted texture on paper grain, with a dithered
// fade so a house turns see-through when the player walks behind it.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform float fade = 1.0;
uniform bool cutout = false;

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

#include "res://shaders/bend.gdshaderinc"

void vertex() {
	VERTEX = bend_vertex(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec4 t = texture(tex, UV * uv_scale);
	if (cutout && t.a < 0.5) discard;
	if (fade < 0.999) {
		int ix = int(mod(FRAGCOORD.x, 4.0));
		int iy = int(mod(FRAGCOORD.y, 4.0));
		if (fade < (BAYER[iy * 4 + ix] + 0.5) / 16.0) discard;
	}
	float g = texture(grain, UV * uv_scale * 1.3).r;
	ALBEDO = t.rgb * tint.rgb * mix(0.88, 1.06, g);
	ROUGHNESS = 1.0;
}
