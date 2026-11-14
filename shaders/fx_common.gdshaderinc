// Shared helpers for the effect shaders.

// A camera-facing model-view matrix that keeps the node's scale (the same
// maths StandardMaterial3D uses for billboards).
mat4 fx_billboard(mat4 view, mat4 inv_view, mat4 model) {
	mat4 mv = view * mat4(inv_view[0], inv_view[1], inv_view[2], model[3]);
	return mv * mat4(
		vec4(length(model[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(model[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(model[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

float fx_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float fx_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fx_hash(i);
	float b = fx_hash(i + vec2(1.0, 0.0));
	float c = fx_hash(i + vec2(0.0, 1.0));
	float d = fx_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 fx_rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Signed distance to a rounded box (negative inside).
float fx_sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Smooth minimum: blends two shapes so joins get rounded fillets.
float fx_smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}

// Shapes for the little billboard sprites. p is -1..1.
float fx_shape(int s, vec2 p, float aux) {
	float r = length(p);
	if (s == 0) {
		return pow(clamp(1.0 - r, 0.0, 1.0), 2.0);
	}
	if (s == 1) {
		float t = abs(p.x);
		float w = 0.11 * (1.0 - t) + 0.004;
		return smoothstep(w, w * 0.15, abs(p.y)) * (1.0 - t) * step(t, 1.0);
	}
	if (s == 2) {
		float k = clamp(1.0 - r, 0.0, 1.0);
		float cross_a = exp(-abs(p.x) * 20.0) * (1.0 - abs(p.y)) + exp(-abs(p.y) * 20.0) * (1.0 - abs(p.x));
		return clamp(cross_a * k + pow(k, 3.0) * 0.8, 0.0, 1.0);
	}
	if (s == 3) {
		float d = abs(r - 0.82);
		return smoothstep(aux, aux * 0.15, d) * step(r, 1.0);
	}
	if (s == 4) {
		return smoothstep(1.0, 0.78, r);
	}
	if (s == 5) {
		// vertical light pillar: soft sides, bright core, fades at the top
		float x = abs(p.x);
		float top = clamp(1.0 - (p.y * 0.5 + 0.5), 0.0, 1.0);
		return smoothstep(1.0, 0.0, x) * pow(top, 0.7) * 0.9;
	}
	return 0.0;
}
