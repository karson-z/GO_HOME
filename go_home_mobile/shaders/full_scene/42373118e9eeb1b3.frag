#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[8];} source_params;

#define uLayerCol (vec3[5](source_params.data[1].xyz,source_params.data[2].xyz,source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz))
#define uLightCol (source_params.data[6].xyz)
#define uK (source_params.data[7].x)
layout(location=0) in vec3 vN;
layout(location=1) in vec3 vP;
layout(location=0) out vec4 probeColor;


    

void sourceMain() {
  vec3 N = normalize(vN);

  vec3 col = mix(mix(uLayerCol[3], uLightCol, 0.05), mix(uLayerCol[3], uLightCol, 0.3), uK);

  col *= 0.7 + 0.46 * smoothstep(-0.2, 0.95, N.y);
  probeColor = vec4(col, smoothstep(0.0, 0.1, vP.y));
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0);}
