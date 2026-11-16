import 'dart:math' as math;

import 'player_physics.dart';

typedef HintBounds = ({double x0, double x1, double y0, double y1});

bool hintOverlap(HintBounds a, HintBounds b) =>
    a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;
HintBounds hintBoyBox(PlayerState p) =>
    (x0: p.x - .4, x1: p.x + .4, y0: p.y, y1: p.y + 1.25);

/// Source xu / pm. Position is the bottom centre of the original key artwork.
class OriginalHintCap {
  OriginalHintCap(
    this.w,
    this.h, {
    this.fadeIn = .5,
    this.fadeOut = .8,
    this.ring = false,
  }) {
    if (ring) cap = capNow = .45;
  }
  final double w, h, fadeIn, fadeOut;
  double x = 0, y = 0, z = 1.2;
  double base = 0, dodge = 1, cap = 1, capNow = 1, a = 0;
  double time = 0, push = 0, nudgeTime = 0;
  bool want = false, nudging = false, hit = false;
  final bool ring;
  HintBounds get box => ring
      ? (x0: x - .21, x1: x + .21, y0: y, y1: y + .42)
      : (x0: x - w / 2, x1: x + w / 2, y0: y, y1: y + h);
  void nudge(bool on) {
    if (on && !nudging) nudgeTime = ring ? 2.1 : 0;
    nudging = on;
  }

  void update(double dt, PlayerState? player) {
    time += dt;
    base = want
        ? math.min(1, base + dt / fadeIn)
        : math.max(0, base - dt / fadeOut);
    hit = player != null && hintOverlap(box, hintBoyBox(player));
    dodge = hit ? math.max(0, dodge - dt / .12) : math.min(1, dodge + dt / .3);
    if (nudging) {
      nudgeTime += dt;
      if (nudgeTime >= 2.4) {
        nudgeTime -= 2.4;
        push = 1;
      }
    }
    push = math.max(0, push - dt / .35);
    capNow = capNow > cap
        ? math.max(cap, capNow - dt / .15)
        : math.min(cap, capNow + dt / (ring ? .2 : .3));
    a = math.min(base, capNow) * dodge;
  }

  double get pressWave => math.sin(push * math.pi);
  double get drawY => y + h / 2 - .03 * pressWave - (ring ? .045 : 0);
  double get drawScale => ring ? 1 - .14 * pressWave : 1;
}

/// Default pinned movement hint (Nr), anchored to the start of each journey.
class OriginalMoveHint {
  final cap = OriginalHintCap(1.998, .48, fadeIn: .7, fadeOut: 1.2);
  bool armed = false, done = false, on = false;
  double time = 0, shownTime = 0, walked = 0, still = 0, anchorX = 0;
  double? lastX;
  int? token;
  int shows = 0;
  String texture = 'move';
  void arm(double x, double y, int nextToken) {
    if (token == nextToken) return;
    token = nextToken;
    done = on = false;
    armed = true;
    time = shownTime = walked = still = 0;
    anchorX = x;
    lastX = x;
    cap.x = x;
    cap.y = y + 1.45;
  }

  void update(
    double dt,
    PlayerState p,
    double move,
    bool jump,
    double viewWidth,
  ) {
    if (armed && !done) {
      time += dt;
      if (lastX != null) walked += (p.x - lastX!).abs();
      lastX = p.x;
      final next = time >= .15;
      if (next && !on) shows++;
      on = next;
      if (on) shownTime += dt;
      if (on && (p.x - anchorX).abs() > viewWidth * .5) {
        done = true;
        on = false;
      }
    }
    final active = move.abs() > .3 || jump;
    still = on && !active && walked < .05 ? still + dt : 0;
    var left = move < -.3, right = move > .3;
    if (on && !active && shownTime >= 6 && walked < .05) {
      final phase = (shownTime - 6) % 2.4;
      if (phase < .35) left = true;
      if (phase >= 1.2 && phase < 1.55) right = true;
    }
    texture = left
        ? 'move_left'
        : right
        ? 'move_right'
        : 'move';
    cap.want = on;
    cap.update(dt, p);
  }
}

/// Source Dr: only teaches the first step higher than the auto-step threshold.
class OriginalJumpHint {
  OriginalJumpHint(this.x0, this.x1, double ground, double top) {
    cap.x = (x0 + x1) / 2;
    cap.y = ground + top + 2.25;
  }
  final double x0, x1;
  final cap = OriginalHintCap(1.798 * 1.25, .48 * 1.25);
  bool jumpHeld = false, done = false, shown = false;
  double pressed = -1, stuck = 0;
  int shows = 0;
  void update(double dt, PlayerState p, double move, bool jump, bool enabled) {
    if (jump && !jumpHeld) pressed = 0;
    jumpHeld = jump;
    if (!done && p.grounded && p.x > x1 + .4 && shows > 0) done = true;
    final next = enabled && !done && p.x >= x0 - 3.5 && p.x <= x1 + .4;
    if (next && !shown) shows++;
    shown = next;
    cap.want = next;
    if (pressed >= 0) {
      cap.cap = .4;
      pressed += dt;
      if (p.grounded && pressed > .3) pressed = -1;
    } else {
      cap.cap = 1;
    }
    stuck = next && p.grounded && x0 - p.x < .6 && p.x < x0 && move > .3
        ? stuck + dt
        : 0;
    cap.nudge(stuck >= 1.5);
    cap.update(dt, p);
  }
}
