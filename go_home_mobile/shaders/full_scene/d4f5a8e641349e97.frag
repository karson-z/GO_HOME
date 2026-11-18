#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[65];} source_params;
uniform sampler2D uNoise;
uniform sampler2D uW0Tile;
#define uZenith (source_params.data[1].xyz)
#define uMid (source_params.data[2].xyz)
#define uHorizon (source_params.data[3].xyz)
#define uLightCol (source_params.data[4].xyz)
#define uSunDir (source_params.data[5].xyz)
#define uMoonDir (source_params.data[6].xyz)
#define uBodies (source_params.data[7].xyzw)
#define uSkyHalo (source_params.data[8].xyzw)
#define uSunrise (source_params.data[9].x)
#define uPoster (source_params.data[10].x)
#define uTilt (source_params.data[11].xy)
#define uTime (source_params.data[12].x)
#define uFogCol (source_params.data[13].xyz)
#define uRimCol (source_params.data[14].xyz)
#define uLightDir (source_params.data[15].xyz)
#define uLightAmt (source_params.data[16].x)
#define uLayerCol (vec3[5](source_params.data[17].xyz,source_params.data[18].xyz,source_params.data[19].xyz,source_params.data[20].xyz,source_params.data[21].xyz))
#define uLayerZ (float[5](source_params.data[22].x,source_params.data[23].x,source_params.data[24].x,source_params.data[25].x,source_params.data[26].x))
#define uFog (source_params.data[27].xyzw)
#define uMistH (source_params.data[28].x)
#define uFarK (source_params.data[29].x)
#define uMistDist (source_params.data[30].x)
#define uRoadClean (source_params.data[31].x)
#define uFarHz (source_params.data[32].x)
#define uGroundCtl (source_params.data[33].xyz)
#define uFogLow (source_params.data[34].x)
#define uRimCtl (source_params.data[35].xyzw)
#define uSunAnchor (source_params.data[36].xyz)
#define uGlowN (int(source_params.data[37].x))
#define uDarkX (source_params.data[38].xyzw)
#define uDarkK (source_params.data[39].x)
#define uDarkMul (source_params.data[40].x)
#define uGlowPos (vec4[8](source_params.data[41].xyzw,source_params.data[42].xyzw,source_params.data[43].xyzw,source_params.data[44].xyzw,source_params.data[45].xyzw,source_params.data[46].xyzw,source_params.data[47].xyzw,source_params.data[48].xyzw))
#define uGlowCol (vec3[8](source_params.data[49].xyz,source_params.data[50].xyz,source_params.data[51].xyz,source_params.data[52].xyz,source_params.data[53].xyz,source_params.data[54].xyz,source_params.data[55].xyz,source_params.data[56].xyz))
#define uGlowSoft (source_params.data[57].x)
#define uW0Win (source_params.data[58].xyzw)
#define uW0P (source_params.data[59].xyzw)
#define uW0Q (source_params.data[60].xyzw)
#define uW0R (source_params.data[61].xyzw)
#define uW0S (source_params.data[62].xyzw)
#define uW0Tip (source_params.data[63].x)
#define cameraPosition (source_params.data[64].xyz)
layout(location=0) in float vCov;
layout(location=1) in float vDark;
layout(location=2) in float vH;
layout(location=3) in vec3 vLit;
layout(location=4) in vec3 vO;
layout(location=5) in vec3 vW;
layout(location=6) in float vW0L;
layout(location=7) in float vW0St;
layout(location=0) out vec4 probeColor;
















vec3 toSky(vec3 d) { return vec3(d.x, d.y * uTilt.x - d.z * uTilt.y, d.z * uTilt.x + d.y * uTilt.y); }
vec3 skyGradient(vec3 d) {
  float h = d.y;
  float a = smoothstep(-0.03, 0.16, h);
  float b = smoothstep(0.1, 0.42, h);
  if (uPoster > 0.5) {
    float n = uPoster;
    a = floor(a * n + 0.5) / n;
    b = floor(b * n + 0.5) / n;
  }
  vec3 c = mix(uHorizon, uMid, a);
  c = mix(c, uZenith, b);

  vec2 dz = normalize(d.xz + vec2(1e-5));
  vec2 sz = normalize(uSunDir.xz + vec2(1e-5));
  float az = max(dot(dz, sz), 0.0);
  float band = exp(-abs(h - max(uSunDir.y, -0.02) * 0.6) * 9.0) * pow(az, uSkyHalo.x);
  c += uLightCol * band * uBodies.y * uSkyHalo.y;

  float cm = max(dot(d, uMoonDir), 0.0);
  c += uLightCol * pow(cm, 6.0) * uBodies.z * 0.12;
  return c;
}



























float ffDark(vec3 W) {
  float kx = smoothstep(uDarkX.x - uDarkX.z, uDarkX.x, W.x) * (1.0 - smoothstep(uDarkX.y, uDarkX.y + uDarkX.w, W.x));

  float kz = smoothstep(-26.0, -9.0, W.z);
  return kx * kz * uDarkK;
}
vec3 ffLight(vec3 W, vec3 N, float wrapK) {
  vec3 s = vec3(0.0);
  for (int i = 0; i < uGlowN; i++) {
    vec3 Lp = uGlowPos[i].xyz - W;
    float d = length(Lp);
    float R = max(uGlowPos[i].w, 1e-3);
    float g = clamp((R - d) / (R * 0.55), 0.0, 1.0);
    g = g * g * (3.0 - 2.0 * g);
    float gt = max(1.0 - d / R, 0.0);
    g = mix(g, gt * gt * gt, uGlowSoft);
    s += uGlowCol[i] * g * (wrapK + (1.0 - wrapK) * max(dot(N, Lp / max(d, 1e-3)), 0.0));
  }
  return s;
}

vec3 skyOnGround(vec3 W, float flr) {
  if (uGroundCtl.x <= 0.0) return vec3(0.0);
  float zk = smoothstep(-8.0, -3.0, W.z) * mix(1.0, 0.25, smoothstep(-1.5, 9.0, W.z));

  float a = texture(uNoise, W.xz * vec2(0.083, 0.47) + vec2(0.13, 0.71)).r;
  float a2 = texture(uNoise, W.xz * vec2(0.21, 1.13) + vec2(0.59, 0.29)).b;
  float b = texture(uNoise, W.xz * vec2(0.61, 2.9) + 0.37).g;
  float pk = 0.3 + 1.4 * (a * 0.4 + a2 * 0.35 + b * 0.25);
  float ns = (W.x - uSunAnchor.x) / 10.0;
  float warmK = exp(-ns * ns) * (1.0 - smoothstep(-1.0, 8.0, W.z));

  vec3 skyC = mix(mix(vec3(0.34, 0.40, 0.50), vec3(0.42, 0.42, 0.44), uSunrise), vec3(0.52, 0.41, 0.29), warmK);
  return skyC * 0.05 * uGroundCtl.x * flr * zk * pk;
}
vec3 layerColor(float z) {
  if (z >= uLayerZ[0]) return uLayerCol[0];
  for (int i = 0; i < 4; i++) {
    if (z >= uLayerZ[i + 1]) {
      float k = (z - uLayerZ[i + 1]) / (uLayerZ[i] - uLayerZ[i + 1]);
      return mix(uLayerCol[i + 1], uLayerCol[i], k);
    }
  }
  return mix(uLayerCol[4], uHorizon, clamp((uLayerZ[4] - z) / 260.0, 0.0, uFarHz));
}
vec3 mistOver(vec3 col, vec3 W, float amt) {
  vec3 Vd = normalize(W - cameraPosition);
  float d = length(cameraPosition - W);
  float hgt = max(W.y - uFog.z, 0.0);
  float wisp = texture(uNoise, W.xz * vec2(0.018, 0.05) + vec2(uTime * 0.012, 0.0)).r;
  float wisp2 = texture(uNoise, W.xy * vec2(0.03, 0.08) + vec2(-uTime * 0.008, uTime * 0.003)).g;
  float layerH = (0.6 + uFog.y * 7.0) * uMistH;
  float mist = uFog.x * uFog.w * exp(-hgt / layerH) * smoothstep(8.0, 70.0, d) * (0.55 + 0.9 * wisp * wisp2);
  mist += uFog.x * 0.22 * smoothstep(40.0, 300.0, d) * uMistDist;
  float dense = smoothstep(0.5, 0.78, uFog.x);
  mist += dense * (0.62 * smoothstep(12.0, 75.0, d) + 0.35 * exp(-hgt / (layerH * 1.6)) * smoothstep(6.0, 30.0, d)) * (0.7 + 0.6 * wisp);

  mist *= 1.0 - uRoadClean * smoothstep(-9.0, -3.0, W.z);
  mist = clamp(mist * amt, 0.0, 0.95);
  vec3 sv = toSky(Vd);
  float sc = pow(max(dot(sv, uLightDir), 0.0), 12.0);
  vec3 fogC = mix(uFogCol, skyGradient(sv), 0.35 * mix(1.0, smoothstep(0.0, 0.1, sv.y), uFogLow)) + uLightCol * sc * 0.25 * uLightAmt;
  return mix(col, fogC, mist);
}
    







float w0St = 0.5;
float w0L = 0.0;
float w0Wk = 0.0;
float w0Win(float x) { return smoothstep(uW0Win.x, uW0Win.y, x) * (1.0 - smoothstep(uW0Win.z, uW0Win.w, x)); }

float w0Light(vec3 W, out float st) {
  vec4 tf = texture(uW0Tile, vec2(-W.x / 4.0, 46.0 / (22.0 - min(W.z, 20.0))));
  st = tf.r * 0.72 + tf.b * 0.28;

  float p = texture(uW0Tile, W.xz / vec2(14.0, 9.0) + 0.13).g * 0.65 + texture(uW0Tile, W.xz / vec2(31.0, 37.0) + 0.57).g * 0.35;
  float m2 = texture(uW0Tile, W.xz / vec2(6.0, 5.0) + 0.21).g;
  float L = (0.12 + 1.0 * p) * (0.68 + 0.64 * smoothstep(0.32, 0.68, m2));

  float rk = 1.0 - smoothstep(0.9, 2.1, abs(W.z - 0.1));
  L = max(L, rk * uW0Q.w * (0.6 + 0.8 * texture(uW0Tile, W.xz / vec2(7.0, 3.0)).g));

  L += (1.0 - smoothstep(-3.0, -1.5, W.z)) * smoothstep(-6.5, -3.8, W.z) * 0.22;

  L *= 1.0 - 0.55 * smoothstep(2.4, 8.0, W.z);
  L += (st - 0.5) * uW0P.x * smoothstep(0.05, 0.3, L) * (1.0 - smoothstep(0.7, 1.1, L));
  return L;
}

float w0Near(vec3 W) { return 1.0 - smoothstep(1.6, 7.5, length(uGlowPos[0].xz - W.xz)); }

float w0Behind(vec3 W) { return (1.0 - smoothstep(-2.6, -0.45, W.z)) * smoothstep(-6.5, -3.0, W.z) * (1.0 - smoothstep(1.2, 4.5, abs(W.x - uGlowPos[0].x))); }

vec3 w0Paint(vec3 col, float L, float st, vec3 W) {
  float k = smoothstep(uW0P.y, uW0P.z, L);
  float nr = w0Near(W);
  vec3 dark = col * uW0P.w * mix(uW0S.y, 1.0, nr) * vec3(0.88, 0.93, 1.1);
  vec3 lite = col * mix(uW0S.x, uW0Q.x, nr) * mix(vec3(0.86, 0.95, 1.18), vec3(0.95, 1.0, 1.1), nr);
  return mix(dark, lite, k) * (1.0 + (st - 0.5) * uW0Q.y) * (1.0 - uW0S.w * w0Behind(W));
}


  
void sourceMain() {

  float h = clamp(vH, 0.0, 1.0);

  vec3 c = layerColor(vO.z) + uZenith * 0.05 * (1.0 - h) * uRimCtl.w;

  c *= 1.0 + 0.12 * h * h;

  float ns = (vW.x - uSunAnchor.x) / 26.0;
  float nearSun = exp(-ns * ns);

  c += uRimCol * pow(h, 4.0) * (0.02 + 0.1 * nearSun) * uLightAmt * uRimCtl.y * mix(1.0, vCov, step(0.001, uGroundCtl.y));

  c += skyOnGround(vW, 1.0) * (0.4 + 1.3 * h * h) * mix(1.0, vCov, 0.5);
  c = w0Paint(c, vW0L + uW0Tip * h * h * smoothstep(0.15, 0.4, vW0L), vW0St, vO);
  float ffd = ffDark(vW);
  c = mistOver(c, vW, 1.0 - ffd * 0.9);
  c *= mix(1.0, uDarkMul, ffd);

  c += (1.0 - 0.5 * ffd) * vLit * mix(0.12 + 1.2 * h * h, 0.1 + 2.2 * h * h, uGlowSoft);
  c *= mix(vDark, 1.0, 0.35 * h * h * h);
  c *= mix(0.7, 2.1, smoothstep(0.62, 0.8, h)) * mix(vec3(1.0), vec3(0.94, 0.98, 1.08), smoothstep(0.62, 0.8, h));
  probeColor = vec4(c, 0.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x+texture(uW0Tile,vec2(0.5)).x);}
