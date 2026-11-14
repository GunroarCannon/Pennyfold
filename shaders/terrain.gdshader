// Open-world ground: vertex colours (grass, paths, sand, rock, fields) on a
// paper grain, with thin contour lines so the hills read like stacked
// sheets of cardboard in a topographic model.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
uniform float contour = 1.1;
uniform float line_dark = 0.78;

#include "res://shaders/bend.gdshaderinc"

varying float h;

void vertex() {
	h = VERTEX.y;
	VERTEX = bend_vertex(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float g = texture(grain, UV).r;
	col *= mix(0.86, 1.07, g);
	float k = h / contour + 0.5;
	float f = fract(k);
	float d = min(f, 1.0 - f) / max(fwidth(k), 0.0001);
	col *= mix(line_dark, 1.0, smoothstep(0.6, 1.6, d));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
