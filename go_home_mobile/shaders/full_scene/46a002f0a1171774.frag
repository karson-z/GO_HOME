#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uLightCol (source_params.data[1].xyz)
#define uLightAmt (source_params.data[2].x)
layout(location=0) in float vL;
layout(location=1) in float vS;
layout(location=0) out vec4 probeColor;
#define USE_INSTANCING 

   
void sourceMain() {
  float band = sin(clamp(vS, 0.0, 1.0) * 3.14159);
  float a = band * band * (1.0 - vL) * (1.0 - vL) * 0.16 * uLightAmt;
  probeColor = vec4(uLightCol, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
