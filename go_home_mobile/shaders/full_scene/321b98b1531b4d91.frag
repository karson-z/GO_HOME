#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;

#define uLight (source_params.data[1].xyz)
layout(location=0) in vec2 sourcePointCoord;
layout(location=1) in float vA;
layout(location=0) out vec4 probeColor;



 
void sourceMain() {
  float d = length(sourcePointCoord - 0.5) * 2.0;
  float a = 1.0 - smoothstep(0.0, 1.0, d);
  probeColor = vec4(uLight * a * a * vA, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
