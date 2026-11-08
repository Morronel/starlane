// Baked once into a panorama texture at startup (see sky.gd).
shader_type canvas_item;

uniform vec3 col_a = vec3(0.10, 0.20, 0.55);
uniform vec3 col_b = vec3(0.55, 0.12, 0.45);
uniform vec3 col_c = vec3(0.95, 0.55, 0.35);
uniform vec3 plane_normal = vec3(0.25, 1.0, 0.35);
uniform float seed = 3.7;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 7; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Equirectangular direction, matching Godot's panorama mapping closely enough.
	float phi = (UV.x - 0.5) * TAU;
	float theta = UV.y * PI;
	vec3 d = vec3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi));

	float band = exp(-pow(dot(d, normalize(plane_normal)) * 2.4, 2.0));
	vec3 q = d * 2.2 + seed;
	float w = fbm(q);
	float n1 = fbm(q + vec3(w * 1.8));
	float n2 = fbm(d * 4.5 + vec3(n1 * 2.5) + seed * 2.0);

	float dens = smoothstep(0.46, 0.9, n2) * (0.15 + band * 1.0);
	dens += smoothstep(0.5, 0.75, n1) * band * 0.35;
	vec3 col = mix(col_a, col_b, smoothstep(0.35, 0.75, n1));
	col = mix(col, col_c, smoothstep(0.62, 0.9, n2) * 0.7);
	vec3 c = col * dens;

	// dark dust lanes inside the band
	float dust = smoothstep(0.48, 0.72, fbm(d * 8.0 + seed * 3.0));
	c *= 1.0 - dust * 0.7 * band;

	// soft galactic glow + faint star haze
	c += vec3(0.5, 0.45, 0.6) * pow(band, 3.0) * 0.08 * (0.5 + n2);
	float haze = hash(floor(d * 900.0));
	c += vec3(pow(haze, 80.0)) * 0.12 * (0.3 + band);

	c += vec3(0.003, 0.005, 0.012);
	COLOR = vec4(c, 1.0);
}
