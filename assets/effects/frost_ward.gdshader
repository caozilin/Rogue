shader_type canvas_item;
uniform float effect_time = 0.0;
uniform float strength = 1.0;
uniform float integrity = 1.0;
uniform float impact = 0.0;
uniform float impact_angle = 0.0;

float hex_edge(vec2 p) {
	vec2 spacing = vec2(1.0, 1.732);
	vec2 a = mod(p, spacing) - spacing * 0.5;
	vec2 b = mod(p - spacing * 0.5, spacing) - spacing * 0.5;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	float edge = max(abs(cell.x), dot(abs(cell), normalize(vec2(1.0, 1.732))));
	return 1.0 - smoothstep(0.016, 0.052, abs(edge - 0.48));
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.30;
	float r = length(p);
	float mask = 1.0 - smoothstep(0.99, 1.025, r);
	float depth = sqrt(max(0.0, 1.0 - r * r));
	float rim = pow(1.0 - depth, 3.0);
	float edge = exp(-pow((r - 0.99) * 95.0, 2.0));
	// Curved lattice and sliding specular ribbons suggest an icy shell.
	vec2 curved = p / (0.55 + depth * 0.45);
	float lattice = hex_edge(curved * 8.0 + vec2(0.0, effect_time * 0.07));
	float ribbon = pow(max(0.0, cos(p.x * 4.0 + p.y * 2.0 - effect_time * 0.55)), 22.0);
	float highlight = exp(-length((p - vec2(-0.43, -0.57)) * vec2(2.6, 4.0)) * 4.0);
	float damage = 1.0 - integrity;
	float fractures = pow(1.0 - abs(sin(atan(p.y, p.x) * 11.0 + sin(r * 35.0) * 0.45)), 35.0);
	fractures *= smoothstep(0.48, 0.90, r) * damage;
	vec2 hit = vec2(cos(impact_angle), sin(impact_angle));
	float distance_to_hit = length(p - hit * 0.88);
	float shock = exp(-pow((distance_to_hit - (1.0 - impact) * 0.85) * 18.0, 2.0)) * impact;
	float alpha = 0.026 + rim * 0.21 + edge * 0.74 + lattice * (0.075 + rim * 0.15);
	alpha += ribbon * rim * 0.10 + highlight * 0.32 + fractures * 0.28 + shock * 0.65;
	vec3 color = mix(vec3(0.18, 0.52, 0.72), vec3(0.73, 0.97, 1.0), clamp(edge + highlight + shock + fractures, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha, 0.0, 0.80) * strength * mask);
}
