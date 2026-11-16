import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/boy_kinematics.dart';
import 'package:go_home_mobile/game/original_boy_motion.dart';
import 'package:go_home_mobile/game/original_boy_runtime.dart';
import 'package:go_home_mobile/game/original_opening_pose.dart';

void main() {
  test('complete sleep/rise blend matches source Bi/eM at 1320 frames', () {
    dynamic read(String path) => jsonDecode(File(path).readAsStringSync());
    final spec = read('assets/characters/boy.json');
    final motion = read('assets/data/original_boy_motion.json');
    final config = read('assets/data/original_config.json');
    for (final scenario in read('test/fixtures/original_opening_pose.json')) {
      final rig = BoyKinematics(Map<String, dynamic>.from(spec));
      final player = OriginalBoyRuntime(rig, Map<String, dynamic>.from(motion));
      final opening = OriginalOpeningPose({
        'riseKeys': config['core_Wj'],
        'sleepPose': config['core_Uj'],
      });
      var frame = 0;
      for (final f in scenario['frames']) {
        player.step(
          (f['dt'] as num).toDouble(),
          const BoyMotionInput(),
          x: 0,
          y: 0,
          groundAt: (_) => 0,
        );
        opening.apply(
          rig,
          weight: (f['weight'] as num).toDouble(),
          sleep: (f['sleep'] as num).toDouble(),
          rise: (f['rise'] as num?)?.toDouble(),
        );
        for (final entry in (f['out'] as Map).entries) {
          final j = rig.joints[entry.key]!, expected = entry.value;
          for (final value in {
            'x': j.x,
            'y': j.y,
            'rot': j.rot,
            'sx': j.sx,
            'sy': j.sy,
          }.entries) {
            expect(
              value.value,
              closeTo(expected[value.key], 1e-8),
              reason: '${scenario['mode']} $frame ${entry.key}.${value.key}',
            );
          }
        }
        frame++;
      }
    }
  });
}
