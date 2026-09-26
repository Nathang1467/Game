shader_type canvas_item;
// Darkness / fog overlay for the Blackout and Fog of War bosses.
uniform int mode = 0; // 0 = blackout, 1 = fog
uniform vec2 lights[6];
uniform int light_count = 0;
uniform float radius = 90.0;
uniform vec2 rect_size = vec2(535.0, 975.0);
uniform float fog_line = 460.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 p = UV * rect_size;
	if (mode == 0) {
		float m = 1.0;
		for (int i = 0; i < 6; i++) {
			if (i >= light_count) break;
			float d = length(p - lights[i]);
			m = min(m, smoothstep(radius * 0.5, radius, d));
		}
		COLOR = vec4(0.02, 0.01, 0.05, 0.96 * m);
	} else {
		float n = noise(p * 0.02 + vec2(TIME * 0.2, TIME * 0.05)) * 0.6 + noise(p * 0.05 - TIME * 0.1) * 0.4;
		float edge = smoothstep(fog_line + 40.0, fog_line - 30.0, p.y + n * 40.0);
		COLOR = vec4(vec3(0.55, 0.5, 0.7) * (0.6 + 0.4 * n), edge * 0.93);
	}
}
