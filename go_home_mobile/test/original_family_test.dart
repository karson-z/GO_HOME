import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_family.dart';

void main() {
  final data = Map<String, dynamic>.from(
    jsonDecode(File('assets/data/original_boy_motion.json').readAsStringSync()),
  );
  final scenarios = jsonDecode(
    File('test/fixtures/original_family.json').readAsStringSync(),
  ) as List;
  for (final s in scenarios) {
    test('source family skeleton and anchors ${s['who']}', () {
      final who = s['who'] as String,
          name = who == 'soul' ? 'boy' : 'fam2-$who';
      final spec = Map<String, dynamic>.from(
        jsonDecode(File('assets/characters/$name.json').readAsStringSync()),
      );
      final a = OriginalFamily(who, spec, data);
      var frame = 0;
      for (final f in s['frames']) {
        double n(dynamic v) => (v as num? ?? 0).toDouble();
        final p = f['input'], reach = <String, FamilyReach>{};
        for (final r in p['reach'] as List? ?? []) {
          reach[r['side']] = (
            p: (x: n(r['p']['x']), y: n(r['p']['y'])),
            weight: n(r['w']),
            palm: r['palm'] == null ? null : n(r['palm']),
          );
        }
        a.update(
          time: n(p['time']),
          x: n(p['x']),
          y: n(p['y']),
          face: n(p['face']),
          groundAt: (x) => math.sin(x * .7) * .03,
          sit: n(p['sit']?['k']),
          slump: n(p['sit']?['slump']),
          lean: n(p['lean']),
          reach: reach,
          look: p['look'] == null
              ? null
              : (x: n(p['look']['x']), y: n(p['look']['y'])),
          shrink: n(p['shrink']),
        );
        for (final entry in (f['out'] as Map).entries) {
          final j = a.rig.joints[entry.key]!;
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
              closeTo(entry.value[key], 2e-7),
              reason: '$who frame $frame ${entry.key}.$key',
            );
          }
        }
        for (final entry in (f['points'] as Map).entries) {
          final actual = a.point(entry.key);
          expect(
            actual.x,
            closeTo(entry.value['x'], 2e-7),
            reason: '$who frame $frame ${entry.key}.x',
          );
          expect(
            actual.y,
            closeTo(entry.value['y'], 2e-7),
            reason: '$who frame $frame ${entry.key}.y',
          );
        }
        frame++;
      }
    });
  }
}
