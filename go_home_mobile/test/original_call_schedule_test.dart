import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_call_music.dart';
import 'package:go_home_mobile/game/original_route_music.dart';

void main() {
  test('source Qt call, hum, cut and pending arbitration over 560 frames', () {
    final data = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/data/original_route_audio.json').readAsStringSync(),
      ),
    );
    final layout = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/data/original_route.json').readAsStringSync(),
      )['layout'],
    );
    final frames = jsonDecode(
      File('test/fixtures/original_call_schedule.json').readAsStringSync(),
    ) as List;
    final music = OriginalRouteMusic(data, layout);
    final calls = OriginalCallMusic(music);
    void compareRuns(List<RouteCallRun> actual, List expected, String reason) {
      expect(actual.length, expected.length, reason: reason);
      for (var i = 0; i < actual.length; i++) {
        final a = actual[i], e = expected[i];
        expect(a.animal, e['animal'], reason: reason);
        expect(a.hum, e['hum'], reason: reason);
        expect(
          a.start,
          closeTo((e['start'] as num).toDouble(), 1e-10),
          reason: reason,
        );
        expect(
          a.end,
          closeTo((e['end'] as num).toDouble(), 1e-10),
          reason: reason,
        );
        expect(a.cutAt, e['cutAt'], reason: reason);
      }
    }

    for (var i = 0; i < frames.length; i++) {
      final f = frames[i], op = f['op'];
      music.time = (f['time'] as num).toDouble();
      music.states.clear();
      for (final s in f['active']) {
        music.states[s['id']] = RouteLayerState(
          music.layers[s['id']]!,
          s['from'],
          untilBar: (s['until'] as num).toDouble(),
        );
      }
      switch (op['type']) {
        case 'sing':
          calls.sing(
            op['id'],
            (op['x'] as num).toDouble(),
            hum: op['hum'],
            fit: op['fit'],
            notBefore: (op['notBefore'] as num).toDouble(),
            fitWithin: (op['fitWithin'] as num?)?.toDouble(),
          );
        case 'cut':
          calls.cut(calls.runs[op['index']]);
        case 'stop':
          calls.stopPending(op['animal']);
      }
      final reason = 'source frame $i, ${op['type']} at ${f['time']}';
      compareRuns(calls.runs, f['runs'], reason);
      compareRuns(calls.singLog, f['log'], reason);
      expect(calls.humBlocked, f['blocked'], reason: reason);
      expect(
        calls.lastSing.keys,
        (f['last'] as List).map((s) => s['animal']),
        reason: reason,
      );
      for (final p in f['last']) {
        expect(calls.lastSing[p['animal']]!.time, p['time'], reason: reason);
        expect(calls.lastSing[p['animal']]!.x, p['x'], reason: reason);
      }
    }
  });
}
