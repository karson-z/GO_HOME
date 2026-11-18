#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[36];} source_params;
uniform sampler2D uMap;
#define uRimCol (source_params.data[1].xyz)
#define uLightDir (source_params.data[2].xyz)
#define uLayerCol (vec3[5](source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz,source_params.data[6].xyz,source_params.data[7].xyz))
#define uAccent (source_params.data[8].xyz)
#define uFootY (source_params.data[9].x)
#define uFootH (source_params.data[10].x)
#define uClipY (source_params.data[11].x)
#define uRimPx (source_params.data[12].x)
#define uLift (source_params.data[13].x)
#define uOpacity (source_params.data[14].x)
#define uFadeIn (source_params.data[15].x)
#define uWarm (source_params.data[16].x)
#define uWake (source_params.data[17].x)
#define uSleepProp (source_params.data[18].x)
#define uFloor (source_params.data[19].x)
#define uMainL (source_params.data[20].x)
#define uRimBoost (source_params.data[21].x)
#define uClipSoft (source_params.data[22].x)
#define uFloorAdd (source_params.data[23].x)
#define uDarkSpread (source_params.data[24].x)
#define uSleepDim (source_params.data[25].x)
#define uEdgeK (source_params.data[26].x)
#define uClipWave (source_params.data[27].x)
#define uClipT (source_params.data[28].x)
#define uWetCol (source_params.data[29].xyz)
#define uWatch (source_params.data[30].x)
#define uSpark (source_params.data[31].x)
#define uBandPx (source_params.data[32].x)
#define uBandL (source_params.data[33].x)
#define uFilmRimPx (source_params.data[34].x)
#define uFilmRimK (source_params.data[35].x)
layout(location=0) in vec2 vUv;
layout(location=1) in float vWx;
layout(location=2) in float vWy;
layout(location=0) out vec4 probeColor;
































  
vec3 oklch(float L, float C, float h) {
  float a = C * cos(h), b = C * sin(h);
  float l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  float m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  float s_ = L - 0.0894841775 * a - 1.2914855480 * b;
  l_ = l_ * l_ * l_; m_ = m_ * m_ * m_; s_ = s_ * s_ * s_;
  return max(vec3(4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
                 -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
                 -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_), 0.0);
}
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
 
void sourceMain() {

  vec2 dx = dFdx(vUv), dy = dFdy(vUv);


#ifdef MIP_GRAD
#define TEX(uv) textureGrad(uMap, uv, dx, dy)
#else
#define TEX(uv) texture(uMap, uv)
#endif
  vec4 t = TEX(vUv);
  float a = t.a;

  float clipY = uClipY + uClipWave * sin(6.2831853 * vWx / 0.5 + 3.0 * uClipT);
  if (a < 0.01 || vWy < clipY - uClipSoft) discard;
  float clipA = uClipSoft > 0.0 ? smoothstep(clipY - uClipSoft, clipY + uClipSoft, vWy) : 1.0;

  float v = t.r / a, m = t.g / a, wm = uWatch > 0.5 && uSpark < 0.5 ? t.b / a : 0.0;
  float sk = uSpark > 0.5 ? t.b / a : 0.0;
  vec3 play = uLayerCol[1];



  float Lroad = pow(max(luma(play), 1e-6), 1.0 / 3.0);

  float Lcap = max(pow(max(luma(uLayerCol[4]), 1e-6), 1.0 / 3.0) + 0.03, Lroad + 0.08);

  float Lmain = min(max(Lroad + 0.18 * uLift, uFloor + uFloorAdd), Lcap);

  Lmain = max(Lmain, uMainL);


  float Lceil = max(min(Lcap, Lmain + 0.15), Lmain + 0.04);
  float room = Lceil - Lmain;
  float spread = (v - 0.42) * 0.5;
  float Lawake = Lmain + (spread > 0.0 ? room * (1.0 - exp(-spread / room)) : spread * uDarkSpread);

  float Lsleep = uSleepDim < 0.0 ? Lroad + (v - 0.42) * 0.25 : max(Lawake - uSleepDim, Lroad);
  float Lb = max(0.0, mix(Lsleep, Lawake, uWake));

  vec2 L = normalize(vec2(uLightDir.x * 0.9, 0.7));
  float ax = TEX(vUv + dx).a - TEX(vUv - dx).a;
  float ay = TEX(vUv + dy).a - TEX(vUv - dy).a;
  vec2 n = -vec2(ax, ay);
  float facing = length(n) > 1e-4 ? smoothstep(0.15, 0.6, dot(normalize(n), L)) : 0.0;

  if (uBandL > 0.0) {
    float out3 = TEX(vUv + (dx * L.x + dy * L.y) * uBandPx).a;
    Lb += uBandL * clamp(a - out3, 0.0, 1.0) * facing;
  }
  vec3 hue = mix(play, uRimCol, 0.5);
  hue /= max(luma(hue), 1e-6);
  vec3 body = hue * Lb * Lb * Lb;

  vec3 wDark = vec3(0.070, 0.042, 0.042), wLo = vec3(0.175, 0.125, 0.070), wHi = vec3(0.283, 0.188, 0.080), wTop = vec3(0.50, 0.34, 0.16);
  vec3 warm = mix(wDark, wLo, smoothstep(0.15, 0.4, v));
  warm = mix(warm, wHi, smoothstep(0.4, 0.56, v));
  warm = mix(warm, wTop, smoothstep(0.56, 0.75, v));
  body = mix(body, warm, uWarm);



  vec3 accHue = mix(vec3(1.0), uAccent / max(luma(uAccent), 1e-6), 0.5);
  float La = Lb + 0.10 * mix(0.4, 1.0, uWake);
  vec3 acc = accHue * La * La * La;
  vec3 col = mix(body, acc, m);

  if (wm > 0.5) {
    float Llit = Lmain + room * (1.0 - exp(-0.06 / room));
    float face = step(0.48, v);
    float Lw = min(mix(Lmain + 0.04, Llit + 0.12, face), min(0.72, Lcap));
    Lw = mix(Lw, Lw - 0.06, 1.0 - uWake);
    col = oklch(Lw, mix(0.10, 0.05, face), radians(mix(80.0, 85.0, face)));
    m = 1.0;
  }


  if (sk > 0.5) {
    float Lfog = pow(max(luma(uLayerCol[4]), 1e-6), 1.0 / 3.0);
    float ivory = step(0.48, v);
    float Ls = min(0.80, Lfog + 0.35);
    col = oklch(Ls, mix(0.10, 0.02, ivory), radians(mix(80.0, 85.0, ivory)));
    m = 1.0;
  }


  float out1 = TEX(vUv + (dx * L.x + dy * L.y) * uRimPx).a;
  float edge = clamp(a - out1, 0.0, 1.0) * facing * (uEdgeK < 0.0 ? uWake : uEdgeK);
  vec3 rimC = mix(uRimCol * 0.95, vec3(0.79, 0.552, 0.254), uWarm);
  col = mix(col, rimC, edge * (1.0 - m) * (0.55 + 0.30 * uRimBoost));

  float foot = smoothstep(0.0, uFootH, vWy - uFootY);
  col = mix(mix(col, play * 1.4 + uRimCol * 0.04, 0.45), col, foot);

  if (uClipY > -1e4) col = mix(col, uWetCol, 0.2 * (1.0 - smoothstep(clipY, clipY + 0.04, vWy)));
  

  {
    float fr = 0.0;
    for (int i = 0; i < 8; i++) { float an = float(i) * 0.7854; fr += texture(uMap, vUv + (dx * cos(an) + dy * sin(an)) * uFilmRimPx).a; }
    float fe = clamp((a - fr / 8.0) * 1.6, 0.0, 1.0);
    float Lf = dot(uLayerCol[4], vec3(0.2126, 0.7152, 0.0722));
    vec3 fc = vec3(1.0, 0.95, 0.84) * max(0.9, Lf * 1.9);
    col = mix(col, fc, fe * uFilmRimK * (0.6 + 0.4 * facing));
  }
  probeColor = vec4(col, a * uOpacity * uFadeIn * clipA);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
