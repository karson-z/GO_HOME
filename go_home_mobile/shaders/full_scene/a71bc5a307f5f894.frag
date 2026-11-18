#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;

#define uLightCol (source_params.data[1].xyz)
#define uK (source_params.data[2].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;


  
void sourceMain() {
  float e = 1.0 - abs(vUv.x * 2.0 - 1.0);
  float a = smoothstep(0.0, 0.8, e) * smoothstep(0.0, 0.85, vUv.y) * (1.0 - smoothstep(0.92, 1.0, vUv.y));
  probeColor = vec4(uLightCol * a * uK, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
