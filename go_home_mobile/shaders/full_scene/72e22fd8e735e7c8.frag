#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[27];} source_params;
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
#define uFog (source_params.data[14].xyzw)
#define uLightAmt (source_params.data[15].x)
#define uLightDir (source_params.data[16].xyz)
#define uBase (source_params.data[17].x)
#define uThick (source_params.data[18].x)
#define uAmt (source_params.data[19].x)
#define uSkyCut (source_params.data[20].x)
#define uSkyMix (source_params.data[21].x)
#define uFogLow (source_params.data[22].x)
#define uFromX (source_params.data[23].xy)
#define uToX (source_params.data[24].xy)
#define uZone (source_params.data[25].xyzw)
#define cameraPosition (source_params.data[26].xyz)
layout(location=0) in vec3 vWorld;
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
  vec3 V = toSky(normalize(vWorld - cameraPosition));
  float h = vWorld.y - uBase;

  float dense = smoothstep(0.5, 0.78, uFog.x);
  float thick = uThick * (1.0 + dense * 1.8 + uFog.y * 0.8);

  float edge = texture(uNoise, vec2(vWorld.x * 0.006 + uTime * 0.004, vWorld.z * 0.01)).b;
  h -= (edge - 0.5) * thick * 1.4;
  float prof = exp(-max(h, 0.0) / thick) * smoothstep(-1.5, 0.5, h);
  float n1 = texture(uNoise, vec2(vWorld.x * 0.012 + uTime * 0.01, h * 0.05 + vWorld.z * 0.01)).r;
  float n2 = texture(uNoise, vec2(vWorld.x * 0.035 - uTime * 0.016, h * 0.12)).g;
  float a = uAmt * uFog.x * uFog.w * prof * mix(smoothstep(0.25, 0.75, n1 * 0.75 + n2 * 0.5), 0.55 + 0.6 * n1, dense) * (1.0 + dense * 0.6);
  if (uPoster > 0.5) a = floor(a * uPoster + 0.5) / uPoster;

  float sc = pow(max(dot(V, uLightDir), 0.0), 14.0);
  vec3 c = mix(uFogCol, skyGradient(V), uSkyMix * mix(1.0, smoothstep(0.0, 0.1, V.y), uFogLow)) + uLightCol * sc * 0.3 * uLightAmt;

  a *= mix(1.0, (1.0 - smoothstep(0.0, 0.07, V.y)), uSkyCut);

  c += uLightCol * dense * 0.12 * (1.0 - smoothstep(0.0, 0.2, abs(h / thick - 0.6)));
  a *= smoothstep(uFromX.x, uFromX.y, vWorld.x) * (1.0 - smoothstep(uToX.x, uToX.y, vWorld.x));

  a *= smoothstep(uZone.x, uZone.y, vWorld.x) * (1.0 - smoothstep(uZone.z, uZone.w, vWorld.x));
  probeColor = vec4(c, clamp(a, 0.0, 0.88));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
