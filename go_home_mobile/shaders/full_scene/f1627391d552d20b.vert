#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[45];} source_params;

#define uTime (source_params.data[1].x)
#define uSway (source_params.data[2].x)
#define uTreeSway (source_params.data[3].x)
#define uLeafPct (source_params.data[4].x)
#define uSunAnchor (source_params.data[5].xyz)
#define uCenter (source_params.data[6].xyz)
#define uWind (source_params.data[7].xyz)
#define uWindK (source_params.data[8].x)
#define uWindW (source_params.data[9].x)
#define uDetail (source_params.data[10].x)
#define uGlowN (int(source_params.data[11].x))
#define uDarkX (source_params.data[12].xyzw)
#define uDarkK (source_params.data[13].x)
#define uDarkMul (source_params.data[14].x)
#define uGlowPos (vec4[8](source_params.data[15].xyzw,source_params.data[16].xyzw,source_params.data[17].xyzw,source_params.data[18].xyzw,source_params.data[19].xyzw,source_params.data[20].xyzw,source_params.data[21].xyzw,source_params.data[22].xyzw))
#define uGlowCol (vec3[8](source_params.data[23].xyz,source_params.data[24].xyz,source_params.data[25].xyz,source_params.data[26].xyz,source_params.data[27].xyz,source_params.data[28].xyz,source_params.data[29].xyz,source_params.data[30].xyz))
#define uGlowSoft (source_params.data[31].x)
#define projectionMatrix (mat4(source_params.data[32].xyzw,source_params.data[33].xyzw,source_params.data[34].xyzw,source_params.data[35].xyzw))
#define viewMatrix (mat4(source_params.data[36].xyzw,source_params.data[37].xyzw,source_params.data[38].xyzw,source_params.data[39].xyzw))
#define modelMatrix (mat4(source_params.data[40].xyzw,source_params.data[41].xyzw,source_params.data[42].xyzw,source_params.data[43].xyzw))
#define cameraPosition (source_params.data[44].xyz)
layout(location=0) out vec3 vLit;
layout(location=1) out vec3 vO;
layout(location=2) out float vSide;
layout(location=3) out vec2 vSunUv;
layout(location=4) out vec4 vTint;
layout(location=5) out vec2 vUv;
layout(location=6) out vec3 vW;
layout(set=0,binding=0) uniform FrameInfo {mat4 camera_transform;vec3 camera_position;float depth_bias;vec4 depth_offset;vec4 depth_slope;} frame_info;
layout(location=0) in vec3 position;
layout(location=1) in vec3 normal;
layout(location=2) in vec2 texture_coords;
layout(location=3) in vec2 texture_coords_1;
layout(location=4) in vec4 color;
layout(location=5) in vec4 tangent;
layout(location=6) in vec4 aUv;
layout(location=7) in vec4 aTint;
layout(location=8) in vec4 aAnchor;
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
  vUv = mix(aUv.xy, aUv.zw, uv);
  vTint = aTint;
  vec4 w = instanceMatrix * vec4(position, 1.0);
  vec4 o = instanceMatrix * vec4(0.0, 0.0, 0.0, 1.0);
  w = modelMatrix * w;
  o = modelMatrix * o;

  float tb = max(w.y - aAnchor.y, 0.0);
  w.x += windSway(aAnchor.x, aAnchor.x * 1.7 + aAnchor.z * 0.9, uTime, 0.22) * uTreeSway * 0.06 * tb * tb / (1.0 + tb * 0.25);

  float az = aAnchor.z;
  float pct = uLeafPct >= 0.0 ? uLeafPct : (az > -11.0 ? mix(0.55, 0.8, smoothstep(-11.0, -3.0, az)) : az > -41.0 ? mix(0.3, 0.55, smoothstep(-41.0, -11.0, az)) : mix(0.0, 0.3, smoothstep(-80.0, -41.0, az)));
  float sb = step(0.001, uSway) * windSway(o.x, aAnchor.w * 6.283, uTime, 0.42) * windAmp(az, pct);
  w.x += sb * (0.6 + 0.4 * uv.y);
  w.y += sb * 0.3 * (0.6 + 0.4 * uv.y);

  w.x += step(0.001, uSway) * uDetail * sin(uTime * 7.5 + aTint.a * 40.0) * 0.014 * uv.y;
  w.y += step(0.001, uSway) * uDetail * sin(uTime * 5.9 + aTint.a * 30.0) * 0.01 * uv.y;
  
  {
    float tx = aAnchor.x, fy = aAnchor.y;
    float hN = max(w.y - fy, 0.0);
    float side = abs(w.x - tx);
    float crownK = smoothstep(2.50, 6.00, hN + side * 0.35);
    float ph1 = w.x * 0.33 + w.y * 0.41 + aAnchor.w * 6.283;
    float ph2 = w.x * 0.11 - w.y * 0.27 + 2.1;
    float g = windSway(w.x, ph1, uTime, 0.42);
    float big = windSway(tx, ph2, uTime, 0.22);
    w.x += crownK * (g * 0.55 + big * 0.75) * uLeafPct;
    w.y += crownK * (g * 0.28 - big * 0.1) * uLeafPct * 0.7;
  }

  vW = w.xyz;
  vO = o.xyz;
  vLit = ffLight(w.xyz, vec3(0.0, 1.0, 0.0), 1.0);
  vec2 d = normalize(uSunAnchor.xy - w.xy);

  vSide = mix(1.0, smoothstep(0.1, 0.85, dot(normalize(o.xy - uCenter.xy + vec2(1e-3)), d)), uCenter.z);
  vec3 ax = normalize(mat3(modelMatrix) * instanceMatrix[0].xyz);
  vec3 ay = normalize(mat3(modelMatrix) * instanceMatrix[1].xyz);
  vSunUv = vec2(dot(d, ax.xy), dot(d, ay.xy)) * sign(aUv.z - aUv.x);
  gl_Position = projectionMatrix * viewMatrix * w;
}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+aUv.x+aTint.x+aAnchor.x+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+frame_info.camera_transform[0][0]);}
