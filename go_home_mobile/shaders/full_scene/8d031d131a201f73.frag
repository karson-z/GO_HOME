#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[11];} source_params;

#define uCol (source_params.data[1].xyz)
#define uOp (source_params.data[2].x)
#define uDir (source_params.data[3].x)
#define uT (source_params.data[4].x)
#define uMove (source_params.data[5].x)
#define uPhase (source_params.data[6].x)
#define uLen (source_params.data[7].x)
#define uRear (source_params.data[8].x)
#define uFront (source_params.data[9].x)
#define uH (source_params.data[10].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;


     
   

float g(float x, float c, float w) { float d = (x - c) / w; return exp(-d * d); }
void sourceMain() {
  float u = uDir > 0.0 ? vUv.x : 1.0 - vUv.x;
  float xm = u * uLen;
  float y = (vUv.y - 0.5) * uH;
  float body = smoothstep(uRear - 0.05, uRear + 0.15, xm) * (1.0 - smoothstep(uFront - 0.05, uFront + 0.1, xm));
  float L = uFront - uRear;
  float fl = uRear + 0.78 * L, hl = uRear + 0.22 * L;
  float s = sin(6.2831853 * uPhase);
  float crest = 0.04
    + uMove * 0.18 * g(xm, uFront - 0.08, 0.28)
    + uMove * 0.08 * body * (g(xm, fl, 0.24) * (0.5 + 0.5 * s) + g(xm, hl, 0.24) * (0.5 - 0.5 * s))
    + 0.012 * sin(6.2831853 * xm / 0.38 + 4.0 * uT) * (0.4 + 0.6 * uMove);

  float behind = max(0.0, uRear - xm), ahead = max(0.0, xm - uFront);

  float trail = uMove * 0.045 * exp(-behind / 0.45) * max(0.0, sin(6.2831853 * behind / 0.3 - 7.0 * uT));
  float push = uMove * 0.06 * exp(-ahead / 0.14);
  float outside = xm < uRear ? 1.0 : xm > uFront ? 1.0 : 0.0;
  crest = xm < uRear ? 0.008 + trail : xm > uFront ? 0.008 + push : crest;
  float water = smoothstep(-0.03, -0.005, y) * (1.0 - smoothstep(crest - 0.006, crest + 0.004, y));


  float rimK = xm < uRear ? 0.0 : mix(1.0, smoothstep(0.012, 0.03, crest), outside);
  float rd = (y - crest + 0.006) / 0.016;
  float rim = exp(-rd * rd) * rimK;
  float foam = uMove * g(xm, uFront - 0.08, 0.3);
  float ends = smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.86, 1.0, u));
  float a = uOp * ends * max((0.5 + 0.35 * foam) * water * (xm < uRear ? 0.0 : mix(1.0, rimK, outside)), 0.95 * rim);
  vec3 c = mix(uCol * 1.08, vec3(0.97, 0.96, 0.93), max(0.62 * rim, 0.55 * foam * water));
  probeColor = vec4(c, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
