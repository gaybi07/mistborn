shader_type spatial;
render_mode cull_disabled;
// Capa de bruma (malla de Meshy): tela desgarrada con sus mapas PBR. La mueven sus huesos
// (Mistcloak.build_model); aquí solo se pinta, teñida con el traje si `recolor` es 1.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap;
uniform vec3 suit : source_color = vec3(1.0);
uniform float recolor = 0.0;  // 1 = pinta el brillo de la tela con `suit` (trajes de color)

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(c, suit * clamp(0.42 + l * 3.0, 0.0, 1.15), recolor);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = texture(rough_tex, UV).r;
}
