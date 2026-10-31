shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Agua del río Kredres: turbia de ceniza pero visible. El color depende de cuánta agua hay debajo
// (se ve el fondo cerca de la orilla, oscura en el centro), espuma donde toca la orilla y los
// pilares, ondas que corren río abajo y un brillo del cielo en ángulo rasante (también de noche).

uniform vec3 deep : source_color = vec3(0.09, 0.14, 0.15);
uniform vec3 shallow : source_color = vec3(0.32, 0.36, 0.33);
uniform vec3 foam_color : source_color = vec3(0.72, 0.7, 0.66);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.6, 0.7);
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;  // lluvia: más rizado
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

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

	// Cuánta agua hay entre la superficie y lo que está detrás (fondo, orilla, pilares).
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	behind.xyz /= behind.w;
	float thick = max(VERTEX.z - behind.z, 0.0);
	float murk = smoothstep(0.0, 2.5, thick);

	vec3 col = mix(shallow, deep, murk);
	col = mix(col, vec3(0.34, 0.33, 0.31), ash_amount * 0.35 * n);
	// Espuma: una franja que tiembla donde el agua toca algo.
	float foam = (1.0 - smoothstep(0.0, 0.45 + n * 0.35, thick)) * (0.6 + 0.4 * n);
	col = mix(col, foam_color, foam * 0.8);

	// Brillo del cielo en ángulo rasante (un reflejo barato que se ve también de noche).
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = col * (0.85 + 0.3 * n);
	EMISSION = sky_tint * fresnel * 0.18 + foam_color * foam * 0.05;
	ALPHA = mix(0.55, 0.94, murk) + foam * 0.3;
	ROUGHNESS = mix(0.06, 0.22, wetness) + n * 0.06;
	SPECULAR = 0.75;
	// Ondas: inclina la normal según el ruido.
	float dx = noise(flow * 3.0 + vec2(0.1, 0.0)) - noise(flow * 3.0 - vec2(0.1, 0.0));
	float dz = noise(flow * 3.0 + vec2(0.0, 0.1)) - noise(flow * 3.0 - vec2(0.0, 0.1));
	NORMAL_MAP = normalize(vec3(dx * (1.5 + wetness * 2.0), dz * (1.5 + wetness * 2.0), 1.0)) * 0.5 + 0.5;
}
