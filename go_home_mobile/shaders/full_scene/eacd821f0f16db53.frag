#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[6];} source_params;

#define sourcePolygonOffset (source_params.data[1].xy)
#define uShown (source_params.data[2].x)
#define uLight (source_params.data[3].xyz)
#define uThick (source_params.data[4].x)
#define cameraPosition (source_params.data[5].xyz)
layout(location=0) in float vH;
layout(location=1) in vec3 vN;
layout(location=2) in vec3 vW;
layout(location=0) out vec4 probeColor;



  
  
void sourceUnbiasedMain() {
  vec3 N = normalize(vN), V = normalize(cameraPosition - vW);
  float fres = clamp(1.0 - abs(dot(N, V)), 0.0, 1.0);
  float h = abs(vH);

  float top = (1.0 - smoothstep(0.03, 0.17, h)) * (0.3 + 0.7 * smoothstep(0.55, 0.95, abs(N.y)));
  float fall = mix(0.05, 0.13, uThick) * exp(-h * 3.0);
  float side = pow(fres, 2.2) * 0.22 * exp(-h * 2.0);
  probeColor = vec4(uLight * (top * 0.36 + fall + side) * uShown, 1.0);
}
void sourceMain(){sourceUnbiasedMain();float z=gl_FragCoord.z;float slope=max(abs(dFdx(z)),abs(dFdy(z)));gl_FragDepth=clamp(z+sourcePolygonOffset.x*slope+sourcePolygonOffset.y*(1.0/16777216.0),0.0,1.0);}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
