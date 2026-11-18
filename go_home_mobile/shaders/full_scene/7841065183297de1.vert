#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[21];} source_params;

#define uTime (source_params.data[1].x)
#define uSway (source_params.data[2].x)
#define uFlutter (source_params.data[3].x)
#define uWind (source_params.data[4].xyz)
#define uWindK (source_params.data[5].x)
#define uWindW (source_params.data[6].x)
#define uDetail (source_params.data[7].x)
#define projectionMatrix (mat4(source_params.data[8].xyzw,source_params.data[9].xyzw,source_params.data[10].xyzw,source_params.data[11].xyzw))
#define viewMatrix (mat4(source_params.data[12].xyzw,source_params.data[13].xyzw,source_params.data[14].xyzw,source_params.data[15].xyzw))
#define modelMatrix (mat4(source_params.data[16].xyzw,source_params.data[17].xyzw,source_params.data[18].xyzw,source_params.data[19].xyzw))
#define cameraPosition (source_params.data[20].xyz)
layout(location=0) out vec3 vNormalW;
layout(location=1) out vec3 vOrigin;
layout(location=2) out vec3 vWorld;
layout(set=0,binding=0) uniform FrameInfo {mat4 camera_transform;vec3 camera_position;float depth_bias;vec4 depth_offset;vec4 depth_slope;} frame_info;
layout(location=0) in vec3 position;
layout(location=1) in vec3 normal;
layout(location=2) in vec2 texture_coords;
layout(location=3) in vec2 texture_coords_1;
layout(location=4) in vec4 color;
layout(location=5) in vec4 tangent;
layout(location=6) in vec4 model_transform_0;
layout(location=7) in vec4 model_transform_1;
layout(location=8) in vec4 model_transform_2;
layout(location=9) in vec4 model_transform_3;
layout(location=10) in vec4 instance_color;

mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;
#define DOUBLE_SIDED 












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
void sourceMain() {
  vec4 w = vec4(position, 1.0);
  vec3 n = normal;
  vec4 o = vec4(0.0, 0.0, 0.0, 1.0);
  #ifdef USE_INSTANCING
    w = instanceMatrix * w;
    n = mat3(instanceMatrix) * n;
    o = instanceMatrix * o;
  #endif
  w = modelMatrix * w;
  o = modelMatrix * o;
  vOrigin = o.xyz;
  if (uSway > 0.0) {

    float hgt = max((w.y - o.y) * sign(modelMatrix[1].y), 0.0);
    float s = windSway(o.x, o.x * 1.7 + o.z * 0.9, uTime, 0.22);
    w.x += s * uSway * 0.06 * hgt * hgt / (1.0 + hgt * 0.25);
  }
  if (uFlutter > 0.0) {
    float hgt = max(w.y - o.y, 0.0);
    float q = w.x * 2.3 + w.y * 1.7 + w.z * 1.9;
    float amt = uFlutter * uWind.x * min(hgt * 0.5, 1.0);
    w.x += sin(uTime * 3.1 + q) * amt;
    w.y += sin(uTime * 2.3 + q * 1.3) * amt * 0.6;
    w.z += sin(uTime * 2.7 + q * 0.7) * amt * 0.5;
  }
  vWorld = w.xyz;
  vNormalW = mat3(modelMatrix) * n;
  gl_Position = projectionMatrix * viewMatrix * w;
}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+frame_info.camera_transform[0][0]);}
