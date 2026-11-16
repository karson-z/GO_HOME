import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_artist_firefly.dart';

void main() {
  test(
    'source sP/iP: 1800 firefly vector pose frames across all five moves',
    () {
      final data = jsonDecode(
        File('assets/characters/artist-firefly.json').readAsStringSync(),
      );
      final motion = OriginalArtistFirefly(
        Map<String, dynamic>.from(data['vectorParts']),
      );
      final frames = jsonDecode(
        File('test/fixtures/original_artist_firefly.json').readAsStringSync(),
      ) as List;
      for (var i = 0; i < frames.length; i++) {
        final f = frames[i];
        final p = motion.pose(
          (f['t'] as num).toDouble(),
          move: f['move'],
          climb: (f['climb'] as num).toDouble(),
          glow: (f['glow'] as num).toDouble(),
        );
        expect(p.glow, f['glow']);
        expect(p.lampX, closeTo(f['lamp']['x'], 1e-11), reason: '$i lampX');
        expect(p.lampY, closeTo(f['lamp']['y'], 1e-11), reason: '$i lampY');
        expect(p.parts.length, f['parts'].length);
        for (var j = 0; j < p.parts.length; j++) {
          final e = p.parts[j], r = f['parts'][j];
          expect(e.id, r['id']);
          expect(e.alpha, r['alpha']);
          expect(e.far, r['far']);
          expect(e.v, r['v']);
          expect(e.g, r['g']);
          expect(e.b, r['b']);
          for (var k = 0; k < 6; k++) {
            expect(
              e.matrix.values[k],
              closeTo(r['m'][k], 1e-11),
              reason: '$i ${e.id} matrix $k',
            );
          }
        }
      }
    },
  );
}
