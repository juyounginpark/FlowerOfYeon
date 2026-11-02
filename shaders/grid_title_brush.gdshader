shader_type canvas_item;
uniform float sweep=0.0;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
    vec4 pigment=texture(TEXTURE,UV);
    float edge=sweep+(sin(UV.y*65.0)+sin(UV.y*137.0))*.002;
    float reveal=1.0-smoothstep(edge-.012,edge,UV.x);
    COLOR=vec4(pigment.rgb,pigment.a*reveal*.82)*tint;
}
