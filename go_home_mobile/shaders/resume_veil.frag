#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
out vec4 fragColor;

// Original ZN: two CSS gradients, with color-mix explicitly in sRGB.
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 fog = vec3(89.0, 93.0, 107.0) / 255.0;
  vec3 top = mix(vec3(223.0, 228.0, 238.0) / 255.0, fog, .84);
  vec3 bottom = mix(vec3(28.0, 30.0, 40.0) / 255.0, fog, .82);
  vec3 bed = uv.y < .48
      ? mix(top, fog, clamp(uv.y / .48, 0.0, 1.0))
      : mix(fog, bottom, clamp((uv.y - .48) / .52, 0.0, 1.0));
  float radial = 1.0 - clamp(length((uv - vec2(.5, .62)) / vec2(.7, .55)) / .7, 0.0, 1.0);
  vec3 light = mix(vec3(255.0, 246.0, 232.0) / 255.0, fog, .88);
  fragColor = vec4(mix(bed, light, radial), 1.0);
}
