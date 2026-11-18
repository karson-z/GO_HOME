import 'scene_data.dart' as sd;

/// Preserve authored fractional draw ordering in the scene compiler.
num sourceRenderOrder(sd.SceneNode? object, int fallback) =>
    object?.userData['sourceRenderOrder'] as num? ?? fallback;
