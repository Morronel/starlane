shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 color = vec3(1.0, 0.2, 0.1);
uniform float rate = 1.0;
uniform float phase = 0.0;
void fragment() {
	float b = pow(max(sin((TIME * rate + phase) * TAU), 0.0), 8.0);
	ALBEDO = color * (0.2 + b * 8.0);
}
