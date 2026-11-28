shader_type canvas_item;
// Old-film iris: closes on the centre of the screen, opens on the next one.

uniform float radius : hint_range(0.0, 1.6) = 1.6;
uniform vec2 aspect = vec2(1.7778, 1.0);
uniform vec4 tint : source_color = vec4(0.051, 0.035, 0.027, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p) / length(aspect * 0.5);
	COLOR = vec4(tint.rgb, step(radius, d));
}
