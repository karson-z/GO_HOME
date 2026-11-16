#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform float uProgress;
uniform float uClearing;
uniform sampler2D uField;
out vec4 fragColor;
float fieldAt(vec2 p) {
  vec2 size=vec2(736.0,228.0);
  vec3 low=floor(texture(uField,(vec2(p.x*2.0,p.y)+.5)/size).rgb*255.0+.5);
  float high=floor(texture(uField,(vec2(p.x*2.0+1.0,p.y)+.5)/size).r*255.0+.5);
  float exponent=mod(high,128.0)*2.0+floor(low.b/128.0);
  float mantissa=mod(low.b,128.0)*65536.0+low.g*256.0+low.r;
  return (1.0+mantissa/8388608.0)*exp2(exponent-127.0);
}
vec4 sourcePixel(vec2 p) {
  vec2 pixel=clamp(p,vec2(0),vec2(319,179));
  vec2 q=pixel/vec2(319.0,179.0);
  vec3 top=vec3(110,115,128), middle=vec3(89,93,107), bottom=vec3(78,82,95);
  vec3 color=q.y<.48?mix(top,middle,q.y/.48):mix(middle,bottom,(q.y-.48)/.52);
  float opacity=1.0;
  if(uClearing>.5) {
    vec2 offset=floor(vec2(36.0*uProgress,20.0*(1.0-uProgress))+.5);
    float noise=fieldAt(pixel+offset);
    vec2 radial=(q-vec2(.25,.62))/vec2(.55,.45);
    float edge=(length(radial)+(noise-.5)*1.2-(-.3+2.8*uProgress))/.14;
    opacity=smoothstep(0.0,1.0,edge);
  }
  // ImageData stores quantized straight RGBA before browser interpolation.
  opacity=floor(opacity*255.0+.5)/255.0;
  color=floor(color+.5)/255.0;
  return vec4(color*opacity,opacity);
}
void main() {
  vec2 uv=FlutterFragCoord().xy/uSize;
  // Match the browser's bilinear stretching of the original 320x180 canvas.
  vec2 p=uv*vec2(320.0,180.0)-.5, base=floor(p), f=fract(p);
  fragColor=mix(mix(sourcePixel(base),sourcePixel(base+vec2(1,0)),f.x),
                mix(sourcePixel(base+vec2(0,1)),sourcePixel(base+vec2(1,1)),f.x),f.y);
}
