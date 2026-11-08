shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color = vec3(0.2, 0.85, 1.0);
uniform vec3 color2 = vec3(0.6, 0.4, 1.0);
uniform float intensity = 1.0;
uniform float flow_speed = 120.0;

void fragment() {
	// UV.x = distance along lane in meters, UV.y = around the tube 0..1
	float along = UV.x;
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float chevron = fract((along - TIME * flow_speed) / 60.0 + abs(fract(UV.y * 6.0) - 0.5) * 0.6);
	float stripe = smoothstep(0.0, 0.08, chevron) * (1.0 - smoothstep(0.12, 0.35, chevron));
	float rails = smoothstep(0.44, 0.495, abs(fract(UV.y * 6.0) - 0.5));
	vec3 c = mix(color, color2, sin(along * 0.002) * 0.5 + 0.5);
	float dist = length(VERTEX);
	float near_fade = smoothstep(15.0, 160.0, dist);
	float a = edge * 0.3 * near_fade + stripe * 0.22 + rails * 0.35;
	ALBEDO = c * a * intensity * (0.35 + 0.65 * near_fade);
}
