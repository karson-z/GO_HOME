import 'package:three_js/three_js.dart' as three;

import 'original_firefly_light.dart';

/// Explicit GPU equivalent of the source SpriteMaterial map/alphaMap path.
/// Its vertex shader billboards exactly as Three.js Sprite (sizeAttenuation).
class NativeFireflyLight {
  NativeFireflyLight({this.amber = true}) {
    texture = three.DataTexture(originalFireflyTexture(), 64, 64)
      ..minFilter = three.LinearFilter
      ..magFilter = three.LinearFilter
      ..generateMipmaps = false
      ..needsUpdate = true;
    glow = _layer('glow', 0xffe4a0, true, false, 40);
    core = _layer('core', 0xfff6d2, false, true, 41);
    if (amber) warm = _layer('amber', 0xffa32e, false, true, 40);
    root.visible = false;
  }
  final bool amber;
  final root = three.Group();
  late final three.DataTexture texture;
  late final three.Mesh glow, core;
  three.Mesh? warm;
  final _materials = <three.ShaderMaterial>[];
  final _geometry = three.PlaneGeometry(1, 1);

  three.Mesh _layer(
    String name,
    int color,
    bool additive,
    bool alphaMap,
    int order,
  ) {
    final material = three.ShaderMaterial.fromMap({
      'name': 'source-firefly-$name',
      'uniforms': {
        'uMap': {'value': texture},
        'uColor': {'value': three.Color.fromHex32(color).toLinear()},
        'uOpacity': {'value': 1.0},
        'uAlphaMap': {'value': alphaMap ? 1.0 : 0.0},
      },
      'vertexShader': vertexShader,
      'fragmentShader': fragmentShader,
      'transparent': true,
      'depthTest': false,
      'depthWrite': false,
      'fog': false,
      'blending': additive ? three.AdditiveBlending : three.NormalBlending,
    });
    _materials.add(material);
    final mesh = three.Mesh(_geometry, material)
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

  void _alpha(three.Mesh layer, double value) =>
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
