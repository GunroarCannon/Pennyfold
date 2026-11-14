// Rolling-log world curve, shared by every bent material (see scripts/bend.gd).
global uniform vec3 bend_origin;
global uniform vec2 bend_fwd;
global uniform float bend_k;
global uniform float bend_ks;

float bend_drop(vec3 w) {
	vec2 d = w.xz - bend_origin.xz;
	float a = dot(d, bend_fwd);
	float s = d.x * bend_fwd.y - d.y * bend_fwd.x;
	float a_drop = (a > 0.0) ? (a * a) : (a * a * 0.35);
	return bend_k * a_drop + bend_ks * s * s;
}

// Lowers a model-space vertex by the curve at its world position.
vec3 bend_vertex(vec3 v, mat4 model) {
	vec3 w = (model * vec4(v, 1.0)).xyz;
	w.y -= bend_drop(w);
	return (inverse(model) * vec4(w, 1.0)).xyz;
}
