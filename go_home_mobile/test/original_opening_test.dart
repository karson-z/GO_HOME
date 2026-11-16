import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_opening.dart';

void main() {
  test('stand-up authored Hermite joints match source at 2001 positions', () {
    final data = jsonDecode(
      File('assets/data/original_mechanisms.json').readAsStringSync(),
    );
    final opening = OriginalOpening(Map<String, dynamic>.from(data['opening']))
      ..goAt = 0;
    final frames = jsonDecode(
      File('test/fixtures/original_opening.json').readAsStringSync(),
    ) as List;
    for (final f in frames) {
      opening.time = .9 + (f['u'] as num) * 1.6;
      final rot = opening.riseRot;
      for (final e in (f['rot'] as Map).entries) {
        expect(rot[e.key], closeTo(e.value, 1e-12));
      }
      expect(rot['head'], closeTo(f['head'], 1e-12));
    }
  });
  test(
    'opening waits for arrival, then wakes, stands and walks before controls',
    () {
      final o = OriginalOpening({
        'tree': {'sitDx': .78},
      });
      expect(o.menuAlpha, 0);
      o.time = 7;
      expect(o.menuAlpha, 1);
      o.begin();
      expect(o.sleep, 1);
      expect(o.walking, false);
      o.time += 2.5;
      expect(o.rise, 1);
      expect(o.walking, true);
      o.time += 2;
      expect(o.finished, true);
      expect(o.boyX, closeTo(5.68, 1e-12));
    },
  );
}
