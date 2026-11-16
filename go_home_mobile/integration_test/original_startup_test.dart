import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/audio_engine.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:go_home_mobile/ui/original_startup_overlay.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'original first-launch guide, fog shader and opening work natively',
    (tester) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final game = GameController(
        await ScoreLibrary.load(),
        route: await OriginalRoute.load(),
      )..prepareStartup();
      var saves = 0;
      game.onSave = () async {
        saves++;
      };
      await tester.pumpWidget(GoHomeApp(game: game));
      await capture(tester, 'startup-loading');
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (!game.startup!.canPress && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      final dynamic overlay = tester.state(find.byType(OriginalStartupOverlay));
      final GameAudio audio =
          (tester.state(find.byType(GoHomeApp)) as dynamic).audio;
      expect(game.startup!.canPress, isTrue);
      expect(overlay.shader, isNotNull);
      expect(audio.error, isNull);
      expect(audio.routeAudio.running, isFalse);
      final dynamic world = tester.state(find.byType(OriginalWorldView));
      expect(world.openingView.root.visible, isFalse);
      await verifyFog(
        overlay.shader as ui.FragmentShader,
        overlay.field as ui.Image,
      );
      await capture(tester, 'startup-phones');
      final touch = await tester.startGesture(
        tester.getCenter(find.byType(OriginalStartupOverlay)),
      );
      expect(
        game.startup!.phase,
        'tapped',
        reason: 'Original EN responds to pointerdown before release',
      );
      await touch.up();
      await advance(tester, .5);
      expect(game.startup!.phase, 'cal');
      expect(audio.startupTuning, isTrue);
      final slider = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.slider == true,
      );
      final rect = tester.getRect(slider);
      await tester.tapAt(Offset(rect.left + rect.width * .45, rect.center.dy));
      await advance(tester, .3);
      expect(game.masterVolume, .45);
      expect(game.opening!.arriveFrom, isNull);
      await capture(tester, 'startup-calibration');
      await tester.tap(find.text('完成'));
      await advance(tester, .2);
      expect(game.audioCalibrated, isTrue);
      expect(saves, greaterThan(0));
      expect(game.hasSave, isFalse);
      expect(audio.startupTuning, isFalse);
      game.opening!.time = game.startup!.outAt! + 1.75;
      await advance(tester, .15);
      expect(game.startup!.phase, 'clear');
      await capture(tester, 'startup-fog-clear');
      game.opening!.time = game.startup!.arriveAt! + 2.3;
      await advance(tester, .1);
      expect(game.startup!.done, isTrue);
      expect(world.openingView.root.visible, isTrue);
      await capture(tester, 'startup-firefly');
      game.opening!.time = game.startup!.arriveAt! + 6.35;
      await advance(tester, .1);
      await capture(tester, 'startup-title-reveal');
      game.opening!.time = game.startup!.arriveAt! + 7.8;
      await advance(tester, .1);
      await capture(tester, 'startup-menu');
      expect(find.text('By Blizzardfan'), findsNothing);
      expect(find.bySemanticsLabel('向右'), findsNothing);
      await tester.tap(find.text('开始'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.mode, GameMode.playing);
      await capture(tester, 'startup-title-leave');
      final before = world.renderer.camera.position.clone();
      game.opening!.time = game.opening!.goAt! + 4.49;
      game.update(.02);
      expect(game.opening, isNull);
      // Handover retains the exact held shot; the following updates use the
      // already source-verified camera damping and release time.
      final held = game.camera!.pose.pos;
      expect(held[0], closeTo(before.x, 1e-6));
      expect(held[1], closeTo(before.y, 1e-6));
      expect(held[2], closeTo(before.z, 1e-6));
      await advance(tester, .15);
      expect(game.camera!.relSmooth, 10);
      expect(audio.routeAudio.running, isTrue);
      expect(audio.error, isNull);
      expect(tester.takeException(), isNull);
      debugPrint(
        'STARTUP_OK calibration=.45 shader=9x1196 samples cameraHoldRelease=10',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      game.dispose();
    },
  );
}

Future<void> advance(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 20).ceil(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (name == 'startup-fog-clear' || name == 'startup-title-reveal') {
    await tester.pump();
  } else {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  final ack = File('${Directory.systemTemp.path}/$name.capture-ack');
  if (await ack.exists()) await ack.delete();
  debugPrintSynchronously('STARTUP_CAPTURE $name ${ack.path}');
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!await ack.exists() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (await ack.exists()) await ack.delete();
}

Future<void> verifyFog(ui.FragmentShader shader, ui.Image field) async {
  final source = jsonDecode(
    await rootBundle.loadString('assets/startup/original_startup.json'),
  );
  var maxAlphaError = 0, maxColorError = 0, count = 0;
  for (final f in source['fogPixels']) {
    final recorder = ui.PictureRecorder();
    // Keep one recorder for the shader's native raster output.
    final target = Canvas(recorder);
    StartupFogPainter(
      shader: shader,
      field: field,
      progress: (f['progress'] as num).toDouble(),
      clearing: true,
      time: 0,
    ).paint(target, const Size(320, 180));
    final picture = recorder.endRecording(),
        image = await picture.toImage(320, 180);
    final data = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    for (final p in f['samples']) {
      final i = ((p[1] as int) * 320 + (p[0] as int)) * 4;
      final a = (data[i + 3] - (p[5] as int)).abs();
      if (a > maxAlphaError) maxAlphaError = a;
      if ((p[5] as int) > 32) {
        for (var c = 0; c < 3; c++) {
          final error = (data[i + c] - (p[2 + c] as int)).abs();
          if (error > maxColorError) maxColorError = error;
        }
      }
      count++;
    }
    image.dispose();
    picture.dispose();
  }
  expect(maxAlphaError, lessThanOrEqualTo(2));
  expect(maxColorError, lessThanOrEqualTo(5));
  debugPrint(
    'STARTUP_SHADER samples=$count maxAlphaError=$maxAlphaError maxColorError=$maxColorError',
  );
}
