// An energy beam on a cylinder: rounded tapered ends, a soft glowing rim and
// bright core, with bands of light flowing along it.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, shadows_disabled;

uniform vec4 col : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform float height = 10.0;
uniform float fade = 1.0;
uniform float flow = 1.0;

varying float v_t;

void vertex() {
	float t = VERTEX.y / height + 0.5;
	v_t = t;
	float cap = pow(clamp(sin(clamp(t, 0.0, 1.0) * 3.14159), 0.0, 1.0), 0.28);
	float wob = 1.0 + 0.07 * sin(t * 40.0 - TIME * 30.0 * flow);
	VERTEX.xz *= cap * wob;
}

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float core = pow(facing, 2.6);
	float soft = pow(facing, 0.9);
	float band = 0.78 + 0.22 * sin(v_t * 55.0 - TIME * 36.0 * flow);
	vec3 c = mix(col.rgb, vec3(1.0), core * 0.9);
	ALBEDO = c * band;
	ALPHA = clamp(soft * (0.45 + core * 0.8) * fade, 0.0, 1.0);
}
