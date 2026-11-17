import 'package:three_js/three_js.dart' as three;

/// ANGLE's Frustum.intersectsObject currently ignores InstancedMesh bounds.
/// Use the source Three.js object sphere, including every instance and its
/// original wind padding, before submitting the batch to that renderer.
class NativeSceneCulling {
  final _batches =
      <({three.InstancedMesh mesh, three.BoundingSphere sphere})>[];
  final _worldSphere = three.BoundingSphere();

  void add(three.InstancedMesh mesh, three.BoundingSphere sphere) {
    mesh.frustumCulled = false;
    _batches.add((mesh: mesh, sphere: sphere));
  }

  void update(three.Frustum frustum) {
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
