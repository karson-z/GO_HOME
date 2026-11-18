#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[7];} source_params;

#define uCol (source_params.data[1].xyz)
#define uOp (source_params.data[2].x)
#define uMove (source_params.data[3].x)
#define uT (source_params.data[4].x)
#define uSize (source_params.data[5].xy)
#define uAhead (source_params.data[6].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;


     

void sourceMain() {
  float s = vUv.x * uSize.x - (uSize.x - uAhead);
  float w = (vUv.y - 0.5) * uSize.y;
  float b = max(0.0, -s);
  float ad = (abs(w) - 0.354 * b - 0.06) / (0.06 + 0.06 * b);
  float arm = exp(-ad * ad) * exp(-b / 0.75) * smoothstep(0.0, 0.12, b);
  float bd = (length(vec2(max(s, 0.0) * 1.6, w)) - 0.18) / 0.035;
  float bow = exp(-bd * bd) * (s > -0.05 ? 1.0 : 0.0);
  float ripple = 0.5 + 0.5 * sin(b * 26.0 - uT * 9.0);
  float a = uOp * uMove * max(arm * (0.6 + 0.4 * ripple), bow);
  if (a < 0.004) discard;
  probeColor = vec4(uCol, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
