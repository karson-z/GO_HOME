import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_scene_progress.dart';
import 'package:go_home_mobile/ui/original_scene_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/original_scene_progress.json').readAsStringSync(),
  );
  final chapters = List<String>.from(fixture['chapters']);
  test('checkpoint route preserves original chapter heights and geometry', () {
    final points = OriginalSceneProgressArtwork.points(chapters);
    for (var i = 0; i < points.length; i++) {
      expect(points[i].x, closeTo(fixture['points'][i]['x'], 1e-12));
      expect(points[i].y, closeTo(fixture['points'][i]['y'], 1e-12));
    }
  });
  for (final trace in fixture['traces']) {
    test('checkpoint ${trace['kind']} matches original animation and SVG', () {
      final progress = OriginalSceneProgress();
      if (trace['kind'] == 'enter') {
        progress.reset(completed: [0, 1, 2], at: 2);
        progress.enter(3);
      } else {
        progress.reset(completed: [0, 1], at: 2);
        progress.finish(2, 9);
      }
      for (final f in trace['frames']) {
        progress.update((f['dt'] as num).toDouble());
        expect(progress.active, f['active']);
        expect(progress.age, closeTo(f['age'], 1e-12));
        expect(progress.opacity, closeTo(f['opacity'], 1e-12));
        if (progress.active) expect(progress.swapped, f['swapped']);
        if (f['paths'] != null) {
          final svg = OriginalSceneProgressArtwork.svg(chapters, progress);
          final paths = RegExp(' d="([^"]+)"')
              .allMatches(svg)
              .map((m) => m[1])
              .toList();
          // Raw JS doubles in the tree use a different text representation.
          String normalize(String path) => path.replaceAllMapped(
            RegExp(r'-?(?:\d*\.?\d+)(?:e[-+]?\d+)?'),
            (m) => double.parse(m[0]!).toStringAsFixed(2),
          );
          expect(
            paths.map((p) => normalize(p!)).toList(),
            (f['paths'] as List).cast<String>().map(normalize).toList(),
            reason: 'age=${progress.age}',
          );
        }
      }
    });
  }
  test('backtracking and re-entering completed scenes do not replay toast', () {
    final p = OriginalSceneProgress()..enter(2);
    p.update(3);
    p.enter(2);
    expect(p.active, isFalse);
    p.enter(1);
    expect(p.active, isFalse);
    p.finish(2, 9);
    p.update(3);
    p.enter(2);
    expect(p.active, isFalse);
    expect(p.finish(2, 9), isFalse);
    expect(p.active, isFalse);
  });
  test(
    'controller records traversal, freezes pause and restores without replay',
    () async {
      final route = await OriginalRoute.load(),
          scores = await ScoreLibrary.load();
      final game = GameController(scores, route: route)
        ..start()
        ..enterLevel(1)
        ..sceneReady();
      game.update(.1);
      expect(game.sceneProgress.kind, 'enter');
      expect(game.sceneProgress.lit, 1);
      game.pause();
      final age = game.sceneProgress.age;
      game.update(.1);
      expect(game.sceneProgress.age, age);
      game.resume();
      game.solved.add(1);
      game.update(.1);
      expect(
        game.sceneProgress.done,
        isEmpty,
        reason: 'melody completion is before crossing',
      );
      game.hedgehog!.finish();
      game.x = route.segments[1].goalX + .2;
      game.y = route.segments[1].oy;
      game.vx = game.vy = 0;
      game.grounded = true;
      game.update(.1);
      expect(game.sceneProgress.done, {1});
      expect(game.sceneProgress.kind, 'done');
      expect(game.sceneProgress.current, 2);
      final saved = game.toJson();
      final restored = GameController(scores, route: route)
        ..restore(saved)
        ..start()
        ..sceneReady();
      expect(restored.sceneProgress.done, {1});
      restored.update(.1);
      expect(restored.sceneProgress.active, isFalse);
      game.start(restart: true);
      expect(game.sceneProgress.done, isEmpty);
      expect(game.sceneProgress.active, isFalse);
      game.dispose();
      restored.dispose();
    },
  );
}
