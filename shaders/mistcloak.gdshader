shader_type spatial;
render_mode cull_disabled;
// Capa de bruma (Mistcloak.build_model): lana fina gris carbón en paños verticales, que abajo se rasga en
// tiras (los cortes los arma tools/blender/make_mistcloak.py; acá se calculan igual con slit_col y slit_v
// para afinar las tiras hacia la punta y deshilachar sus bordes). Por dentro, más oscura.
// UV: x alrededor del cuerpo (0 y 1 = bordes de adelante); y del cuello al borde, dada vuelta por el .glb.

uniform vec3 base_color : source_color = vec3(0.075, 0.072, 0.07);

const float COLS = 72.0;  // columnas de la malla - 1
const float STEP = 4.5;  // columnas entre cadena y cadena (72 / 16)

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
	float v = 1.0 - UV.y;  // el .glb llega con la v dada vuelta
	float vc = clamp(v, 0.0, 1.0);
	float around = mix(0.6, 2.6, vc);  // metros alrededor del cuerpo a esta altura
	vec2 m = vec2(UV.x * around, v * 1.25);

	// Corte más cercano (entre la cadena k y la k + 1) y qué tan lejos está, de 0 (en el corte) a 1 (en
	// el medio de la tira).
	float s = UV.x * COLS / STEP;
	float k = clamp(floor(s), 0.0, 15.0);
	float slit = round((k + 0.5) * STEP);
	float e = clamp(abs(UV.x * COLS - slit) / (STEP * 0.5), 0.0, 1.0);
	float slit_m = abs(UV.x * COLS - slit) / COLS * around;  // metros al corte
	float slit_v = 0.45 + 0.05 * mod(k * 7.0, 5.0);
	float strip_t = clamp((v - slit_v) / (1.0 - slit_v), 0.0, 1.0);
	float strip_id = floor(s + 0.5);

	float keep = 1.0;
	// Ya rasgada: las tiras se separan y se afinan hacia la punta, con el borde deshilachado.
	float fray = noise(vec2(v * 45.0, k * 3.1 + step(slit, UV.x * COLS) * 7.0));
	keep *= max(step(0.004 + 0.035 * pow(strip_t, 1.5) + 0.01 * fray * strip_t, slit_m), step(strip_t, 0.0));
	// Punta de cada tira: más larga al medio, gastada e irregular.
	float tip = (0.015 + 0.11 * pow(1.0 - e, 1.4) + 0.04 * noise(vec2(m.x * 14.0, strip_id))) / 1.25;
	keep *= step(v, 1.0 - tip);
	// Bordes de adelante, apenas deshilachados.
	float front = min(UV.x, 1.0 - UV.x) * around;
	keep *= step((0.003 + 0.02 * vc * vc) * noise(vec2(v * 40.0, step(0.5, UV.x) * 11.0)), front);
	// Pocos agujeros chicos, en la parte rasgada.
	float hole = step(0.9, noise(vec2(m.x * 7.0, m.y * 3.0))) * step(0.15, strip_t) * step(0.3, e);
	ALPHA = keep * (1.0 - hole);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// Lana lisa: tono parejo con variación suave, un poco distinto en cada paño, y fibras verticales finas.
	float soft = noise(m * 2.5) * 0.6 + noise(m * 6.0) * 0.4;
	float fiber = noise(vec2(m.x * 160.0, m.y * 9.0));
	vec3 c = base_color * (0.88 + 0.22 * soft) * (0.94 + 0.12 * hash(vec2(strip_id, 3.0))) * (0.95 + 0.1 * fiber);
	// Sombra en la unión de los paños y borde gastado más claro en las tiras.
	c *= mix(0.78, 1.0, smoothstep(0.0, 0.35, e)) + 0.25 * strip_t * smoothstep(0.25, 0.0, e);
	if (!FRONT_FACING) {
		c *= 0.55;
	}
	ALBEDO = c;
	ROUGHNESS = 0.88;
	// Cada paño se curva un poco (como una tira de tela), más marcado ya rasgado.
	float side = sign(UV.x * COLS - slit);
	float fold = cos(e * 3.14159) * side * mix(0.18, 0.4, strip_t);
	NORMAL_MAP = normalize(vec3(fold + (fiber - 0.5) * 0.08, 0.0, 1.0)) * 0.5 + 0.5;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	BACKLIGHT = c * 0.2;
}
