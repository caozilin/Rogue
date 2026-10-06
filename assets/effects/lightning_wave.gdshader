shader_type canvas_item;
uniform float effect_time = 0.0;
uniform float radius = 0.1;
uniform float extent = 800.0;
uniform float strength = 1.0;
uniform float final_wave = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float jagged = sin(a * 67.0 + effect_time * 29.0) * 2.5 / extent;
	float distance_to_wall = abs(r - radius + jagged) * extent;
	float core = exp(-pow(distance_to_wall / 2.4, 2.0));
	float corona = exp(-distance_to_wall / (12.0 + final_wave * 8.0));
	float braid_distance = abs((r - radius) * extent + 13.0 + sin(a * 43.0 - effect_time * 23.0) * 8.0);
	float braid = exp(-pow(braid_distance / 1.8, 2.0));
	// A raised second contour and electric filaments give the expanding ring a wall silhouette.
	float raised = abs(length(p + vec2(0.0, 28.0 / extent)) - radius) * extent;
	float crest = exp(-pow(raised / 2.0, 2.0));
	float threads = pow(max(0.0, sin(a * 137.0 + effect_time * 17.0)), 24.0);
	float wall = exp(-distance_to_wall / 30.0) * threads;
	float lattice = pow(max(0.0, sin(a * 21.0 + r * 45.0 - effect_time * 11.0)), 15.0);
	float afterglow = exp(-max(0.0, radius - r) * extent / 48.0) * step(r, radius);
	float alpha = core * 0.8 + corona * (0.18 + lattice * 0.25) + braid * 0.55 + crest * 0.38 + wall * 0.30 + afterglow * 0.03;
	vec3 color = mix(vec3(0.48, 0.23, 0.95), vec3(0.68, 0.96, 1.0), clamp(core + braid * 0.5 + lattice * 0.5, 0.0, 1.0));
	COLOR = vec4(color, alpha * strength);
}
