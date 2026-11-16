import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_firefly.dart';
import 'package:go_home_mobile/game/original_firefly_motion.dart';

void main() {
  test('seven fireflies match source By poses and offsets for 5040 frames', () {
    final config = jsonDecode(
      File('assets/data/original_mechanisms.json').readAsStringSync(),
    )['firefly'];
    final calls =
        jsonDecode(File('assets/data/calls.json').readAsStringSync()) as Map;
    final scores = ScoreLibrary(
      calls.map(
        (id, c) => MapEntry(
          id,
          Melody(id, [
            for (var i = 0; i < c['keys'].length; i++)
              CallNote(
                c['keys'][i],
                (c['notes'][i]['bar'] * 16 + c['notes'][i]['step']).toDouble(),
                (c['notes'][i]['len'] as num).toDouble(),
              ),
          ]),
        ),
      ),
    );
    final state = OriginalFirefly(Map<String, dynamic>.from(config), scores);
    final motions = List.generate(7, (_) => OriginalFireflyMotion());
    final frames = jsonDecode(
      File('test/fixtures/original_firefly_motion.json').readAsStringSync(),
    );
    var frame = 0;
    for (final row in frames) {
      state.phase = row['phase'];
      state.phaseTime = (row['phaseTime'] as num).toDouble();
      for (var i = 0; i < 7; i++) {
        final f = state.flies[i], input = row['flies'][i], ref = row['out'][i];
        f.x = (input['x'] as num).toDouble();
        f.y = (input['y'] as num).toDouble();
        f.flash = (input['flash'] as num).toDouble();
        f.hurt = (input['hurt'] as num).toDouble();
        f.back = (input['back'] as num).toDouble();
        f.visibility = (input['vis'] as num).toDouble();
        f.gone = input['gone'];
        f.scout = input['scout'] == null
            ? null
            : (FireflyScout(0, 0, 0, 0)
                ..time = (input['scout']['t'] as num).toDouble());
        final pose = motions[i].step(
          state,
          i,
          f.flash,
          (row['dt'] as num).toDouble(),
          (row['time'] as num).toDouble(),
          flashUp: row['up'][i],
          cymbal: row['cym'],
        );
        for (final r in pose.rot.entries) {
          expect(
            r.value,
            closeTo(ref['rot'][r.key]['rot'], 1e-10),
            reason: '$frame/$i ${r.key}',
          );
        }
        final actual = {
          'offsetX': pose.offsetX,
          'offsetY': pose.offsetY,
          'lanternScale': pose.lanternScale,
          'light': pose.light,
          'wake': pose.wake,
          'opacity': pose.opacity,
          'facing': pose.turn.facing,
          'squash': pose.turn.squash,
          'headMirror': pose.turn.headMirror,
          'headSquash': pose.turn.headSquash,
        };
        final expected = {
          'offsetX': ref['off']['x'],
          'offsetY': ref['off']['y'],
          'lanternScale': ref['rot']['lantern']['sx'],
          'light': ref['light'],
          'wake': ref['wake'],
          'opacity': ref['opacity'],
          ...ref['turn'],
        };
        for (final e in actual.entries) {
          expect(
            e.value,
            closeTo(expected[e.key], 1e-10),
            reason: '$frame/$i ${e.key}',
          );
        }
        expect(pose.front, ref['front'], reason: '$frame/$i front');
        expect(pose.visible, ref['visible']);
      }
      frame++;
    }
  });
}
