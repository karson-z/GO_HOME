#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[4];} source_params;
uniform sampler2D uNoise;
#define uTime (source_params.data[1].x)
#define uLightCol (source_params.data[2].xyz)
#define uStrength (source_params.data[3].x)
layout(location=0) in vec2 vUv;
layout(location=1) in vec3 vWorld;
layout(location=0) out vec4 probeColor;








void sourceMain() {

  float acr = (vUv.x - 0.5) * 3.2;
  float across = exp(-acr * acr);
  float along = smoothstep(0.0, 0.25, vUv.y) * (1.0 - smoothstep(0.55, 1.0, vUv.y));
  float n = texture(uNoise, vec2(vUv.x * 0.8 + uTime * 0.01, vUv.y * 0.6 - uTime * 0.04)).r;
  float a = across * along * (0.45 + 0.9 * n) * uStrength;
  probeColor = vec4(uLightCol * a, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
