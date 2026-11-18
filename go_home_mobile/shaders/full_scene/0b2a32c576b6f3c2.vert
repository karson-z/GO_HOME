#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[14];} source_params;

#define projectionMatrix (mat4(source_params.data[1].xyzw,source_params.data[2].xyzw,source_params.data[3].xyzw,source_params.data[4].xyzw))
#define viewMatrix (mat4(source_params.data[5].xyzw,source_params.data[6].xyzw,source_params.data[7].xyzw,source_params.data[8].xyzw))
#define modelMatrix (mat4(source_params.data[9].xyzw,source_params.data[10].xyzw,source_params.data[11].xyzw,source_params.data[12].xyzw))
#define cameraPosition (source_params.data[13].xyz)
layout(location=0) out float vA;
layout(location=1) out vec2 vUv2;
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
layout(location=11) in float instance_aA;
#define aA instance_aA
mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;
#define USE_INSTANCING 


 
void sourceMain() { vA = aA; vUv2 = uv; gl_Position = projectionMatrix * viewMatrix * modelMatrix * instanceMatrix * vec4(position, 1.0); }
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+instance_aA+frame_info.camera_transform[0][0]);}
