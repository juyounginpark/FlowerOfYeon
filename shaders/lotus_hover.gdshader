shader_type canvas_item;

varying vec4 petal_tint;

void vertex() {
	petal_tint = COLOR;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	// A zero red vertex channel marks an unselected petal during hover.
	if (petal_tint.r < 0.5) {
		float gray = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
		ink.rgb = mix(ink.rgb, vec3(gray), 0.9) * 0.9;
	} else {
		ink.rgb *= petal_tint.rgb;
	}
	COLOR = vec4(ink.rgb, ink.a * petal_tint.a);
}
