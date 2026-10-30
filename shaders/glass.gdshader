shader_type spatial;
// Vidrieras de Kredik Shaw: cristal oscuro; las encendidas brillan (de noche) con luz cálida.

uniform vec3 albedo : source_color = vec3(0.05, 0.06, 0.08);
uniform vec3 glow : source_color = vec3(1.0, 0.6, 0.3);
uniform float glow_energy = 0.0;
uniform float roughness = 0.15;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.4;
	EMISSION = glow * glow_energy * (0.9 + 0.1 * sin(TIME * 1.7 + wpos.x * 3.1 + wpos.y * 1.3));
}
