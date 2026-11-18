#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uK (source_params.data[1].x)
#define uLight (source_params.data[2].xyz)
layout(location=0) in vec2 vP;
layout(location=0) out vec4 probeColor;


  
void sourceMain() {
  float r = length(vP);
  float e = 1.0 - smoothstep(0.0, 1.0, r); float a = e * e;
  probeColor = vec4(uLight * a * uK, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
