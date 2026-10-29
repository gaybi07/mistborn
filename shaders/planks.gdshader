shader_type spatial;
// Tablones de madera en coordenadas de mundo (suelos, bancos, puertas, armarios, vigas):
// juntas entre tablas, vetas, tono distinto por tabla, mugre y ceniza posada en lo alto.
// En las caras de arriba las tablas van a lo largo de Z (along_x = 1: de X); en las de los lados, verticales.

uniform vec3 wood_color : source_color = vec3(0.32, 0.22, 0.14);
uniform float plank_width = 0.22;
uniform float along_x = 0.0;
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
	// uv.x cruza las tablas, uv.y sigue la veta.
	vec2 uv;
	if (abs(wnrm.y) > 0.5) {
		uv = along_x > 0.5 ? wpos.zx : wpos.xz;
	} else {
		uv = vec2(abs(wnrm.x) > 0.5 ? wpos.z : wpos.x, wpos.y);
	}
	float id = floor(uv.x / plank_width);
	float f = fract(uv.x / plank_width);
	float seam = 1.0 - smoothstep(0.0, 0.05, f) * smoothstep(1.0, 0.95, f);
	float shift = hash(vec2(id, 3.0));
	float piece = floor(uv.y / 1.8 + shift);
	float e = fract(uv.y / 1.8 + shift);
	float end_seam = 1.0 - smoothstep(0.0, 0.008, e) * smoothstep(1.0, 0.992, e);
	float grain = noise(vec2(uv.x * 38.0 + id * 7.0, uv.y * 1.3));
	float fine = noise(vec2(uv.x * 140.0, uv.y * 5.0));
	float knot = smoothstep(0.82, 0.95, noise(uv * vec2(9.0, 2.5) + id));
	float tone = 0.72 + 0.5 * hash(vec2(id, piece));
	vec3 col = wood_color * tone * (0.72 + 0.38 * grain + 0.14 * fine) * (1.0 - knot * 0.45);
	col *= 1.0 - max(seam, end_seam) * 0.65;
	col *= 0.82 + 0.18 * noise(wpos.xz * 0.9 + wpos.y * 0.7);
	if (wnrm.y > 0.5) {
		col = mix(col, vec3(0.37, 0.36, 0.35), ash_amount * smoothstep(0.25, 0.75, noise(wpos.xz * 2.5)));
	}
	ALBEDO = col;
	ROUGHNESS = 0.86;
}
