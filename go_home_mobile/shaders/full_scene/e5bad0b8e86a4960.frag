#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[5];} source_params;
uniform sampler2D uNoise;
#define uFogCol (source_params.data[1].xyz)
#define uLightCol (source_params.data[2].xyz)
#define uK (source_params.data[3].x)
#define uSeed (source_params.data[4].x)
layout(location=0) in vec2 vUv2;
layout(location=0) out vec4 probeColor;


    

void sourceMain() {

  float n = texture(uNoise, vec2(vUv2.x * 6.3 + uSeed, vUv2.y * 0.6 + uK * 0.5)).r;
  float n2 = texture(uNoise, vec2(vUv2.x * 17.1 - uSeed, vUv2.y * 1.3 - uK)).g;
  float top = 1.0 - (n - 0.3) * 1.1 - n2 * 0.25 - uK * 0.9;
  float d = top - vUv2.y;
  if (d < 0.0) discard;

  float root = smoothstep(0.0, 0.22, vUv2.y) * sin(vUv2.x * 3.1416);
  float a = smoothstep(0.0, 0.07, d) * root * mix(0.85, 0.4, vUv2.y) * (0.55 + n2 * 1.0) * (1.0 - uK * uK);
  vec3 col = mix(uFogCol * 1.12, uFogCol * 0.8 + uLightCol * 0.7, exp(-d * 9.0));
  probeColor = vec4(col, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
