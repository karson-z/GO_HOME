#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[1];} source_params;
uniform sampler2D uMap;

layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

  void sourceMain() { if (texture(uMap, vUv).a < 0.2) discard; probeColor = vec4(0.0); }
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
