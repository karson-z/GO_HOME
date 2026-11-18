#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[1];} source_params;


layout(location=0) in vec3 vP;
layout(location=0) out vec4 probeColor;


void sourceMain() {
  float wob = 0.35 * sin(vP.x * 0.9 + 0.6) + 0.2 * sin(vP.x * 2.3 + 2.0);
  float a = smoothstep(7.8, 9.2, vP.z + wob) * smoothstep(17.0, 23.0, vP.x + wob) * (1.0 - smoothstep(30.0, 35.0, vP.x));
  if (a <= 0.0) discard;
  vec3 c = mix(vec3(0.0072, 0.0085, 0.013), vec3(0.0035, 0.004, 0.0065), smoothstep(8.5, 14.0, vP.z));
  probeColor = vec4(c, a);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
