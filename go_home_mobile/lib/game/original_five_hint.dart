import 'dart:math' as math;

import 'original_hint_motion.dart';
import 'original_music_box_hint.dart';
import 'player_physics.dart';

/// Original WC: a separate music box teaching the woodpecker's single key.
class OriginalFiveHint {
  double time = 0, alpha = 0, digitAlpha = 0, flash = 0, dx = 0;
  double x = 0, y = 0;
  bool was = false;
  final sparks = <({double x, double y, double vx, double vy, double age})>[];
  void press() {
    if (alpha < .05) return;
    flash = 1;
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2 + .4;
      sparks.add((
        x: x,
        y: y,
        vx: math.cos(a) * .7,
        vy: math.sin(a) * .7 + .3,
        age: 0,
      ));
    }
  }

  List<HintDraw> update(
    double dt,
    bool shown,
    PlayerState p,
    HintBounds view, {
    double? beat,
  }) {
    time += dt;
    if (shown && !was) {
      final left = view.x0 + (view.x1 - view.x0) * .08;
      final right = view.x1 - (view.x1 - view.x0) * .08;
      dx = p.x - .4 < left
          ? left - (p.x - .4)
          : p.x + .4 > right
          ? right - (p.x + .4)
          : 0;
    }
    was = shown;
    alpha = shown ? math.min(1, alpha + dt / .4) : math.max(0, alpha - dt / .3);
    x = p.x + dx;
    final base = p.y + 1.55;
    final phase = ((((beat ?? time / .5) % 1) + 1) % 1) * .5;
    final u = (phase - .09) / .41;
    final hop = phase < .09 ? 0.0 : .26 * 4 * u * (1 - u);
    final squash = phase < .09
        ? 1 - math.sin(math.pi * phase / .09) * .22
        : 1.0;
    y = base + .28 - .13 + hop + .36 / 2 * squash;
    digitAlpha = shown
        ? alpha
        : math.max(0, math.min(alpha, digitAlpha - dt / .1));
    flash = math.max(0, flash - dt / .35);
    final out = [
      HintDraw(
        'five-lid',
        x,
        base + .56 / 2 - .015,
        .8,
        .56,
        alpha,
        z: .7,
        order: 14,
      ),
      HintDraw(
        'five-digit',
        x,
        y,
        .54 * (2 - squash),
        .54 * squash,
        digitAlpha,
        z: .71,
        order: 15,
      ),
      HintDraw(
        'five-box',
        x,
        base + .56 / 2 - .015,
        .8,
        .56,
        alpha,
        z: .7,
        order: 16,
      ),
      HintDraw(
        'five-lit',
        x,
        y,
        .54 * (2 - squash),
        .54 * squash,
        digitAlpha * flash,
        z: .71,
        order: 17,
        additive: true,
      ),
    ];
    for (var i = 0; i < sparks.length; i++) {
      final s = sparks[i], age = s.age + dt;
      final next = (
        x: s.x + s.vx * dt,
        y: s.y + s.vy * dt,
        vx: s.vx,
        vy: s.vy - 1.2 * dt,
        age: age,
      );
      sparks[i] = next;
      out.add(
        HintDraw(
          'five-spark',
          next.x,
          next.y,
          .09,
          .09,
          math.max(0, 1 - age / .35) * alpha,
          color: 0xe8f4ff,
          additive: true,
          order: 18,
          z: .71,
        ),
      );
    }
    sparks.removeWhere((s) => s.age >= .35);
    return out;
  }
}
