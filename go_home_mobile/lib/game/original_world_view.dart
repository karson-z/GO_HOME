import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

import 'game_controller.dart';
import 'native_world_assets.dart';
import 'native_postprocess.dart';
import 'native_boy_renderer.dart';
import 'original_boy_motion.dart';
import 'native_render_order.dart';
import 'original_rhythm.dart';
import 'player_physics.dart';
import 'native_opening_view.dart';
import 'native_hedgehog_view.dart';
import 'native_puppet_renderer.dart';
import 'native_bat_view.dart';
import 'original_palette.dart';
import 'original_route_palette.dart';
import 'native_owl_view.dart';
import 'native_turtle_view.dart';
import 'original_turtle.dart';
import 'native_squirrel_view.dart';
import 'native_bear_view.dart';
import 'native_far_view.dart';
import 'native_woodpecker_view.dart';
import 'native_firefly_view.dart';
import 'original_firefly.dart';
import 'native_ending_view.dart';
import 'native_ending_flight_view.dart';
import 'original_ending_flight.dart';
import 'original_ending_look.dart';
import 'native_game_hints.dart';
import 'native_gpu_warmup.dart';

class OriginalWorldView extends StatefulWidget {
  const OriginalWorldView({super.key, required this.game});
  @visibleForTesting
  static void Function(three.ThreeJS)? configureRendererForTest;
  final GameController game;
  @override
  State<OriginalWorldView> createState() => _OriginalWorldViewState();
}

class _OriginalWorldViewState extends State<OriginalWorldView> {
  late final three.ThreeJS renderer;
  final assets = NativeWorldAssets();
  final Map<String, NativeWorldChunk> chunks = {};
  final Set<String> pending = {};
  final Set<Future<void>> loadingJobs = {};
  Future<void>? transition;
  NativeWorldChunk? global;
  NativePostprocess? post;
  NativeGpuWarmup? gpuWarmup;
  NativeBoyRenderer? boy;
  NativeOpeningView? openingView;
  NativeHedgehogView? hedgeView;
  NativeBatView? batView;
  NativeOwlView? owlView;
  NativeTurtleView? turtleView;
  NativeFireflyView? fireflyView;
  NativeSquirrelView? squirrelView;
  NativeBearView? bearView;
  NativeFarView? farView;
  NativeWoodpeckerView? woodpeckerView;
  NativeEndingView? endingView;
  NativeEndingFlightView? endingFlightView;
  NativeGameHints? hintsView;
  OriginalRoutePalette? routePalette;
  int paletteRevision = -1;
  double currentPaletteT = 0;
  final Map<int, NativePuppetRenderer> animals = {};
  bool disposed = false, ready = false;
  String? error;
  GameController get game => widget.game;

  @override
  void initState() {
    super.initState();
    renderer = three.ThreeJS(
      setup: setup,
      onSetupComplete: () {
        if (mounted) setState(() => ready = true);
      },
      settings: three.Settings(
        useSourceTexture: true,
        clearColor: 0x1d202a,
        enableShadowMap: false,
        screenResolution: 1.5,
        antialias: false,
        renderOptions: {'format': three.RGBAFormat, 'samples': 0},
      ),
    );
  }

  Future<void> setup() async {
    renderer.scene = three.Scene()..matrixAutoUpdate = false;
    renderer.camera = three.PerspectiveCamera(
      28,
      renderer.width / renderer.height,
      .5,
      2000,
    );
    try {
      OriginalWorldView.configureRendererForTest?.call(renderer);
      installSourceRenderOrder(renderer.renderer!);
      await assets.initialize();
      routePalette = OriginalRoutePalette(await OriginalPalette.load());
      global = await assets.load('_global');
      farView = NativeFarView(global!);
      if (disposed) {
        global!.dispose();
        return;
      }
      renderer.scene.add(global!.root);
      boy = await NativeBoyRenderer.load(assets.shared);
      if (disposed) {
        boy!.dispose();
        return;
      }
      renderer.scene.add(boy!.root);
      hintsView = await NativeGameHints.load();
      if (disposed) {
        hintsView!.dispose();
        return;
      }
      renderer.scene.add(hintsView!.root);
      openingView = NativeOpeningView();
      renderer.scene.add(openingView!.root);
      openingView!.attachLead(
        renderer.scene,
        (x) => assets.groundAt(global!, x),
      );
      applyQuality();
      game.camera!.aspect = renderer.width / renderer.height;
      game.camera!.snap(game.x, game.y);
      await stream(blocking: true);
      post = NativePostprocess(renderer, assets)
        ..sceneResolution = game.renderResolution;
      await post!.initialize();
      gpuWarmup = NativeGpuWarmup(
        renderer.renderer!,
        renderer.scene,
        () => renderer.camera,
        () => post?.sceneTarget,
      );
      assets.prepare = gpuWarmup!.prepare;
      // These chunks were constructed before the HDR target existed. Prepare
      // them under the loading screen too, rather than on the first play frame.
      for (final chunk in [global!, ...chunks.values]) {
        await gpuWarmup!.prepare(chunk);
        if (disposed) return;
      }
      post!.beforeSceneRender = (r) {
        boy?.renderParts(r);
        turtleView?.renderParts(r);
        bearView?.renderParts(r);
        fireflyView?.renderParts(r);
        endingView?.renderParts(r);
        for (final animal in animals.values) {
          animal.renderParts(r);
        }
        final frustum = viewFrustum();
        updateSceneVisibility(frustum);
        // Culling needs current matrices. Update once here; render() must not
        // traverse the entire world a second time. Static chunk roots retain
        // their matrices, while animated objects mark their own changes.
        renderer.scene.updateMatrixWorld();
        global?.culling.update(frustum);
        for (final chunk in chunks.values) {
          if (chunk.root.visible) chunk.culling.update(frustum);
        }
      };
      renderer.scene.matrixWorldAutoUpdate = false;
      renderer.postProcessor = post!.render;
      if (disposed) return;
      game.sceneReady();
    } catch (e, stack) {
      debugPrint('Original native scene: $e\n$stack');
      if (mounted) setState(() => error = e.toString());
    }
    renderer.addAnimationEvent(frame);
  }

  Future<void> loadChunk(String id) async {
    if (!pending.add(id)) return;
    try {
      final chunk = await assets.load(id);
      if (disposed) {
        chunk.dispose();
        return;
      }
      chunks[id] = chunk;
      if (id == 'dusk-hedgehog') hedgeView = NativeHedgehogView(chunk);
      if (id == 'cave-bat') batView = NativeBatView(chunk);
      if (id == 'night-owl') owlView = NativeOwlView(chunk);
      if (id == 'dusk-squirrel') {
        final view = await NativeSquirrelView.load(chunk);
        if (disposed) {
          view.dispose();
          return;
        }
        squirrelView?.dispose();
        squirrelView = view;
      }
      if (id == 'dawn-bear') {
        final view = await NativeBearView.load(
          chunk,
          renderer.scene,
          assets.shared,
        );
        if (disposed) {
          view.dispose();
          return;
        }
        bearView?.dispose();
        bearView = view;
      }
      if (id == 'dawn-woodpecker') woodpeckerView = NativeWoodpeckerView(chunk);
      renderer.scene.add(chunk.root);
      if (id == 'route-ending') {
        endingFlightView = NativeEndingFlightView(chunk);
        final view = await NativeEndingView.load(
          assets.shared,
          Map<String, dynamic>.from(game.route!.mechanisms['ending']),
        );
        if (disposed) {
          view.dispose();
          return;
        }
        endingView?.dispose();
        endingView = view;
        renderer.scene.add(view.root);
      }
      if (id == 'dusk-firefly') {
        final view = await NativeFireflyView.load(assets.shared);
        if (disposed) {
          view.dispose();
          return;
        }
        fireflyView?.dispose();
        fireflyView = view;
        for (final rig in view.rigs) {
          renderer.scene.add(rig.root);
        }
      }
      if (id == 'night-turtle') {
        final view = await NativeTurtleView.load(assets.shared);
        if (disposed) {
          view.dispose();
          return;
        }
        turtleView?.dispose();
        turtleView = view;
        for (final rig in view.rigs) {
          renderer.scene.add(rig.root);
        }
      }
    } catch (e, stack) {
      debugPrint('Source chunk $id: $e\n$stack');
      if (mounted) setState(() => error = '$id: $e');
    } finally {
      pending.remove(id);
    }
  }

  Future<void> stream({bool blocking = false}) async {
    final jobs = <Future<void>>[];
    final current = sceneIndex;
    // Start the next window while approaching a seam, not on the seam frame.
    // Two seconds of travel gives decode/upload time without retaining the
    // whole route. Visibility still uses the actual camera/current scene.
    final leadX = game.x + (game.vx * 2).clamp(-24.0, 24.0);
    final predictedIndex = assets.manifest.indexWhere(
      (meta) => leadX < (meta['x1'] as num),
    );
    final predicted = predictedIndex < 0
        ? assets.manifest.length - 1
        : predictedIndex;
    final frustum = viewFrustum();
    for (var index = 0; index < assets.manifest.length; index++) {
      final meta = assets.manifest[index];
      final id = meta['id'] as String;
      final distance = (index - current).abs();
      final chunk = chunks[id];
      final close =
          (index >= current - 1 && index <= current + 2) ||
          (index >= predicted - 1 && index <= predicted + 2) ||
          (chunk != null &&
              (index == 0 ||
                  distance <= 2 ||
                  distance <= 3 && chunk.intersectsView(frustum))) ||
          (id == 'W0' && (game.ending?.flightTime ?? -1) >= 0);
      if (close && !chunks.containsKey(id) && !pending.contains(id)) {
        jobs.add(loadChunk(id));
      }
      if (!close && chunks.containsKey(id)) {
        chunks.remove(id)!.dispose();
        if (id == 'dusk-hedgehog') hedgeView = null;
        if (id == 'cave-bat') batView = null;
        if (id == 'night-owl') owlView = null;
        if (id == 'dusk-squirrel') {
          squirrelView?.dispose();
          squirrelView = null;
        }
        if (id == 'dawn-bear') {
          bearView?.dispose();
          bearView = null;
        }
        if (id == 'dawn-woodpecker') woodpeckerView = null;
        if (id == 'route-ending') {
          endingView?.dispose();
          endingView = null;
          endingFlightView = null;
        }
        if (id == 'night-turtle') {
          turtleView?.dispose();
          turtleView = null;
        }
        if (id == 'dusk-firefly') {
          fireflyView?.dispose();
          fireflyView = null;
        }
      }
    }
    for (var i = 0; i < game.route!.segments.length; i++) {
      final segment = game.route!.segments[i];
      if (i == 8 ||
          i == 5 ||
          i == 0 ||
          segment.x0 > game.x + 45 ||
          segment.x1 < game.x - 45 ||
          animals.containsKey(i)) {
        continue;
      }
      // Assign a reservation before awaiting so frames do not load duplicate rigs.
      final key = 'animal:$i';
      if (!pending.add(key)) continue;
      jobs.add(() async {
        try {
          final kind = game.route!.segments[i].metadata(i).kind.name;
          final rig = await NativePuppetRenderer.load(
            kind,
            assets.shared,
            ppm: kind == 'squirrel' ? 320 * 1.5 : 280,
          );
          if (disposed) {
            rig.dispose();
            return;
          }
          animals[i] = rig;
          rig.root.position.setValues(
            segment.metadata(i).callerX,
            segment.metadata(i).callerY,
            .4,
          );
          final scale = switch (kind) {
            'firefly' => .8,
            'hedgehog' => 1.2,
            'squirrel' => 1.5,
            _ => 1.0,
          };
          rig.root.scale.setScalar(scale);
          renderer.scene.add(rig.root);
        } finally {
          pending.remove(key);
        }
      }());
    }
    for (final job in jobs) {
      loadingJobs.add(job);
      unawaited(job.whenComplete(() => loadingJobs.remove(job)));
    }
    if (blocking) await Future.wait(loadingJobs.toList());
  }

  int get sceneIndex {
    final index = assets.manifest.indexWhere(
      (meta) => game.x < (meta['x1'] as num),
    );
    return index < 0 ? assets.manifest.length - 1 : index;
  }

  three.Frustum viewFrustum() {
    renderer.camera.updateMatrixWorld(true);
    return three.Frustum()..setFromMatrix(
      three.Matrix4.identity()..multiply2(
        renderer.camera.projectionMatrix,
        renderer.camera.matrixWorldInverse,
      ),
    );
  }

  void updateSceneVisibility(three.Frustum frustum) {
    final current = sceneIndex;
    final flight = (game.ending?.flightTime ?? -1) >= 0;
    final returning = flight && (game.ending?.loopDown ?? false);
    for (var index = 0; index < assets.manifest.length; index++) {
      final meta = assets.manifest[index];
      final chunk = chunks[meta['id']];
      if (chunk == null) continue;
      final active = returning
          ? index == 0
          : index >= current - 1 && index <= current + 2;
      final shownCam = meta['shownCam'] as List?;
      final localCameraX = renderer.camera.position.x - (meta['ox'] as num);
      final shown =
          shownCam == null ||
          localCameraX >= (shownCam[0] as num) &&
              localCameraX <= (shownCam[1] as num);
      chunk.root.visible = flight
          ? (returning && index == 0) || meta['id'] == 'route-ending'
          : active
          ? shown
          : (index - current).abs() <= 3 && chunk.intersectsView(frustum);
      for (final root in chunk.root.children) {
        if (root.name == 'ATMOSPHERE') root.visible = active;
      }
      if (meta['id'] == 'W0') {
        for (final node in chunk.nodes) {
          if (node.name == 'POND_WATER') node.visible = !returning;
        }
      }
    }
  }

  dynamic uniform(String name) => assets.shared[name]?['value'];
  void number(String name, num value) {
    final u = assets.shared[name];
    if (u != null) u['value'] = value.toDouble();
  }

  void color(String name, List v) {
    final c = uniform(name) as three.Color?;
    c?.setRGB(
      (v[0] as num).toDouble(),
      (v[1] as num).toDouble(),
      (v[2] as num).toDouble(),
    );
  }

  void vector(String name, List<num> values) {
    final v = uniform(name);
    if (v is three.Vector2) {
      v.setValues(values[0].toDouble(), values[1].toDouble());
    }
    if (v is three.Vector3) {
      v.setValues(
        values[0].toDouble(),
        values[1].toDouble(),
        values[2].toDouble(),
      );
    }
    if (v is three.Vector4) {
      v.setValues(
        values[0].toDouble(),
        values[1].toDouble(),
        values[2].toDouble(),
        values[3].toDouble(),
      );
    }
  }

  void palette(Map<String, dynamic> p, double cameraX) {
    final shared = assets.shared;
    number('uTime', game.animationTime);
    const colors = {
      'uZenith': 'zenith',
      'uMid': 'mid',
      'uHorizon': 'horizon',
      'uFogCol': 'fog',
      'uLightCol': 'light',
      'uRimCol': 'rim',
    };
    for (final pair in colors.entries) {
      color(pair.key, p[pair.value]);
    }
    final layers = uniform('uLayerCol') as List;
    for (var i = 0; i < layers.length; i++) {
      final c = p['layers'][i] as List;
      (layers[i] as three.Vector3).setValues(c[0], c[1], c[2]);
    }
    const scalars = {
      'uMistDist': 'mistDist',
      'uRoadClean': 'roadClean',
      'uFarHz': 'farHz',
      'uSunrise': 'sunrise',
      'uFogLow': 'fogLow',
      'uGlowSoft': 'glowSoft',
      'uStars': 'stars',
    };
    for (final pair in scalars.entries) {
      number(pair.key, p[pair.value] as num);
    }
    vector('uSkyHalo', [p['bandPow'], p['bandK'], p['haloWide'], p['haloMid']]);
    vector('uRimCtl', [
      p['rimFloor'],
      p['grassTip'],
      p['rimLocal'],
      p['skyFill'],
    ]);
    vector('uGroundCtl', [
      p['groundSky'],
      p['grassPx'],
      2 *
          math.tan(28 * math.pi / 360) /
          (renderer.height * (renderer.settings.screenResolution ?? 1)),
    ]);
    final pose = game.camera!.pose;
    final pitch =
        5.5 * math.pi / 180 +
        math.atan2(
          pose.pos[1] - pose.look[1],
          math.sqrt(
            math.pow(pose.pos[0] - pose.look[0], 2) +
                math.pow(pose.pos[2] - pose.look[2], 2),
          ),
        );
    vector('uTilt', [math.cos(pitch), math.sin(pitch)]);
    final referenceRotation = three.Quaternion()
      ..setFromEuler(three.Euler(5.5 * math.pi / 180, 0, 0));
    three.Vector3 skyDirection(num x, num y) =>
        three.Vector3(
            (x * 2 - 1) * (16 / 9) * math.tan(28 * math.pi / 360),
            (1 - y * 2) * math.tan(28 * math.pi / 360),
            -1,
          )
          ..normalize()
          ..applyQuaternion(referenceRotation);
    final sun = skyDirection(p['sunX'], p['sunY']),
        moon = skyDirection(p['moonX'], p['moonY']);
    (uniform('uSunDir') as three.Vector3).setFrom(sun);
    (uniform('uMoonDir') as three.Vector3).setFrom(moon);
    final daylight = math
        .max(p['sunAmt'] as num, (p['glowAmt'] as num) * .6)
        .toDouble();
    final moonAmt = (p['moonAmt'] as num).toDouble();
    final moonMix = moonAmt / (moonAmt + daylight + .001);
    (uniform('uLightDir') as three.Vector3).setFrom(sun)
      ..lerp(moon, moonMix)
      ..normalize();
    number(
      'uLightAmt',
      math.max(math.max(daylight, moonAmt * .75 * (1 - p['veil'] * .6)), .22),
    );
    vector('uBodies', [
      p['sunAmt'],
      math.max(p['sunAmt'], p['glowAmt']),
      p['moonAmt'],
      p['veil'],
    ]);
    vector('uBodySize', [
      p['sunSize'] * (28 * math.pi / 180) * .32,
      p['moonSize'] * (28 * math.pi / 180) * .3,
      0,
    ]);
    vector('uFog', [
      p['fogDensity'],
      p['fogHeight'],
      assets.groundAt(global!, cameraX) - .4,
      1,
    ]);
    final glowPos = uniform('uGlowPos') as List,
        glowCol = uniform('uGlowCol') as List;
    final accent = p['accent'] as List;
    final soft = (p['glowSoft'] as num).toDouble();
    final darkness = (1 - (p['value'] as num) / 60).clamp(.15, 1.0);
    final defaultRadius = 2.6 + (6 - 2.6) * soft;
    final defaultGain = (.18 * darkness + .04) * (1 - soft) + .72 * soft;
    var radius = 0.0, gain = 0.0, weight = 0.0, dark = 0.0;
    for (final entry in routePalette!.sceneWeights.entries) {
      final chunk = chunks[entry.key];
      final local = chunk?.data['boyGlow'];
      radius += entry.value * (local?['r'] ?? defaultRadius);
      gain += entry.value * (local?['k'] ?? defaultGain);
      weight += entry.value;
      final zone = chunk?.data['darkZone'];
      if (zone != null && entry.value > .004) {
        dark = math.max(dark, entry.value);
        vector('uDarkX', [
          zone['x0'],
          zone['x1'],
          zone['fadeIn'],
          zone['fadeOut'],
        ]);
        number('uDarkMul', zone['mul']);
      }
    }
    number('uDarkK', dark);
    if (weight <= .004) {
      radius = defaultRadius;
      gain = defaultGain;
    } else {
      radius /= weight;
      gain /= weight;
    }
    (glowPos[0] as three.Vector4).setValues(game.x, game.y + .5, .3, radius);
    (glowCol[0] as three.Vector3).setValues(
      accent[0] * gain,
      accent[1] * gain,
      accent[2] * gain,
    );
    shared['uGlowN']['value'] = 1;
    for (final material in global!.materials) {
      if (material.uniforms.containsKey('uCloudAmt')) {
        material.uniforms['uCloudAmt']['value'] = p['cloud'];
      }
    }
  }

  void applyQuality() {
    assets.setQuality(game.quality);
    // Keep Angle's presentation texture stable. Scale the native scene and all
    // postprocess targets, then let the final pass fill the presentation target.
    post?.sceneResolution = game.renderResolution;
  }

  double streamClock = 0;
  void frame(double dt) {
    if (disposed || error != null || global == null) return;
    applyQuality();
    game.camera!.aspect = renderer.width / renderer.height;
    if (game.opening != null && !game.loading) {
      final menuX =
          2.5 +
          .25 * 2 * math.tan(14 * math.pi / 180) * 22 * game.camera!.aspect;
      game.camera!
        ..hold = (pos: [menuX, 12.4, 22.0], look: [menuX, 12.4, 0.0])
        ..holdSmooth = 0
        ..holdRelease = 10
        ..update(dt, game.x, game.y, 0, 1, true);
    }
    game.update(dt);
    if (game.loading && transition == null) {
      final revision = game.sceneRevision;
      transition = stream(blocking: true)
          .then((_) {
            if (!disposed && error == null && revision == game.sceneRevision) {
              game.sceneReady();
            }
          })
          .whenComplete(() => transition = null);
    }
    streamClock += dt;
    if (streamClock > .35) {
      streamClock = 0;
      unawaited(stream());
    }
    final openingMenu = game.mode == GameMode.menu && game.opening != null;
    final opening = game.opening;
    final openingShot = openingMenu || opening != null;
    final menuX =
        2.5 +
        .25 *
            2 *
            math.tan(14 * math.pi / 180) *
            22 *
            (renderer.width / renderer.height);
    final pose = openingShot
        ? (pos: [menuX, 12.4, 22.0], look: [menuX, 12.4, 0.0])
        : game.camera!.pose;
    renderer.camera.position.setValues(pose.pos[0], pose.pos[1], pose.pos[2]);
    renderer.camera.lookAt(
      three.Vector3(pose.look[0], pose.look[1], pose.look[2]),
    );
    farView?.update(pose.look[0]);
    final endSegment = game.route!.segments[8];
    endingFlightView?.update(
      game.endingState,
      renderer.camera,
      endSegment.ox,
      endSegment.oy,
    );
    for (final chunk in chunks.values) {
      chunk.updateLake(game.x);
      chunk.updateMist(
        pose.pos[0],
        assets.groundAt(global!, pose.pos[0]),
        pose.pos[2],
      );
    }
    final elapsed = game.isPlaying ? dt.clamp(0.0, .1) : 0.0;
    hedgeView?.update(game.hedgehogState, elapsed);
    owlView?.update(game.owlState, game.animationTime);
    final squirrelSegment = game.route!.segments[2];
    squirrelView?.update(
      game.squirrelState,
      animals[2],
      squirrelSegment.ox,
      squirrelSegment.oy,
      game.animationTime,
      elapsed,
      game.x,
    );
    if (routePalette != null) {
      var p = routePalette!.frame(
        (game.ending?.loopDown ?? false) ? 3.7 : game.x,
        pose.pos[0],
        elapsed,
        snap:
            paletteRevision != game.sceneRevision ||
            (game.ending?.loopDown ?? false),
        endingBar: game.ending?.bar ?? -4,
        impact: hedgeView?.bounce ?? -1,
      );
      final environment = OriginalEndingLook(
        Map<String, dynamic>.from(
          game.route!.mechanisms['ending']['environment'],
        ),
      );
      var endFade = 0.0;
      if ((p['paletteTime'] as num) >= .89875 - 1e-9 &&
          !(game.ending?.loopDown ?? false)) {
        final end = game.ending;
        var bar = end?.locked == true ? end!.bar : 0.0;
        if (end != null && !end.locked && game.localX > 2 + end.bear.x) {
          var lo = 0.0, hi = 26.0;
          for (var i = 0; i < 18; i++) {
            final mid = (lo + hi) / 2;
            if (end.rider(mid).x < game.localX) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
          bar = lo;
        }
        final target = routePalette!.local(
          'route-ending',
          .97,
          game.x,
          endingBar: bar,
        );
        final wind = p['wind'];
        p = environment.at({...p, ...target}, bar);
        p['wind'] = wind;
        endFade = environment.fade(bar);
      }
      final endChunk = chunks['route-ending'];
      if (endChunk != null) {
        final old = (p['layers'] as List)[1] as List;
        for (final mat in endChunk.materials) {
          final fade = mat.uniforms['uEgU'];
          if (fade != null) fade['value'] = endFade;
          final col = mat.uniforms['uEgOld']?['value'];
          if (col is three.Color) col.setRGB(old[0], old[1], old[2]);
        }
      }
      final end = game.ending;
      if (end != null && end.flightTime >= 0) {
        final t = end.flightTime;
        final grade = end.data['flight']['grade'] as Map;
        final blend =
            endingSmooth((t - 4) / .6) * (1 - endingSmooth((t - 9) / 3));
        for (final key in [
          'saturation',
          'contrast',
          'lift',
          'gain',
          'grain',
          'vignette',
          'bloom',
          'rays',
        ]) {
          p[key] =
              (p[key] as num) + ((grade[key] as num) - (p[key] as num)) * blend;
        }
      }
      paletteRevision = game.sceneRevision;
      palette(p, pose.look[0]);
      final wind = uniform('uWind');
      if (wind is three.Vector2) {
        final target = (p['wind'] as double).isNaN
            ? routePalette!.windAt(game.x)
            : p['wind'] as double;
        wind.x += (target - wind.x) * (1 - math.exp(-elapsed / 1.5));
      }
      post?.updatePalette(p, game.animationTime);
      for (final chunk in chunks.values) {
        chunk.updateBeams(
          pose.pos[0],
          (p['rays'] as num).toDouble(),
          uniform('uLightDir') as three.Vector3,
        );
      }
      final particles = global!.nodes.whereType<three.Points>();
      for (final node in particles) {
        if (node.name != 'PARTICLES') continue;
        final u = node.material!.uniforms;
        (u['uCam']['value'] as three.Vector3).setValues(
          pose.pos[0],
          pose.pos[1],
          0,
        );
        u['uMotes']['value'] = (p['motes'] as num) * .9;
        u['uPx']['value'] = (post!.height * .5) / math.tan(28 * math.pi / 360);
      }
      final t = (p['paletteTime'] as num).toDouble();
      currentPaletteT = t;
      boy?.setPaletteT(t);
      if (fireflyView != null) {
        final segment = game.route!.segments[0];
        final state =
            game.fireflyState ??
            OriginalFirefly(
              Map<String, dynamic>.from(game.route!.mechanisms['firefly']),
              game.scores,
            );
        fireflyView!.update(
          state,
          segment.ox,
          segment.oy,
          game.animationTime,
          t,
        );
      }
      if (turtleView != null) {
        final segment = game.route!.segments[5];
        final state =
            game.turtleState ??
            OriginalTurtle(
              Map<String, dynamic>.from(game.route!.mechanisms['turtle']),
            );
        final local = game.x - segment.ox;
        int? rider;
        for (final shell in state.shells) {
          if (game.grounded && (local - shell.x).abs() < 1) rider = shell.index;
        }
        turtleView!.update(state, segment.ox, segment.oy, elapsed, rider, t);
      }
      for (final animal in animals.values) {
        animal.setPaletteT(t);
      }
      batView?.update(
        game.batState,
        elapsed,
        game.x - game.route!.segments[3].ox,
        t,
      );
    }
    final returning = game.ending?.loopDown ?? false;
    boy?.root.visible = game.cinematic
        ? (returning || (game.ending!.boy.shown && game.ending!.flightTime < 0))
        : true;
    boy?.root.position.setValues(
      returning || openingMenu ? 3.28 : game.x,
      returning || openingMenu ? 10 : game.y,
      returning || openingMenu || opening != null
          ? .15 + _openingSmooth(opening?.rise ?? 0) * .25
          : game.cinematic
          ? game.ending!.boy.z
          : .55,
    );
    boy?.setFootY(game.y);
    boy?.root.scale.setValues(
      game.cinematic ? game.ending!.boy.face : game.facing,
      1,
      1,
    );
    boy?.pose(
      game.animationTime,
      speed: game.vx.abs(),
      airborne: !game.grounded,
      singing: game.heldNotes.isNotEmpty,
    );
    if (!game.cinematic) {
      final p = game.player;
      final platforms = game.platforms;
      double footGround(double x) {
        var y = assets.groundAt(global!, x);
        for (final platform in platforms) {
          if (platform.dynamic &&
              x >= platform.left &&
              x <= platform.right &&
              (platform.top - game.y).abs() <= .5 &&
              (platform.top - game.y).abs() < (y - game.y).abs()) {
            y = platform.top;
          }
        }
        return y;
      }

      boy?.poseOriginal(
        opening != null && game.mode != GameMode.paused && !game.loading
            ? dt.clamp(0.0, .1)
            : elapsed,
        BoyMotionInput(
          vx: p.vx,
          vy: p.vy,
          grounded: p.grounded,
          facing: p.facing,
          wind: p.wind,
          reach: p.reach,
          lean: p.lean,
          strain: p.strain,
          shake: p.shake,
        ),
        game.noteSerial,
        x: openingMenu ? 3.28 : game.x,
        y: openingMenu ? 10 : game.y,
        groundAt: footGround,
        revision: game.sceneRevision,
        jumpAir: p.jumpAir,
        inset: p.inset,
        live: platforms.any(
          (p) => p.dynamic && game.x >= p.left && game.x <= p.right,
        ),
      );
    }
    if (opening != null) {
      boy?.poseOpening(opening);
    } else if (openingMenu) {
      boy?.poseMenuSleep();
    }
    if (boy != null) openingView?.update(opening, boy!);
    if (game.cinematic) {
      final e = game.ending!;
      boy?.poseCinematic(
        returning ? 'sleep' : e.boy.cue.act,
        game.animationTime,
        e.boy.cue.k,
      );
    }
    endingView?.update(
      game.endingState,
      endSegment.ox,
      endSegment.oy,
      elapsed,
      game.animationTime,
      currentPaletteT,
      boyLandmarks: boy?.endingLandmarks() ?? const {},
    );
    if (boy != null) {
      openingView?.updateReturning(
        game.endingState,
        boy!,
        endSegment.ox,
        endSegment.oy,
      );
    }
    openingView?.applySize(
      renderer.camera,
      returning: returning && (game.endingState?.flightTime ?? 0) >= 14
          ? game.endingState
          : null,
    );
    openingView?.updateLead(elapsed, game.x, endingActive: game.cinematic);
    hintsView?.update(
      game,
      renderer.camera,
      renderer.width,
      renderer.height,
      endingView,
    );
    final guide = openingView?.lead;
    if (guide != null && guide.light > .02) {
      final glowPos = uniform('uGlowPos') as List;
      final glowCol = uniform('uGlowCol') as List;
      (glowPos[1] as three.Vector4).setValues(
        guide.position.x,
        guide.position.y,
        guide.position.z,
        2.6,
      );
      final color = three.Color.fromHex32(0xffd9a0).toLinear()
        ..lerpColors(
          three.Color.fromHex32(0xffd9a0).toLinear(),
          three.Color.fromHex32(0xdfe4f2).toLinear(),
          .12,
        );
      (glowCol[1] as three.Vector3).setValues(
        color.red * .45 * guide.light,
        color.green * .45 * guide.light,
        color.blue * .45 * guide.light,
      );
      assets.shared['uGlowN']['value'] = 2;
    }
    final bearSegment = game.route!.segments[6];
    final bearPlayer = PlayerState(
      game.x - bearSegment.ox,
      game.y - bearSegment.oy,
    )..grounded = game.grounded;
    final judge = game.judge;
    final keys = judge is OriginalMelodyJudge && judge.original.progress > 0
        ? judge.original.taps.map((tap) => tap.degree).toSet().length.toDouble()
        : 0.0;
    bearView?.update(
      game.bearState,
      animals[6],
      bearSegment.ox,
      bearSegment.oy,
      elapsed,
      girlX: game.x,
      girlY: game.y,
      girlOnBack: game.bearState?.onBack(bearPlayer) ?? false,
      keys: keys,
      paletteT: currentPaletteT,
    );
    final woodSegment = game.route!.segments[7];
    woodpeckerView?.update(
      game.woodpeckerState,
      animals[7],
      woodSegment.ox,
      woodSegment.oy,
      game.animationTime,
    );
    for (final entry in animals.entries) {
      final animal = entry.value;
      if (entry.key != 2 && entry.key != 6 && entry.key != 7) {
        animal.setWake(game.solved.contains(entry.key) ? 1 : 0);
      }
      if (entry.key == 1) {
        final s = game.route!.segments[1], h = game.hedgehogState;
        if (h != null) {
          animal.root.position.setValues(s.ox + h.hx, s.oy + h.hy, .15);
          animal.number('uFootY', s.oy + h.hy);
          final ball =
              h.mode == 'sleep' || h.mode == 'ball' || h.mode == 'roll';
          animal.setFrame('body', ball ? 'ball' : 'open');
          if (ball) {
            const diameter = .49, k = 1.2;
            final scale = diameter / (.8 * k);
            animal.pose(
              'body',
              rot: -(h.mode == 'sleep' ? 0 : h.ball.roll) / (.5 * diameter),
              sx: scale,
              sy: scale,
              y: diameter / (2 * k) - .4,
            );
          }
          animal.flip.scale.x = h.dir;
        }
      }
      if (entry.key == 3) {
        final s = game.route!.segments[3], b = game.batState;
        animal.root.position.setValues(
          s.ox + (b?.x ?? 9.6),
          s.oy + (b?.y ?? 3.55),
          .6,
        );
        animal.setWake((b?.stage ?? 0) / 2);
      }
      if (entry.key == 4) {
        final s = game.route!.segments[4], o = game.owlState;
        if (o != null) {
          animal.root.position.setValues(s.ox + o.pos.x, s.oy + o.pos.y, -.35);
          animal.number('uFootY', s.oy + o.pos.y);
          animal.setWake(o.stage / 2);
          animal.flip.scale.x = game.x >= s.ox + o.pos.x ? 1 : -1;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      renderer.build(),
      if ((!ready || game.loading) && game.startup == null)
        const IgnorePointer(
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: Color(0xffeee7d6),
            ),
          ),
        ),
      if (error != null)
        ColoredBox(
          color: const Color(0xff20242d),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '原版场景加载未完成\n$error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    disposed = true;
    gpuWarmup?.dispose();
    hintsView?.dispose();
    openingView?.dispose();
    boy?.dispose();
    turtleView?.dispose();
    fireflyView?.dispose();
    squirrelView?.dispose();
    endingView?.dispose();
    bearView?.dispose();
    for (final rig in animals.values) {
      rig.dispose();
    }
    for (final chunk in chunks.values) {
      chunk.dispose();
    }
    global?.dispose();
    post?.dispose();
    assets.dispose();
    renderer.dispose();
    super.dispose();
  }
}

double _openingSmooth(double t) => t * t * (3 - 2 * t);
