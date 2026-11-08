shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color = vec3(0.4, 0.8, 1.0);
uniform float charge = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x);
	float speed = 0.15 + charge * 1.5;
	float swirl = noise(vec2(a * 3.0 + r * 6.0 - TIME * speed * 4.0, r * 4.0 - TIME * speed)) ;
	swirl += 0.5 * noise(vec2(a * 7.0 - r * 10.0 + TIME * speed * 3.0, r * 9.0));
	float rings = 0.5 + 0.5 * sin(r * 30.0 - TIME * (2.0 + charge * 10.0));
	float edge = smoothstep(0.7, 1.0, r);
	float core = (1.0 - smoothstep(0.0, 0.35, r)) * charge * 3.0;
	float v = swirl * 0.25 * (0.3 + r) + rings * 0.08 * r + edge * 0.6 + core;
	v *= 0.35 + charge * 1.6;
	ALBEDO = color * v * (1.0 - smoothstep(0.95, 1.0, r));
}
