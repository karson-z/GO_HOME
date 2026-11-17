import 'dart:typed_data';

import 'package:three_js/three_js.dart' as three;

import 'native_puppet_renderer.dart';

/// Original Fm/flatten squirrel satchel, attached to the solved body anchor.
class NativeSquirrelBag {
  final mount = three.Group()..name = 'squirrel-body-mount';
  late three.Object3D bag, body, flap;
  final List<three.BufferGeometry> geometries = [];
  final List<three.ShaderMaterial> materials = [];
  static NativeSquirrelBag build(
    NativePuppetRenderer rig,
    Map<String, dynamic> data,
  ) {
    final p = NativeSquirrelBag();
    for (final g in data['geometries']) {
      final geometry = three.BufferGeometry();
      for (final entry in (g['attributes'] as Map).entries) {
        geometry.setAttributeFromString(
          entry.key,
          three.Float32BufferAttribute(
            Float32List.fromList(
              (entry.value['values'] as List)
                  .map((n) => (n as num).toDouble())
                  .toList(),
            ),
            entry.value['size'],
          ),
        );
      }
      if (g['index'] != null) {
        geometry.setIndex(
          three.Uint32BufferAttribute(
            Uint32List.fromList((g['index'] as List).cast<int>()),
            1,
          ),
        );
      }
      p.geometries.add(geometry);
    }
    for (final m in data['materials']) {
      p.materials.add(
        three.ShaderMaterial.fromMap({
          'vertexShader': m['vertex'],
          'fragmentShader': m['fragment'],
          'uniforms': (m['uniforms'] as Map).map<String, dynamic>(
            (k, v) => MapEntry(k as String, {
              'value': v is Map && v['color'] != null
                  ? (three.Color()..setRGB(
                      (v['color'][0] as num).toDouble(),
                      (v['color'][1] as num).toDouble(),
                      (v['color'][2] as num).toDouble(),
                    ))
                  : v,
            }),
          ),
          'depthTest': m['depthTest'],
          'depthWrite': m['depthWrite'],
          'side': m['side'],
          'transparent': m['transparent'],
        }),
      );
    }
    three.Object3D build(Map n) {
      final three.Object3D o = n['geometry'] == null
          ? three.Group()
          : three.Mesh(p.geometries[n['geometry']], p.materials[n['material']]);
      o.name = n['name'];
      o.visible = n['visible'];
      o.renderOrder = n['order'];
      o.matrixAutoUpdate = false;
      o.matrix.fromNativeArray(
        (n['matrix'] as List).map((n) => (n as num).toDouble()).toList(),
      );
      for (final child in n['children']) {
        o.add(build(child));
      }
      return o;
    }

    p.mount.matrixAutoUpdate = false;
    final root = build(data['root']);
    p.mount.add(root);
    p.bag = root.children[0];
    p.body = p.bag.children[0];
    p.flap = p.bag.children[1];
    for (final node in [p.bag, p.body, p.flap]) {
      node.matrix.decompose(node.position, node.quaternion, node.scale);
      node.matrixAutoUpdate = true;
    }
    rig.flip.add(p.mount);
    return p;
  }

  void update(
    NativePuppetRenderer rig, {
    double propAlpha = 1,
    List<double>? pose,
  }) {
    if (pose != null) {
      var i = 0;
      for (final node in [bag, body, flap]) {
        node.position.x = pose[i++];
        node.position.y = pose[i++];
        node.scale.x = pose[i++];
        node.scale.y = pose[i++];
        node.updateMatrix();
      }
    }
    rig.stage.updateMatrixWorld(true);
    final anchor = rig.data['anchors']['body'];
    final joint = rig.parts[anchor['parent']]!.joint;
    mount.matrix.setFrom(joint.matrixWorld);
    mount.matrix.multiply(
      three.Matrix4.identity()..makeTranslation(
        (anchor['at'][0] as num).toDouble(),
        (anchor['at'][1] as num).toDouble(),
        0,
      ),
    );
    mount.matrixWorldNeedsUpdate = true;
    mount.visible = joint.visible;
    for (final m in materials) {
      m.uniforms['uOpacity']['value'] =
          rig.material.uniforms['uOpacity']['value'];
      m.uniforms['uClipY']['value'] = rig.material.uniforms['uClipY']['value'];
      m.uniforms['uPropA']['value'] = propAlpha.clamp(0.0, 1.0);
    }
  }

  void dispose() {
    mount.removeFromParent();
    for (final g in geometries) {
      g.dispose();
    }
    for (final m in materials) {
      m.dispose();
    }
  }
}
