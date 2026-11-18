#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;

#define uCol (source_params.data[1].xyz)
layout(location=0) out vec4 probeColor;

 void sourceMain() { probeColor = vec4(uCol, 1.0); }
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
