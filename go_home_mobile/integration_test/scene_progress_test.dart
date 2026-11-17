import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'original corner route enters, completes, fades and passes input',
    (tester) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final game =
          GameController(
              await ScoreLibrary.load(),
              route: await OriginalRoute.load(),
            )
            ..start()
            ..enterLevel(1);
      await tester.pumpWidget(GoHomeApp(game: game));
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (game.loading && DateTime.now().isBefore(deadline)) {
        await advance(tester, .1);
        expect(tester.takeException(), isNull);
      }
      expect(game.loading, isFalse);
      final dynamic world = tester.state(find.byType(OriginalWorldView));
      expect(world.error, isNull);
      final finder = find.byKey(const ValueKey('original-scene-progress'));
      game.sceneProgress.reset(completed: [0], at: 0);
      await advance(tester, .65);
      expect(game.sceneProgress.kind, 'enter');
      expect(game.sceneProgress.lit, 1);
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder),
          size = tester.getSize(find.byType(Scaffold));
      expect(rect.size, const Size(140, 18));
      expect(size.width - rect.right, closeTo(24, 1e-6));
      expect(size.height - rect.bottom, closeTo(24, 1e-6));
      await capture('scene-progress-enter');
      final touch = await tester.startGesture(rect.center);
      expect(game.jumpPointers, isNotEmpty);
      await touch.up();
      game.pause();
      final age = game.sceneProgress.age;
      await advance(tester, .4);
      expect(game.sceneProgress.age, age);
      expect(finder, findsNothing);
      game.resume();
      await advance(tester, .2);
      expect(finder, findsOneWidget);
      game.hedgehog!.finish();
      game.solved.add(1);
      game.x = game.route!.segments[1].goalX + .2;
      game.y = game.segment!.oy;
      game.vx = game.vy = 0;
      game.grounded = true;
      game.camera!.snap(game.x, game.y);
      await advance(tester, .65);
      expect(game.sceneProgress.done, {0, 1});
      expect(game.sceneProgress.kind, 'done');
      expect(game.sceneProgress.current, 2);
      expect(finder, findsOneWidget);
      await capture('scene-progress-done');
      await advance(tester, 3);
      expect(finder, findsNothing);
      game.settingsChanged();
      await advance(tester, .2);
      expect(finder, findsNothing);
      expect(tester.takeException(), isNull);
      await capture('scene-progress-hidden');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}

Future<void> advance(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 20).ceil(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> capture(String name) async {
  final ack = File('${Directory.systemTemp.path}/$name.capture-ack');
  if (await ack.exists()) await ack.delete();
  debugPrintSynchronously('SCENE_PROGRESS_CAPTURE $name ${ack.path}');
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!await ack.exists() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (await ack.exists()) await ack.delete();
}
