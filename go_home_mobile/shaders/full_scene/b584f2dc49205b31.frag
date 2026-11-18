#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[13];} source_params;
uniform sampler2D uMap;
#define uWaterY (source_params.data[1].x)
#define uOpacity (source_params.data[2].x)
#define uDepth (source_params.data[3].x)
#define uStr (source_params.data[4].x)
#define uT (source_params.data[5].x)
#define uTint (source_params.data[6].xyz)
#define uTexel (source_params.data[7].xy)
#define uBlur (source_params.data[8].x)
#define uFull (source_params.data[9].x)
#define uBlur0 (source_params.data[10].x)
#define uCx (source_params.data[11].x)
#define uTaper (source_params.data[12].x)
layout(location=0) in vec2 vUv;
layout(location=1) in float vWx;
layout(location=2) in float vWy;
layout(location=0) out vec4 probeColor;


     
      
  
void sourceMain() {
  float d = uWaterY - vWy;
  if (d < 0.0) discard;
  float q = clamp(d / uDepth, 0.0, 1.0);

  vec2 uv = vec2(uCx + (vUv.x - uCx) * (1.0 + uTaper * q), vUv.y) + vec2(sin(vWy * 40.0 + uT * 3.0) * 0.006 * clamp(d / 0.15, 0.0, 1.0), 0.0);
  float r = uBlur0 + uBlur * q;
  float a = 0.0;
  for (int i = -2; i <= 2; i++) for (int j = -2; j <= 2; j++) a += texture(uMap, uv + vec2(float(i), float(j)) * 0.5 * r * uTexel).a;
  a /= 25.0;
  float k = 1.0 - smoothstep(uFull, uDepth, d);
  float w = a * k * uStr * uOpacity;
  if (w < 0.004) discard;
  probeColor = vec4(mix(vec3(1.0), uTint, w), 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
