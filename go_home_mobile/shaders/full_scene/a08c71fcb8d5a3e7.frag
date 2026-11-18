#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[11];} source_params;

#define uLayerCol (vec3[5](source_params.data[1].xyz,source_params.data[2].xyz,source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz))
#define uFogCol (source_params.data[6].xyz)
#define uFarK (source_params.data[7].x)
#define uDarkX (source_params.data[8].xyzw)
#define uDarkK (source_params.data[9].x)
#define uDarkMul (source_params.data[10].x)
layout(location=0) in vec3 vT;
layout(location=1) in vec3 vW;
layout(location=0) out vec4 probeColor;


     
 
void sourceMain() {
  float up = clamp(vT.x, 0.0, 1.0);
  float lift = vT.z + (vT.y - vT.z) * (1.0 - up) * (1.0 - up);
  vec3 c = uLayerCol[0] + uFogCol * lift;
  float kx = smoothstep(uDarkX.x - uDarkX.z, uDarkX.x, vW.x) * (1.0 - smoothstep(uDarkX.y, uDarkX.y + uDarkX.w, vW.x));
  c *= mix(1.0, uDarkMul, kx * uDarkK);
  probeColor = vec4(c, uFarK);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
