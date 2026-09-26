shader_type canvas_item;
// Soft CRT pass: scanlines, vignette and a touch of colour fringing.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float scan = 0.10;
uniform float vignette = 0.35;
uniform float fringe = 0.9;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(px.x * fringe, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(px.x * fringe, 0.0)).b;
	float line = sin(FRAGCOORD.y * 3.14159 * 0.5) * 0.5 + 0.5;
	c *= 1.0 - scan * line;
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 2.0;
	COLOR = vec4(c, 1.0);
}
