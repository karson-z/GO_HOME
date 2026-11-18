#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[33];} source_params;
uniform sampler2D uEdge;
uniform sampler2D uCloud;
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
#define uLightDir (source_params.data[14].xyz)
#define uAmp (source_params.data[15].x)
#define uFreq (source_params.data[16].x)
#define uSeed (source_params.data[17].x)
#define uDrift (source_params.data[18].x)
#define uK (source_params.data[19].x)
#define uFlip (source_params.data[20].x)
#define uOpacity (source_params.data[21].x)
#define uWarm (source_params.data[22].x)
#define uFade (source_params.data[23].x)
#define uRag (source_params.data[24].x)
#define uFarK (source_params.data[25].x)
#define uSoftK (source_params.data[26].x)
#define uFloorY (source_params.data[27].x)
#define uFogTone (source_params.data[28].x)
#define uFogDim (source_params.data[29].x)
#define uFogLit (source_params.data[30].x)
#define uFogDeep (source_params.data[31].x)
#define cameraPosition (source_params.data[32].xyz)
layout(location=0) in float vTop;
layout(location=1) in vec3 vW;
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

























void sourceMain() {
  float s = uFlip > 0.5 ? -1.0 : 1.0;
  float top0 = vTop;
  float wx = vW.x + uTime * uDrift;

  float warp = texture(uCloud, vec2(wx * uFreq * 0.31 + uSeed, (vW.y - top0) * 0.012 + uSeed * 3.0)).r - 0.5;
  float x = wx * uFreq + uSeed + warp * 0.09 * (uFlip > 0.5 ? 0.2 : 1.0);

  float e = texture(uEdge, vec2(x, 0.5), uFlip > 0.5 ? 3.0 : 2.0 * log2(uSoftK)).r;

  vec2 q = vec2(wx, (vW.y - top0) * 1.7) / max(uAmp, 0.5);
  float n1 = texture(uCloud, q * 0.17 + vec2(uSeed, uTime * 0.004)).r - 0.5;
  float n2 = texture(uCloud, q * 0.61 + vec2(-uTime * 0.007, uSeed * 2.0)).r - 0.5;
  float top = top0 + s * (e * uAmp + (n1 * 0.55 + n2 * 0.22 / uSoftK) * uAmp * uRag);
  float d = (top - vW.y) * s;
  float soft = (uAmp * (0.09 + 0.34 * clamp(n1 + 0.5, 0.0, 1.0)) + 0.03) * uSoftK;
  float a = smoothstep(0.0, soft, d) * smoothstep(uFloorY, uFloorY + 6.0, vW.y);
  if (a < 0.004) discard;

  float eL = texture(uEdge, vec2(x, 0.5), 5.5).r;
  float dL = (top0 + s * eL * uAmp - vW.y) * s;
  vec3 Vw = vW - cameraPosition;
  vec3 V = toSky(normalize(Vw));
  vec3 sky = skyGradient(vec3(V.x, max(V.y, 0.015), V.z));
  vec3 F = mix(uFogCol, sky, 0.35);
  float crest = 1.0 - smoothstep(-0.25 * uAmp, uAmp * 0.85, dL + n1 * uAmp * 0.35);
  vec3 lit, shade;
  if (uFlip > 0.5) {

    shade = mix(vec3(0.075, 0.09, 0.15), vec3(0.20, 0.23, 0.32), uK);
    lit = mix(vec3(0.20, 0.235, 0.33), vec3(0.42, 0.46, 0.58), uK);
  } else {

    vec3 white = mix(uFogCol, vec3(1.0, 0.985, 0.965), 0.55) * mix(0.84, 1.0, uK);
    float sunK = pow(max(dot(V, uLightDir), 0.0), 26.0);
    lit = mix(white, white * vec3(1.0, 0.80, 0.56) * 1.08, sunK * 0.8);
    shade = mix(vec3(0.20, 0.235, 0.36), vec3(0.50, 0.55, 0.68), uK);
    shade = mix(shade, mix(shade, vec3(0.95, 0.70, 0.62), 0.32), sunK);
  }

  if (uFogTone > 0.0) { shade = F * uFogTone; lit = mix(F, vec3(1.0, 0.975, 0.94), uFogLit) * uFogDim; shade *= uFogDim; }
  vec3 col = mix(shade, lit, crest);

  col = mix(col, shade, smoothstep(uAmp * 0.9, uAmp * 2.6, dL) * 0.8);

  if (uFlip < 0.5) col = mix(col, sky, uK * uK * 0.62);

  col = mix(col, mix(F, sky, 0.5) * 0.98, uWarm);

  if (uFogDeep < 1.0) {
    float deepK = smoothstep(0.0, 3.5, dL);
    col *= mix(1.0, uFogDeep, deepK);
    col = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))) * vec3(1.02, 0.98, 0.97), deepK * 0.55);
  }

  probeColor = vec4(col, a * uOpacity * uFade * uFarK);
  { float wMask = max(0.000, smoothstep(0.0, 2.500, vW.x - (616.000 + 0.000 * (0.000 - vW.z)))); if (wMask < 0.004) discard; probeColor.a *= wMask; }
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uEdge,vec2(0.5)).x+texture(uCloud,vec2(0.5)).x);}
