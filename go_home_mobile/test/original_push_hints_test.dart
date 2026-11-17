import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_hint_motion.dart';
import 'package:go_home_mobile/game/original_pusher.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  final scenarios = jsonDecode(
    File('test/fixtures/original_push_hints.json').readAsStringSync(),
  ) as List;
  for (final s in scenarios) {
    test('push hint matches original Ky for ${s['id']}', () {
      double n(Map m, String key) => (m[key] as num).toDouble();
      final body = PushBody(
        s['id'],
        n(s, 'x'),
        n(s, 'y'),
        n(s, 'w'),
        n(s, 'h'),
      );
      final hint = OriginalPushHint(body);
      for (final f in s['frames']) {
        final b = f['body'] as Map, p = f['p'] as Map, e = f['out'] as Map;
        body
          ..x = n(b, 'x')
          ..y = n(b, 'y')
          ..enabled = b['enabled']
          ..alpha = n(b, 'alpha')
          ..fade = b['fade']
          ..pushing = b['pushing'];
        hint.update(
          n(f, 'dt'),
          PlayerState(n(p, 'x'), n(p, 'y'))..grounded = p['grounded'],
        );
        expect(hint.done, e['done'], reason: f['label']);
        expect(hint.on, e['on'], reason: f['label']);
        expect(hint.shows, e['shows'], reason: f['label']);
        for (final actual in {
          'a': hint.cap.a,
          'base': hint.cap.base,
          'dodge': hint.cap.dodge,
          'x': hint.cap.x,
          'y': hint.cap.y,
          'drawY': hint.cap.drawY,
          'w': hint.cap.w,
          'h': hint.cap.h,
        }.entries) {
          expect(
            actual.value,
            closeTo(n(e, actual.key), 1e-9),
            reason: '${f['label']} ${actual.key}',
          );
        }
      }
      expect(hint.done, isTrue);
    });
  }
}
