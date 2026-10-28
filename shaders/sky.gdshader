shader_type sky;
// Cielo de Luthadel: degradado, nubes de ceniza que se mueven despacio, disco de la luna (o del
// sol rojo de día) con halo tapado por las nubes, estrellas tenues entre los claros y bruma en
// el horizonte. Los colores los pone Weather según hora y clima.
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.02, 0.025, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.13, 0.12, 0.14);
uniform vec3 ground_color : source_color = vec3(0.02, 0.02, 0.03);
uniform vec3 cloud_color : source_color = vec3(0.05, 0.05, 0.06);
uniform vec3 cloud_light : source_color = vec3(0.35, 0.4, 0.55);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_speed = 0.006;
uniform float stars : hint_range(0.0, 1.0) = 0.6;
uniform vec3 disc_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float disc_size = 0.03;
uniform float disc_energy = 3.0;
uniform float haze : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = h >= 0.0 ? mix(horizon_color, top_color, pow(h, 0.45))
			: mix(horizon_color, ground_color, pow(-h, 0.4));

	// Luna o sol: disco y halo.
	float ang = acos(clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0));
	float disc = LIGHT0_ENABLED ? smoothstep(disc_size, disc_size * 0.85, ang) : 0.0;
	float halo = LIGHT0_ENABLED ? exp(-ang * 7.0) * 0.4 + exp(-ang * 1.8) * 0.12 : 0.0;

	// Estrellas: muy tenues, solo arriba y donde no hay nubes.
	float star = 0.0;
	if (stars > 0.0 && h > 0.05 && !AT_CUBEMAP_PASS) {
		vec3 cell = floor(d * 260.0);
		float s = hash(cell.xy + cell.z * 31.7);
		star = step(0.9965, s) * stars * smoothstep(0.05, 0.4, h) * (0.5 + 0.5 * hash(cell.zx));
	}

	// Nubes proyectadas sobre una bóveda: más pequeñas y apretadas hacia el horizonte.
	float c = 0.0;
	float shade = 0.0;
	if (h > -0.05) {
		vec2 uv = d.xz / (max(h, 0.0) + 0.12) * 0.55;
		uv += TIME * cloud_speed * vec2(1.0, 0.35);
		float n = fbm(uv);
		float n2 = fbm(uv * 2.3 + vec2(5.2, 1.3) - TIME * cloud_speed * 0.6);
		float v = n * 0.7 + n2 * 0.3;
		c = smoothstep(1.0 - cloud_cover - 0.12, 1.0 - cloud_cover + 0.3, v);
		c *= smoothstep(-0.05, 0.12, h);
		shade = n2;
	}
	// Bordes de las nubes iluminados cerca de la luna o el sol.
	float rim = pow(max(dot(d, LIGHT0_DIRECTION), 0.0), 6.0) * c * (1.0 - c) * 3.0;
	vec3 cloud = mix(cloud_color, cloud_light, clamp((1.0 - shade) * 0.45 + rim, 0.0, 1.0));

	col += disc_color * halo * (1.0 - c * 0.6);
	col += vec3(star) * (1.0 - c);
	col = mix(col, cloud, c);
	col += disc_color * disc * disc_energy * (1.0 - c * 0.92);
	// Bruma: el horizonte se funde con el color de la niebla.
	col = mix(col, horizon_color, exp(-abs(h) * 10.0) * haze);
	COLOR = col;
}
