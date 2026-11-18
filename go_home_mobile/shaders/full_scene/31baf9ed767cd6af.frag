#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[12];} source_params;
uniform sampler2D uMap;
#define uLayerCol (vec3[5](source_params.data[1].xyz,source_params.data[2].xyz,source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz))
#define uWaterY (source_params.data[6].x)
#define uFull (source_params.data[7].x)
#define uNone (source_params.data[8].x)
#define uAlpha (source_params.data[9].x)
#define uOpacity (source_params.data[10].x)
#define uDarken (source_params.data[11].x)
layout(location=0) in vec2 vUv;
layout(location=1) in float vWx;
layout(location=2) in float vWy;
layout(location=0) out vec4 probeColor;










 
void sourceMain() {
  vec4 t = texture(uMap, vUv);
  float a = t.a;
  if (a < 0.01 || vWy > uWaterY) discard;
  float v = t.r / a;
  float k = smoothstep(uWaterY - uNone, uWaterY - uFull, vWy);
  float w = a * uAlpha * k * uOpacity;

  if (uDarken > 0.0) { probeColor = vec4(vec3(1.0 - uDarken * w * (0.9 + 0.35 * (0.42 - v))), 1.0); return; }
  vec3 col = uLayerCol[1] * (0.9 + 0.35 * (v - 0.42));
  probeColor = vec4(col, w);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
