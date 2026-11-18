#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[27];} source_params;
uniform sampler2D uMap;
#define uRimCol (source_params.data[1].xyz)
#define uLightDir (source_params.data[2].xyz)
#define uLayerCol (vec3[5](source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz,source_params.data[6].xyz,source_params.data[7].xyz))
#define uBoxCol (source_params.data[8].xyz)
#define uFootY (source_params.data[9].x)
#define uRimPx (source_params.data[10].x)
#define uLift (source_params.data[11].x)
#define uOpacity (source_params.data[12].x)
#define uWarm (source_params.data[13].x)
#define uFloor (source_params.data[14].x)
#define uGhost (source_params.data[15].x)
#define uGhostCol (source_params.data[16].xyz)
#define uPropCol (source_params.data[17].xyz)
#define uPropCol2 (source_params.data[18].xyz)
#define uHaloCol (source_params.data[19].xyz)
#define uGhostA (source_params.data[20].x)
#define uHaloA (source_params.data[21].x)
#define uHaloPx (source_params.data[22].x)
#define uPropK (source_params.data[23].x)
#define uPropEdge (source_params.data[24].x)
#define uHairOn (source_params.data[25].x)
#define uHairCol (source_params.data[26].xyz)
layout(location=0) in vec2 vUv;
layout(location=1) in float vWy;
layout(location=0) out vec4 probeColor;



























 
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float ringA(vec2 uv, vec2 dx, vec2 dy, float r) {
  float s = 0.0;
  for (int i = 0; i < 8; i++) { float an = float(i) * 0.7854; s += texture(uMap, uv + (dx * cos(an) + dy * sin(an)) * r).a; }
  return s / 8.0;
}
void sourceMain() {

  vec2 dx = dFdx(vUv), dy = dFdy(vUv);
  vec4 t = texture(uMap, vUv);

  float a = t.a;
  if (uGhost > 0.5) {


    float halo = ringA(vUv, dx, dy, uHaloPx) * 0.6 + ringA(vUv, dx, dy, uHaloPx * 0.5) * 0.4;
    halo *= 1.0 - a;
    if (a < 0.01 && halo < 0.01) discard;
    float v = a > 0.001 ? t.r / a : 0.0, m = a > 0.001 ? t.g / a : 0.0;


    vec3 body = uGhostCol * (0.58 + 0.62 * v);
    float bA = a * uGhostA * (0.92 + 0.16 * v);

    float mk = clamp(m * 2.0, 0.0, 1.0);
    vec3 prop = mix(uPropCol2, uPropCol, smoothstep(0.6, 0.9, m)) * (0.75 + 0.4 * v);
    float pA = a * 0.97 * uPropK;
    if (uPropEdge > 0.0) {
      float mr = 0.0;
      for (int i = 0; i < 8; i++) { float an = float(i) * 0.7854; vec4 q = texture(uMap, vUv + (dx * cos(an) + dy * sin(an)) * 1.8); mr += q.a > 0.001 ? q.g / q.a : 0.0; }
      float edgeP = clamp(mr / 8.0 * 2.0 - m * 2.0, 0.0, 1.0) * uPropEdge;
      body *= 1.0 - 0.45 * edgeP;
      bA = mix(bA, a * 0.95, edgeP);
    }
    float Ab = mix(bA, pA, mk);
    vec3 Cb = mix(body, prop, mk);

    float inner = ringA(vUv, dx, dy, uRimPx * 1.6);
    float eA = clamp(a - inner, 0.0, 1.0) * 0.75 * (1.0 - mk);
    float hA = halo * uHaloA;
    vec3 P = uHaloCol * hA; float A = hA;
    P = Cb * Ab + P * (1.0 - Ab); A = Ab + A * (1.0 - Ab);
    P = vec3(1.0, 0.97, 0.9) * eA + P * (1.0 - eA); A = eA + A * (1.0 - eA);

    A *= mix(0.6, 1.0, smoothstep(0.0, 0.08, vWy - uFootY));
    probeColor = vec4(P / max(A, 1e-4), A * uOpacity);
    return;
  }
  if (a < 0.01) discard;
  float v = t.r / a, m = t.g / a;


  vec3 play = uLayerCol[1];
  float Lroad = pow(max(luma(play), 1e-6), 1.0 / 3.0);
  float Lcap = max(pow(max(luma(uLayerCol[4]), 1e-6), 1.0 / 3.0) + 0.03, Lroad + 0.08);
  float Lmain = min(max(Lroad + 0.18 * uLift, uFloor), Lcap);
  float Lb = max(0.0, Lmain + (v - 0.42) * 0.5);
  vec3 hue = mix(play, uRimCol, 0.5);
  hue /= max(luma(hue), 1e-6);
  vec3 body = hue * Lb * Lb * Lb;

  vec3 box = uBoxCol * (0.55 + 0.7 * v);


  vec3 wDark = vec3(0.070, 0.042, 0.042), wCoatLo = vec3(0.175, 0.125, 0.070), wCoatHi = vec3(0.283, 0.188, 0.080), wFace = vec3(0.62, 0.42, 0.20);
  vec3 warm = mix(wDark, wCoatLo, smoothstep(0.15, 0.45, v));
  warm = mix(warm, wCoatHi, smoothstep(0.45, 0.62, v));
  warm = mix(warm, wFace, smoothstep(0.62, 0.8, v));
  body = mix(body, warm, uWarm);
  vec3 col = mix(body, box, m);
  if (uHairOn > 0.5) { float hk = 1.0 - smoothstep(0.12, 0.3, abs(m - 0.5)); col = mix(col, uHairCol * (0.78 + 0.3 * v), hk); }



  vec2 L = normalize(vec2(uLightDir.x * 0.9, 0.7));
  float out1 = texture(uMap, vUv + (dx * L.x + dy * L.y) * uRimPx).a;
  float edge = clamp(a - out1, 0.0, 1.0);

  vec3 rimC = mix(uRimCol * 0.95, vec3(0.79, 0.552, 0.254), uWarm);
  col = mix(col, rimC, edge * (1.0 - m) * 0.55);

  float foot = smoothstep(0.0, 0.06, vWy - uFootY);
  col = mix(mix(col, play * 1.4 + uRimCol * 0.04, 0.45), col, foot);
  probeColor = vec4(col, a * uOpacity);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
