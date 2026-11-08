shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color = vec3(1.0, 0.85, 0.65);

void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = mv * mat4(vec4(s, 0, 0, 0), vec4(0, s, 0, 0), vec4(0, 0, s, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = (1.0 - smoothstep(0.07, 0.09, r)) * 18.0;
	float glow = exp(-r * 7.0) * 3.0 + exp(-r * 2.5) * 0.35;
	// thin anamorphic streak
	float streak = exp(-abs(p.y) * 120.0) * exp(-abs(p.x) * 2.5) * 1.2;
	ALBEDO = color * (core + glow + streak) * (1.0 - smoothstep(0.8, 1.0, r));
}
