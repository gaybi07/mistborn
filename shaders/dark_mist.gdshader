shader_type fog;
// La bruma como la Profundidad: nubes negras que se arrastran por las calles, con claros entre
// ellas. Ruido 3D en coordenadas de mundo que el viento desplaza; más densa a ras de suelo.

uniform sampler3D noise : repeat_enable;
uniform float density = 0.08;
uniform vec3 albedo : source_color = vec3(0.06, 0.06, 0.07);
uniform vec3 emission : source_color = vec3(0.0);
uniform vec3 wind = vec3(1.6, 0.12, 0.7);
uniform float scale = 0.01;  // el ruido se repite cada 1/scale metros (nubes de ~30 m)
uniform float ceiling = 45.0;  // por encima se deshace

void fog() {
	float big = texture(noise, (WORLD_POSITION - wind * TIME) * scale).r;
	float fine = texture(noise, (WORLD_POSITION - wind.zyx * TIME * 1.7) * scale * 3.3).r;
	float c = smoothstep(0.4, 0.72, big * 0.72 + fine * 0.28);
	c *= 1.0 - smoothstep(ceiling * 0.25, ceiling, WORLD_POSITION.y);
	// Sin bordes visibles de la caja que sigue a la cámara.
	vec3 e = abs(UVW * 2.0 - 1.0);
	c *= 1.0 - smoothstep(0.75, 1.0, max(max(e.x, e.z), e.y));
	DENSITY = density * c;
	ALBEDO = albedo;
	EMISSION = emission;
}
