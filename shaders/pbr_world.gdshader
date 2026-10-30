shader_type spatial;
// Material con texturas (Poly Haven) para mallas sin UV: proyecta en coordenadas de mundo según la
// cara (arriba, este-oeste, norte-sur): 3 lecturas de textura por píxel, más barato que los
// sombreadores con ruido procedural. El mapa de normales se aplica sin tangentes.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float scale = 3.0;  // metros que cubre una repetición de la textura
uniform float normal_strength = 1.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0;

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
