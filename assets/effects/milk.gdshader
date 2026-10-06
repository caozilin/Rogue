shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform float effect_time = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform int mode = 0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float n = noise(p * 9.0 + vec2(effect_time * 4.0, -effect_time * 2.0));
 float a = 0.0; float core = 0.0;
 if (mode == 0) {
  float wave = sin(p.x*21.0-effect_time*27.0)*0.05;
  float width = abs(p.y-wave);
  a = (1.0-smoothstep(0.20+n*0.15,0.5,width)) * smoothstep(-1.0,-0.9,p.x) * (1.0-smoothstep(0.9,1.0,p.x));
  core = 1.0-smoothstep(0.02,0.20,width);
 } else {
  float r = length(p); float angle = atan(p.y,p.x);
  float edge = (mode == 1 ? 0.57+0.14*cos(angle*8.0+effect_time) : 0.60+(n-0.5)*0.24);
  edge *= smoothstep(0.0,0.18,progress)+0.1;
  a = 1.0-smoothstep(edge-0.06,edge+0.04,r);
  a *= 0.75+0.25*n;
  core = (1.0-smoothstep(0.0,edge,r)) * (1.0-progress);
 }
 a *= (1.0-smoothstep(0.55,1.0,progress));
 vec3 cream = mix(tint.rgb,vec3(1.0,0.96,0.82),0.30+n*0.40);
 cream = mix(cream,vec3(1.0,0.65,0.84),step(0.85,n)*0.7);
 COLOR = vec4(cream+core*0.5,a*tint.a);
}
