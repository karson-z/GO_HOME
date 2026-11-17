import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/native_game_hints.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:three_js/three_js.dart' as three;

import 'original_world_test.dart' show captureNative;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mistake during demonstration leaves no rings after solving', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    final game =
        GameController(
            await ScoreLibrary.load(),
            route: await OriginalRoute.load(),
          )
          ..start()
          ..enterLevel(4);
    game.round = 1;
    game.owl!.halfWake();
    final caller = game.sourceCaller!;
    final x = caller.x, y = caller.y;
    game.x = x;
    game.y = y;
    game.camera!.snap(x, y);
    await tester.pumpWidget(GoHomeApp(game: game));
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (game.loading && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    expect(game.loading, isFalse);
    final dynamic view = tester.state(find.byType(OriginalWorldView));
    final NativeGameHints hints = view.hintsView;
    final three.ThreeJS native = view.renderer;
    Future<void> render(double seconds) async {
      for (var i = 0; i < (seconds * 20).ceil(); i++) {
        game.x = x;
        game.y = y;
        game.vx = game.vy = 0;
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    }

    caller.state = 'sing';
    final judge = caller.judge;
    game.pressNote(judge.keys.first);
    await render(.1);
    game.pressNote(judge.keys[1] == 7 ? 1 : 7);
    expect(judge.fails, 1);
    expect(caller.wrongs, 0);
    await render(.1);
    caller.state = 'listen';
    caller.autoSings = 2;
    final start = game.clock + 1;
    for (var i = 0; i < judge.keys.length; i++) {
      game.clock = start + judge.onsets[i] - judge.onsets.first;
      game.pressNote(judge.keys[i]);
      await render(.1);
    }
    expect(caller.state, 'awake');
    expect(game.isSolved, isTrue);
    bool visibleEcho() => hints.pool.any(
      (s) => s.visible && s.material!.map == hints.textures['echo'],
    );
    expect(visibleEcho(), isTrue);
    await captureNative(native, 'hint-cleanup-fading');
    await render(2);
    expect(hints.rows['4:1']!.echoes, isEmpty);
    expect(visibleEcho(), isFalse);
    await captureNative(native, 'hint-cleanup-cleared');
    await render(2);
    expect(
      visibleEcho(),
      isFalse,
      reason: 'expired feedback must stay cleared',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    game.dispose();
  });
}
