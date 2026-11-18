#version 450
layout(set=0,binding=2) uniform SourceVertexParams {vec4 data[25];} source_params;
uniform sampler2D uEgTile;
uniform sampler2D uEgShadow;
#define uTime (source_params.data[1].x)
#define uEgOldK (source_params.data[2].xyz)
#define uEgU (source_params.data[3].x)
#define uEgOld (source_params.data[4].xyz)
#define uEgBox (source_params.data[5].xyzw)
#define uEgSlope (source_params.data[6].xy)
#define uEgP (source_params.data[7].xyzw)
#define uWind (source_params.data[8].xyz)
#define uWindK (source_params.data[9].x)
#define uWindW (source_params.data[10].x)
#define uDetail (source_params.data[11].x)
#define projectionMatrix (mat4(source_params.data[12].xyzw,source_params.data[13].xyzw,source_params.data[14].xyzw,source_params.data[15].xyzw))
#define viewMatrix (mat4(source_params.data[16].xyzw,source_params.data[17].xyzw,source_params.data[18].xyzw,source_params.data[19].xyzw))
#define modelMatrix (mat4(source_params.data[20].xyzw,source_params.data[21].xyzw,source_params.data[22].xyzw,source_params.data[23].xyzw))
#define cameraPosition (source_params.data[24].xyz)
layout(location=0) out float vH;
layout(location=1) out vec3 vRoot;
layout(location=2) out vec3 vTip;
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
layout(location=12) in vec3 instance_aStroke;
#define aStroke instance_aStroke
mat4 sourceModel;
#define instanceMatrix (inverse(modelMatrix)*sourceModel)
#define instanceColor instance_color.rgb
#define modelViewMatrix (viewMatrix*modelMatrix)
#define normalMatrix transpose(inverse(mat3(modelViewMatrix)))
#define uv texture_coords
float sourcePointSize;
#define USE_INSTANCING 





  




vec3 egMix(vec3 a, vec3 b, float k) {
  vec3 p = pow(max(a, vec3(0.0)), vec3(1.0 / 3.0)), q = pow(max(b, vec3(0.0)), vec3(1.0 / 3.0));
  vec3 m = mix(p, q, k);
  return k >= 1.0 ? b : m * m * m;
}






float egPatch = 0.5;
float egShadow(vec3 W, float warp) {
  vec2 p = W.xz + (W.y - uEgP.y) * uEgSlope + vec2(warp * 0.5, warp);
  vec2 uv = (p - uEgBox.xy) * uEgBox.zw;
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
  return texture(uEgShadow, uv).r;
}

float egLight(vec3 W, out float stroke) {
  vec4 t = texture(uEgTile, vec2(-W.x, W.z) / vec2(5.0, 7.0));
  vec4 p = texture(uEgTile, W.xz / vec2(31.0, 37.0) + 0.13);
  stroke = t.r * 0.72 + t.b * 0.28;
  float patchK = p.g;
  egPatch = patchK;

  float toCliff = smoothstep(uEgP.x - 15.0, uEgP.x - 1.5, W.x);
  float z0 = mix(3.2, 7.6, toCliff);
  float band = 1.0 - smoothstep(z0 - 1.0, z0 + 3.8, W.z + (patchK - 0.5) * 10.0);
  float side = mix(0.6, 1.05, smoothstep(uEgP.x - 16.0, uEgP.x - 4.0, W.x));

  side = max(side, mix(0.6, 1.02, smoothstep(uEgP.x - 95.0, uEgP.x - 20.0, W.x)) * (1.0 - smoothstep(uEgP.x - 18.0, uEgP.x - 11.5, W.x)));
  float L = band * side * (0.26 + 1.1 * patchK);

  L += (1.0 - smoothstep(-2.6, 1.2, W.z)) * 0.32;

  vec4 m2 = texture(uEgTile, W.xz / vec2(8.0, 10.0) + 0.21);
  L *= 0.7 + 0.6 * smoothstep(0.3, 0.7, m2.g);

  float near = (1.0 - smoothstep(z0 + 1.0, z0 + 8.0, W.z)) * (1.0 - smoothstep(4.0, 8.0, W.z));
  L += smoothstep(0.58, 0.68, texture(uEgTile, W.xz / vec2(13.0, 17.0) + 0.43).g + (t.r - 0.5) * 0.26) * 0.42 * near;
  float sh = egShadow(W, (stroke - 0.5) * 1.3 + (patchK - 0.5) * 3.0);

  vec4 q = texture(uEgTile, W.xz / vec2(11.0, 15.0) + 0.57);
  float fleck = smoothstep(0.56, 0.66, q.g + (stroke - 0.5) * 0.22);
  sh *= 1.0 - fleck * 0.85;
  return L * (1.0 - sh * 0.95);
}
vec3 egRamp(float k, float stroke, float z) {
  float far = smoothstep(1.0, 10.5, z + (egPatch - 0.5) * 7.0);
  vec3 dark = mix(vec3(0.0612, 0.0723, 0.1620), vec3(0.0423, 0.0467, 0.1170), far);
  dark *= 0.92 + 0.18 * stroke;
  vec3 c = mix(dark, vec3(0.1329, 0.1221, 0.1070), smoothstep(0.24, 0.33, k));
  c = mix(c, vec3(0.2961, 0.2270, 0.1441), smoothstep(0.31, 0.44, k));
  c = mix(c, vec3(0.5271, 0.3763, 0.1500), smoothstep(0.44, 0.8, k));
  c = mix(c, vec3(0.7758, 0.5776, 0.2542), smoothstep(0.85, 1.25, k));
  c = mix(c, vec3(0.9216, 0.7605, 0.3712), smoothstep(1.25, 1.55, k));
  c = mix(c, c * (0.88 + 0.24 * stroke), smoothstep(0.3, 0.5, k));

  c *= mix(vec3(1.0), vec3(1.15, 0.96, 0.76), 4.0 * uEgU * (1.0 - uEgU) * smoothstep(0.26, 0.5, k));
  return c;
}
vec3 egGround(vec3 W, vec3 old) {
  float stroke;
  float L = egLight(W, stroke);

  {

    float rk = (1.0 - smoothstep(0.9, 2.1, abs(W.z - 0.1))) * (1.0 - smoothstep(uEgP.x - 26.0, uEgP.x - 13.0, W.x)) * smoothstep(uEgP.z + 3.0, uEgP.z + 28.0, W.x);
    float sl = smoothstep(uEgP.x - 130.0, uEgP.x - 40.0, W.x);
    float pk = texture(uEgTile, W.xz / vec2(9.0, 3.0)).g;
    L = max(L, (0.42 + 0.5 * sl) * rk * (0.75 + 0.5 * pk));
  }

  { vec4 tf = texture(uEgTile, vec2(-W.x / 4.0, 46.0 / (22.0 - min(W.z, 20.0)))); stroke = tf.r * 0.72 + tf.b * 0.28; }
  L += (stroke - 0.5) * 0.7 * smoothstep(0.05, 0.3, L) * (1.0 - smoothstep(0.7, 1.1, L));
  vec3 c = egRamp(L, stroke, W.z);


  return egMix(old, mix(old, c, smoothstep(-6.0, -4.5, W.z) * smoothstep(uEgP.z + 0.5, uEgP.z + 14.0, W.x)), uEgU);
}






float windGust(float x, float t) {
  float p = x * uWindK + t * uWindW;
  float g = (0.5 + 0.5 * sin(p)) * (0.6 + 0.4 * sin(p * 0.37 + 1.7));
  return g * g;
}

float windSway(float x, float ph, float t, float hz) {
  float g = windGust(x, t);
  float w = 6.2832 * hz * t + ph;
  float o = sin(w) * 0.7 + sin(w * 1.83 + ph) * 0.3;
  return -uWind.x * (g * 0.6 + (0.5 + 0.5 * g) * o * 0.5);
}

float windAmp(float z, float pct) { return pct * 0.008866 * max(18.4 - z, 1.0); }

float windS(float x, float ph, float t, float seed) { return windSway(x, ph, t, 0.3) * 1.4; }
void sourceMain() {
  vH = aH;
  vec4 o = modelMatrix * instanceMatrix * vec4(0.0, 0.0, 0.0, 1.0);
  float st;

  float L = egLight(o.xyz, st);
  float edge = 1.0 - smoothstep(0.0, 0.22, abs(L - 0.36));
  float crest = 1.0 - smoothstep(-1.0, 0.2, o.z);
  float nearK = smoothstep(5.5, 8.5, o.z);
  float want = max(edge, max(crest, nearK));

  float slopeK = 1.0 - smoothstep(uEgP.x - 30.0, uEgP.x - 20.0, o.x);

  want = max(want, mix(0.6, 0.95, smoothstep(uEgP.x - 112.0, uEgP.x - 30.0, o.x)) * slopeK);

  want *= 1.0 - 0.85 * slopeK * (1.0 - smoothstep(0.7, 1.5, abs(o.z - 0.1)));
  float fadeIn = max(smoothstep(uEgP.x - 48.0, uEgP.x - 30.0, o.x), slopeK);
  
  vec3 pos = position;

  pos.x -= aStroke.y * aH * aH;
  vec4 w = modelMatrix * instanceMatrix * vec4(pos, 1.0);
  float s = windSway(o.x, o.x * 2.1 + o.z * 3.0, uTime, 0.42);
  w.x += s * aH * aH * windAmp(o.z, 0.5);
  vRoot = egRamp(L, st, o.z);
  float tipL = L + 0.06 + 0.22 * smoothstep(0.2, 0.6, L);
  vTip = egRamp(tipL, st, o.z) * (1.0 + 0.3 * (1.0 - smoothstep(0.2, 0.4, L)));
  float tone = 1.0 + aStroke.z;
  vRoot *= tone; vTip *= tone;

  vec3 oldG = uEgOld * uEgOldK;
  vRoot = egMix(oldG, vec3(0.0252, 0.0284, 0.0723), uEgU); vTip = egMix(oldG * 0.86, mix(vec3(0.0452, 0.0513, 0.1274), mix(vec3(0.4793, 0.3231, 0.0976), vec3(0.8714, 0.6654, 0.2623), st), (0.35 + 0.65 * smoothstep(-0.3, 0.7, sin(o.x * 0.61) + st - 0.5)) * smoothstep(0.1, 0.9, uEgU)), uEgU);
  gl_Position = projectionMatrix * viewMatrix * w;
}
void main(){sourceModel=mat4(model_transform_0,model_transform_1,model_transform_2,model_transform_3);sourceMain();gl_Position.z=(gl_Position.z+gl_Position.w)*0.5;gl_Position.x+=source_params.data[0].x*(position.x+normal.x+texture_coords.x+texture_coords_1.x+color.x+tangent.x+aH+model_transform_0.x+model_transform_1.x+model_transform_2.x+model_transform_3.x+instance_color.x+instance_aStroke.x+frame_info.camera_transform[0][0]+texture(uEgTile,vec2(0.5)).x+texture(uEgShadow,vec2(0.5)).x);}
