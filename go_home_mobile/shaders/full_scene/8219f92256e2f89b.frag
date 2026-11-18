#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;
uniform sampler2D tDiffuse;
#define uToe (source_params.data[1].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;





vec3 neutral(vec3 color) {
  const float StartCompression = 0.8 - 0.04;
  const float Desaturation = 0.15;
  float x = min(color.r, min(color.g, color.b));
  float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
  offset *= mix(smoothstep(0.05, 0.25, x), 1.0, uToe);
  color -= offset;
  float peak = max(color.r, max(color.g, color.b));
  if (peak < StartCompression) return color;
  float d = 1.0 - StartCompression;
  float newPeak = 1.0 - d * d / (peak + d - StartCompression);
  color *= newPeak / peak;
  float g = 1.0 - 1.0 / (Desaturation * (peak - newPeak) + 1.0);
  return mix(color, vec3(newPeak), g);
}
vec3 toSrgb(vec3 c) {
  return mix(c * 12.92, 1.055 * pow(max(c, vec3(1e-6)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
void sourceMain() {
  probeColor = vec4(toSrgb(clamp(neutral(texture(tDiffuse, vUv).rgb), 0.0, 1.0)), 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(tDiffuse,vec2(0.5)).x);}
