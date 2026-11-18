#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[19];} source_params;

#define sourceViewport (source_params.data[1].xy)
#define uTime (source_params.data[2].x)
#define uPx (source_params.data[3].x)
#define uCam (source_params.data[4].xyz)
#define uMotes (source_params.data[5].x)
#define projectionMatrix (mat4(source_params.data[6].xyzw,source_params.data[7].xyzw,source_params.data[8].xyzw,source_params.data[9].xyzw))
#define viewMatrix (mat4(source_params.data[10].xyzw,source_params.data[11].xyzw,source_params.data[12].xyzw,source_params.data[13].xyzw))
#define modelMatrix (mat4(source_params.data[14].xyzw,source_params.data[15].xyzw,source_params.data[16].xyzw,source_params.data[17].xyzw))
#define cameraPosition (source_params.data[18].xyz)
layout(location=0) out vec2 sourcePointCoord;
layout(location=1) out float vAlpha;
layout(location=2) out vec3 vWorld;
layout(set=0,binding=0) uniform FrameInfo {mat4 camera_transform;vec3 camera_position;float depth_bias;vec4 depth_offset;vec4 depth_slope;} frame_info;
layout(location=0) in vec3 position;
layout(location=1) in vec3 normal;
layout(location=2) in vec2 texture_coords;
layout(location=3) in vec2 texture_coords_1;
layout(location=4) in vec4 color;
layout(location=5) in vec4 tangent;
layout(location=6) in vec2 aPointCorner;
layout(location=7) in vec4 aSeed;
layout(location=8) in vec4 model_transform_0;
layout(location=9) in vec4 model_transform_1;
layout(location=10) in vec4 model_transform_2;
layout(location=11) in vec4 model_transform_3;
layout(location=12) in vec4 instance_color;

mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;

  








void pointMain() {


  vec3 box = vec3(52.0, 12.0, 16.0);
  vec3 p = aSeed.xyz * box;
  p.x += uTime * (0.05 + aSeed.w * 0.05);

  float rel = mod(p.x - uCam.x + box.x * 0.5, box.x);
  p.x = uCam.x + rel - box.x * 0.5;
  float edge = smoothstep(0.0, 4.0, rel) * (1.0 - smoothstep(box.x - 4.0, box.x, rel));
  p.y = uCam.y - 5.0 + p.y + sin(uTime * 0.12 + aSeed.w * 20.0) * 0.12;
  p.z = -8.0 + aSeed.z * 14.0;
  float size = 0.024 + aSeed.w * 0.022;
  vAlpha = uMotes * edge;
  vWorld = p;
  vec4 mv = viewMatrix * vec4(p, 1.0);
  gl_Position = projectionMatrix * mv;
  sourcePointSize = vAlpha < 0.002 ? 0.0 : size * uPx / -mv.z;
}
void sourceMain(){pointMain();sourcePointCoord=aPointCorner+0.5;gl_Position.xy+=aPointCorner*sourcePointSize*2.0/sourceViewport*gl_Position.w;}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+aPointCorner.x+aSeed.x+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+frame_info.camera_transform[0][0]);}
