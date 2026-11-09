shader_type spatial;
// Humo de los poderes apuntados del jugador (ver Telegraph.smoke_path y smoke_ring). Cintas siempre de frente a la cámara:
// - mode 0: rayos que salen del origen y fluyen hacia afuera. Uno solo a lo largo de -z (la lanza, la embestida) o uno
//   por moneda (la ráfaga), con su dirección en UV2;
// - mode 1: aro de radio `path_length` en el plano xz, con el humo girando (martillazo);
// - mode 2: esfera entera de humo de radio `path_length`, más densa en el contorno (campo magnético, atracción masiva).
// Respeta la profundidad, así el humo sale de atrás del cuerpo en vez de pintarse encima.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.65, 1.0, 0.9);
uniform int mode = 0;
uniform float path_length = 30.0;  // largo de los rayos, o radio del aro
uniform float width_scale = 1.0;
uniform float start_fade = 2.5;  // metros en que aparece el rayo (el cuerpo tapa el comienzo)
uniform float near_fade = 1.8;  // metros desde la cámara en que el humo termina de aparecer
uniform float opacity = 1.0;  // menos en un abanico, para que muchos rayos juntos no tapen todo
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float progress = 0.0;  // lo pone Telegraph; el humo no se llena

varying float dist;      // metros desde el origen (rayos) o recorridos sobre el aro
varying float along;     // 0 en el origen, 1 al final
varying float across;    // -1 a 1, de un borde al otro de la cinta
varying float seed;      // cada rayo con su propio humo
varying vec3 shell;      // esfera: dirección desde el centro

void vertex() {
	float v = UV.y;
	vec3 center;
	vec3 dir;
	float sway;
	if (mode == 2) {
		// Esfera entera (SphereMesh de radio 1): solo se agranda al radio; el humo lo pone fragment().
		shell = normalize(VERTEX);
		VERTEX = shell * path_length;
		NORMAL = shell;
		dist = 0.0;
		along = 0.5;
		across = 0.0;
		seed = 0.0;
	} else {
	if (mode == 1) {
		float th = v * TAU;
		center = vec3(sin(th), 0.0, -cos(th)) * path_length;
		dir = vec3(cos(th), 0.0, sin(th));
		dist = th * path_length;
		along = 0.5;
		seed = 0.0;
		sway = 0.12 * sin(th * 5.0 - TIME * 2.2);  // frecuencia entera: el aro cierra sin costura
	} else {
		// Más anillos cerca del origen, donde la estela ocupa más pantalla.
		dist = path_length * v * v;
		along = v;
		seed = UV2.x * 4.4 + UV2.y * 7.1;
		// Cada rayo con su dirección: UV2.x es el giro a la derecha y UV2.y la elevación (como SkillTree.burst_dirs).
		dir = vec3(sin(UV2.x) * cos(UV2.y), sin(UV2.y), -cos(UV2.x) * cos(UV2.y));
		center = dir * dist;
		// Ondula como humo, sin moverse en los extremos: sigue saliendo del personaje y llegando a la mira.
		sway = smoothstep(0.0, 2.0, dist) * (1.0 - v) * 0.15 * sin(log(1.0 + dist) * 3.4 - TIME * 2.2 + seed);
	}
	across = UV.x * 2.0 - 1.0;
	vec3 camera_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 side = cross(dir, camera_local - center);
	side = length(side) > 0.001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	center += side * sway;
	float half_width = mode == 1 ? 0.32 : (0.13 + 0.32 * smoothstep(0.0, 1.5, dist)) * mix(1.0, 0.55, v);
	VERTEX = center + side * across * half_width * width_scale;
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// (jirones, hebras) en `t` a lo largo de la cinta y `ac` de través.
vec2 smoke(float t, float ac, float time) {
	// Dos deformaciones que cambian solas con el tiempo (no solo se desplazan): así el humo hierve y se ve vivo aunque
	// gires la cámara, que arrastra la cinta entera y tapaba el avance lento de los jirones.
	float warp = noise(vec2(t * 1.1 - time * 0.8, ac * 1.2 + time * 0.5 + 3.1)) - 0.5;
	float boil = noise(vec2(t * 2.3 + time * 1.1, ac * 2.0 - time * 0.9 + 7.3)) - 0.5;
	float a = ac * 1.2 + warp * 1.3 + boil * 0.5;
	float s = t + boil * 0.35;
	float n1 = noise(vec2(a * 3.0, s * 1.9 - time * 1.6));
	float n2 = noise(vec2(a * 6.5 + 9.0, s * 3.2 - time * 2.4));
	return vec2(smoothstep(0.42, 0.84, n1 * 0.65 + n2 * 0.35), pow(1.0 - abs(n1 * 2.0 - 1.0), 3.5));
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Lo mismo que smoke() pero sobre la superficie de la esfera, en 3D (sin costuras). `p` en metros.
vec2 smoke3(vec3 p, float time) {
	float warp = noise3(p * 0.5 + vec3(0.0, time * 0.5, time * 0.3)) - 0.5;
	float boil = noise3(p * 1.1 - vec3(time * 0.6, 0.0, time * 0.4) + 5.0) - 0.5;
	vec3 q = p + vec3(warp * 1.6, boil * 0.8, -warp * 1.2);
	float n1 = noise3(q * 0.9 + vec3(0.0, -time * 0.7, 0.0));
	float n2 = noise3(q * 2.0 + vec3(time * 0.9, 0.0, 0.0) + 9.0);
	return vec2(smoothstep(0.42, 0.84, n1 * 0.65 + n2 * 0.35), pow(1.0 - abs(n1 * 2.0 - 1.0), 3.5));
}

void fragment() {
	vec2 sm;
	float ends;
	if (mode == 2) {
		// Cáscara de humo: cubre toda la esfera, más densa en el contorno, así se lee la forma entera.
		// Jirones del mismo tamaño en las dos esferas (si no, la grande se llena de venitas).
		sm = smoke3(shell * 3.2, TIME);
		float rim = 1.0 - abs(dot(NORMAL, VIEW));
		float near_camera = smoothstep(0.4, near_fade, length(VERTEX));
		// Con la cámara adentro se ve de frente casi todo: el centro va tenue y el contorno marca la forma.
		float alpha = (0.04 + sm.x * 0.2 + sm.y * 0.14) * (0.3 + 1.1 * rim * rim) * near_camera * opacity;
		ALBEDO = mix(mix(color.rgb, mix(color.rgb, vec3(1.0), 0.6), 0.2 + sm.y * 0.5), vec3(1.0, 0.95, 0.85), flash);
		ALPHA = clamp(alpha + flash * 0.4, 0.0, 1.0) * fade;
	} else {
	if (mode == 1) {
		float t = dist * 0.45;
		float loop = TAU * path_length * 0.45;
		sm = smoke(t, across + seed, TIME);
		// Al cerrar la vuelta se mezcla con el comienzo, así no queda una costura.
		sm = mix(sm, smoke(t - loop, across + seed, TIME), smoothstep(loop - 1.5, loop, t));
		ends = 1.0;
	} else {
		// Logaritmo de la distancia: por la perspectiva, así los jirones miden parecido en pantalla cerca y lejos.
		sm = smoke(log(1.0 + dist * 0.9), across + seed, TIME);
		ends = smoothstep(0.0, start_fade, dist) * (1.0 - smoothstep(0.8, 1.0, along));
	}
	float edge = pow(1.0 - abs(across), 1.7);
	float near_camera = smoothstep(0.4, near_fade, length(VERTEX));  // un rayo que pasa por la cámara no tapa la pantalla
	float alpha = (0.02 + sm.x * 0.2 + sm.y * 0.26) * edge * ends * near_camera * opacity;
	// Del color del metal del poder; las hebras, más claras.
	ALBEDO = mix(mix(color.rgb, mix(color.rgb, vec3(1.0), 0.6), 0.2 + sm.y * 0.5), vec3(1.0, 0.95, 0.85), flash);
	ALPHA = clamp(alpha + flash * 0.5 * edge, 0.0, 1.0) * fade;
	}
}
