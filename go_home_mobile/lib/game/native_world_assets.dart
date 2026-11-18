import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'scene_data.dart' as sd;

import 'native_scene_culling.dart';
import 'native_asset_decode.dart';
import 'native_load_budget.dart';

/// Loads source-generated scene data. All rendering and updates run in Dart.
class NativeWorldAssets {
  final Map<String, Future<sd.TextureData>> _textures = {};
  late Map<String, dynamic> resources;
  late List<Map<String, dynamic>> manifest;
  final Map<String, dynamic> shared = {};
  Future<void> _loadTail = Future<void>.value();

  /// Called before a chunk is exposed to scene rendering.
  Future<void> Function(NativeWorldChunk chunk)? prepare;
  bool _disposed = false;
  String quality = 'high';
  final Map<sd.InstanceMesh, int> _qualityMeshes = {};
  void setQuality(String value) {
    if (value == quality) return;
    quality = value;
    for (final mesh in _qualityMeshes.keys) {
      _applyQuality(mesh);
    }
  }

  void _applyQuality(sd.InstanceMesh mesh) {
    final name = mesh.material?.name;
    if (name != 'grass' && name != 'leaf') return;
    if ((mesh.count ?? 0) == 0 && !_qualityMeshes.containsKey(mesh)) return;
    final full = _qualityMeshes.putIfAbsent(mesh, () => mesh.count ?? 0);
    final index = quality == 'low'
        ? 2
        : quality == 'mid'
        ? 1
        : 0;
    final density = name == 'grass' ? [1.0, .6, .35] : [1.0, .75, .5];
    mesh.count = (full * density[index]).round().clamp(1, full);
    if (name == 'leaf') {
      mesh.material!.alphaToCoverage = index < 2;
    }
  }

  Future<void> initialize() async {
    resources = await decodeNativeJsonAsset('assets/world/resources.json');
    manifest = (jsonDecode(
      await rootBundle.loadString('assets/world/manifest.json'),
    ) as List).cast<Map<String, dynamic>>();
  }

  Future<sd.TextureData> texture(String? id) =>
      _textures.putIfAbsent(id ?? '_empty', () async {
        if (id == null) {
          return sd.PixelTexture(Uint8List.fromList([0, 0, 0, 0]), 1, 1)
            ..needsUpdate = true;
        }
        final data = resources['textures'][id] as Map<String, dynamic>;
        final file = 'assets/world/${data['file']}';
        sd.TextureData t;
        if (data['raw'] == true) {
          final bytes = await rootBundle.load(file);
          final type = data['type'] as int;
          t = type == sd.FloatType
              ? sd.PixelTexture(
                  bytes.buffer.asFloat32List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes ~/ 4,
                  ),
                  data['width'],
                  data['height'],
                  data['format'],
                  type,
                )
              : type == sd.HalfFloatType
              ? sd.PixelTexture(
                  bytes.buffer.asUint16List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes ~/ 2,
                  ),
                  data['width'],
                  data['height'],
                  data['format'],
                  type,
                )
              : sd.PixelTexture(
                  bytes.buffer.asUint8List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes,
                  ),
                  data['width'],
                  data['height'],
                  data['format'],
                  type,
                );
        } else {
          t = await loadNativeTexture(file, flipY: data['flipY'] == true);
        }
        t.wrapS = data['wrapS'];
        t.wrapT = data['wrapT'];
        t.magFilter = data['magFilter'];
        t.minFilter = data['minFilter'];
        t.colorSpace = data['colorSpace'] ?? sd.NoColorSpace;
        t.premultiplyAlpha = data['premultiplyAlpha'] == true;
        t.generateMipmaps = true;
        t.needsUpdate = true;
        if (_disposed) t.dispose();
        return t;
      });

  Future<dynamic> _value(dynamic value) async {
    if (value is List) {
      final values = await Future.wait(value.map(_value));
      // Store color arrays as RGB vectors for contiguous GPU uniform packing.
      return values
          .map((v) => v is sd.Color ? sd.Vector3(v.red, v.green, v.blue) : v)
          .toList();
    }
    if (value is! Map) return value;
    if (value.containsKey('texture')) return texture(value['texture']);
    List<double> numbers(dynamic v) =>
        (v as List).map((n) => (n as num).toDouble()).toList();
    if (value.containsKey('color')) {
      final v = numbers(value['color']);
      return sd.Color()..setRGB(v[0], v[1], v[2]);
    }
    if (value.containsKey('vector')) {
      final v = numbers(value['vector']);
      return switch (v.length) {
        2 => sd.Vector2(v[0], v[1]),
        3 => sd.Vector3(v[0], v[1], v[2]),
        _ => sd.Vector4(v[0], v[1], v[2], v[3]),
      };
    }
    if (value.containsKey('matrix')) {
      final v = numbers(value['matrix']);
      if (v.length == 16) return sd.Matrix4.identity()..fromNativeArray(v);
      final m = sd.Matrix3.identity();
      for (var i = 0; i < 9; i++) {
        m[i] = v[i];
      }
      return m;
    }
    return null;
  }

  Future<dynamic> decodeValue(dynamic value) => _value(value);

  Future<NativeWorldChunk> load(String id) {
    final result = _loadTail.then((_) => _load(id));
    // One builder at a time: simultaneous preloads must not add their CPU
    // budgets together or allocate several complete scenes in the same frame.
    _loadTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<NativeWorldChunk> _load(String id) async {
    if (_disposed) throw StateError('World assets have been disposed');
    final decoded = await decodeNativeWorldAsset(id);
    final json = decoded.metadata;
    final bytes = decoded.bytes;
    final budget = NativeLoadBudget();
    final chunk = NativeWorldChunk(id, json);
    try {
      chunk.onDispose = () {
        for (final node in chunk.nodes) {
          if (node is sd.InstanceMesh) _qualityMeshes.remove(node);
        }
      };
      if (json['shared'] != null) {
        for (final entry in (json['shared'] as Map<String, dynamic>).entries) {
          shared[entry.key] = {
            'value': await budget.waiting(_value(entry.value)),
          };
        }
      }
      sd.VertexAttribute attribute(Map<String, dynamic> data) {
        final offset = bytes.offsetInBytes + (data['offset'] as int);
        final length = data['length'] as int, size = data['size'] as int;
        if (data['integer'] == true) {
          return sd.IndexAttribute(
            bytes.buffer.asUint32List(offset, length),
            size,
          );
        }
        // Views share the worker-owned, mutable binary buffer for the chunk's
        // lifetime; animated branches can deform it without per-attribute copies.
        final array = bytes.buffer.asFloat32List(offset, length);
        if (data['instanced'] == true) {
          return sd.InstanceAttribute(
            array,
            size,
            false,
            data['meshPerAttribute'] as int,
          );
        }
        return sd.FloatAttribute(array, size);
      }

      final geometries = <String, sd.GeometryData>{};
      sd.Vector3 point(List p) => sd.Vector3(
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
        (p[2] as num).toDouble(),
      );
      sd.SphereBounds sphere(Map data) => sd.SphereBounds(
        point(data['center']),
        (data['radius'] as num).toDouble(),
      );
      for (final entry
          in (json['geometries'] as Map<String, dynamic>).entries) {
        await budget.checkpoint();
        final data = entry.value;
        final g = data['instanced'] == true
            ? sd.InstanceGeometry()
            : sd.GeometryData();
        for (final a in (data['attributes'] as Map<String, dynamic>).entries) {
          g.setAttributeFromString(a.key, attribute(a.value));
        }
        if (data['index'] != null) g.setIndex(attribute(data['index']));
        if (data['instanceCount'] != null) {
          g.instanceCount = data['instanceCount'];
        }
        for (final group in data['groups']) {
          g.addGroup(group['start'], group['count'], group['materialIndex']);
        }
        final range = data['drawRange'];
        if (range['count'] != null) {
          g.setDrawRange(range['start'], range['count']);
        }
        if (data['boundingSphere'] != null) {
          g.boundingSphere = sphere(data['boundingSphere']);
        }
        geometries[entry.key] = g;
        chunk.geometries.add(g);
      }
      final materials = <String, sd.MaterialData>{};
      for (final entry in (json['materials'] as Map<String, dynamic>).entries) {
        await budget.checkpoint();
        final data = Map<String, dynamic>.from(entry.value);
        final options = Map<String, dynamic>.from(data)
          ..remove('vertex')
          ..remove('fragment')
          ..remove('uniforms')
          ..remove('sharedBindings')
          ..remove('type')
          ..remove('rotation')
          ..remove('color')
          ..remove('map')
          ..remove('alphaMap');
        sd.MaterialData material;
        if (data['vertex'] != null) {
          final uniforms = <String, dynamic>{};
          for (final u in (data['uniforms'] as Map<String, dynamic>).entries) {
            final binding = data['sharedBindings']?[u.key];
            uniforms[u.key] = binding != null
                ? shared[binding]
                : {'value': await budget.waiting(_value(u.value))};
          }
          options['vertexShader'] = resources['shaders'][data['vertex']];
          options['fragmentShader'] = resources['shaders'][data['fragment']];
          // Some original uniforms (e.g. cave uX/uY) were plain JS arrays.
          // Shader packing uses typed vectors for scalar GLSL values. Keep uniform
          // arrays as lists; their upload path has different requirements.
          final source =
              '${options['vertexShader']}\n${options['fragmentShader']}';
          for (final declaration in RegExp(
            r'\buniform\s+(?:lowp\s+|mediump\s+|highp\s+)?vec([234])\s+(\w+)\s*;',
          ).allMatches(source)) {
            final uniform = uniforms[declaration.group(2)];
            final value = uniform?['value'];
            if (value is! List) continue;
            uniform['value'] = await _value({'vector': value});
          }
          options['uniforms'] = uniforms;
          material = sd.ShaderData.fromMap(options);
        } else {
          if (data['color'] != null) {
            options['color'] = await _value(data['color']);
          }
          if (data['map'] != null) {
            options['map'] = await budget.waiting(texture(data['map']));
          }
          if (data['alphaMap'] != null) {
            options['alphaMap'] = await budget.waiting(
              texture(data['alphaMap']),
            );
          }
          material = data['type'] == 'SpriteMaterial'
              ? sd.BillboardData.fromMap(options)
              : sd.UnlitData.fromMap(options);
        }
        if (data['rotation'] != null) {
          material.rotation = (data['rotation'] as num).toDouble();
        }
        materials[entry.key] = material;
        chunk.materials.add(material);
      }
      Future<sd.SceneNode> node(Map<String, dynamic> data) async {
        await budget.checkpoint();
        final geometry = geometries[data['geometry']];
        final mat = data['material'];
        final material = mat is String
            ? materials[mat]
            : mat is List
            ? materials[mat.first]
            : null;
        sd.SceneNode o;
        if (data['instances'] != null) {
          // The constructor otherwise allocates a throwaway count*16 matrix.
          final mesh = sd.InstanceMesh(geometry!, material, 0)
            ..count = data['count'];
          mesh.instanceMatrix =
              attribute(data['instances']) as sd.InstanceAttribute;
          if (data['instanceColor'] != null) {
            mesh.instanceColor =
                attribute(data['instanceColor']) as sd.InstanceAttribute;
          }
          _applyQuality(mesh);
          o = mesh;
        } else if (data['type'] == 'Sprite') {
          o = sd.BillboardNode(material);
        } else if (geometry != null) {
          o = data['type'] == 'Points'
              ? sd.PointCloud(geometry, material)
              : data['type'] == 'LineSegments'
              ? sd.LineSegments(geometry, material)
              : sd.DrawMesh(geometry, material);
        } else {
          o = sd.GroupNode();
        }
        o.name = data['name'];
        o.visible = data['visible'];
        o.renderOrder = (data['order'] as num).toInt();
        o.frustumCulled = data['culled'];
        o.layers.mask = (data['layers'] as num?)?.toInt() ?? 1;
        if (o is sd.InstanceMesh && (o.count ?? 0) > 0) {
          o.boundingSphere = data['boundingSphere'] != null
              ? sphere(data['boundingSphere'])
              : null;
          if (o.frustumCulled && o.layers.isEnabled(0)) {
            if (o.boundingSphere == null) o.computeBoundingSphere();
            chunk.culling.add(o, o.boundingSphere!);
          }
        }
        o.matrix.fromNativeArray(
          (data['matrix'] as List)
              .cast<num>()
              .map((n) => n.toDouble())
              .toList(),
        );
        o.matrix.decompose(o.position, o.quaternion, o.scale);
        o.matrixAutoUpdate = false;
        o.userData = Map<String, dynamic>.from(data['userData']);
        if (data['order'] != o.renderOrder) {
          o.userData['sourceRenderOrder'] = data['order'];
        }
        chunk.nodes.add(o);
        final box = data['visibilityBox'];
        if (box != null) {
          final bounds = sd.BoxBounds(point(box['min']), point(box['max']));
          chunk.visibilityBoxes.add((node: o, box: bounds));
          if (o is sd.DrawMesh && o is! sd.InstanceMesh) {
            chunk.culling.addBounds(o, bounds);
          }
        }
        for (final child in data['children']) {
          o.add(await node(child));
        }
        return o;
      }

      for (final data in json['nodes']) {
        chunk.root.add(await node(data));
      }
      chunk.root.updateMatrixWorld(true);
      if (_disposed) throw StateError('World assets have been disposed');
      await prepare?.call(chunk);
      if (_disposed) throw StateError('World assets have been disposed');
      return chunk;
    } catch (_) {
      chunk.dispose();
      rethrow;
    }
  }

  double groundAt(NativeWorldChunk global, double x) {
    final heights = global.data['heights'] as List;
    final t =
        ((x - (global.data['heightX0'] as num)) /
                (global.data['heightStep'] as num))
            .clamp(0.0, heights.length - 1.000001);
    final i = t.floor();
    return (heights[i] as num).toDouble() +
        ((heights[i + 1] as num) - (heights[i] as num)) * (t - i);
  }

  void dispose() {
    _disposed = true;
    for (final value in _textures.values) {
      value.then((t) => t.dispose());
    }
    _textures.clear();
    _qualityMeshes.clear();
  }
}

class NativeWorldChunk {
  NativeWorldChunk(this.id, this.data);
  final String id;
  bool _disposed = false;
  void Function()? onDispose;
  final Map<String, dynamic> data;
  final sd.GroupNode root = sd.GroupNode()..matrixAutoUpdate = false;
  final List<sd.SceneNode> nodes = [];
  final List<sd.GeometryData> geometries = [];
  final List<sd.MaterialData> materials = [];
  final culling = NativeSceneCulling();
  final visibilityBoxes = <({sd.SceneNode node, sd.BoxBounds box})>[];

  bool intersectsView(sd.ViewFrustum frustum) => visibilityBoxes.any((entry) {
    for (
      sd.SceneNode? node = entry.node;
      node != null && node != root;
      node = node.parent
    ) {
      if (!node.visible) return false;
    }
    return frustum.intersectsBox(entry.box);
  });

  Map<String, dynamic> palette(double x) {
    final values = data['palette'] as List;
    final t = ((x - (data['paletteX0'] as num)) / (data['paletteStep'] as num))
        .clamp(0.0, values.length - 1.000001);
    final i = t.floor(), amount = t - t.floor();
    dynamic mix(dynamic a, dynamic b) {
      if (a is num && b is num) return a + (b - a) * amount;
      if (a is List && b is List) {
        return [for (var j = 0; j < a.length; j++) mix(a[j], b[j])];
      }
      return a;
    }

    return {
      for (final k in (values[i] as Map).keys)
        k as String: mix(values[i][k], values[i + 1][k]),
    };
  }

  void updateMist(double cameraX, double groundY, double cameraZ) {
    for (final o in nodes) {
      final spec = o.userData['spec'];
      if (spec == null || !o.name.startsWith('MIST_')) continue;
      final base =
          (spec['baseY'] as num?)?.toDouble() ??
          groundY + (spec['off'] as num? ?? 0);
      o.position.x = cameraX;
      o.position.y = base + 38;
      o.updateMatrix();
      if (o is sd.DrawMesh && o.material is sd.ShaderData) {
        o.material!.uniforms['uBase']['value'] = base;
        final zone = o.material!.uniforms['uZone']['value'] as sd.Vector4;
        final extent = .46 * (cameraZ - o.position.z);
        o.visible = cameraX + extent > zone.x && cameraX - extent < zone.w;
      }
    }
  }

  void updateBeams(double cameraX, double rays, sd.Vector3 light) {
    final specs = data['beams'] as List? ?? const [];
    var index = 0;
    for (final node in nodes) {
      if (!node.name.startsWith('BEAM_') || node is! sd.DrawMesh) continue;
      final strength = rays * (specs[index++][2] as num) * .16;
      node.material!.uniforms['uStrength']['value'] = strength;
      node.visible = strength > .002 && (node.position.x - cameraX).abs() < 40;
      node.rotation.z = math.atan2(-light.x, math.max(light.y, .15)) * .8;
      node.updateMatrix();
    }
  }

  /// _S.update: the lake's depth mask must sink with its far-water fade.
  /// It extends well beyond W6 and otherwise cuts holes in later mountains.
  void updateLake(double playerX) {
    if (id != 'W6') return;
    double smooth(double a, double b, double x) {
      final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    final x = playerX - (data['ox'] as num);
    final cut = math.max(smooth(56, 72, x), 1 - smooth(405, 418, playerX));
    for (final node in nodes) {
      if (node.name == 'W6_WATER_DEPTH') {
        final base = node.userData.putIfAbsent(
          'lakeDepthY',
          () => node.position.y,
        ) as double;
        node.position.y = base - 40 * cut;
        node.updateMatrix();
      }
      if (node is! sd.DrawMesh) continue;
      final u = node.material!.uniforms;
      if (node.name == 'W6_WATER') u['uFarCut']['value'] = cut;
      if (node.name == 'W6_GATE_FOG' || node.name == 'W6_FAR_VEIL') {
        final amount = node.name == 'W6_GATE_FOG'
            ? smooth(24.15, 40.15, x) * (1 - smooth(52.15, 76.15, x)) * .98
            : smooth(25.15, 40.15, x) * (1 - smooth(50, 84, x));
        u['uAmt']['value'] = amount;
        node.visible = amount > .002;
      }
      if (node.name == 'W6_HORIZON') {
        u['uAmt']['value'] =
            smooth(44, 70, x) *
            (1 + 2.6 * smooth(70, 96, x)) *
            (1 - smooth(84, 108, x));
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    onDispose?.call();
    root.removeFromParent();
    // Instance attributes are owned separately from shared geometry buffers.
    for (final node in nodes.whereType<sd.InstanceMesh>()) {
      node.dispatchEvent(sd.Event(type: 'dispose'));
    }
    for (final m in materials) {
      m.dispose();
    }
    for (final g in geometries) {
      g.dispose();
    }
  }
}
