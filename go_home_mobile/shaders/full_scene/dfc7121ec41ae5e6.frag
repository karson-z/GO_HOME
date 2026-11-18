#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[7];} source_params;
uniform sampler2D uNoise;
#define uTime (source_params.data[1].x)
#define uFogCol (source_params.data[2].xyz)
#define uBase (source_params.data[3].x)
#define uThick (source_params.data[4].x)
#define uAmt (source_params.data[5].x)
#define uX (source_params.data[6].xyzw)
layout(location=0) in vec3 vW;
layout(location=0) out vec4 probeColor;


      

void sourceMain() {
  float h = vW.y - uBase;
  float edge = texture(uNoise, vec2(vW.x * 0.011 + uTime * 0.004, 0.37)).b;
  h -= (edge - 0.5) * uThick * 1.2;
  float prof = exp(-max(h, 0.0) / uThick) * smoothstep(-0.8, 0.1, h);
  float n1 = texture(uNoise, vec2(vW.x * 0.03 + uTime * 0.008 + uX.w, h * 0.04)).r;
  float n2 = texture(uNoise, vec2(vW.x * 0.08 - uTime * 0.012 + uX.w, h * 0.1)).g;
  float ends = smoothstep(uX.x, uX.x + uX.z, vW.x) * (1.0 - smoothstep(uX.y - uX.z, uX.y, vW.x));
  probeColor = vec4(uFogCol, uAmt * prof * ends * smoothstep(0.34, 0.7, n1 * 0.7 + n2 * 0.5));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
