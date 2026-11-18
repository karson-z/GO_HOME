#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[19];} source_params;

#define uTime (source_params.data[1].x)
#define uWind (source_params.data[2].xyz)
#define uWindK (source_params.data[3].x)
#define uWindW (source_params.data[4].x)
#define uDetail (source_params.data[5].x)
#define projectionMatrix (mat4(source_params.data[6].xyzw,source_params.data[7].xyzw,source_params.data[8].xyzw,source_params.data[9].xyzw))
#define viewMatrix (mat4(source_params.data[10].xyzw,source_params.data[11].xyzw,source_params.data[12].xyzw,source_params.data[13].xyzw))
#define modelMatrix (mat4(source_params.data[14].xyzw,source_params.data[15].xyzw,source_params.data[16].xyzw,source_params.data[17].xyzw))
#define cameraPosition (source_params.data[18].xyz)
layout(location=0) out float vH;
layout(location=1) out vec3 vO;
layout(location=2) out vec3 vW;
layout(set=0,binding=0) uniform FrameInfo {mat4 camera_transform;vec3 camera_position;float depth_bias;vec4 depth_offset;vec4 depth_slope;} frame_info;
layout(location=0) in vec3 position;
layout(location=1) in vec3 normal;
layout(location=2) in vec2 texture_coords;
layout(location=3) in vec2 texture_coords_1;
layout(location=4) in vec4 color;
layout(location=5) in vec4 tangent;
layout(location=6) in float aH;
layout(location=7) in vec4 model_transform_0;
layout(location=8) in vec4 model_transform_1;
layout(location=9) in vec4 model_transform_2;
layout(location=10) in vec4 model_transform_3;
layout(location=11) in vec4 instance_color;

mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;
#define USE_INSTANCING 



  





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
  vH = aH;
  vec4 w = modelMatrix * instanceMatrix * vec4(position, 1.0);
  vec4 o = modelMatrix * instanceMatrix * vec4(0.0, 0.0, 0.0, 1.0);
  float s = windS(o.x, o.x * 2.1 + o.z * 3.0, uTime, 0.0);
  float scale = length(instanceMatrix[1].xyz);
  w.x += s * aH * aH * 0.075 * scale;
  vW = w.xyz; vO = o.xyz;
  gl_Position = projectionMatrix * viewMatrix * w;
}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+aH+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+frame_info.camera_transform[0][0]);}
