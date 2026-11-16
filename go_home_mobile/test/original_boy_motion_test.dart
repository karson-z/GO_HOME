import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_boy_motion.dart';

void compare(dynamic actual, dynamic expected, String path) {
  if (expected is num) {
    expect(actual, closeTo(expected, 1e-10), reason: path);
  } else if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    for (final key in expected.keys) {
      compare(actual[key], expected[key], '$path.$key');
    }
  } else if (expected is List) {
    for (var i = 0; i < expected.length; i++) {
      compare(actual[i], expected[i], '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

void main() {
  final spec = Map<String, dynamic>.from(
    jsonDecode(File('assets/data/original_boy_motion.json').readAsStringSync()),
  );
  final scenarios = jsonDecode(
    File('test/fixtures/original_boy_motion.json').readAsStringSync(),
  ) as List;
  for (final s in scenarios) {
    test('boy source animation ${s['mode']} / ${s['wind']}', () {
      final anim = OriginalBoyMotion(
        spec,
        mode: s['mode'],
        jumpWind: s['wind'],
      );
      var frame = 0;
      for (final f in s['frames']) {
        final p = f['p'], pose = p['pose'];
        double n(dynamic x) => (x as num).toDouble();
        if (f['strum']) anim.strum();
        final out = anim.step(
          n(f['dt']),
          BoyMotionInput(
            vx: n(p['vx']),
            vy: n(p['vy']),
            grounded: p['grounded'],
            facing: n(p['facing']),
            lead: p['lead'],
            wind: n(p['wind']),
            reach: n(pose['reach']),
            lean: n(pose['lean']),
            strain: n(pose['strain']),
            shake: n(pose['shake']),
          ),
        );
        compare(out.toJson(), f['out'], 'frame ${frame++}');
      }
    });
  }
}
