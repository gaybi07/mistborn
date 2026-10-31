shader_type spatial;
// Material con texturas (Poly Haven) para mallas sin UV: proyecta en coordenadas de mundo según la
// cara (arriba, este-oeste, norte-sur): 3 lecturas de textura por píxel, más barato que los
// sombreadores con ruido procedural. El mapa de normales se aplica sin tangentes.
// Con parallax_depth > 0 y un mapa de alturas, relieve por parallax (oclusión) a menos de
// parallax_far m: las juntas se hunden y los ladrillos sobresalen; más lejos no cuesta nada.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float scale = 3.0;  // metros que cubre una repetición de la textura
uniform float normal_strength = 1.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D height_tex : filter_linear_mipmap, repeat_enable;
uniform float parallax_depth = 0.0;  // metros de relieve (0: sin parallax)
uniform float parallax_far = 20.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 uv;
	vec3 t;
	vec3 b;
	if (an.y >= an.x && an.y >= an.z) {
		uv = wpos.xz;
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, 1.0);
	} else if (an.x >= an.z) {
		uv = vec2(wpos.z * sign(wnrm.x), -wpos.y);
		t = vec3(0.0, 0.0, sign(wnrm.x));
		b = vec3(0.0, -1.0, 0.0);
	} else {
		uv = vec2(-wpos.x * sign(wnrm.z), -wpos.y);
		t = vec3(-sign(wnrm.z), 0.0, 0.0);
		b = vec3(0.0, -1.0, 0.0);
	}
	uv /= scale;
	float dist = distance(CAMERA_POSITION_WORLD, wpos);
	if (parallax_depth > 0.0 && dist < parallax_far) {
		// Avanza el rayo de la vista dentro de la superficie hasta que choca con el relieve.
		vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
		vec3 vt = vec3(dot(v, t), dot(v, b), max(dot(v, wnrm), 0.08));
		float depth = parallax_depth * (1.0 - smoothstep(parallax_far * 0.6, parallax_far, dist)) / scale;
		float layers = mix(20.0, 8.0, vt.z);
		vec2 delta = vt.xy / vt.z * depth / layers;
		vec2 gx = dFdx(uv);
		vec2 gy = dFdy(uv);
		float step_d = 1.0 / layers;
		float cur = 0.0;
		vec2 cuv = uv;
		float hd = 1.0 - textureGrad(height_tex, cuv, gx, gy).r;
		for (int i = 0; i < 20; i++) {
			if (cur >= hd) {
				break;
			}
			cuv -= delta;
			hd = 1.0 - textureGrad(height_tex, cuv, gx, gy).r;
			cur += step_d;
		}
		vec2 prev = cuv + delta;
		float after = hd - cur;
		float before = (1.0 - textureGrad(height_tex, prev, gx, gy).r) - cur + step_d;
		uv = mix(cuv, prev, clamp(after / (after - before), 0.0, 1.0));
	}
	vec3 col = texture(albedo_tex, uv).rgb * tint;
	vec3 arm = texture(arm_tex, uv).rgb;
	vec3 nt = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	nt.xy *= normal_strength;
	vec3 n = normalize(t * nt.x - b * nt.y + wnrm * nt.z);
	// Ceniza acumulada arriba; lluvia: más oscuro y brillante.
	if (wnrm.y > 0.5) {
		col = mix(col, vec3(0.34, 0.33, 0.32), ash_amount * 0.85);
	}
	col *= mix(1.0, 0.68, wetness);
	ALBEDO = col;
	ROUGHNESS = mix(arm.g, min(arm.g, 0.35), wetness);
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
