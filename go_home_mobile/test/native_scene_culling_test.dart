import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/native_scene_culling.dart';
import 'package:go_home_mobile/game/native_world_assets.dart';
import 'package:three_js/three_js.dart' as three;

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/original_scene_culling.json').readAsStringSync(),
  );
  test('lake depth and haze match the original W6 update closure', () {
    final data = jsonDecode(File('assets/world/W6.json').readAsStringSync());
    final samples = jsonDecode(
      File('test/fixtures/original_lake_scenery.json').readAsStringSync(),
    ) as List;
    final chunk = NativeWorldChunk('W6', Map<String, dynamic>.from(data));
    final names = (samples.first['values'] as Map).keys.toSet();
    void collect(Map source) {
      if (names.contains(source['name'])) {
        final material = data['materials'][source['material']];
        final uniforms = <String, dynamic>{};
        for (final key in ['uFarCut', 'uAmt']) {
          if (material['uniforms']?[key] != null) {
            uniforms[key] = {'value': material['uniforms'][key]};
          }
        }
        final mesh = three.Mesh(
          three.BufferGeometry(),
          three.ShaderMaterial.fromMap({'uniforms': uniforms}),
        )..name = source['name'];
        mesh.position.y = (source['matrix'][13] as num).toDouble();
        mesh.visible = source['visible'];
        chunk.nodes.add(mesh);
      }
      for (final child in source['children']) {
        collect(child);
      }
    }

    for (final root in data['nodes']) {
      collect(root);
    }
    for (final sample in [...samples, ...samples.reversed]) {
      chunk.updateLake((sample['x'] as num).toDouble());
      for (final node in chunk.nodes.cast<three.Mesh>()) {
        final expected = sample['values'][node.name];
        expect(node.position.y, closeTo(expected['y'], 1e-12));
        expect(node.visible, expected['visible']);
        for (final key in ['uFarCut', 'uAmt']) {
          if (expected[key] != null) {
            expect(
              node.material!.uniforms[key]['value'],
              closeTo(expected[key], 1e-12),
              reason: '${node.name} $sample',
            );
          }
        }
      }
    }
  });
  test(
    'native batch visibility matches original Three.js across all scenes',
    () {
      var prevented = 0;
      for (final sample in fixture['cases']) {
        final mesh = three.InstancedMesh(
          three.BufferGeometry(),
          three.MeshBasicMaterial(),
          1,
        );
        mesh.matrixWorld.fromNativeArray(
          (sample['matrix'] as List).map((v) => (v as num).toDouble()).toList(),
        );
        final sphere = sample['sphere'];
        final center = (sphere['center'] as List).cast<num>();
        final culling = NativeSceneCulling()
          ..add(
            mesh,
            three.BoundingSphere(
              three.Vector3(
                center[0].toDouble(),
                center[1].toDouble(),
                center[2].toDouble(),
              ),
              (sphere['radius'] as num).toDouble(),
            ),
          );
        final frustum = three.Frustum()
          ..setFromMatrix(
            three.Matrix4.identity()..fromNativeArray(
              (sample['projectionView'] as List)
                  .map((v) => (v as num).toDouble())
                  .toList(),
            ),
          );
        culling.update(frustum);
        expect(
          mesh.layers.isEnabled(0),
          sample['visible'],
          reason: '${sample['scene']} ${sample['name']}',
        );
        expect(mesh.frustumCulled, isFalse);
        if (sample['visible'] && !sample['baseVisible']) prevented++;
      }
      expect(
        prevented,
        greaterThan(0),
        reason: 'Exercise the disappearing-instance regression',
      );
    },
  );

  test('all authored scenes retain bounds and source fog seams', () {
    Map read(String id) =>
        jsonDecode(File('assets/world/$id.json').readAsStringSync());
    final manifest = jsonDecode(
      File('assets/world/manifest.json').readAsStringSync(),
    ) as List;
    final defs = fixture['defs'] as List;
    expect(manifest.length, 14);
    for (var index = 0; index < manifest.length; index++) {
      final meta = manifest[index], data = read(meta['id']);
      expect(data['version'], 3);
      final left = index == 0
          ? 0
          : (defs[index - 1]['blend'] as num).clamp(0, defs[index]['blendIn']);
      final right = index == manifest.length - 1
          ? 0
          : (defs[index]['blend'] as num).clamp(0, defs[index + 1]['blendIn']);
      for (final material in (data['materials'] as Map).values) {
        if (material['name'] != 'mist') continue;
        expect(material['uniforms']['uZone']['vector'], [
          index == 0 ? -1e6 : meta['x0'] - left,
          index == 0 ? -1e6 + 1 : meta['x0'] + left,
          index == manifest.length - 1 ? 1e6 : meta['x1'] - right,
          index == manifest.length - 1 ? 1e6 + 1 : meta['x1'] + right,
        ], reason: meta['id']);
      }
      void inspect(Map node) {
        if (node['instances'] != null && node['count'] > 0 && node['culled']) {
          expect(
            node['boundingSphere'],
            isNotNull,
            reason: '${meta['id']} ${node['name']}',
          );
        }
        expect(node['layers'], isA<int>());
        for (final child in node['children']) {
          inspect(child);
        }
      }

      for (final node in data['nodes']) {
        inspect(node);
      }
    }
    final common = read('_global');
    final names = (common['nodes'] as List).map((n) => n['name']).toSet();
    expect(
      names,
      containsAll([
        'DUSK_FAR',
        'DUSK_MID_FF',
        'DUSK_MID_W1',
        'DUSK_MID_W3',
        'DUSK_MID_SQ',
        'NIGHT_FAR',
        'PARTICLES',
      ]),
    );
    expect(
      (read('W0')['nodes'] as List).any((n) => n['name'] == 'DUSK_MID_W3'),
      isFalse,
    );
  });
}
