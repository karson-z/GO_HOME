import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_route_environment.dart';
import 'package:go_home_mobile/game/original_route_music.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/original_route_environment.json').readAsStringSync(),
  );
  test(
    'source as/Et/Dt beds, oneshots, pan, filter and deterministic drips',
    () {
      final data = jsonDecode(
        File('assets/data/original_route_audio.json').readAsStringSync(),
      );
      final layout = jsonDecode(
        File('assets/data/original_route.json').readAsStringSync(),
      )['layout'];
      final music = OriginalRouteMusic(data, layout);
      final shots = <RouteEnvironmentShot>[];
      final environment = OriginalRouteEnvironment(music, onShot: shots.add);
      for (final f in fixture['frames']) {
        final time = (f['time'] as num).toDouble();
        music.time = time;
        if (f['changed']) {
          environment.switchBed(f['scene'], time ~/ 2, 8);
        }
        environment.meter((f['lufs'] as num?)?.toDouble());
        environment.update((f['x'] as num).toDouble(), f['inZone']);
        final why = 'at $time, ${f['scene']} x=${f['x']}';
        expect(environment.targetLufs, f['target'], reason: why);
        expect(
          environment.offsetDb,
          closeTo(f['offsetDb'], 1e-10),
          reason: why,
        );
        expect(environment.nextAt.keys, (f['nextAt'] as Map).keys, reason: why);
        for (final e in environment.nextAt.entries) {
          expect(e.value, closeTo(f['nextAt'][e.key], 1e-9), reason: why);
        }
        final referenceShots = f['shots'] as List;
        expect(shots.length, referenceShots.length, reason: why);
        for (var i = 0; i < shots.length; i++) {
          final shot = shots[i], reference = referenceShots[i];
          expect(shot.file, reference['file'], reason: why);
          for (final e in {
            'time': shot.time,
            'gain': shot.gain,
            'pan': shot.pan,
            'cutoff': shot.cutoff,
            'rate': shot.rate,
          }.entries) {
            expect(
              e.value,
              closeTo(reference[e.key], 1e-9),
              reason: '${e.key} $why',
            );
          }
        }
        shots.clear();
        final loops = f['loops'] as List;
        expect(
          environment.loops.keys,
          unorderedEquals(loops.map((l) => l['file'])),
          reason: why,
        );
        for (final reference in loops) {
          final loop = environment.loops[reference['file']]!;
          expect(loop.gain, closeTo(reference['gain'], 1e-10), reason: why);
          expect(loop.pan, closeTo(reference['pan'], 1e-10), reason: why);
          expect(loop.cutoff, closeTo(reference['cutoff'], 1e-8), reason: why);
        }
      }
    },
  );

  test('source rs absolute/relative loudness gating and bounded history', () {
    final window = OriginalLoudnessWindow();
    for (final f in fixture['loudness']) {
      final time = (f['time'] as num).toDouble();
      if (!f['skip']) window.push(time, (f['energy'] as num).toDouble());
      for (final q in f['queries'] ?? []) {
        final got = window.lufs(time, (q['seconds'] as num).toDouble());
        expect(
          got,
          q['value'] == null ? isNull : closeTo(q['value'], 1e-10),
          reason: 't=$time window=${q['seconds']}',
        );
      }
    }
  });
}
