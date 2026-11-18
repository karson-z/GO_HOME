#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[26];} source_params;
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
#define uOpacity (source_params.data[13].x)
#define uSoft (source_params.data[14].x)
#define uCenter (source_params.data[15].xy)
#define uRadius (source_params.data[16].xy)
#define uPondN (source_params.data[17].x)
#define uRefl (source_params.data[18].xyzw)
#define uWalk (vec4[6](source_params.data[19].xyzw,source_params.data[20].xyzw,source_params.data[21].xyzw,source_params.data[22].xyzw,source_params.data[23].xyzw,source_params.data[24].xyzw))
#define cameraPosition (source_params.data[25].xyz)
layout(location=0) in vec2 vUv;
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
  vec3 V = normalize(vW - cameraPosition);
  vec2 w = texture(uNoise, vW.xz * vec2(0.5, 1.2) + uTime * vec2(0.012, -0.02)).rg - 0.5;
  vec3 R = toSky(normalize(vec3(V.x + w.x * 0.05, abs(V.y) + 0.04 + w.y * 0.03, V.z)));
  vec3 c = skyGradient(R) * (uSoft > 0.5 ? 0.5 : 0.7);


  vec3 gold = mix(uHorizon, uLightCol, 0.4) * vec3(1.02, 0.96, 0.84);
  c = mix(c, gold * (uSoft > 0.5 ? 0.62 : 1.12), 0.4 + 0.5 * uSunrise);

  float e;
  if (uSoft > 0.5) { e = (1.0 - smoothstep(0.35, 1.0, abs(vUv.x - 0.5) * 2.0)) * smoothstep(0.0, 0.7, vUv.y) * 0.45; }
  else {
    float r = length((vW.xz - uCenter) / uRadius);

    float fz = clamp((vW.z - (uCenter.y - uRadius.y)) / (2.0 * uRadius.y), 0.0, 1.0);





    vec3 cFar = vec3(0.96, 0.86, 0.62), cMid = vec3(0.68, 0.63, 0.55), cNear = vec3(0.22, 0.28, 0.36);
    float fzn = fz + (texture(uNoise, vW.xz * vec2(0.6, 2.0)).g - 0.5) * 0.08;
    vec3 skyR = skyGradient(R);
    c = mix(cFar, cMid, smoothstep(0.05, 0.32, fzn));
    c = mix(c, cNear, smoothstep(0.3, 0.88, fzn));
    c = mix(c, skyR * 0.8, 0.12);

    float gl2 = texture(uNoise, vW.xz * vec2(0.18, 6.5) + uTime * vec2(0.025, 0.0)).g;
    c = mix(c, vec3(1.0, 0.93, 0.72), smoothstep(0.66, 0.74, gl2) * (1.0 - smoothstep(0.2, 0.75, fzn)) * 0.75);
    c = mix(c, cMid * 1.3, smoothstep(0.7, 0.78, gl2) * smoothstep(0.35, 0.8, fzn) * 0.5);

    vec3 bank = mix(vec3(0.18, 0.16, 0.13), vec3(0.34, 0.29, 0.19), uSunrise);
    float farB = 1.0 - smoothstep(0.02, 0.09, fz + (texture(uNoise, vW.xz * vec2(1.6, 0.5)).g - 0.5) * 0.04);
    c = mix(c, bank, farB * 0.75);

    float rip = texture(uNoise, vW.xz * vec2(0.35, 3.2) + uTime * vec2(0.02, 0.0)).b;
    c *= 0.93 + 0.16 * smoothstep(0.55, 0.75, rip);

    float rip2 = texture(uNoise, vW.xz * vec2(0.22, 9.0) + uTime * vec2(0.035, 0.0)).b;
    c = mix(c, vec3(0.93, 0.94, 0.95), smoothstep(0.7, 0.78, rip2) * (0.15 + 0.3 * fz));

    c += gold * smoothstep(0.6, 0.78, texture(uNoise, vW.xz * vec2(0.25, 5.5) + uTime * vec2(0.03, 0.0)).g) * 0.35 * smoothstep(0.1, 0.5, fz);

    float wob = (texture(uNoise, vW.xz * vec2(1.8, 6.0) + uTime * vec2(0.05, 0.0)).g - 0.5) * 0.16;
    float q = (vW.z - 0.25) / 1.7;
    float half_ = 0.62 * sqrt(max(0.0, 1.0 - q * q)) * step(0.0, q);
    float t1 = (1.0 - smoothstep(half_ - 0.08, half_ + 0.02, abs(vW.x + wob - uRefl.x))) * uRefl.z;
    float t2 = (1.0 - smoothstep(half_ - 0.08, half_ + 0.02, abs(vW.x + wob - uRefl.y))) * uRefl.w;
    float brk = 0.82 + 0.18 * smoothstep(0.4, 0.6, texture(uNoise, vW.xz * vec2(0.4, 7.0) + uTime * vec2(0.04, 0.0)).b);
    c = mix(c, vec3(0.11, 0.13, 0.09), clamp(t1 + t2, 0.0, 1.0) * 0.8 * brk * (1.0 - smoothstep(0.75, 1.0, q)));

    float gl = texture(uNoise, vW.xz * vec2(2.6, 9.0) + uTime * vec2(0.09, 0.03)).r;

    float shoreN = (texture(uNoise, vW.xz * vec2(1.3, 2.4)).g - 0.5) * 0.14;
    float rim = smoothstep(0.8, 0.97, r + shoreN);
    c += uLightCol * smoothstep(0.82, 0.9, gl) * 0.4 * (1.0 - rim) * (1.0 - fz * 0.6);

    for (int i = 0; i < 6; i++) {
      vec4 q = uWalk[i];
      if (q.z < 0.01) continue;
      float d = length(vec2(vW.x - q.x, (vW.z - q.y) * 1.3));
      float s1 = 0.5 + 0.5 * sin(d * 20.0 - uTime * 4.5);
      float s2 = s1 * s1;
      c += uLightCol * s2 * s2 * exp(-d * 2.4) * smoothstep(0.05, 0.16, d) * 0.4 * q.z;
      c *= 1.0 - 0.3 * q.z * exp(-d * d * 30.0);
    }

    c = mix(c, bank * 0.9, rim * 0.45);

    e = 1.0 - smoothstep(0.82, 1.0, r + shoreN) * uPondN;
  }
  probeColor = vec4(c, uOpacity * e);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
