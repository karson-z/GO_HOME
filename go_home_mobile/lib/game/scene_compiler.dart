// Source asset adapter. All drawing is submitted through Flutter Scene / Flutter GPU.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:flutter_scene/src/gpu/gpu.dart' as gpu;
import 'package:flutter_scene/src/render/frame_transients.dart';

import 'scene_data.dart' as sd;

import 'package:vector_math/vector_math.dart' as vm;

import 'package:go_home_mobile/game/native_world_assets.dart';

import 'native_render_order.dart';
import 'source_uniforms.dart';
import 'native_load_budget.dart';

class SourceShaderLibrary {
  late gpu.ShaderLibrary library;
  late Map<String, dynamic> metadata;
  final textures = <sd.TextureData, fs.TextureSource>{};
  final renderTextures = <sd.TextureData, fs.RenderTexture>{};
  final materials = <SourceMaterial>[];
  final programs = <String, String>{};
  sd.Vector2 viewport = sd.Vector2(1200, 546);
  final textureVersions = <sd.TextureData, int>{};
  static String signature(String vertex, String fragment, Map? defines) {
    String compact(String value) => value.replaceAll(RegExp(r'\s+'), '');
    final keys = (defines?.keys.toList() ?? [])..sort();
    final value =
        '${compact(vertex)}\u0000${compact(fragment)}\u0000${jsonEncode({for (final key in keys) key: defines![key]})}';
    var hash = 1469598103934665603;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 1099511628211) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }

  Future<void> initialize() async {
    metadata = jsonDecode(
      await rootBundle.loadString('assets/data/full_scene_shaders.json'),
    );
    library = (await gpu.loadShaderLibraryAsync(
      'build/shaderbundles/full_scene.shaderbundle',
    ))!;
    for (final p in metadata['programs'] as List) {
      programs[p['signature'] ??
              signature(p['vertex'], p['fragment'], p['defines'])] =
          p['id'];
    }
  }

  String identify(sd.MaterialData material, {bool instanced = false}) {
    if (material is sd.BillboardData) {
      return material.alphaMap == null ? 'sprite' : 'sprite/alpha';
    }
    if (material is sd.UnlitData) {
      return material.map == null ? 'basic' : 'basic/map';
    }
    final defines = <dynamic, dynamic>{...?material.defines};
    if (instanced) defines['USE_INSTANCING'] = '';
    final id =
        programs[signature(
          material.vertexShader!,
          material.fragmentShader!,
          defines,
        )];
    if (id == null) {
      throw StateError(
        'Uncompiled source material: ${material.name} ($defines)',
      );
    }
    return id;
  }

  String key(String name) => metadata['lookup'][name] as String? ?? name;
  SourceMaterial material(
    sd.MaterialData source,
    String name,
    sd.SceneCamera camera, {
    sd.SceneNode? object,
  }) {
    final id = key(name);
    final m = SourceMaterial(
      this,
      source,
      metadata['pairs'][id],
      id,
      camera,
      object,
    );
    materials.add(m);
    return m;
  }

  fs.TextureSource texture(sd.TextureData source) {
    final target = renderTextures[source];
    if (target != null) return target;
    final cached = textures[source];
    if (cached != null && textureVersions[source] != source.version) {
      cached.sampledTexture!.overwrite(
        ByteData.sublistView(source.image!.data),
      );
      textureVersions[source] = source.version;
    }
    return textures.putIfAbsent(source, () {
      final dynamic image = source.image;
      final raw = image.data as TypedData;
      final width = (image.width as num).toInt(),
          height = (image.height as num).toInt();
      final format = source.type == sd.FloatType
          ? gpu.PixelFormat.r32g32b32a32Float
          : source.type == sd.HalfFloatType
          ? gpu.PixelFormat.r16g16b16a16Float
          : source.format == sd.RedFormat
          ? gpu.PixelFormat.r8UNormInt
          : source.colorSpace == sd.SRGBColorSpace
          ? gpu.PixelFormat.r8g8b8a8UNormIntSRGB
          : gpu.PixelFormat.r8g8b8a8UNormInt;
      final t = gpu.gpuContext.createTexture(
        gpu.StorageMode.hostVisible,
        width,
        height,
        format: format,
        enableRenderTargetUsage: false,
      );
      t.overwrite(ByteData.sublistView(raw));
      textureVersions[source] = source.version;
      final sampler = gpu.SamplerOptions(
        minFilter: source.minFilter == sd.NearestFilter
            ? gpu.MinMagFilter.nearest
            : gpu.MinMagFilter.linear,
        magFilter: source.magFilter == sd.NearestFilter
            ? gpu.MinMagFilter.nearest
            : gpu.MinMagFilter.linear,
        widthAddressMode: source.wrapS == sd.RepeatWrapping
            ? gpu.SamplerAddressMode.repeat
            : gpu.SamplerAddressMode.clampToEdge,
        heightAddressMode: source.wrapT == sd.RepeatWrapping
            ? gpu.SamplerAddressMode.repeat
            : gpu.SamplerAddressMode.clampToEdge,
      );
      return fs.GpuTextureSource(t, sampler: sampler);
    });
  }
}

final class SourceMaterial extends fs.ShaderMaterial {
  SourceMaterial(
    this.registry,
    this.source,
    this.spec,
    this.id,
    this.camera,
    this.object,
  ) : super(
        vertexShader: registry.library['${id}_v']!,
        fragmentShader: registry.library['${id}_f']!,
        instanceAttributes: [
          for (final a in spec['instanceCustom'] ?? [])
            fs.ShaderInstanceAttribute(a[1], switch (a[0]) {
              'float' => fs.ShaderInstanceAttributeType.float,
              'vec2' => fs.ShaderInstanceAttributeType.vec2,
              'vec3' => fs.ShaderInstanceAttributeType.vec3,
              _ => fs.ShaderInstanceAttributeType.vec4,
            }),
        ],
        isOpaqueOverride: !source.transparent,
        // Source GLSL keeps OpenGL winding; Scene's encoder fixes clockwise.
        // Invert face culling instead of changing any source geometry.
        cullingMode: source.side == sd.DoubleSide
            ? gpu.CullMode.none
            : source.side == sd.BackSide
            ? gpu.CullMode.backFace
            : gpu.CullMode.frontFace,
      ) {
    for (final stage in ['vertex', 'fragment']) {
      final info = spec[stage] as Map;
      final data = Float32List((info['slots'] as int) * 4);
      storage[stage] = data;
      setUniformBlock(
        stage == 'vertex' ? 'SourceVertexParams' : 'SourceFragmentParams',
        ByteData.sublistView(data),
        stage: stage == 'vertex'
            ? fs.ShaderStage.vertex
            : fs.ShaderStage.fragment,
      );
      for (final name in (info['samplers'] as List).cast<String>()) {
        final value = valueOf(name);
        if (value is sd.TextureData &&
            !value.isRenderTargetTexture &&
            value.image != null) {
          setTexture(
            name,
            registry.texture(value),
            stage: stage == 'vertex'
                ? fs.ShaderStage.vertex
                : fs.ShaderStage.fragment,
          );
        }
      }
    }
    doubleSided = source.side == sd.DoubleSide;
    update();
  }
  final SourceShaderLibrary registry;
  final String id;
  final sd.MaterialData source;
  final Map spec;
  final sd.SceneCamera camera;
  final sd.SceneNode? object;
  final storage = <String, Float32List>{};
  final _boundTextures = <String, fs.TextureSource>{};
  final _polygonOffset = sd.Vector2();
  dynamic valueOf(String name) {
    if (name == 'sourcePolygonOffset') {
      return _polygonOffset..setValues(
        source.polygonOffset ? source.polygonOffsetFactor.toDouble() : 0,
        source.polygonOffset ? source.polygonOffsetUnits.toDouble() : 0,
      );
    }
    if (name == 'sourceViewport') return registry.viewport;
    if (name == 'projectionMatrix') return camera.projectionMatrix;
    if (name == 'viewMatrix') return camera.matrixWorldInverse;
    if (name == 'modelMatrix') {
      return object?.matrixWorld ?? sd.Matrix4.identity();
    }
    if (name == 'cameraPosition') return camera.position;
    if (source is sd.BillboardData || source is sd.UnlitData) {
      if (name == 'map') return source.map;
      if (name == 'alphaMap') return source.alphaMap;
      if (name == 'diffuse') return source.color;
      if (name == 'opacity') return source.opacity;
      if (name == 'alphaTest') return source.alphaTest;
      if (name == 'rotation') return source.rotation;
    }
    return source.uniforms[name]?['value'];
  }

  void update() {
    for (final stage in ['vertex', 'fragment']) {
      final data = storage[stage]!;
      for (final u in spec[stage]['uniforms'] as List) {
        final value = valueOf(u['name']);
        _pack(data, (u['offset'] as int) * 4, u['type'], u['count'], value);
      }
      for (final name in (spec[stage]['samplers'] as List).cast<String>()) {
        final value = valueOf(name);
        if (value is sd.TextureData &&
            (!value.isRenderTargetTexture ||
                registry.renderTextures.containsKey(value))) {
          final texture = registry.texture(value);
          final key = '$stage/$name';
          if (!identical(_boundTextures[key], texture)) {
            _boundTextures[key] = texture;
            setTexture(
              name,
              texture,
              stage: stage == 'vertex'
                  ? fs.ShaderStage.vertex
                  : fs.ShaderStage.fragment,
            );
          }
        }
      }
    }
  }

  static void _pack(
    Float32List data,
    int offset,
    String type,
    int count,
    dynamic value,
  ) => packSourceUniform(data, offset, type, count, value);

  @override
  bool get translucentDepthWrite => source.depthWrite;
  @override
  gpu.CompareFunction get depthCompare => source.depthTest
      ? gpu.CompareFunction.lessEqual
      : gpu.CompareFunction.always;
  @override
  void bind(
    gpu.RenderPass pass,
    TransientWriter transientsBuffer,
    fs.Lighting lighting,
  ) {
    super.bind(pass, transientsBuffer, lighting);
    pass.setDepthWriteEnable(source.depthWrite);
    pass.setDepthCompareOperation(depthCompare);
    // Flutter GPU has no color-write mask. A zero/one blend preserves both
    // color and alpha while the source's depth-only occluder still writes depth.
    if (!source.colorWrite) {
      pass.setColorBlendEnable(true);
      pass.setColorBlendEquation(
        gpu.ColorBlendEquation(
          sourceColorBlendFactor: gpu.BlendFactor.zero,
          destinationColorBlendFactor: gpu.BlendFactor.one,
          sourceAlphaBlendFactor: gpu.BlendFactor.zero,
          destinationAlphaBlendFactor: gpu.BlendFactor.one,
        ),
      );
      return;
    }
    pass.setColorBlendEnable(
      source.blending != sd.NoBlending &&
          (source.transparent || source.blending == sd.CustomBlending),
    );
    gpu.BlendFactor factor(int? f) => switch (f) {
      200 => gpu.BlendFactor.zero,
      201 => gpu.BlendFactor.one,
      202 => gpu.BlendFactor.sourceColor,
      203 => gpu.BlendFactor.oneMinusSourceColor,
      204 => gpu.BlendFactor.sourceAlpha,
      205 => gpu.BlendFactor.oneMinusSourceAlpha,
      _ => gpu.BlendFactor.one,
    };
    pass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: source.blending == sd.CustomBlending
            ? factor(source.blendSrc)
            : gpu.BlendFactor.sourceAlpha,
        destinationColorBlendFactor: source.blending == sd.CustomBlending
            ? factor(source.blendDst)
            : source.blending == sd.AdditiveBlending
            ? gpu.BlendFactor.one
            : gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: source.blending == sd.CustomBlending
            ? factor(source.blendSrcAlpha)
            : gpu.BlendFactor.one,
        destinationAlphaBlendFactor: source.blending == sd.CustomBlending
            ? factor(source.blendDstAlpha)
            : source.blending == sd.AdditiveBlending
            ? gpu.BlendFactor.one
            : gpu.BlendFactor.oneMinusSourceAlpha,
      ),
    );
  }
}

class SceneCompiler {
  SceneCompiler(this.registry, this.camera);
  final SourceShaderLibrary registry;
  final sd.SceneCamera camera;
  sd.ViewFrustum? frustum;
  final nodes = <({sd.SceneNode source, fs.Node target})>[];
  final geometries = <String, fs.MeshGeometry>{};
  final sourceNames = <sd.MaterialData, String>{};
  final geometryCounts = <String, int>{};
  final mapped = <sd.SceneNode, fs.Node>{};
  final sources = <fs.Node, sd.SceneNode>{};
  final sourceMaterials = <sd.SceneNode, sd.MaterialData>{};
  final instancesBySource = <sd.InstanceMesh, fs.InstancedMesh>{};
  final instanceVersions = <sd.InstanceMesh, int>{};
  final geometryVersions = <sd.GeometryData, int>{};
  final geometryBySource = <sd.GeometryData, fs.MeshGeometry>{};
  final _treeVersions = <sd.SceneNode, int>{};
  int meshCount = 0, instances = 0;
  void registerChunk(NativeWorldChunk chunk) {
    final ids = (chunk.data['materials'] as Map).keys.toList();
    for (var i = 0; i < ids.length; i++) {
      final name = '${chunk.id}/${ids[i]}';
      if (registry.metadata['lookup'].containsKey(name)) {
        sourceNames[chunk.materials[i]] = name;
      }
    }
  }

  static bool _usesRenderTexture(sd.SceneNode source) =>
      source.material?.uniforms.values.any(
        (u) =>
            u is Map &&
            u['value'] is sd.TextureData &&
            (u['value'] as sd.TextureData).isRenderTargetTexture,
      ) ??
      false;

  fs.MeshGeometry geometry(sd.SceneNode source, String shaderName) {
    final g = source.geometry!;
    final flipped = _usesRenderTexture(source);
    final cacheKey =
        '${g.uuid}/${registry.key(shaderName)}/${flipped ? 'target' : 'image'}';
    return geometries.putIfAbsent(cacheKey, () {
      final spec = registry.metadata['pairs'][registry.key(shaderName)];
      final points = spec['points'] == true;
      Float32List expand(Float32List data, int size) {
        if (!points) return data;
        return Float32List.fromList([
          for (var i = 0; i < data.length; i += size)
            for (var corner = 0; corner < 6; corner++)
              ...data.sublist(i, i + size),
        ]);
      }

      Float32List? attr(String name, int size) {
        final sd.VertexAttribute? a = g.getAttributeFromString(name);
        if (a == null) return null;
        // World attributes are already worker-owned contiguous float buffers.
        // Keep them as views instead of copying every vertex on the UI isolate.
        if (!points &&
            a.itemSize == size &&
            a.array is Float32List &&
            !(name == 'uv' && flipped)) {
          return a.array as Float32List;
        }
        final out = Float32List(a.count * size);
        for (var i = 0; i < a.count; i++) {
          for (var j = 0; j < size; j++) {
            {
              out[i * size + j] = (switch (j) {
                0 => a.getX(i),
                1 => a.getY(i),
                2 => a.getZ(i),
                _ => a.getW(i),
              }).toDouble();
            }
          }
        }
        return expand(out, size);
      }

      final p = attr('position', 3)!;
      final indices = points ? null : g.index;
      final uv = attr('uv', 2);
      // RenderTexture sampling has the opposite Y origin to uploaded atlases.
      if (flipped && uv != null) {
        for (var i = 1; i < uv.length; i += 2) {
          uv[i] = 1 - uv[i];
        }
      }
      final result = fs.MeshGeometry.fromArrays(
        positions: p,
        normals: attr('normal', 3),
        texCoords: uv,
        indices: indices == null
            ? null
            : indices.array is Uint32List && indices.itemSize == 1
            ? indices.array as Uint32List
            : List<int>.generate(indices.count, (i) => indices.getX(i).toInt()),
        bounds: g.boundingSphere == null
            ? null
            : vm.Aabb3.minMax(
                vm.Vector3(
                  g.boundingSphere!.center.x - g.boundingSphere!.radius,
                  g.boundingSphere!.center.y - g.boundingSphere!.radius,
                  g.boundingSphere!.center.z - g.boundingSphere!.radius,
                ),
                vm.Vector3(
                  g.boundingSphere!.center.x + g.boundingSphere!.radius,
                  g.boundingSphere!.center.y + g.boundingSphere!.radius,
                  g.boundingSphere!.center.z + g.boundingSphere!.radius,
                ),
              ),
        primitiveType: source is sd.PointCloud && !points
            ? gpu.PrimitiveType.point
            : gpu.PrimitiveType.triangle,
        retainCpuData: source.name.startsWith('OWL_BRANCH_'),
        storage: source.name.startsWith('OWL_BRANCH_')
            ? fs.GeometryStorage.updatable
            : fs.GeometryStorage.fixed,
      );
      for (final item in spec['custom'] as List) {
        final type = item[0] as String, name = item[1] as String;
        final size = type == 'float' ? 1 : int.parse(type.substring(3));
        var values = name == 'aPointCorner'
            ? Float32List.fromList([
                for (var i = 0; i < p.length ~/ 18; i++) ...[
                  -.5,
                  -.5,
                  .5,
                  -.5,
                  -.5,
                  .5,
                  -.5,
                  .5,
                  .5,
                  -.5,
                  .5,
                  .5,
                ],
              ])
            : attr(name, size) ?? Float32List(p.length ~/ 3 * size);
        if (values.length == size && p.length ~/ 3 > 1) {
          final constant = values;
          values = Float32List(p.length ~/ 3 * size);
          for (var vertex = 0; vertex < p.length ~/ 3; vertex++) {
            values.setRange(vertex * size, (vertex + 1) * size, constant);
          }
        }
        result.setCustomAttribute(name, values, components: size);
      }
      geometryCounts[cacheKey] = p.length ~/ 3;
      geometryBySource[g] = result;
      geometryVersions[g] = g.getAttributeFromString('position')?.version ?? 0;
      return result;
    });
  }

  fs.Node convert(
    sd.SceneNode source, {
    int layer = 1,
    String? shaderOverride,
    bool includeChildren = true,
    bool deferInstances = false,
  }) {
    final existing = mapped[source];
    if (existing != null) return existing;
    if (source.matrixAutoUpdate) source.updateMatrix();
    fs.Node target = fs.Node(name: source.name)
      ..frustumCulled = false
      ..layers = layer;
    mapped[source] = target;
    sources[target] = source;
    if ((source is sd.DrawMesh ||
            source is sd.BillboardNode ||
            source is sd.PointCloud) &&
        !(source is sd.InstanceMesh && source.count == 0)) {
      final m = source.material!;
      var name =
          shaderOverride ??
          sourceNames[m] ??
          registry.identify(m, instanced: source is sd.InstanceMesh);
      if (source is sd.InstanceMesh &&
          sourceNames.containsKey(m) &&
          registry.metadata['lookup'].containsKey(name)) {
        final names = <String>[
          for (final a
              in (registry.metadata['pairs'][registry.key(name)]['custom']
                  as List))
            if (source.geometry!.getAttributeFromString(a[1])
                is sd.InstanceAttribute)
              a[1] as String,
        ]..sort();
        name = '$name/inst/${names.join(',')}';
      }
      final material = registry.material(m, name, camera, object: source);
      final g = geometry(source, name);
      if (source is sd.InstanceMesh) {
        final inst = fs.InstancedMesh(
          geometry: g,
          material: material,
          sortTransparentInstances: false,
        );
        if (!deferInstances) {
          for (
            var i = 0;
            i < (source.instanceMatrix?.count ?? source.count ?? 0);
            i++
          ) {
            _addInstance(
              source,
              inst,
              registry.metadata['pairs'][registry.key(name)],
              i,
            );
          }
        }
        target.addComponent(fs.InstancedMeshComponent(inst));
        inst.drawSelector = (_) =>
            fs.MeshDrawSelection(instanceCount: source.count ?? 0);
        instancesBySource[source] = inst;
        instanceVersions[source] = source.instanceMatrix?.version ?? 0;
        instances += source.count ?? 0;
      } else {
        target.mesh = fs.Mesh(g, material);
      }
      meshCount++;
      sourceMaterials[source] = m;
    }
    nodes.add((source: source, target: target));
    if (includeChildren) {
      for (final child in source.children) {
        target.add(
          convert(child, layer: layer, shaderOverride: shaderOverride),
        );
      }
      _treeVersions[source] = source.subtreeRevision;
    }
    return target;
  }

  void _addInstance(
    sd.InstanceMesh source,
    fs.InstancedMesh inst,
    Map spec,
    int i,
  ) {
    final tmp = sd.Matrix4.identity();
    source.getMatrixAt(i, tmp);
    final color = source.instanceColor;
    inst.addInstance(
      vm.Matrix4.fromList(tmp.storage),
      color: color == null
          ? null
          : vm.Vector4(
              color.getX(i).toDouble(),
              color.getY(i).toDouble(),
              color.getZ(i).toDouble(),
              1,
            ),
    );
    for (final a in spec['instanceCustom'] ?? []) {
      final attribute =
          source.geometry!.getAttributeFromString(a[1])!
              as sd.InstanceAttribute;
      final index = i ~/ attribute.meshPerAttribute;
      final x = attribute.getX(index).toDouble();
      final value = switch (a[0]) {
        'float' => x,
        'vec2' => vm.Vector2(x, attribute.getY(index).toDouble()),
        'vec3' => vm.Vector3(
          x,
          attribute.getY(index).toDouble(),
          attribute.getZ(index).toDouble(),
        ),
        _ => vm.Vector4(
          x,
          attribute.getY(index).toDouble(),
          attribute.getZ(index).toDouble(),
          attribute.getW(index).toDouble(),
        ),
      };
      inst.setInstanceAttribute(i, a[1], value);
    }
  }

  Future<fs.Node> prepare(
    sd.SceneNode source,
    NativeLoadBudget budget, {
    int layer = 1,
  }) async {
    final existed = mapped.containsKey(source);
    final target = convert(
      source,
      layer: layer,
      includeChildren: false,
      deferInstances: true,
    );
    await budget.checkpoint();
    if (!existed &&
        source is sd.InstanceMesh &&
        instancesBySource.containsKey(source)) {
      final inst = instancesBySource[source]!;
      final spec =
          registry.metadata['pairs'][registry.materials
              .lastWhere((m) => identical(m.object, source))
              .id];
      for (
        var i = 0;
        i < (source.instanceMatrix?.count ?? source.count ?? 0);
        i++
      ) {
        _addInstance(source, inst, spec, i);
        if (i % 32 == 31) await budget.checkpoint();
      }
    }
    for (final child in source.children) {
      final node = await prepare(child, budget, layer: layer);
      if (node.parent == null) target.add(node);
    }
    _treeVersions[source] = source.subtreeRevision;
    return target;
  }

  /// Reconcile additions/removals as source hints, props, and streaming roots change.
  void reconcile(sd.SceneNode root, fs.Node target, {int layer = 1}) {
    if (_treeVersions[root] == root.subtreeRevision) return;
    final expected = root.children.toSet();
    for (final child in target.children.toList()) {
      final source = sources[child];
      if (source != null && !expected.contains(source)) {
        target.remove(child);
        _forget(source);
      }
    }
    for (final child in root.children) {
      var node = mapped[child];
      if (node == null) {
        node = convert(child, layer: layer);
        target.add(node);
      } else {
        if (!identical(node.parent, target)) {
          node.parent?.remove(node);
          target.add(node);
        }
        reconcile(child, node, layer: layer);
      }
    }
    _treeVersions[root] = root.subtreeRevision;
  }

  void _forget(sd.SceneNode source) {
    // Retiring a streamed chunk used to scan the whole world once per node.
    // Collect the subtree and sweep each table once instead.
    final removed = <sd.SceneNode>{};
    source.traverse(removed.add);
    final candidateGeometry = <sd.GeometryData>{};
    final candidateMaterials = <sd.MaterialData>{};
    for (final node in removed) {
      final material = sourceMaterials.remove(node);
      if (material != null) candidateMaterials.add(material);
      if (node.geometry != null) candidateGeometry.add(node.geometry!);
      sources.remove(mapped.remove(node));
      _treeVersions.remove(node);
      if (node is sd.InstanceMesh) {
        instancesBySource.remove(node);
        instanceVersions.remove(node);
      }
    }
    registry.materials.removeWhere((m) => removed.contains(m.object));
    nodes.removeWhere((pair) => removed.contains(pair.source));
    final retainedGeometry = mapped.keys.map((s) => s.geometry).toSet();
    final retiredIds = <String>{};
    for (final g in candidateGeometry.where(
      (g) => !retainedGeometry.contains(g),
    )) {
      geometryBySource.remove(g);
      geometryVersions.remove(g);
      retiredIds.add(g.uuid);
    }
    geometries.removeWhere(
      (key, _) => retiredIds.contains(key.split('/').first),
    );
    geometryCounts.removeWhere(
      (key, _) => retiredIds.contains(key.split('/').first),
    );
    final retainedMaterials = sourceMaterials.values.toSet();
    for (final material in candidateMaterials.difference(retainedMaterials)) {
      sourceNames.remove(material);
    }
  }

  void sync() {
    for (final pair in nodes) {
      final s = pair.source, t = pair.target;
      if (s.matrixAutoUpdate) s.updateMatrix();
      t.visible =
          s.visible &&
          (s.material?.visible ?? true) &&
          (s.geometry == null || s.layers.isEnabled(0));
      if (t.visible &&
          s.geometry != null &&
          s.frustumCulled &&
          frustum != null) {
        t.visible = frustum!.intersectsObject(s);
      }
      t.renderOrder = sourceRenderOrder(s, s.renderOrder).toDouble();
      final a =
          (s.matrixWorldAutoUpdate
                  ? s.matrix
                  : (s.parent == null
                        ? s.matrixWorld
                        : (s.parent!.matrixWorld.clone()..invert()) *
                              s.matrixWorld))
              .storage;
      final b = t.localTransform.storage;
      var changed = false;
      for (var i = 0; i < 16; i++) {
        if (a[i] != b[i]) {
          changed = true;
          break;
        }
      }
      if (changed) t.localTransform = vm.Matrix4.fromList(a);
      if (s is sd.InstanceMesh) {
        final version = s.instanceMatrix?.version ?? 0;
        if (version != instanceVersions[s]) {
          final mesh = instancesBySource[s];
          final matrix = sd.Matrix4.identity();
          if (mesh != null) {
            mesh.updateInstanceTransforms((transforms) {
              for (var i = 0; i < transforms.length; i++) {
                s.getMatrixAt(i, matrix);
                transforms[i].setFrom(vm.Matrix4.fromList(matrix.storage));
              }
            });
          }
          instanceVersions[s] = version;
        }
      }
      final g = s.geometry;
      if (g != null && s.name.startsWith('OWL_BRANCH_')) {
        final p = g.getAttributeFromString('position')!;
        if (geometryVersions[g] != p.version) {
          geometryBySource[g]!.updatePositions(
            Float32List.fromList([
              for (var i = 0; i < p.count; i++) ...[
                p.getX(i).toDouble(),
                p.getY(i).toDouble(),
                p.getZ(i).toDouble(),
              ],
            ]),
          );
          geometryVersions[g] = p.version;
        }
      }
    }
  }
}

class SourcePostprocess extends fs.CustomRenderPass {
  SourcePostprocess(this.registry, this.assets, this.camera);
  final SourceShaderLibrary registry;
  final NativeWorldAssets assets;
  final sd.SceneCamera camera;
  final passes = <String, SourceMaterial>{};
  final targets = <String, gpu.Texture>{};
  final pipelines = <String, gpu.RenderPipeline>{};
  final host = gpu.gpuContext.createHostBuffer();
  late final gpu.BufferView quad = gpu.BufferView(
    gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(
        Float32List.fromList([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      ),
    ),
    offsetInBytes: 0,
    lengthInBytes: 48,
  );
  int width = 0, height = 0, lastCpuUs = 0;
  double strength = 0, threshold = .8;
  String debugOutput = 'final';
  @override
  String get name => 'Original HDR / five-level bloom / grade';
  @override
  fs.RenderStage get stage => fs.RenderStage.afterAntiAliasing;
  Future<void> initialize() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/world/postprocess.json'),
    ) as Map;
    for (final entry in data.entries) {
      final values = entry.value is List ? entry.value as List : [entry.value];
      for (var i = 0; i < values.length; i++) {
        final name = '${entry.key}${entry.value is List ? i : ''}',
            source = values[i] as Map;
        final uniforms = <String, dynamic>{};
        for (final e in (source['uniforms'] as Map).entries) {
          uniforms[e.key] = {'value': await assets.decodeValue(e.value)};
        }
        final material = sd.ShaderData.fromMap({
          'uniforms': uniforms,
          'depthTest': false,
          'depthWrite': false,
        });
        passes[name] = registry.material(material, 'post/$name', camera);
      }
    }
  }

  gpu.Texture target(String id, int w, int h) => targets.putIfAbsent(
    id,
    () => gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      w,
      h,
      format: gpu.PixelFormat.r16g16b16a16Float,
    ),
  );
  void set(String pass, String uniform, dynamic value) =>
      passes[pass]!.source.uniforms[uniform]['value'] = value;
  void resize(int w, int h) {
    if (width == w && height == h) return;
    targets.clear();
    width = w;
    height = h;
    target('guarded', w, h);
    target('bloomed', w, h);
    target('graded', w, h);
    target('final', w, h);
    var bw = (w / 2).round(), bh = (h / 2).round();
    target('bright', bw, bh);
    target('composite', bw, bh);
    for (var i = 0; i < 5; i++) {
      target('h$i', bw, bh);
      target('v$i', bw, bh);
      set('blur$i', 'invSize', sd.Vector2(1 / bw, 1 / bh));
      bw = math.max(1, (bw / 2).round());
      bh = math.max(1, (bh / 2).round());
    }
    set('guard', 'uTexel', sd.Vector2(1 / w, 1 / h));
    set('grade', 'uRes', sd.Vector2(w.toDouble(), h.toDouble()));
    set('composite', 'bloomFactors', [1.0, .8, .6, .4, .2]);
    set(
      'composite',
      'bloomTintColors',
      List.generate(5, (_) => sd.Vector3(1, 1, 1)),
    );
    set('composite', 'bloomRadius', .55);
  }

  void palette(Map<String, dynamic> p, double time) {
    const mapping = {
      'uSat': 'saturation',
      'uContrast': 'contrast',
      'uLift': 'lift',
      'uGain': 'gain',
      'uDarkDesat': 'darkDesat',
      'uGrain': 'grain',
      'uHighK': 'high',
      'uSplitK': 'split',
      'uDarkTintK': 'darkTint',
    };
    for (final e in mapping.entries) {
      set('grade', e.key, p[e.value]);
    }
    set('grade', 'uTime', time);
    set(
      'grade',
      'uVignette',
      p['vignette'] * (.5 + .5 * ((p['value'] as num) / 25).clamp(0, 1)),
    );
    final a = p['shadowTint'] as List, b = p['highlightTint'] as List;
    final maxValue = math.max(
      math.max(b[0] as num, b[1] as num),
      math.max(b[2] as num, .001),
    );
    set('grade', 'uShadowTint', sd.Vector3(a[0], a[1], a[2]));
    set(
      'grade',
      'uHighTint',
      sd.Vector3(b[0] / maxValue, b[1] / maxValue, b[2] / maxValue),
    );
    set('final', 'uToe', p['toe']);
    strength = math.min((p['bloom'] as num).toDouble(), .75) * .42;
    threshold = (p['bloomThreshold'] as num).toDouble();
  }

  void draw(String id, gpu.Texture output, Map<String, gpu.Texture> inputs) {
    final mat = passes[id]!;
    mat.update();
    final shader = mat.fragmentShader;
    final pipeline = pipelines.putIfAbsent(
      id,
      () => gpu.gpuContext.createRenderPipeline(
        registry.library['ProbeFullscreenVertex']!,
        shader,
      ),
    );
    final command = gpu.gpuContext.createCommandBuffer();
    final pass = command.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: output, loadAction: gpu.LoadAction.clear),
      ),
    );
    pass.bindPipeline(pipeline);
    pass.bindVertexBuffer(quad);
    pass.bindUniform(
      shader.getUniformSlot('SourceFragmentParams'),
      host.emplace(ByteData.sublistView(mat.storage['fragment']!)),
    );
    final samplers = (mat.spec['fragment']['samplers'] as List).cast<String>();
    for (final name in samplers) {
      final texture =
          inputs[name] ??
          (mat.valueOf(name) is sd.TextureData
              ? registry.texture(mat.valueOf(name)).sampledTexture
              : null);
      if (texture == null) throw StateError('$id: missing texture $name');
      pass.bindTexture(
        shader.getUniformSlot(name),
        texture,
        sampler: gpu.SamplerOptions(
          minFilter: gpu.MinMagFilter.linear,
          magFilter: gpu.MinMagFilter.linear,
        ),
      );
    }
    pass.setCullMode(gpu.CullMode.none);
    pass.draw(6);
    rendererSubmissions.submit(command);
  }

  void addBloom() {
    final shader = registry.library['ProbeBloomAddFragment']!;
    final pipeline = pipelines.putIfAbsent(
      'addBloom',
      () => gpu.gpuContext.createRenderPipeline(
        registry.library['ProbeFullscreenVertex']!,
        shader,
      ),
    );
    final command = gpu.gpuContext.createCommandBuffer();
    final pass = command.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: targets['bloomed']!),
      ),
    );
    pass.bindPipeline(pipeline);
    pass.bindVertexBuffer(quad);
    pass.bindTexture(shader.getUniformSlot('base_color'), targets['guarded']!);
    pass.bindTexture(
      shader.getUniformSlot('bloom_color'),
      targets['composite']!,
    );
    pass.setCullMode(gpu.CullMode.none);
    pass.setColorBlendEnable(false);
    pass.draw(6);
    rendererSubmissions.submit(command);
  }

  @override
  void execute(fs.RenderPassContext context) {
    if (context.camera is fs.OrthographicCamera ||
        context.camera is SourceCamera &&
            (context.camera as SourceCamera).source is sd.OrthographicLens) {
      return;
    }
    final watch = Stopwatch()..start();
    resize(context.dimensions.width.toInt(), context.dimensions.height.toInt());
    host.reset();
    draw('guard', targets['guarded']!, {'tDiffuse': context.sceneColorHdr});
    set('high', 'luminosityThreshold', threshold);
    set('high', 'smoothWidth', .5);
    draw('high', targets['bright']!, {'tDiffuse': targets['guarded']!});
    var input = targets['bright']!;
    for (var i = 0; i < 5; i++) {
      set('blur$i', 'direction', sd.Vector2(1, 0));
      draw('blur$i', targets['h$i']!, {'colorTexture': input});
      set('blur$i', 'direction', sd.Vector2(0, 1));
      draw('blur$i', targets['v$i']!, {'colorTexture': targets['h$i']!});
      input = targets['v$i']!;
    }
    set('composite', 'bloomStrength', strength);
    draw('composite', targets['composite']!, {
      for (var i = 0; i < 5; i++) 'blurTexture${i + 1}': targets['v$i']!,
    });
    addBloom();
    draw('grade', targets['graded']!, {'tDiffuse': targets['bloomed']!});
    draw('final', targets['final']!, {'tDiffuse': targets['graded']!});
    context.applyShader(
      registry.library['ProbeCopyFragment']!,
      textures: {
        'source_color': debugOutput == 'scene'
            ? context.sceneColorHdr
            : targets[debugOutput]!,
      },
      uniforms: {'CopyInfo': ByteData(16)},
    );
    lastCpuUs = watch.elapsedMicroseconds;
  }
}

/// Uses the exact source camera matrices; only the clip-depth convention changes.
/// This also keeps sorting and bounds checks aligned with the authored camera.
class SourceCamera extends fs.Camera {
  SourceCamera(this.source) : projection = _SourceProjection(source);
  final sd.SceneCamera source;
  @override
  final fs.CameraProjection projection;
  @override
  vm.Vector3 get position =>
      vm.Vector3(source.position.x, source.position.y, source.position.z);
  @override
  vm.Vector3 get forward {
    final v = source.getWorldDirection(sd.Vector3());
    return vm.Vector3(v.x, v.y, v.z);
  }

  @override
  vm.Vector3 get up => vm.Vector3(source.up.x, source.up.y, source.up.z);
  @override
  vm.Matrix4 getViewMatrix() =>
      vm.Matrix4.fromList(source.matrixWorldInverse.storage);
}

class _SourceProjection extends fs.CameraProjection {
  _SourceProjection(this.source);
  final sd.SceneCamera source;
  @override
  vm.Matrix4 getProjectionMatrix(double aspectRatio, {vm.Vector2? jitter}) {
    final m = vm.Matrix4.fromList(source.projectionMatrix.storage);
    for (var column = 0; column < 4; column++) {
      m.setEntry(2, column, (m.entry(2, column) + m.entry(3, column)) * .5);
    }
    return m;
  }
}
