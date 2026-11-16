import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/ui/transparent_game_input.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:go_home_mobile/game/native_firefly_light.dart';
import 'package:go_home_mobile/game/native_game_hints.dart';
import 'package:go_home_mobile/game/original_firefly_light.dart';
import 'package:go_home_mobile/game/audio_engine.dart';
import 'package:go_home_mobile/game/native_ending_view.dart';
import 'package:go_home_mobile/game/native_puppet_renderer.dart';
import 'package:go_home_mobile/game/original_puppet_rig.dart';
import 'package:three_js/three_js.dart' as three;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('source generated scenes render on native GLES', (tester) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    final game = GameController(
      await ScoreLibrary.load(),
      route: await OriginalRoute.load(),
    )..prepareOpening();
    await tester.pumpWidget(GoHomeApp(game: game));
    while (game.loading) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    final dynamic appState = tester.state(find.byType(GoHomeApp));
    final GameAudio audio = appState.audio;
    final audioDeadline = DateTime.now().add(const Duration(seconds: 60));
    while (!audio.routeAudio.ready &&
        audio.routeAudio.error == null &&
        DateTime.now().isBefore(audioDeadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(audio.error, isNull);
    expect(audio.routeAudio.error, isNull);
    expect(audio.routeAudio.ready, isTrue, reason: 'Native PCM bank must load');
    final dynamic openingView = tester.state(find.byType(OriginalWorldView));
    final three.ThreeJS openingNative = openingView.renderer;
    await verifyFireflyShader(openingNative.renderer!);
    for (final age in [1.5, 4.5, 6.95]) {
      game.opening!.time = age;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await captureNative(openingNative, 'opening-$age');
      expect(openingView.boy.root.position.x, closeTo(3.28, 1e-6));
      verifyOpeningSkeleton(openingView.boy);
      final light = openingView.openingView.light;
      expect(light.glow.material, isA<three.ShaderMaterial>());
      expect(
        light.glow.material.fragmentShader,
        NativeFireflyLight.fragmentShader,
      );
      expect(light.texture.image.data.length, 64 * 64 * 4);
      final size = originalFireflySize(
        distance: light.root.position.distanceTo(openingNative.camera.position),
        glow: openingView.openingView.glowValue as double,
      );
      expect(light.glow.scale.x, Float32List.fromList([size.glow])[0]);
      expect(light.core.scale.x, Float32List.fromList([size.core])[0]);
      expect(light.glow.material.depthTest, isFalse);
      expect(light.glow.material.blending, three.AdditiveBlending);
      expect(tester.takeException(), isNull);
    }
    game.beginJourney();
    expect(game.opening, isNotNull);
    for (final age in [.4, 1.4, 2.8, 4.3]) {
      game.opening!.time = game.opening!.goAt! + age;
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await captureNative(openingNative, 'waking-$age');
      verifyOpeningSkeleton(openingView.boy);
      if (age == 1.4) {
        game.pause();
        final bones = <String, List<double>>{
          for (final e in openingView.boy.runtime.rig.joints.entries)
            e.key as String: [
              e.value.x as double,
              e.value.y as double,
              e.value.rot as double,
            ],
        };
        for (var pauseFrame = 0; pauseFrame < 4; pauseFrame++) {
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        for (final e in bones.entries) {
          final joint = openingView.boy.runtime.rig.joints[e.key];
          expect([joint.x, joint.y, joint.rot], e.value);
        }
        verifyOpeningSkeleton(openingView.boy);
        game.resume();
      }
      expect(tester.takeException(), isNull);
    }
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(game.opening, isNull);
    expect(audio.routeAudio.error, isNull);
    expect(audio.routeAudio.running, isTrue);
    expect(audio.routeAudio.scheduledVoices, greaterThan(0));
    expect(audio.routeAudio.engine.getActiveVoiceCount(), greaterThan(0));
    expect(audio.routeAudio.environment!.current, 'dusk');
    expect(find.text('再听一次'), findsNothing);
    expect(find.bySemanticsLabel('向右'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.textContaining('左下角'), findsNothing);
    expect(openingView.hintsView.root.visible, isTrue);
    expect(openingView.hintsView.move.cap.a, greaterThan(.5));
    await captureNative(openingNative, 'hints-move');
    final startX = game.x;
    final touch = await tester.startGesture(
      tester.getTopLeft(find.byType(TransparentGameInput)) +
          Offset(
            tester.getSize(find.byType(TransparentGameInput)).width * .16,
            tester.getSize(find.byType(TransparentGameInput)).height * .85,
          ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(game.x, greaterThan(startX + .2));
    expect(openingView.boy.runtime.gait.mode, 'moving');
    await captureNative(openingNative, 'boy-run');
    await touch.up();
    game.pause();
    final frozen = <String, double>{
      for (final id in ['body', 'thighF', 'shinF', 'footF', 'head'])
        id: openingView.boy.rig.joints[id].rotation.z as double,
    };
    final frozenTime = openingView.boy.motion.time;
    final hintTime = openingView.hintsView.move.cap.time;
    final hintAlpha = openingView.hintsView.move.cap.a;
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(openingView.boy.motion.time, frozenTime);
    expect(openingView.hintsView.move.cap.time, hintTime);
    expect(openingView.hintsView.move.cap.a, hintAlpha);
    expect(audio.routeAudio.running, isFalse);
    final pausedRebases = audio.routeAudio.rebases;
    for (final entry in frozen.entries) {
      expect(openingView.boy.rig.joints[entry.key].rotation.z, entry.value);
    }
    game.resume();
    game.setDirection(900, -1);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(game.facing, -1);
    expect(audio.routeAudio.running, isTrue);
    expect(audio.routeAudio.rebases, greaterThan(pausedRebases));
    expect(audio.routeAudio.error, isNull);
    await captureNative(openingNative, 'boy-turn');
    game.releaseDirection(900);
    game.pressNote(1);
    game.pressNote(3);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await captureNative(openingNative, 'boy-crank');
    game.releaseNote(1);
    game.releaseNote(3);
    game.jump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await captureNative(openingNative, 'boy-jump');
    for (final x in [12.0, 54.0, 68.0]) {
      game.x = x;
      game.y = openingView.assets.groundAt(openingView.global, x);
      game.player.grounded = true;
      game.player.vy = 0;
      game.camera!.snap(game.x, game.y);
      for (var step = 0; step < 8; step++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(openingView.openingView.lead.visible, isTrue);
      expect(
        openingView.openingView.leadLight.glow.material,
        isA<three.ShaderMaterial>(),
      );
      await captureNative(openingNative, 'guide-$x');
    }
    for (var i = -1; i < 9; i++) {
      if (i >= 0) game.enterLevel(i);
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (game.loading && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('原版场景加载未完成'), findsNothing);
      }
      expect(game.loading, isFalse);
      if ([0, 1, 7].contains(i)) {
        final hintX =
            game.segment!.ox +
            (i == 7
                ? 15.6
                : i == 0
                ? 1
                : 3.5);
        game.x = hintX;
        game.y = game.segment!.oy;
        game.player.grounded = true;
        game.player.vy = 0;
        game.camera!.snap(game.x, game.y);
        if (i == 0) {
          game.firefly!
            ..phase = 'listen'
            ..teachShown = true
            ..sings = 2;
        } else if (i == 1) {
          game.sourceCaller!.state = 'listen';
          game.listen();
        } else {
          game.woodpecker!
            ..mode = 'listen'
            ..wantDrum = false
            ..waiting = false
            ..run = null;
          game.woodpecker!.token++;
          game.woodpecker!.window = game.woodpecker!.makeWindow(
            game.clock + 1.6,
            game.clock - 2,
          );
          game.woodpecker!.cue.turn();
        }
        for (var frame = 0; frame < (i == 1 ? 70 : 18); frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final dynamic hintView = tester.state(find.byType(OriginalWorldView));
        final hints = hintView.hintsView as NativeGameHints;
        expect(hints.pool.where((s) => s.visible), isNotEmpty);
        for (final sprite in hints.pool) {
          expect(sprite.material!.sizeAttenuation, isTrue);
        }
        expect(find.text('再听一次'), findsNothing);
        expect(find.text('1'), findsNothing);
        expect(find.bySemanticsLabel('向右'), findsNothing);
        await captureNative(
          hintView.renderer,
          'hints-${i == 0
              ? 'firefly'
              : i == 1
              ? 'caller'
              : 'wood'}',
        );
        if (i == 0) expect(hints.fireflyKeys.any((cap) => cap.a > .1), isTrue);
      }
      if (i == 1) game.hedgehog!.wake();
      if (i == 3) {
        game.bat!.wake();
        game.bat!.call(5, game.clock);
      }
      if (i == 4) {
        game.owl!.fullWake();
        game.owl!.command(0, game.player);
      }
      if (i == 0) game.firefly!.wake(game.player);
      if (i == 2) game.squirrel!.wake();
      if (i == 5) {
        for (var shell = 0; shell < game.turtle!.shells.length; shell++) {
          game.turtle!.surface(shell);
        }
      }
      if (i == 6) game.bear!.wake();
      if (i == 7) {
        game.woodpecker!
          ..mode = 'fall'
          ..crack = 3;
      }
      if (i == 8) {
        game.x = game.segment!.ox + 1;
        game.y = game.segment!.oy;
        for (final note in [5, 2, 7, 4, 6, 3, 1]) {
          game.pressNote(note);
        }
        expect(game.cinematic, isTrue);
      }
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.textContaining('原版场景加载未完成'), findsNothing);
      final dynamic view = tester.state(find.byType(OriginalWorldView));
      final three.ThreeJS native = view.renderer;
      final screen = native.renderer!.getRenderTarget()!;
      native.renderer!.resetState();
      native.renderer!.setRenderTarget(screen);
      final pixels = Uint8List(screen.width * screen.height * 4);
      native.renderer!.readRenderTargetPixels(
        screen,
        0,
        0,
        screen.width,
        screen.height,
        pixels,
      );
      var min = 765, max = 0;
      var opaqueOutput = true;
      for (var p = 0; p < pixels.length; p += 4) {
        final v = pixels[p] + pixels[p + 1] + pixels[p + 2];
        if (v < min) min = v;
        if (v > max) max = v;
        opaqueOutput = opaqueOutput && pixels[p + 3] == 255;
      }
      expect(
        opaqueOutput,
        isTrue,
        reason: 'Final native output must be opaque',
      );
      expect(
        max - min,
        greaterThan(40),
        reason: 'Native output must contain the world, not a blank texture',
      );
      if (i == 2) {
        final mask = Uint8List(512 * 512 * 4);
        native.renderer!.readRenderTargetPixels(
          view.boy.target,
          0,
          0,
          512,
          512,
          mask,
        );
        var opaque = 0;
        for (var y = 297; y < 402; y++) {
          for (var x = 220; x < 331; x++) {
            if (mask[(y * 512 + x) * 4 + 3] > 200) opaque++;
          }
        }
        expect(
          opaque,
          lessThan(9000),
          reason: 'Presentation must preserve the character silhouette on later frames',
        );
        expect(opaque, greaterThan(5000));
      }
      expect(audio.routeAudio.error, isNull);
      if (i < 8) {
        expect(audio.routeAudio.running, isTrue);
        expect(audio.routeAudio.meterPackets, greaterThan(0));
      } else {
        expect(audio.routeAudio.running, isFalse);
      }
      debugPrint(
        'ROUTE_AUDIO_OK chapter=$i scheduled=${audio.routeAudio.scheduledVoices} '
        'meters=${audio.routeAudio.meterPackets} lufs=${audio.routeAudio.musicLufs} '
        'autoGain=${audio.routeAudio.ambienceAutoGain} rebases=${audio.routeAudio.rebases}',
      );
      debugPrint('ORIGINAL_NATIVE_OK $i x=${game.x} y=${game.y}');
      await captureNative(native, 'scene-$i');
      if (i == 6) {
        game.pause();
        final segment = game.route!.segments[6];
        final bear = game.bear!;
        final dynamic adapter = view.bearView;
        var localX = 7.0;
        for (final scenario in ['walk', 'turn', 'wade']) {
          // A teleport snaps source facing and intentionally skips turn art.
          // Reverse continuously here to exercise the .25 s turn debounce.
          if (scenario == 'wade') localX = 10.7;
          final count = scenario == 'turn' ? 20 : 90;
          for (var step = 0; step < count; step++) {
            localX += (scenario == 'turn' ? -.8 : .8) / 60;
            bear
              ..mode = scenario == 'wade' ? 'wade' : 'follow'
              ..x = localX
              ..y = scenario == 'wade' ? adapter.ground(localX) as double : 0
              ..facing = scenario == 'turn' ? -1 : 1;
            game.x = segment.ox + localX + 1;
            game.y = segment.oy;
            game.camera!.snap(game.x, game.y);
            adapter.update(
              bear,
              view.animals[6],
              segment.ox,
              segment.oy,
              1 / 60,
              girlX: game.x,
              girlY: game.y,
              girlOnBack: false,
              keys: 0.0,
              paletteT: view.currentPaletteT as double,
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (scenario == 'turn') expect(adapter.turnRig.root.visible, isTrue);
          if (scenario == 'wade') {
            expect(adapter.vWake.visible, isTrue);
            expect(adapter.line.visible, isTrue);
            expect(
              adapter.under.material.fragmentShader,
              adapter.shaders['look_ZT'],
            );
            expect(adapter.vWake.userData['sourceRenderOrder'], 6.5);
          }
          final cpu = adapter.skeleton;
          final nativeRig = view.animals[6];
          for (final id in ['body', 'head', 'upNF', 'pwNH', 'scarfTailN2']) {
            expect(
              nativeRig.parts[id].joint.rotation.z,
              closeTo(cpu.nodes[id].joint.rot, 1e-7),
            );
          }
          expect(tester.takeException(), isNull);
          await captureNative(native, 'bear-$scenario');
        }
        game.resume();
      }
      if (i == 8) {
        var animalChecks = 0, dogChecks = 0, artistChecks = 0;
        for (final bar in [
          14.5,
          20.5,
          25.6,
          26.5,
          33.5,
          36.5,
          39.3,
          44.5,
          48.5,
        ]) {
          game.ending!.startedAt = game.clock - bar * 2;
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
            await Future<void>.delayed(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          }
          final dynamic current = tester.state(find.byType(OriginalWorldView));
          final NativeEndingView ending = current.endingView;
          for (final entry in ending.animalMotion.entries) {
            final rig = ending.beasts[entry.key]!;
            if (!rig.root.visible) continue;
            verifyDisplayedSkeleton(rig, entry.value.rig);
            expect(rig.flip.scale.x, closeTo(entry.value.facing, 1e-6));
            animalChecks++;
          }
          final dog = ending.beasts['fam-dog']!;
          if (dog.root.visible) {
            final motion = ending.dogMotion;
            verifyDisplayedSkeleton(dog, motion.rig);
            expect(
              dog.flip.scale.x,
              closeTo(motion.rig.facing * motion.rig.squash, 1e-6),
            );
            expect(dog.material.uniforms['uOpacity']['value'], motion.opacity);
            final neck = dog.data['anchors']['neck'];
            final expected =
                dog.parts[neck['parent']]!.joint.matrixWorld.clone()..multiply(
                  three.Matrix4.identity()..makeTranslation(
                    (neck['at'][0] as num).toDouble(),
                    (neck['at'][1] as num).toDouble(),
                    0,
                  ),
                );
            for (var k = 0; k < 16; k++) {
              expect(
                ending.dogProp.mount.matrix.storage[k],
                closeTo(expected.storage[k], 1e-5),
              );
            }
            expect(ending.dogProp.materials.length, 3);
            for (final material in ending.dogProp.materials) {
              expect(material.uniforms['uOpacity']['value'], motion.opacity);
            }
            dogChecks++;
          }
          if (bar == 25.6) {
            final dad = ending.family['dad']!;
            expect(dad.animation.reachLast.keys, containsAll(['F', 'B']));
            expect(dad.animation.reachLast['F']!.palm, isNotNull);
            expect(dad.animation.reachLast['B']!.palm, isNotNull);
          }
          if (bar == 39.3) {
            final mom = ending.family['mom']!;
            expect(mom.root.visible, isTrue);
            expect(mom.animation.reachLast['F']!.palm, isNotNull);
            expect(mom.renderer.quad.renderOrder, 25);
          }
          for (final sprite
              in current.chunks['route-ending'].nodes
                  .whereType<three.Sprite>()) {
            expect(
              sprite.material!.sizeAttenuation,
              isTrue,
              reason: 'Source sprite sizes must attenuate with distance',
            );
          }
          debugPrint('ENDING_NATIVE_OK $bar');
          final dynamic app = tester.state(find.byType(GoHomeApp));
          expect(app.audio.activeTrack, 'original-ending');
          expect(app.audio.error, isNull);
          await captureNative(native, 'ending-$bar');
        }
        for (final after in [
          1.5,
          5.0,
          12.0,
          17.5,
          20.5,
          23.0,
          27.0,
          30.5,
          32.5,
        ]) {
          game.ending!.pressedAt = game.clock - after;
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
            await Future<void>.delayed(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          }
          final dynamic current = tester.state(find.byType(OriginalWorldView));
          final NativeEndingView ending = current.endingView;
          final artist = ending.artistFirefly;
          expect(artist.rasterError, isNull);
          if (artist.root.visible) {
            expect(artist.uploads, greaterThan(0));
            expect(artist.rig.material, isA<three.ShaderMaterial>());
            final pixels = artist.texture.image!.data as Uint8List;
            var covered = 0;
            for (var p = 3; p < pixels.length; p += 4) {
              if (pixels[p] > 0) covered++;
            }
            expect(covered, greaterThan(40));
            expect(covered, lessThan(448 * 336 ~/ 2));
            artistChecks++;
          }
          await captureNative(native, 'finale-$after');
          final dynamic app = tester.state(find.byType(GoHomeApp));
          expect(app.audio.error, isNull);
          debugPrint('FINALE_NATIVE_OK $after');
        }
        expect(animalChecks, greaterThan(0));
        expect(dogChecks, greaterThan(0));
        expect(artistChecks, greaterThan(0));
        debugPrint(
          'ENDING_ADAPTER_OK animals=$animalChecks dog=$dogChecks artist=$artistChecks',
        );
        for (var frame = 0; frame < 60 && game.cinematic; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(game.mode, GameMode.menu);
        expect(game.levelIndex, 0);
        expect(game.cinematic, isFalse);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    game.dispose();
  });
}

void verifyDisplayedSkeleton(
  NativePuppetRenderer native,
  OriginalPuppetRig cpu,
) {
  for (final entry in cpu.nodes.entries) {
    final a = native.parts[entry.key]!.joint, b = entry.value.joint;
    expect(a.position.x, closeTo(b.x, 1e-6), reason: entry.key);
    expect(a.position.y, closeTo(b.y, 1e-6), reason: entry.key);
    expect(a.rotation.z, closeTo(b.rot, 1e-6), reason: entry.key);
    expect(a.scale.x, closeTo(b.sx, 1e-6), reason: entry.key);
    expect(a.scale.y, closeTo(b.sy, 1e-6), reason: entry.key);
    expect(a.visible, entry.value.visible, reason: entry.key);
  }
  expect(native.poseRoot.position.x, closeTo(cpu.rx, 1e-6));
  expect(native.poseRoot.position.y, closeTo(cpu.ry, 1e-6));
}

/// Compare the explicit port against the original SpriteMaterial GPU path on
/// the same GLES target, including blending and an oblique camera billboard.
Future<void> verifyFireflyShader(three.Renderer renderer) async {
  final port = NativeFireflyLight();
  final size = originalFireflySize(distance: 22, glow: .7);
  port.setSize(size);
  port.root.visible = true;
  final reference = three.Scene(), actual = three.Scene()..add(port.root);
  final colors = [0xffe4a0, 0xfff6d2, 0xffa32e];
  final scales = [size.glow, size.core, size.amber];
  final opacity = [1.0, size.coreAlpha, size.amberAlpha];
  final materials = <three.Material>[];
  for (var i = 0; i < 3; i++) {
    final material = three.SpriteMaterial.fromMap({
      'map': port.texture,
      if (i > 0) 'alphaMap': port.texture,
      'color': three.Color.fromHex32(colors[i]).toLinear(),
      'opacity': opacity[i],
      'transparent': true,
      'depthTest': false,
      'depthWrite': false,
      'fog': false,
      'sizeAttenuation': true,
      'blending': i == 0 ? three.AdditiveBlending : three.NormalBlending,
    });
    materials.add(material);
    reference.add(
      three.Sprite(material)
        ..scale.setScalar(scales[i])
        ..renderOrder = i == 1 ? 41 : 40,
    );
  }
  final camera = three.PerspectiveCamera(28, 1, .1, 100)
    ..position.setValues(2, 1, 5)
    ..lookAt(three.Vector3());
  final target = three.RenderTarget(256, 256);
  final previous = renderer.getRenderTarget(), alpha = renderer.getClearAlpha();
  final color = renderer.getClearColor(three.Color());
  Uint8List render(three.Scene scene) {
    (renderer as dynamic).resetState();
    renderer.setRenderTarget(target);
    renderer.setClearColor(three.Color.fromHex32(0x17212c), 1);
    renderer.clear();
    renderer.render(scene, camera);
    final pixels = Uint8List(256 * 256 * 4);
    renderer.readRenderTargetPixels(target, 0, 0, 256, 256, pixels);
    return pixels;
  }

  try {
    final a = render(actual), b = render(reference);
    for (final entry in {'port': a, 'sprite': b}.entries) {
      final file = File(
        '${Directory.systemTemp.path}/firefly-shader-${entry.key}.rgba',
      );
      await file.writeAsBytes(entry.value);
      debugPrint('NATIVE_CAPTURE ${file.path}');
      debugPrint(
        'FIREFLY_PIXELS ${entry.key} corner=${entry.value.sublist(0, 4)} centre=${entry.value.sublist((128 * 256 + 128) * 4, (128 * 256 + 128) * 4 + 4)}',
      );
    }
    var differing = 0, maxDifference = 0;
    for (var i = 0; i < a.length; i++) {
      final d = (a[i] - b[i]).abs();
      if (d > maxDifference) maxDifference = d;
      if (d > 1) differing++;
    }
    expect(
      differing,
      0,
      reason: 'SpriteMaterial shader max error $maxDifference',
    );
    expect(a.toSet().length, greaterThan(10), reason: 'Light must be rendered');
    debugPrint(
      'FIREFLY_SHADER_PARITY maxChannelError=$maxDifference pixels=65536',
    );
  } finally {
    (renderer as dynamic).resetState();
    renderer.setClearColor(color, alpha);
    renderer.setRenderTarget(previous);
    target.dispose();
    for (final m in materials) {
      m.dispose();
    }
    port.dispose();
  }
}

Future<void> captureNative(three.ThreeJS native, String name) async {
  final r = native.renderer!, screen = native.renderer!.getRenderTarget()!;
  r.resetState();
  r.setRenderTarget(screen);
  final pixels = Uint8List(screen.width * screen.height * 4);
  r.readRenderTargetPixels(screen, 0, 0, screen.width, screen.height, pixels);
  var min = 765, max = 0;
  var opaque = true;
  for (var i = 0; i < pixels.length; i += 4) {
    final v = pixels[i] + pixels[i + 1] + pixels[i + 2];
    if (v < min) min = v;
    if (v > max) max = v;
    opaque = opaque && pixels[i + 3] == 255;
  }
  expect(opaque, isTrue);
  expect(
    max - min,
    greaterThan(30),
    reason: 'Cinematic must render a nonblank native frame',
  );
  final flipped = Uint8List(pixels.length), row = screen.width * 4;
  for (var y = 0; y < screen.height; y++) {
    flipped.setRange(
      y * row,
      (y + 1) * row,
      pixels,
      (screen.height - y - 1) * row,
    );
  }
  final image = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    flipped,
    screen.width,
    screen.height,
    ui.PixelFormat.rgba8888,
    image.complete,
  );
  final decoded = await image.future,
      png = await decoded.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${Directory.systemTemp.path}/$name.png');
  await file.writeAsBytes(png!.buffer.asUint8List());
  debugPrint('NATIVE_CAPTURE ${file.path}');
  decoded.dispose();
}

void verifyOpeningSkeleton(dynamic boy) {
  final source = boy.runtime.rig;
  for (final entry in source.joints.entries) {
    final target = boy.rig.joints[entry.key];
    expect(target.position.x, closeTo(entry.value.x as num, 2e-6));
    expect(target.position.y, closeTo(entry.value.y as num, 2e-6));
    expect(target.rotation.z, closeTo(entry.value.rot as num, 2e-6));
    expect(target.scale.x, closeTo(entry.value.sx as num, 2e-6));
    expect(target.scale.y, closeTo(entry.value.sy as num, 2e-6));
  }
  expect(boy.stage.scale.x, closeTo(boy.runtime.pose.turnX as num, 2e-6));
}
