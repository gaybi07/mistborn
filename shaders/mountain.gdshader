shader_type spatial;
// Montes de ceniza (volcanes del norte): basalto oscuro, ceniza en las zonas planas y grietas de
// lava cerca del cráter. No recibe la niebla del motor: aplica su propia "lejanía" (haze), así
// se ven por encima de la muralla de día o con poca niebla, y de noche o con niebla densa quedan
// como siluetas en las que solo brilla la lava.
render_mode fog_disabled;

uniform float haze : hint_range(0.0, 1.0) = 0.6;
uniform vec3 haze_color : source_color = vec3(0.4, 0.42, 0.5);
uniform float haze_brightness = 1.0;
uniform vec3 lava_color : source_color = vec3(1.0, 0.32, 0.08);
/// Altura (m) desde la que aparecen las grietas de lava; muy alta = volcán dormido.
instance uniform float lava_level = 10000.0;

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
	float n = noise(wpos.xz * 0.02) * 0.6 + noise(vec2(wpos.x + wpos.z, wpos.y) * 0.08) * 0.4;
	vec3 rock = vec3(0.11, 0.1, 0.1) * (0.75 + 0.5 * n);
	float flat_ = smoothstep(0.55, 0.85, wnrm.y);
	vec3 col = mix(rock, vec3(0.3, 0.29, 0.28), flat_ * (0.5 + 0.5 * n));
	// Grietas de lava: vetas que bajan desde el cráter.
	float above = smoothstep(lava_level, lava_level + 40.0, wpos.y);
	float veins = smoothstep(0.62, 0.7, noise(vec2(atan(wpos.z, wpos.x) * 40.0, wpos.y * 0.04)));
	float lava = above * veins * (0.6 + 0.4 * sin(TIME * 0.8 + wpos.y * 0.05));
	ALBEDO = mix(col, vec3(0.0), haze);
	ROUGHNESS = 0.95;
	EMISSION = haze_color * haze * haze_brightness + lava_color * lava * 3.0 * (1.0 - 0.6 * haze);
}
