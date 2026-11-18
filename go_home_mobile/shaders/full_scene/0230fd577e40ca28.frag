#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[17];} source_params;
uniform sampler2D tDiffuse;
#define uTime (source_params.data[1].x)
#define uRes (source_params.data[2].xy)
#define uExposure (source_params.data[3].x)
#define uLift (source_params.data[4].x)
#define uGain (source_params.data[5].x)
#define uShadowTint (source_params.data[6].xyz)
#define uHighTint (source_params.data[7].xyz)
#define uSat (source_params.data[8].x)
#define uDarkDesat (source_params.data[9].x)
#define uContrast (source_params.data[10].x)
#define uVignette (source_params.data[11].x)
#define uGrain (source_params.data[12].x)
#define uPaper (source_params.data[13].x)
#define uHighK (source_params.data[14].x)
#define uSplitK (source_params.data[15].x)
#define uDarkTintK (source_params.data[16].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;




















float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void sourceMain() {
  vec3 c = texture(tDiffuse, vUv).rgb * uExposure;
  float l = dot(c, vec3(0.2126, 0.7152, 0.0722));

  float sat = mix(0.35, 1.15, uSat) * (1.0 - uDarkDesat * (1.0 - smoothstep(0.02, 0.25, l)));
  c = mix(vec3(l), c, sat);

  float sh = 1.0 - smoothstep(0.0, 0.18, l);
  float hi = smoothstep(0.25, 1.2, l);
  c = mix(c, c * 0.6 + uShadowTint * 0.5, sh * 0.35 * uSplitK);
  c = mix(c, c * uHighTint * 1.15, hi * 0.35 * uHighK);

  float k = mix(0.85, 1.25, uContrast);
  c = pow(max(c, vec3(1e-5)) / 0.18, vec3(k)) * 0.18;

  c = c * uGain + uLift * 0.25 * (1.0 - c / (1.0 + c));

  if (uPaper > 0.001) {
    float p = vnoise(vUv * uRes / 3.0) * 0.5 + vnoise(vUv * uRes / 11.0) * 0.35 + vnoise(vUv * uRes / 40.0) * 0.15;
    c *= 1.0 + (p - 0.5) * 0.22 * uPaper;
    c = mix(c, c + vec3(0.03, 0.028, 0.022), uPaper * 0.6);
  }

  float lw0 = dot(c, vec3(0.2126, 0.7152, 0.0722));
  float darkK = 1.0 - smoothstep(0.03, 0.13, lw0);

  vec3 tintN = uShadowTint / max(dot(uShadowTint, vec3(0.2126, 0.7152, 0.0722)), 1e-4);

  vec3 tintD = mix(vec3(1.0), tintN, 0.05) * vec3(1.03, 0.97, 1.08);
  c = mix(c, lw0 * tintD, darkK * 0.55 * uDarkTintK);

  vec2 q = vUv - 0.5;
  q.x *= uRes.x / uRes.y * 0.75;
  float v = (1.0 - smoothstep(0.2, 0.85, length(q)));
  c *= mix(1.0, v, uVignette * 1.4);

  float g = hash(vUv * uRes + fract(uTime * 13.7) * 100.0) - 0.5;
  float lw = smoothstep(0.0, 0.08, l) * (1.0 - smoothstep(0.6, 2.0, l));
  c += c * g * uGrain * 4.0 * lw + g * uGrain * 0.03;

  c += (hash(vUv * uRes + 17.0) - 0.5) / 255.0;
  probeColor = vec4(max(c, vec3(0.0)), 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(tDiffuse,vec2(0.5)).x);}
