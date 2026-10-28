shader_type spatial;
// Holograma aditivo con brillo en los bordes (fresnel): sombras de atium y estelas del Sandevistan.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform float strength = 0.5;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float lines = 0.85 + 0.15 * sin(FRAGCOORD.y * 1.5);
	ALBEDO = tint.rgb * (0.12 + fres * 1.8) * strength * lines;
}
