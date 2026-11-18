// ignore_for_file: constant_identifier_names

/// Authored scene and animation data. This module has no renderer, platform
/// plugin, GL context, or engine dependency. SceneCompiler turns it into
/// Flutter Scene nodes; the same data drives the original puzzle animations.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

import 'scene_math.dart';
export 'scene_math.dart';

// Values are the serialized asset format, not a graphics API.
const FrontSide = 0, BackSide = 1, DoubleSide = 2;
const NoBlending = 0,
    NormalBlending = 1,
    AdditiveBlending = 2,
    CustomBlending = 5;
const ZeroFactor = 200,
    OneFactor = 201,
    SrcColorFactor = 202,
    SrcAlphaFactor = 204,
    AddEquation = 100;
const RepeatWrapping = 1000,
    ClampToEdgeWrapping = 1001,
    MirroredRepeatWrapping = 1002;
const NearestFilter = 1003,
    LinearFilter = 1006,
    LinearMipmapLinearFilter = 1008;
const FloatType = 1015,
    HalfFloatType = 1016,
    RGBAFormat = 1023,
    RedFormat = 1028;
const NoColorSpace = '',
    SRGBColorSpace = 'srgb',
    LinearSRGBColorSpace = 'srgb-linear';
int _id = 0;

class Event {
  Event({required this.type});
  final String type;
}

class Disposable {
  final Map<String, List<void Function(Event)>> _listeners = {};
  bool disposed = false;
  void addEventListener(String event, void Function(Event) listener) =>
      _listeners.putIfAbsent(event, () => []).add(listener);
  void dispatchEvent(Event event) {
    for (final callback in [...?_listeners[event.type]]) {
      callback(event);
    }
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    dispatchEvent(Event(type: 'dispose'));
    _listeners.clear();
  }
}

class Layers {
  int mask = 1;
  bool isEnabled(int layer) => (mask & (1 << layer)) != 0;
  void enable(int layer) => mask |= 1 << layer;
  void disable(int layer) => mask &= ~(1 << layer);
  void set(int layer) => mask = 1 << layer;
}

class SceneNode extends Disposable {
  final int id = _id++;
  String get uuid => 'node-$id';
  String name = '';
  bool visible = true,
      frustumCulled = true,
      matrixAutoUpdate = true,
      matrixWorldAutoUpdate = true,
      matrixWorldNeedsUpdate = true;
  int renderOrder = 0;
  final Layers layers = Layers();
  final Vector3 position = Vector3(),
      scale = Vector3(1, 1, 1),
      up = Vector3(0, 1, 0);
  final Quaternion quaternion = Quaternion();
  final Euler _rotation = Euler();
  final List<double> _q = [0, 0, 0, 1], _r = [0, 0, 0];
  Euler get rotation {
    if (_rotation.x == _r[0] &&
        _rotation.y == _r[1] &&
        _rotation.z == _r[2] &&
        (quaternion.x != _q[0] ||
            quaternion.y != _q[1] ||
            quaternion.z != _q[2] ||
            quaternion.w != _q[3])) {
      _rotation.setFromQuaternion(quaternion);
      _rememberRotation();
    }
    return _rotation;
  }

  void _rememberRotation() {
    _q[0] = quaternion.x;
    _q[1] = quaternion.y;
    _q[2] = quaternion.z;
    _q[3] = quaternion.w;
    _r[0] = _rotation.x;
    _r[1] = _rotation.y;
    _r[2] = _rotation.z;
  }

  final Matrix4 matrix = Matrix4.identity(), matrixWorld = Matrix4.identity();
  SceneNode? parent;
  final List<SceneNode> children = [];
  int _subtreeRevision = 0;
  int get subtreeRevision => _subtreeRevision;
  void _structureChanged() {
    for (SceneNode? node = this; node != null; node = node.parent) {
      node._subtreeRevision++;
    }
  }

  Map<String, dynamic> userData = {};
  GeometryData? geometry;
  MaterialData? material;
  SphereBounds? boundingSphere;
  void add(SceneNode node) {
    node.removeFromParent();
    children.add(node);
    node.parent = this;
    node.matrixWorldNeedsUpdate = true;
    _structureChanged();
  }

  void remove(SceneNode node) {
    if (children.remove(node)) {
      node.parent = null;
      _structureChanged();
    }
  }

  void removeFromParent() => parent?.remove(this);
  void traverse(void Function(SceneNode) visit) {
    visit(this);
    for (final c in children) {
      c.traverse(visit);
    }
  }

  void updateMatrix() {
    final e = rotation;
    if (e.x != _r[0] || e.y != _r[1] || e.z != _r[2]) {
      quaternion.setFromEuler(e);
    }
    _rememberRotation();
    matrix.compose(position, quaternion, scale);
    matrixWorldNeedsUpdate = true;
  }

  void updateMatrixWorld([bool force = false]) {
    if (matrixAutoUpdate) updateMatrix();
    if (matrixWorldNeedsUpdate || force) {
      if (matrixWorldAutoUpdate) {
        if (parent == null) {
          matrixWorld.setFrom(matrix);
        } else {
          matrixWorld.multiply2(parent!.matrixWorld, matrix);
        }
      }
      matrixWorldNeedsUpdate = false;
      force = true;
    }
    for (final c in children) {
      c.updateMatrixWorld(force);
    }
  }

  Vector3 getWorldPosition(Vector3 target) {
    _updateParents();
    return target.setFromMatrixPosition(matrixWorld);
  }

  void _updateParents() {
    parent?._updateParents();
    if (matrixAutoUpdate) updateMatrix();
    if (matrixWorldAutoUpdate) {
      if (parent == null) {
        matrixWorld.setFrom(matrix);
      } else {
        matrixWorld.multiply2(parent!.matrixWorld, matrix);
      }
    }
  }

  void lookAt(Vector3 target) {
    final world = getWorldPosition(Vector3());
    final m = vm.makeViewMatrix(world, target, up)..invert();
    quaternion.setFromRotation(m.getRotation());
    _rotation.setFromQuaternion(quaternion);
    _rememberRotation();
  }

  SceneNode? getObjectByName(String value) {
    if (name == value) return this;
    for (final c in children) {
      final found = c.getObjectByName(value);
      if (found != null) return found;
    }
    return null;
  }
}

class GroupNode extends SceneNode {}

class WorldScene extends GroupNode {}

class DrawMesh extends SceneNode {
  DrawMesh(GeometryData? geometry, MaterialData? material) {
    this.geometry = geometry;
    this.material = material;
  }
}

class BillboardNode extends SceneNode {
  BillboardNode(MaterialData? material) {
    this.material = material;
    geometry = PlaneData(1, 1);
  }
}

class PointCloud extends DrawMesh {
  PointCloud(super.geometry, super.material);
}

class LineSegments extends DrawMesh {
  LineSegments(super.geometry, super.material);
}

class InstanceMesh extends DrawMesh {
  InstanceMesh(super.geometry, super.material, this.count) {
    instanceMatrix = InstanceAttribute(Float32List((count ?? 0) * 16), 16);
    for (var i = 0; i < (count ?? 0); i++) {
      setMatrixAt(i, Matrix4.identity());
    }
  }
  void computeBoundingSphere() {
    geometry!.computeBoundingSphere();
    final base = geometry!.boundingSphere!;
    final min = Vector3(double.infinity, double.infinity, double.infinity),
        max = Vector3(-double.infinity, -double.infinity, -double.infinity);
    final spheres = <SphereBounds>[];
    for (var i = 0; i < (count ?? 0); i++) {
      final m = Matrix4.identity();
      getMatrixAt(i, m);
      final b = SphereBounds()
        ..setFrom(base)
        ..applyMatrix4(m);
      spheres.add(b);
      for (var j = 0; j < 3; j++) {
        min[j] = math.min(min[j], b.center[j] - b.radius);
        max[j] = math.max(max[j], b.center[j] + b.radius);
      }
    }
    final center = Vector3()
      ..setFrom(min)
      ..add(max)
      ..scale(.5);
    var radius = 0.0;
    for (final b in spheres) {
      radius = math.max(radius, center.distanceTo(b.center) + b.radius);
    }
    boundingSphere = SphereBounds(center, radius);
  }

  int? count;
  InstanceAttribute? instanceMatrix, instanceColor;
  void getMatrixAt(int index, Matrix4 target) {
    target.fromNativeArray(instanceMatrix!.array.cast<double>(), index * 16);
  }

  void setMatrixAt(int index, Matrix4 value) {
    instanceMatrix!.array.setRange(index * 16, index * 16 + 16, value.storage);
  }
}

class SceneCamera extends SceneNode {
  final Matrix4 projectionMatrix = Matrix4.identity(),
      matrixWorldInverse = Matrix4.identity();
  double near = .1, far = 2000;
  @override
  void updateMatrixWorld([bool force = false]) {
    super.updateMatrixWorld(force);
    matrixWorldInverse.setFrom(matrixWorld);
    matrixWorldInverse.invert();
  }

  void updateProjectionMatrix() {}
  Vector3 getWorldDirection(Vector3 target) {
    updateMatrixWorld();
    target.setValues(
      -matrixWorld.storage[8],
      -matrixWorld.storage[9],
      -matrixWorld.storage[10],
    );
    target.normalize();
    return target;
  }
}

class PerspectiveLens extends SceneCamera {
  PerspectiveLens([
    this.fov = 50,
    this.aspect = 1,
    double near = .1,
    double far = 2000,
  ]) {
    this.near = near;
    this.far = far;
    updateProjectionMatrix();
  }
  double fov, aspect;
  @override
  void updateProjectionMatrix() {
    vm.setPerspectiveMatrix(
      projectionMatrix,
      fov * math.pi / 180,
      aspect,
      near,
      far,
    );
  }
}

class OrthographicLens extends SceneCamera {
  OrthographicLens(
    this.left,
    this.right,
    this.top,
    this.bottom, [
    double near = .1,
    double far = 2000,
  ]) {
    this.near = near;
    this.far = far;
    updateProjectionMatrix();
  }
  double left, right, top, bottom;
  @override
  void updateProjectionMatrix() {
    vm.setOrthographicMatrix(
      projectionMatrix,
      left,
      right,
      bottom,
      top,
      near,
      far,
    );
  }
}

class SphereBounds {
  SphereBounds([Vector3? center, this.radius = 0])
    : center = center ?? Vector3();
  final Vector3 center;
  double radius;
  SphereBounds setFrom(SphereBounds other) {
    center.setFrom(other.center);
    radius = other.radius;
    return this;
  }

  SphereBounds applyMatrix4(Matrix4 m) {
    center.applyMatrix4(m);
    final a = m.storage;
    double norm(int n) =>
        a[n] * a[n] + a[n + 1] * a[n + 1] + a[n + 2] * a[n + 2];
    radius *= math.sqrt(math.max(norm(0), math.max(norm(4), norm(8))));
    return this;
  }
}

class BoxBounds {
  BoxBounds(this.min, this.max);
  final Vector3 min, max;
}

class ViewFrustum {
  final List<List<double>> _planes = [];
  ViewFrustum setFromMatrix(Matrix4 m) {
    _planes.clear();
    for (final row in [0, 1, 2]) {
      for (final sign in [-1, 1]) {
        final p = List<double>.generate(
          4,
          (c) => m.entry(3, c) + sign * m.entry(row, c),
        );
        final n = math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
        _planes.add([for (final v in p) v / n]);
      }
    }
    return this;
  }

  bool intersectsSphere(SphereBounds s) => _planes.every(
    (p) =>
        p[0] * s.center.x + p[1] * s.center.y + p[2] * s.center.z + p[3] >=
        -s.radius,
  );
  bool intersectsBox(BoxBounds b) => _planes.every(
    (p) =>
        p[0] * (p[0] >= 0 ? b.max.x : b.min.x) +
            p[1] * (p[1] >= 0 ? b.max.y : b.min.y) +
            p[2] * (p[2] >= 0 ? b.max.z : b.min.z) +
            p[3] >=
        0,
  );
  bool intersectsObject(SceneNode node) {
    final source = node.boundingSphere ?? node.geometry?.boundingSphere;
    if (source == null) {
      node.geometry?.computeBoundingSphere();
    }
    final sphere = node.boundingSphere ?? node.geometry?.boundingSphere;
    return sphere == null ||
        intersectsSphere(
          SphereBounds()
            ..setFrom(sphere)
            ..applyMatrix4(node.matrixWorld),
        );
  }
}

enum Attribute { position, normal, uv, color }

class VertexAttribute {
  VertexAttribute(this.array, this.itemSize, [this.normalized = false]);
  final List<num> array;
  final int itemSize;
  final bool normalized;
  int version = 0;
  int get count => array.length ~/ itemSize;
  set needsUpdate(bool value) {
    if (value) version++;
  }

  double getX(int i) => array[i * itemSize].toDouble();
  double getY(int i) => array[i * itemSize + 1].toDouble();
  double getZ(int i) => array[i * itemSize + 2].toDouble();
  double getW(int i) => array[i * itemSize + 3].toDouble();
  void setX(int i, num x) => array[i * itemSize] = x;
  void setY(int i, num y) => array[i * itemSize + 1] = y;
  void setXY(int i, num x, num y) {
    setX(i, x);
    array[i * itemSize + 1] = y;
  }

  void setXYZ(int i, num x, num y, num z) {
    setXY(i, x, y);
    array[i * itemSize + 2] = z;
  }
}

class FloatAttribute extends VertexAttribute {
  FloatAttribute(super.array, super.itemSize, [super.normalized]);
}

class IndexAttribute extends VertexAttribute {
  IndexAttribute(super.array, super.itemSize, [super.normalized]);
}

class InstanceAttribute extends VertexAttribute {
  InstanceAttribute(
    super.array,
    super.itemSize, [
    super.normalized,
    this.meshPerAttribute = 1,
  ]);
  final int meshPerAttribute;
}

class GeometryData extends Disposable {
  final int id = _id++;
  String get uuid => 'geometry-$id';
  final Map<String, VertexAttribute> attributes = {};
  VertexAttribute? index;
  SphereBounds? boundingSphere;
  int? instanceCount;
  final List<Map<String, int>> groups = [];
  Map<String, num> drawRange = {'start': 0, 'count': double.infinity};
  void setAttributeFromString(String name, VertexAttribute value) =>
      attributes[name] = value;
  VertexAttribute? getAttributeFromString(String name) => attributes[name];
  VertexAttribute getAttribute(Attribute name) => attributes[name.name]!;
  void setIndex(VertexAttribute value) => index = value;
  void addGroup(int start, int count, int materialIndex) => groups.add({
    'start': start,
    'count': count,
    'materialIndex': materialIndex,
  });
  void setDrawRange(int start, int count) =>
      drawRange = {'start': start, 'count': count};
  GeometryData translate(double x, double y, double z) {
    final p = attributes['position']!;
    for (var i = 0; i < p.count; i++) {
      p.setXYZ(i, p.getX(i) + x, p.getY(i) + y, p.getZ(i) + z);
    }
    p.needsUpdate = true;
    boundingSphere = null;
    return this;
  }

  void computeBoundingSphere() {
    final p = attributes['position'];
    if (p == null || p.count == 0) {
      boundingSphere = SphereBounds();
      return;
    }
    final min = Vector3(double.infinity, double.infinity, double.infinity),
        max = Vector3(-double.infinity, -double.infinity, -double.infinity);
    for (var i = 0; i < p.count; i++) {
      for (var j = 0; j < 3; j++) {
        final v = p.array[i * p.itemSize + j].toDouble();
        min[j] = math.min(min[j], v);
        max[j] = math.max(max[j], v);
      }
    }
    final center = Vector3(
      (min.x + max.x) / 2,
      (min.y + max.y) / 2,
      (min.z + max.z) / 2,
    );
    var r = 0.0;
    for (var i = 0; i < p.count; i++) {
      final d = Vector3(
        p.getX(i).toDouble(),
        p.getY(i).toDouble(),
        p.getZ(i).toDouble(),
      );
      r = math.max(r, center.distanceToSquared(d));
    }
    boundingSphere = SphereBounds(center, math.sqrt(r));
  }
}

class InstanceGeometry extends GeometryData {}

class PlaneData extends GeometryData {
  PlaneData([double width = 1, double height = 1]) {
    final x = width / 2, y = height / 2;
    setAttributeFromString(
      'position',
      FloatAttribute(
        Float32List.fromList([-x, y, 0, x, y, 0, -x, -y, 0, x, -y, 0]),
        3,
      ),
    );
    setAttributeFromString(
      'normal',
      FloatAttribute(
        Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
        3,
      ),
    );
    setAttributeFromString(
      'uv',
      FloatAttribute(Float32List.fromList([0, 1, 1, 1, 0, 0, 1, 0]), 2),
    );
    setIndex(IndexAttribute(Uint32List.fromList([0, 2, 1, 2, 3, 1]), 1));
  }
}

class RingData extends GeometryData {
  RingData(double inner, double outer, int segments) {
    final p = <double>[], n = <double>[], uv = <double>[], indices = <int>[];
    for (final r in [inner, outer]) {
      for (var i = 0; i <= segments; i++) {
        final a = i / segments * math.pi * 2,
            x = r * math.cos(a),
            y = r * math.sin(a);
        p.addAll([x, y, 0]);
        n.addAll([0, 0, 1]);
        uv.addAll([(x / outer + 1) / 2, (y / outer + 1) / 2]);
      }
    }
    for (var i = 0; i < segments; i++) {
      final a = i, b = i + segments + 1;
      indices.addAll([a, b, a + 1, b, b + 1, a + 1]);
    }
    setAttributeFromString(
      'position',
      FloatAttribute(Float32List.fromList(p), 3),
    );
    setAttributeFromString(
      'normal',
      FloatAttribute(Float32List.fromList(n), 3),
    );
    setAttributeFromString('uv', FloatAttribute(Float32List.fromList(uv), 2));
    setIndex(IndexAttribute(Uint32List.fromList(indices), 1));
  }
}

class PixelImage {
  PixelImage({
    this.url = '',
    this.src = '',
    required this.data,
    required this.width,
    required this.height,
  });
  String url, src;
  TypedData data;
  int width, height;
}

class TextureData extends Disposable {
  PixelImage? image;
  int type = 1009,
      format = RGBAFormat,
      wrapS = ClampToEdgeWrapping,
      wrapT = ClampToEdgeWrapping,
      minFilter = LinearFilter,
      magFilter = LinearFilter;
  String colorSpace = NoColorSpace;
  bool premultiplyAlpha = false,
      generateMipmaps = false,
      isRenderTargetTexture = false,
      flipY = false;
  int anisotropy = 1;
  int version = 0;
  set needsUpdate(bool value) {
    if (value) version++;
  }
}

class PixelTexture extends TextureData {
  PixelTexture(
    TypedData data,
    int width,
    int height, [
    int format = RGBAFormat,
    int type = 1009,
  ]) {
    image = PixelImage(data: data, width: width, height: height);
    this.format = format;
    this.type = type;
  }
}

class SurfaceOptions {
  SurfaceOptions.create({
    this.minFilter = LinearFilter,
    this.magFilter = LinearFilter,
    this.format = RGBAFormat,
    this.type = 1009,
    this.colorSpace = NoColorSpace,
    this.depthBuffer = true,
    this.stencilBuffer = false,
  });
  int minFilter, magFilter, format, type;
  String colorSpace;
  bool depthBuffer, stencilBuffer;
}

class RenderSurface extends Disposable {
  RenderSurface(this.width, this.height, [SurfaceOptions? options])
    : options = options ?? SurfaceOptions.create() {
    texture.isRenderTargetTexture = true;
    texture.type = this.options.type;
    texture.format = this.options.format;
  }
  final int width, height;
  final SurfaceOptions options;
  final TextureData texture = TextureData();
  @override
  void dispose() {
    texture.dispose();
    super.dispose();
  }
}

class MaterialData extends Disposable {
  final int id = _id++;
  bool needsUpdate = false;
  String name = '';
  String? vertexShader, fragmentShader;
  Map<String, dynamic> uniforms = {};
  Map<String, dynamic>? defines;
  bool transparent = false,
      depthWrite = true,
      depthTest = true,
      colorWrite = true,
      visible = true,
      premultipliedAlpha = false,
      toneMapped = true,
      alphaToCoverage = false,
      polygonOffset = false,
      fog = false;
  int side = FrontSide, blending = NormalBlending;
  int? blendSrc = SrcAlphaFactor,
      blendDst = 205,
      blendSrcAlpha,
      blendDstAlpha,
      blendEquation = AddEquation,
      blendEquationAlpha;
  double opacity = 1,
      alphaTest = 0,
      rotation = 0,
      polygonOffsetFactor = 0,
      polygonOffsetUnits = 0;
  Color color = Color(1, 1, 1);
  TextureData? map, alphaMap;
  bool sizeAttenuation = true;
  MaterialData([Map<String, dynamic>? options]) {
    if (options != null) configure(options);
  }
  void configure(Map<String, dynamic> o) {
    name = o['name'] ?? name;
    vertexShader = o['vertexShader'];
    fragmentShader = o['fragmentShader'];
    uniforms = Map<String, dynamic>.from(o['uniforms'] ?? {});
    defines = o['defines'] == null
        ? null
        : Map<String, dynamic>.from(o['defines']);
    transparent = o['transparent'] ?? transparent;
    depthWrite = o['depthWrite'] ?? depthWrite;
    depthTest = o['depthTest'] ?? depthTest;
    colorWrite = o['colorWrite'] ?? colorWrite;
    visible = o['visible'] ?? visible;
    premultipliedAlpha = o['premultipliedAlpha'] ?? premultipliedAlpha;
    toneMapped = o['toneMapped'] ?? toneMapped;
    alphaToCoverage = o['alphaToCoverage'] ?? alphaToCoverage;
    polygonOffset = o['polygonOffset'] ?? polygonOffset;
    fog = o['fog'] ?? fog;
    sizeAttenuation = o['sizeAttenuation'] ?? sizeAttenuation;
    side = o['side'] ?? side;
    blending = o['blending'] ?? blending;
    blendSrc = o['blendSrc'] ?? blendSrc;
    blendDst = o['blendDst'] ?? blendDst;
    blendSrcAlpha = o['blendSrcAlpha'];
    blendDstAlpha = o['blendDstAlpha'];
    blendEquation = o['blendEquation'] ?? blendEquation;
    blendEquationAlpha = o['blendEquationAlpha'];
    opacity = (o['opacity'] as num?)?.toDouble() ?? opacity;
    alphaTest = (o['alphaTest'] as num?)?.toDouble() ?? alphaTest;
    rotation = (o['rotation'] as num?)?.toDouble() ?? rotation;
    polygonOffsetFactor = (o['polygonOffsetFactor'] as num?)?.toDouble() ?? 0;
    polygonOffsetUnits = (o['polygonOffsetUnits'] as num?)?.toDouble() ?? 0;
    if (o['color'] is Color) {
      color = o['color'];
    } else if (o['color'] is int) {
      color = Color.fromHex32(o['color']);
    }
    map = o['map'];
    alphaMap = o['alphaMap'];
  }
}

class ShaderData extends MaterialData {
  ShaderData.fromMap(super.options);
}

class UnlitData extends MaterialData {
  UnlitData([super.options]);
  UnlitData.fromMap(super.options);
}

class BillboardData extends MaterialData {
  BillboardData.fromMap(super.options);
}
