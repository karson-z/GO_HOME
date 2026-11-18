import 'scene_data.dart' as sd;

/// Cull authored batches with bounds that include all instances and wind padding.
/// Visibility feeds the Flutter Scene compiler before command submission.
class NativeSceneCulling {
  final _batches = <({sd.InstanceMesh mesh, sd.SphereBounds sphere})>[];
  final _bounds = <({sd.DrawMesh mesh, sd.BoxBounds bounds, bool layerZero})>[];
  final _worldSphere = sd.SphereBounds();
  bool boundsEnabled = true;

  void add(sd.InstanceMesh mesh, sd.SphereBounds sphere) {
    mesh.frustumCulled = false;
    _batches.add((mesh: mesh, sphere: sphere));
  }

  void addBounds(sd.DrawMesh mesh, sd.BoxBounds bounds) {
    final layerZero = mesh.layers.isEnabled(0);
    if (!layerZero) return;
    mesh.frustumCulled = false;
    _bounds.add((mesh: mesh, bounds: bounds, layerZero: layerZero));
  }

  /// Animated effects cannot use the world bounds captured at export time.
  /// Restore source visibility control when the owner takes over their motion.
  void removeBounds(sd.DrawMesh mesh) {
    _bounds.removeWhere((entry) => identical(entry.mesh, mesh));
    mesh.layers.enable(0);
    mesh.frustumCulled = false;
  }

  void setBoundsEnabled(bool enabled) {
    boundsEnabled = enabled;
    for (final entry in _bounds) {
      entry.mesh.frustumCulled = !enabled;
      if (entry.layerZero) entry.mesh.layers.enable(0);
    }
  }

  void update(sd.ViewFrustum frustum) {
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
