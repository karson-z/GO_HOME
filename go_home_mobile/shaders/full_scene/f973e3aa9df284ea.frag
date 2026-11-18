#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[4];} source_params;

#define uCol (source_params.data[1].xyz)
#define uRim (source_params.data[2].xyz)
#define uClipY (source_params.data[3].x)
layout(location=0) in vec3 vN;
layout(location=1) in vec3 vV;
layout(location=2) in float vWY;
layout(location=0) out vec4 probeColor;

     
void sourceMain() { if (vWY < uClipY) discard;
  float f = 1.0 - clamp(dot(normalize(vN), normalize(vV)), 0.0, 1.0);
  float up = 0.5 + 0.5 * normalize(vN).y;
  vec3 c = uCol * (0.72 + 0.28 * up) + uRim * pow(f, 3.0) * 0.55;
  probeColor = vec4(c, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
