shader_type canvas_item;
uniform float ink_time=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fibre(vec2 p){return noise(p)*.55+noise(p*2.03)*.28+noise(p*4.07)*.17;}
float bloom(vec2 uv,vec2 centre,float delay,float seed){
    float t=max(0.0,ink_time-delay);
    float growth=1.0-exp(-t*2.5);
    vec2 p=(uv-centre)/vec2(.31,.115);
    float uneven=(fibre(uv*vec2(65,95)+seed)-.5)*.38;
    float edge=length(p)+uneven;
    float core=1.0-smoothstep(growth-.12,growth+.06,edge);
    float seep=(1.0-smoothstep(growth,growth+.22,edge))*.25;
    return max(core,seep)*smoothstep(0.0,.07,t);
}
float drop(vec2 uv,vec2 centre,float impact,float seed){
    float t=clamp(ink_time/impact,0.0,1.0);
    vec2 pos=vec2(centre.x+sin(t*3.0+seed)*.004,mix(-.04,centre.y,t*t));
    vec2 p=(uv-pos)/vec2(.005,.011+.013*t);
    return (1.0-smoothstep(.65,1.0,length(p)))*(1.0-step(impact,ink_time));
}
void fragment(){
    float opacity=COLOR.a;
    float a=bloom(UV,vec2(.36,.50),.48,1.0);
    a=max(a,bloom(UV,vec2(.54,.51),.66,7.0));
    a=max(a,bloom(UV,vec2(.66,.49),.84,13.0));
    float wet=drop(UV,vec2(.36,.50),.48,1.0)+drop(UV,vec2(.54,.51),.66,7.0)+drop(UV,vec2(.66,.49),.84,13.0);
    float grain=fibre(UV*vec2(380,220));
    float pooling=noise(UV*vec2(28,48));
    vec3 ink=mix(vec3(.025,.023,.020),vec3(.075,.067,.054),grain*.65+pooling*.15);
    COLOR=vec4(ink,clamp(max(wet,a*(.88+grain*.10)),0.0,1.0)*opacity);
}