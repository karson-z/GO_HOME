import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fs;

import 'scene_data.dart' as sd;

import 'native_boy_renderer.dart';
import 'native_puppet_renderer.dart';
import 'native_world_assets.dart';
import 'native_load_budget.dart';
import 'native_pipeline_warmup.dart';
import 'scene_compiler.dart';

/// Sole game renderer. Local scene data drives Flutter Scene GPU resources.
class FlutterSceneRenderer extends ChangeNotifier {
  FlutterSceneRenderer({
    required this.setup,
    required this.onSetupComplete,
    required this.onError,
  });
  final Future<void> Function() setup;
  final VoidCallback onSetupComplete;
  final void Function(Object, StackTrace) onError;
  final registry = SourceShaderLibrary();
  final boundaryKey = GlobalKey();
  Future<ui.Image> capture() =>
      (boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary)
          .toImage(pixelRatio: pixelRatio);
  final gpuScene = fs.Scene()
    ..antiAliasingMode = fs.AntiAliasingMode.none
    ..toneMapping = fs.ToneMappingMode.linear
    ..fitNearPlane = false
    ..reversedDepth = false
    ..maxGpuFramesInFlight = 2;
  sd.WorldScene scene = sd.WorldScene();
  sd.SceneCamera camera = sd.PerspectiveLens(28, 1, .5, 2000);
  SceneCompiler? _world;
  fs.Node? _worldRoot;
  fs.RenderView? _screenView;
  final _atlases = <sd.RenderSurface, _Atlas>{};
  final _preparingAtlasLayers = <int>{};
  final _callbacks = <void Function(double)>[];
  VoidCallback? beforeSceneRender;
  SourcePostprocess? post;
  double width = 1, height = 1, pixelRatio = 1.5;
  bool pause = false, ready = false, disposed = false;
  int renderedFrames = 0;
  int lastUpdateUs = 0, lastSubmitUs = 0;
  int pipelineWarmupUs = 0;
  Future<void>? _initializing;

  SceneCompiler get world => _world ??= SceneCompiler(registry, camera);
  void addAnimationEvent(void Function(double) callback) =>
      _callbacks.add(callback);
  void resize(ui.Size size) {
    width = size.width;
    height = size.height;
    if (camera is sd.PerspectiveLens) {
      (camera as sd.PerspectiveLens).aspect = width / height;
      camera.updateProjectionMatrix();
    }
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      await fs.Scene.initializeStaticResources();
      await registry.initialize();
      if (disposed) return;
      final warmupWatch = Stopwatch()..start();
      await warmRoutePipelines(registry);
      pipelineWarmupUs = warmupWatch.elapsedMicroseconds;
      if (disposed) return;
      await setup();
      if (disposed) return;
      _worldRoot = world.convert(scene);
      gpuScene.add(_worldRoot!);
      _screenView = fs.RenderView(camera: SourceCamera(camera), layerMask: 1);
      ready = true;
      onSetupComplete();
    } catch (error, stack) {
      if (!disposed) onError(error, stack);
    }
  }

  Future<SourcePostprocess> initializePostprocess(
    NativeWorldAssets assets,
  ) async {
    final result = SourcePostprocess(registry, assets, camera);
    await result.initialize();
    if (disposed) return result;
    gpuScene.addRenderPass(result);
    post = result;
    return result;
  }

  void registerChunk(NativeWorldChunk chunk) => world.registerChunk(chunk);

  /// Decode happens in the existing worker; GPU objects stay on the UI isolate.
  /// Prepare short batches and issue a real offscreen draw before exposing a chunk.
  Future<void> prepareChunk(NativeWorldChunk chunk) async {
    if (disposed) return;
    registerChunk(chunk);
    final node = await world.prepare(chunk.root, NativeLoadBudget());
    if (disposed) return;
    final frustum = world.frustum;
    world.frustum = null;
    world.sync();
    world.frustum = frustum;
    for (final material in registry.materials) {
      material.update();
    }
    final warm = fs.Scene()
      ..antiAliasingMode = fs.AntiAliasingMode.none
      ..toneMapping = fs.ToneMappingMode.linear
      ..fitNearPlane = false
      ..reversedDepth = false;
    warm.add(node);
    try {
      await warm.warmUp(
        [fs.RenderView(camera: SourceCamera(camera))],
        includeOffscreen: true,
        sliceBudget: const Duration(milliseconds: 2),
      );
    } finally {
      warm.remove(node);
      warm.dispose();
    }
  }

  /// Called after each rig finishes loading, before it can become visible.
  /// Its target identity also routes water reflections to the same fresh atlas.
  Future<void> registerBoy(NativeBoyRenderer rig) =>
      _registerAtlas(rig.target, rig.stage, rig.camera, rig.root);
  Future<void> registerPuppet(NativePuppetRenderer rig) =>
      _registerAtlas(rig.target, rig.stage, rig.camera, rig.root);
  Future<void> _registerAtlas(
    sd.RenderSurface target,
    sd.WorldScene stage,
    sd.SceneCamera camera,
    sd.SceneNode owner,
  ) async {
    if (disposed || _atlases.containsKey(target)) return;
    final used = {
      ..._atlases.values.map((a) => a.layer),
      ..._preparingAtlasLayers,
    };
    var layer = 2;
    while (used.contains(layer)) {
      layer <<= 1;
    }
    if (layer >= 1 << 61) throw StateError('Too many character atlas layers');
    final texture = fs.RenderTexture(
      width: target.width,
      height: target.height,
      linearColor: true,
    );
    _preparingAtlasLayers.add(layer);
    registry.renderTextures[target.texture] = texture;
    final bridge = SceneCompiler(registry, camera);
    final budget = NativeLoadBudget();
    late final fs.Node node;
    try {
      node = await bridge.prepare(stage, budget, layer: layer);
      // Prepare the world-facing sprite and rig subtree before attachment too.
      // Otherwise reconciliation builds every arriving character in one frame.
      await world.prepare(owner, budget);
    } catch (_) {
      registry.renderTextures.remove(target.texture);
      texture.dispose();
      rethrow;
    } finally {
      _preparingAtlasLayers.remove(layer);
    }
    if (disposed) {
      registry.renderTextures.remove(target.texture);
      texture.dispose();
      return;
    }
    node.visible = false;
    gpuScene.add(node);
    final view = fs.RenderView(
      camera: SourceCamera(camera),
      target: texture,
      layerMask: layer,
      order: -1,
    );
    gpuScene.views.add(view);
    _atlases[target] = _Atlas(
      owner,
      stage,
      camera,
      bridge,
      node,
      view,
      texture,
      layer,
    );
  }

  void update(double dt) {
    if (!ready || disposed || pause) return;
    final watch = Stopwatch()..start();
    try {
      for (final callback in _callbacks) {
        callback(dt);
      }
      beforeSceneRender?.call();
      world.reconcile(scene, _worldRoot!);
      world.sync();
      for (final entry in _atlases.entries.toList()) {
        final a = entry.value;
        var connected = false, visible = true;
        for (sd.SceneNode? p = a.owner; p != null; p = p.parent) {
          visible = visible && p.visible;
          if (identical(p, scene)) connected = true;
        }
        // Several rigs can be prepared before their shared parent is attached.
        // Keep them dormant until first attachment, then retire on removal.
        if (!connected && !a.wasConnected) continue;
        if (!connected) {
          gpuScene.views.remove(a.view);
          gpuScene.remove(a.node);
          a.texture.dispose();
          registry.renderTextures.remove(entry.key.texture);
          registry.materials.removeWhere(
            (m) => a.bridge.mapped.containsKey(m.object),
          );
          _atlases.remove(entry.key);
          continue;
        }
        a.wasConnected = true;
        a.node.visible = visible;
        if (!visible) continue;
        a.stage.updateMatrixWorld(true);
        a.camera.updateMatrixWorld(true);
        a.bridge.reconcile(a.stage, a.node, layer: a.layer);
        a.bridge.sync();
      }
      registry.viewport.setValues(width * pixelRatio, height * pixelRatio);
      for (final material in registry.materials) {
        material.update();
      }
      lastUpdateUs = watch.elapsedMicroseconds;
      notifyListeners();
    } catch (error, stack) {
      ready = false;
      onError(error, stack);
    }
  }

  void render(ui.Canvas canvas, ui.Size size) {
    if (!ready || disposed) return;
    final watch = Stopwatch()..start();
    try {
      gpuScene.renderViews(
        [_screenView!],
        canvas,
        region: ui.Offset.zero & size,
        pixelRatio: pixelRatio,
      );
      lastSubmitUs = watch.elapsedMicroseconds;
      if ((gpuScene.renderStats.latest?.counters.draws ?? 0) > 0) {
        renderedFrames++;
      }
    } catch (error, stack) {
      ready = false;
      scheduleMicrotask(() {
        if (!disposed) onError(error, stack);
      });
    }
  }

  Widget build() => _SceneSurface(renderer: this);
  @override
  void dispose() {
    disposed = true;
    for (final a in _atlases.values) {
      a.texture.dispose();
    }
    _atlases.clear();
    gpuScene.dispose();
    registry.materials.clear();
    registry.textures.clear();
    registry.renderTextures.clear();
    super.dispose();
  }
}

class _Atlas {
  _Atlas(
    this.owner,
    this.stage,
    this.camera,
    this.bridge,
    this.node,
    this.view,
    this.texture,
    this.layer,
  );
  final sd.SceneNode owner;
  final sd.WorldScene stage;
  final sd.SceneCamera camera;
  final SceneCompiler bridge;
  final fs.Node node;
  final fs.RenderView view;
  final fs.RenderTexture texture;
  final int layer;
  bool wasConnected = false;
}

class _SceneSurface extends StatefulWidget {
  const _SceneSurface({required this.renderer});
  final FlutterSceneRenderer renderer;
  @override
  State<_SceneSurface> createState() => _SceneSurfaceState();
}

class _SceneSurfaceState extends State<_SceneSurface>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  Duration? previous;
  @override
  void initState() {
    super.initState();
    ticker = createTicker((elapsed) {
      final dt = previous == null
          ? 0.0
          : (elapsed - previous!).inMicroseconds / 1e6;
      previous = elapsed;
      widget.renderer.update(dt.clamp(0.0, .1));
    })..start();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      widget.renderer.resize(constraints.biggest);
      unawaited(widget.renderer.initialize());
      return RepaintBoundary(
        key: widget.renderer.boundaryKey,
        child: CustomPaint(
          painter: _ScenePainter(widget.renderer),
          size: constraints.biggest,
          isComplex: true,
          willChange: true,
        ),
      );
    },
  );
  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.renderer) : super(repaint: renderer);
  final FlutterSceneRenderer renderer;
  @override
  void paint(ui.Canvas canvas, ui.Size size) => renderer.render(canvas, size);
  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.renderer != renderer;
}
