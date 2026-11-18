#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[18];} source_params;
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
#define uBodySize (source_params.data[12].xyz)
#define uStars (source_params.data[13].x)
#define uTime (source_params.data[14].x)
#define uFogCol (source_params.data[15].xyz)
#define uCloudAmt (source_params.data[16].x)
#define cameraPosition (source_params.data[17].xyz)
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









float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

void sourceMain() {
  vec3 d = toSky(normalize(vWorld - cameraPosition));
  vec3 col = skyGradient(d);
  float light = 0.0;


  if (uStars > 0.01) {
    vec2 sp = vec2(atan(d.x, -d.z) * 260.0, d.y * 260.0);
    vec2 cell = floor(sp);
    float h = hash(cell);
    if (h > 0.985) {
      vec2 f = fract(sp) - 0.5 - (vec2(hash(cell + 7.1), hash(cell + 3.3)) - 0.5) * 0.6;
      float s = (1.0 - smoothstep(0.0, 0.22, length(f))) * (h - 0.985) / 0.015;
      float tw = 0.65 + 0.35 * sin(uTime * (1.0 + h * 3.0) + h * 40.0);
      col += vec3(0.85, 0.9, 1.0) * s * tw * uStars * smoothstep(0.02, 0.2, d.y) * 1.4;
    }
  }


  float cs = max(dot(d, uSunDir), 0.0);
  float sunR = uBodySize.x;
  float discS = smoothstep(cos(sunR), cos(sunR * 0.93), cs) * uBodies.x;
  float haloS = (pow(cs, 40.0) * uSkyHalo.z + pow(cs, 160.0) * uSkyHalo.w + pow(cs, 400.0) * 0.4) * uBodies.y;
  col += uLightCol * haloS;

  col = mix(col, mix(uLightCol * 2.0, vec3(2.4, 2.32, 2.16), uSunrise), discS);
  light += discS * 1.0 + pow(cs, 300.0) * uBodies.y * 0.5;


  float cm = max(dot(d, uMoonDir), 0.0);
  float moonR = uBodySize.y;
  float discM = smoothstep(cos(moonR), cos(moonR * 0.9), cm) * uBodies.z;
  vec3 haloM = vec3(0.75, 0.82, 1.0) * (pow(cm, 30.0) * 0.12 + pow(cm, 600.0) * 0.35) * uBodies.z * (1.0 + uBodies.w * 1.5);
  col += haloM * mix(vec3(1.0), uLightCol, 0.5);
  vec3 tang = normalize(cross(uMoonDir, vec3(0.0, 1.0, 0.0)));
  vec3 bit = cross(tang, uMoonDir);
  vec2 muv = vec2(dot(d - uMoonDir, tang), dot(d - uMoonDir, bit)) / max(moonR, 1e-4);
  float maria = texture(uNoise, muv * 0.35 + 0.3).r;
  vec3 moonCol = vec3(1.9, 1.95, 2.05) * (0.78 + 0.35 * smoothstep(0.35, 0.7, maria));

  vec3 mc = max(moonCol * (1.0 - uBodies.w * 0.45), col * 1.15);
  col = mix(col, mc, discM * (1.0 - uBodies.w * 0.5));
  light += discM * 0.6 * (1.0 - uBodies.w * 0.6) + pow(cm, 400.0) * uBodies.z * 0.2;


  if (uCloudAmt > 0.01 && d.y > -0.02) {
    float hh = d.y + 0.06;
    vec2 base = d.xz / hh;
    float c1 = texture(uNoise, base * vec2(0.010, 0.035) + vec2(uTime * 0.0012, 0.0)).r;
    float c2 = texture(uNoise, base * vec2(0.022, 0.07) + vec2(uTime * 0.002, 0.3)).g;
    float dens = smoothstep(0.52, 0.78, c1 * 0.7 + c2 * 0.45) * uCloudAmt;
    dens *= smoothstep(0.0, 0.05, d.y) * (1.0 - smoothstep(0.25, 0.55, d.y) * 0.6);

    vec3 toL = normalize(mix(uSunDir, uMoonDir, step(uBodies.y + uBodies.x, uBodies.z)));
    vec2 off = normalize(toL.xz / max(toL.y + 0.06, 0.02) - base + vec2(1e-4)) * 6.0;
    float c1b = texture(uNoise, (base + off) * vec2(0.010, 0.035) + vec2(uTime * 0.0012, 0.0)).r;
    float edge = clamp((c1 - c1b) * 3.0 + 0.3, 0.0, 1.0);
    float near = pow(max(dot(d, toL), 0.0), 8.0);

    dens *= 1.0 - 0.85 * pow(max(dot(d, toL), 0.0), 60.0);
    vec3 cloudDark = mix(uMid, uZenith, 0.5) * 0.75;
    vec3 cloudLit = uLightCol * (0.55 + 0.75 * near);
    vec3 cc = mix(cloudDark, cloudLit, edge * (0.25 + 0.75 * near) * max(max(uBodies.y, uBodies.z), 0.25));
    col = mix(col, cc, dens * 0.85);
    light *= 1.0 - dens * 0.85;
  }


  col = mix(col, uFogCol, (1.0 - smoothstep(-0.08, 0.0, d.y)));
  probeColor = vec4(col, clamp(light, 0.0, 1.0));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
