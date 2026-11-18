#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[9];} source_params;
uniform sampler2D uMap;
#define uOpacity (source_params.data[1].x)
#define uFootY (source_params.data[2].x)
#define uGhostCol (source_params.data[3].xyz)
#define uHaloCol (source_params.data[4].xyz)
#define uGhostA (source_params.data[5].x)
#define uHaloA (source_params.data[6].x)
#define uHaloPx (source_params.data[7].x)
#define uRimPx2 (source_params.data[8].x)
layout(location=0) in vec2 vUv;
layout(location=1) in float vWx;
layout(location=2) in float vWy;
layout(location=0) out vec4 probeColor;


  
     
 
float ringA(vec2 uv, vec2 dx, vec2 dy, float r) { float s = 0.0; for (int i = 0; i < 8; i++) { float an = float(i) * 0.7854; s += texture(uMap, uv + (dx * cos(an) + dy * sin(an)) * r).a; } return s / 8.0; }
void sourceMain() {
  vec2 dx = dFdx(vUv), dy = dFdy(vUv);
  vec4 t = texture(uMap, vUv);
  float a = t.a;
  float halo = (ringA(vUv, dx, dy, uHaloPx) * 0.6 + ringA(vUv, dx, dy, uHaloPx * 0.5) * 0.4) * (1.0 - a);
  if (a < 0.01 && halo < 0.01) discard;
  float v = a > 0.001 ? t.r / a : 0.0;
  vec3 body = uGhostCol * (0.58 + 0.62 * v);
  float bA = a * uGhostA * (0.92 + 0.16 * v);
  float eA = clamp(a - ringA(vUv, dx, dy, uRimPx2 * 1.6), 0.0, 1.0) * 0.75;
  float hA = halo * uHaloA;
  vec3 P = uHaloCol * hA; float A = hA;
  P = body * bA + P * (1.0 - bA); A = bA + A * (1.0 - bA);
  P = vec3(1.0, 0.97, 0.9) * eA + P * (1.0 - eA); A = eA + A * (1.0 - eA);
  A *= mix(0.6, 1.0, smoothstep(0.0, 0.08, vWy - uFootY));
  probeColor = vec4(P / max(A, 1e-4), A * uOpacity);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
