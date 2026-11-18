#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[19];} source_params;
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
#define uLightAmt (source_params.data[14].x)
#define uSunWorld (source_params.data[15].xyz)
#define uFog (source_params.data[16].xyzw)
#define uFarK (source_params.data[17].x)
#define cameraPosition (source_params.data[18].xyz)
layout(location=0) in float vEdge;
layout(location=1) in vec3 vWorld;
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
  vec3 Vw = normalize(vWorld - cameraPosition);
  vec2 w1 = texture(uNoise, vec2(vWorld.x * 0.09 + uTime * 0.015, vWorld.z * 0.55 - uTime * 0.02)).rg - 0.5;
  vec2 w2 = texture(uNoise, vec2(vWorld.x * 0.31 - uTime * 0.01, vWorld.z * 1.7 + uTime * 0.03)).gb - 0.5;
  vec2 wave = w1 * 0.9 + w2 * 0.35;

  vec3 refl = skyGradient(normalize(vec3(Vw.x, 0.03 + abs(wave.y) * 0.14, Vw.z)));

  float az = max(dot(normalize(Vw.xz), normalize(uSunWorld.xz)), 0.0);
  float path = pow(az, 1400.0) * 1.1 + pow(az, 180.0) * 0.32;
  float sparkle = smoothstep(0.45, 0.8, texture(uNoise, vWorld.xz * vec2(0.5, 2.4) + uTime * vec2(0.05, -0.08)).a);

  vec3 col = refl * mix(0.24, 0.6, pow(az, 300.0)) + uLightCol * path * (0.35 + 3.0 * sparkle) * uLightAmt;
  col = mix(col, uFogCol * 0.72, clamp(uFog.x * 0.45, 0.0, 0.6));

  float bank = texture(uNoise, vWorld.xz * vec2(0.22, 0.7)).r;
  col = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))) * vec3(0.94, 0.98, 1.12), 0.55) * 0.8; col = mix(uFogCol * 0.3, col, 0.16); probeColor = vec4(col, smoothstep(0.0, 0.9, vEdge - (bank - 0.5) * 0.7) * mix(0.62, 1.0, pow(az, 300.0)) * uFarK);
  if ((1.0 - smoothstep(-0.500, 0.0, vWorld.x - (288.000 + 0.430 * (0.000 - vWorld.z)))) < 0.5) discard;
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
