shader_type spatial;
// Pulso alomántico que siente un Buscador (bronce): una onda que se expande y se desvanece,
// visible a través de las paredes. Brilla en los bordes (fresnel) como una cáscara.
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.85, 0.65, 0.35, 1.0);
uniform float strength = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = tint.rgb * rim * strength * 1.6;
}
