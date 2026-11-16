import 'dart:math' as math;
import 'dart:typed_data';

import 'original_ending_flight.dart';

/// Fog-look iy texture. Keep byte quantisation and linear filtering: an
/// analytic radial gradient has a different centre and falloff.
Uint8List originalFireflyTexture() {
  final bytes = Uint8List(64 * 64 * 4);
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      final dx = (x + .5) / 64 - .5, dy = (y + .5) / 64 - .5;
      final r = math.min(1.0, math.sqrt(dx * dx + dy * dy) * 2);
      final v = math
          .min(
            255.0,
            (math.pow(1 - r, 3) * .75 +
                    math.pow(math.max(0, 1 - r * 3.2), 2) * .6) *
                255,
          )
          .toInt();
      final offset = (y * 64 + x) * 4;
      bytes[offset] = bytes[offset + 1] = bytes[offset + 2] = v;
      bytes[offset + 3] = 255;
    }
  }
  return bytes;
}

typedef FireflyLightSize = ({
  double glow,
  double core,
  double coreAlpha,
  double amber,
  double amberAlpha,
  bool amberVisible,
});

/// Source fog-look ay, including its 0.4 opening scale and return-loop fade.
FireflyLightSize originalFireflySize({
  required double distance,
  required double glow,
  double? returningTime,
  double loopDuration = 16,
}) {
  final returning = returningTime != null;
  final p = returning ? distance : math.max(4.0, distance);
  final d = returning
      ? ((returningTime - (loopDuration - 2.2)) / 2.2).clamp(0.0, 1.0)
      : 1.0;
  final m =
      .3 *
      (p / 14 + .45) *
      (returning ? .9 + .2 * glow : .75 + .35 * glow) *
      (1 - .6 * d * d * (3 - 2 * d));
  final h = returning
      ? ((returningTime - (loopDuration - 1)) / 1).clamp(0.0, 1.0)
      : 1.0;
  return (
    glow: m * 2,
    core:
        math.max(.3, m * .72) *
        (p / 22 + .35) *
        (returning ? 1 : .8 + .2 * glow),
    coreAlpha: returning ? .95 : .6 + .35 * glow,
    amber: m * 1.6 * (p / 22 + .35),
    amberAlpha: (.55 + .4 * glow) * h,
    amberVisible: h > .002,
  );
}

/// Source fog-look ly, the first walk's hide/lead/gone controller.
class OriginalLeadFirefly {
  OriginalLeadFirefly({
    required this.groundAt,
    this.ox = 0,
    this.logAt = 56.5,
    this.logLength = .8,
    this.logTop = .62,
  });
  final double Function(double) groundAt;
  final double ox, logAt, logLength, logTop;
  double time = 0, opacity = 0, light = 0;
  String phase = 'hide';
  bool sawOpening = false, visible = false;
  EndingPoint? origin;
  EndingPoint position = (x: 0, y: 0, z: 0);

  void update(
    double dt,
    double playerX, {
    EndingPoint? opening,
    bool endingActive = false,
  }) {
    time += dt;
    if (opening != null) {
      sawOpening = true;
      origin = opening;
      phase = 'hide';
    }
    if (opening != null || endingActive || playerX > 78.5 || playerX < ox - 2) {
      visible = false;
      opacity = light = 0;
      if (opening != null || playerX < ox + 20) phase = 'hide';
      return;
    }
    if (origin == null ||
        (!sawOpening && phase == 'hide' && (origin!.x - playerX).abs() > 12)) {
      origin = (x: playerX + 5, y: groundAt(playerX + 5) + .35, z: -1.4);
    }
    double x, y, z, alpha;
    if (phase == 'hide') {
      x = origin!.x;
      y = groundAt(x) + .35;
      z = -1.4;
      alpha = .25 + .2 * math.max(0, math.sin(time * 2.3));
      if (playerX > x - 3.2) phase = 'lead';
      if (position.x == 0) position = (x: x, y: y, z: z);
    } else {
      x = math.min(playerX + 4.2, 72.5);
      y = groundAt(x) + 1.15 + .14 * math.sin(time * 2.1);
      z = -.6 + .25 * math.sin(time * .7);
      final left = ox + logAt - logLength / 2;
      final right = ox + logAt + logLength / 2;
      if (playerX < left - .2 && x > left - .6) {
        x = (left + right) / 2;
        y = groundAt(left - .5) + logTop + 1.35 + .12 * math.sin(time * 2.6);
        z = -.3;
      }
      final merge = endingSmooth((playerX - 60) / 8);
      if (merge > 0) {
        x += (72.5 - x) * merge;
        y += (groundAt(72.5) + 1.7 - y) * merge;
        z += (-1.3 - z) * merge;
      }
      alpha =
          (.7 + .25 * math.max(0, math.sin(time * 3.1))) *
          (1 - endingSmooth((playerX - 66) / 5));
      if (alpha < .01 && playerX > 70) phase = 'gone';
    }
    final smoothing = 1 - math.exp(-dt * (phase == 'hide' ? 6 : 1.8));
    final dx = (x - position.x) * smoothing,
        dy = (y - position.y) * smoothing,
        dz = (z - position.z) * smoothing;
    final speed = math.sqrt(dx * dx + dy * dy) / math.max(dt, .001);
    final limit = speed > 4.5 ? 4.5 / speed : 1;
    position = (
      x: position.x + dx * limit,
      y: position.y + dy * limit,
      z: position.z + dz * limit,
    );
    opacity += (alpha - opacity) * (1 - math.exp(-dt * 4));
    light = phase == 'lead' ? opacity : opacity * .4;
    visible = opacity > .01;
  }
}
