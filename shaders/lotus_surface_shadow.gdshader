shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 step_ = TEXTURE_PIXEL_SIZE * 6.0;
	float alpha = texture(TEXTURE, UV).a * 0.28;
	alpha += texture(TEXTURE, UV + vec2(step_.x, 0)).a * 0.12;
	alpha += texture(TEXTURE, UV - vec2(step_.x, 0)).a * 0.12;
	alpha += texture(TEXTURE, UV + vec2(0, step_.y)).a * 0.12;
	alpha += texture(TEXTURE, UV - vec2(0, step_.y)).a * 0.12;
	alpha += texture(TEXTURE, UV + step_).a * 0.06;
	alpha += texture(TEXTURE, UV - step_).a * 0.06;
	alpha += texture(TEXTURE, UV + vec2(step_.x, -step_.y)).a * 0.06;
	alpha += texture(TEXTURE, UV + vec2(-step_.x, step_.y)).a * 0.06;
	COLOR = vec4(0.12, 0.24, 0.25, alpha * 0.17);
}
