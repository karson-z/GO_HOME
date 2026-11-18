#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;

#define uLift (source_params.data[1].x)
layout(location=0) in vec2 vP;
layout(location=0) out vec4 probeColor;




float sqJambS(float y) { return 23.42 + 0.42 * sin(y * 0.95 + 0.7) + 0.2 * sin(y * 2.4 + 2.0) + 0.07 * sin(y * 6.1); }
float sqTopS(float x) {
  float left = 1.0 - smoothstep(24.0, 25.0, x);
  return 4.8 + 1.65 * smoothstep(24.0, 28.6, x) - 0.3 * left * left + 0.26 * sin(x * 1.55 + 0.4) + 0.15 * sin(x * 3.7 + 2.2) + 0.06 * sin(x * 8.9 + 1.0);
}

float sqJamb(float y) { float u = y / 0.85, k = floor(u); return mix(sqJambS(k * 0.85), sqJambS((k + 1.0) * 0.85), fract(u)); }
float sqTop(float x) { float u = (x - 0.3) / 0.7, k = floor(u); return mix(sqTopS(k * 0.7 + 0.3), sqTopS((k + 1.0) * 0.7 + 0.3), fract(u)); }
float sqOpen(vec2 p) { return min(p.x - sqJamb(p.y), sqTop(p.x) - p.y); }

float sqEdge(float y) { return 0.42 * sin(y * 0.83 + 0.5) + 0.24 * sin(y * 2.1 + 1.7) + 0.1 * sin(y * 5.3); }

vec3 sqRim(vec3 col, vec2 p, float d, float k, vec3 lit) {
  float t = -d;
  float s = (p.x - p.y * 0.55) / 1.3 + 0.35 * sin(p.y * 0.9 + p.x * 0.4);
  float fs = fract(s), h = fract(sin(floor(s) * 127.1) * 43758.5453);

  float w = 0.14 + 0.16 * h;
  float seam = step(0.08, fs) * (1.0 - step(0.94, fs));
  float band = (1.0 - smoothstep(w - 0.015, w + 0.015, t)) * smoothstep(0.0, 0.02, t) * seam;
  float moon = mix(0.6, 1.15, (1.0 - smoothstep(23.5, 30.0, p.x))) * mix(0.85, 1.1, smoothstep(1.0, 5.0, p.y));
  float topE = step(sqTop(p.x) - p.y, p.x - sqJamb(p.y));
  return mix(col, lit * (0.9 + 0.3 * h), clamp(band * moon * k * mix(1.0, 0.45, topE), 0.0, 1.0));
}

void sourceMain() {
  float top = sqTop(vP.x) + 20.0 * smoothstep(27.2, 27.4, vP.x);

  float shape = min(vP.x - sqJamb(vP.y) + 0.38, top - vP.y) + 0.12;

  float fx = vP.x - 0.8 * sqEdge(vP.y * 0.7 + 3.0);

  float above = smoothstep(sqTop(vP.x) - 0.2, sqTop(vP.x) + 0.3, vP.y);
  float a = smoothstep(0.0, 0.05, shape) * (1.0 - smoothstep(31.4, 35.0, fx)) * mix(1.0, smoothstep(27.4, 31.0, vP.x), above);
  if (a <= 0.0) discard;


  float wob = 0.5 + 0.5 * sin(vP.x * 0.9 + vP.y * 0.55 + 1.3) * sin(vP.y * 1.3 - vP.x * 0.35);
  

  float aU = (vP.x - 22.8) / 0.8, aK = floor(aU);
  float aTop = 4.7 + 1.55 * mix(sqrt(max(0.0, 1.0 - pow((aK * 0.8 + 22.8 - 28.4) / 5.6, 2.0))), sqrt(max(0.0, 1.0 - pow(((aK + 1.0) * 0.8 + 22.8 - 28.4) / 5.6, 2.0))), fract(aU));
  float rIn = min(vP.x - sqJamb(vP.y) - 0.1, aTop - vP.y);
  float n1 = 0.5 + 0.5 * sin(vP.y * 3.1 + sin(vP.x * 1.7) * 1.5) * sin(vP.x * 2.3 + 0.7);


  float topN = step(aTop - vP.y, vP.x - sqJamb(vP.y) - 0.1);

  float jy = mix(floor(vP.y / 0.9), floor(vP.x / 0.8) + 100.0, topN), jf = mix(fract(vP.y / 0.9), fract(vP.x / 0.8), topN);
  float jh = mix(fract(sin(jy * 91.7) * 4375.85), fract(sin((jy + 1.0) * 91.7) * 4375.85), jf);
  float e1 = 0.72 + 0.5 * jh;
  float e2 = e1 + 0.75 + 0.35 * mix(fract(sin(jy * 17.3) * 1531.2), fract(sin((jy + 1.0) * 17.3) * 1531.2), jf);
  float fid = floor((vP.y * 0.8 + vP.x * 0.45) / 0.95), fh = fract(sin(fid * 57.3) * 2731.9);
  vec3 c = mix(vec3(0.033, 0.038, 0.053) * (0.85 + 0.3 * fh), vec3(0.015, 0.017, 0.025) * (0.9 + 0.2 * fh), smoothstep(-0.015, 0.015, rIn - e1));

  float e3 = e2 + 0.85 + 0.4 * mix(fract(sin(jy * 33.1) * 913.7), fract(sin((jy + 1.0) * 33.1) * 913.7), jf);
  c = mix(c, vec3(0.0105, 0.012, 0.018) * (0.9 + 0.2 * fh), smoothstep(-0.015, 0.015, rIn - e2));
  c = mix(c, vec3(0.006, 0.007, 0.012), smoothstep(-0.015, 0.015, rIn - e3));
  { float sx = (vP.x - 26.65) / 0.62; float sTop = 1.85 * sqrt(max(0.0, 1.0 - sx * sx)) - 0.3 * abs(sin(vP.x * 6.1 + 0.5));
    float side = uLift * smoothstep(-0.03, 0.03, sTop - vP.y) * smoothstep(-0.03, 0.03, vP.y - 0.12 - 0.18 * abs(sin(vP.x * 4.3))) * (1.0 - step(1.0, abs(sx)));
    c = mix(c, vec3(0.03, 0.038, 0.062) * mix(1.0, 0.55, smoothstep(0.0, 1.8, vP.y)), side); }
  c = mix(vec3(0.02, 0.023, 0.031), c, smoothstep(-0.01, 0.01, rIn));
  float gx = (vP.x - 30.8) / 2.6;

  float gTop = 3.5 * sqrt(max(0.0, 1.0 - gx * gx)) - 0.55 * pow(abs(sin(vP.x * 2.6 + 0.4)), 3.0) - 0.25 * abs(sin(vP.x * 5.3 + 1.1));
  float rub = 0.75 * exp(-pow((vP.x - 29.4) / 0.6, 2.0)) + 0.55 * exp(-pow((vP.x - 32.2) / 0.85, 2.0)) + 0.2 * exp(-pow((vP.x - 30.8) / 0.3, 2.0));
  float deep = uLift * smoothstep(-0.04, 0.04, gTop - vP.y) * smoothstep(-0.04, 0.04, vP.y - rub) * (1.0 - smoothstep(0.86, 0.94, abs(gx)));
  vec3 glowC = vec3(0.06, 0.078, 0.13) * (0.85 + 0.15 * wob) * mix(1.0, 0.45, smoothstep(0.0, 3.4, vP.y));

  glowC *= 1.0 + 0.45 * (1.0 - smoothstep(0.0, 2.0, vP.y)) * (1.0 - smoothstep(0.1, 0.75, abs(gx)));
  float midR = 0.75 + 0.5 * pow(abs(sin(vP.x * 1.7 + 0.9)), 2.0) + 0.22 * abs(sin(vP.x * 4.6 + 0.2));
  float midH = 3.05 - 0.6 * pow(abs(sin(vP.x * 2.1 + 1.7)), 4.0);
  glowC = mix(glowC, glowC * 0.48, max(smoothstep(-0.03, 0.03, midR - vP.y), smoothstep(-0.03, 0.03, vP.y - midH)));
  c = mix(c, glowC, deep);
  float fl = (1.0 - smoothstep(0.05, 0.6, vP.y)) * smoothstep(23.8, 25.4, vP.x) * uLift;
  c = mix(c, mix(vec3(0.034, 0.04, 0.058), glowC * 0.85, smoothstep(26.0, 30.0, vP.x)), fl * 0.9);
  c += (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.004 * deep;
  
  { float dTop = vP.y - sqTop(vP.x);
    if (dTop > 0.0) { vec3 st = vec3(0.036, 0.04, 0.056) * (0.8 + 0.4 * wob); c = sqRim(st, vP, -dTop, 0.60 * 0.4, vec3(0.085, 0.095, 0.13));  c = mix(c, vec3(0.02, 0.022, 0.032), smoothstep(5.0, 9.0, dTop)); } }
  probeColor = vec4(0.006, 0.007, 0.012, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
