#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[3];} source_params;
uniform sampler2D uMap;
#define uEgU (source_params.data[1].x)
#define uEgOld (source_params.data[2].xyz)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

 



vec3 egMix(vec3 a, vec3 b, float k) {
  vec3 p = pow(max(a, vec3(0.0)), vec3(1.0 / 3.0)), q = pow(max(b, vec3(0.0)), vec3(1.0 / 3.0));
  vec3 m = mix(p, q, k);
  return k >= 1.0 ? b : m * m * m;
}

void sourceMain() {
  vec4 t = texture(uMap, vUv);
  float w = max(fwidth(t.a), 1e-3);
  float a = clamp((t.a - 0.5) / w + 0.5, 0.0, 1.0);
  if (a < 0.01) discard;
  probeColor = vec4(egMix(uEgOld, t.rgb, uEgU), a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
