shader_type canvas_item;
uniform float progress = 0.0;
uniform float effect_time = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform int mode = 0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.8;
	float n = noise(p * 15.0 + vec2(effect_time * 7.0, -effect_time * 3.0));
	float r = length(p);
	float strength = 0.0;
	if (mode == 0) {
		float head = -1.35 + min(1.0, progress * 2.8) * 2.7;
		float angle = mod(atan(p.y, p.x) - head + 3.141593, 6.283186) - 3.141593;
		float trail = smoothstep(-1.35, -0.1, angle) * (1.0 - smoothstep(-0.02, 0.08, angle));
		float edge = abs(r - (0.95 + (n - 0.5) * 0.03));
		strength = exp(-edge * edge * 550.0) * trail;
		strength += exp(-edge * edge * 40.0) * trail * 0.28;
	} else if (mode == 1) {
		float edge = abs(r - clamp(progress * 2.0, 0.05, 1.1));
		strength = exp(-edge * edge * 400.0) * (0.6 + n * 0.4);
		strength += exp(-r * r * 9.0) * (1.0 - progress) * 0.55;
	} else {
		float diagonal = min(abs(p.x - p.y * 1.25), abs(p.x + p.y * 1.25));
		strength = exp(-diagonal * diagonal * 250.0) * smoothstep(1.4, 0.4, r) * (0.65 + n * 0.35);
		strength += exp(-r * r * 5.0) * 0.3;
	}
	vec3 color = mix(tint.rgb, vec3(1.0, 0.98, 0.88), smoothstep(0.6, 1.0, strength));
	COLOR = vec4(color, clamp(strength, 0.0, 1.0) * (1.0 - progress));
}
