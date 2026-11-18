import 'scene_data.dart' as sd;

import 'original_firefly_light.dart';

/// Explicit GPU equivalent of the source SpriteMaterial map/alphaMap path.
/// Its vertex shader billboards exactly as Three.js Sprite (sizeAttenuation).
class NativeFireflyLight {
  NativeFireflyLight({this.amber = true}) {
    texture = sd.PixelTexture(originalFireflyTexture(), 64, 64)
      ..minFilter = sd.LinearFilter
      ..magFilter = sd.LinearFilter
      ..generateMipmaps = false
      ..needsUpdate = true;
    glow = _layer('glow', 0xffe4a0, true, false, 40);
    core = _layer('core', 0xfff6d2, false, true, 41);
    if (amber) warm = _layer('amber', 0xffa32e, false, true, 40);
    root.visible = false;
  }
  final bool amber;
  final root = sd.GroupNode();
  late final sd.PixelTexture texture;
  late final sd.DrawMesh glow, core;
  sd.DrawMesh? warm;
  final _materials = <sd.ShaderData>[];
  final _geometry = sd.PlaneData(1, 1);

  sd.DrawMesh _layer(
    String name,
    int color,
    bool additive,
    bool alphaMap,
    int order,
  ) {
    final material = sd.ShaderData.fromMap({
      'name': 'source-firefly-$name',
      'uniforms': {
        'uMap': {'value': texture},
        'uColor': {'value': sd.Color.fromHex32(color).toLinear()},
        'uOpacity': {'value': 1.0},
        'uAlphaMap': {'value': alphaMap ? 1.0 : 0.0},
      },
      'vertexShader': vertexShader,
      'fragmentShader': fragmentShader,
      'transparent': true,
      'depthTest': false,
      'depthWrite': false,
      'fog': false,
      'blending': additive ? sd.AdditiveBlending : sd.NormalBlending,
    });
    _materials.add(material);
    final mesh = sd.DrawMesh(_geometry, material)
      ..name = 'start-firefly-$name'
      ..renderOrder = order
      ..frustumCulled = false;
    root.add(mesh);
    return mesh;
  }

  static const vertexShader = '''
varying vec2 vUv;
void main() {
  vUv = uv;
  vec4 mv = modelViewMatrix * vec4(0.0, 0.0, 0.0, 1.0);
  vec2 scale = vec2(length(modelMatrix[0].xyz), length(modelMatrix[1].xyz));
  mv.xy += position.xy * scale;
  gl_Position = projectionMatrix * mv;
}
''';
  static const fragmentShader = '''
uniform sampler2D uMap;
uniform vec3 uColor;
uniform float uOpacity;
uniform float uAlphaMap;
varying vec2 vUv;
void main() {
  vec4 texel = texture2D(uMap, vUv);
  gl_FragColor = vec4(uColor * texel.rgb,
      uOpacity * texel.a * mix(1.0, texel.g, uAlphaMap));
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}
''';

  void _alpha(sd.DrawMesh layer, double value) =>
      layer.material!.uniforms['uOpacity']['value'] = value;
  void setSize(FireflyLightSize size) {
    glow.scale.setScalar(size.glow);
    core.scale.setScalar(size.core);
    _alpha(glow, 1);
    _alpha(core, size.coreAlpha);
    if (warm != null) {
      warm!.visible = size.amberVisible;
      warm!.scale.setScalar(size.amber);
      _alpha(warm!, size.amberAlpha);
    }
  }

  void setLead(double alpha) {
    root.visible = alpha > .01;
    glow.scale.setScalar(.62);
    core.scale.setScalar(.17);
    _alpha(glow, .75 * alpha);
    _alpha(core, .95 * alpha);
  }

  void dispose() {
    root.removeFromParent();
    _geometry.dispose();
    for (final material in _materials) {
      material.dispose();
    }
    texture.dispose();
  }
}
