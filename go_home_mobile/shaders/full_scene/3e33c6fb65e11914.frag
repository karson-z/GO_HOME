#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[77];} source_params;
uniform sampler2D uNoise;
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
#define uSkyK (source_params.data[59].x)
#define uBark (source_params.data[60].xyz)
#define uRim (source_params.data[61].x)
#define uValue (source_params.data[62].x)
#define uMist (source_params.data[63].x)
#define uJitter (source_params.data[64].x)
#define uLayerShift (source_params.data[65].x)
#define uTrueZ (source_params.data[66].x)
#define uGrain (source_params.data[67].x)
#define uForm (source_params.data[68].x)
#define uSoilK (source_params.data[69].x)
#define uTint (source_params.data[70].xyz)
#define uTintK (source_params.data[71].x)
#define uCave (source_params.data[72].xy)
#define uCaveX (source_params.data[73].xyz)
#define uSqOy (source_params.data[74].x)
#define uSqOy2 (source_params.data[75].xy)
#define cameraPosition (source_params.data[76].xyz)
layout(location=0) in vec3 vNormalW;
layout(location=1) in vec3 vOrigin;
layout(location=2) in vec3 vWorld;
layout(location=0) out vec4 probeColor;
#define DOUBLE_SIDED 















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























void sourceMain() {
  vec3 V = normalize(cameraPosition - vWorld);
  float nl = length(vNormalW);
  vec3 N = nl > 1e-4 ? vNormalW / nl : V;
  #ifdef DOUBLE_SIDED
    N = (!gl_FrontFacing) ? N : -N;
  #endif
  float rimBoost = 1.0;
  #ifdef CLIP_CAVE
    float lx = vWorld.x - uCave.x;
    float ly = vWorld.y - uCave.y;
    float ay = arch(lx);
    if (ly < ay && lx > uCaveX.x) discard;
    rimBoost += (1.0 - smoothstep(ay, ay + 0.4, ly)) * smoothstep(uCaveX.y, uCaveX.z, lx) * 1.4;
  #endif
  float lz = mix(vWorld.z, vOrigin.z, 0.75 * (1.0 - uTrueZ)) + uLayerShift;
  
  vec3 col = layerColor(lz) * uValue;
  
  float ph = fract(sin(dot(floor(vOrigin.xz * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
  col *= 1.0 + uJitter * (ph * 2.0 - 1.0);
  col = mix(col, uTint, uTintK);
  if (uGrain > 0.0) {


    vec2 gp = N.y > 0.7 ? vWorld.xz * vec2(1.0, 2.2) : vWorld.xy;
    float g = texture(uNoise, gp * vec2(0.34, 0.09) + vWorld.z * 0.11).g * 0.6 + texture(uNoise, gp * vec2(1.1, 0.27)).b * 0.4;
    col *= 1.0 + (g - 0.5) * uGrain * 1.6;
  }
  col += uZenith * 0.05 * max(N.y, 0.0) * uRimCtl.w;

  vec2 toSun = normalize(uSunAnchor.xy - vWorld.xy + vec2(1e-3));
  col += skyOnGround(vWorld, smoothstep(0.25, 0.95, N.y)) * uSkyK * clamp(1.0 + 1.2 * N.x * toSun.x, 0.6, 1.35);
  vec2 L2 = normalize(mix(uLightDir.xy, uSunAnchor.xy - vWorld.xy, uRimCtl.z) + vec2(1e-4));
  vec2 N2 = normalize(N.xy + vec2(1e-4));
  float fres = 1.0 - abs(dot(N, V));
  float rimShape = smoothstep(0.84, 0.99, fres);
  rimShape *= 1.0 - 0.85 * smoothstep(0.75, 0.97, N.y);
  float facing = smoothstep(-0.1, 0.75, dot(N2, L2));
  float depthK = clamp(1.0 - (-vOrigin.z - 6.0) / 120.0, 0.25, 1.0);
  col += uRimCol * rimShape * facing * (uRim < 0.15 ? abs(uRim) : max(uRim, uRimCtl.x * smoothstep(-40.0, -20.0, vWorld.z))) * rimBoost * uLightAmt * depthK * 0.7;

  if (uForm > 0.0) col += uRimCol * uForm * uLightAmt * smoothstep(0.1, 0.95, dot(N2, L2)) * (1.0 - abs(N.z)) ;
  float barkN = 0.0;
  if (uBark.x + uBark.y > 0.0) {
    float b1 = texture(uNoise, vWorld.xy * vec2(1.3, 0.17) + vWorld.z * 0.07).g;
    float b2 = texture(uNoise, vWorld.xy * vec2(3.7, 0.45) + 0.31).r;
    barkN = mix(smoothstep(0.3, 0.72, b1 * 0.6 + b2 * 0.4), 0.55, smoothstep(1.2, 2.2, abs(vWorld.x - uBark.z)));
    vec2 toA = normalize(uSunAnchor.xy - vWorld.xy + vec2(1e-3));

    float side = smoothstep(-0.55, 0.6, dot(N.xy, toA));

    col += mix(mix(uZenith, uMid, 0.5) * 0.35, uLightCol, side) * uBark.x * (0.25 + 0.75 * side) * (0.35 + 0.9 * barkN);
  }
  float mistAmt = uMist;
  {
  vec3 Lk = normalize(vec3(uSunAnchor.x, uSunAnchor.y + 3.5, max(4.5, vWorld.z + 3.5)) - vWorld);
  float nl = dot(N, Lk);
  float n = texture(uNoise, vWorld.xy * vec2(0.35, 0.28) + vWorld.z * 0.08).g;
  vec3 c = mix(vec3(0.0037, 0.0044, 0.0080), vec3(0.0052, 0.0060, 0.0110), smoothstep(-0.100, 0.500, nl));
  c = mix(c, vec3(0.0086, 0.0103, 0.0185), smoothstep(0.660, 0.860, nl));
  c = mix(c, vec3(0.0242, 0.0284, 0.0452), smoothstep(0.840, 0.980, nl) * 0.200);
  c += vec3(0.0105, 0.0115, 0.0165) * 0.000 * smoothstep(0.35, 0.95, dot(N, normalize(vec3(-0.45, 0.62, 0.64))));
  if (0.000 > 0.0) {
    float up = smoothstep(0.45, 0.9, N.y);
    float side = smoothstep(0.2, 0.85, dot(N, normalize(vec3(-0.62, 0.5, 0.6))));
    float hi = mix(0.7, 1.15, smoothstep(1.0, 9.0, vWorld.y - uSqOy));
    float ledge = max(up * (0.75 + 0.5 * n), side * 0.55) * hi;
    c = mix(c, vec3(0.0612, 0.0723, 0.1119), clamp(ledge * 0.000, 0.0, 0.9));
  }
  c *= mix(0.78, 1.0, smoothstep(0.0, 1.0, vWorld.y - uSqOy));

  if (!(!gl_FrontFacing)) c *= 0.12;
  c *= 1.0 + 0.000 * (1.0 - smoothstep(0.1, 1.8, vWorld.y - uSqOy));
  c *= 1.0 - 0.000 * smoothstep(4.6, 6.2, vWorld.y - uSqOy);
  col = c * 0.620 * 0.960 + c * 0.620 * 0.080 * n;
}

  float ffd = ffDark(vWorld);
  col = mistOver(col, vWorld, mistAmt * (1.0 - ffd * 0.9));
  col *= mix(1.0, uDarkMul, ffd);
  vec3 ffl = ffLight(vWorld, N, 0.3);


  float flr = smoothstep(0.55, 0.95, N.y);
  float soil = mix(1.0, 0.25 + 1.5 * texture(uNoise, vWorld.xz * vec2(1.9, 0.7)).r * texture(uNoise, vWorld.xz * vec2(5.3, 1.7)).g * 2.0, uGlowSoft * flr * uSoilK);
  ffl = vec3(dot(ffl, vec3(0.3, 0.55, 0.15))) * vec3(0.92, 0.97, 1.08);
  col += ffl * (0.5 * (1.0 - 0.8 * N.z * N.z) + mix(1.6, 0.12, uRimCtl.z) * rimShape + 0.45 * flr) * soil * mix(1.0, max(uSkyK, 0.25), uGlowSoft);

  col += ffl * uBark.y * (0.3 + 0.9 * barkN) * vec3(1.0, 0.82, 0.62);
  #ifdef CAVE_FLOOR

    float caveK = smoothstep(uCaveX.x, uCaveX.y, vWorld.x - uCave.x) * (1.0 - smoothstep(0.6, 2.2, vWorld.z));
    col = mix(col, vec3(0.0125, 0.0065, 0.0095), caveK);
  #endif



  float farFade = (1.0 - uFarK) * max(uFadeAll, 1.0 - smoothstep(-32.0, -16.0, mix(vWorld.z, vOrigin.z, 0.75)));

  if (farFade > 0.985) discard;
  probeColor = vec4(col, 1.0 - farFade);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
