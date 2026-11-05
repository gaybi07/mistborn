shader_type spatial;
// Jirón de bruma: una mancha sin bordes hecha de ruido, que se deshace de a poco. Mira siempre a la cámara.
// Sirve en un quad suelto y en partículas (COLOR.a viene de su curva de vida).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 tint = vec4(0.7, 0.75, 0.85, 0.3);
uniform float dissolve = 0.0;  // 0 entero, 1 ya no está
uniform float seed = 0.0;
uniform float soft_distance = 0.6;  // metros en los que se funde con lo que toca

varying float instance_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.03 + 1.7) * 0.28 + noise(p * 4.1 + 5.3) * 0.15 + noise(p * 8.2 + 9.2) * 0.07;
}

void vertex() {
	instance_seed = seed + float(INSTANCE_ID) * 7.3;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME * 0.22;
	vec2 warp = vec2(fbm(p * 1.4 + instance_seed + t), fbm(p * 1.4 + instance_seed + 4.1 - t));
	float n = fbm(p * 1.6 + warp * 1.7 + instance_seed);
	// Sin círculo a la vista: el ruido se come el borde.
	float shape = smoothstep(1.0, 0.1, length(p) + (n - 0.5) * 1.1);
	float body = smoothstep(dissolve * 0.9 - 0.05, dissolve * 0.9 + 0.35, n) * shape;

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / soft_distance, 0.0, 1.0);
	soft *= smoothstep(1.5, 5.0, -VERTEX.z);  // nunca tapa la cámara

	ALBEDO = tint.rgb * (0.85 + n * 0.3);
	ALPHA = clamp(body * tint.a * COLOR.a * soft, 0.0, 1.0);
}
