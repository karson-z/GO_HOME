#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[11];} source_params;
uniform sampler2D uBlob;
uniform sampler2D uCloud;
#define uFFw (source_params.data[1].xyz)
#define uOrigin (source_params.data[2].xy)
#define uTopY (source_params.data[3].x)
#define uBotY (source_params.data[4].x)
#define uTime (source_params.data[5].x)
#define uFade (source_params.data[6].x)
#define uHMin (source_params.data[7].x)
#define uTop (source_params.data[8].xyz)
#define uMid (source_params.data[9].xyz)
#define uBot (source_params.data[10].xyz)
layout(location=0) in float vA;
layout(location=1) in vec2 vU;
layout(location=2) in vec3 vW;
layout(location=3) in float vZ;
layout(location=0) out vec4 probeColor;
#define USE_INSTANCING 

















void sourceMain() {
  vec4 s = texture(uBlob, vU);

  vec2 P = vW.xy - uOrigin;
  float n = texture(uCloud, P * vec2(0.021, 0.034) + uTime * 0.004).r;
  float n2 = texture(uCloud, P * vec2(0.083, 0.121) - uTime * 0.006).r;
  float den = s.r * (0.2 + 1.3 * n) + (n2 - 0.5) * 0.45;
  float a = smoothstep(0.3, 1.4, den) * smoothstep(1.2, 8.0, vZ) * vA * uFade * 0.75;
  if (a < 0.004) discard;

  float h = max(clamp((vW.y - uBotY) / (uTopY - uBotY), 0.0, 1.0), uHMin);
  vec3 lit = (h > 0.5 ? mix(uMid, uTop, (h - 0.5) * 2.0) : mix(uBot, uMid, h * 2.0)) * 1.08;
  vec3 c = lit * (0.8 + 0.28 * n);
  float d = length((vW - uFFw).xy);
  c += vec3(1.0, 0.82, 0.5) * exp(-d * d / 5.0) * 0.1;
  probeColor = vec4(c, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uBlob,vec2(0.5)).x+texture(uCloud,vec2(0.5)).x);}
