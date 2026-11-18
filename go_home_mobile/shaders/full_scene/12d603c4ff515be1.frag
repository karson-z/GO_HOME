#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[1];} source_params;


layout(location=0) in vec3 vBody;
layout(location=1) in float vH;
layout(location=2) in float vSide;
layout(location=3) in float vThrough;
layout(location=0) out vec4 probeColor;


   
void sourceMain() {
  float h = clamp(vH, 0.0, 1.0);

  vec3 body = mix(vBody, vBody * vec3(0.72, 0.74, 0.82), smoothstep(0.05, 0.5, h));
  vec3 c = mix(body, mix(vec3(0.3005, 0.2051, 0.0802), vec3(0.8388, 0.5271, 0.0908), h * h), pow(h, 3.0) * vThrough);
  c *= 0.9 + 0.2 * clamp(vSide, 0.0, 1.0);
  probeColor = vec4(c, 0.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
