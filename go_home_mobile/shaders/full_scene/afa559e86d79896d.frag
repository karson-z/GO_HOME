#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[16];} source_params;
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
#define uFogCol (source_params.data[12].xyz)
#define uK (source_params.data[13].x)
#define uAsp (source_params.data[14].x)
#define uTime (source_params.data[15].x)
layout(location=0) in vec2 vUv;
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
  vec2 p = vec2(vUv.x * uAsp, vUv.y);
  float n = texture(uCloud, p * vec2(0.27, 0.5) + vec2(uTime * 0.012, -uTime * 0.02)).r;
  float n2 = texture(uCloud, p * vec2(0.8, 1.3) + vec2(-uTime * 0.02, uTime * 0.03)).r;

  float cover = uK * 1.5 - (n * 0.34 + n2 * 0.16);
  float a = smoothstep(0.0, 0.95, cover) * mix(0.62, 1.0, 1.0 - smoothstep(0.5, 1.0, vUv.y));

  vec3 c = mix(uMid, uZenith, 0.25 + 0.5 * vUv.y) * (0.86 + 0.16 * n2);
  probeColor = vec4(c, clamp(a, 0.0, 1.0) * 0.97);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uCloud,vec2(0.5)).x);}
