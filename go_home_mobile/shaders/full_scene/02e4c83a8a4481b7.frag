#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[38];} source_params;
uniform sampler2D uNoise;
uniform sampler2D uRefl;
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
#define uReflMat (mat4(source_params.data[13].xyzw,source_params.data[14].xyzw,source_params.data[15].xyzw,source_params.data[16].xyzw))
#define uFogCol (source_params.data[17].xyz)
#define uLayerCol (vec3[5](source_params.data[18].xyz,source_params.data[19].xyz,source_params.data[20].xyz,source_params.data[21].xyz,source_params.data[22].xyz))
#define uFog (source_params.data[23].xyzw)
#define uSunWorld (source_params.data[24].xyz)
#define uLightAmt (source_params.data[25].x)
#define uRiverNew (source_params.data[26].x)
#define uWaterY (source_params.data[27].x)
#define uDepth (source_params.data[28].x)
#define uFade (source_params.data[29].x)
#define uGap (source_params.data[30].xy)
#define uRock (source_params.data[31].xy)
#define uLayerZ (float[5](source_params.data[32].x,source_params.data[33].x,source_params.data[34].x,source_params.data[35].x,source_params.data[36].x))
#define cameraPosition (source_params.data[37].xyz)
layout(location=0) in vec3 vW;
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













vec3 surfaceAt(vec3 P) {
  vec3 V = normalize(P - cameraPosition);
  float d = length(P - cameraPosition);

  vec2 warp = (texture(uNoise, P.xz * vec2(0.031, 0.067) + uTime * 0.0035).rg - 0.5) * vec2(5.0, 2.2);
  vec2 Q = P.xz + warp;
  float calm = smoothstep(0.34, 0.68, texture(uNoise, P.xz * vec2(0.043, 0.13) + vec2(uTime * 0.006, 0.31)).b);
  vec2 w1 = texture(uNoise, vec2(Q.x * 0.07 + Q.y * 0.05 + uTime * 0.015, Q.y * 0.2 - uTime * 0.02)).rg - 0.5;
  vec2 w2 = texture(uNoise, vec2(Q.x * 0.23 - Q.y * 0.11 - uTime * 0.01, Q.y * 0.62 + uTime * 0.03)).gb - 0.5;

  float rvK = smoothstep(432.0, 440.0, P.x);

  float rvN = rvK * uRiverNew;
  vec2 wave = (w1 * 0.9 + w2 * 0.35) * mix(0.28, 1.0, calm) * mix(1.0, 0.5, rvK) * mix(1.0, 0.45, rvN);
  vec3 N = normalize(vec3(wave.x * 0.18, 1.0, wave.y * 0.12));
  vec4 tc = uReflMat * vec4(P, 1.0);
  vec2 ruv = tc.xy / tc.w + vec2(wave.x * 0.012, wave.y * 0.004);
  float rvS = mix(1.0, 1.8, rvK) * mix(1.0, 0.3, rvN);
  vec3 refl = texture(uRefl, ruv).rgb * 0.4
    + texture(uRefl, ruv + vec2(0.0, 0.006 * rvS)).rgb * 0.2 + texture(uRefl, ruv - vec2(0.0, 0.006 * rvS)).rgb * 0.2
    + texture(uRefl, ruv + vec2(0.0, 0.014 * rvS)).rgb * 0.1 + texture(uRefl, ruv - vec2(0.0, 0.014 * rvS)).rgb * 0.1;
  vec3 deep = uLayerCol[1] * 0.6 * mix(1.0, 0.62, rvN);
  float fres = mix(0.5, 0.92, smoothstep(5.0, 30.0, d));

  vec3 col = mix(deep, min(refl, uLightCol * 1.05) * mix(0.78, 0.58, rvN), fres);

  vec3 R = reflect(V, normalize(vec3(wave.x * 0.1, 1.0, wave.y * 0.55)));
  float gl = pow(max(dot(R, uSunWorld), 0.0), 260.0);
  float sparkle = smoothstep(0.55, 0.85, texture(uNoise, P.xz * vec2(0.6, 2.4) + uTime * vec2(0.05, -0.08)).a);
  col += uLightCol * gl * mix(0.35 + 1.6 * sparkle, 0.5 + 0.35 * sparkle, rvK) * mix(1.0, 0.45, rvN) * uLightAmt * 1.1;

  col += uLightCol * pow(max(dot(reflect(V, N), uSunWorld), 0.0), 70.0) * 0.3 * uLightAmt;

  float w5k = 1.0 - smoothstep(420.0, 432.0, P.x);
  if (w5k > 0.001) {
    float az = max(dot(normalize(V.xz), normalize(uSunWorld.xz)), 0.0);
    float road = pow(az, 900.0) * 0.75 + pow(az, 180.0) * 0.25;
    float streak = smoothstep(0.32, 0.72, texture(uNoise, vec2(P.x * 0.11 + uTime * 0.01, P.z * 0.85 - uTime * 0.03)).r);
    col += uLightCol * road * (0.16 + 0.95 * streak) * smoothstep(5.0, 16.0, d) * uLightAmt * w5k;
  }

  if (rvN > 0.001) {
    float azB = max(dot(normalize(V.xz), normalize(uSunWorld.xz)), 0.0);
    float bz = (d - 24.0) / 6.0;
    float band = exp(-bz * bz) * smoothstep(0.2, 0.75, azB);
    float brk = 0.75 + 0.25 * texture(uNoise, vec2(P.x * 0.09 + uTime * 0.004, P.z * 0.6)).g;
    col += uLightCol * band * brk * 0.075 * uLightAmt * rvN;
  }

  col = mix(col, uFogCol, clamp((uFog.x * 0.35 + 0.28) * smoothstep(14.0, 62.0, d), 0.0, 0.72) * (1.0 - 0.5 * w5k) * mix(1.0, 0.45, rvN));
  return col;
}
     

void sourceMain() {

  vec3 V = vW - cameraPosition;
  vec3 Q = cameraPosition + V * ((uWaterY - cameraPosition.y) / V.y);
  float depth = uWaterY - vW.y;

  float wob = (texture(uNoise, vec2(vW.x * 0.07 + 0.3, uTime * 0.012)).g - 0.5) * 0.75 + (texture(uNoise, vec2(vW.x * 0.23 + uTime * 0.02, uTime * 0.03)).r - 0.5) * 0.3;
  float fade = 1.0 - smoothstep(0.0, 1.7, depth + wob);
  fade *= fade;
  vec3 top = surfaceAt(Q);
  float k = clamp(depth / uDepth, 0.0, 1.0);

  vec3 water = mix(uFogCol * 0.72, uLayerCol[3] * 0.5, k);
  float a = mix(0.07, 0.3, k);

  float lump = (texture(uNoise, vec2(vW.x * 0.11 + 7.0, vW.y * 0.17)).b - 0.5) * 1.5 + (texture(uNoise, vec2(vW.x * 0.37, vW.y * 0.41 + 2.0)).r - 0.5) * 0.5;
  float inner = min(min(vW.x - uGap.x, uGap.y - vW.x), (uDepth - depth) * 1.5 + 0.1) + lump;
  float murk = (1.0 - smoothstep(0.45, 1.65, inner)) * smoothstep(0.05, 0.75, depth + wob * 0.5);
  vec3 soil = uLayerCol[0];
  for (int i = 0; i < 4; i++) if (-9.0 < uLayerZ[i] && -9.0 >= uLayerZ[i + 1]) soil = mix(uLayerCol[i + 1], uLayerCol[i], (-9.0 - uLayerZ[i + 1]) / (uLayerZ[i] - uLayerZ[i + 1]));
  water = mix(water, soil, murk);
  a = mix(a, 1.0, murk);

  float ru = (vW.x - uRock.x) / uRock.y;
  float rs = exp(-ru * ru) * (1.0 - smoothstep(0.1, 1.5, depth));
  water = mix(water, soil, rs * 0.85);
  a = mix(a, 0.92, rs);
  top = mix(top, soil * 1.2, exp(-ru * ru) * 0.8);
  probeColor = vec4(mix(water, top, fade), mix(a, 1.0, fade) * uFade);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x+texture(uRefl,vec2(0.5)).x);}
