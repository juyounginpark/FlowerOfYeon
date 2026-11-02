shader_type canvas_item;
render_mode unshaded;

uniform vec2 ripple_center_px = vec2(640.0, 341.32);
uniform vec2 surface_size = vec2(1280.0, 644.0);
uniform float ink_opacity : hint_range(0.0, 1.0) = 0.44;
uniform float ink_brightness : hint_range(0.0, 1.0) = 0.5;
uniform float wave_pixels : hint_range(0.0, 16.0) = 8.0;

#include "res://shaders/lotus_ripples.gdshaderinc"

void fragment() {
	vec2 screen_px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 p = (screen_px - ripple_center_px) / min(surface_size.x, surface_size.y);
	float radius = length(p);
	float phase = lotus_ripple_phase(radius);
	vec2 direction = p / max(radius, 0.0001);
	float amplitude = wave_pixels * (0.65 + 0.35 * exp(-radius * 1.2));
	vec2 displacement_px = direction * cos(phase) * amplitude
		+ vec2(sin(phase) * 1.2, cos(phase) * 0.6);
	// Derivatives keep the displacement in screen pixels, including atlas UVs.
	vec2 displaced_uv = UV + dFdx(UV) * displacement_px.x + dFdy(UV) * displacement_px.y;
	vec4 ink = texture(TEXTURE, clamp(displaced_uv, vec2(0.001), vec2(0.999)));
	ink.rgb *= ink_brightness;
	ink.a *= ink_opacity;
	COLOR = ink;
}
