import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' as fs;

import 'native_asset_decode.dart';
import 'native_load_budget.dart';
import 'scene_compiler.dart';
import 'scene_data.dart' as sd;

/// Compile the whole route's shader/state variants during initial loading.
/// A tiny real draw uses the same vertex/instance layout and render state as
/// gameplay, without loading or retaining the other chapters' textures/meshes.
Future<void> warmRoutePipelines(SourceShaderLibrary registry) async {
  final manifest = await decodeNativeJsonAsset(
    'assets/data/scene_pipeline_warmup.json',
  );
  final camera = sd.PerspectiveLens(28, 1, .5, 100)..position.z = 5;
  camera.updateMatrixWorld(true);
  final root = sd.GroupNode();
  final compiler = SceneCompiler(registry, camera);
  final texture = sd.PixelTexture(
    Uint8List.fromList([255, 255, 255, 255]),
    1,
    1,
  );
  final budget = NativeLoadBudget();
  for (final entry in manifest['pipelines'] as List) {
    await budget.checkpoint();
    final id = entry['shader'] as String, spec = registry.metadata['pairs'][id];
    final uniforms = <String, dynamic>{};
    for (final stage in ['vertex', 'fragment']) {
      for (final uniform in spec[stage]['uniforms']) {
        final type = uniform['type'] as String, count = uniform['count'] as int;
        Object value() => switch (type) {
          'mat4' => sd.Matrix4.identity(),
          'mat3' => sd.Matrix3.identity(),
          'vec4' => sd.Vector4(1, 1, 1, 1),
          'vec3' => sd.Vector3(1, 1, 1),
          'vec2' => sd.Vector2(1, 1),
          'bool' => false,
          _ => 1.0,
        };
        uniforms[uniform['name']] = {
          'value': count == 1 ? value() : List.generate(count, (_) => value()),
        };
      }
      for (final name in spec[stage]['samplers']) {
        uniforms[name] = {'value': texture};
      }
    }
    final material = sd.ShaderData.fromMap({
      ...Map<String, dynamic>.from(entry['state']),
      'uniforms': uniforms,
    });
    final geometry = sd.PlaneData();
    for (final attr in [...spec['custom'], ...spec['instanceCustom']]) {
      final size = attr[0] == 'float'
          ? 1
          : int.parse((attr[0] as String).substring(3));
      final instanced = (spec['instanceCustom'] as List).contains(attr);
      geometry.setAttributeFromString(
        attr[1],
        instanced
            ? sd.InstanceAttribute(
                (Float32List(size)..fillRange(0, size, 1)),
                size,
              )
            : sd.FloatAttribute(
                (Float32List(4 * size)..fillRange(0, 4 * size, 1)),
                size,
              ),
      );
    }
    final sd.SceneNode node = (spec['instanceCustom'] as List).isEmpty
        ? sd.DrawMesh(geometry, material)
        : sd.InstanceMesh(geometry, material, 1);
    node.frustumCulled = false;
    compiler.sourceNames[material] = id;
    root.add(node);
  }
  root.updateMatrixWorld(true);
  final node = await compiler.prepare(root, budget);
  compiler.sync();
  final warm = fs.Scene()
    ..antiAliasingMode = fs.AntiAliasingMode.none
    ..toneMapping = fs.ToneMappingMode.linear
    ..fitNearPlane = false
    ..reversedDepth = false;
  warm.add(node);
  try {
    await warm.warmUp(
      [fs.RenderView(camera: SourceCamera(camera))],
      includeOffscreen: true,
      sliceBudget: const Duration(milliseconds: 2),
    );
  } finally {
    warm.remove(node);
    warm.dispose();
    registry.materials.removeWhere(
      (m) => compiler.mapped.containsKey(m.object),
    );
    registry.textures.remove(texture);
    registry.textureVersions.remove(texture);
  }
}
