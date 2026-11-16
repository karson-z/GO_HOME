import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_turtle.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  final config = Map<String, dynamic>.from(
    jsonDecode(
      File('assets/data/original_mechanisms.json').readAsStringSync(),
    )['turtle'],
  );
  final fixtures = jsonDecode(
    File('test/fixtures/original_turtle.json').readAsStringSync(),
  ) as List;
  for (final f in fixtures) {
    test('source turtle mechanism: ${f['id']}', () {
      var turtle = OriginalTurtle(config);
      for (var frame = 0; frame < f['samples'].length; frame++) {
        final sample = f['samples'][frame], v = sample['player'];
        final p =
            PlayerState((v['x'] as num).toDouble(), (v['y'] as num).toDouble())
              ..safeX = (v['safeX'] as num).toDouble()
              ..safeY = (v['safeY'] as num).toDouble()
              ..grounded = v['grounded']
              ..coyote = (v['coyote'] as num).toDouble()
              ..vy = (v['vy'] as num).toDouble()
              ..jumping = v['jumping'];
        if (sample['surface'] != null) turtle.surface(sample['surface']);
        turtle.beforeStep(p, 1 / 60);
        final reason = '${f['id']} frame $frame';
        expect(turtle.side(p), sample['side'], reason: reason);
        expect(turtle.crossed, sample['crossed'], reason: reason);
        expect(p.y, closeTo(sample['result']['y'], 1e-9), reason: reason);
        expect(p.grounded, sample['result']['grounded'], reason: reason);
        for (var i = 0; i < turtle.shells.length; i++) {
          final s = turtle.shells[i], e = sample['shells'][i];
          for (final v in {
            'x': s.x,
            'top': s.top,
            'riseTime': s.riseTime,
            'riseFrom': s.riseFrom,
          }.entries) {
            expect(
              v.value,
              closeTo(e[v.key], 1e-9),
              reason: '$reason shell $i ${v.key}',
            );
          }
          expect(s.sink, closeTo(e['sink']['x'], 1e-9),reason:'$reason sink');
          expect(s.sinkVelocity, closeTo(e['sink']['v'], 1e-9),reason:'$reason sinkVelocity');
        }
        final ps = turtle.platforms;
        expect(ps.length, sample['platforms'].length, reason: reason);
        for (var i = 0; i < ps.length; i++) {
          expect(
            ps[i].top,
            closeTo(sample['platforms'][i]['maxY'], 1e-9),
            reason: reason,
          );
        }
        if (frame % 120 == 119) {
          turtle = OriginalTurtle(config)
            ..restore(jsonDecode(jsonEncode(turtle.toJson())));
        }
      }
    });
  }
}
