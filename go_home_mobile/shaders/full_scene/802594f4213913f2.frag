#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uLightCol (source_params.data[1].xyz)
#define uLightAmt (source_params.data[2].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

   void sourceMain() { probeColor = vec4(uLightCol, vUv.x * vUv.y * 0.14 * uLightAmt); }
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
