#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[1];} source_params;


layout(location=0) in vec3 vP;
layout(location=0) out vec4 probeColor;


void sourceMain() {
  float edge = -0.55 + 0.3 * sin(vP.x * 1.35 + 0.8) + 0.17 * sin(vP.x * 3.4 + 2.0) + 0.42 * smoothstep(27.0, 31.0, vP.x);
  float a = (1.0 - smoothstep(edge - 0.3, edge + 0.3, vP.z)) * smoothstep(23.8, 24.7, vP.x) * (1.0 - smoothstep(31.5, 33.6, vP.x));
  if (a <= 0.0) discard;
  probeColor = vec4(0.006, 0.007, 0.012, a * 0.92);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
