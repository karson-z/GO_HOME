#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[21];} source_params;
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
#define uWaterY (source_params.data[14].x)
#define uFadeX (source_params.data[15].x)
#define uThick (source_params.data[16].x)
#define uFarK (source_params.data[17].x)
#define uPatch (source_params.data[18].x)
#define uSeed (source_params.data[19].x)
#define cameraPosition (source_params.data[20].xyz)
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











void sourceMain() {
  vec3 V = normalize(vW - cameraPosition);
  float n = texture(uNoise, vec2(vW.x * 0.012 + uTime * 0.004, 0.61)).r;
  float n2 = texture(uNoise, vec2(vW.x * 0.05 - uTime * 0.006, 0.23)).g;
  float h = max(vW.y - uWaterY, 0.0);

  float a = exp(-h / ((0.8 + 1.6 * n + 0.5 * n2) * uThick)) * smoothstep(uFadeX, uFadeX + 12.0, vW.x) * uFarK;

  if (uPatch > 0.0) {
    float p1 = texture(uNoise, vec2(vW.x * 0.021 + uTime * 0.011 + uSeed, 0.37 + uSeed * 0.13)).b;
    float p2 = texture(uNoise, vec2(vW.x * 0.067 - uTime * 0.017 + uSeed * 1.7, 0.83)).r;
    a *= uPatch * smoothstep(0.22, 0.78, p1) * (0.55 + 0.9 * p2);
  }

  probeColor = vec4(mix(uFogCol, skyGradient(toSky(V)), 0.45), a);
  { float wMask = max(0.000, (1.0 - smoothstep(-10.000, 0.0, vW.x - (548.000 + 0.443 * (18.400 - vW.z))))); if (wMask < 0.004) discard; probeColor.a *= wMask; }
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
