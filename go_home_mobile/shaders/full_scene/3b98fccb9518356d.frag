#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[5];} source_params;
uniform sampler2D uNoise;
#define uFogCol (source_params.data[1].xyz)
#define uK (source_params.data[2].x)
#define uAmt (source_params.data[3].x)
#define uC (source_params.data[4].xy)
layout(location=0) in vec3 vW;
layout(location=0) out vec4 probeColor;


    

void sourceMain() {

  vec2 P = vW.xz - uC;
  float r = length(P * vec2(1.0, 1.6));
  float n = texture(uNoise, vW.xz * vec2(0.5, 0.9)).a * 0.7 + texture(uNoise, vW.xz * vec2(1.7, 2.6)).b * 0.3;
  float th = smoothstep(0.0, 1.0, r / max(0.4 + uK * 1.2, 1e-3)) * 0.9 + uK * 0.55;
  float a = smoothstep(th, th + 0.1, n) * (1.0 - uK) * uAmt;
  if (a < 0.01) discard;
  probeColor = vec4(uFogCol * 1.18, a * 0.85);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
