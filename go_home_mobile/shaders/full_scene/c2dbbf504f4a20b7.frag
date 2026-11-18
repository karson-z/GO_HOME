#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;
uniform sampler2D map;
#define diffuse (source_params.data[1].xyz)
#define opacity (source_params.data[2].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

void sourceMain(){probeColor=texture(map,vUv)*vec4(diffuse,opacity);}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(map,vec2(0.5)).x);}
