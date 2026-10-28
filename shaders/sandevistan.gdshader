shader_type canvas_item;
// Post-proceso del Sandevistan (atium avivado): aberración cromática radial,
// desenfoque de velocidad en los bordes, virado de color que cicla, viñeta y líneas de escaneo.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hue = 0.0;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);

	vec2 off = c * (0.004 + 0.025 * d) * intensity;
	vec3 col;
	col.r = texture(screen_texture, uv + off).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - off).b;

	vec3 blur = vec3(0.0);
	for (int i = 1; i <= 6; i++) {
		blur += texture(screen_texture, uv - c * float(i) * 0.01 * intensity).rgb;
	}
	blur /= 6.0;
	col = mix(col, blur, smoothstep(0.15, 0.6, d) * 0.6 * intensity);

	vec3 tint = hsv2rgb(vec3(hue, 0.7, 1.0));
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(lum) * vec3(0.6, 1.0, 0.85), col, 0.5) + tint * 0.08;
	col = mix(col, graded, intensity);

	col *= 1.0 - intensity * smoothstep(0.3, 0.8, d) * 0.65;
	col += tint * intensity * smoothstep(0.45, 0.75, d) * 0.25;
	col *= 1.0 - intensity * 0.05 * (0.5 + 0.5 * sin(FRAGCOORD.y * 2.0));

	COLOR = vec4(col, 1.0);
}
