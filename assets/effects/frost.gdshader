shader_type canvas_item;
uniform float effect_time = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float effect_age = 0.0;
uniform float pulse_interval = 0.5;
uniform float ward = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.25;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = effect_time;
	float mist = noise(p * 6.0 + vec2(t * 0.18, -t * 0.12));
	float cracks = pow(1.0 - abs(sin(a * 15.0 + sin(r * 24.0 + mist * 2.0) * 0.3)), 25.0);
	cracks *= smoothstep(0.1, 0.5, r) * (1.0 - smoothstep(0.78, 0.95, r));
	float ice = noise(p * 29.0 + mist * 0.55);
	float rim = exp(-pow((r - 0.99) * 100.0, 2.0));
	float rim_glow = exp(-pow((r - 0.97) * 23.0, 2.0));
	float inner_ring = exp(-pow((r - 0.83) * 115.0, 2.0));
	float rune = smoothstep(0.5, 0.8, cos(a * 24.0 + t * 0.45)) * inner_ring;
	float wave_phase = fract(effect_age / max(pulse_interval, 0.1));
	float wave_r = wave_phase * 0.96;
	float wave = exp(-pow((r - wave_r) * 42.0, 2.0)) * (1.0 - wave_phase) * 0.20;
	float fog = pow(noise(p * 4.0 + vec2(sin(t * 0.22), t * 0.20)), 2.0);
	float tendrils = pow(max(0.0, sin(a * 7.0 + r * 9.0 - t * 0.8)), 6.0) * fog;
	float facets = pow(max(0.0, ice - 0.56), 2.0) * 0.45;
	float bloom = smoothstep(0.0, 0.45, effect_age);
	float fill = (0.035 + mist * 0.10 + facets + tendrils * 0.16) * (1.0 - smoothstep(0.78, 1.0, r));
	float spokes = pow(max(0.0, cos(a * 6.0)), 60.0) * (1.0 - smoothstep(0.10, 0.68, r)) * 0.09;
	float alpha = fill * bloom + rim * (0.65 + ward * 0.20) + rim_glow * 0.10 + inner_ring * 0.14 + rune * 0.29 + cracks * 0.26 * bloom + wave + spokes;
	vec3 color = mix(vec3(0.13, 0.37, 0.53), vec3(0.66, 0.95, 1.0), clamp(rim + rune + cracks + wave * 2.0 + facets * 4.0, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha, 0.0, 0.87) * strength * (1.0 - smoothstep(1.0, 1.025, r)));
}
