shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.3, -1.0);
uniform vec3 c1 = vec3(0.85, 0.62, 0.42);
uniform vec3 c2 = vec3(0.55, 0.32, 0.25);
uniform vec3 c3 = vec3(0.95, 0.88, 0.75);
uniform vec3 night = vec3(0.035, 0.03, 0.07);

varying vec3 obj_pos;
varying vec3 world_n;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void vertex() {
	obj_pos = normalize(VERTEX);
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = obj_pos;
	float warp = fbm(p * 3.0 + vec3(0.0, 0.0, TIME * 0.002));
	float lat = p.y * 9.0 + warp * 2.2 + fbm(p * 12.0) * 0.4;
	float bands = sin(lat) * 0.5 + 0.5;
	float fine = sin(lat * 3.7 + warp * 4.0) * 0.5 + 0.5;
	vec3 col = mix(c2, c1, bands);
	col = mix(col, c3, smoothstep(0.7, 1.0, fine) * 0.5);
	// storm spot
	vec3 spot_c = normalize(vec3(0.6, -0.25, 0.75));
	float spot = smoothstep(0.985, 0.995, dot(p, spot_c) + fbm(p * 20.0) * 0.01);
	col = mix(col, vec3(0.75, 0.35, 0.22), spot * 0.8);

	float ndl = dot(world_n, normalize(sun_dir));
	float light = smoothstep(-0.15, 0.6, ndl);
	vec3 lit = col * light * 1.15 + night * (1.0 - light);
	// atmospheric rim on lit side
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	lit += vec3(0.9, 0.7, 0.5) * rim * smoothstep(-0.3, 0.5, ndl) * 0.6;
	ALBEDO = lit;
}
