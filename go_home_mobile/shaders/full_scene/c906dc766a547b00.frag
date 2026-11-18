#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uK (source_params.data[1].x)
#define uLight (source_params.data[2].xyz)
layout(location=0) in vec2 vP;
layout(location=0) out vec4 probeColor;


  
void sourceMain() {
  float r = length(vP);
  float q = (r - 0.8) / 0.15; float a = exp(-q * q) * 0.34 * (1.0 - smoothstep(0.84, 1.04, r));
  probeColor = vec4(uLight * a * uK, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
