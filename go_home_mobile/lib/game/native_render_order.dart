import 'package:three_js/three_js.dart' as three;

/// three_js Object3D.renderOrder is int; original Three.js uses floating point.
/// Preserve source fractions without rounding the water wake into another layer.
num sourceRenderOrder(three.Object3D? object, int fallback) =>
    object?.userData['sourceRenderOrder'] as num? ?? fallback;

int sourceTransparentSort(dynamic a, dynamic b) {
  final int group = (a.groupOrder as int).compareTo(b.groupOrder as int);
  if (group != 0) return group;
  final order =
      sourceRenderOrder(
        a.object as three.Object3D?,
        a.renderOrder as int,
      ).compareTo(
        sourceRenderOrder(b.object as three.Object3D?, b.renderOrder as int),
      );
  if (order != 0) return order;
  final int depth = (b.z as double).compareTo(a.z as double);
  if (depth != 0) return depth;
  return (a.id as int).compareTo(b.id as int);
}

void installSourceRenderOrder(three.Renderer renderer) {
  // ANGLE's API is present in the native renderer, but omitted by Renderer.
  (renderer as dynamic).setTransparentSort(sourceTransparentSort);
}
