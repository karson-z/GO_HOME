#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uCol (source_params.data[1].xyz)
#define uA (source_params.data[2].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

  
void sourceMain() { vec2 p = vUv * 2.0 - 1.0; float r = length(p); float core = exp(-r * r * 40.0); float glow = exp(-r * r * 9.0) * (1.0 - smoothstep(0.8, 1.0, r));

  probeColor = vec4(uCol * (core * 1.6 + glow * 0.4) * uA, 1.0); }
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
