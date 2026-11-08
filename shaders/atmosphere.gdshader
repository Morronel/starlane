shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled, shadows_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.3, -1.0);
uniform vec3 tint = vec3(1.0, 0.75, 0.5);
varying vec3 world_n;

void vertex() {
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Back faces of a slightly larger sphere: bright thin halo around the limb.
	float f = clamp(dot(-NORMAL, VIEW), 0.0, 1.0);
	float halo = pow(1.0 - f, 1.5) * smoothstep(0.0, 0.25, f);
	float lit = smoothstep(-0.4, 0.6, dot(world_n, normalize(sun_dir)));
	ALBEDO = tint * halo * lit * 1.4;
}
