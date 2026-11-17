import 'package:three_js/three_js.dart' as three;

import 'native_load_budget.dart';
import 'native_world_assets.dart';

/// GL work stays on the renderer's context. A real draw is needed: compile()
/// alone leaves first-use pipeline work to the first visible frame.
class NativeGpuWarmup {
  NativeGpuWarmup(this.renderer, this.scene, this.camera, this.target);
  final three.AngleRenderer renderer;
  final three.Scene scene;
  final three.Camera Function() camera;
  final three.RenderTarget? Function() target;
  final _stage = three.Scene()..matrixWorldAutoUpdate = false;
  three.RenderTarget? _target;
  bool disposed = false;
  bool drawEnabled = const bool.fromEnvironment(
    'SCENE_DRAW_WARMUP',
    defaultValue: true,
  );
  void Function(String chunk, String node, int microseconds)? onDraw;

  Future<void> prepare(NativeWorldChunk chunk) async {
    final budget = NativeLoadBudget();
    final textures = <three.Texture>{};
    void texture(dynamic value) {
      if (value is three.Texture) textures.add(value);
      if (value is List) value.forEach(texture);
    }

    for (final material in chunk.materials) {
      texture(material.map);
      texture(material.alphaMap);
      for (final uniform in material.uniforms.values) {
        texture(uniform['value']);
      }
    }
    for (final texture in textures) {
      await budget.checkpoint();
      if (disposed) return;
      final previous = renderer.getRenderTarget();
      renderer.resetState();
      try {
        renderer.initTexture(texture);
      } finally {
        renderer.setRenderTarget(previous);
      }
    }
    for (final node in chunk.nodes) {
      if (node.geometry == null) continue;
      await budget.checkpoint();
      if (disposed) return;
      // The adapter exposes geometry/instance uploads independently of draw.
      renderer.objects.update(node);
      final previous = renderer.getRenderTarget();
      final autoClear = renderer.autoClear;
      try {
        final destination = target();
        // Some dormant source effects (for example DAWN_FOAM) deliberately
        // have unbound uniforms. Their owner must configure them before draw.
        final unbound =
            node.material?.uniforms.values.any(
              (uniform) => uniform['value'] == null,
            ) ??
            false;
        if (!drawEnabled || destination == null || unbound) {
          renderer.setRenderTarget(destination);
          renderer.compile(node, camera(), scene);
        } else {
          // Keep the exact attachment formats, depth and sample count. A small
          // viewport avoids doing a full-size scene render during preparation.
          _target ??= three.RenderTarget(
            16,
            16,
            three.RenderTargetOptions(
              destination.options.toJson()..remove('depthTexture'),
            )..stencilBuffer = destination.options.stencilBuffer,
          );
          // Presentation touches GL outside the renderer between event turns.
          renderer.resetState();
          renderer.setRenderTarget(_target);
          renderer.autoClear = false;
          renderer.clear();
          final watch = onDraw == null ? null : (Stopwatch()..start());
          drawNode(node);
          if (watch != null) {
            onDraw!(chunk.id, node.name, watch.elapsedMicroseconds);
          }
        }
      } finally {
        renderer.autoClear = autoClear;
        renderer.setRenderTarget(previous);
      }
    }
  }

  /// Borrow the node synchronously; never change its parent or world matrix.
  /// Render even hidden/out-of-view geometry, including instanced batches and
  /// the renderer's normal material-side passes. Restore every visibility bit.
  void drawNode(three.Object3D node) {
    final visible = node.visible, culled = node.frustumCulled;
    final layers = node.layers.mask;
    final children = [for (final child in node.children) child.visible];
    _stage.fog = scene.fog;
    _stage.environment = scene.environment;
    _stage.children.add(node);
    try {
      node.visible = true;
      node.frustumCulled = false;
      node.layers.mask = camera().layers.mask;
      for (final child in node.children) {
        child.visible = false;
      }
      renderer.render(_stage, camera());
    } finally {
      _stage.children.clear();
      node.visible = visible;
      node.frustumCulled = culled;
      node.layers.mask = layers;
      for (var i = 0; i < children.length; i++) {
        node.children[i].visible = children[i];
      }
    }
  }

  void dispose() {
    disposed = true;
    onDraw = null;
    _target?.dispose();
    _target = null;
  }
}
