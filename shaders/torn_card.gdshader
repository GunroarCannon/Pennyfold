// Gives a full-screen cardboard card ragged torn edges (bottom heavily, sides
// lightly) with pale fibres, so it peels away like paper instead of sliding
// off as a clean rectangle.
shader_type canvas_item;

uniform vec2 size = vec2(1280.0, 720.0);
uniform float tear = 1.0;

varying vec2 lp;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float amp = 38.0 * tear;
	float by = size.y - 28.0 * tear - amp * (vn(vec2(lp.x * 0.02, 1.0)) * 0.7 + vn(vec2(lp.x * 0.11, 5.0)) * 0.3);
	float dy = by - lp.y;
	float sx = 12.0 * tear * vn(vec2(lp.y * 0.05, 7.0));
	float dl = lp.x - sx;
	float dr = size.x - sx - lp.x;
	float d = min(dy, min(dl, dr));
	if (d < -6.0) discard;
	vec4 c = COLOR;
	float fibre = smoothstep(16.0, 0.0, d);
	c.rgb = mix(c.rgb, vec3(0.92, 0.82, 0.64), fibre * (0.45 + 0.55 * vn(lp * 0.7)));
	c.rgb = mix(c.rgb, vec3(0.17, 0.11, 0.07), smoothstep(2.5, 0.0, abs(d - 1.0)) * 0.55);
	c.a *= smoothstep(-6.0, -2.0, d);
	COLOR = c;
}
