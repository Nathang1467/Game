shader_type canvas_item;
// Swirling paint background: a slow, hypnotic arcade-carpet vortex.
uniform vec4 col_a : source_color = vec4(0.09, 0.06, 0.16, 1.0);
uniform vec4 col_b : source_color = vec4(0.16, 0.08, 0.26, 1.0);
uniform vec4 col_c : source_color = vec4(0.04, 0.22, 0.28, 1.0);
uniform float speed = 0.35;
uniform float intensity = 1.0;
uniform float pixel = 4.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 fc = floor(FRAGCOORD.xy / pixel) * pixel;
	vec2 uv = (fc - 0.5 * res) / res.y;
	float t = TIME * speed;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	a += 1.6 * r - t * 0.6;
	vec2 p = vec2(cos(a), sin(a)) * r * 3.0;
	for (int i = 0; i < 4; i++) {
		p += vec2(sin(p.y * 1.3 + t), cos(p.x * 1.1 - t * 0.8)) * 0.55;
	}
	float v = 0.5 + 0.5 * sin(p.x + p.y);
	float w = 0.5 + 0.5 * sin(length(p) * 1.4 - t * 1.3);
	vec3 c = mix(col_a.rgb, col_b.rgb, smoothstep(0.2, 0.8, v));
	c = mix(c, col_c.rgb, smoothstep(0.55, 0.95, w) * 0.8);
	c *= mix(1.0, 1.0 - r * 0.55, 1.0);
	COLOR = vec4(mix(col_a.rgb, c, intensity), 1.0);
}
