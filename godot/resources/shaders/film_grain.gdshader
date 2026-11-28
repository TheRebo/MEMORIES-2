shader_type canvas_item;
// Warm grain and a soft flicker over flashback scenes (memories look like old film).

uniform vec3 grain_color : source_color = vec3(0.35, 0.25, 0.12);
uniform float cell = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = floor(FRAGCOORD.xy / cell);
	float n = hash(c + floor(TIME * 8.0) * 17.0);
	float flick = 0.05 * step(0.5, fract(TIME * 1.25)) - 0.03 * step(0.85, fract(TIME * 2.5));
	COLOR = vec4(grain_color, clamp(n * 0.32 + flick, 0.0, 1.0));
}
