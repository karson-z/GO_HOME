#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[20];} source_params;
uniform sampler2D uCloud;
uniform sampler2D uEdge;
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
#define uFogCol (source_params.data[12].xyz)
#define uLightDir (source_params.data[13].xyz)
#define uAmp (source_params.data[14].x)
#define uFreq (source_params.data[15].x)
#define uSeed (source_params.data[16].x)
#define uK (source_params.data[17].x)
#define uFade (source_params.data[18].x)
#define cameraPosition (source_params.data[19].xyz)
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

  float x = vW.x * uFreq + uSeed;
  float h = texture(uCloud, vec2(x * 1.3, uSeed)).r * 0.62 + texture(uCloud, vec2(x * 4.1, uSeed * 2.0)).r * 0.3;
  float tree = texture(uEdge, vec2(vW.x * 0.0062 + uSeed * 3.0, 0.5)).r * 0.6 + texture(uEdge, vec2(vW.x * 0.0171 + uSeed * 5.0, 0.5)).r * 0.4;
  float top0 = vTop + (h - 0.2) * uAmp;

  float topLow = vTop + texture(uCloud, vec2(x * 1.3, uSeed)).r * uAmp * 0.8;
  float top = top0 + (tree - 0.4) * 5.2 * (1.0 - uK) * (1.0 - uK * 0.5);
  float d = top - vW.y;

  float a = smoothstep(0.0, max(0.25 + uK * 1.2, fwidth(d) * 3.0), d);
  if (a < 0.004) discard;
  vec3 V = toSky(normalize(vW - cameraPosition));
  vec3 sky = skyGradient(vec3(V.x, max(V.y, 0.015), V.z));

  const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);
  float lum = dot(uFogCol, LUM);
  vec3 haze = mix(vec3(lum), uZenith * (lum / max(dot(uZenith, LUM), 0.02)), 0.5);
  vec3 far = mix(haze, mix(sky, uMid, 0.6), 0.42) * 0.84;
  far += uLightCol * pow(max(dot(V, uLightDir), 0.0), 7.0) * 0.1;
  vec3 near = mix(mix(haze, sky, 0.3), uZenith, 0.45) * 0.42;
  vec3 c = mix(near, far, uK);

  c = mix(c, far, smoothstep(uAmp * 0.1, uAmp * 1.1 + 5.5, topLow - vW.y) * 0.9);

  c = mix(c, dot(c, LUM) * uFogCol / max(lum, 0.002), 0.85);
  probeColor = vec4(c, a * uFade);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uCloud,vec2(0.5)).x+texture(uEdge,vec2(0.5)).x);}
