shader_type spatial;
// Zona de aviso en el piso (ver Telegraph): círculo, anillo, cono o franja. `progress` llena la zona hasta que
// pega (1); `flash` es el destello del golpe. Borde con bruma que se mueve, para que no parezca un sprite.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;  // siempre visible: en pendientes y escalones el plano queda bajo el terreno

uniform vec4 color : source_color = vec4(1.0, 0.16, 0.1, 1.0);
uniform int shape = 0;            // 0 círculo, 1 anillo, 2 cono, 3 franja
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float inner = 0.0;        // anillo: radio de adentro (fracción del de afuera)
uniform float half_angle = 0.6;   // cono: medio ángulo (radianes)
uniform float edge = 0.04;        // grosor del borde (fracción)
uniform bool fill = true;         // sin relleno: solo el borde (zonas que no dañan)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;    // -1..1, adelante = -y
	float inside = 0.0;            // 1 dentro de la zona
	float rim = 0.0;               // cerca del borde
	float reach = 0.0;             // 0 en el origen, 1 en el borde de afuera (para el relleno)
	if (shape == 0 || shape == 1) {
		float r = length(p);
		inside = step(r, 1.0) * step(inner, r);
		rim = max(1.0 - smoothstep(0.0, edge, 1.0 - r), inner > 0.0 ? 1.0 - smoothstep(0.0, edge, r - inner) : 0.0);
		reach = shape == 1 ? (r - inner) / max(1.0 - inner, 0.001) : r;
	} else if (shape == 2) {
		float r = length(p);
		float a = acos(clamp(dot(normalize(p + vec2(0.0, 1e-5)), vec2(0.0, -1.0)), -1.0, 1.0));
		inside = step(r, 1.0) * step(a, half_angle);
		rim = max(1.0 - smoothstep(0.0, edge, 1.0 - r), 1.0 - smoothstep(0.0, edge * 2.0, (half_angle - a) * r));
		reach = r;
	} else {
		// franja: el origen en el borde de +z (UV.y = 1), avanza hacia -z
		float along = 1.0 - UV.y;
		float across = abs(UV.x - 0.5) * 2.0;
		inside = 1.0;
		rim = max(1.0 - smoothstep(0.0, edge * 4.0, 1.0 - across), 1.0 - smoothstep(0.0, edge, 1.0 - along));
		reach = along;
	}
	if (inside < 0.5) {
		discard;
	}
	float mist = noise(UV * 9.0 + vec2(TIME * 0.6, -TIME * 0.4)) * 0.6 + noise(UV * 23.0 - TIME * 0.9) * 0.4;
	float filled = fill ? step(reach, progress) : 0.0;
	float alpha = (fill ? 0.14 : 0.0) + filled * 0.32 + rim * 0.75;
	alpha *= 0.65 + 0.35 * mist;
	// El frente del relleno brilla un poco: se ve cuánto falta.
	alpha += fill ? (1.0 - smoothstep(0.0, 0.04, abs(reach - progress))) * 0.35 * step(progress, 0.999) : 0.0;
	ALBEDO = mix(color.rgb, vec3(1.0, 0.95, 0.85), flash);
	ALPHA = clamp(alpha + flash * 0.5 * inside, 0.0, 1.0) * fade * color.a;
}
