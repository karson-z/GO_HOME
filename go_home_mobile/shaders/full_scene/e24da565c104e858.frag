#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[4];} source_params;

#define diffuse (source_params.data[1].xyz)
#define opacity (source_params.data[2].x)
#define alphaTest (source_params.data[3].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

void sourceMain(){probeColor=vec4(diffuse,opacity);if(probeColor.a<alphaTest)discard;}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
