import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native GPU loads every level, character and repeated restart', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final game = GameController(await ScoreLibrary.load())..start();
    await tester.pumpWidget(GoHomeApp(game: game));

    Future<void> waitForScene() async {
      final deadline = DateTime.now().add(const Duration(seconds: 50));
      while (game.loading && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.text('场景加载未完成'), findsNothing);
      }
      expect(game.loading, isFalse, reason: game.level.id);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
    }

    await waitForScene();
    for (var i = 0; i < levels.length; i++) {
      game.enterLevel(i);
      await waitForScene();
      expect(find.text(levels[i].title), findsOneWidget);
      game.pressNote(1);
      game.releaseNote(1);
      game.jump();
      await tester.pump(const Duration(milliseconds: 100));
      game.pause();
      final position = game.x;
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.x, position);
      game.resume();
      debugPrint('NATIVE_SMOKE_OK ${game.level.id}');
    }
    // The same level must rebuild rather than remain stuck at loading=true.
    game.enterLevel(8);
    await waitForScene();
    // Rapid chapter changes must discard stale async loads safely.
    game.enterLevel(1);
    await tester.pump(const Duration(milliseconds: 20));
    game.enterLevel(7);
    await waitForScene();
    game.start(restart: true);
    await waitForScene();
    expect(game.levelIndex, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    game.dispose();
  });
}
