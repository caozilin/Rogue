shader_type canvas_item;

uniform float remaining : hint_range(0.0, 1.0) = 0.0;
uniform bool disabled = false;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec2 direction = UV - vec2(0.5);
	// Clockwise from twelve o'clock: reveal the color as cooldown recovers.
	float angle = mod(atan(direction.x, -direction.y) + 6.2831853, 6.2831853) / 6.2831853;
	bool cooling = remaining > 0.0 && angle >= 1.0 - remaining;
	if (cooling || disabled) {
		float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
		pixel.rgb = vec3(gray) * (disabled ? 0.40 : 0.55);
	}
	if (!disabled && remaining > 0.0 && remaining < 1.0 &&
		abs(angle - (1.0 - remaining)) < 0.008 && length(direction) > 0.13) {
		pixel.rgb = vec3(0.80, 0.89, 0.98);
	}
	COLOR = pixel;
}
