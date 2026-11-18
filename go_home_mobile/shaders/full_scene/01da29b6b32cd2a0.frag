#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uFogCol (source_params.data[1].xyz)
#define uFarK (source_params.data[2].x)
layout(location=0) in vec2 vU;
layout(location=0) out vec4 probeColor;

  
void sourceMain() {
  float h = smoothstep(0.0, 0.35, vU.x) * (1.0 - smoothstep(0.35, 1.0, vU.x));
  float v = 1.0 - smoothstep(0.72, 1.0, vU.y);
  probeColor = vec4(uFogCol, 0.14 * h * v * uFarK);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
