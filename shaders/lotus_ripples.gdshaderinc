// Shared water field: the pond and floating ink use the same space and clock.
float lotus_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float lotus_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lotus_hash(i), lotus_hash(i + vec2(1, 0)), f.x),
		mix(lotus_hash(i + vec2(0, 1)), lotus_hash(i + vec2(1, 1)), f.x), f.y);
}
float lotus_ripple_phase(float radius) {
	return radius * 55.0 - TIME * 1.35 + lotus_noise(vec2(radius * 5.0, 0.0)) * 0.22;
}
