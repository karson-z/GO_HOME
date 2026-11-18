#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[18];} source_params;
uniform sampler2D uMap;
uniform sampler2D uMask;
#define uOpacity (source_params.data[1].x)
#define uFootY (source_params.data[2].x)
#define uLayerCol (vec3[5](source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz,source_params.data[6].xyz,source_params.data[7].xyz))
#define uRimCol (source_params.data[8].xyz)
#define uLightDir (source_params.data[9].xyz)
#define uWarm (source_params.data[10].x)
#define uVer (source_params.data[11].x)
#define uTime (source_params.data[12].x)
#define uBodyA (source_params.data[13].x)
#define uSeed (source_params.data[14].x)
#define uExpo (source_params.data[15].x)
#define uFilmRimPx (source_params.data[16].x)
#define uFilmRimK (source_params.data[17].x)
layout(location=0) in vec2 vUv;
layout(location=1) in float vWx;
layout(location=2) in float vWy;
layout(location=0) out vec4 probeColor;


   
   
      
  
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float ringA(vec2 uv, vec2 dx, vec2 dy, float r) { float s = 0.0; for (int i = 0; i < 8; i++) { float an = float(i) * 0.7854; s += texture(uMap, uv + (dx * cos(an) + dy * sin(an)) * r).a; } return s / 8.0; }
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32 + uSeed); return fract(p.x * p.y); }
void sourceMain() {
  vec2 dx = dFdx(vUv), dy = dFdy(vUv);
  vec4 t = texture(uMap, vUv);
  float a = t.a;
  float haloR = uVer > 0.5 && uVer < 1.5 ? 7.0 : uVer > 1.5 && uVer < 2.5 ? 14.0 : 0.0;
  float halo = haloR > 0.0 ? (ringA(vUv, dx, dy, haloR) * 0.6 + ringA(vUv, dx, dy, haloR * 0.5) * 0.4) * (1.0 - a) : 0.0;
  if (a < 0.01 && halo < 0.01) discard;
  vec3 src = a > 0.001 ? t.rgb / a : vec3(0.0);
  vec3 lin = pow(clamp(src, 0.0, 1.0), vec3(2.2));
  vec4 mk4 = texture(uMask, vUv);
  float mk = clamp(max(mk4.r, mk4.g) * 1.4, 0.0, 1.0);

  float Lfog = luma(uLayerCol[4]);
  vec3 warmK = mix(vec3(1.0), uRimCol / max(luma(uRimCol), 1e-4), 0.22 * uWarm);
  float E = uExpo * clamp(0.75 + Lfog * 0.6, 0.85, 1.35);
  vec3 lit = lin * warmK * E;


  float mA = clamp(mk4.r * 1.4, 0.0, 1.0), mS = clamp(mk4.g * 1.4, 0.0, 1.0);
  vec3 g1 = vec3(luma(lin));
  vec3 accC = max(g1 + (lin - g1) * 1.45, 0.0) * E * 1.1;
  accC *= max(1.0, max(0.3, Lfog * 0.8) / max(luma(accC), 1e-3));
  vec3 spkC = mix(lin, vec3(1.0, 0.97, 0.9), 0.55) * max(1.3, Lfog * 2.2);
  vec3 prop = mS > mA ? spkC : accC;

  vec2 L = normalize(vec2(uLightDir.x * 0.9, 0.7));
  float ax = texture(uMap, vUv + dx).a - texture(uMap, vUv - dx).a;
  float ay = texture(uMap, vUv + dy).a - texture(uMap, vUv - dy).a;
  vec2 n = -vec2(ax, ay);
  float facing = length(n) > 1e-4 ? smoothstep(0.15, 0.6, dot(normalize(n), L)) : 0.0;
  float outL = texture(uMap, vUv + (dx * L.x + dy * L.y) * 1.5).a;
  float edgeL = clamp(a - outL, 0.0, 1.0) * facing;
  vec3 C; float A;
  vec3 cream = vec3(1.0, 0.86, 0.66);
  if (uVer < 0.5) {
    C = mix(lit, vec3(1.0, 0.93, 0.8) * max(0.7, Lfog * 1.3), edgeL * 0.55 * (1.0 - mk));
    A = a;
  } else {
    vec3 body;


    if (uVer < 1.5) { vec3 g0 = vec3(luma(lit)); vec3 sat = max(g0 + (lit - g0) * 1.15, 0.0); body = mix(sat * 1.06, cream * max(0.7, Lfog * 1.35) * (0.65 + 0.7 * luma(lin) / 0.25), 0.12); }
    else if (uVer < 2.5) {
      body = mix(lit * 1.15, cream * max(0.5, Lfog) * (0.6 + 0.8 * luma(lin) / 0.25), 0.4);
      float flow = sin(vWy * 9.0 - uTime * 2.2 + sin(vWx * 7.0 + uTime * 0.7) * 1.4);
      body *= 1.0 + 0.7 * smoothstep(0.5, 1.0, flow);
    } else body = mix(lit, vec3(luma(lit)), 0.55) * 1.05;
    C = mix(body, prop, mk);
    A = mix(uBodyA, 1.0, mk) * a;
  }
  vec3 Pm = C * A;


  {
    float fe = clamp((a - ringA(vUv, dx, dy, uFilmRimPx)) * 1.6, 0.0, 1.0) * (1.0 - mk);
    vec3 rc = vec3(1.0, 0.95, 0.84) * max(0.9, Lfog * 1.9);
    float rk = uFilmRimK * (uVer > 0.5 && uVer < 1.5 ? 1.0 : uVer > 1.5 && uVer < 2.5 ? 0.7 : 0.6 + 0.4 * facing);
    float eA = fe * rk;
    Pm = rc * eA + Pm * (1.0 - eA); A = eA + A * (1.0 - eA);
  }
  if (halo > 0.0) {
    float hA = halo * (uVer < 1.5 ? 0.6 : 0.22);
    vec3 hc = (uVer < 1.5 ? vec3(1.0, 0.62, 0.25) : vec3(1.0, 0.9, 0.7)) * max(0.7, Lfog * 1.5);
    Pm = Pm + hc * hA * (1.0 - A); A = A + hA * (1.0 - A);
  }

  if (uVer > 0.5) {
    float gS = 0.0;
    for (int i = 0; i < 8; i++) { float an = float(i) * 0.7854; gS += texture(uMask, vUv + (dx * cos(an) + dy * sin(an)) * 4.5).g; }
    gS = clamp(gS / 8.0 * 2.0, 0.0, 1.0) * (1.0 - mS);
    float tw = 0.85 + 0.15 * sin(uTime * 3.0 + vWx * 20.0);
    vec3 gc = vec3(1.0, 0.97, 0.88) * max(1.2, Lfog * 2.2);
    Pm += gc * gS * 0.7 * tw * (1.0 - A * 0.5); A = max(A, gS * 0.7);
  }

  if (uVer > 1.5 && uVer < 2.5) {
    vec2 w = vec2(vWx, vWy - uTime * 0.18);
    vec2 cell = floor(w / 0.07);
    vec2 f = fract(w / 0.07);
    float r = h21(cell);
    vec2 c0 = vec2(0.2 + 0.6 * h21(cell + 7.1), 0.2 + 0.6 * r);
    float d = length(f - c0);
    float tw = 0.5 + 0.5 * sin(uTime * (2.0 + 3.0 * r) + r * 40.0);
    float dot0 = smoothstep(0.22, 0.0, d) * step(0.6, r) * tw * clamp(a * 0.6 + halo * 2.0, 0.0, 1.0);
    vec3 dc = vec3(1.0, 0.93, 0.75) * max(1.0, Lfog * 1.8);
    Pm += dc * dot0 * 1.2; A = max(A, dot0);
  }

  float up = vWy - uFootY;
  if (uVer > 0.5 && uVer < 2.5) {
    float melt = smoothstep(0.0, 0.26, up);

    float mf = uVer < 1.5 ? 0.55 : 0.3;
    A *= mix(mf, 1.0, melt); Pm *= mix(mf, 1.0, melt);
    float pool = exp(-up * up / 0.01) * (a > 0.01 ? 0.5 : halo * 1.5);
    Pm += vec3(1.0, 0.85, 0.6) * max(0.7, Lfog * 1.5) * pool * 0.5; A = max(A, pool * 0.5);
  } else if (uVer > 2.5) {
    float melt = smoothstep(0.0, 0.08, up);
    A *= mix(0.5, 1.0, melt); Pm *= mix(0.5, 1.0, melt);
  }
  probeColor = vec4(Pm / max(A, 1e-4), clamp(A, 0.0, 1.0) * uOpacity);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x+texture(uMask,vec2(0.5)).x);}
