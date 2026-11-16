import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_ending_look.dart';

void main() {
  test('ending world colors match source OKLab fade at 601 times', () {
    final mechanisms = jsonDecode(
      File('assets/data/original_mechanisms.json').readAsStringSync(),
    );
    final fixture = jsonDecode(
      File('test/fixtures/original_ending_look.json').readAsStringSync(),
    );
    final look = OriginalEndingLook(
      Map<String, dynamic>.from(mechanisms['ending']['environment']),
    );
    void same(dynamic a, dynamic b, String key) {
      if (a is List && b is List) {
        for (var i = 0; i < a.length; i++) {
          same(a[i], b[i], '$key[$i]');
        }
      } else if (a is num && b is num) {
        expect(a, closeTo(b, 1e-7), reason: key);
      }
    }

    for (final frame in fixture['frames']) {
      final bar = (frame['bar'] as num).toDouble(),
          actual = look.at(Map<String, dynamic>.from(fixture['target']), bar);
      expect(look.fade(bar), closeTo(frame['fade'], 1e-12));
      for (final key in (frame['look'] as Map).keys) {
        same(actual[key], frame['look'][key], '$bar $key');
      }
    }
  });
}
