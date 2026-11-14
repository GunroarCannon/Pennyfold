// A torn cardboard flap for screen transitions: kraft colour, corrugation
// lines, crumple shading and a ragged, fibrous tear along the inner edge.
shader_type canvas_item;

uniform float side = 1.0;      // +1: tear on the right edge, -1: on the left
uniform vec4 kraft : source_color = vec4(0.60, 0.43, 0.26, 1.0);
uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.07, 1.0);
uniform vec2 px = vec2(800.0, 600.0);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * px;
	// distance from the tear edge in pixels (positive inside the flap)
	float from_edge = side > 0.0 ? (px.x - p.x) : p.x;
	float tear = 26.0 * (vn(vec2(p.y * 0.035, 3.0)) - 0.5) + 12.0 * (vn(vec2(p.y * 0.13, 9.0)) - 0.5) + 4.0 * (vn(vec2(p.y * 0.5, 1.0)) - 0.5);
	float d = from_edge - 30.0 - tear;
	if (d < -10.0) discard;
	float a = smoothstep(-10.0, -6.0, d);
	// pale torn paper fibres right at the edge, then the cardboard face
	vec3 c = kraft.rgb;
	float grain = vn(p * 0.35) * 0.12 + vn(p * 0.05) * 0.10;
	c *= 0.92 + grain;
	float flute = 0.5 + 0.5 * sin(p.y * 0.55);
	c *= 0.96 + flute * 0.05;
	float crease = smoothstep(0.02, 0.0, abs(vn(p * 0.012) - 0.5)) * 0.18;
	c *= 1.0 - crease;
	float fibre = smoothstep(14.0, 0.0, d + 8.0);
	c = mix(c, vec3(0.90, 0.80, 0.62), fibre * (0.5 + 0.5 * vn(p * 0.8)));
	float rim = smoothstep(3.0, 0.0, d + 5.0) ;
	c = mix(c, ink.rgb, rim * 0.5);
	COLOR = vec4(c, a);
}
