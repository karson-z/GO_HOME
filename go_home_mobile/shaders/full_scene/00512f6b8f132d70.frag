#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[13];} source_params;
uniform sampler2D uNoise;
#define uTime (source_params.data[1].x)
#define uLayerCol (vec3[5](source_params.data[2].xyz,source_params.data[3].xyz,source_params.data[4].xyz,source_params.data[5].xyz,source_params.data[6].xyz))
#define uFogCol (source_params.data[7].xyz)
#define uLightCol (source_params.data[8].xyz)
#define uLightAmt (source_params.data[9].x)
#define uSurfaceY (source_params.data[10].x)
#define uShade (source_params.data[11].x)
#define uEat (source_params.data[12].x)
layout(location=0) in vec3 vN;
layout(location=1) in vec3 vW;
layout(location=0) out vec4 probeColor;


        
 
float caustic(vec2 p) {
  float a = texture(uNoise, p * 0.11 + vec2(uTime * 0.012, uTime * 0.007)).r;
  float b = texture(uNoise, p * 0.17 - vec2(uTime * 0.009, -uTime * 0.011)).g;
  return pow(1.0 - min(abs(a - b) * 6.5, 1.0), 4.0);
}
void sourceMain() {
  float nl = length(vN);
  vec3 N = nl > 1e-5 ? vN / nl : vec3(0.0, 1.0, 0.0);
  float up = 0.2 + 0.8 * pow(max(N.y, 0.0), 3.0);
  vec3 col = mix(uLayerCol[3], uLayerCol[4], 0.25);
  col *= 1.0 + 0.12 * smoothstep(-3.0, 1.0, vW.z);
  col += uLightCol * caustic(vW.xz * vec2(1.0, 1.6) + vW.y) * 0.05 * uLightAmt * max(N.y, 0.0);

  float back = smoothstep(1.0, 20.0, -vW.z);
  vec3 deep = mix(uLayerCol[3], uFogCol, 0.25) * 0.8;
  col = mix(col, deep, back * 0.92) * mix(1.0, up, 0.85);

  col *= mix(1.0, 0.78, smoothstep(0.6, 2.6, uSurfaceY - vW.y));

  col = mix(col, mix(uLayerCol[3], uFogCol, 0.2) * 0.8, 1.0 - exp(-max(0.0, -vW.z) * uEat));
  col *= uShade;
  probeColor = vec4(col, 1.0);
}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(uNoise,vec2(0.5)).x);}
