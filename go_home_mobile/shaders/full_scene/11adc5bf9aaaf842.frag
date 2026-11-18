#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[67];} source_params;
uniform sampler2D uNoise;
uniform sampler2D uMask;
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
#define uFadeAll (source_params.data[58].x)
#define uFadeAlpha (source_params.data[59].x)
#define uRim (source_params.data[60].x)
#define uMist (source_params.data[61].x)
#define uLayerShift (source_params.data[62].x)
#define uEgP (source_params.data[63].xyzw)
#define uEgU (source_params.data[64].x)
#define uEgOld (source_params.data[65].xyz)
#define cameraPosition (source_params.data[66].xyz)
layout(location=0) in float vEgSide;
layout(location=1) in vec3 vLit;
layout(location=2) in vec3 vO;
layout(location=3) in float vSide;
layout(location=4) in vec2 vSunUv;
layout(location=5) in vec4 vTint;
layout(location=6) in vec2 vUv;
layout(location=7) in vec3 vW;
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










vec3 egMix(vec3 a, vec3 b, float k) {
  vec3 p = pow(max(a, vec3(0.0)), vec3(1.0 / 3.0)), q = pow(max(b, vec3(0.0)), vec3(1.0 / 3.0));
  vec3 m = mix(p, q, k);
  return k >= 1.0 ? b : m * m * m;
}









void sourceMain() {
  vec4 m = texture(uMask, vUv);
  float a = m.r;
  float w = max(fwidth(a), 1e-3);
  a = clamp((a - 0.5) / w + 0.5, 0.0, 1.0);


  float farFade = uFadeAlpha * (1.0 - uFarK) * max(uFadeAll, 1.0 - smoothstep(-32.0, -16.0, vO.z));
  a *= 1.0 - farFade;
  if (a < 0.01) discard;
  vec3 col = layerColor(mix(vW.z, vO.z, 0.75) + uLayerShift) * vTint.rgb;

  float lit = 1.0 - texture(uMask, vUv + vSunUv * 0.006).r;
  col += uRimCol * lit * uRim * 0.16 * vSide * uLightAmt;
  float ffd = ffDark(vW);
  col = mistOver(col, vW, uMist * (1.0 - ffd * 0.9));
  {
    vec2 Lc = vec2(0.82, 0.57);
    float cl = dot(vW.xy - vO.xy, Lc) / 0.5;

    vec3 c = mix(vec3(0.0273, 0.0382, 0.0409), vec3(0.0497, 0.0742, 0.0369), smoothstep(-0.5, 0.5, cl));
    c = mix(c, vec3(0.2747, 0.2384, 0.0648), clamp(lit * 1.1, 0.0, 1.0) * 0.32);
    col = egMix(col, mix(col, c * vTint.rgb, smoothstep(-6.0, -5.0, vO.z)), uEgU);
  }
  {
    float U = clamp(uEgU * 1.50, 0.0, 1.0) * (1.0 - smoothstep(uEgP.x - 22.0, uEgP.x - 14.0, vO.x));
    
    float pn = texture(uNoise, vO.xy * 0.31).g;
    float zf = smoothstep(-34.0, -8.0, vO.z);
    vec3 base = mix(vec3(0.0168, 0.0242, 0.0284), vec3(0.0437, 0.0612, 0.0423), smoothstep(-0.6, 0.7, vEgSide + (pn - 0.5) * 0.8));
    col = egMix(col, mix(col, base, 0.5 + 0.5 * zf), U);

    float sun = smoothstep(-0.25, 1.25, vEgSide + (pn - 0.5) * 0.7);

    col = mix(col, mix(vec3(0.4342, 0.2542, 0.0482), vec3(0.9216, 0.6724, 0.2086), lit), sun * (0.04 + 0.96 * lit) * pow(U, 1.4) * zf);
  }
col *= mix(1.0, uDarkMul, ffd);
  col += vLit * (0.3 + 1.2 * lit);
  probeColor = vec4(col, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x+texture(uMask,vec2(0.5)).x);}
