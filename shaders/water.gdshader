shader_type spatial;
// Agua del río Kredres: oscura, turbia de ceniza, con ondas que corren río abajo.

uniform vec3 deep : source_color = vec3(0.06, 0.08, 0.1);
uniform vec3 shallow : source_color = vec3(0.16, 0.18, 0.19);
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;  // lluvia: más rizado

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	// UV.x = metros a lo largo del río, UV.y = 0..1 a lo ancho.
	vec2 flow = vec2(UV.x * 0.25 - TIME * 0.35, UV.y * 4.0);
	float n = noise(flow * 2.0) * 0.6 + noise(flow * 6.0 + TIME * 0.2) * 0.4;
	float edge = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	vec3 col = mix(shallow, deep, edge);
	col = mix(col, vec3(0.3, 0.29, 0.28), ash_amount * 0.35 * n);
	ALBEDO = col * (0.85 + 0.3 * n);
	ROUGHNESS = mix(0.08, 0.25, wetness) + n * 0.08;
	SPECULAR = 0.7;
	// Ondas: inclina la normal según el ruido.
	float dx = noise(flow * 3.0 + vec2(0.1, 0.0)) - noise(flow * 3.0 - vec2(0.1, 0.0));
	float dz = noise(flow * 3.0 + vec2(0.0, 0.1)) - noise(flow * 3.0 - vec2(0.0, 0.1));
	NORMAL_MAP = normalize(vec3(dx * (1.5 + wetness * 2.0), dz * (1.5 + wetness * 2.0), 1.0)) * 0.5 + 0.5;
}
