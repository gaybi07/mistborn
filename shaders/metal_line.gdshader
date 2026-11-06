shader_type spatial;
// Línea de acero/hierro como un hilo de bruma azul: suave en los bordes, con jirones que fluyen.
// UV.x = metros a lo largo de la línea, UV.y = 0..1 a lo ancho.
// UV2.x = velocidad de flujo (+ hacia el objetivo, - hacia ti), UV2.y = semilla por objeto.
// COLOR.rgb = color, COLOR.a = intensidad.
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform float brightness = 0.8;
uniform float core = 0.0;  // 1 = núcleo fino y brillante (objetivo)

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
	float across = UV.y * 2.0 - 1.0;
	float along = UV.x;
	float flow = UV2.x;
	float seed = UV2.y;

	float n1 = noise(vec2(along * 0.8 - TIME * flow, seed));
	float n2 = noise(vec2(along * 2.6 - TIME * flow * 1.6, seed * 1.7 + across * 1.5));
	// Jirones de bruma: más cortados y con una tercera capa fina que los deshilacha.
	float n3 = noise(vec2(along * 5.0 - TIME * flow * 2.3, seed * 2.9 + across * 3.0));
	float wisps = clamp(0.15 + n1 * 1.0 + (n2 - 0.5) * 0.9 + (n3 - 0.5) * 0.5, 0.0, 1.3);
	// El ancho también ondula, como humo; bordes muy suaves (difuminado).
	float width = 0.7 + 0.35 * n2;
	float soft = exp(-across * across * 2.6 / (width * width));
	float line_core = exp(-across * across * 90.0) * core * (0.55 + 0.45 * n1);
	// Nace disolviéndose: los primeros metros son casi bruma.
	float start_fade = smoothstep(0.0, 1.5, along);
	// Las cintas lentas (flujo bajo, tipo aurora) respiran suavemente; las rápidas (PNJ) no cambian.
	float calm = 1.0 - smoothstep(0.2, 0.5, abs(flow));
	float breathe = 1.0 - 0.2 * calm * (0.5 + 0.5 * sin(TIME * 0.8 + seed * 3.0 + along * 0.15));

	ALBEDO = COLOR.rgb * brightness * (1.0 + line_core * 0.9);
	ALPHA = clamp(COLOR.a * start_fade * breathe * (soft * wisps * 0.75 + line_core * 0.7), 0.0, 1.0);
}
