shader_type spatial;
render_mode cull_disabled;
// Tiras de la capa de bruma (Mistcloak): tela fina con trama, bordes deshilachados y la punta
// desgarrada en zigzag, cada vez más clara hacia la punta (se deshace en bruma). La luz la atraviesa
// un poco (BACKLIGHT). UV: x a lo ancho de la tira, y de arriba (0) a la punta (1); UV2.x: azar por tira.

uniform vec3 base_color : source_color = vec3(0.1, 0.105, 0.12);
uniform vec3 mist_color : source_color = vec3(0.3, 0.32, 0.36);

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

void fragment() {
	float seed = UV2.x;
	float v = UV.y;
	float edge = abs(UV.x * 2.0 - 1.0);
	// Punta desgarrada: corte irregular en zigzag.
	float jag = noise(vec2(UV.x * 6.0, seed * 31.0)) * 0.13 + noise(vec2(UV.x * 21.0, seed * 7.0)) * 0.05;
	// Bordes deshilachados, más hacia la punta (cada borde con su propio ruido).
	float fray = noise(vec2(v * 38.0, seed * 13.0 + step(0.5, UV.x) * 5.0)) * (0.03 + 0.22 * v * v);
	float keep = step(v, 1.0 - jag) * step(edge, 1.0 - fray);
	// Algún desgarro suelto en la mitad de abajo.
	float hole = step(0.9 - 0.1 * v, noise(vec2(UV.x * 9.0 + seed * 3.0, v * 14.0))) * step(0.45, v);
	ALPHA = keep * (1.0 - hole);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	float weave = 0.93 + 0.07 * sin(UV.x * 120.0) * sin(v * 260.0);
	float blot = noise(vec2(UV.x * 3.0 + seed * 10.0, v * 5.0));
	vec3 c = mix(base_color, mist_color, smoothstep(0.35, 1.0, v) * 0.55);
	c *= (0.82 + 0.36 * blot) * weave * (0.9 + 0.2 * seed);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// Pliegues a lo largo de la tira (dos ondas que se cruzan) y la trama en relieve.
	float fold = sin(UV.x * 9.4 + seed * 6.0 + v * 2.5) * 0.6 + sin(UV.x * 21.0 - v * 4.0 + seed * 3.0) * 0.25;
	float thread = sin(v * 260.0) * 0.06;
	NORMAL_MAP = normalize(vec3(fold * 0.45, thread, 1.0)) * 0.5 + 0.5;
	BACKLIGHT = c * 0.7;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
