#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[41];} source_params;

#define uTime (source_params.data[1].x)
#define uGroundCtl (source_params.data[2].xyz)
#define uWind (source_params.data[3].xyz)
#define uWindK (source_params.data[4].x)
#define uWindW (source_params.data[5].x)
#define uDetail (source_params.data[6].x)
#define uGlowN (int(source_params.data[7].x))
#define uDarkX (source_params.data[8].xyzw)
#define uDarkK (source_params.data[9].x)
#define uDarkMul (source_params.data[10].x)
#define uGlowPos (vec4[8](source_params.data[11].xyzw,source_params.data[12].xyzw,source_params.data[13].xyzw,source_params.data[14].xyzw,source_params.data[15].xyzw,source_params.data[16].xyzw,source_params.data[17].xyzw,source_params.data[18].xyzw))
#define uGlowCol (vec3[8](source_params.data[19].xyz,source_params.data[20].xyz,source_params.data[21].xyz,source_params.data[22].xyz,source_params.data[23].xyz,source_params.data[24].xyz,source_params.data[25].xyz,source_params.data[26].xyz))
#define uGlowSoft (source_params.data[27].x)
#define projectionMatrix (mat4(source_params.data[28].xyzw,source_params.data[29].xyzw,source_params.data[30].xyzw,source_params.data[31].xyzw))
#define viewMatrix (mat4(source_params.data[32].xyzw,source_params.data[33].xyzw,source_params.data[34].xyzw,source_params.data[35].xyzw))
#define modelMatrix (mat4(source_params.data[36].xyzw,source_params.data[37].xyzw,source_params.data[38].xyzw,source_params.data[39].xyzw))
#define cameraPosition (source_params.data[40].xyz)
layout(location=0) out float vCov;
layout(location=1) out float vH;
layout(location=2) out vec3 vLit;
layout(location=3) out vec3 vO;
layout(location=4) out vec3 vW;
layout(set=0,binding=0) uniform FrameInfo {mat4 camera_transform;vec3 camera_position;float depth_bias;vec4 depth_offset;vec4 depth_slope;} frame_info;
layout(location=0) in vec3 position;
layout(location=1) in vec3 normal;
layout(location=2) in vec2 texture_coords;
layout(location=3) in vec2 texture_coords_1;
layout(location=4) in vec4 color;
layout(location=5) in vec4 tangent;
layout(location=6) in float aH;
layout(location=7) in float aSide;
layout(location=8) in float aHW;
layout(location=9) in vec4 model_transform_0;
layout(location=10) in vec4 model_transform_1;
layout(location=11) in vec4 model_transform_2;
layout(location=12) in vec4 model_transform_3;
layout(location=13) in vec4 instance_color;

mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;







    





float windGust(float x, float t) {
  float p = x * uWindK - t * uWindW;
  float g = (0.5 + 0.5 * sin(p)) * (0.6 + 0.4 * sin(p * 0.37 + 1.7));
  return g * g;
}

float windSway(float x, float ph, float t, float hz) {
  float g = windGust(x, t);
  float w = 6.2832 * hz * t + ph;
  float o = sin(w) * 0.7 + sin(w * 1.83 + ph) * 0.3;
  return uWind.x * (g * 0.6 + (0.5 + 0.5 * g) * o * 0.5);
}

float windAmp(float z, float pct) { return pct * 0.008866 * max(18.4 - z, 1.0); }

float windS(float x, float ph, float t, float seed) { return windSway(x, ph, t, 0.3) * 1.4; }








float ffDark(vec3 W) {
  float kx = smoothstep(uDarkX.x - uDarkX.z, uDarkX.x, W.x) * (1.0 - smoothstep(uDarkX.y, uDarkX.y + uDarkX.w, W.x));

  float kz = smoothstep(-26.0, -9.0, W.z);
  return kx * kz * uDarkK;
}
vec3 ffLight(vec3 W, vec3 N, float wrapK) {
  vec3 s = vec3(0.0);
  for (int i = 0; i < uGlowN; i++) {
    vec3 Lp = uGlowPos[i].xyz - W;
    float d = length(Lp);
    float R = max(uGlowPos[i].w, 1e-3);
    float g = clamp((R - d) / (R * 0.55), 0.0, 1.0);
    g = g * g * (3.0 - 2.0 * g);
    float gt = max(1.0 - d / R, 0.0);
    g = mix(g, gt * gt * gt, uGlowSoft);
    s += uGlowCol[i] * g * (wrapK + (1.0 - wrapK) * max(dot(N, Lp / max(d, 1e-3)), 0.0));
  }
  return s;
}
void sourceMain() {
  vH = aH;
  vec4 w = modelMatrix * instanceMatrix * vec4(position, 1.0);
  vec4 o = modelMatrix * instanceMatrix * vec4(0.0, 0.0, 0.0, 1.0);
  float scale = length(instanceMatrix[1].xyz);
  float s = windSway(o.x, o.x * 2.1 + o.z * 3.0, uTime, 0.42);

  w.x += s * aH * aH * min(0.34 * scale, windAmp(o.z, 1.0));


  vCov = 1.0;
  if (uGroundCtl.y > 0.0) {
    vec3 side = mat3(instanceMatrix) * vec3(1.0, 0.0, 0.0);
    float cur = aHW * length(side) * abs(side.x) / max(length(side), 1e-4);
    float need = 0.5 * uGroundCtl.y * uGroundCtl.z * length(cameraPosition - w.xyz);
    if (cur < need) {
      w.x += aSide * (need - cur);
      vCov = cur / max(need, 1e-4);
    }
  }
  vW = w.xyz; vO = o.xyz;

  vLit = ffLight(w.xyz, vec3(0.0, 1.0, 0.0), 1.0);
  gl_Position = projectionMatrix * viewMatrix * w;
}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+aH+aSide+aHW+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+frame_info.camera_transform[0][0]);}
