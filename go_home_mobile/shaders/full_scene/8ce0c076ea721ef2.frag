#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[7];} source_params;
uniform sampler2D uNoise;
#define uTime (source_params.data[1].x)
#define uLightCol (source_params.data[2].xyz)
#define uLightAmt (source_params.data[3].x)
#define uWaterY (source_params.data[4].x)
#define uDepth (source_params.data[5].x)
#define uFade (source_params.data[6].x)
layout(location=0) in vec3 vW;
layout(location=0) out vec4 probeColor;


      

void sourceMain() {
  float depth = uWaterY - vW.y;

  float u = vW.x + depth * 0.34;
  float a = texture(uNoise, vec2(u * 0.055 + uTime * 0.0035, 0.31)).r;
  float b = texture(uNoise, vec2(u * 0.13 - uTime * 0.005, 0.67)).g;
  float s = pow(smoothstep(0.58, 0.8, a), 1.6) * (0.6 + 0.6 * b);
  float along = smoothstep(0.0, 0.25, depth) * (1.0 - smoothstep(0.35, 1.0, depth / uDepth));
  probeColor = vec4(uLightCol * s * along * 0.2 * uLightAmt * uFade, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
