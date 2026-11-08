shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Calm lane look: a soft rim glow, four steady guide rails and slow, long
// swells of light drifting along the tube. No high-frequency stripes, so
// riding at full speed never strobes. Colours come from the current system.
uniform vec3 color = vec3(0.2, 0.85, 1.0);
uniform vec3 color2 = vec3(0.6, 0.4, 1.0);
uniform float intensity = 1.0;
uniform float flow_speed = 70.0;

void fragment() {
	// UV.x = distance along lane in meters, UV.y = around the tube 0..1
	float along = UV.x;
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	float swell = 0.5 + 0.5 * sin((along - TIME * flow_speed) * 0.0042);
	swell *= swell;
	float rail_d = abs(fract(UV.y * 4.0) - 0.5);
	float rails = smoothstep(0.465, 0.5, rail_d);
	vec3 c = mix(color, color2, 0.5 + 0.5 * sin(along * 0.0006));
	float dist = length(VERTEX);
	float near_fade = smoothstep(40.0, 600.0, dist);
	float a = rim * 0.2 * near_fade + swell * 0.045 * near_fade + rails * 0.11 * (0.35 + 0.65 * near_fade);
	ALBEDO = c * a * intensity;
}
