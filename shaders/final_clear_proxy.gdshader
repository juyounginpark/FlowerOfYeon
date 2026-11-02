shader_type canvas_item;

uniform float clear_glow : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(ink.rgb, vec3(1.0, 0.96, 0.78), clear_glow * 0.85), ink.a);
}
