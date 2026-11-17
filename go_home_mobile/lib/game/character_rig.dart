import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_asset_decode.dart';

/// Ports the original atlas, pivots, hierarchy, rest pose and layer order.
class CharacterRig {
  CharacterRig._(this.name, this.texture);
  final String name;
  final three.Texture texture;
  final three.Group root = three.Group();
  final Map<String, three.Group> joints = {};
  final Map<String, double> rest = {};
  final List<three.Mesh> meshes = [];
  final List<three.BufferGeometry> geometries = [];
  final List<three.Material> materials = [];
  static Future<CharacterRig> load(String name) async {
    final data = await decodeNativeJsonAsset('assets/characters/$name.json');
    // Native GLES has no WebGL UNPACK_FLIP_Y. Flip decoded image pixels so the
    // source atlas UVs retain the browser's bottom-left coordinate convention.
    final texture = await loadNativeTexture(
      'assets/characters/$name.png',
      flipY: true,
    );
    texture.colorSpace = three.NoColorSpace;
    final rig = CharacterRig._(name, texture);
    final parts = (data['parts'] as List).cast<Map<String, dynamic>>();
    final frames = <String, Map<String, dynamic>>{};
    for (final p in parts) {
      final id = p['id'] as String;
      rig.joints[id] = three.Group();
      rig.rest[id] = (p['rest'] as num? ?? 0).toDouble();
      if (p['frames'] != null) {
        final options = (p['frames'] as Map)
            .cast<String, Map<String, dynamic>>();
        final preferred = switch (name) {
          'woodpecker' => id == 'body' || id == 'head' ? 'perch' : 'base',
          'bat' => id == 'body' ? 'open' : 'up',
          _ => 'side',
        };
        frames[id] =
            options[preferred] ?? options['fold'] ?? options.values.first;
      } else {
        frames[id] = p;
      }
    }
    const boyParents = {
      'hem': 'body',
      'hem2': 'hem',
      'head': 'body',
      'upperArmF': 'body',
      'upperArmB': 'body',
      'foreArmF': 'upperArmF',
      'foreArmB': 'upperArmB',
      'handF': 'foreArmF',
      'handB': 'foreArmB',
      'thighF': 'body',
      'thighB': 'body',
      'shinF': 'thighF',
      'shinB': 'thighB',
      'footF': 'shinF',
      'footB': 'shinB',
      'musicbox': 'handF',
    };
    final hidden = <String>{};
    for (final f in frames.values) {
      hidden.addAll((f['hide'] as List? ?? []).cast<String>());
    }
    for (final p in parts) {
      final id = p['id'] as String;
      final frame = frames[id]!;
      final joint = rig.joints[id]!;
      final parent = (name == 'boy' || name.startsWith('fam2-'))
          ? boyParents[id]
          : p['parent'] as String?;
      List at = (frame['at'] ?? p['at'] ?? [0, 0]) as List;
      if (parent != null) {
        final overrides = frames[parent]?['childAt'] as Map?;
        if (overrides?[id] != null) at = overrides![id] as List;
      }
      joint.position.setValues(
        (at[0] as num).toDouble(),
        (at[1] as num).toDouble(),
        0,
      );
      joint.rotation.z = rig.rest[id]!;
      (parent != null ? rig.joints[parent]! : rig.root).add(joint);
      final uv = (frame['uv'] ?? p['uv']) as List?;
      final size = (frame['size'] ?? p['size']) as List?;
      if (uv == null || size == null) continue;
      final pivot = (frame['pivot'] ?? p['pivot'] ?? [.5, .5]) as List;
      final w = (size[0] as num).toDouble(), h = (size[1] as num).toDouble();
      final geometry = three.PlaneGeometry(w, h);
      final uvs = geometry.getAttribute(three.Attribute.uv);
      for (var i = 0; i < uvs.count; i++) {
        final u = uvs.getX(i)!, v = uvs.getY(i)!;
        uvs.setXY(i, uv[0] + u * (uv[2] - uv[0]), uv[1] + v * (uv[3] - uv[1]));
      }
      final material = three.ShaderMaterial.fromMap({
        'uniforms': {
          'uMap': {'value': texture},
          'uBody': {'value': three.Color.fromHex32(0xb2aa91).toLinear()},
          'uAccent': {
            'value': three.Color.fromHex32(name == 'boy' ? 0xe8c780 : 0xb6a587)
                .toLinear(),
          },
          'uWarm': {'value': name == 'boy' || name == 'bear' ? .65 : .25},
        },
        'vertexShader': _vertexShader,
        'fragmentShader': _fragmentShader,
        'transparent': true,
        'depthWrite': false,
        'side': three.DoubleSide,
      });
      final mesh = three.Mesh(geometry, material);
      mesh.position.setValues(
        (.5 - pivot[0]) * w,
        (.5 - pivot[1]) * h,
        ((p['layer'] as num? ?? _boyLayer(id)) * .0006),
      );
      mesh.renderOrder = (p['layer'] as num? ?? _boyLayer(id)).toInt();
      mesh.visible = !hidden.contains(id);
      joint.add(mesh);
      rig.meshes.add(mesh);
      rig.geometries.add(geometry);
      rig.materials.add(material);
    }
    return rig;
  }

  // Source atlases encode value in R and accent mask in G. They are not RGB
  // artwork. Decode the source channels in a native GPU shader, preserving alpha.
  static const _vertexShader = r''' 
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  ''';
  static const _fragmentShader = r'''
    uniform sampler2D uMap;
    uniform vec3 uBody;
    uniform vec3 uAccent;
    uniform float uWarm;
    varying vec2 vUv;
    void main() {
      vec4 t = texture2D(uMap, vUv);
      if (t.a < 0.015) discard;
      float v = clamp(t.r / max(t.a, 0.001), 0.0, 1.0);
      float m = clamp(t.g / max(t.a, 0.001), 0.0, 1.0);
      vec3 warm = mix(vec3(0.070,0.042,0.042), vec3(0.175,0.125,0.070), smoothstep(0.15,0.45,v));
      warm = mix(warm, vec3(0.283,0.188,0.080), smoothstep(0.45,0.62,v));
      warm = mix(warm, vec3(0.62,0.42,0.20), smoothstep(0.62,0.8,v));
      vec3 body = mix(uBody * (0.40 + 0.95*v), warm, uWarm);
      vec3 box = uAccent * (0.55 + 0.7*v);
      vec3 col = mix(body, box, m);
      gl_FragColor = vec4(pow(max(col, vec3(0.0)), vec3(1.0/2.2)), t.a);
    }
  ''';
  void setPeriod(String period) {
    final c = three.Color.fromHex32(
      period == 'night'
          ? 0xa4b5c8
          : period == 'dawn'
          ? 0xc6bb9b
          : 0xb2aa91,
    ).toLinear();
    for (final mat in materials) {
      (mat as three.ShaderMaterial).uniforms['uBody']['value'] = c;
    }
  }

  static int _boyLayer(String id) => switch (id) {
    'upperArmB' || 'foreArmB' || 'handB' => 10,
    'thighB' || 'shinB' || 'footB' => 15,
    'thighF' || 'shinF' || 'footF' => 25,
    'body' => 40,
    'hem' => 45,
    'head' => 50,
    _ => 60,
  };
  void pose(
    double time, {
    double speed = 0,
    bool airborne = false,
    bool singing = false,
  }) {
    for (final entry in joints.entries) {
      entry.value.rotation.z = rest[entry.key] ?? 0;
    }
    if (name == 'boy') {
      final stride = math.sin(time * 10) * math.min(1, speed / 3.8);
      joints['thighF']?.rotation.z = stride * .65;
      joints['thighB']?.rotation.z = -stride * .65;
      joints['shinF']?.rotation.z = math.max(0, -stride) * .7;
      joints['shinB']?.rotation.z = math.max(0, stride) * .7;
      joints['upperArmF']?.rotation.z = .22 - stride * .26;
      joints['upperArmB']?.rotation.z = .3 + stride * .26;
      if (airborne) {
        joints['thighF']?.rotation.z = -.45;
        joints['thighB']?.rotation.z = .45;
        joints['shinB']?.rotation.z = .7;
        joints['upperArmF']?.rotation.z = -.7;
      }
      if (singing) {
        joints['foreArmF']?.rotation.z = 1.5;
        joints['head']?.rotation.z = math.sin(time * 4) * .04;
      }
      joints['body']?.position.y =
          .4204 +
          math.sin(time * (speed > .2 ? 20 : 2)) * (speed > .2 ? 0.018 : .006);
    } else {
      joints['head']?.rotation.z =
          (rest['head'] ?? 0) + math.sin(time * 2.3) * (singing ? 0.1 : .025);
      for (final id in ['wingF', 'wingN']) {
        if (name == 'bat' || name == 'firefly') {
          joints[id]?.rotation.z =
              math.sin(time * 12) * (name == 'bat' ? 0.5 : .3);
        }
      }
      if (name == 'squirrel') {
        joints['tail']?.rotation.z = math.sin(time * 2) * .08;
      }
    }
  }

  void dispose() {
    root.removeFromParent();
    for (final m in materials) {
      m.dispose();
    }
    for (final g in geometries) {
      g.dispose();
    }
    texture.dispose();
  }
}
