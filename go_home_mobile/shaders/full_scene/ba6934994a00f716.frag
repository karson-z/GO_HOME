#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[7];} source_params;
uniform sampler2D uNoise;
#define uFogCol (source_params.data[1].xyz)
#define uHorizon (source_params.data[2].xyz)
#define uTime (source_params.data[3].x)
#define uFarK (source_params.data[4].x)
#define uDarkX (source_params.data[5].xyzw)
#define uDarkK (source_params.data[6].x)
layout(location=0) in float vK;
layout(location=1) in float vUp;
layout(location=2) in vec3 vW;
layout(location=0) out vec4 probeColor;


      
  
void sourceMain() {
  float up = clamp(vUp, 0.0, 1.0);
  float n = texture(uNoise, vec2(vW.x * 0.035 + uTime * 0.006, up * 0.35 + vW.z * 0.1)).r;
  float kx = smoothstep(uDarkX.x - uDarkX.z, uDarkX.x, vW.x) * (1.0 - smoothstep(uDarkX.y, uDarkX.y + uDarkX.w, vW.x));
  float a = (1.0 - smoothstep(0.55, 1.0, up)) * (0.75 + 0.5 * n) * uFarK * (1.0 - 0.85 * kx * uDarkK);
  probeColor = vec4(mix(uFogCol, uHorizon, 0.2), clamp(a * vK, 0.0, 0.4));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
