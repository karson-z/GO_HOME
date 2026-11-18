#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;
uniform sampler2D uNoise;
#define uFogCol (source_params.data[1].xyz)
#define uTime (source_params.data[2].x)
layout(location=0) in float vK;
layout(location=1) in vec3 vW;
layout(location=0) out vec4 probeColor;


    
void sourceMain() {
  float n = texture(uNoise, vec2(vW.x * 0.02 + uTime * 0.006, vW.y * 0.06)).r;
  probeColor = vec4(uFogCol * 0.62, vK * (0.5 + 0.6 * n) * 0.6);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
