import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_ending_animal_motion.dart';
import 'package:go_home_mobile/game/original_puppet_rig.dart';

void main() {
  final scenarios = jsonDecode(
    File('test/fixtures/original_ending_animal_motion.json').readAsStringSync(),
  ) as List;
  for (final scenario in scenarios) {
    test('source finale animal ${scenario['kind']} 480 skeleton frames', () {
      final rig = OriginalPuppetRig(
        jsonDecode(
          File('assets/characters/${scenario['art']}.json').readAsStringSync(),
        ),
      );
      final motion = OriginalEndingAnimalMotion(scenario['kind'], rig);
      var frame = 0;
      for (final f in scenario['frames']) {
        final input = f['input'];
        double n(String key) => (input[key] as num).toDouble();
        if (f['hidden']) {
          motion.hide();
        } else {
          motion.drive(
            x: n('x'),
            y: n('y'),
            z: n('z'),
            floorY: n('floorY'),
            progress: n('progress'),
            time: n('time'),
            dt: n('dt'),
            swapFx: input['swapFx'],
          );
        }
        final state = f['state'];
        for (final value in {
          'dist': motion.dist,
          'air': motion.air,
          'shownT': motion.shownT,
        }.entries) {
          expect(
            value.value,
            closeTo(state[value.key], 1e-9),
            reason: 'frame $frame ${value.key}',
          );
        }
        expect(motion.wasShown, state['wasShown']);
        if (!f['hidden']) {
          for (final (value, target) in [
            (motion.x, f['position'][0]),
            (motion.y, f['position'][1]),
            (motion.z, f['position'][2]),
            (motion.facing, f['facing']),
            (motion.opacity, f['opacity']),
            (motion.footY, f['footY']),
            (motion.clipY, f['clipY']),
            (motion.clipSoft, f['clipSoft']),
          ]) {
            expect(value, closeTo(target, 1e-9), reason: 'frame $frame actor');
          }
          for (final entry in (f['out'] as Map).entries) {
            final node = rig.nodes[entry.key]!,
                pose = node.joint,
                target = entry.value;
            for (final value in {
              'x': pose.x,
              'y': pose.y,
              'rot': pose.rot,
              'sx': pose.sx,
              'sy': pose.sy,
            }.entries) {
              expect(
                value.value,
                closeTo(target[value.key], 1e-9),
                reason: 'frame $frame ${entry.key}.${value.key}',
              );
            }
            expect(
              node.frame,
              target['frame'],
              reason: 'frame $frame ${entry.key}.frame',
            );
            expect(
              node.visible,
              target['visible'],
              reason: 'frame $frame ${entry.key}.visible',
            );
          }
        }
        frame++;
      }
    });
  }
}
