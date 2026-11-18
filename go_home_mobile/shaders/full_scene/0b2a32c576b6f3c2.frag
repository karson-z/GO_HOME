#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uFogCol (source_params.data[1].xyz)
#define uLightCol (source_params.data[2].xyz)
layout(location=0) in float vA;
layout(location=1) in vec2 vUv2;
layout(location=0) out vec4 probeColor;
#define USE_INSTANCING 

 
 
void sourceMain() {
  vec2 q = (vUv2 - 0.5) * 2.0;
  float a = 1.0 - smoothstep(0.55, 1.0, length(q));
  if (a < 0.02 || vA < 0.01) discard;
  probeColor = vec4(mix(uFogCol, uLightCol, 0.3) * 1.14, a * vA * 0.92);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
