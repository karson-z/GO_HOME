import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_firefly_light.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/original_firefly_light.json').readAsStringSync(),
  );
  test('fog-look iy light texture matches every source byte', () {
    expect(originalFireflyTexture(), base64Decode(fixture['texture']));
  });
  test(
    'ay opening/returning sizes match the source at 41 camera/glow states',
    () {
      for (final row in fixture['size']) {
        final size = originalFireflySize(
          distance: (row['distance'] as num).toDouble(),
          glow: (row['glow'] as num).toDouble(),
          returningTime: (row['returningTime'] as num?)?.toDouble(),
        );
        expect(size.amberVisible, row['size']['amberVisible']);
        final actual = {
          'glow': size.glow,
          'core': size.core,
          'coreAlpha': size.coreAlpha,
          'amber': size.amber,
          'amberAlpha': size.amberAlpha,
        };
        for (final e in actual.entries) {
          expect(e.value, closeTo(row['size'][e.key], 1e-12), reason: '$row');
        }
      }
    },
  );
  test(
    'ly approach, log crossing, retreat and ending match 1800 source frames',
    () {
      final lead = OriginalLeadFirefly(
        groundAt: (x) => 10 - math.max(0, math.min(28, x - 20)) * .125,
      );
      var frame = 0;
      for (final row in fixture['frames']) {
        final o = row['opening'];
        lead.update(
          (row['dt'] as num).toDouble(),
          (row['x'] as num).toDouble(),
          opening: o == null
              ? null
              : (
                  x: (o['x'] as num).toDouble(),
                  y: (o['y'] as num).toDouble(),
                  z: (o['z'] as num).toDouble(),
                ),
          endingActive: row['endingActive'],
        );
        expect(lead.visible, row['visible'], reason: 'frame $frame');
        if (lead.visible) {
          expect(
            lead.position.x,
            closeTo(row['position']['x'], 1e-10),
            reason: 'x $frame',
          );
          expect(
            lead.position.y,
            closeTo(row['position']['y'], 1e-10),
            reason: 'y $frame',
          );
          expect(
            lead.position.z,
            closeTo(row['position']['z'], 1e-10),
            reason: 'z $frame',
          );
          expect(.75 * lead.opacity, closeTo(row['alpha'], 1e-12));
          expect(.95 * lead.opacity, closeTo(row['coreAlpha'], 1e-12));
        }
        if (row['light'] != null) {
          expect(.45 * lead.light, closeTo(row['light']['k'], 1e-12));
        } else {
          expect(lead.light, lessThanOrEqualTo(.02));
        }
        frame++;
      }
    },
  );
}
