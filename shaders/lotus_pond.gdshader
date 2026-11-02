shader_type canvas_item;
render_mode unshaded;
uniform vec2 origin = vec2(0.5, 0.53);
uniform vec2 resolution = vec2(1280.0, 644.0);
#include "res://shaders/lotus_ripples.gdshaderinc"
void fragment() {
	vec2 px = UV * resolution;
	float wash = lotus_noise(UV * vec2(4.0, 6.0)) * 0.5 + lotus_noise(UV * 15.0) * 0.2;
	vec3 paper = vec3(0.86, 0.84, 0.74);
	vec3 water = mix(vec3(0.43, 0.56, 0.54), vec3(0.27, 0.41, 0.42), smoothstep(0.0, 1.0, UV.y));
	vec3 color = mix(paper, water, smoothstep(0.00, 0.54, UV.y));
	color += (wash - 0.32) * 0.075;
	// Equal world-space axes: circular ripples seen directly from above.
	vec2 p = (UV - origin) * resolution / min(resolution.x, resolution.y);
	float radius = length(p);
	float phase = lotus_ripple_phase(radius);
	float rings = sin(phase);
	float line = pow(max(0.0, rings), 30.0);
	float echo = pow(max(0.0, sin(phase + 0.55)), 32.0);
	float envelope = smoothstep(0.12, 0.24, radius) * exp(-radius * 2.0);
	color += (line * 0.055 - echo * 0.024) * envelope;
	color += (lotus_hash(px) - 0.5) * 0.032;
	color += (lotus_noise(vec2(px.x * 0.6, px.y * 0.15)) - 0.5) * 0.024;
	float vignette = smoothstep(0.28, 0.76, length((UV - 0.5) * vec2(0.9, 0.65)));
	COLOR = vec4(color - vignette * 0.06, 1.0);
}
