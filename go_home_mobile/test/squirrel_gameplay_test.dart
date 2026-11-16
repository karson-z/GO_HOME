import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScoreLibrary scores;
  late OriginalRoute route;
  setUpAll(() async {
    scores = await ScoreLibrary.load();
    route = await OriginalRoute.load();
  });
  GameController create() {
    final game = GameController(scores, route: route)
      ..start()
      ..enterLevel(2)
      ..sceneReady();
    game.x = game.segment!.ox + 14;
    game.y = game.segment!.oy;
    return game;
  }

  void answer(GameController game, String id) {
    final start = game.clock;
    for (final n in scores.melodies[id]!.notes) {
      game.clock = start + n.step * .125;
      game.pressNote(n.degree);
      game.releaseNote(n.degree);
    }
  }

  Future<void> advance(GameController game, double seconds) async {
    for (var i = 0; i < (seconds * 60).ceil(); i++) {
      game.update(1 / 60);
      await Future<void>.value();
    }
  }

  test(
    'main route uses the full source wake song, not the head experiment',
    () {
      final game = create();
      expect(game.level.calls, ['squirrel-harp']);
      expect(game.sourceCaller!.judge.keys, [1, 3, 5, 6, 7, 6, 5, 3]);
      answer(game, 'squirrel-harp-head');
      expect(game.squirrel!.awake, isFalse);
      game.dispose();
    },
  );

  test('wake, single fruit commands, door reply and physical exit', () async {
    final game = create();
    final played = <String>[];
    game.onScheduleCall = (melody, request, x) {
      played.add(melody.id);
      return game.clock + .12;
    };
    await advance(game, .1);
    expect(played, contains('squirrel-harp'));
    answer(game, 'squirrel-harp');
    final sq = game.squirrel!;
    expect(sq.mode, 'out');
    expect(game.isSolved, isFalse);
    await advance(game, .7);
    expect(sq.waiting, isTrue);
    final hints = sq.fruitHints(0);
    // Values read from original zv/_v: keys stay beside the hanging fruit.
    expect(hints.map((h) => h.texture), ['tag-6', 'tag-7', 'tag-1']);
    for (var i = 0; i < hints.length; i++) {
      expect(hints[i].x, closeTo([10.5, 16.6, 18.5][i], 1e-9));
      expect(hints[i].y, closeTo([5.3, 5.75, 4.55][i], 1e-9));
      expect(hints[i].depthTest, isTrue);
      expect(hints[i].order, 11);
      expect(hints[i].z, .6);
    }
    game.pressNote(2);
    game.releaseNote(2);
    expect(sq.refused, 1);
    for (final degree in [6, 7, 1]) {
      expect(sq.waiting, isTrue);
      game.pressNote(degree);
      game.releaseNote(degree);
      expect(sq.mode, 'go');
      expect(sq.fruitHints(game.clock), isEmpty);
      game.pressNote(1);
      game.releaseNote(1);
      expect(sq.commands, [6, 7, 1].indexOf(degree) + 1);
      var sawFocus = false;
      for (var i = 0; i < 1800 && !['perch', 'home'].contains(sq.mode); i++) {
        await advance(game, 1 / 60);
        if (sq.cameraFocus(game.localX) != null) {
          sawFocus = true;
          expect(
            game.camera!.focus!.maxX,
            closeTo(game.segment!.ox + 26.4, 1e-9),
          );
        }
      }
      expect(sawFocus, isTrue);
      expect(sq.fruits.firstWhere((f) => f.degree == degree).state, 'socketed');
      expect(game.isSolved, isFalse);
    }
    expect(sq.allBells, isTrue);
    expect(sq.doorOpen, isFalse);
    expect(sq.fruitHints(game.clock), isEmpty);
    game.x = game.segment!.ox + 20;
    await advance(game, 3);
    expect(played, contains('squirrel-harp-door'));
    answer(game, 'squirrel-harp-door');
    expect(sq.chimeTime, 0);
    expect(sq.doorOpen, isFalse);
    await advance(game, .5);
    expect(sq.doorOpen, isFalse);
    await advance(game, .2);
    expect(sq.doorOpen, isTrue);
    expect(game.isSolved, isTrue);
    expect(game.camera!.focus, isNull);
    await advance(game, 5);
    expect(sq.doorY, -5.2);
    game.setDirection(999, 1);
    await advance(game, 4);
    game.releaseDirection(999);
    expect(game.x, greaterThan(route.segments[2].ox + 25.6));
    game.dispose();
  });
}
