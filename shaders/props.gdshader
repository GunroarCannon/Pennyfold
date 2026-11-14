// Scattered nature cut-outs drawn with one MultiMesh per chunk.
// Each card turns to face the camera (around Y), sways in the wind, folds
// up from the ground like a pop-up book as the player comes near (and folds
// away again in the distance), and dithers out when it stands between the
// camera and the player so it never hides the hero.
// INSTANCE_CUSTOM: x = atlas cell u0, y = cell width (0..1), z = seed,
// w = chop shake (0..1).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 player_pos = vec3(0.0);
uniform vec3 cam_pos = vec3(0.0, 10.0, 10.0);
uniform float pop_near = 62.0;
uniform float pop_far = 78.0;
uniform float tint = 1.0;

#include "res://shaders/bend.gdshaderinc"

varying float v_vis;
varying vec2 v_grain;

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 fwd = cam_pos - origin;
	fwd.y = 0.0;
	fwd = normalize(fwd + vec3(0.0001, 0.0, 0.0));
	vec3 right = vec3(fwd.z, 0.0, -fwd.x);
	float d = distance(origin.xz, player_pos.xz);
	float pop = 1.0 - smoothstep(pop_near, pop_far, d);
	float ang = (1.0 - pop) * 1.55;
	vec3 up = vec3(0.0, cos(ang), 0.0) - fwd * sin(ang);
	float sway = sin(TIME * 1.6 + INSTANCE_CUSTOM.z * 40.0) * 0.06 * VERTEX.y
		+ sin(TIME * 52.0) * 0.16 * INSTANCE_CUSTOM.w * VERTEX.y;
	vec3 world = origin + right * (VERTEX.x + sway) * sx + up * VERTEX.y * sy;
	world.y -= bend_drop(world);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(fwd, 0.0)).xyz);
	UV = vec2(INSTANCE_CUSTOM.x + UV.x * INSTANCE_CUSTOM.y, UV.y);
	v_grain = world.xy * 0.4;
	// occlusion: props nearer to the camera than the player, close to the line of sight
	vec2 a = cam_pos.xz;
	vec2 b = player_pos.xz;
	vec2 ab = b - a;
	float t = clamp(dot(origin.xz - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
	float off = distance(origin.xz, a + ab * t);
	float occ = (t > 0.05 && t < 0.97) ? (1.0 - smoothstep(0.8, 4.6, off - sx * 0.3)) : 0.0;
	v_vis = 1.0 - occ * 0.5;
}

void fragment() {
	vec4 c = texture(atlas, UV);
	if (c.a < 0.5) discard;
	int ix = int(mod(FRAGCOORD.x, 4.0));
	int iy = int(mod(FRAGCOORD.y, 4.0));
	if (v_vis < (BAYER[iy * 4 + ix] + 0.5) / 16.0) discard;
	ALBEDO = c.rgb * tint;
	ROUGHNESS = 1.0;
}
