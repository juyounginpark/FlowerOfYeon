shader_type canvas_item;
uniform sampler2D ink_mask : filter_linear, repeat_disable;
uniform float progress : hint_range(0.0,1.0)=0.0;
void fragment() {
	float mask=texture(ink_mask,UV).r;
	float rounding=smoothstep(0.0,.30,progress);
	vec2 p=UV-.5;
	vec2 warped=.5+p*(1.0+progress*.16*(1.0-dot(p,p)*2.0));
	vec4 scene=texture(TEXTURE,clamp(warped,vec2(0.0),vec2(1.0)));
	scene.rgb=mix(scene.rgb,vec3(.045,.065,.055),smoothstep(.45,1.0,progress));
	float alpha=mix(1.0,smoothstep(.025,.95,mask),rounding);
	alpha*=1.0-smoothstep(.72,1.0,progress);
	COLOR=vec4(scene.rgb,scene.a*alpha);
}
