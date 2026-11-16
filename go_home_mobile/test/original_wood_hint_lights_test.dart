import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_caller.dart';
import 'package:go_home_mobile/game/original_wood_hint_lights.dart';
import 'package:go_home_mobile/game/original_woodpecker.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  final scores = ScoreLibrary({
    'woodpecker-v1': const Melody('woodpecker-v1', [
      CallNote(5, 0, 1),
      CallNote(5, 4, 1),
    ]),
  });
  const view = (x0: 0.0, x1: 30.0, y0: -2.0, y1: 8.0);
  final player = PlayerState(15, 0);

  test('wood cue positions and timing match original nT', () {
    final fixtures = jsonDecode(
      File('test/fixtures/original_wood_hint_cues.json').readAsStringSync(),
    ) as List;
    for (final f in fixtures) {
      final wood = OriginalWoodpecker(scores)
        ..mode = f['mode']
        ..window = null
        ..run = CallerRun(
          'sing',
          CallerSung([
            const CallerExpected(5, 6),
            const CallerExpected(5, 6.5),
          ], bar: 3),
        );
      wood.window = wood.makeWindow(10, 6);
      final lights = OriginalWoodHintLights();
      final draws = lights.update(
        wood,
        (f['now'] as num).toDouble(),
        0,
        player,
        view,
        100,
        20,
      );
      final expected = f['draw'] as List;
      expect(
        draws.length,
        expected.length,
        reason: '${f['mode']} at ${f['now']}',
      );
      void check(dynamic d, Map e) {
        final p = wood.transform(
          (e['x'] as num).toDouble(),
          (e['y'] as num).toDouble(),
        );
        expect(d.x, closeTo(100 + p.x, 1e-9));
        expect(d.y, closeTo(20 + p.y, 1e-9));
        expect(d.w, closeTo(e['w'], 1e-9));
        expect(d.alpha, closeTo(e['alpha'], 1e-9));
      }

      for (var i = 0; i < draws.length; i++) {
        check(draws[i], expected[i]);
      }
      if (f['approach'] == null) {
        expect(lights.approach, isNull);
      } else {
        check(lights.approach!, f['approach']);
        expect(lights.approach!.rotation, -wood.angle);
      }
    }
  });

  test('wood marks survive response and clear on a new demonstration', () {
    final wood = OriginalWoodpecker(scores)..mode = 'drum';
    wood.run = CallerRun(
      'sing',
      CallerSung([
        const CallerExpected(5, 6),
        const CallerExpected(5, 6.5),
      ], bar: 3),
    )..index = 2;
    final lights = OriginalWoodHintLights();
    lights.update(wood, 6.5, 1 / 60, player, view, 0, 0);
    expect(lights.marks.length, 2);
    wood.mode = 'listen';
    wood.window = wood.makeWindow(10, 6);
    expect(wood.note(5, 10), 'hit');
    lights.update(wood, 10, 1 / 60, player, view, 0, 0);
    expect(lights.marks.first.hit, isTrue);
    wood.note(2, 10.2);
    lights.update(wood, 10.2, 1 / 60, player, view, 0, 0);
    expect(lights.marks.last.wrong, isTrue);
    wood.run = CallerRun(
      'sing',
      CallerSung([const CallerExpected(5, 14)], bar: 7),
    )..index = 1;
    lights.update(wood, 14, 1 / 60, player, view, 0, 0);
    expect(lights.marks.length, 1);
    expect(lights.marks.single.hit, isFalse);
    expect(lights.marks.single.wrong, isFalse);
    expect(lights.fading.length, 2);
  });
}
