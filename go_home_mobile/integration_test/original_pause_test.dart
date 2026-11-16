import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/audio_engine.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:go_home_mobile/ui/original_pause_menu.dart';
import 'package:go_home_mobile/ui/original_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'original pause surface, transitions, settings, input and saved return',
    (tester) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final game = GameController(
        await ScoreLibrary.load(),
        route: await OriginalRoute.load(),
      );
      await tester.pumpWidget(GoHomeApp(game: game));
      final dynamic world = tester.state(find.byType(OriginalWorldView));
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      final GameAudio audio =
          (tester.state(find.byType(GoHomeApp)) as dynamic).audio;
      while ((!world.ready || game.loading || !audio.routeAudio.ready) &&
          DateTime.now().isBefore(deadline)) {
        await advance(tester, .2);
      }
      expect(world.error, isNull);
      game.start();
      await advance(tester, 1);
      expect(
        find.byKey(const ValueKey('original-menu-corner')),
        findsOneWidget,
      );
      await capture(tester, 'pause-corner');
      game.setDirection(91, 1);
      game.pressNote(2);
      await tester.tap(find.byKey(const ValueKey('original-menu-corner')));
      await advance(tester, .65);
      expect(game.mode, GameMode.paused);
      expect(game.directions, isEmpty);
      expect(game.heldNotes, isEmpty);
      final pause = tester.state<OriginalPauseMenuState>(
        find.byType(OriginalPauseMenu),
      );
      expect(pause.selected, 0);
      expect(find.text('暂停'), findsNothing);
      expect(find.text('回到安全位置'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('继续'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('回到主菜单'), findsOneWidget);
      final x = game.x, clock = game.clock, note = game.noteSerial;
      final camera = world.renderer.camera.projectionMatrix.storage.toList();
      final hintTime = world.hintsView.move.cap.time;
      expect(world.hintsView.tipOpacity, closeTo(0, .001));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await advance(tester, .4);
      expect(game.x, x);
      expect(game.clock, clock);
      expect(game.noteSerial, note);
      expect(world.hintsView.move.cap.time, hintTime);
      expect(world.renderer.camera.projectionMatrix.storage, camera);
      await capture(tester, 'pause-zh');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(pause.selected, 1);
      await advance(tester, .3);
      await capture(tester, 'pause-settings-selection');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await advance(tester, .65);
      expect(find.byType(OriginalSettings), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await advance(tester, .5);
      expect(game.mode, GameMode.paused);
      expect(pause.selected, 1);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      await capture(tester, 'pause-en');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await advance(tester, .5);
      expect(game.mode, GameMode.playing);
      expect(world.hintsView.tipOpacity, closeTo(1, .001));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await advance(tester, .6);
      expect(pause.selected, 0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('pause-row-0'))),
      );
      await tester.pump(const Duration(milliseconds: 70));
      expect(game.mode, GameMode.paused);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.mode, GameMode.paused); // The original confirms after 200ms.
      await advance(tester, .3);
      expect(game.mode, GameMode.playing);
      // Save a later checkpoint and return through the third original row.
      game.enterLevel(1);
      await advance(tester, .5);
      final savedX = game.x;
      game.pause();
      await advance(tester, .6);
      await tester.tap(find.byKey(const ValueKey('pause-row-2')));
      await advance(tester, .6);
      expect(game.mode, GameMode.menu);
      expect(game.levelIndex, 1);
      expect(game.x, savedX);
      expect(game.hasSave, isTrue);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Go Home'), findsNWidgets(3));
      await capture(tester, 'pause-return-title');
      game.start();
      await advance(tester, .5);
      expect(game.levelIndex, 1);
      expect(audio.error, isNull);
      expect(audio.routeAudio.error, isNull);
      expect(tester.takeException(), isNull);
      debugPrint(
        'PAUSE_OK corner/three rows hand layout selection delay keyboard settings language freeze tip-hush saved-return',
      );
      await tester.pumpWidget(const SizedBox.shrink());
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
  debugPrintSynchronously('PAUSE_CAPTURE $name ${ack.path}');
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!await ack.exists() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (await ack.exists()) await ack.delete();
}
