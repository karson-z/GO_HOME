import 'dart:io';

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
import 'package:go_home_mobile/ui/original_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'source settings from title and pause, audio calibration, persistence and input isolation',
    (tester) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final game = GameController(
        await ScoreLibrary.load(),
        route: await OriginalRoute.load(),
      )..prepareOpening(immediate: true);
      var saves = 0;
      game.onSave = () async {
        saves++;
      };
      await tester.pumpWidget(GoHomeApp(game: game));
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      final dynamic world = tester.state(find.byType(OriginalWorldView));
      while ((!world.ready || game.loading) &&
          DateTime.now().isBefore(deadline)) {
        await advance(tester, .2);
      }
      expect(world.error, isNull);
      await advance(tester, 2);
      final GameAudio audio =
          (tester.state(find.byType(GoHomeApp)) as dynamic).audio;
      await tester.tap(find.text('设置'));
      await advance(tester, .5);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('开始'), findsNothing);
      expect(find.text('Go Home'), findsNWidgets(3));
      expect(find.text('总音量'), findsOneWidget);
      expect(find.text('数字提示'), findsOneWidget);
      debugPrint(
        'SETTINGS_VIEW before size=${world.renderer.width},${world.renderer.height} target=${world.renderer.renderTarget.width},${world.renderer.renderTarget.height} camera=${world.renderer.camera.position.toList()} aspect=${world.renderer.camera.aspect} projection=${world.renderer.camera.projectionMatrix.storage}',
      );
      final cameraBefore = world.renderer.camera.projectionMatrix.storage
          .toList();
      final posBefore = world.renderer.camera.position.toList();
      await capture(tester, 'settings-menu-zh');
      for (var i = 0; i < 3; i++) {
        final rect = tester.getRect(find.byKey(ValueKey('settings-volume-$i')));
        await tester.tapAt(
          Offset(rect.left + rect.width * [.45, .6, .8][i], rect.center.dy),
        );
      }
      expect(game.masterVolume, .45);
      expect(game.musicVolume, .6);
      expect(game.sfxVolume, .8);
      await tester.tap(find.text('中'));
      await advance(tester, .2);
      expect(game.quality, 'mid');
      expect(world.post.width, (world.renderer.width * 1.0).round());
      await tester.tap(find.text('低'));
      await advance(tester, .2);
      expect(game.quality, 'low');
      expect(world.post.width, (world.renderer.width * .75).round());
      await tester.tap(find.text('高'));
      await advance(tester, .2);
      expect(world.post.width, (world.renderer.width * 1.5).round());
      expect(world.renderer.camera.projectionMatrix.storage, cameraBefore);
      expect(world.renderer.camera.position.toList(), posBefore);
      debugPrint(
        'SETTINGS_VIEW after size=${world.renderer.width},${world.renderer.height} target=${world.renderer.renderTarget.width},${world.renderer.renderTarget.height} camera=${world.renderer.camera.position.toList()} aspect=${world.renderer.camera.aspect} projection=${world.renderer.camera.projectionMatrix.storage}',
      );
      await tester.tap(find.text('关'));
      expect(game.hintMode, 'off');
      await tester.tap(find.text('开'));
      expect(game.hintMode, 'on');
      await tester.tap(find.text('自动'));
      expect(game.hintMode, 'auto');
      await tester.tap(
        find.descendant(
          of: find.byType(OriginalSettings),
          matching: find.text('English'),
        ),
      );
      await tester.pump();
      expect(find.text('Main volume'), findsOneWidget);
      expect(find.text('Number hints'), findsOneWidget);
      await capture(tester, 'settings-menu-en');
      await tester.tap(find.text('Test volume'));
      await advance(tester, 1.0);
      expect(audio.startupTuning, isTrue);
      expect(game.settingsDuck, 0);
      expect(game.startup, isNull); // Recalibration must not replay the intro.
      final rect = tester.getRect(find.byType(OriginalVolumeSlider));
      await tester.tapAt(Offset(rect.left + rect.width * .3, rect.center.dy));
      expect(game.masterVolume, .3);
      await capture(tester, 'settings-recalibration');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await advance(tester, .2);
      expect(game.masterVolume, .45);
      expect(game.settingsCalibration, isFalse);
      await tester.tap(find.text('Test volume'));
      await advance(tester, 1.0);
      final rect2 = tester.getRect(find.byType(OriginalVolumeSlider));
      await tester.tapAt(
        Offset(rect2.left + rect2.width * .55, rect2.center.dy),
      );
      await tester.tap(find.text('Done'));
      await advance(tester, .6);
      expect(game.audioCalibrated, isTrue);
      expect(game.masterVolume, .55);
      expect(audio.startupTuning, isFalse);
      await advance(tester, 2.5);
      expect(game.settingsDuck, 1);
      final restored = GameController(game.scores, route: game.route)
        ..restore(game.toJson());
      expect(restored.masterVolume, .55);
      expect(restored.musicVolume, .6);
      expect(restored.sfxVolume, .8);
      expect(restored.english, isTrue);
      expect(restored.quality, 'high');
      expect(restored.hintMode, 'auto');
      restored.dispose();
      expect(saves, greaterThan(8));
      await tester.tap(find.text('Back'));
      await advance(tester, .5);
      expect(find.byType(OriginalSettings), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      game.opening = null;
      game.start();
      game.pause();
      await tester.pump();
      await advance(tester, .6);
      await tester.tap(find.text('Settings'));
      await advance(tester, .5);
      final x = game.x, note = game.noteSerial;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      expect(game.directions, isEmpty);
      expect(game.noteSerial, note);
      expect(game.x, x);
      await capture(tester, 'settings-paused');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await advance(tester, .5);
      expect(game.mode, GameMode.paused);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('暂停'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(game.mode, GameMode.playing);
      expect(audio.error, isNull);
      expect(tester.takeException(), isNull);
      debugPrint(
        'SETTINGS_OK title/pause volumes language quality hints recalibration cancel/complete persistence input',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      game.dispose();
    },
  );
}

Future<void> advance(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 20).ceil(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  await advance(tester, .2);
  final ack = File('${Directory.systemTemp.path}/$name.capture-ack');
  if (await ack.exists()) await ack.delete();
  debugPrintSynchronously('SETTINGS_CAPTURE $name ${ack.path}');
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!await ack.exists() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (await ack.exists()) await ack.delete();
}
