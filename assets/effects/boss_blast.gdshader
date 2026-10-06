shader_type canvas_item;
uniform float progress = 0.0;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.57 + noise(p * 2.03) * 0.29 + noise(p * 4.07) * 0.14; }
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.62)) * 2.0;
	float t = progress * 3.8 + seed;
	float n = fbm(p * 5.0 + vec2(seed, t * 2.0));
	float fine = fbm(p * 14.0 + vec2(t, t * 3.0));
	float rise = progress * 0.5;
	float dist = length((p + vec2(0, rise)) / vec2(0.72, 0.58));
	float cloud = 1.0 - smoothstep(0.42, 1.02, dist + (n - 0.5) * 0.65);
	float column = (1.0 - smoothstep(0.08, 0.36, abs(p.x) + (n - 0.5) * 0.22)) * smoothstep(-0.9, -0.55, p.y) * (1.0 - smoothstep(0.04, 0.35, p.y));
	float density = max(cloud, column * 0.9);
	float hot = clamp(density * 0.45 + fine * 0.65 + (1.0 - progress) * 0.2, 0.0, 1.0);
	vec3 color = mix(vec3(0.48, 0.035, 0.007), vec3(1.0, 0.34, 0.018), smoothstep(0.15, 0.65, hot));
	color = mix(color, vec3(1.0, 0.85, 0.35), smoothstep(0.6, 0.85, hot));
	color = mix(color, vec3(1.0, 0.97, 0.84), smoothstep(0.83, 1.0, hot));
	float smoke = smoothstep(0.4, 0.95, progress) * (1.0 - smoothstep(0.2, 0.55, density));
	color = mix(color, vec3(0.19, 0.15, 0.14), smoke * 0.8);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x) * smoothstep(0.0, 0.08, UV.y);
	float fade = 1.0 - smoothstep(0.42, 1.0, progress);
	COLOR = vec4(color, density * fade * edge * 0.85);
}
