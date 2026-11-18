#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;
uniform sampler2D uMap;
#define uUv (source_params.data[1].xyzw)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;


  
void sourceMain() {
  vec4 t = texture(uMap, mix(uUv.xy, uUv.zw, vUv));
  if (t.a < 0.01) discard;
  probeColor = vec4(t.r, t.g, 0.0, t.a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
