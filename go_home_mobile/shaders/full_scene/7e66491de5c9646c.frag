#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[14];} source_params;

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
#define cameraPosition (source_params.data[13].xyz)
layout(location=0) in float vAmp;
layout(location=1) in vec2 vL;
layout(location=2) in vec3 vW;
layout(location=0) out vec4 probeColor;
#define USE_INSTANCING 















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

  float r = length(vL);
  float s = clamp((r - 0.72) / 0.28, 0.0, 1.0);
  vec2 radial = vL / max(r, 1e-3);
  vec2 n = radial * sin(s * 6.2832) * vAmp;
  vec3 col = waterAt(vW, n * 0.24);
  float edge = sin(s * 3.1416);
  probeColor = vec4(col, clamp(edge * vAmp * 1.6, 0.0, 0.92));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
