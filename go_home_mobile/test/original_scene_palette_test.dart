import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_palette.dart';
import 'package:go_home_mobile/game/original_route_palette.dart';

void main() {
  final base = OriginalPalette(
    jsonDecode(File('assets/data/original_palette.json').readAsStringSync()),
  );
  final palette = OriginalRoutePalette(base);
  final f = jsonDecode(
    File('test/fixtures/original_scene_palette.json').readAsStringSync(),
  );
  void compare(dynamic a, dynamic b, String why) {
    if (b is num) {
      expect(a, closeTo(b, 1e-9), reason: why);
    } else if (b is List) {
      for (var i = 0; i < b.length; i++) {
        compare(a[i], b[i], '$why [$i]');
      }
    } else if (b is Map) {
      for (final key in b.keys) {
        compare(a[key], b[key], '$why $key');
      }
    } else {
      expect(a, b, reason: why);
    }
  }

  test('all 14 source scene palette tweaks at 434 positions and times', () {
    for (final row in f['samples']) {
      compare(
        palette.local(
          row['id'],
          row['time'].toDouble(),
          row['x'].toDouble(),
          impact: row['impact'].toDouble(),
          endingBar: row['bar'].toDouble(),
        ),
        row['p'],
        '${row['id']} x=${row['x']}',
      );
    }
  });
  test('143 original linear scene blends with route adjustments', () {
    for (final row in f['blends']) {
      final x = row['x'].toDouble(), t = row['time'].toDouble();
      final p = palette.local(row['a'], t, x),
          q = palette.local(row['b'], t, x);
      OriginalRoutePalette.blend(p, q, row['k'].toDouble());
      base.routeAdjust(p, x);
      compare(p, row['p'], '${row['a']} ${row['b']} x=$x');
    }
  });
  test(
    'source monotonic time including backwards travel and explicit snaps',
    () {
      final clock = OriginalPaletteClock();
      for (final row in f['clocks']) {
        expect(
          clock.step(
            row['target'].toDouble(),
            row['dt'].toDouble(),
            snap: row['snap'],
          ),
          closeTo(row['t'], 1e-12),
        );
      }
    },
  );
}
