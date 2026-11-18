#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[15];} source_params;
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
#define uFogCol (source_params.data[12].xyz)
#define uTime (source_params.data[13].x)
#define cameraPosition (source_params.data[14].xyz)
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


vec3 waterAt(vec3 P, vec2 n) {
  vec3 V = normalize(P - cameraPosition);

  vec3 R = normalize(vec3(V.x + n.x, abs(V.y) * 0.3 + 0.02 + n.y * 0.5, V.z + n.y));
  vec3 col = skyGradient(toSky(R));
  float d = length(P - cameraPosition);
  col *= mix(0.74, 0.92, smoothstep(10.0, 40.0, d));
  col = mix(col, mix(uFogCol, skyGradient(toSky(V)), 0.45), smoothstep(22.0, 70.0, d));
  return col;
}



void sourceMain() {
  vec2 P = vW.xz;

  vec2 warp = (texture(uNoise, P * vec2(0.031, 0.067) + uTime * 0.0035).rg - 0.5) * vec2(5.0, 2.2);
  vec2 Q = P + warp;
  float calm = smoothstep(0.34, 0.68, texture(uNoise, P * vec2(0.043, 0.13) + vec2(uTime * 0.006, 0.31)).b);

  vec2 w1 = texture(uNoise, vec2(Q.x * 0.07 + Q.y * 0.05 + uTime * 0.015, Q.y * 0.2 + uTime * 0.03)).rg - 0.5;
  vec2 w2 = texture(uNoise, vec2(Q.x * 0.23 - Q.y * 0.11 - uTime * 0.01, Q.y * 0.62 + uTime * 0.05)).gb - 0.5;
  vec2 wave = (w1 * 0.9 + w2 * 0.35) * mix(0.28, 1.0, calm);
  vec3 col = waterAt(vW, wave * 0.07);

  col *= mix(0.9, 1.02, calm);
  probeColor = vec4(col, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
