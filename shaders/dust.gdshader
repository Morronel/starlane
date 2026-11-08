shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float box_size = 240.0;
uniform vec3 velocity = vec3(0.0);
varying float fade;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 p = MODEL_MATRIX[3].xyz;
	vec3 rel = mod(p - cam + box_size * 0.5, box_size) - box_size * 0.5;
	vec3 wp = cam + rel;
	float d = length(rel);
	fade = (1.0 - smoothstep(box_size * 0.2, box_size * 0.5, d)) * smoothstep(2.0, 10.0, d);
	// stretch along velocity for a streak effect at speed
	vec3 vdir = length(velocity) > 0.1 ? normalize(velocity) : vec3(0, 0, 1);
	float stretch = clamp(length(velocity) * 0.025, 0.0, 10.0);
	vec3 right = normalize(cross(vdir, normalize(wp - cam)));
	vec3 world = wp + right * VERTEX.x * 0.25 + vdir * VERTEX.y * (0.25 + stretch);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = (1.0 - smoothstep(0.2, 1.0, abs(p.x))) * (1.0 - smoothstep(0.6, 1.0, abs(p.y)));
	ALBEDO = vec3(0.6, 0.75, 1.0) * a * fade * (0.08 + clamp(length(velocity) * 0.0015, 0.0, 0.25) / (1.0 + length(velocity) * 0.0006));
}
