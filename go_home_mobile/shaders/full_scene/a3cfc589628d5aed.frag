#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[4];} source_params;
uniform sampler2D uMap;
#define uColor (source_params.data[1].xyz)
#define uOpacity (source_params.data[2].x)
#define uAlphaMap (source_params.data[3].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;







void sourceMain() {
  vec4 texel = texture(uMap, vUv);
  probeColor = vec4(uColor * texel.rgb,
      uOpacity * texel.a * mix(1.0, texel.g, uAlphaMap));
  
  
}

void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uMap,vec2(0.5)).x);}
