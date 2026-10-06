shader_type canvas_item;

uniform vec2 rect_origin = vec2(0.0);
uniform vec2 rect_size = vec2(96.0);
uniform float phase = 0.0;
uniform float idle_time = 0.0;
uniform float walk_weight = 0.0;
uniform float travel_lean = 0.0;
uniform float rush_weight = 0.0;
uniform int profile = 0; // 0: armored humanoid, 1: creature, 2: flying, 3: robe.

void vertex() {
	vec2 p = (VERTEX - rect_origin) / rect_size;
	float side = smoothstep(0.46, 0.54, p.x) * 2.0 - 1.0;
	float step = sin(phase) * side;
	float feet = smoothstep(0.61, 0.88, p.y);
	float legs = 1.0 - smoothstep(0.26, 0.45, abs(p.x - 0.5));
	float arms = smoothstep(0.18, 0.34, abs(p.x - 0.5)) * smoothstep(0.18, 0.35, p.y) * (1.0 - smoothstep(0.60, 0.79, p.y));
	float cloth = smoothstep(0.40, 0.82, p.y);
	float stride = walk_weight * (profile == 1 ? 0.035 : 0.045);
	// Feet alternate while the dense mesh keeps the torso and head intact.
	VERTEX.y -= max(0.0, step) * feet * legs * rect_size.y * stride;
	VERTEX.x += step * feet * legs * rect_size.x * stride * 0.48;
	VERTEX.x -= sin(phase) * side * arms * rect_size.x * walk_weight * 0.025;
	VERTEX.x += sin(phase - p.y * 1.8) * cloth * rect_size.x * walk_weight * (profile == 3 ? 0.025 : 0.012);
	float body_bob = -abs(sin(phase)) * rect_size.y * walk_weight * (profile == 1 ? 0.016 : 0.020);
	VERTEX.y += body_bob + sin(idle_time * 2.1) * rect_size.y * 0.0035 * (1.0 - feet * 0.65);
	VERTEX.x += (1.0 - p.y) * rect_size.y * (travel_lean * walk_weight * 0.027 + travel_lean * rush_weight * 0.055);
	// Heavy bodies compress lightly as each foot bears weight.
	if (profile == 1) {
		VERTEX.x += (p.x - 0.5) * rect_size.x * sin(phase * 2.0) * walk_weight * 0.018;
	}
	if (profile == 2) {
		float wing = smoothstep(0.13, 0.42, abs(p.x - 0.5));
		float flap = sin(idle_time * 8.2 + phase * 0.18);
		VERTEX.x += side * wing * rect_size.x * flap * 0.065;
		VERTEX.y += wing * rect_size.y * flap * 0.047;
		VERTEX.y -= sin(idle_time * 3.0) * rect_size.y * 0.022;
	}
}
