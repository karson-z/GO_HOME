#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[6];} source_params;
uniform sampler2D uMap;
#define uLayerCol (vec3[5](source_params.data[1].xyz,source_params.data[2].xyz,source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz))
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

  
void sourceMain() {
  vec4 t = texture(uMap, vUv);
  float w = max(fwidth(t.a), 1e-3);
  float a = clamp((t.a - 0.5) / w + 0.5, 0.0, 1.0);
  if (a < 0.01) discard;
  float lum = dot(t.rgb, vec3(0.3, 0.55, 0.15));
  vec3 base = mix(uLayerCol[1], uLayerCol[2], 0.45);

  float hi = mix(2.8, 2.0, smoothstep(0.42, 0.56, vUv.y));
  probeColor = vec4(base * mix(1.25, hi, smoothstep(0.03, 0.3, lum)), a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
