import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_ending_flight.dart';

void main() {
  test('cloud camera, authored easing and firefly blink match source', () {
    final spec = jsonDecode(
      File('assets/data/original_mechanisms.json').readAsStringSync(),
    );
    final flight = OriginalEndingFlight(
      Map<String, dynamic>.from(spec['ending']['flight']),
    );
    final frames = jsonDecode(
      File('test/fixtures/original_ending_flight.json').readAsStringSync(),
    ) as List;
    final arrival = OriginalEndingArrival((x: 1.1, y: .405, z: .27));
    for (final frame in frames) {
      final time = (frame['t'] as num).toDouble();
      for (final key in ['loop', 'long', 'short']) {
        final p = flight.at(time, key), r = frame['paths'][key];
        final actual = [p.cx, p.cy, p.distance, p.pitch, p.fx, p.fy];
        final expected = [
          r['cx'],
          r['cy'],
          r['D'],
          r['pitch'],
          r['fx'],
          r['fy'],
        ];
        for (var i = 0; i < actual.length; i++) {
          expect(
            actual[i],
            closeTo(expected[i], 1e-10),
            reason: '$key at $time column $i',
          );
        }
        final shot = flight.camera(time, 15, -7, key);
        for (var i = 0; i < 3; i++) {
          expect(shot.pos[i], closeTo(r['camera']['pos'][i], 1e-10));
          expect(shot.look[i], closeTo(r['camera']['look'][i], 1e-10));
        }
      }
      expect(OriginalEndingFlight.title(time), closeTo(frame['title'], 1e-12));
      expect(
        OriginalEndingFlight.blink(time, .9),
        closeTo(frame['blink'], 1e-12),
      );
      expect(endingFlightEase(time / 30, 2, .4), closeTo(frame['ease'], 1e-12));
      final live = frame['live'], expected = frame['arrival'];
      final pos = arrival.at(
        time / 30,
        time,
        liveBox: (
          x: (live['x'] as num).toDouble(),
          y: (live['y'] as num).toDouble(),
          z: (live['z'] as num).toDouble(),
        ),
      );
      expect(pos.x, closeTo(expected['x'], 1e-10));
      expect(pos.y, closeTo(expected['y'], 1e-10));
      expect(pos.z, closeTo(expected['z'], 1e-10));
    }
  });
}
