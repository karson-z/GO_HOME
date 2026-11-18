#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[29];} source_params;
uniform sampler2D uRefl;
uniform sampler2D uNoise;
#define sourcePolygonOffset (source_params.data[1].xy)
#define uFarCut (source_params.data[2].x)
#define uZenith (source_params.data[3].xyz)
#define uMid (source_params.data[4].xyz)
#define uHorizon (source_params.data[5].xyz)
#define uLightCol (source_params.data[6].xyz)
#define uSunDir (source_params.data[7].xyz)
#define uMoonDir (source_params.data[8].xyz)
#define uBodies (source_params.data[9].xyzw)
#define uSkyHalo (source_params.data[10].xyzw)
#define uSunrise (source_params.data[11].x)
#define uPoster (source_params.data[12].x)
#define uTilt (source_params.data[13].xy)
#define uTime (source_params.data[14].x)
#define uReflMat (mat4(source_params.data[15].xyzw,source_params.data[16].xyzw,source_params.data[17].xyzw,source_params.data[18].xyzw))
#define uReflOn (source_params.data[19].x)
#define uLake (source_params.data[20].xyzw)
#define uReflPx (source_params.data[21].xy)
#define uFogCol (source_params.data[22].xyz)
#define uFog (source_params.data[23].xyzw)
#define uFadeX (source_params.data[24].x)
#define uFarK (source_params.data[25].x)
#define uSunWorld (source_params.data[26].xyz)
#define uLightAmt (source_params.data[27].x)
#define cameraPosition (source_params.data[28].xyz)
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







vec3 rS(vec2 p) { vec2 h = vec2(uReflPx.x, 0.0); return (texture(uRefl, p + h).rgb + 2.0 * texture(uRefl, p).rgb + texture(uRefl, p - h).rgb) * 0.25; }








void sourceUnbiasedMain() {
  vec3 V = normalize(vWorld - cameraPosition);


  vec2 warp = (texture(uNoise, vWorld.xz * vec2(0.031, 0.067) + uTime * 0.0035).rg - 0.5) * vec2(5.0, 2.2);
  vec2 Q = vWorld.xz + warp;
  vec2 w1 = texture(uNoise, vec2(Q.x * 0.05 + uTime * 0.006, Q.y * 0.42 - uTime * 0.009)).rg - 0.5;
  vec2 w2 = texture(uNoise, vec2(Q.x * 0.19 - uTime * 0.008, Q.y * 1.5 + uTime * 0.014)).gb - 0.5;
  float calm = smoothstep(0.34, 0.68, texture(uNoise, vWorld.xz * vec2(0.043, 0.13) + vec2(uTime * 0.006, 0.31)).b);
  float wave = (w1.y * 0.9 + w2.y * 0.45) * mix(0.28, 1.0, calm);
  vec3 R = normalize(vec3(V.x, abs(V.y) + wave * 0.05, V.z));
  vec3 col = skyGradient(toSky(R));
  float d = length(vWorld - cameraPosition);


  if (uReflOn > 0.5) {
    vec4 tc = uReflMat * vec4(vWorld, 1.0);


    float lkJ = 0.55 + 0.9 * texture(uNoise, gl_FragCoord.xy / 61.0).r;
    float lkW = mix(1.0, 0.45, uLake.x), lkS = mix(1.0, 0.4, max(uLake.x, uLake.z)) * lkJ;

    float lkRip = sin(vWorld.z * 1.9 + vWorld.x * 0.07 + uTime * 0.5) * 0.6 + sin(vWorld.z * 4.7 - vWorld.x * 0.13 - uTime * 0.8) * 0.4;
    float lkRipV = sin(vWorld.z * 3.3 + vWorld.x * 0.05 - uTime * 0.6);
    vec2 ruv = tc.xy / tc.w + vec2(lkRip * 0.006, lkRipV * 0.0025) * lkW;
    vec3 refl = rS(ruv) * 0.4
      + rS(ruv + vec2(0.0, 0.007 * lkS)) * 0.2 + rS(ruv - vec2(0.0, 0.007 * lkS)) * 0.2
      + rS(ruv + vec2(0.0, 0.016 * lkS)) * 0.1 + rS(ruv - vec2(0.0, 0.016 * lkS)) * 0.1;

    if (uLake.y > 0.0) {

      float nearK = mix(3.0, 1.0, smoothstep(12.0, 40.0, d));
      vec2 rw = ruv + vec2(sin(vWorld.z * 0.9 + vWorld.x * 0.04 + uTime * 0.3) * 0.012 * nearK * uLake.y, 0.0);
      vec2 hx = vec2(0.012 * nearK * uLake.y * lkJ, 0.0);
      vec3 hb = texture(uRefl, rw).rgb * 0.2 + (texture(uRefl, rw + hx).rgb + texture(uRefl, rw - hx).rgb) * 0.25
        + (texture(uRefl, rw + 2.0 * hx + vec2(0.0, 0.01)).rgb + texture(uRefl, rw - 2.0 * hx - vec2(0.0, 0.01)).rgb) * 0.15;
      refl = mix(refl, hb, 0.75);
    }
    col = min(refl, uLightCol * 1.05);


    if (uLake.x > 0.0) {
      vec3 mean = (texture(uRefl, ruv + vec2(0.05, 0.03)).rgb + texture(uRefl, ruv - vec2(0.05, 0.03)).rgb
        + texture(uRefl, ruv + vec2(-0.05, 0.03)).rgb + texture(uRefl, ruv + vec2(0.05, -0.03)).rgb) * 0.25;
      mean = min(mean, uLightCol * 1.05);
      col = max(mean + (col - mean) * (1.0 + 1.5 * uLake.x), vec3(0.0)) * (1.0 - 0.4 * uLake.x);
    }
  }

  col *= mix(0.6, 1.0, smoothstep(10.0, 40.0, d));

  col = mix(col, mix(uFogCol, skyGradient(toSky(V)), 0.45), smoothstep(16.0, 62.0, d) * mix(1.0, 0.15, uReflOn) * (1.0 - 0.8 * max(uLake.x, 0.6 * uLake.z)));

  col = mix(col, skyGradient(toSky(V)), smoothstep(140.0, 380.0, d));

  col += uHorizon * smoothstep(0.08, 0.32, wave) * 0.05;

  vec3 Rm = reflect(V, normalize(vec3(w1.x * 0.1, 1.0, wave * 0.55)));
  float glm = pow(max(dot(Rm, uSunWorld), 0.0), 260.0);
  float spm = smoothstep(0.55, 0.85, texture(uNoise, vWorld.xz * vec2(0.6, 2.4) + uTime * vec2(0.05, -0.08)).a);
  float haloM = pow(max(dot(reflect(V, normalize(vec3(w1.x * 0.18, 1.0, wave * 0.12))), uSunWorld), 0.0), 70.0);
  col += uLightCol * (glm * (0.35 + 1.6 * spm) * 1.1 + haloM * 0.3) * uLightAmt * uBodies.z;

  float a = mix(0.66, 0.8, smoothstep(10.0, 46.0, d)) + wave * 0.16;
  a = mix(0.93, a, smoothstep(13.0, 22.0, d));

  a = mix(a, 0.95, max(uLake.x, uLake.z));

  a = mix(clamp(a, 0.5, 0.92), 1.0, smoothstep(50.0, 70.0, d));


  float xSwap = uFadeX - 14.0 * (1.0 - smoothstep(-30.0, -8.0, vWorld.z));
  a *= smoothstep(xSwap, xSwap + 12.0, vWorld.x);

  a *= uFarK;

  float shore = (texture(uNoise, vec2(vWorld.x * 0.011, 0.31)).r - 0.5) * 70.0 + (texture(uNoise, vec2(vWorld.x * 0.043, 0.67)).g - 0.5) * 24.0;
  a *= mix(1.0, smoothstep(-150.0 + shore, -70.0 + shore, vWorld.z), uFarCut);
  probeColor = vec4(col, a);




  if (uLake.w > 0.0) { vec4 tq = uReflMat * vec4(vWorld, 1.0); vec3 rawC = texture(uRefl, tq.xy / tq.w).rgb; probeColor = uLake.w > 1.5 ? vec4(rawC, 1.0) : mix(probeColor, vec4(rawC, smoothstep(xSwap, xSwap + 12.0, vWorld.x) * uFarK * mix(1.0, smoothstep(-150.0 + shore, -70.0 + shore, vWorld.z), uFarCut)), min(uLake.w, 1.0)); }
  { float wMask = max(0.000, (1.0 - smoothstep(-10.000, 0.0, vWorld.x - (548.000 + 0.443 * (18.400 - vWorld.z))))); if (wMask < 0.004) discard; probeColor.a *= wMask; }
}
void sourceMain(){sourceUnbiasedMain();float z=gl_FragCoord.z;float slope=max(abs(dFdx(z)),abs(dFdy(z)));gl_FragDepth=clamp(z+sourcePolygonOffset.x*slope+sourcePolygonOffset.y*(1.0/16777216.0),0.0,1.0);}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uRefl,vec2(0.5)).x+texture(uNoise,vec2(0.5)).x);}
