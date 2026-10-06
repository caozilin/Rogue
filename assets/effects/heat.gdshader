shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float effect_time = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask = (1.0 - smoothstep(0.25, 1.0, length(p))) * 0.32;
	vec2 warp = vec2(sin(p.y * 22.0 + effect_time * 8.0), cos(p.x * 18.0 - effect_time * 6.0)) * 0.0018 * mask;
	vec3 scene = texture(screen_texture, SCREEN_UV + warp).rgb;
	COLOR = vec4(scene + vec3(0.04, 0.012, 0.0) * mask, mask);
}
