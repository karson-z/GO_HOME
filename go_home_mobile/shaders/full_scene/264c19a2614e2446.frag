#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[4];} source_params;

#define uFarCol (source_params.data[1].xyz)
#define uX (source_params.data[2].xy)
#define uY (source_params.data[3].xy)
layout(location=0) in vec2 vL;
layout(location=0) out vec4 probeColor;


   
void sourceMain() {
  float a = 1.0 - smoothstep(uY.y, uY.x, vL.y);
  a *= smoothstep(uX.x, uX.x + 0.8, vL.x) * (1.0 - smoothstep(uX.y - 0.8, uX.y, vL.x));
  probeColor = vec4(uFarCol * 0.35, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
