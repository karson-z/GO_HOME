import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_boy_motion.dart';
import 'package:go_home_mobile/game/original_boy_gait.dart';
import 'package:go_home_mobile/game/boy_kinematics.dart';

void main() {
  final config = Map<String, dynamic>.from(
    jsonDecode(File('assets/data/original_boy_motion.json').readAsStringSync()),
  );
  final spec = Map<String, dynamic>.from(
    jsonDecode(File('assets/characters/boy.json').readAsStringSync()),
  );
  final scenarios = jsonDecode(
    File('test/fixtures/original_boy_gait.json').readAsStringSync(),
  ) as List;
  for (final s in scenarios) {
    test('source full-body gait ${s['terrain']}', () {
      final rig = BoyKinematics(spec), anim = OriginalBoyMotion(config);
      final gait = OriginalBoyGait(rig, config);
      gait.groundAt = (x) => s['terrain'] == 'flat'
          ? 0
          : s['terrain'] == 'slope'
          ? math.sin(x * .5) * .15
          : (x / 1.5).floor() * .025;
      var i = 0;
      for (final f in s['frames']) {
        double n(dynamic value) => (value as num).toDouble();
        final p = f['p'], pose = p['pose'], frame = f['frame'];
        BoyMotionInput input(bool grounded) => BoyMotionInput(
          vx: n(p['vx']),
          vy: n(p['vy']),
          grounded: grounded,
          facing: n(p['facing']),
          wind: n(p['wind']),
          lean: n(pose['lean']),
          reach: n(pose['reach']),
        );
        if (f['strum']) anim.strum();
        final a = anim.step(n(f['dt']), input(p['grounded']));
        rig.apply(a);
        gait.snapAnim();
        gait.step(
          n(f['dt']),
          input(
            a.windup != null && a.windup!['phase'] != 'release' && p['grounded']
                ? false
                : p['grounded'],
          ),
          BoyGaitFrame(
            n(frame['rootX']),
            n(frame['rootY']),
            n(frame['facing']),
            n(frame['turnX']),
          ),
          a,
        );
        expect(gait.mode, f['state']['mode'], reason: 'frame $i mode');
        expect(
          gait.phase,
          closeTo(f['state']['phase'], 1e-10),
          reason: 'frame $i phase',
        );
        for (final e in (f['out'] as Map).entries) {
          final j = rig.joints[e.key]!;
          final actual = {
            'x': j.x,
            'y': j.y,
            'rot': j.rot,
            'sx': j.sx,
            'sy': j.sy,
          };
          for (final key in actual.keys) {
            expect(
              actual[key],
              closeTo(e.value[key], 1e-7),
              reason: '${s['terrain']} frame $i ${e.key}.$key',
            );
          }
        }
        i++;
      }
    });
  }
}
