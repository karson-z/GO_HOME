import 'package:three_js/three_js.dart' as three;

/// ANGLE's Frustum.intersectsObject currently ignores InstancedMesh bounds.
/// Use the source Three.js object sphere, including every instance and its
/// original wind padding, before submitting the batch to that renderer.
class NativeSceneCulling {
  final _batches =
      <({three.InstancedMesh mesh, three.BoundingSphere sphere})>[];
  final _bounds =
      <({three.Mesh mesh, three.BoundingBox bounds, bool layerZero})>[];
  final _worldSphere = three.BoundingSphere();
  bool boundsEnabled = true;

  void add(three.InstancedMesh mesh, three.BoundingSphere sphere) {
    mesh.frustumCulled = false;
    _batches.add((mesh: mesh, sphere: sphere));
  }

  void addBounds(three.Mesh mesh, three.BoundingBox bounds) {
    final layerZero = mesh.layers.isEnabled(0);
    if (!layerZero) return;
    mesh.frustumCulled = false;
    _bounds.add((mesh: mesh, bounds: bounds, layerZero: layerZero));
  }

  void setBoundsEnabled(bool enabled) {
    boundsEnabled = enabled;
    for (final entry in _bounds) {
      entry.mesh.frustumCulled = !enabled;
      if (entry.layerZero) entry.mesh.layers.enable(0);
    }
  }

  void update(three.Frustum frustum) {
    if (boundsEnabled) {
      for (final entry in _bounds) {
        if (frustum.intersectsBox(entry.bounds)) {
          entry.mesh.layers.enable(0);
        } else {
          entry.mesh.layers.disable(0);
        }
      }
    }
    for (final batch in _batches) {
      _worldSphere.setFrom(batch.sphere).applyMatrix4(batch.mesh.matrixWorld);
      if (frustum.intersectsSphere(_worldSphere)) {
        batch.mesh.layers.enable(0);
      } else {
        batch.mesh.layers.disable(0);
      }
    }
  }
}
