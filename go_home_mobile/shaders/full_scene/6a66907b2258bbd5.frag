#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;
uniform sampler2D tDiffuse;
#define uTexel (source_params.data[1].xy)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

  
vec3 safe(vec3 c) { return (any(isnan(c)) || any(isinf(c))) ? vec3(0.0) : min(c, vec3(8.0)); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void sourceMain() {
  vec4 raw = texture(tDiffuse, vUv);
  vec3 c = safe(raw.rgb);
  vec3 a = safe(texture(tDiffuse, vUv + vec2(uTexel.x, 0.0)).rgb), b = safe(texture(tDiffuse, vUv - vec2(uTexel.x, 0.0)).rgb);
  vec3 d = safe(texture(tDiffuse, vUv + vec2(0.0, uTexel.y)).rgb), e = safe(texture(tDiffuse, vUv - vec2(0.0, uTexel.y)).rgb);
  float near = max(max(lum(a), lum(b)), max(lum(d), lum(e)));
  bool bad = any(isnan(raw.rgb)) || any(isinf(raw.rgb)) || (lum(c) > 0.6 && lum(c) > near * 2.5);
  float al = (isnan(raw.a) || isinf(raw.a)) ? 0.0 : clamp(raw.a, 0.0, 1.0);
  probeColor = vec4(bad ? (a + b + d + e) * 0.25 : c, al);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(tDiffuse,vec2(0.5)).x);}
