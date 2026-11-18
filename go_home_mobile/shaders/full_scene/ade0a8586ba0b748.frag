#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[1];} source_params;


layout(location=0) out vec4 probeColor;

void sourceMain() { probeColor = vec4(0.006, 0.007, 0.012, 1.0); }
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
