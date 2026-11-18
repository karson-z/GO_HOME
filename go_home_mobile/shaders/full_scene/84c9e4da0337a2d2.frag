#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[1];} source_params;


layout(location=0) in float vH;
layout(location=1) in vec3 vRoot;
layout(location=2) in vec3 vTip;
layout(location=0) out vec4 probeColor;
#define USE_INSTANCING 

  
void sourceMain() {
  float h = clamp(vH, 0.0, 1.0);
  probeColor = vec4(mix(vRoot, vTip, h * h), 0.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
