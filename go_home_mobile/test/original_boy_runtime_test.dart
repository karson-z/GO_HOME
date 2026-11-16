import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/boy_kinematics.dart';
import 'package:go_home_mobile/game/original_boy_motion.dart';
import 'package:go_home_mobile/game/original_boy_runtime.dart';

void main() {
  final config = Map<String, dynamic>.from(
    jsonDecode(File('assets/data/original_boy_motion.json').readAsStringSync()),
  );
  final spec = Map<String, dynamic>.from(
    jsonDecode(File('assets/characters/boy.json').readAsStringSync()),
  );
  final scenarios = jsonDecode(
    File('test/fixtures/original_boy_runtime.json').readAsStringSync(),
  ) as List;
  for (final s in scenarios) {
    test('complete source boy pipeline ${s['terrain']}', () {
      final rig = BoyKinematics(spec),
          runtime = OriginalBoyRuntime(rig, config);
      double ground(double x) => switch (s['terrain']) {
        'flat' => 0,
        'slope' => math.sin(x * .5) * .15,
        'steps' => (x / 1.5).floor() * .025,
        'live' => math.sin(x) * .1,
        _ => x > 3 ? -1 : 0,
      };
      var i = 0, serial = 0;
      for (final f in s['frames']) {
        double n(dynamic v) => (v as num).toDouble();
        final p = f['p'], pose = p['pose'];
        if (f['serial'] > serial) {
          runtime.motion.strum(f['serial'] - serial as int);
        }
        serial = f['serial'];
        runtime.step(
          n(f['dt']),
          BoyMotionInput(
            vx: n(p['vx']),
            vy: n(p['vy']),
            grounded: p['grounded'],
            facing: n(p['facing']),
            wind: n(p['wind']),
            lean: n(pose['lean']),
            reach: n(pose['reach']),
          ),
          x: n(p['x']),
          y: n(p['y']),
          groundAt: ground,
          live: s['terrain'] == 'live',
          jumpAir: p['jumpAir'],
          inset: n(pose['inset']),
        );
        expect(runtime.dx, closeTo(f['dx'], 1e-8), reason: 'frame $i dx');
        expect(runtime.dy, closeTo(f['dy'], 1e-8), reason: 'frame $i dy');
        expect(runtime.gait.mode, f['mode'], reason: 'frame $i mode');
        expect(
          runtime.gait.phase,
          closeTo(f['phase'], 1e-8),
          reason: 'frame $i phase',
        );
        expect(
          runtime.pose.turnX,
          closeTo(f['turn'], 1e-8),
          reason: 'frame $i turn',
        );
        for (final e in (f['out'] as Map).entries) {
          final j = rig.joints[e.key]!;
          final values = {
            'x': j.x,
            'y': j.y,
            'rot': j.rot,
            'sx': j.sx,
            'sy': j.sy,
          };
          for (final key in values.keys) {
            expect(
              values[key],
              closeTo(e.value[key], 2e-7),
              reason: '${s['terrain']} frame $i ${e.key}.$key',
            );
          }
        }
        i++;
      }
    });
  }
}
