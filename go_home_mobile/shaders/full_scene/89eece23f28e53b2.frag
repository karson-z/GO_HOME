#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[29];} source_params;
uniform sampler2D uNoise;
uniform sampler2D uRefl;
uniform sampler2D uShore;
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
#define uBox (source_params.data[13].xyzw)
#define uReflMat (mat4(source_params.data[14].xyzw,source_params.data[15].xyzw,source_params.data[16].xyzw,source_params.data[17].xyzw))
#define uAxis (source_params.data[18].xyz)
#define uSquash (source_params.data[19].x)
#define uFarEdge (source_params.data[20].xy)
#define uShoreFade (source_params.data[21].x)
#define uFogCol (source_params.data[22].xyz)
#define uSunWorld (source_params.data[23].xyz)
#define uLightAmt (source_params.data[24].x)
#define uGlint (source_params.data[25].x)
#define uWaterK (source_params.data[26].x)
#define uShade (source_params.data[27].x)
#define cameraPosition (source_params.data[28].xyz)
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
  vec3 P = vW;
  vec3 V = normalize(P - cameraPosition);
  float d = length(P - cameraPosition);

  vec2 warp = (texture(uNoise, P.xz * vec2(0.031, 0.067) + uTime * 0.0035).rg - 0.5) * vec2(5.0, 2.2);
  vec2 Q = P.xz + warp;
  float calm = smoothstep(0.34, 0.68, texture(uNoise, P.xz * vec2(0.043, 0.13) + vec2(uTime * 0.006, 0.31)).b);
  vec2 w1 = texture(uNoise, vec2(Q.x * 0.07 + Q.y * 0.05 + uTime * 0.015, Q.y * 0.2 - uTime * 0.02)).rg - 0.5;
  vec2 w2 = texture(uNoise, vec2(Q.x * 0.23 - Q.y * 0.11 - uTime * 0.01, Q.y * 0.62 + uTime * 0.03)).gb - 0.5;
  vec2 wave = (w1 * 0.9 + w2 * 0.35) * mix(0.16, 0.55, calm);
  vec4 tc = uReflMat * vec4(P, 1.0);
  vec2 ruv = tc.xy / tc.w;
  vec4 ft = uReflMat * vec4(uAxis, 1.0);
  float y0 = ft.y / ft.w;
  ruv.y = y0 + (ruv.y - y0) * uSquash;
  ruv += vec2(wave.x * 0.012, wave.y * 0.004);
  vec3 refl = texture(uRefl, ruv).rgb * 0.4
    + texture(uRefl, ruv + vec2(0.0, 0.004)).rgb * 0.2 + texture(uRefl, ruv - vec2(0.0, 0.004)).rgb * 0.2
    + texture(uRefl, ruv + vec2(0.0, 0.009)).rgb * 0.1 + texture(uRefl, ruv - vec2(0.0, 0.009)).rgb * 0.1;

  vec3 Rn = reflect(V, normalize(vec3(wave.x * 0.05, 1.0, wave.y * 0.05)));
  vec3 skyC = skyGradient(toSky(normalize(vec3(Rn.x, Rn.y * 0.3, Rn.z))));
  float lum = dot(refl, vec3(0.3, 0.55, 0.15));
  float treeK = 1.0 - smoothstep(0.09, 0.26, lum);

  vec3 col = mix(skyC, refl + uFogCol * 0.24, treeK);
  float cl = dot(col, vec3(0.3, 0.55, 0.15));
  col = mix(vec3(cl), col, 1.45) * mix(0.55, 0.7, smoothstep(10.0, 48.0, d));

  vec3 R = reflect(V, normalize(vec3(wave.x * 0.1, 1.0, wave.y * 0.55)));
  col += uLightCol * pow(max(dot(R, uSunWorld), 0.0), 260.0) * 0.5 * uLightAmt * uGlint;
  col *= uWaterK;
  if (uShade > 0.0) {


    float ruff = texture(uNoise, vec2(P.x * 0.011 + uTime * 0.0015, P.z * 0.04 + 0.43)).r;
    float band = smoothstep(0.2, 0.85, ruff * 0.6 + calm * 0.4);

    float far = (1.0 - smoothstep(-62.0, -14.0, P.z));
    col *= mix(1.0 - 0.22 * uShade, 1.0 + 0.06 * uShade, band) * mix(1.0 - 0.3 * uShade, 1.0 + 0.06 * uShade, far);

    col *= 1.0 + 0.3 * uShade * (1.0 - smoothstep(-64.0, -50.0, P.z));
  }

  float s = texture(uShore, (P.xz - uBox.xy) / uBox.zw).r;
  float edge = 1.0 - smoothstep(0.02, 0.42, s);
  col = mix(col, uFogCol * 0.86, edge * 0.5 * (1.0 - smoothstep(uFarEdge.x, uFarEdge.y, P.z)));
  probeColor = vec4(col, smoothstep(0.0, uShoreFade, s));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x+texture(uRefl,vec2(0.5)).x+texture(uShore,vec2(0.5)).x);}
