import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

/// Loads source-generated scene data. All rendering and updates run in Dart.
class NativeWorldAssets {
  final Map<String, Future<three.Texture>> _textures = {};
  late Map<String, dynamic> resources;
  late List<Map<String, dynamic>> manifest;
  final Map<String, dynamic> shared = {};
  bool _disposed = false;
  String quality = 'high';
  final Map<three.InstancedMesh, int> _qualityMeshes = {};
  void setQuality(String value) {
    if (value == quality) return;
    quality = value;
    for (final mesh in _qualityMeshes.keys) {
      _applyQuality(mesh);
    }
  }

  void _applyQuality(three.InstancedMesh mesh) {
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
    resources = jsonDecode(
      await rootBundle.loadString('assets/world/resources.json'),
    );
    manifest = (jsonDecode(
      await rootBundle.loadString('assets/world/manifest.json'),
    ) as List).cast<Map<String, dynamic>>();
  }

  Future<three.Texture> texture(String? id) =>
      _textures.putIfAbsent(id ?? '_empty', () async {
        if (id == null) {
          return three.DataTexture(Uint8List.fromList([0, 0, 0, 0]), 1, 1)
            ..needsUpdate = true;
        }
        final data = resources['textures'][id] as Map<String, dynamic>;
        final file = 'assets/world/${data['file']}';
        three.Texture t;
        if (data['raw'] == true) {
          final bytes = await rootBundle.load(file);
          final type = data['type'] as int;
          t = type == three.FloatType
              ? three.DataTexture(
                  bytes.buffer.asFloat32List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes ~/ 4,
                  ),
                  data['width'],
                  data['height'],
                  data['format'],
                  type,
                )
              : type == three.HalfFloatType
              ? three.DataTexture(
                  bytes.buffer.asUint16List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes ~/ 2,
                  ),
                  data['width'],
                  data['height'],
                  data['format'],
                  type,
                )
              : three.DataTexture(
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
          final loaded = await three.TextureLoader(flipY: data['flipY'] == true)
              .fromAsset(file);
          if (loaded == null) throw StateError('Missing source texture: $file');
          t = loaded;
        }
        t.wrapS = data['wrapS'];
        t.wrapT = data['wrapT'];
        t.magFilter = data['magFilter'];
        t.minFilter = data['minFilter'];
        t.colorSpace = data['colorSpace'] ?? three.NoColorSpace;
        t.premultiplyAlpha = data['premultiplyAlpha'] == true;
        t.generateMipmaps = true;
        t.needsUpdate = true;
        if (_disposed) t.dispose();
        return t;
      });

  Future<dynamic> _value(dynamic value) async {
    if (value is List) {
      final values = await Future.wait(value.map(_value));
      // Dart Color stores RGBA; the GPU array flattener requires exactly RGB.
      return values
          .map(
            (v) => v is three.Color ? three.Vector3(v.red, v.green, v.blue) : v,
          )
          .toList();
    }
    if (value is! Map) return value;
    if (value.containsKey('texture')) return texture(value['texture']);
    List<double> numbers(dynamic v) =>
        (v as List).map((n) => (n as num).toDouble()).toList();
    if (value.containsKey('color')) {
      final v = numbers(value['color']);
      return three.Color()..setRGB(v[0], v[1], v[2]);
    }
    if (value.containsKey('vector')) {
      final v = numbers(value['vector']);
      return switch (v.length) {
        2 => three.Vector2(v[0], v[1]),
        3 => three.Vector3(v[0], v[1], v[2]),
        _ => three.Vector4(v[0], v[1], v[2], v[3]),
      };
    }
    if (value.containsKey('matrix')) {
      final v = numbers(value['matrix']);
      if (v.length == 16) return three.Matrix4.identity()..fromNativeArray(v);
      final m = three.Matrix3.identity();
      for (var i = 0; i < 9; i++) {
        m[i] = v[i];
      }
      return m;
    }
    return null;
  }

  Future<dynamic> decodeValue(dynamic value) => _value(value);

  Future<NativeWorldChunk> load(String id) async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/world/$id.json'),
    ) as Map<String, dynamic>;
    final bytes = await rootBundle.load('assets/world/$id.bin');
    final chunk = NativeWorldChunk(id, json);
    chunk.onDispose = () {
      for (final node in chunk.nodes) {
        if (node is three.InstancedMesh) _qualityMeshes.remove(node);
      }
    };
    if (json['shared'] != null) {
      for (final entry in (json['shared'] as Map<String, dynamic>).entries) {
        shared[entry.key] = {'value': await _value(entry.value)};
      }
    }
    three.BufferAttribute attribute(Map<String, dynamic> data) {
      final offset = bytes.offsetInBytes + (data['offset'] as int);
      final length = data['length'] as int, size = data['size'] as int;
      if (data['integer'] == true) {
        return three.Uint32BufferAttribute(
          bytes.buffer.asUint32List(offset, length),
          size,
        );
      }
      final array = Float32List.fromList(
        bytes.buffer.asFloat32List(offset, length),
      );
      if (data['instanced'] == true) {
        return three.InstancedBufferAttribute(
          array,
          size,
          false,
          data['meshPerAttribute'] as int,
        );
      }
      return three.Float32BufferAttribute(array, size);
    }

    final geometries = <String, three.BufferGeometry>{};
    for (final entry in (json['geometries'] as Map<String, dynamic>).entries) {
      final data = entry.value;
      final g = data['instanced'] == true
          ? three.InstancedBufferGeometry()
          : three.BufferGeometry();
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
      geometries[entry.key] = g;
      chunk.geometries.add(g);
    }
    final materials = <String, three.Material>{};
    for (final entry in (json['materials'] as Map<String, dynamic>).entries) {
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
      three.Material material;
      if (data['vertex'] != null) {
        final uniforms = <String, dynamic>{};
        for (final u in (data['uniforms'] as Map<String, dynamic>).entries) {
          final binding = data['sharedBindings']?[u.key];
          uniforms[u.key] = binding != null
              ? shared[binding]
              : {'value': await _value(u.value)};
        }
        options['uniforms'] = uniforms;
        options['vertexShader'] = resources['shaders'][data['vertex']];
        options['fragmentShader'] = resources['shaders'][data['fragment']];
        material = three.ShaderMaterial.fromMap(options);
      } else {
        if (data['color'] != null) {
          options['color'] = await _value(data['color']);
        }
        if (data['map'] != null) options['map'] = await texture(data['map']);
        if (data['alphaMap'] != null) {
          options['alphaMap'] = await texture(data['alphaMap']);
        }
        material = data['type'] == 'SpriteMaterial'
            ? three.SpriteMaterial.fromMap(options)
            : three.MeshBasicMaterial.fromMap(options);
      }
      if (data['rotation'] != null) {
        material.rotation = (data['rotation'] as num).toDouble();
      }
      materials[entry.key] = material;
      chunk.materials.add(material);
    }
    three.Object3D node(Map<String, dynamic> data) {
      final geometry = geometries[data['geometry']];
      final mat = data['material'];
      final material = mat is String
          ? materials[mat]
          : mat is List
          ? materials[mat.first]
          : null;
      three.Object3D o;
      if (data['instances'] != null) {
        final mesh = three.InstancedMesh(geometry!, material, data['count']);
        _applyQuality(mesh);
        mesh.instanceMatrix =
            attribute(data['instances']) as three.InstancedBufferAttribute;
        if (data['instanceColor'] != null) {
          mesh.instanceColor = attribute(
            data['instanceColor'],
          ) as three.InstancedBufferAttribute;
        }
        o = mesh;
      } else if (data['type'] == 'Sprite') {
        o = three.Sprite(material);
      } else if (geometry != null) {
        o = data['type'] == 'Points'
            ? three.Points(geometry, material)
            : data['type'] == 'LineSegments'
            ? three.LineSegments(geometry, material)
            : three.Mesh(geometry, material);
      } else {
        o = three.Group();
      }
      o.name = data['name'];
      o.visible = data['visible'];
      o.renderOrder = (data['order'] as num).toInt();
      o.frustumCulled = data['culled'];
      o.matrix.fromNativeArray(
        (data['matrix'] as List).cast<num>().map((n) => n.toDouble()).toList(),
      );
      o.matrix.decompose(o.position, o.quaternion, o.scale);
      o.matrixAutoUpdate = false;
      o.userData = Map<String, dynamic>.from(data['userData']);
      if (data['order'] != o.renderOrder) {
        o.userData['sourceRenderOrder'] = data['order'];
      }
      chunk.nodes.add(o);
      for (final child in data['children']) {
        o.add(node(child));
      }
      return o;
    }

    for (final data in json['nodes']) {
      chunk.root.add(node(data));
    }
    chunk.root.updateMatrixWorld(true);
    return chunk;
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
  void Function()? onDispose;
  final Map<String, dynamic> data;
  final three.Group root = three.Group();
  final List<three.Object3D> nodes = [];
  final List<three.BufferGeometry> geometries = [];
  final List<three.Material> materials = [];

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

  void updateMist(double cameraX, double groundY) {
    for (final o in nodes) {
      final spec = o.userData['spec'];
      if (spec == null || !o.name.startsWith('MIST_')) continue;
      final base =
          (spec['baseY'] as num?)?.toDouble() ??
          groundY + (spec['off'] as num? ?? 0);
      o.position.x = cameraX;
      o.position.y = base + 38;
      o.updateMatrix();
      if (o is three.Mesh && o.material is three.ShaderMaterial) {
        o.material!.uniforms['uBase']['value'] = base;
      }
    }
  }

  void dispose() {
    onDispose?.call();
    root.removeFromParent();
    for (final m in materials) {
      m.dispose();
    }
    for (final g in geometries) {
      g.dispose();
    }
  }
}
