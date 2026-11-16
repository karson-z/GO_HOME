import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_ending_dog_motion.dart';
import 'package:go_home_mobile/game/original_puppet_rig.dart';

void main() {
  test('source IE dog: 1080 gait, turn, inertia and action frames', () {
    final frames = jsonDecode(
      File('test/fixtures/original_ending_dog_motion.json').readAsStringSync(),
    ) as List;
    final rig = OriginalPuppetRig(
      jsonDecode(File('assets/characters/fam-dog.json').readAsStringSync()),
    );
    final motion = OriginalEndingDogMotion(rig);
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i], input = f['input'];
      double n(String key) => (input[key] as num).toDouble();
      if (f['hidden']) {
        motion.hide();
      } else {
        motion.drive(
          x: n('x'),
          y: n('y'),
          z: n('z'),
          face: n('face'),
          act: input['act'],
          k: n('k'),
          time: n('time'),
          dt: n('dt'),
          groundY: n('groundY'),
          alpha: n('alpha'),
          lift: n('lift'),
          v: (input['v'] as num?)?.toDouble(),
          mode: input['mode'],
          touchKey: input['touchKey'],
        );
      }
      for (final e in {
        'dist': motion.dist,
        'vS': motion.vS,
        'shownFor': motion.shownFor,
      }.entries) {
        expect(
          e.value,
          closeTo(f['state'][e.key], 1e-9),
          reason: 'frame $i ${e.key}',
        );
      }
      expect(motion.shown, f['state']['shown']);
      expect(motion.act, f['state']['act']);
      expect(motion.mode, f['state']['mode']);
      expect(motion.touchKey, f['state']['touchKey']);
      if (f['hidden']) continue;
      for (final (value, target) in [
        (motion.x, f['position'][0]),
        (motion.y, f['position'][1]),
        (motion.z, f['position'][2]),
        (rig.facing, f['facing']),
        (rig.squash, f['squash']),
        (motion.opacity, f['opacity']),
        (motion.lift, f['lift']),
        (motion.footY, f['footY']),
      ]) {
        expect(value, closeTo(target, 1e-9), reason: 'frame $i actor');
      }
      expect(rig.squash >= .12, f['flipVisible']);
      for (final entry in (f['out'] as Map).entries) {
        final p = rig.nodes[entry.key]!.joint;
        for (final e in {
          'x': p.x,
          'y': p.y,
          'rot': p.rot,
          'sx': p.sx,
          'sy': p.sy,
        }.entries) {
          expect(
            e.value,
            closeTo(entry.value[e.key], 1e-9),
            reason: 'frame $i ${entry.key}.${e.key}',
          );
        }
      }
    }
  });
}
