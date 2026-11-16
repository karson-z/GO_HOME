import 'dart:math' as math;

import 'original_hint_motion.dart';
import 'original_music_box_hint.dart';
import 'player_physics.dart';

class OriginalTalkMemory {
  bool used = false;
  int shows = 0;
}

/// Source Od with the default hand drawn ear strip. The shared memory limits
/// ear teaching across callers, while each caller keeps its own fade and dodge.
class OriginalTalkHint {
  double time = 0, alpha = 0, textBase = 0, textDodge = 1;
  double scale = 1, shiftX = 0, shiftY = 0, capShift = 0;
  bool wasOn = false, withText = false;
  String side = 'above', preferredSide = 'above';

  ({double dx, double dy}) _fit(HintBounds b, HintBounds view) {
    final width = view.x1 - view.x0, height = view.y1 - view.y0;
    final left = view.x0 + width * .08, right = view.x1 - width * .08;
    final dx = b.x1 - b.x0 > right - left
        ? (left + right - b.x0 - b.x1) / 2
        : b.x0 < left
        ? left - b.x0
        : b.x1 > right
        ? right - b.x1
        : 0.0;
    return (dx: dx, dy: math.min(0, view.y1 - height * .1 - b.y1));
  }

  List<HintDraw> update(
    double dt,
    OriginalHintCap cap,
    PlayerState player,
    HintBounds view,
    OriginalTalkMemory memory, {
    required double stripW,
    required double stripH,
    bool ear = true,
  }) {
    time += dt;
    final on = cap.want;
    if (on && !wasOn && ear) {
      withText = !memory.used && memory.shows < 2;
      if (withText) memory.shows++;
    }
    if (!on && alpha <= .001) withText = false;
    wasOn = on;
    alpha = on ? math.min(1, alpha + dt / .5) : math.max(0, alpha - dt / .25);
    // cap.y is Od's r-size/2+bob; strip placement uses the unanimated centre.
    final bob = math.sin(time * 2.2) * .05;
    var cx = cap.x;
    final cy = cap.y + .21 - bob;
    if (alpha <= .001 && on) {
      capShift = _fit((
        x0: cx - .24,
        x1: cx + .24,
        y0: cy - .24,
        y1: cy + .24,
      ), view).dx;
    }
    cx += capShift;
    cap.x = cx;
    final boy = hintBoyBox(player);
    HintBounds stripBox() {
      final w = stripW * scale, h = stripH * scale;
      if (side == 'above') {
        final bottom = cy + .21 + .1;
        return (x0: cx - w / 2, x1: cx + w / 2, y0: bottom, y1: bottom + h);
      }
      final sign = side == 'left' ? -1 : 1;
      final start = cx + sign * (.21 + .08), end = start + sign * w;
      return (
        x0: math.min(start, end),
        x1: math.max(start, end),
        y0: cy - h / 2,
        y1: cy + h / 2,
      );
    }

    cap.cap = 1 - textBase;
    cap.update(dt, player);
    textBase = on && withText
        ? math.min(1, textBase + dt / .5)
        : math.max(0, textBase - dt / .8);
    final before = stripBox();
    final hit =
        textBase > 0 &&
        hintOverlap((
          x0: before.x0 + shiftX,
          x1: before.x1 + shiftX,
          y0: before.y0 + shiftY,
          y1: before.y1 + shiftY,
        ), boy);
    textDodge = hit
        ? math.max(0, textDodge - dt / .12)
        : math.min(1, textDodge + dt / .3);
    if (textBase < .05) {
      scale = (.026 * (view.y1 - view.y0) / (.36 * .55)).clamp(1.0, 2.2);
      var best = double.infinity;
      var bestSide = 'above';
      var bestShift = (dx: 0.0, dy: 0.0);
      for (final next in [
        preferredSide,
        'above',
        preferredSide == 'left' ? 'right' : 'left',
      ]) {
        side = next;
        final shift = _fit(stripBox(), view);
        final score =
            shift.dx.abs() + shift.dy.abs() + (next == preferredSide ? 0 : .05);
        if (score < best) {
          best = score;
          bestSide = next;
          bestShift = shift;
        }
      }
      side = bestSide;
      shiftX = bestShift.dx;
      shiftY = bestShift.dy;
    }
    final b = stripBox();
    return [
      HintDraw(
        'talk',
        cap.x,
        cap.drawY,
        cap.w * cap.drawScale,
        cap.h * cap.drawScale,
        cap.a,
        z: cap.z,
      ),
      if (ear)
        HintDraw(
          'ear',
          (b.x0 + b.x1) / 2 + shiftX,
          (b.y0 + b.y1) / 2 + shiftY + bob,
          stripW * scale,
          stripH * scale,
          math.min(textBase, alpha) * textDodge,
          z: cap.z,
        ),
    ];
  }
}
