shader_type spatial;
// Onda en el aire: un frente que deforma lo que hay detrás, como el calor o una onda de choque, con un velo de bruma.
// Quad en el plano XY de cuerpo entero (UV 0..1). Sirve de frente a la cámara, en el piso o mirando hacia donde va.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float progress = 0.5;  // radio del frente: 0 centro, 1 borde
uniform float fade = 1.0;
uniform float strength = 0.03;  // cuánto corre la imagen, en fracción de pantalla
uniform float band = 0.1;  // ancho del frente
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.2);  // color y densidad de la bruma que arrastra
uniform float seed = 0.0;

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
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = fbm(p * 3.0 + seed + TIME * 0.35);
	// El frente no es un círculo perfecto: ondula como el aire.
	float d = (r - progress - (n - 0.5) * 0.22) / band;
	// Un frente roto: hay tramos donde casi no se nota, para que no se lea como un aro dibujado.
	float broken = smoothstep(0.2, 0.62, fbm(p * 2.2 + seed * 1.3 - TIME * 0.2));
	float crest = exp(-d * d) * mix(0.2, 1.0, broken);
	float edge = smoothstep(1.0, 0.8, r) * smoothstep(0.0, 0.08, r);
	float k = fade * edge;
	// Se apaga pegado a la cámara, visto de canto y donde toca algo: sin líneas duras ni pantalla tapada.
	float dist = -VERTEX.z;
	k *= smoothstep(1.5, 5.0, dist) * smoothstep(0.06, 0.4, abs(dot(NORMAL, VIEW)));
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).x;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	k *= clamp((VERTEX.z - behind.z) / 0.6, 0.0, 1.0);

	vec3 local_dir = vec3(p.x, -p.y, 0.0) / max(r, 0.001);
	vec2 screen_dir = (VIEW_MATRIX * MODEL_MATRIX * vec4(local_dir, 0.0)).xy;
	screen_dir /= max(length(screen_dir), 0.15);
	// Una lente: empuja de un lado del frente y tira del otro.
	vec2 offset = screen_dir * vec2(1.0, -1.0) * d * crest * strength * k * 1.6 * min(6.0 / max(dist, 1.0), 1.0);
	vec3 bg = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;

	float veil = crest * tint.a * k * smoothstep(0.35, 0.8, n) * 0.35;
	ALBEDO = mix(bg, tint.rgb, veil);
	ALPHA = clamp(crest * k * 3.0, 0.0, 1.0);
}
