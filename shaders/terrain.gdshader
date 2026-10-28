shader_type spatial;
// Terreno del exterior: tierra cubierta de ceniza con manchas de hierba marrón (en el mundo de
// Mistborn las plantas son pardas). Sirve para llanuras, colinas y caminos (road = 1).

uniform vec3 dirt : source_color = vec3(0.2, 0.17, 0.14);
uniform vec3 grass : source_color = vec3(0.26, 0.22, 0.12);
uniform vec3 ash_color : source_color = vec3(0.33, 0.32, 0.31);
uniform float road = 0.0;
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
	vec2 p = wpos.xz;
	float n1 = noise(p * 0.05);
	float n2 = noise(p * 0.4);
	float n3 = noise(p * 3.0);
	vec3 col = mix(dirt, grass, smoothstep(0.45, 0.75, n1 * 0.7 + n2 * 0.3) * (1.0 - road));
	col *= 0.8 + 0.35 * n3;
	// Laderas empinadas: roca más oscura.
	col = mix(col, vec3(0.13, 0.12, 0.11), smoothstep(0.85, 0.6, wnrm.y));
	// Caminos: tierra apisonada con roderas.
	col = mix(col, vec3(0.24, 0.2, 0.16) * (0.85 + 0.25 * n3), road);
	float ash = smoothstep(mix(0.5, 0.1, ash_amount), 0.9, noise(p * 0.12) * 0.7 + n3 * 0.3) * mix(0.55, 0.9, ash_amount);
	col = mix(col, ash_color, ash * wnrm.y);
	float puddle = smoothstep(0.62, 0.7, noise(p * 0.07 + 3.0)) * wetness * max(road, 0.4);
	col *= mix(1.0, 0.6, wetness) * (1.0 - puddle * 0.3);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.4, wetness), 0.05, puddle);
}
