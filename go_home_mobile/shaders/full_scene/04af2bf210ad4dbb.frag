#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[11];} source_params;

#define uCol (source_params.data[1].xyz)
#define uLift (source_params.data[2].x)
#define uClipY (source_params.data[3].x)
#define uOpacity (source_params.data[4].x)
#define uPropA (source_params.data[5].x)
#define uBodyL (source_params.data[6].x)
#define uPropTop (source_params.data[7].x)
#define uPropSide (source_params.data[8].x)
#define uPropC (source_params.data[9].x)
#define uPropH (source_params.data[10].x)
layout(location=0) in float vUp;
layout(location=1) in float vWy;
layout(location=0) out vec4 probeColor;


    
    
 
vec3 oklch(float L, float C, float h) {
  float a = C * cos(h), b = C * sin(h);
  float l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  float m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  float s_ = L - 0.0894841775 * a - 1.2914855480 * b;
  l_ = l_ * l_ * l_; m_ = m_ * m_ * m_; s_ = s_ * s_ * s_;
  return max(vec3(4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
                 -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
                 -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_), 0.0);
}
void sourceMain() {
  if (vWy < uClipY) discard;
  float up = step(0.25, vUp);

  vec3 c = uBodyL < 0.0 ? uCol * mix(0.68, 1.0, up) * uLift : oklch(uBodyL + mix(uPropSide, uPropTop, up), uPropC, uPropH);
  probeColor = vec4(c, uOpacity * uPropA);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
