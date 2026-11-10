// Espectro de la bruma (WraithRig): una masa de bruma con huesos adentro, sin esqueleto. El cuerpo se mueve acá:
// respira, ondula como gelatina, se arrastra en tirones (crawl), se echa atrás y se lanza (lunge) y se derrite (melt).
// El frente del modelo es +Z (en el espacio de la malla).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;  // glTF: rugosidad en G, metal en B
uniform float height = 1.2;  // alto de la malla, en sus unidades
uniform float crawl = 0.0;  // 0 quieto .. 1 arrastrándose rápido
uniform float lunge = 0.0;  // < 0 echado atrás, 1 estirado hacia adelante
uniform float melt = 0.0;  // 0 entero .. 1 derretido
uniform float flash = 0.0;  // golpe recibido
uniform float seed = 0.0;  // para que no latan todos juntos

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float t = TIME + seed;
	vec3 v = VERTEX;
	float up = clamp(v.y / height, 0.0, 1.0);
	// Respira y ondula: ondas que suben por el cuerpo, más arriba que en la base.
	float breathe = sin(t * 1.7) * 0.035;
	float jelly = sin(t * 2.3 + v.y * 6.0 + v.x * 3.0) * 0.03 + sin(t * 3.1 - v.y * 4.0 + v.z * 5.0) * 0.02;
	v.xz *= 1.0 + (breathe + jelly) * (0.3 + up);
	v.y *= 1.0 - breathe * 0.6;
	// Se arrastra: una onda corre de adelante hacia atrás y el cuerpo se estira y se junta a tirones.
	float pulse = sin(t * 5.0);
	v.y += sin(v.z * 4.0 + t * 7.0) * 0.04 * crawl * up;
	v.z *= 1.0 + pulse * 0.07 * crawl;
	v.y *= 1.0 - pulse * 0.05 * crawl;
	// Se lanza: lo de arriba se va hacia adelante y se aplasta; antes se echa atrás.
	v.z += lunge * up * up * height * 0.9;
	v.y *= 1.0 - max(lunge, 0.0) * 0.25;
	// Se derrite: se aplasta y se desparrama por el piso.
	v.y *= 1.0 - melt * 0.85;
	v.xz *= 1.0 + melt * 0.6 * (1.0 - up * 0.5);
	VERTEX = v;
}

void fragment() {
	// Al derretirse se deshace en manchas.
	if (melt > 0.0 && noise(UV * 40.0) < melt * 1.1 - 0.1) {
		discard;
	}
	vec4 orm = texture(orm_tex, UV);
	ALBEDO = texture(albedo_tex, UV).rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	// Borde pálido, como si la luz pasara a través; rojo al recibir un golpe.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.55, 0.6, 0.65) * rim * 0.35 * (1.0 - melt) + vec3(1.0, 0.3, 0.25) * flash;
}
