shader_type canvas_item;
render_mode unshaded;
uniform vec2 contact_uv = vec2(0.5, 0.98);
void fragment() {
	float travel = UV.y;
	vec2 uv = vec2(UV.x, contact_uv.y * (1.0 - travel));
	float loosen = smoothstep(0.0, 0.65, travel);
	uv.x += (sin(UV.y * 59.0 - TIME * 1.85) * 0.006
		+ sin(UV.y * 117.0 + TIME * 1.1) * 0.002) * loosen;
	uv.y += sin(UV.y * 78.0 - TIME * 1.85) * 0.0025 * loosen;
	vec4 ink = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	float bands = 0.92 + 0.08 * sin(UV.y * 145.0 - TIME * 1.85);
	ink.rgb = mix(ink.rgb, vec3(0.34, 0.46, 0.44), 0.22);
	ink.a *= (1.0 - smoothstep(0.02, 0.98, travel)) * 0.30 * bands;
	COLOR = ink;
}
