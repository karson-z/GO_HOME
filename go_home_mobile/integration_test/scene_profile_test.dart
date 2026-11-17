import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' as io;
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ffi/ffi.dart';
import 'package:three_js/three_js.dart' as three;

import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/native_gpu_warmup.dart';
import 'package:go_home_mobile/game/native_world_assets.dart';

import 'support/render_diagnostics.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('profile scene seams on native hardware', (tester) async {
    const diagnostics = bool.fromEnvironment('PROFILE_DIAGNOSTICS');
    const focus = bool.fromEnvironment('PROFILE_DIAGNOSTIC_FOCUS');
    RenderDiagnostics? glTrace;
    if (diagnostics) {
      OriginalWorldView.configureRendererForTest = (native) {
        final context = RenderDiagnostics(native.gl!);
        glTrace = context;
        native.renderTarget?.dispose();
        native.renderer!.dispose();
        native.gl = context;
        native.initRenderer();
        context.initializeGpuTimer();
      };
    }
    addTearDown(() {
      OriginalWorldView.configureRendererForTest = null;
    });
    const smoke = bool.fromEnvironment('PROFILE_SMOKE');
    const allowDebug = bool.fromEnvironment('PROFILE_ALLOW_DEBUG');
    expect(
      kProfileMode || allowDebug,
      isTrue,
      reason:
          'Performance baseline requires flutter drive --profile on hardware',
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    final game = GameController(
      await ScoreLibrary.load(),
      route: await OriginalRoute.load(),
    )..start();
    game.quality = const String.fromEnvironment(
      'PROFILE_QUALITY',
      defaultValue: 'high',
    );
    game.x = 54;
    game.camera!.snap(game.x, game.y);
    await tester.pumpWidget(GoHomeApp(game: game));
    Future<void> waitUntil(bool Function() ready, int seconds) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (!ready() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(ready(), isTrue, reason: 'Native scene timed out');
      expect(tester.takeException(), isNull);
    }

    await waitUntil(() => !game.loading, 120);
    final dynamic view = tester.state(find.byType(OriginalWorldView));
    final three.ThreeJS native = view.renderer;
    final manifest = view.assets.manifest as List;
    final frames = <Map<String, Object?>>[];
    final changes = <Map<String, Object?>>[];
    final flutterFrames = <Map<String, num>>[];
    final clock = Stopwatch()..start();
    final warmupDraws = <Map<String, Object?>>[];
    final renderChecks = <Map<String, Object?>>[];
    view.gpuWarmup.onDraw = (String chunk, String node, int micros) {
      warmupDraws.add({
        'tUs': clock.elapsedMicroseconds,
        'vmTUs': developer.Timeline.now,
        'chunk': chunk,
        'node': node,
        'durationUs': micros,
      });
    };
    final cpuOriginUs = developer.Timeline.now;
    var presentUs = 0, activateUs = 0;
    Map<String, Object?> renderDetails = {};
    final stageTimes = <String, int>{};
    double? resolutionOverride;
    if (diagnostics) {
      native.renderer!.info.autoReset = false;
      view.post.onProfileStage = (String stage, int micros) {
        stageTimes[stage] = micros;
        const order = [
          'charactersAndCulling',
          'world',
          'guard',
          'bloomExtract',
          'bloomBlur',
          'bloomComposite',
          'grade',
          'final',
        ];
        final index = order.indexOf(stage);
        glTrace!.phase = index + 1 < order.length ? order[index + 1] : 'final';
      };
      native.customRenderer = (scene, camera, texture, [dt]) async {
        if (native.sourceTexture == null) {
          native.angle!.activateTexture(texture);
        }
        native.rendererUpdate?.call();
        native.postProcessor!.call(dt);
        var t = developer.Timeline.now;
        if (native.sourceTexture != null) {
          native.angle!.activateTexture(texture);
        }
        activateUs = developer.Timeline.now - t;
        t = developer.Timeline.now;
        await native.angle!.updateTexture(texture, native.sourceTexture);
        presentUs = developer.Timeline.now - t;
      };
    }
    String? window;
    double targetX = game.x, velocity = 0;
    var previousUs = 0, updateUs = 0, renderUs = 0, lastState = '';
    Map<String, Object?>? row;
    final event = native.events.first;
    final render = native.postProcessor!;
    native.events[0] = (double dt) {
      final begin = clock.elapsedMicroseconds;
      if (window != null) {
        if (previousUs != 0) {
          row = {
            'tUs': begin,
            if (diagnostics) 'vmTUs': developer.Timeline.now,
            'window': window,
            'x': targetX,
            'intervalUs': begin - previousUs,
            'updateUs': updateUs,
            'renderSubmitUs': renderUs,
            'loading': game.loading,
            'scene': view.sceneIndex,
            if (diagnostics) ...{
              'presentUs': presentUs,
              'activateUs': activateUs,
              'renderDetails': renderDetails,
            },
          };
          frames.add(row!);
        }
        targetX += velocity * dt.clamp(0, .1);
        // Scripted travel bypasses puzzles while keeping the actual game,
        // camera, audio, streaming and rendering loops active.
        game.x = targetX;
        game.y = view.assets.groundAt(view.global, targetX) as double;
        game.vx = velocity;
        game.vy = 0;
        game.player.safeX = game.x;
        game.player.safeY = game.y;
        game.camera!.hold = null;
        final state =
            '${view.chunks.keys.toList()..sort()}|${view.pending.toList()..sort()}';
        if (state != lastState) {
          changes.add({
            'tUs': begin,
            'window': window,
            'x': targetX,
            'state': state,
          });
          lastState = state;
        }
      }
      event(dt);
      updateUs = clock.elapsedMicroseconds - begin;
      previousUs = window == null ? 0 : begin;
    };
    native.postProcessor = ([double? dt]) {
      if (diagnostics) {
        glTrace!.window = window;
        glTrace!.beginFrame();
        native.renderer!.info.reset();
        stageTimes.clear();
        if (resolutionOverride != null) {
          view.post.sceneResolution = resolutionOverride;
        }
      }
      final start = clock.elapsedMicroseconds;
      render(dt);
      renderUs = clock.elapsedMicroseconds - start;
      if (diagnostics) {
        renderDetails = {
          ...glTrace!.endFrame(),
          'stages': Map<String, int>.of(stageTimes),
          'drawCalls': native.renderer!.info.render['calls'],
          'triangles': native.renderer!.info.render['triangles'],
          'programs': (native.renderer!.info.programs as List).length,
          'resolution': [view.post.width, view.post.height],
        };
      }
    };
    void timings(List<ui.FrameTiming> batch) {
      if (window == null) return;
      for (final frame in batch) {
        flutterFrames.add({
          'vsyncUs': frame.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          'buildUs': frame.buildDuration.inMicroseconds,
          'rasterUs': frame.rasterDuration.inMicroseconds,
          'totalUs': frame.totalSpan.inMicroseconds,
        });
      }
    }

    binding.addTimingsCallback(timings);
    final boundaries = manifest
        .skip(1)
        .map((m) => (m['x0'] as num).toDouble())
        .toList();
    if (diagnostics) {
      boundaries.removeWhere(
        (x) => !(focus ? [614.85] : [64.0, 222.2, 614.85, 666.85]).any(
          (v) => (x - v).abs() < .01,
        ),
      );
    }
    if (smoke) boundaries.removeRange(1, boundaries.length);
    var completedWindows = 0;
    final expectedWindows = boundaries.length * 2 + (diagnostics ? 3 : 0);
    Map<String, Object?> metadata() => {
      'buildMode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug-smoke',
      'baseline':
          kProfileMode &&
          !smoke &&
          !diagnostics &&
          completedWindows == expectedWindows,
      'diagnostics': diagnostics,
      'drawWarmup': view.gpuWarmup.drawEnabled,
      'cpuOriginUs': cpuOriginUs,
      'completedWindows': completedWindows,
      'expectedWindows': expectedWindows,
      'platform': io.Platform.operatingSystem,
      'os': io.Platform.operatingSystemVersion,
      'quality': game.quality,
      'renderResolution': game.renderResolution,
      'logicalWidth': native.width,
      'logicalHeight': native.height,
      'physicalWidth': view.post.width,
      'physicalHeight': view.post.height,
      'refreshRate':
          ui.PlatformDispatcher.instance.views.first.display.refreshRate,
      'method': 'Actual renderer event intervals; scripted 3.4 units/s travel through each seam +/-10; prep excluded. Render submission is CPU wall time, not GPU timing. Flutter raster timing alone does not measure ANGLE drawing.',
    };
    void checkpoint(String activeWindow) {
      completedWindows++;
      final windowFrames = frames
          .where((f) => f['window'] == activeWindow)
          .toList();
      // Output outside the measured interval; no per-frame logging or captures.
      debugPrint('PROFILE_WINDOW $activeWindow ${windowFrames.length} frames');
      // Android log lines have a size limit. Chunk each checkpoint so a
      // disconnect cannot erase all the completed measurement windows.
      final checkpoint = base64Encode(
        utf8.encode(
          jsonEncode({
            ...metadata(),
            'frames': windowFrames,
            'streamEvents': changes
                .where((f) => f['window'] == activeWindow)
                .toList(),
            'summary': summarize(windowFrames),
          }),
        ),
      );
      // Flutter's Android stdout bridge truncates below logcat's own limit.
      const chunkSize = 600;
      final parts = (checkpoint.length / chunkSize).ceil();
      for (var part = 0; part < parts; part++) {
        debugPrintSynchronously(
          'PROFILE_CHECKPOINT $completedWindows ${part + 1}/$parts '
          '${checkpoint.substring(part * chunkSize, math.min((part + 1) * chunkSize, checkpoint.length))}',
        );
      }
    }

    if (diagnostics) debugPrintSynchronously('PROFILE_READY ${io.pid}');
    try {
      for (final direction in [1, -1]) {
        for (final seam in direction > 0 ? boundaries : boundaries.reversed) {
          window = null;
          game.enterLevel(game.route!.segmentAt(seam - direction * 10));
          targetX = seam - direction * 10;
          game.x = targetX;
          game.y = view.assets.groundAt(view.global, targetX) as double;
          game.camera!.snap(targetX, game.y);
          await view.stream(blocking: true);
          game.sceneReady();
          await Future<void>.delayed(const Duration(seconds: 1));
          previousUs = 0;
          lastState = '';
          window = '${direction > 0 ? 'forward' : 'return'}:$seam';
          velocity = direction * 3.4;
          final activeWindow = window;
          await waitUntil(() => direction * (targetX - seam) >= 10, 45);
          window = null;
          checkpoint(activeWindow);
        }
      }
      if (diagnostics) {
        for (final variant in [
          'steadyHigh',
          'steadyHalfPixels',
          'steadyHighRepeat',
        ]) {
          window = null;
          velocity = 0;
          targetX = 615;
          game.enterLevel(game.route!.segmentAt(targetX));
          game.x = targetX;
          game.y = view.assets.groundAt(view.global, targetX) as double;
          game.camera!.snap(targetX, game.y);
          await view.stream(blocking: true);
          game.sceneReady();
          resolutionOverride = variant == 'steadyHalfPixels' ? .75 : 1.5;
          await Future<void>.delayed(const Duration(seconds: 3));
          previousUs = 0;
          window = '$variant:615.0';
          await Future<void>.delayed(const Duration(seconds: 6));
          final active = window;
          window = null;
          checkpoint(active);
        }
      }
      // Readbacks are outside measurement windows. Re-render a frozen state
      // with a forced full matrix update, then compare to the optimized path.
      final output = native.renderTarget!;
      Uint8List pixels() {
        final length = output.width * output.height * 4;
        if (!io.Platform.isAndroid) {
          final buffer = Uint8List(length);
          native.renderer!.readRenderTargetPixels(
            output,
            0,
            0,
            output.width,
            output.height,
            buffer,
          );
          return buffer;
        }
        // The adapter's Android upload pool does not copy read results back
        // into ordinary Dart views. Read directly into owned native memory,
        // through the same GLES library as the renderer (not system GLES).
        final library = ffi.DynamicLibrary.open(
          native.gl!.gl.useAngle ? 'libGLESv2_angle.so' : 'libGLESv3.so',
        );
        final read = library
            .lookupFunction<
              ffi.Void Function(
                ffi.Int32,
                ffi.Int32,
                ffi.Int32,
                ffi.Int32,
                ffi.Uint32,
                ffi.Uint32,
                ffi.Pointer<ffi.Void>,
              ),
              void Function(int, int, int, int, int, int, ffi.Pointer<ffi.Void>)
            >('glReadPixels');
        final error = library
            .lookupFunction<ffi.Uint32 Function(), int Function()>(
              'glGetError',
            );
        final allocation = calloc<ffi.Uint8>(length);
        try {
          native.renderer!.resetState();
          native.renderer!.setRenderTarget(output);
          error();
          read(
            0,
            0,
            output.width,
            output.height,
            0x1908,
            0x1401,
            allocation.cast(),
          );
          expect(error(), 0, reason: 'Native RGBA readback GL error');
          return Uint8List.fromList(allocation.asTypedList(length));
        } finally {
          calloc.free(allocation);
        }
      }

      void checkPixels(String name, Uint8List a, Uint8List b) {
        var differences = 0, maxDelta = 0;
        for (var i = 0; i < a.length; i++) {
          final delta = (a[i] - b[i]).abs();
          if (delta > 0) differences++;
          maxDelta = math.max(maxDelta, delta);
        }
        renderChecks.add({
          'name': name,
          'channels': a.length,
          'differentChannels': differences,
          'maxDelta': maxDelta,
        });
        expect(
          a.any((v) => v > 0 && v < 255),
          isTrue,
          reason: 'Readback must contain rendered image data',
        );
        expect(maxDelta, lessThanOrEqualTo(1), reason: name);
      }

      native.postProcessor!();
      final optimized = pixels();
      native.scene.updateMatrixWorld(true);
      native.scene.matrixWorldAutoUpdate = true;
      native.postProcessor!();
      native.scene.matrixWorldAutoUpdate = false;
      checkPixels('incremental versus forced matrices', optimized, pixels());

      final boundedChunks = <NativeWorldChunk>[
        view.global,
        ...view.chunks.values,
      ];
      final imageWithBounds = pixels();
      for (final chunk in boundedChunks) {
        chunk.culling.setBoundsEnabled(false);
      }
      native.postProcessor!();
      checkPixels(
        'world bounds culling preserves image',
        imageWithBounds,
        pixels(),
      );
      for (final chunk in boundedChunks) {
        chunk.culling.setBoundsEnabled(true);
      }
      native.postProcessor!();

      // Exercise warmup on an already-visible mesh. It must neither reparent
      // the mesh nor write into the displayed framebuffer.
      final NativeWorldChunk chunk = view.chunks.values.first;
      final node = chunk.nodes.firstWhere(
        (n) =>
            n.geometry != null &&
            n.material is three.ShaderMaterial &&
            n.material!.uniforms.values.every((u) => u['value'] != null),
      );
      final parent = node.parent;
      final visible = node.visible, culled = node.frustumCulled;
      final layers = node.layers.mask;
      final probe = NativeWorldChunk('readback-probe', {})..nodes.add(node);
      final warmup = NativeGpuWarmup(
        native.renderer!,
        native.scene,
        () => native.camera,
        () => view.post.sceneTarget as three.RenderTarget,
      );
      final beforeWarmup = pixels();
      await warmup.prepare(probe);
      // A single prepared node only crosses microtask checkpoints, so the
      // game frame cannot advance between these two display-target reads.
      expect(node.parent, same(parent));
      expect(node.visible, visible);
      expect(node.frustumCulled, culled);
      expect(node.layers.mask, layers);
      checkPixels('warmup preserves displayed target', beforeWarmup, pixels());
      warmup.dispose();
    } finally {
      window = null;
      glTrace?.collectGpu();
      native.events[0] = event;
      native.postProcessor = render;
      binding.removeTimingsCallback(timings);
      binding.reportData = {
        ...metadata(),
        'summary': summarize(frames),
        'frames': frames,
        'streamEvents': changes,
        'flutterFrames': flutterFrames,
        'warmupDraws': warmupDraws,
        'renderChecks': renderChecks,
        'cpuEndUs': developer.Timeline.now,
        if (diagnostics) ...{
          'glSlowCalls': glTrace!.slowCalls,
          'gpuSamples': glTrace!.gpuSamples,
          'gpuTimerUnavailable': glTrace!.gpuUnavailable,
          'gpuTimerNote': 'Asynchronous EXT timer, 32-bit nanoseconds; disjoint samples discarded. Includes idle gaps between commands, not a GPU utilization counter.',
        },
      };
    }
    expect(view.error, isNull);
    expect(frames.length, greaterThan(20));
    expect(frames.every((f) => f['renderSubmitUs'] != null), isTrue);
    if (diagnostics) {
      view.post.onProfileStage = null;
      native.customRenderer = null;
      native.renderer!.info.autoReset = true;
      glTrace!.disposeDiagnostics();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 18)));
}

List<Map<String, Object?>> summarize(List<Map<String, Object?>> frames) {
  final groups = <String, List<Map<String, Object?>>>{};
  for (final f in frames) {
    (groups[f['window'] as String] ??= []).add(f);
  }
  double percentile(List<double> sorted, double q) =>
      sorted[math.min(sorted.length - 1, (sorted.length * q).floor())];
  return [
    for (final group in groups.entries)
      () {
        final intervals = [
          for (final f in group.value) (f['intervalUs'] as int) / 1000,
        ]..sort();
        final renders = [
          for (final f in group.value)
            (f['renderSubmitUs'] as num? ?? 0) / 1000,
        ]..sort();
        return <String, Object?>{
          'window': group.key,
          'frames': intervals.length,
          'p50Ms': percentile(intervals, .5),
          'p95Ms': percentile(intervals, .95),
          'p99Ms': percentile(intervals, .99),
          'maxMs': intervals.last,
          'over20Ms': intervals.where((ms) => ms > 20).length,
          'over34Ms': intervals.where((ms) => ms > 34).length,
          'renderP95Ms': percentile(renders, .95),
          'renderMaxMs': renders.last,
        };
      }(),
  ];
}
