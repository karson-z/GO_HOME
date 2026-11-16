import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_bear_motion.dart';
import 'package:go_home_mobile/game/original_puppet_rig.dart';

void main() {
  final spec = jsonDecode(
    File('assets/characters/bear.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final scenarios = jsonDecode(
    File('test/fixtures/original_bear_motion.json').readAsStringSync(),
  ) as List;
  double smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double ground(double x) =>
      -1.75 * smooth(9.85, 10.55, x) * (1 - smooth(13.65, 14.35, x));
  for (final s in scenarios) {
    test('source bear full skeleton ${s['name']}', () {
      final rig = OriginalPuppetRig(spec);
      final motion = OriginalBearMotion(rig);
      var i = 0;
      for (final f in s['frames']) {
        final e = f['input'];
        double n(String k) => (e[k] as num).toDouble();
        final dt = n('dt');
        motion.step(
          BearMotionInput(
            dt: dt,
            x: n('x'),
            y: n('y'),
            mode: e['mode'],
            face: n('face'),
            puff: n('puff'),
            sniff: n('sniffT'),
            keys: n('keys'),
            arc: n('arcT'),
            girlOnBack: e['girlOnBack'],
            girlX: n('girlX'),
            girlY: n('girlY'),
            hasSit: e['hasSit'],
            bank: s['name'] == 'bank'
                ? BearBank(
                    ground: ground,
                    minX: 10,
                    maxX: 14.2,
                    fordY: -1.115,
                    waterY: -.35,
                  )
                : null,
          ),
        );
        rig.update(dt.clamp(0, .1));
        final state = f['state'];
        final values = {
          'phase': motion.phase,
          'vf': motion.vf,
          'facing': motion.facing,
          'pitch': motion.lastPitch,
          'hipY': motion.hipY,
          'shoulderY': motion.shoulderY,
        };
        for (final e in values.entries) {
          expect(
            e.value,
            closeTo(state[e.key], 1e-7),
            reason: '${s['name']} frame $i ${e.key}',
          );
        }
        expect(
          motion.bodyFrame,
          state['bodyFrame'],
          reason: 'frame $i bodyFrame',
        );
        expect(
          motion.footfalls,
          state['footfalls'],
          reason: 'frame $i footfalls',
        );
        expect(rig.rx, closeTo(f['root'][0], 1e-7), reason: 'frame $i root.x');
        expect(rig.ry, closeTo(f['root'][1], 1e-7), reason: 'frame $i root.y');
        for (final e in (f['out'] as Map).entries) {
          final node = rig.nodes[e.key]!, j = node.joint;
          final actual = {
            'x': j.x,
            'y': j.y,
            'rot': j.rot,
            'sx': j.sx,
            'sy': j.sy,
          };
          for (final a in actual.entries) {
            expect(
              a.value,
              closeTo(e.value[a.key], 1e-7),
              reason: '${s['name']} frame $i ${e.key}.${a.key}',
            );
          }
          expect(
            node.frame,
            e.value['frame'],
            reason: 'frame $i ${e.key}.frame',
          );
          expect(
            node.visible,
            e.value['visible'],
            reason: 'frame $i ${e.key}.visible',
          );
        }
        i++;
      }
    });
  }
}
