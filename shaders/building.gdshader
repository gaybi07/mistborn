shader_type spatial;
// Fachadas procedurales en coordenadas de mundo: sillares de piedra, manchas de hollín
// y ventanas (algunas encendidas con luz cálida que parpadea). Sirve para cualquier caja.

uniform vec3 stone_color : source_color = vec3(0.33, 0.31, 0.29);
uniform vec3 window_color : source_color = vec3(1.0, 0.62, 0.28);
uniform float lit_ratio = 0.22;
uniform float window_glow = 3.0;
uniform float windows = 1.0;  // 0 = sin ventanas (murallas, torres de defensa)
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

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
	bool top = abs(wnrm.y) > 0.5;
	vec2 uv = top ? wpos.xz : (abs(wnrm.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y));

	vec2 b = uv * vec2(1.6, 3.2);
	b.x += mod(floor(b.y), 2.0) * 0.5;
	vec2 bf = fract(b);
	float mortar = max(1.0 - smoothstep(0.0, 0.05, bf.x), 1.0 - smoothstep(0.0, 0.08, bf.y));
	float n = noise(uv * 2.5) * 0.6 + noise(uv * 11.0) * 0.4;
	vec3 tint = vec3(0.9 + 0.2 * hash(floor(wpos.xz / 9.0)));
	vec3 col = stone_color * tint * (0.7 + 0.45 * n) * (0.9 + 0.2 * hash(floor(b)));
	col *= 1.0 - mortar * 0.45;
	float streak = noise(vec2(uv.x * 3.0, wpos.y * 0.15));
	col *= mix(1.0, 0.65, smoothstep(0.4, 0.9, streak));

	float rough = 0.92;
	vec3 emit = vec3(0.0);
	if (!top && windows > 0.5) {
		vec2 cell = uv / vec2(2.6, 3.4);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float win = step(0.32, f.x) * step(f.x, 0.68) * step(0.28, f.y) * step(f.y, 0.78) * step(0.5, id.y);
		float frame = clamp(step(0.27, f.x) * step(f.x, 0.73) * step(0.23, f.y) * step(f.y, 0.83) * step(0.5, id.y) - win, 0.0, 1.0);
		float h = hash(id + wnrm.xz * 17.0);
		float lit = step(1.0 - lit_ratio, h);
		vec3 glass = mix(vec3(0.03, 0.035, 0.04), window_color * 0.4, lit);
		col = mix(col, glass, win);
		col = mix(col, col * 0.5, frame);
		emit = window_color * window_glow * lit * win * (0.85 + 0.15 * sin(TIME * 2.0 + h * 40.0));
		rough = mix(rough, 0.15, win);
	} else if (top) {
		col *= 0.6;
	}
	// Ceniza acumulada en las superficies de arriba; lluvia: piedra oscurecida y algo brillante.
	if (top) {
		col = mix(col, vec3(0.34, 0.33, 0.32), ash_amount * 0.85);
	}
	col *= mix(1.0, 0.68, wetness);
	rough = mix(rough, min(rough, 0.4), wetness);
	ALBEDO = col;
	ROUGHNESS = rough;
	EMISSION = emit;
}
