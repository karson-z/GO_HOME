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
  testWidgets('stone and curled hedgehog show original push hints on GLES', (
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
          ..enterLevel(1);
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
    final segment = game.segment!, h = game.hedgehog!;

    Future<void> render(double seconds) async {
      for (var i = 0; i < (seconds * 20).ceil(); i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    }

    three.Sprite sprite(String id) => hints.pool.firstWhere(
      (s) => s.visible && s.material!.map == hints.textures['push-$id'],
    );

    game.x = segment.ox + h.stump.x - 2;
    game.y = segment.oy;
    game.camera!.snap(game.x, game.y);
    game.hintMode = 'off'; // Push teaching is independent of numeric assists.
    await render(.8);
    expect(hints.pushHints.first.on, isTrue);
    expect(hints.pushHints.last.on, isFalse);
    final stone = sprite('stump');
    expect(stone.position.x, closeTo(segment.ox + h.stump.x, 1e-5));
    expect(stone.position.y, closeTo(segment.oy + 1.8 + .624 / 2, 1e-5));
    expect(stone.material!.opacity, greaterThan(.9));
    expect(stone.material!.depthTest, isFalse);
    await captureNative(native, 'push-hint-stone');

    game.pause();
    final age = hints.pushHints.first.cap.time;
    await render(.4);
    expect(hints.pushHints.first.cap.time, age);
    expect(stone.material!.opacity, lessThan(.01));
    game.resume();
    game.setDirection(999, 1);
    for (var i = 0; i < 140 && !hints.pushHints.first.done; i++) {
      await render(.05);
    }
    game.releaseDirection(999);
    expect(hints.pushHints.first.done, isTrue);
    expect(h.stump.x - h.stump.homeX, greaterThanOrEqualTo(.3));
    await render(1);
    expect(
      hints.pool.any(
        (s) => s.visible && s.material!.map == hints.textures['push-stump'],
      ),
      isFalse,
    );

    h.curl();
    game.x = segment.ox + 3.6;
    game.y = segment.oy + 1.9;
    game.vx = game.vy = 0;
    game.grounded = true;
    game.camera!.snap(game.x, game.y);
    await render(.8);
    expect(hints.pushHints.last.on, isTrue);
    expect(sprite('ball').material!.opacity, greaterThan(.9));
    await captureNative(native, 'push-hint-hedgehog');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
