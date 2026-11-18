#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[5];} source_params;

#define uDeep (source_params.data[1].xyz)
#define uWarm (source_params.data[2].xyz)
#define uRim (source_params.data[3].xyz)
#define uK (source_params.data[4].x)
layout(location=0) in vec2 vP;
layout(location=0) out vec4 probeColor;


    
void sourceMain() {
  float r = length(vP);
  vec3 c = mix(uDeep, uWarm, (1.0 - smoothstep(-1.0, 0.1, vP.y)) * uK);
  c = mix(c, uRim * 0.42, smoothstep(0.9, 0.985, r) * (0.35 + 0.65 * (1.0 - smoothstep(-0.8, 0.6, vP.y))));
  probeColor = vec4(c, 0.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
