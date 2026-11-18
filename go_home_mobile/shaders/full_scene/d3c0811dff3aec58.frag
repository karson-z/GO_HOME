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
#define uTop (source_params.data[14].x)
#define uThick (source_params.data[15].x)
#define uAmt (source_params.data[16].x)
#define uFadeX (source_params.data[17].x)
#define uDeep (source_params.data[18].x)
#define uFloor (source_params.data[19].x)
#define cameraPosition (source_params.data[20].xyz)
layout(location=0) in vec3 vW;
layout(location=1) in float vX;
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
  float n1 = texture(uNoise, vec2(vW.x * 0.07 + uTime * 0.012, vW.y * 0.11 - uTime * 0.004)).r;
  float n2 = texture(uNoise, vec2(vW.x * 0.19 - uTime * 0.018, vW.y * 0.27 + uTime * 0.006)).g;
  float d = uTop + (n1 - 0.5) * 1.2 - vW.y;
  float a = smoothstep(0.0, uThick, d) * (0.62 + n2 * 0.55) * smoothstep(0.0, uFadeX, vX) * (1.0 - smoothstep(1.0 - uFadeX, 1.0, vX));

  a *= smoothstep(uFloor, uFloor + 0.7, vW.y);

  vec3 col = mix(uFogCol, skyGradient(toSky(V)), 0.3) * mix(0.42, 0.8, exp(-max(d, 0.0) * uDeep));

  col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), 0.55);
  probeColor = vec4(col, clamp(a * uAmt, 0.0, 0.96));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
