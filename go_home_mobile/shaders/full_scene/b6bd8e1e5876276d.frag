#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[13];} source_params;
uniform sampler2D uEdge;
uniform sampler2D uCloud;
#define uFFs (source_params.data[1].xy)
#define uA (source_params.data[2].x)
#define uB (source_params.data[3].x)
#define uAsp (source_params.data[4].x)
#define uTime (source_params.data[5].x)
#define uH (source_params.data[6].x)
#define uOut (source_params.data[7].x)
#define uVeil (source_params.data[8].x)
#define uLow (source_params.data[9].x)
#define uTop (source_params.data[10].xyz)
#define uMid (source_params.data[11].xyz)
#define uBot (source_params.data[12].xyz)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

















void sourceMain() {
  float x = vUv.x * uAsp;

  float n1 = texture(uCloud, vec2(x * 0.31, vUv.y * 0.5 + uTime * 0.01)).r - 0.5;
  float n2 = texture(uCloud, vec2(x * 1.13 + 3.0, vUv.y * 1.9 - uTime * 0.02)).r - 0.5;
  float top = uA + (texture(uEdge, vec2(x * 0.16 + 0.3 + n1 * 0.02, 0.5)).r - 0.35) * 0.11 + n1 * 0.17 + n2 * 0.06;
  float n3 = texture(uCloud, vec2(x, vUv.y) * 0.62 + vec2(uTime * 0.012, 0.4)).r - 0.5;
  float n4 = texture(uCloud, vec2(x, vUv.y) * 1.7 + vec2(-uTime * 0.02, 0.1)).r - 0.5;
  float bot = uB + (n3 * 0.34 + n4 * 0.12);
  float a = smoothstep(0.0, 0.16 + 0.26 * (n1 + 0.5), top - vUv.y) * smoothstep(0.0, 0.36, vUv.y - bot);


  float lowThin = mix(1.0, mix(0.3, 1.5, vUv.y), uLow);
  float veil = clamp(uVeil * (0.88 + 0.3 * (n3 + 0.5)) * 1.12 * lowThin, 0.0, 1.0);
  a = max(a * uOut, veil);
  if (a < 0.004) discard;
  vec3 c = uH > 0.5 ? mix(uMid, uTop, (uH - 0.5) * 2.0) : mix(uBot, uMid, uH * 2.0);

  c *= 0.9 + 0.32 * (n1 + 0.5) * (n2 + 0.75);

  vec2 d = (vUv - uFFs) * vec2(uAsp, 1.0);
  c += vec3(1.0, 0.8, 0.48) * exp(-dot(d, d) / 0.05) * 0.1;
  probeColor = vec4(c, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uEdge,vec2(0.5)).x+texture(uCloud,vec2(0.5)).x);}
