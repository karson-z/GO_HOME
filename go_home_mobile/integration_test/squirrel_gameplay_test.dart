import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/audio_engine.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:three_js/three_js.dart' as three;

import 'original_world_test.dart' show captureNative;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('source squirrel puzzle on native GLES', (tester) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    final game =
        GameController(
            await ScoreLibrary.load(),
            route: await OriginalRoute.load(),
          )
          ..start()
          ..enterLevel(2);
    await tester.pumpWidget(GoHomeApp(game: game));
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (game.loading && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    expect(game.loading, isFalse);
    final dynamic app = tester.state(find.byType(GoHomeApp));
    final GameAudio audio = app.audio;
    while (!audio.routeAudio.ready &&
        audio.routeAudio.error == null &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(audio.routeAudio.ready, isTrue);
    final dynamic view = tester.state(find.byType(OriginalWorldView));
    final three.ThreeJS native = view.renderer;
    Future<void> render(String name) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(tester.takeException(), isNull);
      await captureNative(native, 'squirrel-$name');
    }

    Future<void> advance(double seconds) async {
      for (var i = 0; i < (seconds * 60).ceil(); i++) {
        game.update(1 / 60);
        await Future<void>.value();
      }
    }

    void answer(String id) {
      final start = game.clock;
      for (final n in game.scores.melodies[id]!.notes) {
        game.clock = start + n.step * .125;
        game.pressNote(n.degree);
        game.releaseNote(n.degree);
      }
    }

    game.x = game.segment!.ox + 14;
    game.y = game.segment!.oy;
    game.camera!.snap(game.x, game.y);
    await advance(.2);
    await render('wake');
    expect(game.sourceCaller!.judge.keys, [1, 3, 5, 6, 7, 6, 5, 3]);
    answer('squirrel-harp');
    await advance(.7);
    await render('fruit-keys');
    final sq = game.squirrel!;
    expect(sq.waiting, isTrue);
    final sprites = (view.hintsView.pool as List).cast<three.Sprite>();
    for (final degree in [6, 7, 1]) {
      expect(
        sprites.any(
          (s) =>
              s.visible &&
              s.material!.map == view.hintsView.textures['tag-$degree'] &&
              s.material!.depthTest == true,
        ),
        isTrue,
      );
    }
    expect(view.hintsView.rows.containsKey('squirrel-head'), isFalse);
    for (final degree in [6, 7, 1]) {
      game.pressNote(degree);
      game.releaseNote(degree);
      var captured = false;
      for (var i = 0; i < 1800 && !['perch', 'home'].contains(sq.mode); i++) {
        await advance(1 / 60);
        if (!captured && sq.act == 'press') {
          await render('insert-$degree');
          captured = true;
        }
      }
      expect(captured, isTrue);
      expect(sq.fruits.firstWhere((f) => f.degree == degree).state, 'socketed');
    }
    game.x = game.segment!.ox + 20;
    await advance(3);
    await render('door-melody');
    expect(sq.bellsSung, isTrue);
    answer('squirrel-harp-door');
    await advance(.4);
    expect(sq.doorOpen, isFalse);
    await advance(.3);
    expect(sq.doorOpen, isTrue);
    await advance(5);
    await render('door-open');
    expect(sq.doorY, -5.2);
    game.setDirection(999, 1);
    await advance(4);
    game.releaseDirection(999);
    expect(game.x, greaterThan(game.route!.segments[2].ox + 25.6));
    await render('exit');
    expect(audio.routeAudio.error, isNull);
    expect(audio.error, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
