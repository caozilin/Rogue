shader_type canvas_item;
uniform float effect_time = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.03) * 0.28 + noise(p * 4.07) * 0.13; }

void fragment() {
	vec2 p = (UV - vec2(0.64, 0.5)) * vec2(4.0, 3.0);
	float t = effect_time * 2.7 + seed;
	float n = fbm(p * 3.1 + vec2(t * 1.8, -t * 0.4));
	float detail = fbm(p * 8.0 + vec2(t * 3.0, -t));
	float sphere = length(p * vec2(1.0, 1.04));
	float body = 1.0 - smoothstep(0.65, 1.04, sphere + (n - 0.5) * 0.48);
	float tail_width = max(0.0, 0.48 - abs(p.y + sin(p.x * 5.0 + t) * 0.12));
	float trail = smoothstep(-2.25, -0.15, p.x) * (1.0 - smoothstep(-0.25, 0.15, p.x));
	float tail_mask = 1.0 - smoothstep(0.18, 0.82, abs(p.y + sin(p.x * 5.0 + t) * 0.12));
	float tongue = smoothstep(0.30, 0.66, n + tail_width * 0.5) * trail * tail_mask;
	float density = max(body, tongue * 0.88);
	float hot = clamp(body * (0.75 - sphere * 0.44) + detail * 0.60, 0.0, 1.0);
	vec3 color = mix(vec3(0.72, 0.085, 0.015), vec3(1.0, 0.46, 0.045), smoothstep(0.16, 0.64, hot));
	color = mix(color, vec3(1.0, 0.91, 0.52), smoothstep(0.62, 0.85, hot));
	color = mix(color, vec3(1.0, 0.98, 0.87), smoothstep(0.8, 1.0, hot));
	float filaments = pow(max(0.0, 1.0 - abs(detail - 0.53) * 13.0), 3.0) * body;
	color += vec3(0.23, 0.18, 0.06) * filaments;
	float glow = exp(-sphere * sphere * 2.8) * 0.38;
	float alpha = max(density * 0.93, glow);
	color = mix(vec3(1.0, 0.29, 0.018), color, smoothstep(0.05, 0.7, density));
	COLOR = vec4(color, alpha * smoothstep(0.0, 0.07, 1.0 - abs(p.y) / 1.5));
}
