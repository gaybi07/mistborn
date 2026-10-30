shader_type spatial;
// Adoquines procedurales (celdas de Voronoi) con juntas oscuras y ceniza acumulada.

uniform vec3 stone_a : source_color = vec3(0.25, 0.24, 0.23);
uniform vec3 stone_b : source_color = vec3(0.16, 0.155, 0.15);
uniform vec3 ash_color : source_color = vec3(0.34, 0.33, 0.32);
uniform float scale = 2.2;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;   // lluvia: más oscuro, brillante y con charcos
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0; // lluvia de ceniza: el suelo se cubre
uniform float triplanar = 0.0; // 1 = también en paredes (rocas, acantilados), no solo en el suelo

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, u.x),
			mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, u.x), u.y);
}

void fragment() {
	vec2 pl = wpos.xz;
	if (triplanar > 0.5 && abs(wnrm.y) < 0.6) {
		pl = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	}
	vec2 p = pl * scale;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 cid = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				cid = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float gap = 1.0 - smoothstep(0.03, 0.12, d2 - d1);
	vec3 col = mix(stone_a, stone_b, hash2(cid).x);
	col *= 0.85 + 0.3 * noise(pl * 6.0);
	float ash_n = noise(pl * 0.15) * 0.7 + noise(pl * 1.3) * 0.3;
	float ashf = smoothstep(mix(0.45, 0.1, ash_amount), 0.85, ash_n) * mix(0.6, 0.95, ash_amount);
	col = mix(col, ash_color, ashf);
	col *= 1.0 - gap * 0.7 * (1.0 - ashf * 0.6);
	float rough = mix(0.72, 1.0, gap);
	// Mojado: más oscuro y brillante; en los huecos del terreno se forman charcos.
	float puddle = smoothstep(0.58, 0.68, noise(pl * 0.09 + 7.0)) * wetness;
	col *= mix(1.0, 0.62, wetness) * (1.0 - puddle * 0.25);
	rough = mix(rough, 0.25, wetness * (1.0 - gap * 0.5));
	rough = mix(rough, 0.03, puddle);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.5, 0.9, wetness);
}
