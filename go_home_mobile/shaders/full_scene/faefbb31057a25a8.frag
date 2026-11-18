#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[6];} source_params;

#define uLightCol (source_params.data[1].xyz)
#define uCol (source_params.data[2].xyz)
#define uUseCol (source_params.data[3].x)
#define uFarK (source_params.data[4].x)
#define uFade (source_params.data[5].x)
layout(location=0) in vec2 sourcePointCoord;
layout(location=1) in float vA;
layout(location=0) out vec4 probeColor;



    

void sourceMain() {
  float d = length(sourcePointCoord - 0.5) * 2.0;
  float a = max(0.0, 1.0 - d);
  a *= a;
  probeColor = vec4(mix(uLightCol, uCol, uUseCol), a * vA * mix(1.0, uFarK, uFade));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
