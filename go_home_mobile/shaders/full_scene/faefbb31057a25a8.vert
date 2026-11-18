#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[18];} source_params;

#define sourceViewport (source_params.data[1].xy)
#define uTime (source_params.data[2].x)
#define uDrift (source_params.data[3].x)
#define uBlink (source_params.data[4].x)
#define projectionMatrix (mat4(source_params.data[5].xyzw,source_params.data[6].xyzw,source_params.data[7].xyzw,source_params.data[8].xyzw))
#define viewMatrix (mat4(source_params.data[9].xyzw,source_params.data[10].xyzw,source_params.data[11].xyzw,source_params.data[12].xyzw))
#define modelMatrix (mat4(source_params.data[13].xyzw,source_params.data[14].xyzw,source_params.data[15].xyzw,source_params.data[16].xyzw))
#define cameraPosition (source_params.data[17].xyz)
layout(location=0) out vec2 sourcePointCoord;
layout(location=1) out float vA;
layout(set=0,binding=0) uniform FrameInfo {mat4 camera_transform;vec3 camera_position;float depth_bias;vec4 depth_offset;vec4 depth_slope;} frame_info;
layout(location=0) in vec3 position;
layout(location=1) in vec3 normal;
layout(location=2) in vec2 texture_coords;
layout(location=3) in vec2 texture_coords_1;
layout(location=4) in vec4 color;
layout(location=5) in vec4 tangent;
layout(location=6) in vec2 aPointCorner;
layout(location=7) in float aSeed;
layout(location=8) in float aSize;
layout(location=9) in float aAmt;
layout(location=10) in vec4 model_transform_0;
layout(location=11) in vec4 model_transform_1;
layout(location=12) in vec4 model_transform_2;
layout(location=13) in vec4 model_transform_3;
layout(location=14) in vec4 instance_color;

mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;

  

  
  

void pointMain() {
  vec3 p = position;
  p.x += sin(uTime * 0.31 + aSeed) * uDrift + sin(uTime * 0.73 + aSeed * 2.1) * uDrift * 0.35;
  p.y += sin(uTime * 0.23 + aSeed * 1.7) * uDrift * 0.6;
  p.z += cos(uTime * 0.19 + aSeed * 0.7) * uDrift * 0.3;
  vec4 mv = modelViewMatrix * vec4(p, 1.0);
  float b = 0.5 + 0.5 * sin(uTime * 0.9 + aSeed * 3.3);
  vA = aAmt * mix(1.0, b * b, uBlink);
  sourcePointSize = aSize * projectionMatrix[1][1] * 360.0 / max(0.1, -mv.z);
  gl_Position = projectionMatrix * mv;
}
void sourceMain(){pointMain();sourcePointCoord=aPointCorner+0.5;gl_Position.xy+=aPointCorner*sourcePointSize*2.0/sourceViewport*gl_Position.w;}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+aPointCorner.x+aSeed+aSize+aAmt+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+frame_info.camera_transform[0][0]);}
