// Lake water: painted blue sheet with drifting wave strokes.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec4 deep : source_color = vec4(0.36, 0.62, 0.86, 1.0);
uniform vec4 light : source_color = vec4(0.82, 0.93, 0.99, 1.0);
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;

#include "res://shaders/bend.gdshaderinc"

void vertex() {
	VERTEX = bend_vertex(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec2 w = UV * 9.0;
	float wave = sin(w.x * 3.0 + sin(w.y * 1.7 + TIME * 0.8) * 2.0 + TIME * 1.2);
	float stroke = smoothstep(0.93, 0.99, wave) * step(0.5, fract(w.y * 0.5 + 0.25));
	vec3 col = mix(deep.rgb, light.rgb, stroke * 0.8);
	col *= mix(0.9, 1.05, texture(grain, UV * 4.0).r);
	ALBEDO = col;
	ROUGHNESS = 0.6;
	ALPHA = 0.9;
}
